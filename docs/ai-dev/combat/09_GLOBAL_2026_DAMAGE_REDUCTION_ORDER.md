# Global 2026 — Stage 7, lane 2: the damage-reduction pipeline order

Baseline: `main` at `f6b81a8`.

**`FIDELITY_BLOCKER — DAMAGE_REDUCTION_PIPELINE_ORDER` — CLOSED.**

This is the one Stage 7 lane that is an engineering problem rather than an evidence
problem. The order community evidence establishes — every resistance before armor, armor
before mitigation — was already known; what was missing was the work, and I had raised it
as non-local for two specific reasons. Both are addressed here, and so is a third that
only became visible once the order was actually moved: reordering the reduction
reclassifies hits, and every side effect keyed on the block type had to be decided again.

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

## Reordering damage also reclassifies hits

Moving the resistances ahead of defense and armor does more than change a number. Defense
and armor now decide against a **smaller** value than they used to, so some hits change
category. One class is new and is the reason this section exists.

### The resistance-assisted block

The resistance does **not** take the whole hit, but it takes enough of it that defense or
armor then does:

```
100 damage, 100 armor, 70% resistance, armor roll ∈ [50, 99]

before:  100 − roll        =>  [1, 50] taken. Armor did not stop it.
after:   100 → 30 − roll   =>  0 taken.       Armor stopped it.
```

Both halves are deterministic at these numbers, which is what makes the class testable:
armor can *never* finish 100 on its own, and can *never* fail to finish 30.

This is not a corner case. Melee weapons set both `blockedByArmor` and `blockedByShield`
(`weapons.cpp:238`), and real items carry `absorbpercentphysical` — 20%, 80% and 5% in
`data/items/items.xml` alone, before the Wheel's own physical resistance. Against any
defender wearing physical absorb, **most melee hits are in this class**.

### The contract

| | Follows | Why |
|---|---|---|
| damage | **new order** | the correction itself |
| caller `blockType` | **new order** | zero damage has to report a block, or `sendBlockEffect` draws a damage effect for a hit that dealt none |
| attacker's `onAttackedCreatureBlockHit` | **new order** | see below |
| `onBlockHit()` / Shielding | **new order** | the layer that really stopped the hit |
| item charges | **preserved** | see below |
| `blockCount` | **preserved** | decremented where it always was |

Four of those follow the new order and two are preserved, which is a split worth
justifying rather than asserting.

**What happened to the creature follows the corrected order.** The attacker's advance keys
on drawing blood: `BLOCK_NONE` reopens a thirty-hit window and grants a skill point, a block
spends one of it. That mechanic is well corroborated — a blood hit grants advancement "for
the next 30 combat moves", where a combat move is an attack made or a block attempted. Under
the corrected order a resistance-assisted hit deals **zero** damage, so no blood was drawn,
and telling the attacker `BLOCK_NONE` would bank a blood hit that never happened. The same
reasoning puts Shielding on the real blocking layer.

This means an earlier draft of this change was wrong in the opposite direction. It special-
cased the attacker so a fully absorbed hit still reported `BLOCK_NONE`, on the grounds of
preserving pre-move behaviour. That was preserving an artefact: the old answer was
`BLOCK_NONE` only because the resistances ran *after* the callback. The special case is
gone, and `resistanceAbsorbedAll` with it.

**Item charges are preserved, because they are an item economy rather than a combat
outcome.** The old absorb loop sat behind an early return, so a charge came out exactly
when nothing had already stopped the hit — and the hit it asked about was the **unreduced**
one, since the resistances ran last. A resistance-assisted hit therefore *did* cost a
charge before this change: armor had not stopped it. Gating on what actually happens now
would silently stop charging that whole class, making physical-absorb gear quietly cheaper
to run. So the charge rule reads a hypothetical:

```cpp
if (!defenceOrArmorWouldHaveStoppedTheUnreducedHit && !mitigationFinishedTheHit) {
```

| Outcome | Charge spent? | Why |
|---|---|---|
| immunity | no | the list is never populated |
| defense or armor would have stopped the **unreduced** hit | no | the old early return skipped the loop |
| mitigation alone finished it | no | `mitigationFinishedTheHit` |
| resistance-assisted block | **yes** | armor would not have stopped the unreduced hit |
| the resistance took the whole hit, armor would not have | **yes** | nothing else was going to stop it |
| the hit landed | **yes** | unchanged |

Two earlier drafts got this table wrong in both directions — first gating on "damage
remains", which would have stopped charging fully absorbed hits; then dropping the
mitigation condition, which started charging mitigated ones; and then gating on
`blockedByDefenceOrArmor`, which stopped charging the entire resistance-assisted class.

### One roll per layer

The hypothetical needs to know whether defense and armor would have stopped the unreduced
hit, and **armor is a random roll**. Rolling a second time to answer that would make the
real hit and its classification disagree by luck, which would turn the charge rule into a
coin flip.

So each layer is rolled exactly once, up front, and `runDefenceAndArmor` — a local lambda
that sequences defense then armor with the rolls already fixed — is run twice over the same
two numbers: once on the real post-resistance damage, once on the unreduced value for
classification only. The second run cannot touch the damage the defender takes; its result
feeds one boolean.

One deliberate difference in RNG consumption: the armor roll is now drawn whenever
`checkArmor` holds, where the old sequential flow skipped it if defense had already blocked.
That is one extra uniform draw on defense-blocked hits, and nothing depends on the stream.

### What is preserved

  - **`blockCount`** is decremented at the point it always was — before the resistances,
    which now run ahead of defense and armor. A resistance swallowing the hit does not hand
    the defender its block back.
  - **The defender's Shielding rule itself** is unchanged: defense or armor stopping the hit
    advances it. Only *which hits qualify* moved, and it moved in both directions — a hit a
    resistance swallows outright no longer advances Shielding, and a resistance-assisted
    block now does.
  - Whether Global grants the attacker its skill point on a hit its target's resistance
    swallowed is **FIDELITY_PENDING_EVIDENCE**. No source addresses engine-internal block
    classification; the contract above is derived from the corrected order plus the
    corroborated blood-hit mechanic.

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

`tests/unit/players/damage_reduction_order_test.cpp`, **20 cases**.

**The ordering itself** — a minimal Player survives the whole chain; the fixture's premises
(the armour slot is the only armour, mitigation is zero); the no-resistance control lands in
[901, 950]; the resistance applies before the armor, at or below 250 where the old order
could never go below 270; sixty-four rolls never reach the old order's range; the resistance
is worth more than it used to be; a reduced hit that still lands reports no block; a damage
type the item does not absorb is untouched and charges nothing.

**The resistance-assisted class** — armor alone cannot stop a hit of 100; the resistance
lets armor finish it; the attacker is told `BLOCK_ARMOR`, because no blood was drawn;
Shielding advances, observed; the charge is still spent.

**A resistance that takes the whole hit** — the caller and the attacker are both told
`BLOCK_ARMOR`; Shielding does **not** advance, observed; no charge when armor would have
stopped the hit anyway, and a charge when it would not.

**No regression** — an ordinary armor block with no resistance involved still blocks,
still advances Shielding and still charges nothing; a hit mitigation finishes spends no
charge, with a landing hit as its control.

The armor roll is random, which would normally make these assertions impossible. Every case
above is built on a pair of **disjoint** ranges — 1000 damage separates the two orders at
250 against 270, and 100 damage separates "armor cannot finish this" from "armor always
finishes this" — so each assertion holds for every roll rather than for most of them.

### Two test seams

`Creature` gained two hooks in the `setTest`/`getTest` convention this repository already
uses on `Player`. Both exist because a decision this lane had to get right was otherwise
unobservable, and production reads neither.

  - **`setTestBlockCount`**. `blockCount` only ever accrues in `Creature::onThink`, so
    `hasDefense` is false for any creature a fixture builds and `onBlockHit()` could never
    fire — which meant the Shielding rule could not be tested at all, not even with a
    positive control. `Player` is `final`, so a test-double cannot override `onBlockHit()`
    either. With the hook, Shielding is read back through `getSkillPercent(SKILL_SHIELD)`:
    a new Player sits at level 10 with zero tries and a vocation's shield base is 100 tries
    for level 11, so one advance moves it from 0.00% to exactly 1.00%.
  - **`didTestSpendResistanceCharges`**. Spending a charge goes through
    `g_game().transformItem`, which returns early on an item with no parent and therefore
    cannot be observed through the item in a unit test. `blockHit` records the *decision* —
    whether the resistances' charges were spent — and the tests read that. It is the rule
    that was at risk here, and it was got wrong three times before this.

**Still not proven by tests:** the imbuement branch specifically, which needs the imbuement
registry; and the `transformItem` call itself, as opposed to the decision to make it.
