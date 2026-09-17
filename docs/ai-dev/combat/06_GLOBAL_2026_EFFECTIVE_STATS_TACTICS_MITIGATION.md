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
`Player::refreshPercentSkillRecipes` whenever a non-percent source changes — `setVarSkill` and
a skill advance both call it.

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
fails the build, so the slots now name the stance that replaced the spell.

**Player impact, stated plainly:** a character who had learned either spell keeps the learned
entry but can no longer cast it, and the gold spent is not refunded. That is inherent to
retiring a spell and is the Technical Director's call, not a side effect this lane can avoid.

## G. Test evidence

| File | Cases | What it proves |
|---|---|---|
| `tests/unit/items/effective_combat_values_test.cpp` | 9 | the three percentages, that they differ, fractions kept, nothing ≤ 0 scaled, shield vs spellbook vs other classification, a double application is visibly wrong, the rounding point |
| `tests/unit/players/condition/effective_skill_percent_test.cpp` | 11 | 100 +30% = 130; equipment counts and follows up and down; five refreshes do not compound; recast applies once and removal restores exactly; two recipes add and are order-independent; a relog restores once; the blob carries the recipe not the value; flat and percent coexist; a proficiency skill bonus counts as source; `getBaseSkill` stays raw; a pre-separation blob drops the stale value |
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
- `FIDELITY_BLOCKER — WHEEL_SORCERER_SLOT_SPELL` — the Sorcerer's red- and blue-middle 100
  slots used to grant the retired Sap Strength; they now grant Aura of Sapped Strength, the
  stance that replaced it. **This was a forced choice, not an evidenced one.** Leaving the dead
  name in place was the first attempt and it does *not* degrade safely:
  `InternalPlayerWheel::registerWheelSpellTable` logs a warning for a name it cannot resolve,
  and the CI runtime smoke test fails the build on any warning line. The two grade upgrades on
  that slot (`increase.area`, `increase.damageReduction`) were read by the old script through
  `upgradeSpellsWOD` and `getWheelSpellAdditionalArea`; a stance reads neither, so they are
  kept but inert — the same wired-and-doing-nothing state PR #49 left Lord of Destruction and
  the Shield Slam augments in. What the official 15.25 Wheel actually grants in that slot is
  not published, so the Technical Director should confirm or replace this mapping.
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
