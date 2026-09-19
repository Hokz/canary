# Global 2026 — Stage 7: Knight healing, and the level contribution behind it

Baseline: `ddef9c1` (PR #52's head — this lane touches the same four healing scripts, so
it stacks on that PR rather than conflicting with it).

Stage 2 routed Knight heal scaling to Stage 7 because the Shielding coefficients were not
published. Research supplied a concrete public 15.25 implementation to work from, and
auditing it against this repository turned up more than expected.

## What the audit found

### 1. We already had the level contribution — with a bug

`Player::calculateFlatDamageHealing` walked a tiered progression: levels 0..500 at 1/5, the
next 600 at 1/6, the next 700 at 1/7, and so on. Every completed tier is therefore worth
exactly 100.

The research's `B(L)`:

```
S = floor((sqrt(2L + 2025) + 5) / 10)
B = floor((L + 1000) / S) + 50 * S - 450
```

is the **closed form of exactly that progression** — it reproduces it at every level, with
zero mismatches across the whole range.

The loop, however, had **two separate faults**.

**Fault A — the partial tier was rounded up.** The progression floors it; the loop used
`ceil`. That made it one too high across most of the first tier:

| level | progression | the loop returned |
|---|---|---|
| 8 | 1 | 2 |
| 18 | 3 | 4 |
| 499 | 99 | 100 |

**Fault B — completed tiers were accumulated by threshold, not by width.** Above the
first tier this ran away:

| level | progression | the loop returned |
|---|---|---|
| 1000 | 183 | 184 |
| **1100** | **200** | **284** |
| **2000** | **325** | **566** |
| **8000** | **892** | **2873** |

Every character above level 1100 had an inflated flat damage and healing bonus, and so
did Shield Bash and Shield Slam, which read this value. Fault A is a one-point difference;
fault B reaches more than three times the correct value.

**This makes `B(L)` far better evidenced than the research expected.** It rests on two
independent legs: a public 15.25 implementation arrived at it, and it is the exact closed
form of a progression this engine already documented. A third, smaller corroboration: the
`level * 0.2` that every pre-15.25 healing formula in this datapack used is `B(L)`'s first
tier.

### 2. Two of the four Magic Level pairs were already ours

| Spell | what this datapack had | the reference | verdict |
|---|---|---|---|
| Bruise Bane | ML × 1.795, max = min + 5 | ML × 0.9, max = min + 5 | differs |
| Wound Cleansing | 4.0 / 7.95 | 4.0 / 7.95 | **identical** |
| Fair Wound Cleansing | 8.0 / 15.9 (as ×2 of the above) | 8.0 / 15.9 | **identical** |
| Intense Wound Cleansing | 70 / 92 | 20 / 40 | differs |

Two exact matches, arrived at independently, is meaningful corroboration of the
reference's Magic Level column. It says nothing about the Shielding column.

## What changed

`data/libs/functions/knight_healing.lua` holds the whole mechanic — one table, four
spells, every coefficient in it:

```
common = B(level) * levels + Shielding * shield + basePower
min    = common + MagicLevel * mlMin
max    = common + MagicLevel * mlMax      (or min + flatSpread)
```

| Spell | Base Power | levels | shield | ML min | ML max |
|---|---|---|---|---|---|
| Bruise Bane | 15 | 1 | 0.3 | 0.9 | min + 5 |
| Wound Cleansing | 70 | 1 | 1.0 | 4.0 | 7.95 |
| Fair Wound Cleansing | 225 | 2 | 2.5 | 8.0 | 15.9 |
| Intense Wound Cleansing | 500 | 2 | 5.0 | 20.0 | 40.0 |

Each spell script is now three lines that name its spell and nothing else. Shielding is
read as the **effective** skill, so a Protector stance and equipment both count — the same
source every other 15.25 skill consumer uses.

## Confidence, per value

Stated separately because they are not equally proven, and the governance rule is that a
community-derived constant must never be presented as official:

| Value | Status |
|---|---|
| Base Powers 15 / 70 / 225 / 500 | **VERIFIED_OFFICIAL** — named in CipSoft's 15.25 vocation adjustments |
| "scales with Magic Level + Shielding" | **VERIFIED_OFFICIAL** — stated by CipSoft |
| `B(L)` level contribution | **VERIFIED** — closed form of the progression this engine documents, independently matched |
| Wound Cleansing and Fair ML pairs | **CORROBORATED** — this datapack already carried them |
| Bruise Bane and Intense ML pairs | **COMMUNITY_DERIVED_TUNABLE** — reference implementation only |
| **Shielding coefficients 0.3 / 1.0 / 2.5 / 5.0** | **COMMUNITY_DERIVED_TUNABLE** — *not* published by CipSoft. A strong lead, not a Global constant. |

The Shielding coefficients live in one table in one file. Retuning them is one edit, and
the tests that pin them are in one file too.

## Tests

| File | Cases | What it proves |
|---|---|---|
| `tests/unit/players/flat_damage_healing_test.cpp` | 9 | the closed form at twenty-four levels, covering every step transition on both sides (499/500/501, 1099/1100/1101, 1799/1800/1801, 2600/2601) and level 5; the step changing exactly at each boundary; every completed tier worth exactly 100; the high-level runaway named (200 not 284, 325 not 566, 892 not 2873); never decreasing across **every** level from 1 to 10000; the first tier equals the old `level / 5`; level 1 gives nothing; and the clamp holding at the exact overflow threshold |
| `tests/lua/test_knight_healing_formulas.lua` | 24 | twelve exact min/max pairs across three (level contribution, Shielding, Magic Level) points for all four spells; all four have coefficients; the official Base Powers; the two corroborated ML pairs; Shielding raises the heal through its own coefficient only; the two bigger spells count the level contribution twice; an unknown spell is refused rather than healing nothing; max is never below min |

The expected numbers are hand-computed from the documented shape, not recomputed from the
table — a test that re-derives the formula it checks proves only that Lua multiplies.

## The clamp

The return type is `uint16_t`, so the value is clamped rather than allowed to wrap.
Unclamped, `B(L)` first exceeds 65535 at **level 21,769,760**:

| level | unclamped | returned |
|---|---|---|
| 21,769,759 | 65535 | 65535 |
| 21,769,760 | 65536 | 65535 (clamped) |
| 4,294,967,295 (`UINT32_MAX`) | 926369 | 65535 (clamped) |

The intermediate arithmetic is `int64_t`, and the largest intermediate at `UINT32_MAX` is
about 4.29e9 — nowhere near overflow. **No production bug here**; the clamp and the widths
are correct, and the test now proves it at the threshold rather than at level 100000, where
`B(L)` is only 4044 and nothing is near the cap.

## Every consumer of the level contribution

Twenty spells, one heal mechanic and the client's own stat display read it. All of them are
15.25 formulas that should carry the corrected value, so **every impact below is intended**
and no caller needed changing:

| Consumer | Kind | Impact |
|---|---|---|
| 16 attack spells — the whole Monk kit (`double_jab`, `swift_jab`, `tiger_clash`, `greater_tiger_clash`, `flurry_of_blows`, `greater_flurry_of_blows`, `forceful_uppercut`, `devastating_knockout`, `sweeping_takedown`, `thousand_fist_blows`, `chained_penance`, `spiritual_outburst`, `mystic_repulse`), plus `shield_bash`, `shield_slam`, `ethereal_barrage` | DAMAGE_FORMULA | EXPECTED_TO_CHANGE_WITH_B_L |
| the four Knight heals, via `knight_healing.lua` | HEALING_FORMULA | EXPECTED_TO_CHANGE_WITH_B_L |
| `Combat::harmonyHeal` — the Monk Harmony heal | HEALING_FORMULA | EXPECTED_TO_CHANGE_WITH_B_L |
| `protocolgame.cpp` (two sites) | DISPLAY_ONLY | the client now shows the corrected bonus |
| `player_functions.cpp` | OTHER | the Lua binding itself |

Worth stating because it was checked rather than assumed: `Combat::harmonyHeal` is the
**only** engine-side consumer that feeds damage or healing. There is no blanket flat bonus
added to every spell, so a spell script that adds the contribution itself is not applying
it twice.

**Not proven by tests:** that these are the numbers Global produces. That needs measurements
at known level, magic level and Shielding, which is the remaining evidence task. The
Shielding column is the part to measure first; everything else now has at least two
independent sources.
