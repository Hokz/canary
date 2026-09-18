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

The loop, however, accumulated each tier's **full threshold** instead of its **width**, so
it agreed with the progression its own comment described only while no tier had completed:

| level | the documented progression | the loop returned |
|---|---|---|
| 500 | 100 | 100 |
| 1000 | 184 | 184 |
| **1100** | **200** | **284** |
| **2000** | **325** | **566** |
| **8000** | **893** | **2873** |

Every character above level 1100 had an inflated flat damage and healing bonus, and so did
Shield Bash and Shield Slam, which read this value. The closed form replaces the loop.

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
| `tests/unit/players/flat_damage_healing_test.cpp` | 6 | the closed form at seventeen levels; every completed tier worth exactly 100 at the tier boundaries; the high-level runaway named (200 not 284, 325 not 566, 892 not 2873); never decreasing across 4000 levels; the first tier equals the old `level / 5`; level 1 gives nothing and an absurd level does not wrap |
| `tests/lua/test_knight_healing_formulas.lua` | 19 | twelve exact min/max pairs across three (level contribution, Shielding, Magic Level) points for all four spells; all four have coefficients; the official Base Powers; the two corroborated ML pairs; Shielding raises the heal through its own coefficient only; the two bigger spells count the level contribution twice; an unknown spell is refused rather than healing nothing; max is never below min |

The expected numbers are hand-computed from the documented shape, not recomputed from the
table — a test that re-derives the formula it checks proves only that Lua multiplies.

**Not proven by tests:** that these are the numbers Global produces. That needs measurements
at known level, magic level and Shielding, which is the remaining evidence task. The
Shielding column is the part to measure first; everything else now has at least two
independent sources.
