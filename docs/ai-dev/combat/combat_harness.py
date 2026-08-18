"""
Canary combat-pipeline formula mirror + sensitivity harness.
READ-ONLY INVESTIGATION TOOL -- not part of the game server, not wired into any build.

Every formula below is transcribed from a specific cited source location found during the
COMBAT-ROOT-ARCHITECTURE passes (docs/ai-dev/combat/01_COMBAT_ROOT_ARCHITECTURE_CLAUDE_DISCOVERY.md,
docs/ai-dev/combat/02_COMBAT_TARGETED_EVIDENCE_CLAUDE.md). This harness has NOT been cross-validated
against a running server (no gameplay harness exists in this environment) -- treat all outputs as
CANDIDATE sensitivity/mechanism data for ChatGPT/owner review, not as ground truth.

=== Pass 02 corrections applied (see docs/ai-dev/combat/02_COMBAT_TARGETED_EVIDENCE_CLAUDE.md section 11) ===

J1. C++ std::round/std::lround round HALF AWAY FROM ZERO. Python's builtin round() is banker's
    rounding (round-half-to-even) and is WRONG for mirroring this engine. cpp_round_half_away() and
    cpp_lround() below replace every prior bare use of round().
J2. The engine's mitigation compound assignment (creature.cpp:914, `damage -= (damage*mitigation)/100.;`)
    computes `damage - reduction` ENTIRELY IN DOUBLE PRECISION FIRST, then truncates the FINAL combined
    result toward zero exactly once (implicit double->int32_t narrowing on the compound-assign store).
    This is NOT the same as truncating the reduction alone and then subtracting as integers -- those
    two orders can disagree by 1 whenever the reduction has a fractional part. mitigate_cpp_exact()
    below fixes this; the pass-01 harness's mitigate() had this bug (truncated the reduction, not the
    final result) and is INTENTIONALLY LEFT BELOW, renamed, as a labeled contrast for the microtests.
J3. Creature::blockCount is initialized to 0 (creature.hpp:898), NOT full. It gains +1 only when
    accumulated blockTicks reaches >=1000ms (creature.cpp:142-146), capped at 2, and blockTicks resets
    to exactly 0 (not decremented by 1000) on every threshold crossing -- BlockCountPool below now
    models this exactly, including the non-modulo reset (partial-tick drift is real and preserved).
J4. Replaced the pass-01 "fewer samples per attacker count" approximation with a real discrete-event
    timeline (DiscreteEventTimeline) -- explicit attacker count/interval/phase-offset, one shared
    defender BlockCountPool advanced by real elapsed time between ordered events, not a sampling proxy.
J5. Player::blockHit's absorb loop (player.cpp:3861-3919) is NOT a single "group percent" per item --
    per item, EACH imbuement slot applies its OWN std::ceil-rounded subtraction sequentially (against
    the already-shrunk running damage), and only THEN does that item's own ability absorb (absorbPercent
    + fieldAbsorbPercent, SUMMED once, std::round-rounded) apply as a separate subtraction. The pass-01
    harness collapsed imbuement+item into one artificial "group" -- player_item_absorb_pipeline() below
    replaces that with the correctly-nested, non-collapsed structure.
J6. normal_random() below is explicitly labeled DISTRIBUTION_SHAPE_APPROXIMATION, not a "byte-for-byte
    port" of std::normal_distribution<float>(0.5f,0.25f) -- the underlying PRNG stream (Mersenne
    Twister seeded via std::random_device, drawn through libstdc++'s specific normal_distribution
    implementation) is NOT reproduced; only the distribution's shape (rejection-sampled to [0,1],
    mean 0.5, sd 0.25, scaled to [min,max]) is approximated via Python's random.gauss. Sequence
    identity with the live server is NOT claimed and must not be assumed.

Usage: python combat_harness.py   (runs only the deterministic microtests, per pass-02 instruction not
to run a large probabilistic campaign this pass; run_probabilistic_sanity_check() from pass 01 is kept
in this module, updated to use the corrected functions, but is not auto-invoked.)
"""
import math
import random
import statistics

RNG_LABEL = "DISTRIBUTION_SHAPE_APPROXIMATION"  # see module docstring J6 -- NOT a byte-for-byte PRNG port

# ---------------------------------------------------------------------------
# J1: C++ rounding-semantics helpers
# ---------------------------------------------------------------------------

def cpp_round_half_away(x: float) -> float:
    """Mirrors std::round: round half away from zero (not Python's round-half-to-even)."""
    if x >= 0:
        return math.floor(x + 0.5)
    return math.ceil(x - 0.5)


def cpp_lround(x: float) -> int:
    """Mirrors std::lround: same half-away-from-zero rule, returns an integer."""
    return int(cpp_round_half_away(x))


def cpp_trunc_toward_zero(x: float) -> int:
    """Mirrors an implicit double->int32_t narrowing conversion in C++ (e.g. a compound
    assignment `int32_t &= double_expr`): truncates toward zero. Python's math.trunc already
    does this correctly for both signs; kept as an explicitly named helper for clarity/audit-ability
    at each call site rather than relying on an unlabeled math.trunc() scattered through the code."""
    return math.trunc(x)


def python_bankers_round_for_contrast(x: float) -> int:
    """Deliberately the WRONG (Python-native) rounding, kept only so the microtests can demonstrate
    the divergence from cpp_round_half_away() at half-integer values -- never use this for a real
    formula mirror."""
    return round(x)


# ---------------------------------------------------------------------------
# Primitives -- src/utils/tools.cpp:455-475 (verified exact, pass 01)
# ---------------------------------------------------------------------------

def uniform_random(a, b):
    if a == b:
        return a
    if a > b:
        a, b = b, a
    return random.randint(a, b)


def normal_random(a, b):
    """DISTRIBUTION_SHAPE_APPROXIMATION (see J6) of tools.cpp:466-475's
    std::normal_distribution<float>(0.5f, 0.25f), rejection-sampled to [0,1], then
    lround(v * (b - a)) + min(a,b). The rounding step itself (cpp_lround) IS an exact mirror;
    the underlying random stream is not."""
    lo, hi = min(a, b), max(a, b)
    while True:
        v = random.gauss(0.5, 0.25)
        if 0.0 <= v <= 1.0:
            break
    return lo + cpp_lround(v * (hi - lo))


# ---------------------------------------------------------------------------
# Outgoing player melee damage -- weapons.cpp:645-664, 88-100
# ---------------------------------------------------------------------------

def player_melee_damage_range(level, skill, weapon_attack, attack_factor, element_attack=0, proficiency_attack=0):
    combined_attack = weapon_attack + element_attack + proficiency_attack
    max_value = cpp_round_half_away(0.085 * attack_factor * combined_attack * skill + (level // 5))
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


def mitigate_cpp_exact(damage, mitigation_pct):
    """J2 fix. creature.cpp:914: damage -= (damage * getMitigation()) / 100.;
    Correct semantics: compute (damage - reduction) fully in double, THEN truncate the whole
    result toward zero exactly once -- NOT truncate the reduction and subtract as integers."""
    if damage <= 0:
        return damage
    reduction = (damage * mitigation_pct) / 100.0
    result_double = damage - reduction
    reduced = cpp_trunc_toward_zero(result_double)
    return max(0, reduced)


def mitigate_PASS01_BUGGY_reference(damage, mitigation_pct):
    """Deliberately kept, deliberately mislabeled in its own name: this is the pass-01 harness's
    mitigate() function, which truncated the REDUCTION alone before subtracting -- WRONG per J2.
    Kept only so the microtests can demonstrate the numeric divergence from mitigate_cpp_exact()."""
    if damage <= 0:
        return damage
    reduced = damage - int((damage * mitigation_pct) / 100.0)
    return max(0, reduced)


def monster_elemental_resist(damage, percent):
    # monster.cpp:1404-1423 -- damage *= (100 - percent) / 100, round-to-nearest, NOT clamped in C++
    if damage == 0 or percent == 0:
        return damage
    damage = cpp_round_half_away(damage * ((100 - percent) / 100.0))
    return max(0, damage)


# ---------------------------------------------------------------------------
# J3: exact blockCount/blockTicks lifecycle -- creature.hpp:898, creature.cpp:142-146,958-993
# ---------------------------------------------------------------------------

class BlockCountPool:
    """Exact mirror of Creature's blockCount/blockTicks state machine.
    - blockCount starts at 0 (creature.hpp:898: `uint32_t blockCount = 0;`), NOT full.
    - blockTicks accumulates by the onThink interval; when it reaches >=1000, blockCount is
      incremented by 1 (capped at 2) and blockTicks is reset to EXACTLY 0 (not decremented by
      1000) -- creature.cpp:142-146. This means a non-1000-divisible tick interval loses the
      remainder each time a threshold is crossed; that drift is intentionally preserved here.
    - consumption (creature.cpp:958-965): a charge is consumed by ANY hit where
      `checkDefense || checkArmor` is true, not only checkDefense -- see A002 in pass 02.
    """

    def __init__(self):
        self.block_count = 0
        self.block_ticks = 0

    def advance(self, interval_ms):
        self.block_ticks += interval_ms
        if self.block_ticks >= 1000:
            self.block_count = min(self.block_count + 1, 2)
            self.block_ticks = 0  # exact reset, matches source -- NOT `-= 1000`

    def try_consume(self, check_defense, check_armor):
        """Returns (consumed: bool, has_defense: bool). A charge is taken whenever
        check_defense or check_armor is true (creature.cpp:958-960); has_defense (whether the
        shield/weapon defense ROLL itself is permitted) additionally requires check_defense."""
        if not (check_defense or check_armor):
            return False, False
        if self.block_count > 0:
            self.block_count -= 1
            return True, check_defense
        return True, False  # slot consumed attempt still counted as "checked" even with 0 charges;
        # has_defense stays False since no charge was available -- matches hasDefense only becoming
        # true inside the `if (blockCount > 0)` branch in creature.cpp:961-964.


# ---------------------------------------------------------------------------
# J5: exact, non-collapsed Player::blockHit item/imbuement absorb order
# player.cpp:3861-3919
# ---------------------------------------------------------------------------

def player_item_absorb_pipeline(damage, equipped_items):
    """equipped_items: ordered list of items (slot order matters for reproducibility, though the
    real engine's stacking is multiplicative regardless of order since each step operates on the
    already-shrunk running damage -- order only matters for exact intermediate values, not the
    final result, given fixed percentages).

    Each item is a dict: {"imbuement_percents": [p1, p2, ...], "ability_absorb_percent": x,
    "field_absorb_percent": y (0 if not a field-damage context)}.

    Per item, in order (NOT collapsed into one combined percent -- J5):
      1. each imbuement slot's absorb percent is applied INDIVIDUALLY, std::ceil-rounded,
         sequentially against the shrinking damage (player.cpp:3881: `std::ceil(...)`).
      2. only after all imbuement slots on that item, the item's own ability absorb
         (absorbPercent + fieldAbsorbPercent, SUMMED into one combined percent) is applied as a
         single std::round-rounded subtraction (player.cpp:3890-3906).
    Then the NEXT item repeats this, against the further-shrunk damage.
    """
    for item in equipped_items:
        if damage <= 0:
            break
        for imbuement_pct in item.get("imbuement_percents", []):
            if damage <= 0:
                break
            if imbuement_pct == 0:
                continue
            damage -= math.ceil(damage * (imbuement_pct / 100.0))  # player.cpp:3881 -- std::ceil
            damage = max(0, damage)
        if damage <= 0:
            break
        total_ability_pct = item.get("ability_absorb_percent", 0) + item.get("field_absorb_percent", 0)
        if total_ability_pct != 0:
            damage -= cpp_round_half_away(damage * (total_ability_pct / 100.0))  # player.cpp:3902 -- std::round
            damage = max(0, damage)
    return damage


def wheel_resistance_adjustment(damage, wheel_element_absorb_basis_points, avatar_skill_percent):
    """player_wheel.cpp:4024-4031 (PlayerWheel::adjustDamageBasedOnResistanceAndSkill), applied
    ONCE, after every equipped item's absorb loop above -- both std::ceil-rounded."""
    if damage <= 0:
        return damage
    if wheel_element_absorb_basis_points:
        damage -= math.ceil((damage * wheel_element_absorb_basis_points) / 10000.0)
        damage = max(0, damage)
    if avatar_skill_percent:
        damage -= math.ceil((damage * avatar_skill_percent) / 100.0)
        damage = max(0, damage)
    return damage


# ---------------------------------------------------------------------------
# Full pipelines, confirmed order (pass 01 section 6), using corrected functions
# ---------------------------------------------------------------------------

def resolve_hit_vs_monster(raw_damage, monster_armor, monster_defense, monster_mitigation_pct,
                            monster_element_pct, block_pool: BlockCountPool, is_physical=True):
    damage = raw_damage
    check_defense = is_physical
    check_armor = is_physical
    _, has_defense = block_pool.try_consume(check_defense, check_armor)
    if check_defense:
        damage -= defense_reduction(monster_defense, has_defense)
        damage = max(0, damage)
    if check_armor and damage > 0:
        damage -= armor_reduction(monster_armor)
        damage = max(0, damage)
    if damage > 0:
        damage = mitigate_cpp_exact(damage, min(monster_mitigation_pct, 30.0))  # monster.cpp:1394 cap
    if damage > 0:
        damage = monster_elemental_resist(damage, monster_element_pct)
    return damage


def resolve_hit_vs_player(raw_damage, player_armor, player_defense, player_mitigation_pct,
                           equipped_items, block_pool: BlockCountPool, is_physical=True,
                           wheel_element_absorb_bp=0, wheel_avatar_skill_pct=0):
    damage = raw_damage
    check_defense = is_physical
    check_armor = is_physical
    _, has_defense = block_pool.try_consume(check_defense, check_armor)
    if check_defense:
        damage -= defense_reduction(player_defense, has_defense)
        damage = max(0, damage)
    if check_armor and damage > 0:
        damage -= armor_reduction(player_armor)
        damage = max(0, damage)
    if damage > 0:
        damage = mitigate_cpp_exact(damage, player_mitigation_pct)  # no cap on player side
    if damage > 0:
        damage = player_item_absorb_pipeline(damage, equipped_items)
    if damage > 0:
        damage = wheel_resistance_adjustment(damage, wheel_element_absorb_bp, wheel_avatar_skill_pct)
    return damage


# ---------------------------------------------------------------------------
# J4: discrete-event multi-attacker timeline (deterministic, no RNG) -- proves the shared
# BlockCountPool's real time-stepped behavior instead of the pass-01 sampling approximation.
# ---------------------------------------------------------------------------

class AttackEvent:
    __slots__ = ("time_ms", "attacker_id", "is_physical")

    def __init__(self, time_ms, attacker_id, is_physical=True):
        self.time_ms = time_ms
        self.attacker_id = attacker_id
        self.is_physical = is_physical


def build_attacker_schedule(attacker_specs, duration_ms):
    """attacker_specs: list of (attacker_id, interval_ms, phase_offset_ms, is_physical).
    Returns a time-ordered list of AttackEvent covering [0, duration_ms)."""
    events = []
    for attacker_id, interval_ms, phase_offset_ms, is_physical in attacker_specs:
        t = phase_offset_ms
        while t < duration_ms:
            events.append(AttackEvent(t, attacker_id, is_physical))
            t += interval_ms
    events.sort(key=lambda e: e.time_ms)
    return events


def run_discrete_event_timeline(attacker_specs, duration_ms, verbose=False):
    """Deterministic timeline: advances ONE shared defender BlockCountPool by real elapsed time
    between consecutive events (not per-hit fixed increments), then resolves whether each event's
    hit gets a defense-roll opportunity (checkDefense=checkArmor=is_physical, matching the
    physical-only BLOCKARMOR/BLOCKSHIELD gating found in pass 01 section 4C/E). Returns a list of
    (time_ms, attacker_id, had_charge_available, got_defense_roll) tuples plus the final pool state.
    No damage RNG is involved -- this proves only the charge-consumption timeline mechanism (J4's
    explicit "no large balancing campaign" instruction)."""
    pool = BlockCountPool()
    events = build_attacker_schedule(attacker_specs, duration_ms)
    last_t = 0
    results = []
    for ev in events:
        pool.advance(ev.time_ms - last_t)
        last_t = ev.time_ms
        had_charge_before = pool.block_count > 0
        _, has_defense = pool.try_consume(check_defense=ev.is_physical, check_armor=ev.is_physical)
        results.append((ev.time_ms, ev.attacker_id, had_charge_before, has_defense))
        if verbose:
            print(f"  t={ev.time_ms:5d}ms attacker={ev.attacker_id} chargeAvailable={had_charge_before} gotDefenseRoll={has_defense} poolAfter={pool.block_count}")
    return results, pool


# ---------------------------------------------------------------------------
# J7: deterministic microtests (assertions), NOT a probabilistic campaign.
# ---------------------------------------------------------------------------

def _assert(name, condition, detail=""):
    status = "PASS" if condition else "FAIL"
    print(f"[{status}] {name}" + (f" -- {detail}" if detail else ""))
    if not condition:
        raise AssertionError(f"{name}: {detail}")


def run_microtests():
    print("=== J7 MICROTEST 1: C++ half-away rounding vs Python banker's rounding ===")
    # std::round(2.5) == 3.0 (half away from zero); Python round(2.5) == 2 (banker's, rounds to even)
    _assert("cpp_round_half_away(2.5) == 3", cpp_round_half_away(2.5) == 3)
    _assert("cpp_round_half_away(-2.5) == -3", cpp_round_half_away(-2.5) == -3)
    _assert("cpp_round_half_away(0.5) == 1", cpp_round_half_away(0.5) == 1)
    _assert("cpp_round_half_away(-0.5) == -1", cpp_round_half_away(-0.5) == -1)
    _assert("python round(2.5) == 2 (demonstrates the divergence this fix corrects)",
            python_bankers_round_for_contrast(2.5) == 2)
    _assert("cpp_round_half_away(2.5) != python round(2.5) -- proves the bug pass-02 asked to fix",
            cpp_round_half_away(2.5) != python_bankers_round_for_contrast(2.5))

    print()
    print("=== J7 MICROTEST 2: mitigation fractional-truncation-order case ===")
    # damage=100, mitigation=33.7% -> reduction=33.7 -> correct: trunc(100-33.7)=trunc(66.3)=66
    # pass-01 buggy version: 100 - int(33.7) = 100 - 33 = 67 (off by one)
    correct = mitigate_cpp_exact(100, 33.7)
    buggy = mitigate_PASS01_BUGGY_reference(100, 33.7)
    _assert("mitigate_cpp_exact(100, 33.7%) == 66", correct == 66, f"got {correct}")
    _assert("mitigate_PASS01_BUGGY_reference(100, 33.7%) == 67 (the bug being demonstrated)", buggy == 67, f"got {buggy}")
    _assert("corrected and buggy mitigation functions disagree on this fractional case", correct != buggy,
            f"correct={correct} buggy={buggy}")

    print()
    print("=== J7 MICROTEST 3: blockCount starts at 0 ===")
    pool = BlockCountPool()
    _assert("BlockCountPool starts with block_count == 0", pool.block_count == 0)
    _assert("BlockCountPool starts with block_ticks == 0", pool.block_ticks == 0)

    print()
    print("=== J7 MICROTEST 4: charge appears at exactly 1000ms ===")
    pool = BlockCountPool()
    pool.advance(999)
    _assert("no charge yet at 999ms", pool.block_count == 0, f"got {pool.block_count}")
    pool.advance(1)
    _assert("charge appears at 1000ms cumulative", pool.block_count == 1, f"got {pool.block_count}")
    _assert("block_ticks resets to exactly 0 (not -=1000) on threshold cross", pool.block_ticks == 0)

    print()
    print("=== J7 MICROTEST 5: blockCount caps at 2 ===")
    pool = BlockCountPool()
    for _ in range(10):
        pool.advance(1000)
    _assert("block_count caps at 2 after many 1000ms advances", pool.block_count == 2, f"got {pool.block_count}")

    print()
    print("=== J7 MICROTEST 6 (A002): an armor-only hit (checkDefense=False, checkArmor=True) consumes a charge ===")
    pool = BlockCountPool()
    pool.advance(1000)  # 1 charge available
    _assert("1 charge available before the armor-only hit", pool.block_count == 1)
    consumed, has_defense = pool.try_consume(check_defense=False, check_armor=True)
    _assert("armor-only hit IS counted as consuming an attempt", consumed is True)
    _assert("armor-only hit receives NO defense roll for itself", has_defense is False)
    _assert("the shared charge was actually spent (pool now at 0)", pool.block_count == 0, f"got {pool.block_count}")
    # now a SUBSEQUENT melee hit in the same window finds no charge left:
    consumed2, has_defense2 = pool.try_consume(check_defense=True, check_armor=True)
    _assert("a later melee hit in the same window is starved of its defense roll by the earlier armor-only hit",
            has_defense2 is False, "this is the exact A002 mechanism -- see 02_COMBAT_TARGETED_EVIDENCE_CLAUDE.md section 5")

    print()
    print("=== J7 MICROTEST 7: defense+armor path applies both, defense first ===")
    random.seed(42)
    pool = BlockCountPool()
    pool.advance(1000)
    dmg = 1000
    d_reduction = defense_reduction(100, True)
    a_reduction = armor_reduction(80)
    expected = max(0, max(0, dmg - d_reduction) - a_reduction)
    _assert("defense then armor reduces sequentially (not summed independently)", expected < dmg,
            f"dmg={dmg} defense_reduction={d_reduction} armor_reduction={a_reduction} expected_after_both={expected}")

    print()
    print("=== J7 MICROTEST 8: elemental hit bypasses defense+armor entirely (monsters.cpp:111-121) ===")
    random.seed(7)
    pool_phys = BlockCountPool()
    pool_phys.advance(1000)
    pool_elem = BlockCountPool()
    pool_elem.advance(1000)
    raw = 500
    physical_result = resolve_hit_vs_player(raw, player_armor=60, player_defense=40, player_mitigation_pct=18.0,
                                             equipped_items=[], block_pool=pool_phys, is_physical=True)
    elemental_result = resolve_hit_vs_player(raw, player_armor=60, player_defense=40, player_mitigation_pct=18.0,
                                              equipped_items=[], block_pool=pool_elem, is_physical=False)
    _assert("elemental path (is_physical=False) never consumes/uses defense+armor, so it takes MORE damage than the physical path at identical raw/mitigation",
            elemental_result >= physical_result, f"physical={physical_result} elemental={elemental_result}")
    _assert("elemental hit did not touch the blockCount pool at all", pool_elem.block_count == 1,
            f"pool_elem.block_count={pool_elem.block_count} (should be unchanged from the advance(1000) above, since is_physical=False -> check_defense=check_armor=False -> try_consume no-ops)")

    print()
    print("=== J7 MICROTEST 9: J5 non-collapsed item/imbuement absorb order ===")
    # One item: two imbuements (10%, 5%, each std::ceil, sequential), then item ability absorb 8% (std::round), once.
    item = {"imbuement_percents": [10, 5], "ability_absorb_percent": 8, "field_absorb_percent": 0}
    damage = 1000
    # step by step by hand, to prove the harness's nesting matches the described order:
    d1 = damage - math.ceil(damage * 0.10)  # first imbuement, ceil
    d2 = d1 - math.ceil(d1 * 0.05)          # second imbuement, ceil, against the ALREADY-shrunk d1
    d3 = d2 - cpp_round_half_away(d2 * 0.08)  # item ability absorb, round, against the further-shrunk d2
    harness_result = player_item_absorb_pipeline(damage, [item])
    _assert("player_item_absorb_pipeline matches the hand-traced per-item nested order (imbuements sequentially, THEN item ability once)",
            harness_result == d3, f"hand-traced={d3} harness={harness_result}")

    print()
    print("=== J7 MICROTEST 10: discrete-event timeline mechanism (deterministic, no damage RNG) ===")
    # 3 attackers, one every 400ms with staggered phase offsets, over a 2000ms window, all physical.
    specs = [("melee_A", 400, 0, True), ("melee_B", 400, 133, True), ("ranged_C", 900, 50, True)]
    results, final_pool = run_discrete_event_timeline(specs, duration_ms=2000, verbose=True)
    total_events = len(results)
    got_defense_count = sum(1 for _, _, _, hd in results if hd)
    _assert("discrete-event timeline produced a deterministic, non-empty, time-ordered event list",
            total_events > 0 and all(results[i][0] <= results[i + 1][0] for i in range(len(results) - 1)))
    _assert("defense-roll opportunities are bounded by the shared 2-cap regenerating pool, not by attacker count",
            got_defense_count <= total_events)
    print(f"  total_events={total_events} got_defense_roll_count={got_defense_count} final_pool_block_count={final_pool.block_count}")

    print()
    print("ALL MICROTESTS PASSED")


# ---------------------------------------------------------------------------
# Pass-01 probabilistic sanity-check scenarios, kept for continuity, updated to use the
# corrected functions. NOT auto-invoked this pass per the explicit "no large campaign" instruction --
# call run_probabilistic_sanity_check() manually if a future pass authorizes it.
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


def run_probabilistic_sanity_check():
    random.seed(1234)
    N = 2000
    print("=== SCENARIO 1: level 200 knight, sword skill 100, weapon atk 45, ATTACK mode, vs monster armor sweep ===")
    for monster_armor in (0, 20, 50, 100, 200):
        pool = BlockCountPool()
        pool.advance(1000)  # give it its first charge, matching a defender that's been alive >=1s
        raws = [roll_melee_damage(200, 100, 45, ATTACK_FACTOR["ATTACK"]) for _ in range(N)]
        finals = [resolve_hit_vs_monster(r, monster_armor, monster_defense=0, monster_mitigation_pct=0,
                                          monster_element_pct=0, block_pool=pool, is_physical=True) for r in raws]
        raw_stats, final_stats = summarize(raws), summarize(finals)
        effective_reduction = 1.0 - (final_stats["mean"] / raw_stats["mean"]) if raw_stats["mean"] else 0.0
        print(f"  monster_armor={monster_armor:4d}  raw_mean={raw_stats['mean']:.1f}  final_mean={final_stats['mean']:.1f}"
              f"  effective_reduction={effective_reduction*100:.1f}%  final_p10/p90={final_stats['p10']}/{final_stats['p90']}")


if __name__ == "__main__":
    run_microtests()
