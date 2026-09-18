# Global 2026 — Stage 2: Knight completeness

Baseline: `main` at `f6b81a8` (Stage 1 merged).

Audit first, as before. Most of the Knight's 15.25 surface was already in place from
PR #49; three rows were genuinely wrong and are changed here; four need coefficients that
are not published and are routed to Stage 7 rather than guessed at.

## Audit matrix

| Row | Requirement | Status | Evidence |
|---|---|---|---|
| A | Blood Rage post-July +25% melee skill | ALREADY CORRECT | `blood_rage.lua`: `MELEEPERCENT 125` |
| A | Blood Rage damage taken, blocking | ALREADY CORRECT | `DAMAGERECEIVED 115`, `DISABLE_DEFENSE` |
| A | Protector shielding / damage behaviour | ALREADY CORRECT | `SHIELDPERCENT 130`, dealt 85, received 85 |
| A | effective / total skill semantics | ALREADY CORRECT | both are percent conditions, so they ride the PR #50 effective-skill machinery |
| A | legacy timed versions retired | ALREADY CORRECT | ids 132 / 133 were converted in place, not duplicated |
| B | Berserk / Fierce Berserk / Groundshaker mana | ALREADY CORRECT | 115 / 340 / 160 |
| C | Shield Bash: shield required, single target, shield-defence source, next-auto-attack debuff, release power/cooldown/mana/level | ALREADY CORRECT | `shield_bash.lua`: level 18, 30 mana, 4s, base power 55, 50% for 10s |
| C | Shield Bash exact damage formula | FIDELITY_BLOCKER — FORMULA_EVIDENCE_REQUIRED | already labelled in the script; Stage 7 |
| D | Shield Slam: adjacent area, shield required, same debuff primitive, release values | ALREADY CORRECT | `shield_slam.lua`: `AREA_SQUARE1X1`, level 30, 110 mana, 6s, base power 52 |
| D | Shield Slam exact damage formula | FIDELITY_BLOCKER — FORMULA_EVIDENCE_REQUIRED | Stage 7 |
| E | post-July healing mana 60 / 135 / 300 | ALREADY CORRECT | `db6e327` |
| E | **2s healing group cooldown** | **IMPLEMENTED HERE** | the four Knight heals raised 1s → 2s |
| E | better ML + shielding scaling on Knight heals | **FIDELITY_PENDING_EVIDENCE** | see below |
| F | Chivalrous Challenge range + July range fix | ALREADY CORRECT | range 7, noted in the script |
| F | Front Sweep final base power / shape | **FIDELITY_PENDING_EVIDENCE** | see below |
| G | **Battle Healing rework** | **IMPLEMENTED HERE** | Shielding multiplier 0.2 → 2 |
| G | **Combat Mastery rework** | **IMPLEMENTED HERE** | two-handed critical 4/8/12% → 10/12/14% |
| G | Front Sweep augments | ALREADY MAPPED | `io_wheel.cpp:295`, `:583`, `:825` |
| G | Groundshaker augment swap | **FIDELITY_PENDING_EVIDENCE** | mapped (`:299`, `:616`, `:884`) but the intended swap is unspecified |
| G | Shield Slam augments | **MISSING — values unspecified** | Shield Slam has no Wheel mapping at all; the roadmap names the row but no augment values |

## What changed

### Battle Healing — Shielding multiplier 2

`checkBattleHealingAmount` multiplied Shielding by **0.2**, which at 100 Shielding was
20 hit points a tick before the health tiers — negligible. Post-July it is **2**.

The two low-health tiers are deliberately untouched: ×2 at 60% health and below, ×3 at
30% and below, both composing on top of the new multiplier.

`PRODUCT_DECISION`: the requirement read "shield multiplier = 2" and the function has two
multipliers. The Shielding coefficient was the reading chosen by the Product Owner; the
alternative — flattening the ×3 tier to ×2 — would have been a nerf rather than a rework.

### Combat Mastery — two-handed critical 10 / 12 / 14

Was 400 / 800 / 1200 basis points (4 / 8 / 12 percent) by stage; now 1000 / 1200 / 1400.
Stage 1 gains the most and the stages sit two percent apart instead of four.

The one-handed branch — the Defence grant of 10 / 20 / 30 — is untouched.

`PRODUCT_DECISION`: the requirement read "thresholds = 14/12/10%", descending, which does
not match a stage progression. Read as ascending 10 / 12 / 14 by stage, on the Product
Owner's ruling.

### Knight healing — 2s group cooldown

Bruise Bane, Wound Cleansing, Fair Wound Cleansing and Intense Wound Cleansing now hold
the healing group for **2 seconds**. Each spell's own cooldown is unchanged, so the group
gate is what now paces the family.

Scoped to the Knight's four heals on the Product Owner's ruling. Every other vocation's
healing group cooldown stays at 1s — the value was global before this change, so it is
worth stating that this row makes the Knight deliberately different rather than aligning
him with anyone.

## Routed to Stage 7

Four rows need numbers that are not published, and inventing them is exactly what the
governance forbids:

  - **Knight heal scaling.** `wound_cleansing.lua` still scales on level and magic level
    only — `level*0.2 + ml*4 … ml*7.95` — with a comment dating the comparison to 2021.
    There is no Shielding term at all. "Better ML + shielding scaling" needs coefficients;
    `db6e327` changed the mana and said explicitly that it left formulas alone.
  - **Front Sweep.** Still carries `* 1.1` and a literal `TODO : Use New Real Formula
    instead of an %`. Its 15.25 base power and shape are not published.
  - **Groundshaker augment swap.** The spell is mapped on the Wheel; which augment swaps
    for which is not stated.
  - **Shield Slam augments.** The spell has no Wheel mapping at all. The row is named but
    no augment values are given, so there is nothing to implement yet.

## Tests

| File | Cases | What it proves |
|---|---|---|
| `tests/unit/players/wheel/knight_wheel_rework_test.cpp` | 9 | Battle Healing multiplies Shielding by 2, scales linearly, keeps both low-health tiers with inclusive boundaries, and is exactly ten times its old value; Combat Mastery's two-handed critical is 1000/1200/1400 by stage, nothing without the stage, two percent apart and ascending, above the old stage 1; a one-hander still takes the Defence branch and gets no critical |

**Not proven by tests:** the 2s healing group cooldown. Group cooldowns are applied by the
spell engine from the registered value; asserting the gate would need a live cast with a
clock, which no harness here provides. The registered values are the change, and they are
four one-line datapack edits visible in the diff.
