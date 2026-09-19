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

Layers 6 and 7 move behind a new virtual on `Creature`, ahead of defense and armor:

```
creature resistance  ->  immunity  ->  equipment resistance  ->  defense  ->  armor  ->  mitigation
```

**Immunity stays first of all.** It zeroes the damage outright, so nothing after it can
matter, and that was already its place. An earlier draft of this document listed immunity
after the equipment resistances, which never matched the code.

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
return — so a charge was spent **exactly when nothing had already stopped the hit**:
immunity, defense, armor and mitigation all skipped it, because all four ran before it.

Running the resistances earlier means none of those have happened yet when the absorb
applies. The items are therefore collected and charged at the end, after mitigation, under
the same three conditions:

| Outcome | Charge spent? | Why |
|---|---|---|
| immunity | no | the list is never populated |
| defense or armor stopped it | no | `blockedByDefenceOrArmor` |
| mitigation alone finished it | no | `mitigationFinishedTheHit` |
| the resistance itself took the whole hit | **yes** | the charge came out inside the loop before this moved, and the loop had run |
| the hit landed | **yes** | unchanged |

An earlier draft of this change got the last two rows wrong in both directions. It first
gated on "damage remains", which would have **stopped charging fully absorbed hits** — the
one case the old code definitely did charge. It then dropped the mitigation condition, which
**started charging hits mitigation alone finished** — a case the old code definitely did
not. Both are now explicit flags rather than inferences from an overloaded `BLOCK_ARMOR`.

### What the attacker is told, and what the defender advances

`onAttackedCreatureBlockHit` is called inside `Creature::blockHit`, before the player's
layers used to run. So when equipment resistance absorbed a hit completely, the old code
told the attacker **`BLOCK_NONE`** while returning **`BLOCK_ARMOR`** to the caller.

An earlier draft of this change let the two agree. That was the wrong call:
`Player::onAttackedCreatureBlockHit` drives `addAttackSkillPoint`, so agreeing would have
**silently stopped an attacker banking a skill point** when the defender's resistance ate
the hit. This is a damage-order correction; progression is not its business.

So the notification is now held at its pre-move answer explicitly:

```cpp
attacker->onAttackedCreatureBlockHit(resistanceAbsorbedAll ? BLOCK_NONE : blockType);
```

The caller still receives `BLOCK_ARMOR`. The two answers differ on purpose, and the
`resistanceAbsorbedAll` flag is what makes that difference legible instead of riding on an
overloaded `BLOCK_ARMOR`. Whether Global itself grants the skill point is
**FIDELITY_PENDING_EVIDENCE**; preserving current behaviour is the defensible default.

The same reasoning covers the defender:

  - **`blockCount`** is decremented at the point it always was — before the resistances,
    which now run ahead of defense and armor. A resistance swallowing the hit does not
    hand the defender its block back.
  - **`onBlockHit()`**, which advances Shielding, is gated on `blockedByDefenceOrArmor`. A
    block by defense or armor advances it, exactly as before. A resistance absorbing
    everything is not a block by either layer, so it does not advance it. That one is a
    change rather than a preservation, and the next section states and accepts it.

### The one defender-side delta, accepted

Armor and defense now see the damage the resistances already reduced. That has a
consequence worth stating rather than discovering:

**A small hit that a resistance swallows outright no longer advances the defender's
Shielding.** Before the reorder it reached armor at full strength, armor stopped it, and
`onBlockHit()` fired. Now it never reaches armor. Against an element the defender resists
heavily, Shielding trains a little more slowly.

This is accepted rather than preserved. The block determination inherently sees the reduced
damage once the resistances come first — preserving the old answer would mean running armor
twice, or on a number the defender never took. And semantically, a resistance absorbing
damage is the armour's elemental protection working, not the shield, which is what
Shielding measures.

**Structurally enforced, not directly covered.** The gate is the two-line
`if (hasDefense && blockedByDefenceOrArmor)` in `Creature::blockHit`, and nothing in the
unit suite observes `onBlockHit()` itself. `AResistanceSwallowingTheHitIsNotABlock` proves
only what its assertions say - the absorb takes the whole hit and the caller is told
`BLOCK_ARMOR` - which is the input side of the gate, not its effect.

Observing the effect is out of reach of this fixture, for two concrete reasons worth
recording so the next attempt does not rediscover them. `Player` is `final`
(`player.hpp:129`), so no test-double can override `onBlockHit()`. And `Creature::blockCount`
starts at zero and only accrues in `Creature::onThink` (`creature.cpp:144`), so `hasDefense`
is false for every call this fixture makes and `onBlockHit()` never fires here at all -
including on a hit that armor does stop, which means even a positive control would prove
nothing. A test that genuinely covered this would have to drive `blockCount` through
`onThink`, prime `shieldBlockCount` via `onAttackedCreatureBlockHit(BLOCK_NONE)`, equip a
shield so `hasShield()` holds, and read the advance back through
`getSkillPercent(SKILL_SHIELD)`. That is integration-shaped work, and it is deliberately not
claimed here.

### The fixture crash this lane cost a day to

Six tests in this file segfaulted, and the cause was neither the ordering nor production
code. `blockHit`'s first branch is `isImmune`; `Player::isImmune` asks `hasFlag`; and
`Player::hasFlag` dereferences `group` unconditionally (`player.cpp:7882`) while
`Player::group` defaults to `nullptr`. A Player that has not been through `IOLoginData`
cannot answer a flag.

Only the one test that never called `blockHit` passed, which is what made it look like an
ordering problem. Fixed in the fixture with an empty `Group` — the pattern the repository
already uses — rather than with a null check, because production always assigns a group and
guarding `hasFlag` would hide the next fixture that forgets.

## Tests

| File | Cases | What it proves |
|---|---|---|
| `tests/unit/players/damage_reduction_order_test.cpp` | 11 | a minimal Player survives the whole chain; the fixture's premises; the no-resistance control lands in [901, 950]; **the resistance applies before the armor**, at or below 250 where the old order could never go below 270; sixty-four rolls never reach the old order's range; the resistance is worth more than it used to be; a reduced hit that still lands reports no block; a resistance swallowing the hit still reports `BLOCK_ARMOR` to the caller (the input side of the Shielding gate - the gate's effect is structurally enforced, not covered, see above); a fully absorbed hit reports `BLOCK_ARMOR` to the caller and `BLOCK_NONE` to the attacker, so no skill point is lost; a damage type the item does not absorb is untouched |

The armor roll is random, which would normally make an ordering assertion impossible. The
fixture is chosen so the two orders land in **disjoint** ranges, which makes an upper bound
of 250 a deterministic proof that the resistance ran first, whatever the roll.

**Not proven by tests**, stated here rather than left to be discovered:

  - **The imbuement branch specifically.** It needs an imbued item, which needs the
    imbuement registry.
  - **Charge consumption.** It needs `g_game().transformItem`, and therefore a running
    game. The charge *condition* is the part that was at risk, and it is two flags read in
    one place — `!blockedByDefenceOrArmor && !mitigationFinishedTheHit` — rather than a
    rule spread across the function.
  - **The Shielding gate's effect.** `onBlockHit()` is never reached from this fixture at
    all, for the reasons given above; only the value it is gated on is asserted.
