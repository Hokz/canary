# Global 2026 — Stage 7, lane 2: the damage-reduction pipeline order

Baseline: `main` at `f6b81a8`.

**`FIDELITY_BLOCKER — DAMAGE_REDUCTION_PIPELINE_ORDER` — CLOSED.**

This is the one Stage 7 lane that is an engineering problem rather than an evidence
problem. The order community evidence establishes — every resistance before armor, armor
before mitigation — was already known; what was missing was the work, and I had raised it
as non-local for two specific reasons. Both are addressed here.

## What the order was

| # | Layer | Where |
|---|---|---|
| 1 | creature resistance, Elemental Pierce, flat absorb, attacker's increase | `applyAbsorbDamageModifications` |
| 2 | immunity | `Creature::blockHit` |
| 3 | defense / block | `Creature::blockHit` |
| 4 | **armor** | `Creature::blockHit` |
| 5 | **mitigation** | `Creature::mitigateDamage` |
| 6 | **item + imbuement resistance** | `Player::blockHit`, after everything |
| 7 | **Wheel resistance** | `Player::blockHit`, after everything |

Layers 6 and 7 ran **last**, after armor had subtracted and mitigation had scaled.

## What it is now

Layers 6 and 7 move to position 2, behind a new virtual on `Creature`:

```
creature resistance  ->  equipment resistance  ->  immunity  ->  defense  ->  armor  ->  mitigation
```

`Creature::applyEquipmentResistances` is a no-op for anything that wears nothing;
`Player` overrides it with the body that used to sit at the end of `Player::blockHit`.
`Player::blockHit` now does nothing but delegate and send the attacker's square.

## Why the numbers change

A percentage applied before a flat subtraction is worth more than the same percentage
after it. That is the whole substance of the fix:

```
1000 damage, 100 armor, 70% fire resistance

resistance then armor (correct):  1000 -> 300, minus a roll of [50, 99]  =>  [201, 250] taken
armor then resistance (old):      1000 - [50, 99] -> 70% removed         =>  [270, 285] taken
```

Resistance against **mitigation** is a different matter: both are percentages, so their
product is the same either way and only integer rounding differs. The layer that mattered
was armor.

## The two obstacles, and what was done about them

### Item charges

The old code spent a charge inside the absorb loop, and the loop sat behind an early
return — so a charge was spent **exactly when neither defense nor armor had blocked the
hit**, including when the absorb itself took the damage to zero.

Running the resistances earlier means defense and armor have not happened yet, so that
condition cannot be read at the point the absorb applies. The items whose absorb applied
are therefore collected, and the charges are spent at the end under a
`blockedByDefenceOrArmor` flag that reproduces the original condition exactly.

The tempting shortcut — spend the charge if damage remains — is **wrong**, and was in the
first draft of this change: it would have quietly stopped charging fully absorbed hits,
which the old code did charge.

One divergence remains and is accepted: a hit that **mitigation** alone takes to zero now
spends a charge, where before mitigation ran first and the loop was skipped. Mitigation is
a percentage and can only reach zero on a hit that was already almost nothing.

### What the attacker is told

`onAttackedCreatureBlockHit` is called inside `Creature::blockHit`, before the player's
layers used to run. So when equipment resistance absorbed a hit completely, the old code
told the attacker **`BLOCK_NONE`** while returning **`BLOCK_ARMOR`** to the caller — the
two disagreed.

With the resistances ahead of the block determination, a fully absorbed hit sets
`BLOCK_ARMOR` before the callback, and the attacker is told the same thing the caller is.

**This is a behaviour change, not only a tidy-up.** `Player::onAttackedCreatureBlockHit`
drives `addAttackSkillPoint` and the blood-hit counter, so an attacker whose hit is fully
absorbed by resistance no longer banks an attack skill point. That is consistent with how
armor and defense already behave, and it is the inconsistency this closes — but it is a
real change to skill advancement and is called out here rather than buried.

## Tests

| File | Cases | What it proves |
|---|---|---|
| `tests/unit/players/damage_reduction_order_test.cpp` | 7 | the fixture's premises (armour is the only armour, mitigation is zero); the no-resistance control lands in [901, 950]; **the resistance applies before the armor**, landing at or below 250 where the old order could never go below 270; sixty-four rolls never reach the old order's range; the resistance is worth more than it used to be, as a comparison rather than a constant; a fully absorbed hit reports `BLOCK_ARMOR`; a damage type the item does not absorb is untouched |

The armor roll is random, which would normally make an ordering assertion impossible. The
fixture is chosen so the two orders land in **disjoint** ranges, which makes an upper bound
of 250 a deterministic proof that the resistance ran first, whatever the roll.

**Not proven by tests:** the interaction with imbuements specifically (the imbuement branch
needs an imbued item, which needs the imbuement registry), and charge consumption, which
needs `g_game().transformItem` and therefore a running game. The charge *condition* is the
part that was at risk, and it is stated in one flag in one place.
