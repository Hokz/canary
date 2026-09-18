# Global 2026 — Effective Skill, Tactics, Effective Item Values and Mitigation Inputs

**NOT MERGED. NOT AUTHORIZED TO MERGE.**

This lane changes the foundation the 15.25 combat model stands on: what a percentage of a
skill is a percentage *of*, whether Attack / Balanced / Defense still weigh anything, and
where the update's global equipment compensation lives. It deliberately stops short of the
full CipSoft mitigation reformulation, because that formula is not proven coefficient by
coefficient — see **E**.

## A. Preflight

| Check | Result |
|---|---|
| PR #49 merged | yes, merge commit `25049b3265e46919db8573551bf16e0424290f7f` |
| `main` contains it | yes, `main` is that commit |
| Post-merge CI on `main` | green — CI run `35269391642`, Repository Audit run `35269391100` |
| PR #48 untouched | yes, still open at `f59c77afdaf6a17f5d04e0a29c58736717d11883` |
| Base of this branch | `ai-dev/combat-tactics-effective-stats-15250-01`, created from `25049b3` |

## B. Fight-mode dependency map

Every place `fightMode` reaches, and what it is now.

| Where | Old effect | New effect | Kind |
|---|---|---|---|
| `ProtocolGame::parseFightModes` / `sendFightModes` | reads/writes the byte, or omits it for the current profile | unchanged | protocol only |
| `Game::playerSetFightModes`, `Player::setFightMode`, `Player::fightMode` | stores the mode | unchanged | state only |
| `PlayerFunctions::luaPlayerGetFightMode`, `registerEnum(FIGHTMODE_*)` | exposes the mode to Lua | unchanged | scripting |
| `Player::getAttackFactor` | 1.0 / 0.75 / 0.5 | **1.0 always** on the modern model; legacy profiles keep the triple | combat math |
| `Player::getDefenseFactor` | 0.5 / 0.75 / 1.0 (with the attack-speed branch) | **1.0 always** on the modern model; legacy unchanged | combat math |
| `Player::getDefense`, `defenseSkill == 0` branch | returns 1 or 2 by mode | **1** on the modern model; legacy unchanged | combat math |
| `Player::attackTotal` | equipment x 1.2 / 1.0 / 0.6 | **equipment x 1.0** on the modern model; legacy unchanged | combat math |
| `PlayerWheel::calculateMitigation` | fightFactor 0.8 / 1.0 / 1.2 | **no fight factor** on the modern model; legacy unchanged | combat math |
| `Player::getCombatTacticsMitigation` | 0.8 / 1.0 / 1.2 | **deleted** — it had no caller | dead code |

`Player::usesModernCombatModel()` is the single predicate: the connected client's protocol
profile has `ProtocolFeature::TacticsWithoutFightMode` (the `"current"` 15.25 profile does;
Tibia 11.00 and the 8.60 profiles do not). A player with no client — a unit test, a player
mid-login — is on the modern model. The two models never mix on one player: a legacy client
gets the pre-15.25 attack factor, defence factor, attack total, mitigation weighting **and**
raw item values, all together.

`FightMode_t` itself, its protocol bytes and its Lua enum were not touched. Removing the
indicators from the modern client's UI needs verified packet evidence this repository does
not have — see **J**.

## C. Effective skill design

### The problem

`ConditionAttributes::updatePercentSkills` computed a percent recipe from
`Player::getBaseSkill` — the raw trained skill, equipment excluded. The 15.25 stances scale
from the *total* skill. The obvious fix, reading `getSkillLevel`, is the trap the brief names:
`getSkillLevel` already contains the flat value the recipe itself put on the player through
`varSkills`, so every re-derivation would compound (100 → 130 → 169 → 219).

### The aggregation

```
trained skill (skills[].level)
  + loyalty
  + varSkills            <- equipment, imbuements, flat condition recipes, AND percent-derived values
  + Wheel additions
  + Weapon Proficiency skill bonus
  = getSkillLevel                       (what combat uses)

  ... the same pipeline with (varSkills - varSkillsFromPercent)
  = getSkillLevelForPercentScaling      (what a percent recipe scales from)
```

`Player::varSkillsFromPercent` is a second array tracking exactly the part of `varSkills`
that percent recipes contributed. `addPercentDerivedSkill` writes both; `setVarSkill` — every
other source — writes only `varSkills`. Subtracting one from the other is the whole
non-recursion argument: the source a recipe reads can never contain a recipe's output, its
own or anyone else's.

**Counted as source:** trained skill, loyalty, equipment, imbuements, flat condition recipes,
Wheel skill stats, Weapon Proficiency skill bonuses.
**Excluded:** every percent-derived value, without exception.

### Idempotence

`ConditionAttributes::reapplyPercentSkills` computes what the recipe *should* have on the
player right now, compares it with what it *does* have (`skillsFromPercentApplied`) and moves
the difference. Applying it any number of times is therefore a no-op after the first. It runs
on `startCondition`, on a merge, on `endCondition` (retiring the recipe), and from
`Player::refreshPercentSkillRecipes` whenever a non-percent source changes.

**Every source has to announce itself, and two of them do not go through `setVarSkill`:**

| Source | How it reaches the skill | What asks for the re-derivation |
|---|---|---|
| equipment, imbuements, flat condition recipes, item decay | `Player::setVarSkill` | `setVarSkill` itself |
| training | `Player::addSkillAdvance` | the advance, per level gained |
| Weapon Proficiency | `WeaponProficiency::m_skills`, written directly | `addSkillBonus` and `resetSkillBonuses` |
| Wheel skill stats | `PlayerWheel::m_stats`, written directly | `addStat` and `resetStats` |
| Wheel conditional bonuses, on login or a Wheel reload | instants and major stats settled by a whole bonus-data pass | the end of `PlayerWheel::registerPlayerBonusData` |
| Wheel conditional bonuses, **while playing** (`getMajorStatConditional`) | `PlayerWheel::m_majorStats`, moved on and off by `onThink` | `applyConditionalMajorStat` marks it, `flushConditionalSkillSources` acts on it |

The component arrays are the ones that would silently go stale: the bonus lands in the
skill the player has while the percentage keeps scaling from the skill he had before it, until
some later, unrelated `setVarSkill` corrects it. `AProficiencyBonusGainedWhileTheStanceIsOnRecalculatesAtOnce`
and `AWheelSkillStatGainedWhileTheStanceIsOnRecalculatesAtOnce` exercise exactly that order —
stance first, source second — because the reverse order passes either way.

### The dynamic conditional bonuses

Positional Tactics (+3 Distance with no monster adjacent) and Battle Instinct (+6 Shielding per
adjacent monster beyond the fourth) are not stored skill stats. They are major stats that
`Player::computeSkillLevel` reads back through `getMajorStatConditional`, moved on and off by
`PlayerWheel::onThink` several times a minute. They are a skill source like any other, and the
first round of this work reached only the login and reload pass — while playing, a stance stayed
frozen at whatever the source was when it was cast.

Four major stats, and only four, reach a skill: `DISTANCE` (Positional Tactics → `SKILL_DISTANCE`),
`SHIELD` (Battle Instinct → `SKILL_SHIELD`), `CRITICAL_DMG` (Ballistic Mastery) and `CRITICAL_DMG_2`
(Combat Mastery), both → `SKILL_CRITICAL_HIT_DAMAGE`. `MELEE` looks like one and is not: the melee
skills read `WheelStat_t::MELEE`, a static stat. `DEFENSE`, `DAMAGE`, `PHYSICAL_DMG`, `HOLY_DMG`,
`MAGIC` and `HOLY_RESISTANCE` feed damage, defence or a resistance and no skill at all.
`PlayerWheel::majorStatFeedsEffectiveSkill` is that list, and it has to be kept in step with
`computeSkillLevel`.

The invalidation is deliberately not a hook on `setMajorStat`, which would re-derive on every tick
that moves a damage bonus. Instead every conditional ability writes through
`applyConditionalMajorStat`, which marks the recipes stale only when the value actually moved *and*
what moved feeds a skill; `flushConditionalSkillSources` then re-derives **once** at the end of the
evaluation — `onThink` (both its normal path and its leave-combat reset) and `checkAbilities`. It
uses `Player::rederivePercentSkillRecipes`, the variant that does not send, because those two
callers send one skills payload themselves once they know the whole outcome.

`checkBattleInstinct` and `checkPositionalTactics` now do the counting only and hand the rule to
`applyBattleInstinct` / `applyPositionalTactics`. The counting needs a map; the rule does not, so
the regression tests drive the real mutation path without one.

Two recipes on the same skill read the same source, so they add and the order they arrive in
does not change the result: 100 with +30% and +20% is 150, never 100 × 1.3 × 1.2.

Within one condition the flat recipe lands **before** its percentage is derived, so a condition
carrying both counts its own flat bonus as a source for its own percentage. Deriving first and
applying the flat afterwards left the percentage computed against the smaller skill until the
next unrelated refresh silently corrected it — a value that depended on when you looked. CI
caught this: `AConditionsOwnFlatRecipeCountsTowardsItsOwnPercentage` now pins it, and the
ordering is the same in `startCondition` and in the merge path.

### Persistence

The condition blob saves the **recipe**, never the value it produced. `skills[]` now holds the
flat recipe only. A blob written before this change kept the derived value in that same slot,
so `CONDITIONATTR_PERCENT_RECIPES_SEPARATE` marks the new format and a blob without it has its
flat value dropped for any skill that also carries a percentage — otherwise every existing
player with a stance would log in with the bonus counted twice.

## D. Effective item value design

`src/creatures/combat/effective_combat_values.hpp` holds the three percentages and nothing
else: weapon Attack ×1.20, shield Defence ×1.30, spellbook Defence ×1.60. Raw item data is
untouched — `Item::getAttack` and `Item::getDefense` still answer exactly what `items.xml`
says, which is what the market, item descriptions and serialisation read.

| Layer | Accessor |
|---|---|
| raw | `Item::getAttack()`, `Item::getDefense()` |
| effective | `Player::getEffectiveWeaponAttackValue(raw)`, `Player::getEffectiveOffhandDefense(item)`, `Player::getEffectiveShieldDefense()` |
| consumers | the weapon damage formulas, `Player::getDefense`, `Player::getDefenseEquipment`, `PlayerWheel::calculateMitigation`, the client stat payloads, `Player:getEffectiveShieldDefense` in Lua |

Each consumer takes the value from the Player, so the percentage is applied exactly once.
`EffectiveCombatValues::scaled` returns `double`; the fraction survives into whatever formula
consumes it and only that formula's own rounding applies. Where an integer is needed before
then — `getDefenseEquipment`, the wire fields, `getEffectiveShieldDefense` — `toInteger`
rounds half away from zero, and it is the only place that rounds.

**What is compensated:** an item's Attack, a weapon's elemental attack, ammunition and bow
attack, a shield's Defence, a spellbook's Defence.
**What is not:** the bare-fist constant 7 (no item), the Weapon Proficiency flat
`ATTACK_DAMAGE` (its own layer, added after), spell and rune damage (no weapon attack value in
them at all), a quiver's or any other off-hand item's Defence, monster values.

### Shield vs spellbook

`ItemParse::parseWeaponType` compared the attribute's **key** against `"spellbook"` instead of
its **value**, so `ItemType::spellbook` was never set for any item and all 21 spellbooks in
`items.xml` counted as plain shields. That is fixed here; it is a prerequisite, because the two
now take different percentages. The fix also reaches `PlayerWheel::calculateMitigation`, whose
`shield->isSpellBook()` branch (vocation `mitigationSecondaryShield` instead of
`mitigationPrimaryShield`) had been unreachable for the same reason.

### Shield Bash / Shield Slam

`Player:getEquippedShieldDefense` in Lua now delegates to `Player::getEffectiveShieldDefense`,
so the spells scale from the same compensated number as normal shield combat and no script
applies the 30% a second time. The damage *formula* remains the inference PR #49 marked —
`FIDELITY_BLOCKER — FORMULA_EVIDENCE_REQUIRED` is unchanged and untouched by this lane.

## E. Mitigation matrix

| Component | Current Canary behaviour | 15.25 evidence | Proven replacement? | Implemented? | Blocker |
|---|---|---|---|---|---|
| Fight-mode factor | 0.8 / 1.0 / 1.2 | tactics removed from the modern client | yes — the mode no longer exists to weigh | **yes**, modern path only | — |
| Shield Defence input | raw `shield->getDefense()` | shield Defence +30% | yes — the compensation is published | **yes**, via `getEffectiveOffhandDefense` | — |
| Spellbook Defence input | raw, and misclassified as a shield | spellbook Defence +60% | yes | **yes**, classification fixed and value compensated | — |
| Vocation `mitigationFactor` (shielding weight) | per-vocation, `data/XML/vocations.xml` | not published | no | unchanged | `MITIGATION_FIDELITY_PENDING_EVIDENCE` |
| Vocation `mitigationPrimaryShield` / `mitigationSecondaryShield` | per-vocation | not published | no | unchanged | `MITIGATION_FIDELITY_PENDING_EVIDENCE` |
| Weapon type coefficient | not modelled separately | not published | no | not added | `MITIGATION_FIDELITY_PENDING_EVIDENCE` |
| 1H vs 2H | two-handed replaces the defence value and uses the secondary factor | not published | no | unchanged | `MITIGATION_FIDELITY_PENDING_EVIDENCE` |
| Bow / crossbow contribution | ammo type switches to the secondary factor | not published | no | unchanged | `MITIGATION_FIDELITY_PENDING_EVIDENCE` |
| Armour | not part of the player mitigation formula | not published | no | unchanged | `MITIGATION_FIDELITY_PENDING_EVIDENCE` |
| Wheel Dedication | `MITIGATION_INCREASE 0.075` per point | accepted by the project | yes | unchanged, as accepted | — |
| Lesser Gems | base `2000` × grade `1.0/1.1/1.2/1.5` = 20/22/24/30% | accepted by the project | yes | unchanged, as accepted | — |
| Monster mitigation | `Monster::getMitigation`, capped at 30 | not published | no | **untouched** | `MITIGATION_FIDELITY_PENDING_EVIDENCE` |
| Caps / rounding | `ceil(x*100)/100`, no cap on players | not published | no | unchanged | `MITIGATION_FIDELITY_PENDING_EVIDENCE` |

The data flow is explicit and single-pass:

```
raw item defence -> effective item defence (x1.30 or x1.60, once)
                 -> mitigation formula input
                 -> mitigation output (then the Wheel multiplier, once)
```

No coefficient was invented. Status: **`PROVEN_COMBAT_LAYER_COMPLETE_MITIGATION_FIDELITY_PENDING_EVIDENCE`**.

## F. Legacy spell migration

`data/scripts/spells/support/sap_strength.lua` and `expose_weakness.lua` are deleted: the
modern design applies those debuffs through the Crippling Aura stances PR #49 introduced, and
keeping a second, directly castable source of the same effect would be two mechanics doing one
job. Every NPC path that taught them is gone with them — 8 NPCs (`barnabas_dee`, `gundralph`,
`malunga`, `myra`, `romir`, `shalmar`, `tamoril`, `tothdral`), each losing two teaching nodes,
two level-menu entries, and the levels 175 and 275 from its level list; `gundralph` and
`shalmar` also named them in their attack-spell listing.

**Preserved:** the debuffs themselves. `CripplingAura::sappedStrength()` and
`exposedWeakness()` (`src/creatures/combat/crippling_aura.cpp`) are the engine-side
implementation the auras use, and they are untouched. The two aura scripts keep their
behaviour; only their header notes changed, because they claimed the old scripts were left in
place and that is no longer true.

**One Wheel reference had to follow.** `src/io/io_wheel.cpp` named "Sap Strength" in three
places — the Sorcerer spell table and the two 100-point slot grants. See **J**: the dead name
fails the build, and no evidenced replacement exists, so the slot now grants no spell and the
mapping is an open blocker rather than a guess.

**Player impact, stated plainly:** a character who had learned either spell keeps the learned
entry but can no longer cast it, and the gold spent is not refunded. That is inherent to
retiring a spell and is the Technical Director's call, not a side effect this lane can avoid.

## G. Test evidence

| File | Cases | What it proves |
|---|---|---|
| `tests/unit/items/effective_combat_values_test.cpp` | 9 | the three percentages, that they differ, fractions kept, nothing ≤ 0 scaled, shield vs spellbook vs other classification, a double application is visibly wrong, the rounding point |
| `tests/unit/players/condition/effective_skill_percent_test.cpp` | 24 | 100 +30% = 130; equipment counts and follows up and down; five refreshes do not compound; recast applies once and removal restores exactly; two recipes add and are order-independent; a relog restores once; the blob carries the recipe not the value; flat and percent coexist; a proficiency skill bonus counts as source; a proficiency bonus, a Wheel stat and both together gained **while the stance is already on** re-derive at once and unwind exactly; a condition's own flat recipe feeds its own percentage; `getBaseSkill` stays raw; a pre-separation blob drops the stale value; **Positional Tactics' Distance and Battle Instinct's Shielding move an already-active stance at once, unwind exactly and do not compound over five enter/leave cycles**; a conditional bonus is worth nothing while its instant is not held; a non-skill major stat asks for no re-derivation; one evaluation that moves two stats costs one pass; the leave-combat reset takes both stances down with it |
| `tests/unit/players/combat_tactics_test.cpp` | 9 | attack factor, defence factor, defence, mitigation, attack total and defence equipment identical in all three fight modes; a legacy client still gets the old weighting and those numbers really differ; weapon +20% modern only; shield +30% and spellbook +60%; an ordinary off-hand gets neither; raw item data untouched; Shield Bash reads the same compensated value; no percentage applied twice along the defence chain |

Existing suites kept green locally: `test_stance_library.lua` (15), `test_vocation_balance_formulas.lua` (18), `stylua`, `luac`, `clang-format`, `cmake-format`, the Lua API quality and binding-doc checks.

## H. Before / after

Deterministic fixtures. Level 100, the named skill at 100, vocation multipliers 1.0, no Wheel
and no proficiency unless stated.

| Case | Input | Before | After |
|---|---|---|---|
| Sharpshooter on a Paladin | trained 10 + equipment 90 = 100 Distance, +32% | 10 + 3 = **13** (32% of the *base* 10) | **132** (32% of the total 100) |
| The same, equipment removed | trained 10, +32% | 13 | **13** — it follows the equipment back down |
| Melee max damage, sword attack 100, skill 100, Attack mode | `0.085 × factor × attack × skill + level/5` | factor 1.0, attack 100 → **870** | factor 1.0, attack **120** → **1040** |
| The same, Balanced mode | | factor 0.75 → **658** | **1040** — the mode is gone from the math |
| The same, Defense mode | | factor 0.5 → **445** | **1040** |
| Defence, shield defence 100, shielding 100 | `(skill/4 + 2.23) × defence × factor × 0.16` | 27.23 × 100 × 1.0 × 0.16 = **435** | 27.23 × **130** × 1.0 × 0.16 = **566** |
| Defence equipment, shield raw 100 | wire field | **100** | **130** |
| Defence equipment, spellbook raw 100 | wire field | **100** (misclassified as a shield) | **160** |
| Defence equipment, quiver raw 100 | wire field | 100 | **100** — unchanged, it is neither |
| Mitigation, shielding 10, shield raw 100, all vocation factors 1.0 | `((skill × factor) + (shieldFactor × defence)) / 100 × fightFactor` | Attack **0.88**, Balanced **1.10**, Defense **1.32** | **1.40** in all three |
| A spell or rune | any | unaffected | **unaffected** — no weapon attack value in the formula |

## J. Remaining blockers

- `MITIGATION_FIDELITY_PENDING_EVIDENCE` — the vocation weights, weapon-type and 1H/2H
  coefficients, armour's place, caps and rounding of the official reformulation. The proven
  layer is implemented; nothing was guessed. See **E** for the component-by-component state.
- `FIDELITY_BLOCKER — MODERN_TACTICS_UI_PROTOCOL_EVIDENCE_REQUIRED` — the Full Attack / Full
  Defense indicators are client-side. The server already omits the fight-mode byte for the
  current profile (`TacticsWithoutFightMode`, PR #42). Removing the indicators themselves
  needs verified packet evidence this repository does not have, and no byte was invented.
- `FIDELITY_BLOCKER — WHEEL_SORCERER_SLOT_SPELL` — **open, and deliberately left open.** The
  Sorcerer's red- and blue-middle 100 slots used to grant the retired Sap Strength. Three
  things are true at once: leaving the dead name in place does *not* degrade safely
  (`registerWheelSpellTable` logs a warning for a name it cannot resolve, and the runtime smoke
  test fails the build on any warning line); naming the replacement stance there would assert
  an equivalence nothing proves, and the slot's two grade upgrades (`increase.area`,
  `increase.damageReduction`) were read by the old script through `upgradeSpellsWOD` and
  `getWheelSpellAdditionalArea`, which a stance reads neither of; and what the official 15.25
  Wheel grants in that slot is not published.

  So the entry is left **nameless**, `registerWheelSpellTable` skips an empty name as "this
  slot grants no spell" rather than "this spell is missing", and the two slot grants are now
  Druid-only. **Consequence, stated plainly: a Sorcerer with 100 points in either slot gets no
  spell from it** (the slot's mana stat is unaffected). That is a real loss against the
  pre-retirement behaviour and it is the Technical Director's call to resolve — mapping the
  slot to `Aura of Sapped Strength` is a one-line change if that is the decision.
- `FIDELITY_BLOCKER — FORMULA_EVIDENCE_REQUIRED` — Shield Bash / Slam damage shape, carried
  over from PR #49 unchanged. This lane only corrected the stat that feeds it.
- Every other PR #49 blocker (`WAND_MANA_GENERATION_AMOUNT`, `OFFICIAL_SPELL_IDS`,
  `TARGETING_PROTOCOL_EVIDENCE_REQUIRED`, `STANCE_GROUP_PROTOCOL_ID`,
  `WHEEL_SCALE_MAPPING_REQUIRED`) is untouched and still open.

### Not in this lane

Monster combat: no shared `Creature` helper was modified. `Player::getDefense`,
`getDefenseFactor`, `getAttackFactor` and `getMitigation` are overrides; `Monster::getDefense`
and `Monster::getMitigation` are separate functions and were not edited, so the player
compensation cannot reach a monster template. §25's regression test is therefore not
applicable — the condition it is conditioned on ("if a shared helper is changed") did not
occur.

The Wheel was not rewritten: Dedication stays at 0.075 per point, the Lesser Gem base stays at
2000, and the Beam Mastery scale blocker from PR #49 stays as it is.

---

# Round 3 — the post-July Sorcerer Wheel and the modern mitigation profile

Two closed deliverables on top of the effective-skill work above. Nothing in rounds 1 and 2
was undone: the percent-recipe source, the re-derivation hooks and the dynamic Wheel
invalidation are all as they were.

## K. The Sorcerer Wheel, post-July

Two augment pairs had lost the spell they applied to. Both now carry the post-July one, which
closes `WHEEL_SORCERER_SLOT_SPELL` — a Sorcerer no longer loses two maxed 100-point slots.

| Slot pair | Was | Is now | Augment I | Augment II |
|---|---|---|---|---|
| green-middle 100, purple-top 100 | Magic Shield | **Special Spells** | −4s cooldown | +50% base damage |
| red-middle 100, blue-middle 100 | Sap Strength (retired) | **Death Echo** | −2s cooldown | +12% base damage |

**Special Spells applies to exactly three spells** — `Lightning`, `Strong Energy Strike`,
`Strong Flame Strike`. Not the Ultimate strikes, not any other strike, not a generic class.

The set lives in one list behind one alias. `registerWheelSpellTable` expands the alias to
build the bonus tables and `IOWheel::addSpell` expands it to grant the spells, both through
`InternalPlayerWheel::expandSpellAlias`, so the slot and the table cannot come to name
different sets. `Any_Focus_Mage_Spell`, which already worked this way through its own branch,
now goes through the same expansion.

The Druid keeps `Nature's Embrace` in the red- and blue-middle slots and no other vocation
moves. `Sap Strength` is not reintroduced as a castable spell anywhere.

### Beam Mastery

Two different numbers, and the point of the change is that they stay different:

| | Stage I | Stage II | Stage III |
|---|---|---|---|
| **Adjacent-square** damage (`getBeamMasteryAdjacentDamagePercent`) — new | 25% | 40% | 70% |
| **Central beam** per-target increase (`checkBeamMasteryDamage`) — unchanged | 10 | 12 | 14 |

The central beam also keeps its 1s-per-target cooldown reduction, untouched. A test asserts
the two scales never collapse into one value, because overwriting the central mechanic with
25/40/70 is the specific mistake to avoid.

### The adjacent geometry — wired

`FIDELITY_BLOCKER — BEAM_ADJACENT_AREA_GEOMETRY` is **closed**. The adjacent effect is two
one-tile-wide lines parallel to the central beam, one on each side, each the same length as
the beam that actually executes.

```
X . X
X . X      X = flank damage      . = the central beam, its own Combat
X . X      0 = nothing           P = caster, no flank damage
0 P 0
```

`buildBeamMasteryFlankAreas(length)` in `data/libs/functions/combat.lua` builds both matrices
— one helper, not three copies. Cardinal: rows 1..N−1 are `{ 1, 0, 1 }`, row N is `{ 0, 2, 0 }`.
Diagonal: the super-diagonal `(i, i+1)` and the sub-diagonal `(i+1, i)`, both edge-adjacent to
the central cell `(i, i)`, with the caster in the last cell.

**The caster's tile carries `2`, not `3`.** `AreaCombat::createArea` reads `3` as *centre and
damage*; `2` is *centre only*. Using `3` would have put a flank hit on the caster's own tile,
which is the one thing the geometry must not do — so the marker is `2` and a test asserts no
cell in either matrix is ever `3`.

| Spell | Central (Beam Mastery active) | Flank | Directions |
|---|---|---|---|
| Energy Beam | `AREA_BEAM7` / `AREADIAGONAL_BEAM7` | length 7, cardinal + diagonal | cardinal + diagonal, as before |
| Great Energy Beam | `AREA_BEAM10` | length 10, cardinal | cardinal only, as before |
| Great Death Beam | `AREA_BEAM6/7/8` by grade | matching 6/7/8, cardinal | cardinal only, as before |

No spell gained a direction it did not already have.

**A pre-existing bug fixed on the way.** `great_death_beam.lua` passed one shared `Combat`
object through its `createCombat` helper three times, so each call overwrote the previous
area and all three grades executed the last one — the beam was **always `AREA_BEAM8`**
regardless of grade. Each grade now owns its `Combat`, which is both the correct behaviour
and what lets a flank match the length that actually ran. Grades 1 and 2 therefore get the
`BEAM6` / `BEAM7` lengths the data always specified, which is shorter than what they were
getting.

### Keeping the flank out of the central accounting

The flank `Combat` carries the **same instant spell name** as the central beam — it has to, so
that spell augments, the elemental stance and the natural-element rules apply to it. The name
therefore cannot tell the two passes apart, and `PlayerWheel::getBeamAffectedTotal` keys off
exactly that name. Without a flag, a flank target would be counted as a central one.

`CombatParams::beamMasteryFlank`, set from Lua through `COMBAT_PARAM_BEAM_MASTERY_FLANK`, is
that flag. `Combat::CombatFunc` skips both `getBeamAffectedTotal` and
`updateBeamMasteryDamage` when it is set, so a flank hit takes **no** part in:

  - the central beam's target total;
  - the 1-second-per-target cooldown reduction;
  - the central per-target damage increase of 10 / 12 / 14.

It is a flag rather than a cleared spell name on purpose: clearing the name would also
discard the augments and stance behaviour the flank is supposed to keep.

### Flank damage

```
flank min, max = the spell's own formula x (getBeamMasteryAdjacentDamage() / 100)
```

Read per cast from the C++ accessor, so 25 / 40 / 70 is written down in exactly one place and
no Lua file carries a second table. The flank `Combat` only executes when the percentage is
above zero, so stage 0 produces no flank pass at all.

### What is proven and what is not

Proven by tests: the geometry (cell counts per length, no cell on the central line, the caster
marked but never damaged, left/right symmetry, disjointness from the central beam, no
duplicate diagonal cells), the flag's default and both settings, that it disturbs no other
combat parameter, and the 0 / 25 / 40 / 70 accessor with the exact factor the datapack derives.

**Not proven by tests:** the damage numbers a live cast produces, and the stance conversion
applied to a flank hit. Both need a running map with creatures on it, which this repository's
unit and Lua suites cannot provide — there is no combat-integration harness. The stance and
augment behaviour follows by construction (the flank goes through the same
`Combat::getCombatDamage` with the same spell name), but that is an argument, not a test, and
it is recorded here as such rather than claimed as verified.

## L. The modern mitigation profile

### Why the legacy three had to go

`<mitigation multiplier primaryShield secondaryShield />` carried three numbers, and the old
formula used two of them in **two different mathematical positions** depending on equipment —
sometimes weighting one source of Defence before the sum, sometimes multiplying the whole
result after it. `primaryShield` therefore meant two different things, and there was no way to
tune a bow apart from a spellbook because both rode the same `secondaryShield`.

### The pipeline

```
effective Shielding x skillFactor                  -> skill contribution
effective Defence   x <source>DefenseFactor        -> Defence contribution   (per source)
(skill + Defence) / 100                            -> base mitigation
base x <category>EquipmentMultiplier               -> equipment-adjusted     (one category)
equipment-adjusted x Wheel mitigation multiplier   -> final mitigation, in %
```

No fight-mode multiplier on the modern model. A legacy client still gets 0.8 / 1.0 / 1.2, the
compatibility path round 1 established.

### The thirteen knobs

Every one is a dimensionless multiplier — never a percentage, never a flat addend. A
`DefenseFactor` weights **one source** of Defence before the sum; an `EquipmentMultiplier`
weights **the whole result** afterwards, and only the one category the equipment resolves to
ever applies.

| Field | What it weights | Derived from legacy as | Confidence |
|---|---|---|---|
| `skillFactor` | effective Shielding | `multiplier` | project-audited |
| `shieldDefenseFactor` | a shield's effective Defence | `primaryShield` | project-audited |
| `spellbookDefenseFactor` | a spellbook's effective Defence | `1.0` | project-audited |
| `oneHandedDefenseFactor` | a one-hander's full Defence | `primaryShield` | project-audited |
| `twoHandedDefenseFactor` | a two-hander's full Defence | `secondaryShield` | project-audited |
| `shieldEquipmentMultiplier` | the result, shield stance | `1.0` | project-audited |
| `spellbookEquipmentMultiplier` | the result, spellbook stance | `secondaryShield` | project-audited |
| `oneHandedEquipmentMultiplier` | the result, one-handed, no off-hand | `1.0` | project-audited |
| `twoHandedEquipmentMultiplier` | the result, two-handed | `1.0` | project-audited |
| `bowEquipmentMultiplier` | the result, bow | `secondaryShield` | COMMUNITY_DERIVED_TUNABLE |
| `crossbowEquipmentMultiplier` | the result, crossbow | `secondaryShield` | COMMUNITY_DERIVED_TUNABLE |
| `quiverEquipmentMultiplier` | the result, quiver off-hand | `secondaryShield` | COMMUNITY_DERIVED_TUNABLE |
| `elementalBondEquipmentMultiplier` | the result, bonded weapon | `1.0` (neutral) | FIDELITY_PENDING_EVIDENCE |

`data/XML/vocations.xml` stays the single source of truth for per-class tuning; nothing moved
into `config.lua`. The legacy three fill all thirteen through
`VocationMitigationProfile::deriveFromLegacy`, so a `vocations.xml` that was never updated
keeps exactly the numbers it had, and any explicit modern attribute then overrides its own
knob. The audited family values are unchanged: Sorcerer/Druid 1.26 / 2.00 / 1.20, Paladin
1.28 / 2.08 / 1.20, Knight 1.30 / 2.05 / 1.25, Monk 1.28 / 2.08 / 1.20.

### The one combination whose behaviour changes — accepted as baseline

**A spellbook in the off hand together with a one-handed weapon** (the Mage case). The old code
let the weapon's branch overwrite the shared factor, so the spellbook's Defence was silently
weighted by `primaryShield` — a number that has nothing to do with a spellbook. Each source now
carries its own factor. That is the ambiguity the refactor exists to remove.

**Status: closed by product decision.** The Product Owner accepts the new modern behaviour for
the Mage as the project baseline. It is not a fidelity blocker, the old ambiguous
`primaryShield` weighting is not to be reproduced, and the explicit per-source / per-category
model stands. It stays tunable through `spellbookDefenseFactor` and
`spellbookEquipmentMultiplier` in `data/XML/vocations.xml`.

### One-handed weapons

A one-handed weapon now contributes its **full** Defence (`getDefense() + getExtraDefense()`),
not only `extraDefense`. COMMUNITY_DERIVED_TUNABLE, approved for this round. The +20% Attack
compensation is never applied to it — that is an Attack rule — and a shield in the other hand
contributes separately through its own factor, so nothing is counted twice.

### Monster mitigation

`monsterMitigationMultiplier = 1.5` and `monsterMitigationCap = 45.0` in `config.lua.dist`,
read through `ConfigManager::getFloat`. The 15.25 note says monster mitigation went up; it does
not say by how much or to what ceiling, so neither is a constant in the source. Both fall back
to these defaults when an existing server's `config.lua` does not carry the keys.
`DISABLE_MONSTER_ARMOR` behaviour is untouched. Both remain COMMUNITY_DERIVED_TUNABLE.

**Neither value may be negative.** `Creature::mitigateDamage` computes
`damage -= damage * mitigation / 100`, so a negative mitigation would *add* damage instead of
removing it — the percentage layer inverted. `ConfigManager::loadNonNegativeFloatConfig`
corrects a negative or non-finite value to **zero** at the configuration boundary and logs a
warning naming the identifier, so combat never sees an invalid value. Zero is used rather than
the default, because a server that deliberately turned the value down should not find it
silently restored, and zero is the nearest valid value for both keys. No upper bound is
imposed: there is no technical reason for one, and inventing a ceiling would be a balance
decision in disguise.

`Monster::getMitigation` keeps one `std::max(0.0f, …)` on the way out. That is not redundant
with the boundary check: `info.mitigation` comes from a monster's own XML, which nothing
validates, and it is a second way a negative value could arrive.

### The damage-type whitelist

`Creature::isMitigatableCombatType` names the seven common types — physical, earth, ice, fire,
energy, holy, death. The old code excluded only the two drains and agony, which quietly swept
in **drowning, neutral and undefined** damage as well, and would have swept in any new combat
type by default. The switch is exhaustive, so a new type has to be classified rather than
inherited.

### Rounding — characterised, not changed

`ceil(x * 100) / 100` on the equipment-adjusted value: two decimals, rounded up. The Wheel
multiplier applies **after** that, multiplicatively — a base of 2.50% with a +20% Wheel bonus
is 3.00%, never 22.50%. Multiple Wheel sources accumulate into one multiplier before it is
applied, so 20% and 10% give ×1.30 and not ×1.20 ×1.10.

## M. COMMUNITY_EVIDENCE — DAMAGE_REDUCTION_ORDER

The audit §12 asked for. The actual order today, for a Player taking a hit:

| # | Layer | Where |
|---|---|---|
| 1 | creature-level resistance, **Elemental Pierce**, absorb flat, attacker's increase | `Creature::applyAbsorbDamageModifications` |
| 2 | immunity | `Creature::blockHit` |
| 3 | **defense / block** | `Creature::blockHit` |
| 4 | **armor** | `Creature::blockHit` |
| 5 | **mitigation** | `Creature::mitigateDamage` |
| 6 | **item + imbuement resistance** | `Player::blockHit`, inventory loop |
| 7 | **Wheel resistance** | `PlayerWheel::adjustDamageBasedOnResistanceAndSkill` |

Community spike-trap testing indicates **resistance → armor → mitigation**. Layer 1 is already
in that position. Layers **6 and 7 are late**: they run after armour and after mitigation.

### FIDELITY_BLOCKER — DAMAGE_REDUCTION_PIPELINE_ORDER

Moving 6 and 7 ahead of `Creature::blockHit` is **not** a local correction, for two reasons
that have nothing to do with reduction order:

1. The inventory loop decrements item **charges** (`transformItem`) and today only does so on
   a hit that was not blocked. Running it earlier would consume durability on hits that are
   then fully absorbed by defence or armour.
2. Both layers sit behind `blockHit`'s early return on `blockType != BLOCK_NONE`. Moving them
   changes which `BlockType_t` is produced and therefore what `onAttackedCreatureBlockHit`
   reports — shield-block visuals and shielding skill advances.

Per §12.4 this sub-change is stopped and reported rather than forced in. The order is
documented above so the decision is explicit, and correcting it belongs in its own lane with
its own tests for charges and block reporting.

## N. Confidence table

| Value | Label |
|---|---|
| Death Echo Augment II +12%; Beam adjacent 25/40/70; no modern fight mode; +20% Attack; +30% shield Def; +60% spellbook Def; Dedication 0.075%; Gems 20/22/24/30 | POST_JULY_VERIFIED |
| Special Spells replaces the Magic Shield pair; Death Echo replaces the Sap Strength pair; the exact three-spell Special Spells set | PROJECT_ACCEPTED_POST_JULY_MAPPING |
| One-handed full Defence contribution; monster ×1.5; monster cap 45 (both clamped non-negative, unchanged label); the base/equipment/Wheel model | COMMUNITY_DERIVED_TUNABLE |
| Exact Elemental Bond multiplier; exact 2H / bow / crossbow coefficients; exact official internal rounding | FIDELITY_PENDING_EVIDENCE |
| resistance → armor → mitigation ordering | COMMUNITY_EVIDENCE, blocked — see M |
| Beam adjacent-square geometry (two parallel flank lines) | COMMUNITY_DERIVED_TUNABLE — blocker closed |

**No community-derived number is presented as an exact Global value.**
