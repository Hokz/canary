"""
Canary combat-pipeline formula mirror + sensitivity harness.
READ-ONLY INVESTIGATION TOOL -- not part of the game server, not wired into any build.

Every formula below is transcribed from a specific cited source location found during
COMBAT-ROOT-ARCHITECTURE pass 01 (see docs/ai-dev/combat/01_COMBAT_ROOT_ARCHITECTURE_CLAUDE_DISCOVERY.md
section 17 for the citation of each function). This harness has NOT been cross-validated against a
running server (no gameplay harness exists in this environment) -- treat all outputs as CANDIDATE
sensitivity data for ChatGPT/owner review, not as ground truth.

Usage: python combat_harness.py
"""
import math
import random
import statistics

# ---------------------------------------------------------------------------
# Primitives -- src/utils/tools.cpp:455-475 (verified exact, read this pass)
# ---------------------------------------------------------------------------

def uniform_random(a, b):
    if a == b:
        return a
    if a > b:
        a, b = b, a
    return random.randint(a, b)


def normal_random(a, b):
    # std::normal_distribution<float>(0.5f, 0.25f), rejection-sampled to [0,1],
    # then lround(v * (b - a)) + min(a,b). tools.cpp:466-475.
    lo, hi = min(a, b), max(a, b)
    while True:
        v = random.gauss(0.5, 0.25)
        if 0.0 <= v <= 1.0:
            break
    return lo + round(v * (hi - lo))


# ---------------------------------------------------------------------------
# Outgoing player melee damage -- weapons.cpp:645-664, 88-100
# ---------------------------------------------------------------------------

def player_melee_damage_range(level, skill, weapon_attack, attack_factor, element_attack=0, proficiency_attack=0):
    combined_attack = weapon_attack + element_attack + proficiency_attack
    max_value = round(0.085 * attack_factor * combined_attack * skill + (level // 5))
    min_value = (level // 5) if weapon_attack > 0 else 0
    return min_value, max_value


def roll_melee_damage(level, skill, weapon_attack, attack_factor, element_attack=0, proficiency_attack=0):
    lo, hi = player_melee_damage_range(level, skill, weapon_attack, attack_factor, element_attack, proficiency_attack)
    return normal_random(lo, hi)


# fight-mode attack factor -- player.cpp:822-833
ATTACK_FACTOR = {"ATTACK": 1.0, "BALANCED": 0.75, "DEFENSE": 0.5}


# ---------------------------------------------------------------------------
# Defensive pipeline, in confirmed runtime order -- creature.cpp:944-1009,
# 911-922, 924-942; player.cpp:640,758,732; monster.cpp:1389-1427
# ---------------------------------------------------------------------------

def armor_reduction(armor):
    # creature.cpp:976-988
    if armor > 3:
        return uniform_random(armor // 2, armor - (armor % 2 + 1))
    elif armor > 0:
        return 1
    return 0


def defense_reduction(defense, has_block_charge):
    # creature.cpp:958-974 -- gated by blockCount ("has_block_charge")
    if not has_block_charge:
        return 0
    return uniform_random(defense // 2, defense)


def mitigate(damage, mitigation_pct):
    # creature.cpp:911-922 -- damage -= (damage * mitigation) / 100.  (int32_t truncation, NOT rounded)
    if damage <= 0:
        return damage
    reduced = damage - int((damage * mitigation_pct) / 100.0)
    return max(0, reduced)


def item_absorb_stack(damage, percents_same_item_groups):
    """
    percents_same_item_groups: list of lists. Each inner list = percents on ONE item
    (summed additively, player.cpp:3890-3906 totalAbsorbPercent). Each item then applied
    sequentially against the shrinking damage (multiplicative across items), matching the
    live Player::blockHit loop (player.cpp:3861-3919), NOT the dead getFinalDamageReduction
    closed-form (player.cpp:5644, confirmed unreachable -- see finding COMBAT-C-006).
    """
    for group in percents_same_item_groups:
        if damage <= 0:
            break
        total_pct = sum(group)
        damage -= round(damage * (total_pct / 100.0))
        damage = max(0, damage)
    return damage


def monster_elemental_resist(damage, percent):
    # monster.cpp:1404-1423 -- damage *= (100 - percent) / 100, round-to-nearest, NOT clamped in C++
    if damage == 0 or percent == 0:
        return damage
    damage = round(damage * ((100 - percent) / 100.0))
    return max(0, damage)


class BlockCountPool:
    """Mirrors creature.hpp:898 + creature.cpp:142-146: cap 2, +1 per 1000ms, shared per defender."""

    def __init__(self, cap=2):
        self.cap = cap
        self.count = cap

    def try_consume(self):
        if self.count > 0:
            self.count -= 1
            return True
        return False


def resolve_hit_vs_monster(raw_damage, monster_armor, monster_defense, monster_mitigation_pct,
                            monster_element_pct, block_pool: BlockCountPool, is_physical=True):
    """Full pipeline for a hit landing on a MONSTER target, confirmed order:
    (condition absorb -- N/A, no condition active in this harness case)
    -> immunity (N/A)
    -> defense (blockCount-gated, monster.cpp getDefense()) [physical only, since BLOCKSHIELD/BLOCKARMOR
       are only set for physical melee per monsters.cpp:111-121]
    -> armor (same physical-only gating)
    -> mitigation (Monster::getMitigation, capped at 30 -- monster.cpp:1394)
    -> elemental resist (Monster::blockHit's elementMap step, monster.cpp:1404-1423)
    """
    damage = raw_damage
    if is_physical:
        has_charge = block_pool.try_consume()
        damage -= defense_reduction(monster_defense, has_charge)
        damage = max(0, damage)
        if damage > 0:
            damage -= armor_reduction(monster_armor)
            damage = max(0, damage)
    if damage > 0:
        damage = mitigate(damage, min(monster_mitigation_pct, 30.0))
    if damage > 0:
        damage = monster_elemental_resist(damage, monster_element_pct)
    return damage


def resolve_hit_vs_player(raw_damage, player_armor, player_defense, player_mitigation_pct,
                           item_absorb_groups, block_pool: BlockCountPool, is_physical=True):
    """Full pipeline for a hit landing on a PLAYER target, confirmed order:
    defense -> armor -> mitigation (Wheel, uncapped) -> item/imbuement absorb loop (last).
    """
    damage = raw_damage
    if is_physical:
        has_charge = block_pool.try_consume()
        damage -= defense_reduction(player_defense, has_charge)
        damage = max(0, damage)
        if damage > 0:
            damage -= armor_reduction(player_armor)
            damage = max(0, damage)
    if damage > 0:
        damage = mitigate(damage, player_mitigation_pct)  # no cap on player side
    if damage > 0:
        damage = item_absorb_stack(damage, item_absorb_groups)
    return damage


# ---------------------------------------------------------------------------
# Small sanity-check runner -- NOT a balancing campaign, per task instruction.
# A handful of scenarios, N=2000 samples each, just to confirm the harness runs
# and to produce example sensitivity statistics for the handoff doc.
# ---------------------------------------------------------------------------

def summarize(samples):
    s = sorted(samples)
    n = len(s)

    def pct(p):
        idx = min(n - 1, int(round(p / 100.0 * (n - 1))))
        return s[idx]

    return {
        "min": s[0], "max": s[-1],
        "mean": statistics.mean(s), "median": statistics.median(s),
        "stdev": statistics.pstdev(s),
        "p10": pct(10), "p25": pct(25), "p75": pct(75), "p90": pct(90), "p95": pct(95),
    }


def sanity_check():
    random.seed(1234)
    N = 2000

    print("=== SCENARIO 1: level 200 knight, sword skill 100, weapon atk 45, ATTACK mode, vs monster armor sweep ===")
    for monster_armor in (0, 20, 50, 100, 200):
        pool = BlockCountPool()
        raws = [roll_melee_damage(200, 100, 45, ATTACK_FACTOR["ATTACK"]) for _ in range(N)]
        finals = [resolve_hit_vs_monster(r, monster_armor, monster_defense=0, monster_mitigation_pct=0,
                                          monster_element_pct=0, block_pool=pool, is_physical=True) for r in raws]
        raw_stats, final_stats = summarize(raws), summarize(finals)
        effective_reduction = 1.0 - (final_stats["mean"] / raw_stats["mean"]) if raw_stats["mean"] else 0.0
        print(f"  monster_armor={monster_armor:4d}  raw_mean={raw_stats['mean']:.1f}  final_mean={final_stats['mean']:.1f}"
              f"  effective_reduction={effective_reduction*100:.1f}%  final_p10/p90={final_stats['p10']}/{final_stats['p90']}")

    print()
    print("=== SCENARIO 2: marginal benefit of +armor at fixed high raw damage (level 400, skill 130, atk 80) ===")
    prev_mean = None
    for monster_armor in (0, 50, 100, 150, 200, 250, 300):
        pool = BlockCountPool()
        raws = [roll_melee_damage(400, 130, 80, ATTACK_FACTOR["ATTACK"]) for _ in range(N)]
        finals = [resolve_hit_vs_monster(r, monster_armor, 0, 0, 0, pool, True) for r in raws]
        m = statistics.mean(finals)
        marginal = "" if prev_mean is None else f"  marginal(+50 armor)={prev_mean - m:.2f} dmg/hit"
        print(f"  monster_armor={monster_armor:4d}  final_mean={m:.1f}{marginal}")
        prev_mean = m

    print()
    print("=== SCENARIO 3: monster attacking player -- mitigation-only vs mitigation+absorb, multi-attacker blockCount saturation ===")
    for n_attackers in (1, 3, 6):
        pool = BlockCountPool()  # ONE shared pool per defender per ~1s window, confirmed creature.cpp:958-993
        raws = [uniform_random(400, 900) for _ in range(N)]  # a mid-tier monster melee roll
        finals = [resolve_hit_vs_player(r, player_armor=60, player_defense=40, player_mitigation_pct=18.0,
                                         item_absorb_groups=[[10], [5]], block_pool=pool, is_physical=True)
                  for r in raws[:N // max(1, n_attackers)]]  # crude: fewer defense charges survive as attacker count rises
        eff = 1.0 - (statistics.mean(finals) / statistics.mean(raws)) if raws else 0
        print(f"  simultaneous_attackers={n_attackers}  effective_reduction~={eff*100:.1f}%  (blockCount cap=2/s shared across all attackers on this defender)")

    print()
    print("=== SCENARIO 4: elemental hit bypasses armor/defense entirely (monsters.cpp:111-121 gating) ===")
    pool = BlockCountPool()
    raws = [uniform_random(400, 900) for _ in range(N)]
    finals_physical = [resolve_hit_vs_player(r, 60, 40, 18.0, [[10], [5]], pool, is_physical=True) for r in raws]
    pool2 = BlockCountPool()
    finals_elemental = [resolve_hit_vs_player(r, 60, 40, 18.0, [[10], [5]], pool2, is_physical=False) for r in raws]
    print(f"  physical path final_mean={statistics.mean(finals_physical):.1f}  elemental path final_mean={statistics.mean(finals_elemental):.1f}"
          f"  (elemental skips armor+defense entirely -- only mitigation+absorb apply)")


if __name__ == "__main__":
    sanity_check()
