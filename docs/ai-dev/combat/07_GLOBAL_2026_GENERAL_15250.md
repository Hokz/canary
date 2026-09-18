# Global 2026 — Stage 1: general 15.25 completeness

Baseline: `main` at `fd56f9d` (the frozen 15.25 foundation, PR #49 + PR #50).

Stage 1 covers the vocation-independent rules of the 15.25 Vocation Adjustments. The
instruction was **audit first, implement only what is absent or incorrect**, so most of
what follows is a verification record rather than a change: PR #49 already carried a
large part of this, and re-implementing it would have been churn.

## Audit matrix

| # | Requirement | Status | Evidence |
|---|---|---|---|
| 1 | AoE runes (Avalanche, Great Fireball, Thunderstorm, Stone Shower) share base power 50; release-state area preserved | ALREADY CORRECT | all four in `data/scripts/runes/` carry the identical `(level/5) + (ml*1.2) + 7` … `+ (ml*2.8) + 17` formula and `AREA_CIRCLE3X3` |
| 2 | Explosion Rune affects 9 squares, not 5 | ALREADY CORRECT | `AREA_SQUARE1X1` (`register_spells.lua:488`) is a full 3×3 — eight `1`s plus a centre `3`; changed from the 5-tile plus shape by `db6e327` |
| 3 | Auto attacks trigger charms on the main target only; spells and runes unaffected | **IMPLEMENTED HERE** | `CharmProc::allows`, `Player`'s auto-attack context, `Weapon`'s `AutoAttackScope` |
| 4 | Gift of Life additionally restores 20/25/30% maximum mana | **IMPLEMENTED HERE** | `PlayerWheel::getGiftOfLifeManaAmount`, sent by `checkGiftOfLife` |
| 5 | Group XP: 2 different vocations = 35%, 3 = 70% | **BLOCKED — PRODUCT_DECISION** | see below |
| 6 | Combat mode / effective item values (audit only) | ALREADY CORRECT, FROZEN | `effective_combat_values.hpp` 120/130/160; no fight-mode weighting on the modern path |
| 7 | Dedication 0.075% per promotion point; gems 20/22/24/30%; monster mitigation increased | ALREADY CORRECT | `io_wheel.cpp:19` `MITIGATION_INCREASE 0.075`; `wheel_gems.cpp:157` base `2000`; `config.lua.dist:517-518` `1.5` / `45.0` |
| 8 | Potion management (Superior, both Distilled, Great Mana Potion, kegs/casks) | ALREADY CORRECT | `potions.lua` 53162/53163/53164 at 240–360 mana, level 100; `shops.lua:145-147` prices 254 / 381 / 732 — the Distilled pair is exactly +50% over Superior (254) and Ultimate (488); item 238 has no vocation gate |
| 9 | Energy Ring: exactly 2 mana per 1 damage | ALREADY CORRECT | `mana_shield_absorption.hpp`, pinned by `mana_shield_absorption_test.cpp` |
| 10 | Ultimate Healing Rune cannot target another character; Intense audited alike | ALREADY CORRECT | both rune scripts reject a non-self player target and keep self-use |
| 11 | Stance QoL: persistence, no stance, recast disables, family exclusivity, Sorcerer one elemental + one crippling | ALREADY CORRECT | `stance.lua` `Stance.cast` / `Stance.clearFamily`; persistence fixed by `0cbe1f2`; pinned by `stance_persistence_test.cpp`, `stance_family_cooldown_test.cpp`, `test_stance_library.lua` |

## 3. One auto attack, one charm roll

The update adds area ammunition — the storm arrows, thirteen squares each. An arrow
like that is **one auto attack that runs a single `Combat` over thirteen tiles**, and
`Game::combatChangeHealth` runs once per creature damaged, so the offensive charm rolled
once per creature caught. One shot, up to thirteen procs.

The obvious discriminator does not work: `CombatParams::origin` defaults to
`ORIGIN_SPELL` (`combat.hpp:95`), and a scripted weapon never overrides it, so at the
charm call site an area arrow is indistinguishable from an area spell. The built-in
weapon path sets `ORIGIN_RANGED` explicitly; the scripted path — which is the one every
area arrow uses — does not.

So the shot is marked at its source instead:

  - `Weapon::internalUseWeapon` wraps the script call in `AutoAttackScope`, which records
    the creature the shot was aimed at and clears it again on the way out. A guard rather
    than a hand-cleared flag, because `callFunction` can fail and the context must not
    outlive the shot.
  - `Player` holds that context — a creature id and a flag, runtime only, never saved.
  - `CharmProc::allows` is the decision, a pure function of five booleans, so it can be
    exercised without a live area shot.

Ammunition loosed at a **tile** rather than a creature has no main target, so nothing it
catches rolls a charm. Cleave was already excluded, through `damage.extension`.

Spells and runes are untouched: they never set the context, so an area rune still rolls
on every creature it hits, exactly as before.

## 4. Gift of Life returns mana too

`checkGiftOfLife` restored health only. It now sends the same percentage of maximum mana
as a second change — health and mana are two different pipelines, so it is a second call,
with no attacker so nothing treats it as combat.

Both amounts are accessors, `getGiftOfLifeHealthAmount` and `getGiftOfLifeManaAmount`, so
the percentages can be asserted without staging a near-death. One percentage feeds both.

## 5. Group XP — a conflict, not a gap

**This row is not implemented, and deliberately so.**

Stage 1 asks for a vocation-diversity bonus: two different vocations 35%, three 70%. The
repository does the opposite on purpose. Commit `fe96cb1` (16 September) replaced exactly
that lookup table with a bonus keyed on **party size**:

```
2 or 3 members  -> +25%
4 or more       -> +50%
1 member        -> no bonus
```

Its message states the intent plainly — "a party of four knights and a party of
knight/druid/paladin/sorcerer now receive exactly the same bonus" — and tabulates every
resulting delta, including the diverse-party losses. `db6e327` had installed the
diversity table `{1: 1.2, 2: 1.35, 3: 1.70, 4: 2.0}`; `fe96cb1` removed it.

Reverting a deliberate product decision because a later roadmap line says otherwise is
not a call this lane can make. Restoring 35% / 70% means undoing `fe96cb1` and accepting
its deltas in reverse, which is a balance decision with an owner. Status:
**PRODUCT_DECISION**, raised, awaiting Danilo.

Nothing else in Stage 1 depends on it.

## Tests

| File | Cases | What it proves |
|---|---|---|
| `tests/unit/game/charm_proc_test.cpp` | 13 | an ordinary spell hit rolls; an area spell still rolls on everything; an auto attack rolls on its main target and never on the splash; `noCharm`, cleave and damage-over-time never roll; the whole 32-row truth table; the context names exactly one main target, treats a tile shot as having none, clears, is replaced by a second shot, and cannot leak into the next spell |
| `tests/unit/players/wheel/gift_of_life_test.cpp` | 7 | 20/25/30 by stage and 0 without it; mana comes back at every stage; health is unchanged; equal maximums give equal amounts, so both halves read one percentage; a manaless character gets health and no mana; the amounts truncate |

**Not proven by tests:** that a live thirteen-square arrow procs exactly once. That needs
a running map with several creatures around a target, and this repository has no
combat-integration harness. What is proven is the decision the live path calls and the
context it reads — the two things that were wrong.
