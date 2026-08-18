# Canary Combat System — Root Architecture & Global Fidelity Audit
## Pass 01: Investigative Engineer / Red Team Discovery (CLAUDE)

**READ-ONLY INVESTIGATION. NO PRODUCTION CODE WAS MODIFIED IN THIS PASS.**

## 1. Verified repo/main SHA

- Repository: `Hokz/canary`, branch `main`, working tree clean.
- HEAD verified at pass start: `4209ba583a4dcb2ae528750dcfeb2e7c0109863a` — exact match to the expected starting main head.
- This document reports the state of `main` at that exact commit. No branch was created, no commit was made, no file under `src/`, `data/`, or `data-otservbr-global/` was edited.

## 2. Scope and non-authority statement

This is a **CLAUDE-origin** investigative pass. Every finding below is a **hypothesis for ChatGPT (Technical Director / Final Auditor) validation**, not a confirmed defect. Nothing in this document should be read as:
- a claim that any behavior is GLOBAL_EXACT or GLOBAL_WRONG (no authoritative Tibia-Global reference data was consulted this pass — this is pure Canary-source archaeology),
- a severity classification,
- a merge/implementation recommendation,
- a new project directive.

All findings carry `Status: UNVALIDATED` and `Needs ChatGPT validation: YES`. Confidence levels reflect how directly the *source evidence* supports the claim, not how important or severe ChatGPT might judge it to be.

**Method note:** this pass's research was conducted via four parallel deep-read investigations (outgoing player damage; player defensive pipeline; monster offensive/defensive pipeline; conditions/reflect/leech/healing), each independently tracing call graphs from the entry points down to the arithmetic, followed by this synthesis. Every citation below (`file:line`) was verified against the exact SHA in section 1. Where a quoted line range came from a sub-investigation rather than this document's own direct read, it is still a direct quote of the current `main` source, not a paraphrase of documentation.

## 3. Combat architecture overview

Canary's combat is built around **one shared choke-point pipeline**, not per-attacker-type parallel implementations. The key structural fact, confirmed independently by all four research threads:

- **One function decides if/how much a hit is reduced**: `Creature::blockHit` (`src/creatures/creature.cpp:944-1009`), overridden (not replaced) by `Player::blockHit` (`player.cpp:3851`) and `Monster::blockHit` (`monster.cpp:1401`) — both overrides call the base first, then append species-specific post-processing.
- **One function decides how much damage a hit rolls for**: `Combat::getCombatDamage` (`combat.cpp:52-129`), branching on `creature->getCombatValues()` (true only for monsters with flat `minCombatValue`/`maxCombatValue`) vs. player `formulaType`/`valueCallback` paths.
- **One function actually subtracts HP**: `Game::combatChangeHealth` (`game.cpp:8330`), reached via `Game::combatBlockHit` (`game.cpp:7860`) → `target->blockHit(...)`.
- **One function applies critical hits**: `Combat::applyExtensions` (`combat.cpp:2492-2620`), with explicit `if (player) {...} else if (monster) {...}` branches inside the same function.

This means player-attacks-monster, monster-attacks-player, spell damage, weapon damage, and condition/DoT damage all converge on the same few functions — a fix or defect in one of these choke points propagates to (almost) every direction at once. The exceptions to that symmetry are enumerated in section 9/16 and the finding registry.

## 4. Full damage pipelines A-I

Each stage: **input value → modifier → function → output value**, with the exact point randomness enters called out.

### A. Player melee → monster
1. `Creature::checkCreatureAttack`/`onAttacking` (creature.cpp:174-208) → `Player::doAttacking` (player.cpp:3924-3980), gated on `getAttackSpeed()` cooldown.
2. `Weapon::useWeapon` → `WeaponMelee::getWeaponDamage` (weapons.cpp:645-664): `maxDamage = round(0.085 * attackFactor * (weaponAttack+elementAttack+proficiencyAttack) * weaponSkill + level/5)`, `minDamage = level/5` (or 0 if no physical attack). **Randomness: `normal_random(minDamage, maxDamage)`** (bell-curve around the midpoint, not uniform — tools.cpp:466-475).
3. `Weapon::internalUseWeapon` (weapons.cpp:255-319): `totalDamage = (weaponDamage * damageModifier) / 100` (damageModifier = 100, or halved/zeroed for an improperly-wielded weapon), split into `damage.primary`/`damage.secondary` by physical/elemental proportion.
4. `Combat::doCombatHealth` → `Combat::CombatHealthFunc` (combat.cpp:685-830): imbuement elemental split may overwrite the secondary value (`applyImbuementElementalDamage`, combat.cpp:833-873); unjustified-PvP halving (N/A vs monster); `Combat::applyExtensions` rolls **critical hit** (`uniform_random(1,10000) <= baseChance`, multiplicative `*= 1+bonus/10000`) and "fatal hit" (`uniform_random(0,10000)/100.0 < fatalChance`, additive `+= round(value*0.6)`).
5. `Game::combatBlockHit` (game.cpp:7860): dodge roll N/A (monsters don't dodge the same way — `getDodgeChance` is player-side); Monk Mantra flat absorb N/A vs monster; `target->blockHit(...)` → `Monster::blockHit` (§6/§11).
6. `Game::combatChangeHealth` (game.cpp:8330): buff multipliers, clamp to remaining HP (`realDamage = min(targetHealth, primary+secondary)`), `drainHealth`.
7. If attacker is a player and `damage.origin != ORIGIN_CONDITION` and `!damage.extension`: `applyCharmRune`, `applyLifeLeech`, `applyManaLeech` (game.cpp:8746-8753) computed on the **post-mitigation `realDamage`**, not the raw roll (`Game::calculateLeechAmount`, game.cpp:9042-9045, `std::lround`-rounded, clamped `[0, realDamage]`).

### B. Player distance → monster
Same entry point (`doAttacking`), but `WeaponDistance` overrides `getWeaponDamage`/`getElementDamage` with an **independently hand-written** formula (weapons.cpp:899-940), not a call to the shared `Weapons::getMaxWeaponDamage`: `maxValue = round(0.09*attackFactor*skill*attackValue + level/5)`, with `minValue` halved or quartered depending on target type / elemental ammo, scaled by `vocation->distDamageMultiplier` (a separate multiplier field from `meleeDamageMultiplier`). A pre-damage **hit/miss roll** (weapons.cpp:687-862, distance-skill-driven chance table, or 100% for a "perfect shot") decides whether the projectile even reaches the target before the rest of pipeline A (steps 3-7) applies.

### C. Player spell → monster
Cast → `Combat::doCombat` → `Combat::getCombatDamage` (combat.cpp:52-129):
- `COMBAT_FORMULA_LEVELMAGIC`: `levelFormula = level*2 + (magicLevel+specializedMagicLevel)*3` (combat.cpp:33-50), then `normal_random(levelFormula*mina+minb, levelFormula*maxa+maxb)` — the multiply-then-cast to `int32_t` **truncates**, unlike the weapon path's `std::round`.
- `COMBAT_FORMULA_SKILL`: rolls off the equipped weapon's own `getWeaponDamage(..., maxDamage=true)`.
- `COMBAT_FORMULA_DAMAGE`: flat `normal_random(mina, maxa)` (used by monster spells too, §D).
- A parallel Lua-callback path (`ValueCallback::getMinMaxValues`, combat.cpp:1835-1899) exists for scripts using `setCallback` instead of `setFormula`; its magic-level helper does *not* bake in the `level*2/magic*3` weighting — that's left to the Lua script.
Then rejoins pipeline A at step 4 (crit, block, health change, leech) — **except** flat armor/shield-defense only apply if the spell's `CombatParams` set `blockedByArmor`/`blockedByShield`, which for player weapon-type spells/attacks happens only for physical melee types (combat.cpp:1245-1256) — elemental spell damage generally bypasses armor/defense entirely and relies on mitigation + absorb% only.

### D. Monster melee → player
`Monster::commitCombatIntention` (monster.cpp:1934-1990) rolls `spellBlock.chance >= uniform_random(1,100)`, then `spellBlock.spell->castSpell(...)` → `CombatSpell::castSpell` (spells.cpp:402-448) → `combat->doCombat` — **the exact same `Combat::doCombat`/`Combat::doCombatHealth` entry point players use**. Damage roll: `Combat::getCombatDamage` finds `creature->getCombatValues(min,max)` true (`Monster::getCombatValues`, monster.cpp:3345-3353, returns the Lua `attacks[].minDamage/maxDamage` verbatim) → `normal_random(min,max)`. `Combat::applyExtensions`' monster branch (combat.cpp:2610-2625) applies a separate monster critical-chance/damage roll, then multiplies by `Monster::getAttackMultiplier()` = `RATE_MONSTER_ATTACK`/`RATE_BOSS_ATTACK` config rate × Forge-stack bonus (`1.35 + (stacks-1)*0.1`). Rejoins the shared `combatBlockHit`/`Player::blockHit` pipeline (§7).

### E. Monster spell → player
Structurally identical to D — same `spellBlock`/`CombatSpell` mechanism, no melee-vs-spell branch inside the shared functions. The only material difference is `CombatParams` flag-setting: `monsters.cpp:111-121` sets both `BLOCKARMOR`/`BLOCKSHIELD` for `"melee"` attacks, but for `"combat"` (spell) attacks sets `BLOCKARMOR` **only if `spell->combatType == COMBAT_PHYSICALDAMAGE`** — a fire/ice/energy/earth/holy/death monster spell therefore does not trigger the player's armor-subtraction or shield-defense-roll steps at all; only mitigation + item/imbuement absorb% protect against it.

### F. Condition/DoT → player
`Creature::executeConditions` (creature.cpp:1565-1580, ticked from creature `onThink`) → `ConditionDamage::executeCondition` (condition.cpp:1933-1970) → `ConditionDamage::doDamage` (condition.cpp:1987-2020). The **per-tick magnitude is pre-baked once at condition-creation time** (`generateDamageList`, condition.cpp:2132-2148, a decreasing-value series from `uniform_random(minDamage,maxDamage)`), not re-rolled or re-derived from live caster stats each tick. Tagged with a real `CombatType_t` via `Combat::ConditionToDamageType` (combat.cpp:143-163: fire→`COMBAT_FIREDAMAGE`, poison→`COMBAT_EARTHDAMAGE`, energy→`COMBAT_ENERGYDAMAGE`, bleeding→`COMBAT_PHYSICALDAMAGE`, drown→`COMBAT_DROWNDAMAGE`, freezing→`COMBAT_ICEDAMAGE`), then routed through the **same** `Game::combatBlockHit`/`Game::combatChangeHealth` used by direct hits (condition.cpp:2011,2019) — **not** a shortcut raw health subtraction. Differences from a direct hit: `checkDefense`/`checkArmor` are hard-coded `false,false` (so shield-block and flat armor never apply to a DoT tick — mirrors how most non-melee spells already behave), Monk Mantra flat absorb and the post-buff floor-clamp are explicitly skipped (`if (!condition)` guards, game.cpp:7917-7920, 7992-7995), and leech/charm-rune are explicitly excluded (`damage.origin != ORIGIN_CONDITION` gate, game.cpp:8747). Mitigation%, item/imbuement absorb%, and monster `elementMap` all still apply identically to a DoT tick as to a direct hit of the same element.

### G. Healing
`Combat::getCombatDamage` produces a positive `damage.primary.value` with `damage.primary.type = COMBAT_HEALING`. `Game::combatBlockHit` (game.cpp:7860-7872) **early-returns `false`** ("not blocked") the instant it sees `damage.primary.value > 0`, **before** `blockHit`/mitigation/absorb/reflect ever execute — confirmed clean separation, not an accidental pass-through of the damage-reduction pipeline. `Game::combatChangeHealth`'s positive-value branch (game.cpp:8333-8434) applies only attacker-side buffs (`applyWheelOfDestinyHealing`, `BUFF_HEALINGDEALT`) and a target-side `BUFF_HEALINGRECEIVED` multiplier (an explicit healing-specific buff, not armor/mitigation) before `target->gainHealth(...)`.

### H. Reflected damage
Computed inside `Game::combatBlockHit`, **after** `target->blockHit(...)` has already mutated `damage.primary.value` in place (game.cpp:7922) — **reflect is calculated on post-mitigation, actually-dealt damage**, not the raw pre-armor roll. `reflectPercent = ceil(damage.primary.value * pct/100)` (game.cpp:7950, `std::ceil` — never rounds a positive percent to 0), capped at `ceil(attacker.maxHealth * 0.01)` (1% of the original attacker's max HP). The reflected hit re-enters the **full** `Combat::doCombatHealth` pipeline against the original attacker (`damage.extension = true` prevents this reflected hit from re-triggering leech/further-reflect/Mantra) — meaning the attacker's own armor/mitigation reduces the reflected damage a second time.

### I. Life/mana drain (leech)
Not a separate spell mechanic in this codebase — it's an item/skill stat (`SKILL_LIFE_LEECH_AMOUNT`/`SKILL_MANA_LEECH_AMOUNT`, basis-points) applied deterministically (no chance roll) whenever nonzero, computed via `Game::calculateLeechAmount(realDamage, skillAmount, targetsAffected)` (game.cpp:9042-9045): `realDamage * (skillAmount/10000) * (0.1*targets+0.9)/targets`, `std::lround`-rounded (**can legitimately round to exactly 0** for a small skill% against a small post-mitigation hit), clamped to `[0, realDamage]`. `COMBAT_LIFEDRAIN`/`COMBAT_MANADRAIN` are a *separate*, coincidentally-similarly-named concept: plain `CombatType_t` tags used for certain monster attacks, explicitly **excluded from the generic Wheel-of-Destiny mitigation%** (`Creature::mitigateDamage`, creature.cpp:911-922, excludes `COMBAT_MANADRAIN`/`COMBAT_LIFEDRAIN`/`COMBAT_AGONYDAMAGE`) but not excluded from armor/absorb/elemental resistance.

## 5. Formula inventory

| Formula | Location | Expression |
|---|---|---|
| Melee max damage (player) | weapons.cpp:655 | `round(0.085 * attackFactor * (weaponAtk+elemAtk+profAtk) * skill + level/5)` |
| Melee min damage (player) | weapons.cpp:657 | `level/5` if physicalAttack>0 else `0` |
| Distance max damage | weapons.cpp:920 | `round(0.09 * attackFactor * skill * attackValue + level/5)` |
| Melee max damage (monster) | weapons.cpp:88-91 | `ceil(skill*(attack*0.05) + attack*0.5)` |
| Spell LEVELMAGIC formula | combat.cpp:33-50, 94-97 | `levelFormula=level*2+(magic+specialized)*3`; `normal_random(levelFormula*mina+minb, levelFormula*maxa+maxb)` |
| Critical multiplier | combat.cpp:2492-2620 | chance basis-points `/10000`; `value *= 1 + bonus/10000` |
| Fatal hit | combat.cpp:2519-2526,2597-2601 | `+= round(value * 0.6)` if `uniform_random(0,10000)/100.0 < fatalChance` |
| Player armor | player.cpp:640-651 | `sum(7 slots' item armor) * int32_t(vocation.armorMultiplier)` |
| Player defense | player.cpp:758-796 | `(skill/4.0 + 2.23) * defenseValue * defenseFactor * scalingFactor * vocation.defenseMultiplier` |
| Player mitigation | player_wheel.cpp:4033-4086 | `ceil(((skill*mitigationFactor + shieldFactor*defenseValue)/100) * fightFactor * distanceFactor * 100)/100`, uncapped |
| Monster armor | monster.cpp:1397-1399 | `Lua armor * defenseMultiplier` |
| Monster defense | monster.cpp:241-250 | `(Lua defense + runtime defense) * defenseMultiplier` |
| Monster mitigation | monster.cpp:1389-1395 | `Lua mitigation * defenseMultiplier` (+ armor/defense fold-in if `DISABLE_MONSTER_ARMOR`), **capped at 30.0** |
| Armor/defense hit reduction | creature.cpp:968,979 | `uniform_random(stat/2, stat)`-ish random subtraction |
| Mitigation reduction | creature.cpp:914 | `damage -= (damage*mitigation)/100.` (int32_t truncation) |
| Elemental resist (monster) | monster.cpp:1417-1423 | `round(damage * (100-percent)/100)`, unclamped in C++ |
| Item absorb (player) | player.cpp:3890-3906 | sequential per-slot `damage -= round(damage*totalPct/100)` |
| Leech amount | game.cpp:9042-9045 | `lround(realDamage * skill/10000 * (0.1*n+0.9)/n)`, clamped `[0,realDamage]` |
| Reflect amount | game.cpp:7950-7951 | `ceil(damage*pct/100)`, capped `ceil(attackerMaxHP*0.01)` |
| PvP multiplier | game.cpp:8218-8247 | `round(damage * pvpDealt * pvpReceived * levelDiffMultiplier)` |

## 6. Defense / armor / mitigation order

Confirmed **runtime execution order** (not declaration order) for a hit landing on either a player or monster target, reconstructed from `Creature::blockHit`/`Player::blockHit`/`Monster::blockHit`:

1. **Dodge roll** (player defender only, `getDodgeChance`, game.cpp:7875-7882) — full avoidance, short-circuits everything else.
2. **Monk Mantra flat absorb** (player defender only, elemental types, skipped for condition damage).
3. **`applyAbsorbDamageModifications`** (creature.cpp:924-942) — condition-driven absorb%/absorbFlat/attacker's increase%, runs unconditionally, first inside `blockHit` itself.
4. **`DISABLE_MONSTER_ARMOR` check** (creature.cpp:950, monster defender only) — may zero `checkDefense`/`checkArmor`.
5. **Immunity check** — full zero, short-circuits armor/defense/mitigation (not absorb, which already ran).
6. **Defense** (shield/weapon, `blockCount`-gated — see §9) — flat-ish random subtraction, `uniform_random(defense/2, defense)`.
7. **Armor** — flat-ish random subtraction, `uniform_random(armor/2, armor-(armor%2+1))`, **not** gated by `blockCount`.
8. **Mitigation** (`Creature::mitigateDamage`) — percent of whatever remains after 6-7, excluded for `COMBAT_MANADRAIN`/`COMBAT_LIFEDRAIN`/`COMBAT_AGONYDAMAGE`.
9. **Species-specific final layer**: monster → `elementMap` percent (monster.cpp:1404-1423); player → item/imbuement absorb% loop + Wheel elemental resistance (player.cpp:3861-3922), gated to only run if not already fully blocked.
10. **Buff multipliers**, then **PvP multiplier** (PvP only, last).
11. Clamp to remaining HP, `drainHealth`.

**Key point for the audit's own framing**: armor/defense (flat, absolute) run *before* mitigation (percent, of the remainder) — so mitigation's own marginal contribution shrinks as armor/defense's contribution grows, not the reverse (see H2 in section 16 — this contradicts the literal hypothesis as stated).

## 7. Absorb / resistance order

- **Condition-driven absorb** (`getAbsorbPercent`/`getAbsorbFlat`/attacker's `getIncreasePercent`) is additive-into-one-array, single pass, applied first (step 3 above).
- **Item/imbuement absorb (player)**: additive **within one item** (`absorbPercent + fieldAbsorbPercent` summed before subtraction), but **multiplicative across different items/imbuements** (the loop mutates `damage` in place between iterations — classic diminishing-returns stacking: two 10% absorbs on different items give ≈19% combined, not 20%).
- **Monster elemental resist** is a single `elementMap` lookup per combat type — no stacking concern (one value per type).
- A **fully separate, closed-form, correctly-diminishing-returns multiplicative absorb formula exists** (`Player::getFinalDamageReduction`/`calculateDamageReductionFromEquipedItems`, player.cpp:5644-5706) but is **dead code** — confirmed via repo-wide grep, zero call sites. The live absorb math is the cruder inline loop described above, not this formula.

## 8. Fight mode effects

`fightMode` (`FIGHTMODE_ATTACK`/`BALANCED`/`DEFENSE`) is read in **at least 5 places**, not one:

| Function | ATTACK | BALANCED | DEFENSE |
|---|---|---|---|
| `Player::getAttackFactor` (outgoing damage) | 1.0 | 0.75 | 0.5 |
| `Player::getDefense` zero-skill fallback | 1 | 1 | 2 |
| `Player::getDefenseFactor` | 0.5-1.0 (time-gated) | 0.75-1.0 (time-gated) | 1.0 |
| `PlayerWheel::calculateMitigation` fightFactor | 0.8 | 1.0 | 1.2 |
| `Player::attackTotal` (UI-only, **different** coefficients — see COMBAT-C-009) | ×1.2 | ×1.0 | ×0.6 |

Fight mode does **not** touch `getArmor()`, the dodge chance, or the item/imbuement absorb loop.

## 9. Multi-attacker / block saturation behavior

`blockCount` (creature.hpp:898, per-defender instance member, cap **2**, +1 every 1000ms — creature.cpp:142-146) gates **only the shield/weapon defense roll**, consumed by `if (checkDefense || checkArmor) { if (blockCount>0) {--blockCount; hasDefense=true;} }` (creature.cpp:958-965). **Armor reduction is entirely ungated by `blockCount`** (`if (checkArmor) {...}` has no `hasDefense` dependency) — so armor applies identically and without saturation to attacker #1 and attacker #6 in the same window, while the shield/weapon defense roll is available to at most ~2 qualifying hits per second **shared across every attacker hitting that defender**, and a purely-armor-checked hit (`checkArmor=true, checkDefense=false`) still consumes a shared slot without using it, potentially starving a later melee hit's own defense roll in the same window.

## 10. Player outgoing damage formulas

See section 4A-C and section 5. Key structural notes: melee and distance use **two independently-written formulas** with the same general shape (`coefficient * attackFactor * skill * attack + level/5`) but different coefficients (0.085 vs 0.09) and different edge-case branching (distance halves/quarters its min value by target-type/element, melee doesn't); spell damage has **three** distinct formula types (`LEVELMAGIC`/`SKILL`/`DAMAGE`) plus a fourth Lua-callback escape hatch; critical/fatal are applied as a single shared post-roll multiplier+additive step regardless of attack type.

## 11. Monster defensive pipeline

`Monster::blockHit` = `Creature::blockHit` (shared base, §6 steps 3-8) + `elementMap` percent (§6 step 9). Monster armor/defense/mitigation are all flat Lua-authored values scaled by `getDefenseMultiplier()` = config rate (`RATE_MONSTER_DEFENSE`/`RATE_BOSS_DEFENSE`) × Forge-stack bonus (`1 + 0.1*stacks`). **Monster mitigation is hard-capped at 30.0** (monster.cpp:1394, `std::min<float>(mitigation, 30.f)`) — no equivalent cap exists anywhere in the player mitigation chain. `DISABLE_MONSTER_ARMOR` (config key `disableMonsterArmor`, default `false`, **not documented in `config.lua.dist`**) does not simply zero monster armor — it disables the flat defense/armor subtraction steps (`checkDefense=checkArmor=false`) and *compensates* by folding `(defense+armor)` into the mitigation percentage (still capped at 30), a net **nerf** for any monster whose armor/defense would otherwise imply >30% effective reduction.

## 12. Conditions / DoT / reflected/leech paths

See section 4F, H, I. Structural summary: DoT ticks go through the *same* `combatBlockHit`/`combatChangeHealth` functions as direct hits (not a shortcut), respect elemental resistance/mitigation/absorb identically to a direct hit of the same element, but never trigger shield-block, armor subtraction, Monk Mantra, or leech/charm procs. Reflect is computed on post-mitigation damage and re-applies the *original attacker's own* defenses a second time. Leech is computed on post-mitigation, HP-capped `realDamage`, deterministically (no chance roll), and is structurally impossible from condition-origin or already-reflected/extension damage.

## 13. Visual feedback semantics

`InternalGame::sendBlockEffect` (game.cpp:398-438) fires an effect **only when `blockType != BLOCK_NONE`**, and `blockType` only becomes non-`BLOCK_NONE` when the corresponding reduction step (defense/armor/immunity/dodge) drove `damage` to **exactly 0** (creature.cpp:969-973, 984-987). **A partial reduction — e.g. armor+mitigation+absorb knocking a hit from 400 down to 60 — produces no distinct visual or sound feedback at all**; it renders identically to an unmitigated hit of magnitude 60. The player has no in-client signal of *how much* a hit was reduced unless it was reduced to zero.

## 14. Integer rounding / clamps / caps

Consolidated from all four sub-investigations (representative, not exhaustive — see the finding registry for the highest-relevance ones):

- `level/5` (int truncation) recurs in at least 4 separate damage-formula locations, creating a hard breakpoint every 5 character levels.
- `Creature::mitigateDamage` (creature.cpp:914) truncates toward zero (implicit `double→int32_t` narrowing, no `std::round`), while nearly every sibling absorb step (`applyAbsorbDamageModifications`, item absorb loop, monster elemental resist, Wheel adjustments) explicitly uses `std::round`/`std::ceil` — an inconsistency isolated to exactly this one step.
- `Player::getDefense()` (player.cpp:796) computes its entire formula in `double` and returns `int32_t` with **no rounding call at all**.
- `Player::getArmor()` casts `vocation->armorMultiplier` (a `float`) to `int32_t` **before** multiplying (player.cpp:650) — currently dormant since every vocation's `armorMultiplier` is `1.0` in `vocations.xml`, but a live landmine for any future fractional-multiplier tuning.
- `Game::calculateLeechAmount` uses `std::lround` and **can legitimately round to exactly 0** for a small leech% against a small post-mitigation hit; `reflectPercent`'s `std::ceil` (game.cpp:7950) **never** rounds a positive percent to 0 — the two "percent of damage" mechanics in the same file round in opposite directions at the low end.
- Monster elemental resist percent is **unclamped at the C++ level**; the only clamp (`[minElementalResistance, maxElementalResistance]`, default `[-200,200]`) lives in the **Lua registration script** (`register_monster_type.lua:461-464`), not the engine — a monster registered via a raw `monsterType:addElement(...)` call bypassing that script gets no clamping at all.

## 15. Candidate finding registry (COMBAT-C-###)

---
**ID:** COMBAT-C-001
**Title:** Monster mitigation hard-capped at 30%; player mitigation has no equivalent cap
**Origin:** CLAUDE
**Source files/functions:** `src/creatures/monsters/monster.cpp:1389-1395` (`Monster::getMitigation`); `src/creatures/players/components/wheel/player_wheel.cpp:4033-4086` (`PlayerWheel::calculateMitigation`)
**Observed Canary behavior:** `Monster::getMitigation()` ends with `return std::min<float>(mitigation, 30.f);`. `PlayerWheel::calculateMitigation()` has no `std::min`/clamp anywhere in its body.
**Evidence:** direct quotes in section 11 and the monster-pipeline sub-report.
**Hypothesis:** this asymmetry may be intentional (monsters are meant to always take *some* meaningful damage regardless of stacked mitigation sources; players are meant to be able to build toward very high mitigation via Wheel/gear), or may be an oversight where a symmetric cap was intended on both sides.
**Possible gameplay consequence:** a monster designed/tuned with very high `defenses.mitigation` (or via `DISABLE_MONSTER_ARMOR`'s armor/defense fold-in) cannot exceed 30% effective reduction from this stat, capping how "tanky" a monster's mitigation identity can feel regardless of its Lua-authored value; conversely a heavily-invested player build may exceed 30% with no corresponding ceiling.
**Confidence:** HIGH
**Needs ChatGPT validation:** YES
**Suggested experiment:** harness sweep of monster `defenses.mitigation` from 0-100 against a fixed attacker, confirm the output plateaus at 30% exactly at `mitigation>=30`.
**Related findings:** COMBAT-C-002, COMBAT-C-013
**Status:** UNVALIDATED

---
**ID:** COMBAT-C-002
**Title:** Block visual/audio effect is binary — no signal for partial damage reduction
**Origin:** CLAUDE
**Source files/functions:** `src/game/game.cpp:398-438` (`InternalGame::sendBlockEffect`); `src/creatures/creature.cpp:969-973,984-987`
**Observed Canary behavior:** the effect dispatcher only fires when `blockType != BLOCK_NONE`, and `blockType` only becomes non-`BLOCK_NONE` when a reduction step drove damage to exactly 0.
**Evidence:** direct quotes in section 13.
**Hypothesis:** this is very likely the single largest contributor to the "equipment/mitigation feels imperceptible" complaint the task opened with — every partial reduction (the overwhelming majority of hits against any reasonably-equipped target) is visually indistinguishable from zero mitigation.
**Possible gameplay consequence:** players cannot perceive their own armor/mitigation/absorb working at all except in the rare case it fully blocks a hit; this is a UX/feedback gap independent of whether the underlying math is "correct."
**Confidence:** HIGH
**Needs ChatGPT validation:** YES
**Suggested experiment:** none needed beyond source confirmation (already direct/unambiguous); a follow-up could check whether the client-side damage-number popup at least distinguishes color/style for a reduced vs. unreduced hit, which is outside this pass's C++ server-side scope.
**Related findings:** none
**Status:** UNVALIDATED

---
**ID:** COMBAT-C-003
**Title:** `blockCount` gates shield/weapon defense but not armor; a shared 2/second pool across all attackers
**Origin:** CLAUDE
**Source files/functions:** `src/creatures/creature.hpp:898`; `src/creatures/creature.cpp:142-146,958-993`
**Observed Canary behavior:** `blockCount` (cap 2, regenerates +1/1000ms) is decremented by any hit where `checkDefense||checkArmor` is true, but only the shield/weapon-defense roll is conditioned on a successful decrement (`hasDefense`); the armor step runs unconditionally whenever `checkArmor` is true.
**Evidence:** quoted in section 9 and the player-pipeline sub-report.
**Hypothesis:** under sustained multi-attacker pressure (e.g. a hunting party or a monster surrounded), shield/weapon defense saturates almost immediately (2 charges, shared) while armor keeps applying to every hit — meaning "block" (the flashy `BLOCK_DEFENSE` effect) becomes rare under pressure while the less-visible armor step keeps working quietly, compounding the COMBAT-C-002 perception gap.
**Possible gameplay consequence:** perceived defensive weakness specifically scales with number of simultaneous attackers, independent of gear.
**Confidence:** HIGH
**Needs ChatGPT validation:** YES
**Suggested experiment:** harness scenario 3 (already run this pass, section 17) — needs a more rigorous time-stepped multi-attacker simulation (current version is a crude approximation, explicitly flagged) before trusting exact percentages.
**Related findings:** COMBAT-C-002
**Status:** UNVALIDATED

---
**ID:** COMBAT-C-004
**Title:** Elemental damage (spells, elemental monster attacks) bypasses armor and shield-defense entirely
**Origin:** CLAUDE
**Source files/functions:** `src/creatures/monsters/monsters.cpp:111-121`; `src/creatures/combat/combat.cpp:1245-1256`
**Observed Canary behavior:** `CombatParams::blockedByArmor`/`blockedByShield` are only set `true` for physical melee attack types; elemental "combat"-type spells (monster or player-triggered) leave both flags `false`, so `Creature::blockHit`'s `checkDefense`/`checkArmor` branch never executes for them — only mitigation% and item/imbuement absorb% apply.
**Evidence:** quoted in section 4C/E.
**Hypothesis:** this may be intentional design (armor = anti-physical, resistance/absorb = anti-elemental, a deliberate split identity), or an unintended gap where armor investment feels "wasted" against the elemental-heavy attack rosters common at higher content tiers.
**Possible gameplay consequence:** a player who gears exclusively for armor (vs. elemental resistance/mitigation) would perceive armor as ineffective against any elemental-heavy encounter — directly relevant to the task's "feels less perceptible than expected" framing, but only for elemental damage specifically.
**Confidence:** HIGH
**Needs ChatGPT validation:** YES
**Suggested experiment:** harness scenario 4 (already run this pass) comparing physical vs. elemental damage paths at identical raw damage and target stats.
**Related findings:** COMBAT-C-001
**Status:** UNVALIDATED

---
**ID:** COMBAT-C-005
**Title:** `Creature::mitigateDamage` truncates instead of rounds, inconsistent with sibling absorb steps
**Origin:** CLAUDE
**Source files/functions:** `src/creatures/creature.cpp:911-922`
**Observed Canary behavior:** `damage -= (damage * getMitigation()) / 100.;` assigns a `double` RHS into `int32_t damage` via compound assignment with no `std::round`/`std::ceil` — implicit truncation toward zero. Every other percent-based reduction step in the same call chain (`applyAbsorbDamageModifications`, item absorb loop, monster elemental resist, Wheel adjustments) explicitly rounds.
**Evidence:** quoted in section 14.
**Hypothesis:** likely an oversight rather than deliberate design, given every structurally-similar sibling function rounds explicitly.
**Possible gameplay consequence:** systematically biases mitigation slightly in the defender's favor at low percentages/small hits (never rounds up), and is a minor but real contributor to gear-upgrade values feeling slightly muted.
**Confidence:** MEDIUM (real, but magnitude is at most ±1 damage per hit)
**Needs ChatGPT validation:** YES
**Suggested experiment:** harness comparison of truncated vs. rounded mitigation over a large hit sample at various mitigation percentages to quantify cumulative drift.
**Related findings:** COMBAT-C-008
**Status:** UNVALIDATED

---
**ID:** COMBAT-C-006
**Title:** `Player::getFinalDamageReduction()` — a correct, closed-form, diminishing-returns absorb-stacking formula — is dead code; the live path is a cruder inline loop
**Origin:** CLAUDE
**Source files/functions:** `src/creatures/players/player.cpp:5644-5706` (dead); `src/creatures/players/player.cpp:3861-3919` (live, inside `Player::blockHit`)
**Observed Canary behavior:** `getFinalDamageReduction`/`calculateDamageReductionFromEquipedItems`/`calculateDamageReductionFromItem` implement `(100-currentTotal)/100*resistance + currentTotal` per item (the textbook correct diminishing-returns stacking formula), clamped to `[-100,100]`. Repo-wide grep confirms zero callers. The actually-executed path is a `for` loop in `Player::blockHit` that sequentially subtracts each item's (or imbuement's) percent from the shrinking `damage` value directly — mathematically similar in shape but not proven identical, and with the additive-within-item/multiplicative-across-item nuance described in section 7.
**Evidence:** confirmed via repo-wide grep by the sub-investigation; both functions quoted in the player-pipeline sub-report.
**Hypothesis:** this may represent an incomplete refactor — the closed-form function looks like an intended replacement for the inline loop that was never wired in — or it may be genuinely obsolete/abandoned code.
**Possible gameplay consequence:** none currently (dead code has zero runtime effect), but signals that "the formula ChatGPT/documentation might expect" and "the formula that actually runs" could diverge if anyone (including a future audit) reads the wrong one as authoritative.
**Confidence:** HIGH (dead-code fact); LOW-MEDIUM (gameplay relevance, since it's inert)
**Needs ChatGPT validation:** YES
**Suggested experiment:** none needed for the dead-code fact itself; ChatGPT should decide whether this function should be wired in, removed, or left as-is.
**Related findings:** COMBAT-C-007
**Status:** UNVALIDATED

---
**ID:** COMBAT-C-007
**Title:** `Player::getCombatTacticsMitigation()` is dead code duplicating logic already live inside `PlayerWheel::calculateMitigation()`
**Origin:** CLAUDE
**Source files/functions:** `src/creatures/players/player.cpp:736-756`; `src/creatures/players/components/wheel/player_wheel.cpp:4039-4054`
**Observed Canary behavior:** both implement the identical `fightMode`-driven `0.8/1.0/1.2` factor switch; only the Wheel copy is ever called.
**Evidence:** confirmed via repo-wide grep by the sub-investigation.
**Hypothesis:** leftover from a refactor (mitigation logic likely moved into `PlayerWheel` at some point and the old `Player::` copy was never deleted).
**Possible gameplay consequence:** none (dead code); flagged for codebase-hygiene awareness only.
**Confidence:** HIGH
**Needs ChatGPT validation:** YES (low priority)
**Suggested experiment:** none
**Related findings:** COMBAT-C-006
**Status:** UNVALIDATED

---
**ID:** COMBAT-C-008
**Title:** `Player::getArmor()` truncates the vocation armor multiplier to `int32_t` before multiplying (currently dormant)
**Origin:** CLAUDE
**Source files/functions:** `src/creatures/players/player.cpp:640-651`; `data/XML/vocations.xml`
**Observed Canary behavior:** `armor * static_cast<int32_t>(vocation->armorMultiplier)` — the cast happens before the multiply, so any fractional `armorMultiplier` (e.g. `1.5`) would truncate to `1`, and any sub-1.0 value would truncate to `0`. Every vocation in the current `vocations.xml` sets `armor="1.0"`, so `static_cast<int32_t>(1.0f) == 1` currently masks this.
**Evidence:** quoted in section 14.
**Hypothesis:** latent bug, inert only because current data happens to use whole-number multipliers.
**Possible gameplay consequence:** if a future balance pass tunes `armorMultiplier` to a fractional value for any vocation, that vocation's armor could silently collapse to a much smaller (or zero) value than intended, with no error/warning.
**Confidence:** MEDIUM (code fact confirmed HIGH; live gameplay impact currently NONE since data is inert)
**Needs ChatGPT validation:** YES
**Suggested experiment:** harness test with a synthetic `armorMultiplier=1.5`/`0.5` to confirm the truncation behavior numerically.
**Related findings:** COMBAT-C-005
**Status:** UNVALIDATED

---
**ID:** COMBAT-C-009
**Title:** Client attack-info UI (`Player::attackTotal`) uses different fight-mode coefficients than the real damage formula
**Origin:** CLAUDE
**Source files/functions:** `src/creatures/players/player.cpp:604-633` (`attackTotal`, UI-only); `src/creatures/players/player.cpp:822-833` (`getAttackFactor`, real formula)
**Observed Canary behavior:** `attackTotal`'s fight-mode multiplier is `1.2/1.0/0.6` (ATTACK/BALANCED/DEFENSE); the actual damage-roll formula's multiplier (`getAttackFactor`, consumed by `Weapons::getMaxWeaponDamage`) is `1.0/0.75/0.5`. `attackTotal` is used only to populate the client's attack-value tooltip (`protocolgame.cpp:5353-5424`), never in actual damage computation.
**Evidence:** both quoted in section 8 / the outgoing-damage sub-report.
**Hypothesis:** the UI tooltip may not be intended as a literal damage preview (could be a separate "attack rating" concept), or this is formula drift between the display and the real mechanic.
**Possible gameplay consequence:** if players interpret the attack-value tooltip as a damage preview, its fight-mode scaling curve does not match how their real damage actually scales across fight modes — a direct source of "the mechanic feels different than what the game shows me."
**Confidence:** HIGH (both formulas confirmed distinct); the interpretive question (is this a display-vs-reality bug) needs ChatGPT
**Needs ChatGPT validation:** YES
**Suggested experiment:** harness comparison of `attackTotal`'s predicted value vs. actual mean rolled damage across the 3 fight modes at a fixed gear/skill loadout.
**Related findings:** none
**Status:** UNVALIDATED

---
**ID:** COMBAT-C-010
**Title:** `DISABLE_MONSTER_ARMOR` is undocumented in `config.lua.dist` and does not behave as its name implies
**Origin:** CLAUDE
**Source files/functions:** `src/config/config_enums.hpp:68`; `src/config/configmanager.cpp:91`; `src/creatures/creature.cpp:950`; `src/creatures/monsters/monster.cpp:1391-1393`
**Observed Canary behavior:** the Lua config key `disableMonsterArmor` (default `false`) does not appear anywhere in `config.lua.dist`. When enabled, it does not "disable armor" in the naive sense — it skips the flat defense/armor subtraction steps for monster targets AND compensates by folding `(defense+armor)` into the monster's mitigation percentage (itself capped at 30% — COMBAT-C-001), a net *nerf* for high-armor monsters rather than a full removal of defensive identity.
**Evidence:** quoted in section 11 / the monster-pipeline sub-report.
**Hypothesis:** the flag's name and its actual compensating behavior may surprise a server operator who enables it expecting monsters to simply take full damage.
**Possible gameplay consequence:** if this repo's own `config.lua`/live server config has this flag set to a non-default value, it materially changes monster "defensive feel" repo-wide in a way not documented anywhere a server operator would naturally look.
**Confidence:** HIGH
**Needs ChatGPT validation:** YES — first check whether this specific server's live/`.dist`-derived config actually sets this flag away from default
**Suggested experiment:** grep the live server config (not just `.dist`) for this key; if set `true`, run harness scenario 1 with and without the compensating mitigation fold-in to quantify the delta.
**Related findings:** COMBAT-C-001
**Status:** UNVALIDATED

---
**ID:** COMBAT-C-011
**Title:** Two independent PvP outgoing-damage reduction passes stack in the same call chain
**Origin:** CLAUDE
**Source files/functions:** `src/creatures/combat/combat.cpp:724-731` (unjustified-attack halving); `src/game/game.cpp:8218-8227` (`Game::applyPvPDamage`)
**Observed Canary behavior:** an unjustified PvP hit is halved once in `Combat::CombatHealthFunc`, then separately multiplied by `pvpDamageDealtMultiplier * pvpDamageReceivedMultiplier * levelDifferenceMultiplier` later in `Game::combatChangeHealth` — both run, in sequence, for every qualifying PvP hit.
**Evidence:** quoted in the outgoing-damage sub-report.
**Hypothesis:** likely intentional (different design purposes — skull/justification penalty vs. vocation/level PvP balancing), but flagged since it is exactly the "modifier applied twice" pattern this audit was asked to look for.
**Possible gameplay consequence:** PvP damage-reduction magnitude could be larger than a designer expects if these two were meant to be alternatives rather than stacked.
**Confidence:** MEDIUM
**Needs ChatGPT validation:** YES
**Suggested experiment:** harness PvP scenario comparing an unjustified hit's total reduction with both passes vs. either alone.
**Related findings:** none
**Status:** UNVALIDATED

---
**ID:** COMBAT-C-012
**Title:** Elemental imbuement split overwrites (does not add to) the weapon's own inherent elemental split
**Origin:** CLAUDE
**Source files/functions:** `src/items/weapons/weapons.cpp:282-294` (`internalUseWeapon`); `src/creatures/combat/combat.cpp:833-873` (`applyImbuementElementalDamage`)
**Observed Canary behavior:** `internalUseWeapon` first splits `damage.primary`/`damage.secondary` by the weapon's own physical/elemental attack proportion; later in the same combat resolution, `applyImbuementElementalDamage` (if an elemental imbuement is slotted and `damage.primary.type == COMBAT_PHYSICALDAMAGE`) recomputes and **overwrites** `damage.secondary.value`/`type` from `damage.primary.value` alone.
**Evidence:** quoted in the outgoing-damage sub-report.
**Hypothesis:** unclear whether a weapon with both a built-in element (e.g. a fire sword) and a different elemental imbuement (e.g. ice) is *intended* to have the imbuement fully replace the weapon's own element, or whether the two should combine.
**Possible gameplay consequence:** a player combining an elemental weapon with a different-element imbuement may get a silently different elemental damage split than the sum of both sources would suggest.
**Confidence:** MEDIUM
**Needs ChatGPT validation:** YES
**Suggested experiment:** harness/manual test with a fire-innate weapon + ice imbuement, compare resulting primary/secondary split against a naive "both should apply" expectation.
**Related findings:** none
**Status:** UNVALIDATED

---
**ID:** COMBAT-C-013
**Title:** `Monster::blockHit`'s elemental resistance percent is unclamped in C++; only the Lua registration script enforces `[-200,200]`
**Origin:** CLAUDE
**Source files/functions:** `src/creatures/monsters/monster.cpp:1404-1423`; `data/scripts/lib/register_monster_type.lua:441-468`
**Observed Canary behavior:** `Monster::blockHit`'s `elementMod` is applied with no `std::clamp` at the C++ level; the `[minElementalResistance, maxElementalResistance]` clip (default `[-200,200]`) is enforced only inside the Lua registration library, and only when `canClip` is true (which is true unless all 7 base elements are explicitly listed at exactly 100%).
**Evidence:** quoted in section 11 and section 14.
**Hypothesis:** any monster type registered via a direct `monsterType:addElement(...)` call bypassing `register_monster_type.lua`'s `elements` table handler receives no clamping at all, and a value like `percent=500` would silently apply as a 5x damage multiplier with no engine-level guard.
**Possible gameplay consequence:** low likelihood of live impact if every monster in this repo goes through the standard registration library, but represents a data-integrity gap at the engine layer.
**Confidence:** MEDIUM
**Needs ChatGPT validation:** YES
**Suggested experiment:** repo-wide grep for direct `:addElement(` calls outside `register_monster_type.lua`'s own `elements` handler, to see if any monster file bypasses the clip.
**Related findings:** COMBAT-C-001
**Status:** UNVALIDATED

---
**ID:** COMBAT-C-014
**Title:** Monk Mantra and the post-buff floor-clamp protect against a direct elemental hit but not the resulting DoT condition of the same element
**Origin:** CLAUDE
**Source files/functions:** `src/game/game.cpp:7917-7920,7992-7995`; `src/creatures/combat/combat.cpp:630-650` (`applyMantraAbsorb`)
**Observed Canary behavior:** both are wrapped in `if (!condition) {...}` guards inside `Game::combatBlockHit`, explicitly skipped whenever the hit originates from a condition tick — even though burning/freezing/energy/earth conditions map to the exact same `CombatType_t` as the spell that applied them.
**Evidence:** quoted in section 4F / the conditions sub-report.
**Hypothesis:** likely deliberate (Mantra as an "active hit" defense, not a persistent-DoT counter), but worth confirming since it means a Monk's elemental Mantra absorb has an asymmetric relationship with elemental burn/poison/freeze effects it doesn't obviously advertise.
**Possible gameplay consequence:** a Monk player could reasonably expect fire-Mantra to reduce burning-DoT damage (same element) and be surprised it doesn't.
**Confidence:** MEDIUM-HIGH
**Needs ChatGPT validation:** YES
**Suggested experiment:** none needed beyond source confirmation (unambiguous guard); a design-intent question for ChatGPT/owner.
**Related findings:** none
**Status:** UNVALIDATED

---
**ID:** COMBAT-C-015
**Title:** `WeaponDistance` reimplements the max-damage formula inline, inconsistently, instead of sharing `Weapons::getMaxWeaponDamage`
**Origin:** CLAUDE
**Source files/functions:** `src/items/weapons/weapons.cpp:864-940`
**Observed Canary behavior:** melee (`WeaponMelee`) and fist attacks all funnel through the shared `Weapons::getMaxWeaponDamage`; `WeaponDistance::getWeaponDamage`/`getElementDamage` hand-write an equivalent-shaped formula directly, and the two distance functions are **not internally consistent with each other**: `getWeaponDamage` halves/quarters `minValue` based on `hasElement && target->getPlayer()`, while `getElementDamage` halves/quarters based on `target->getPlayer()` alone, without checking `hasElement`.
**Evidence:** quoted in the outgoing-damage sub-report.
**Hypothesis:** could be intentional (physical vs. elemental component of a distance hit behaving differently by design) or formula drift between two functions that were meant to mirror each other.
**Possible gameplay consequence:** distance weapons' elemental-vs-physical damage split against players vs. monsters may not follow the pattern a designer expects.
**Confidence:** MEDIUM
**Needs ChatGPT validation:** YES
**Suggested experiment:** harness comparison of `getWeaponDamage` vs `getElementDamage` output across the `hasElement`×`targetIsPlayer` 2×2 matrix.
**Related findings:** none
**Status:** UNVALIDATED

---
**ID:** COMBAT-C-016
**Title:** `Weapon::getCombatDamage` (base class virtual) appears to be entirely dead code
**Origin:** CLAUDE
**Source files/functions:** `src/items/weapons/weapons.hpp:75`; `src/items/weapons/weapons.cpp:197-218`
**Observed Canary behavior:** implements a full melee-damage-plus-elemental-split formula structurally similar to the live `WeaponMelee::getWeaponDamage`+`internalUseWeapon` combination, but a repo-wide grep found zero call sites for this specific overload (easily confused with the unrelated `Combat::getCombatDamage` and `Creature::getCombatDamage()`, which *are* both live).
**Evidence:** confirmed via grep by the outgoing-damage sub-investigation.
**Hypothesis:** dead/legacy code, likely superseded by the `internalUseWeapon` path.
**Possible gameplay consequence:** none currently (unreferenced); flagged for codebase-hygiene awareness.
**Confidence:** MEDIUM (grep-based; a fresh grep in a follow-up pass should re-confirm before treating as certain)
**Needs ChatGPT validation:** YES (low priority)
**Suggested experiment:** independent re-grep to confirm zero call sites.
**Related findings:** COMBAT-C-006
**Status:** UNVALIDATED

## 16. Red-team hypothesis matrix H1-H10

| # | Hypothesis | Verdict | Basis |
|---|---|---|---|
| H1 | Armor may become perceptually weak against large hits | PARTIALLY_SUPPORTED | Armor's reduction is a flat/randomized absolute quantity (`uniform_random(armor/2, armor-...)`) that does not scale with the raw damage roll's magnitude — mechanically confirmed. Harness scenario 2 (section 17) shows the *marginal* benefit of +armor does not obviously collapse at high raw damage, but the *percentage* effective reduction does shrink as raw damage grows relative to a fixed armor value. Needs ChatGPT/numeric-threshold judgment on what counts as "perceptually weak." |
| H2 | Mitigation may be applied late enough to compress the value of armor/defense | CONTRADICTED_BY_SOURCE | Confirmed order is armor/defense (flat) → mitigation (%). A later percentage step reduces *its own* marginal value as prior flat reduction grows (mitigating a smaller remainder), not the value of the earlier flat step, which is already realized before mitigation runs. |
| H3 | Multiple attackers may saturate defense because blockCount is finite | CONFIRMED_BY_SOURCE | `blockCount` (cap 2, +1/sec, shared per defender) gates the shield/weapon defense roll only; armor is unaffected. Direct source confirmation, section 9 / COMBAT-C-003. |
| H4 | Fight mode may influence more defensive variables than expected | CONFIRMED_BY_SOURCE | 4 distinct live functions read `fightMode` for defense-side effects (`getDefense`'s zero-skill branch, `getDefenseFactor`, `calculateMitigation`'s `fightFactor`), plus a 5th dead-code duplicate (`getCombatTacticsMitigation`) and a 6th UI-only shadow formula (`attackTotal`, offense-side but same enum). Section 8 / COMBAT-C-009. |
| H5 | Weapon defense may apply without a shield | CONFIRMED_BY_SOURCE | `Player::getDefense()` explicitly uses `weapon->getDefense()+extraDefense` and `getWeaponSkill(weapon)` when no shield is equipped. Section 6/11 (player sub-report §3). |
| H6 | Percent absorption and finalDamageReduction may overlap or stack unexpectedly | PARTIALLY_SUPPORTED | The "canonical" `getFinalDamageReduction` formula is dead code (COMBAT-C-006), so no double-application occurs at runtime. The live inline loop does have a real, confirmed unintuitive nuance: additive-within-item, multiplicative-across-item stacking (section 7). |
| H7 | Monster armor/defense may flatten weapon-upgrade perception | NOT_ENOUGH_EVIDENCE | Mechanism (flat/random armor subtraction against a scaling raw-damage roll) directionally supports this, and harness scenario 2 shows the *percentage* effect does shrink at very high raw damage, but a rigorous, larger sweep (beyond this pass's "small sanity check only" mandate) is needed before a confident verdict. |
| H8 | Integer rounding may create or erase meaningful gear breakpoints | CONFIRMED_BY_SOURCE | Multiple concrete instances: `level/5` breakpoints (4+ locations), untracked mitigation truncation (COMBAT-C-005), untracked defense-formula truncation, dormant `armorMultiplier` truncation bug (COMBAT-C-008), leech rounding to exactly 0 at low values. Section 14. |
| H9 | Block visual effects may not communicate partial defense/armor reductions | CONFIRMED_BY_SOURCE | Unambiguous: the effect dispatcher is gated purely on `blockType != BLOCK_NONE`, itself gated purely on damage reaching exactly 0. Section 13 / COMBAT-C-002. |
| H10 | Player-vs-monster and monster-vs-player pipelines may not be symmetrical | PARTIALLY_SUPPORTED | Structurally overwhelmingly symmetric (one shared `combatBlockHit`/`doCombatHealth`/`getCombatDamage`/`applyExtensions`, polymorphic dispatch, not parallel duplicated code) — but 2 concrete, real asymmetries confirmed: the monster-only 30%-mitigation cap (COMBAT-C-001) and the monster-only `DISABLE_MONSTER_ARMOR` toggle with no player-side equivalent (COMBAT-C-010). |

## 17. Test harness design / small sanity checks

**Design:** a standalone Python module (kept outside the git repository per this pass's read-only mandate — not committed, not part of production code) mirroring the confirmed formulas: `normal_random`/`uniform_random` (byte-for-byte port of `tools.cpp:455-475`'s distribution shapes), player melee damage range, armor/defense/mitigation reduction steps in the confirmed order (section 6), item-absorb stacking, monster elemental resist, and a `BlockCountPool` class modeling the shared 2-charge/second defense-roll pool (section 9).

**Explicit limitation, per this pass's own mandate ("must first mirror engine formulas exactly before results are trusted", "small sanity checks only, no large balancing campaigns"):** this harness has been cross-checked against cited source line-by-line for the formulas it implements, but has **not** been validated against a live running server (none exists in this environment). The multi-attacker scenario (§3 below) is a crude approximation (fewer samples per attacker count, not a real time-stepped simulation of concurrent hits against a shared `blockCount` clock) and is explicitly flagged as such — a rigorous version needs real discrete-event timing, which is future-pass scope.

**Small sanity-check results (N=2000 samples/scenario, seed=1234, reproducible):**

1. **Armor sweep** (level 200, skill 100, weapon attack 45, ATTACK mode) vs. monster armor 0/20/50/100/200: effective reduction rose from 0% → 6.3% → 16.0% → 32.0% → 61.7%, confirming armor's percentage contribution scales with the armor:raw-damage ratio, not a fixed floor.
2. **Marginal +50 armor benefit** at fixed high raw damage (level 400, skill 130, attack 80): marginal reduction per +50 armor ranged 17-46 damage/hit across the 0-300 armor sweep, non-monotonic in this run — worth a larger, seeded/averaged re-run before treating the non-monotonicity as meaningful rather than sampling noise.
3. **Multi-attacker blockCount saturation** (crude approximation, see limitation above): effective reduction across 1/3/6 simultaneous attackers showed only a small drop (34.6% → 33.9% → 33.8%) in this crude model — this likely **understates** the real effect, since the harness does not model the temporal dynamics of the shared 2-charge/second pool under truly concurrent hits; flagged as needing a proper discrete-event version before drawing conclusions.
4. **Physical vs. elemental path** (identical raw damage, identical target stats): physical path final mean 424.8 vs. elemental path final mean 456.3 — elemental damage (skipping armor+defense entirely per COMBAT-C-004) is measurably higher, quantitatively confirming the mechanism's real-world magnitude in this synthetic scenario.

Full script and exact commands are in section 20.

## 18. Unknowns / unresolved source questions

- Exact intended relationship between a weapon's built-in elemental split and an elemental imbuement on the same weapon (COMBAT-C-012) — needs design-intent clarification, not further source archaeology.
- Whether the two independent PvP damage-reduction passes (COMBAT-C-011) are intentionally layered or a historical accident.
- Whether `Player::getFinalDamageReduction`'s dead closed-form absorb formula (COMBAT-C-006) represents an *intended* future replacement for the live inline loop, or abandoned code — could not be determined from source alone (no comments/TODOs found referencing it).
- Whether any monster type in `data-otservbr-global/monster/` bypasses `register_monster_type.lua`'s `elements` clip via a raw `addElement` call (COMBAT-C-013) — not checked this pass (would require a full monster-file grep sweep, deferred to keep this pass's scope to the engine-level architecture).
- Whether this specific server's actual runtime config (as opposed to `config.lua.dist`'s default) sets `disableMonsterArmor` to `true` (COMBAT-C-010) — not checked this pass (no live `config.lua` was located/inspected; only the `.dist` template).
- The `BUFF_DAMAGEDEALT`/`BUFF_DAMAGERECEIVED` double-application question flagged by the player-defense sub-report (section 6 of that report) was not fully disambiguated — the two call sites appeared to be gated by different conditions but this was not conclusively resolved.
- No authoritative Tibia-Global reference data was consulted this pass (out of scope — this is Canary-source-only archaeology per the task's own framing); none of the above findings should be read as claims about deviation from Global behavior.

## 19. Suggested follow-up evidence tasks for ChatGPT

1. Determine whether COMBAT-C-002 (binary block-effect feedback) and COMBAT-C-003 (blockCount saturation) together are sufficient to explain the "feels less perceptible than expected" complaint, or whether a deeper numeric imbalance (requiring the full harness treatment, beyond this pass's small-sanity-check mandate) is also needed.
2. Decide the severity and intended fix (if any) for the two dead-code findings (COMBAT-C-006, COMBAT-C-007, COMBAT-C-016) — remove, wire in, or leave.
3. Clarify design intent for COMBAT-C-012 (imbuement/weapon elemental split) and COMBAT-C-011 (double PvP reduction) — these are intent questions, not further-archaeology questions.
4. Authorize (or scope down) a rigorous, larger-scale harness campaign (proper discrete-event multi-attacker simulation, full breakpoint sweep across level/skill/gear ranges) as a distinct future pass, since this pass was explicitly bounded to "small sanity checks only."
5. Confirm whether this server's live config sets `disableMonsterArmor` away from its documented-nowhere default (COMBAT-C-010) — this single config fact materially changes how several other findings should be weighted.
6. If Global reference data becomes available, a future pass should cross-check the formula *shapes* found here (e.g. the 0.085/0.09 melee/distance coefficients, the level*2+magic*3 spell weighting) against known Global constants — this pass deliberately made no such comparison.

## 20. Exact commands/scripts used

Repo verification:
```
git status --short
git rev-parse HEAD
git branch --show-current
```

Source discovery (representative; the four parallel research agents each ran dozens of targeted `Grep`/`Read` calls — full call logs are in their respective task transcripts, not reproduced here):
```
git fetch origin main
git checkout main
git pull --ff-only origin main
grep -n "disableMonsterArmor\|DISABLE_MONSTER_ARMOR" src/config/configmanager.cpp src/config/config_enums.hpp
grep -n "normal_random\|uniform_random" src/utils/tools.cpp
```

Harness (full source in this pass's scratch directory, not committed to the repository):
```
python combat_harness.py
```
Harness formulas were each individually cross-cited against the exact `file:line` shown in sections 4-14 above before the sanity check was run. Output of that run is quoted verbatim in section 17.

No repository files were created, modified, or staged as part of this investigation, other than this document itself (`docs/ai-dev/combat/01_COMBAT_ROOT_ARCHITECTURE_CLAUDE_DISCOVERY.md`).
