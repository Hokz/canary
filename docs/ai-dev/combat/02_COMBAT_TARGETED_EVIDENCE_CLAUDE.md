# Canary Combat System — Targeted Evidence / Red Team Pass 02

**READ-ONLY. NO PRODUCTION CODE MODIFIED. ANALYSIS BRANCH ONLY.**

Origin: CLAUDE (Investigative Engineer / Red Team / Evidence Collector). ChatGPT remains the exclusive
official auditor, Global-reference interpreter, severity classifier, and merge authority. Nothing below
is a severity assignment, a Global-exact/wrong claim, a fix, or a directive change. Several items below
were explicitly framed by ChatGPT as questions to falsify, not pre-approved bugs — verdicts reflect what
the source evidence actually shows, including where a suspicion was rejected or only partially supported.

## 1. Baseline and branch

- Production baseline under audit: `main @ 4209ba583a4dcb2ae528750dcfeb2e7c0109863a` (unchanged — verified, not modified this pass).
- Analysis branch: `ai-analysis/combat-root-discovery-claude-01`.
- Prior evidence commit on this branch: `cd81441f4ee683df235987f272a6f2261eeab245` (pass 01).
- This pass adds one new commit to the same branch (SHA reported in the final chat response), containing only `docs/ai-dev/combat/02_COMBAT_TARGETED_EVIDENCE_CLAUDE.md`, an updated `docs/ai-dev/combat/combat_harness.py`, and `docs/ai-dev/combat/02_harness_microtests.txt`.

## 2. Raw call-site evidence A1-A5

**A1. `Player::getFinalDamageReduction`**
Command: `Grep "getFinalDamageReduction" (repo-wide)`
Matches: `src/creatures/players/player.hpp:1963` (declaration), `src/creatures/players/player.cpp:5644` (definition). No other matches in `src/`, `data/`, or `data-otservbr-global/`.
Verdict: **NO_RUNTIME_CALLER_FOUND**

**A2. `Player::calculateDamageReductionFromEquipedItems`**
Command: `Grep "calculateDamageReductionFromEquipedItems" (repo-wide)`
Matches: `player.hpp:1964` (declaration), `player.cpp:5658` (definition), `player.cpp:5647` (one call site — **inside `getFinalDamageReduction` itself**, A1's own body). No caller outside that dead function.
Verdict: **NO_RUNTIME_CALLER_FOUND** (its only caller is itself dead code)

**A3. `Player::getCombatTacticsMitigation`**
Command: `Grep "getCombatTacticsMitigation" (repo-wide)`
Matches: `player.hpp:862` (declaration), `player.cpp:736` (definition). No other matches anywhere.
Verdict: **NO_RUNTIME_CALLER_FOUND**

**A4. `Weapon::getCombatDamage` (base `Weapon` class member, distinct from `Combat::getCombatDamage`/`Creature::getCombatDamage()`/`Lua::getCombatDamage`)**
Commands: `Grep "getCombatDamage" (src/, repo-wide within src)`, then `Grep "->getCombatDamage\(" (src/)` to isolate call sites specifically.
Matches for the declaration/definition: `src/items/weapons/weapons.hpp:75` (virtual declaration, signature `getCombatDamage(CombatDamage combat, const std::shared_ptr<Player> &player, const std::shared_ptr<Item> &item, int32_t damageModifier)`), `src/items/weapons/weapons.cpp:197` (definition). The narrower `->getCombatDamage(` grep across all of `src/` returned exactly one hit, `src/creatures/combat/combat.cpp:1493: auto creatureDamage = creature->getCombatDamage();` — a zero-argument call, which is `Creature::getCombatDamage()` (a different function, `creature.hpp:816`/`creature.cpp:2219`, a plain getter for a cached damage value), **not** the 4-argument `Weapon::getCombatDamage` overload. Zero call sites for the `Weapon`-class 4-arg overload were found.
Verdict: **NO_RUNTIME_CALLER_FOUND**

**A5. Direct `MonsterType`/`addElement` bindings or Lua `:addElement(` use outside the standard `register_monster_type.lua` path**
Commands: `Grep "addElement" (repo-wide)`, `Grep ":addElement\(" (data/, data-otservbr-global/)`, `Grep "addElement|AddElement" (src/lua/functions/creatures/monster/monster_type_functions.cpp)`.
Findings:
- The single C++ Lua binding: `src/lua/functions/creatures/monster/monster_type_functions.cpp:87`: `Lua::registerMethod(L, "MonsterType", "addElement", MonsterTypeFunctions::luaMonsterTypeAddElement);`, defined at line 1087. **No clamp exists inside this C++ binding itself** (confirmed pass 01, re-confirmed this pass by re-reading the function — it stores `Lua::getNumber<int32_t>(L, 3)` directly into `elementMap` with no `std::clamp`).
- `Grep ":addElement\(" ` across all of `data-otservbr-global/` and `data/`: **exactly one file**, `data/scripts/lib/register_monster_type.lua` (the standard registration library itself, which applies the `[minElementalResistance, maxElementalResistance]` clip before calling `mtype:addElement(...)`).
- The only other repo-wide match for the bare substring `addElement` was `src/creatures/players/components/weapon_proficiency.cpp`'s `addElementCritical`/`WeaponProficiency::addElementCritical` — an unrelated function (weapon-proficiency critical-hit stat accumulation, matched only by substring overlap, not a monster-element binding).
Verdict: **NO_RUNTIME_CALLER_FOUND** for any bypass — every current monster in this repository's data registers its elements exclusively through the standard, clamped `register_monster_type.lua` path. (See section 10 for the fuller C-013 discussion, including the structural point that the engine-level binding itself still has no clamp, independent of current data being safe.)

## 3. FightMode dependency map

20 distinct code-level consumers (FM-001 through FM-020) plus 2 informational rows (a naming-collision false positive and a confirmed absence of persistence) were found. Full matrix:

| ID | file:function | read/write | runtime purpose | effect if combat modes disappear | removal difficulty | dependencies |
|---|---|---|---|---|---|---|
| FM-001 | `creatures_definitions.hpp:812-816` `FightMode_t` enum | type def | Defines `FIGHTMODE_ATTACK=1/BALANCED=2/DEFENSE=3` — exactly 3 values, no "none". | Deleted last, after all consumers migrate. | LOW | All rows |
| FM-002 | `player.hpp:1839` `FightMode_t fightMode = FIGHTMODE_ATTACK;` (private) | storage | Per-player state, defaults to ATTACK. | Field removed. | LOW | 4 of 12 `friend class` grants actually touch it (Game, ProtocolGame, PlayerFunctions, PlayerWheel) |
| FM-003 | `player.cpp:6120-6125` `Player::setFightMode()` | write | Sets field, triggers `sendStats()`+`sendSkills()`. | Deleted/stubbed. | LOW | Those two send calls are shared with unrelated systems — must not be removed wholesale |
| FM-004 | `player.cpp:822-833` `Player::getAttackFactor()` | read | Outgoing-damage multiplier 1.0/0.75/0.5. | Formula redesign needed. | **HIGH** | 7 live call sites in `weapons.cpp` scaling real damage rolls |
| FM-005 | `player.cpp:835-854` `Player::getDefenseFactor(bool sendToClient)` | read | Defense multiplier; has a `sendToClient` UI-simplified twin (0.5/0.75 constants) distinct from the real timing-aware server value. | Both formulas need resolving together. | **HIGH** | Feeds `getDefense()` (FM-009), live incoming-damage roll |
| FM-006 | `player.cpp:604-633` `Player::attackTotal()` | read (UI only) | Tooltip formula, 1.2/1.0/0.6 — different coefficients than FM-004's real 1.0/0.75/0.5. Never feeds back into combat math. | Trivial to stub. | LOW | Called from `protocolgame.cpp` (FM-017) |
| FM-007 | `player.cpp:736-756` `Player::getCombatTacticsMitigation()` | read | Third copy of the 0.8/1.0/1.2 fightFactor table. **Confirmed dead** (A3 above). | Trivial delete. | LOW | None — orphaned |
| FM-008 | `player_wheel.cpp:4033-4086` `PlayerWheel::calculateMitigation()` | read | `fightFactor` (0.8/1.0/1.2) baked into the **live incoming-damage mitigation %** for every hit a player takes. | Formula redesign, not a simple switch deletion — changes effective mitigation for every player. | **HIGH** | `Creature::mitigateDamage` (all incoming damage), Wheel "Combat Mastery" stacking |
| FM-009 | `player.cpp:784-792` zero-skill branch in `Player::getDefense()` | read | Flat `1`/`2` fallback when defense skill is 0. | Needs an explicit non-mode fallback. | MEDIUM | Also calls FM-005 unconditionally on the non-zero path |
| FM-010 | `weapons.cpp:203,225,483,632,652,879,918` | read | 7 sites reading `getAttackFactor()`, applied directly to melee/distance/ammo damage at hit-resolution time. | Most entangled consumer in the codebase. | **HIGH** | The actual live PvE/PvP damage pipeline |
| FM-011 | `creature.cpp:911-922` `Creature::mitigateDamage()` | read (indirect via `getMitigation()`) | No direct enum reference; behavior shifts the moment FM-008 changes. | N/A directly | MEDIUM | Monsters use a *different* override with no fightMode dependency at all |
| FM-012 | `creature.cpp:944-974` `Creature::blockHit()` | read (indirect via `getDefense()`) | Active-defense roll uses FM-009/FM-005-gated values. | N/A directly | MEDIUM | Shared with monster defense path (monster side has no fightMode dependency) |
| FM-013 | `protocolgame.cpp:2706-2722` `parseFightModes()` | read (opcode `0xA0`, client→server) | Parses raw mode byte + chase/secure bytes, calls `Game::playerSetFightModes`. | Handler removed or repurposed to chase/secure-only. | MEDIUM | Chase/secure mode share this packet and must be preserved separately |
| FM-014 | `protocolgame.cpp:1866-1868`, `.hpp:180` opcode `0xA0` dispatch | routing | Routes byte `0xA0` to FM-013. | Removed alongside FM-013. | LOW | Pure routing |
| FM-015 | `game.hpp:401`, `game.cpp:7029-7038` `Game::playerSetFightModes()` | write | Bridges protocol → `setFightMode`/`setChaseMode`/`setSecureMode` in one call. | Signature change (breaking for its one caller). | LOW | Only caller is FM-013 |
| FM-016 | `protocolgame.cpp:8473-8483` + `player.cpp:8390-8394` `sendFightModes()` (opcode `0xA7`, server→client) | write | **Confirmed entirely dead code** — never called anywhere, including at login or inside `setFightMode()`. | Trivial delete. | LOW | None — orphaned; opcode `0xA7` becomes fully unused |
| FM-017 | `protocolgame.cpp:5285-5596` Cyclopedia offence/defence stats + `9668-9910` `AddPlayerStats`/`AddPlayerSkills` (legacy packet) | read | Two independent packet builders both serialize `attackTotal`×3, `getDefense(true)`, `getMitigation()`. `AddPlayerSkills` is the one actually re-sent on every `setFightMode()` call. | Both keep working but payload composition/meaning changes. | MEDIUM | Must stay numerically consistent with each other and with FM-004/FM-008 — this is where the original UI/real-formula mismatch (COMBAT-C-009) lives |
| FM-018 | `lua_enums.cpp:609-612`/`.hpp:42` `initFightModeEnums()` | write (Lua binding, startup) | Registers the 3 constants as Lua globals. | Safe to delete unless a script reads them. | LOW | Any custom out-of-tree script referencing `FIGHTMODE_*` would break silently |
| FM-019 | `player_functions.cpp:374,3861-3870` `player:getFightMode()` | read (Lua binding) | Exposes raw `fightMode` int to scripts; no `setFightMode` Lua binding exists (write is protocol-only). | Stub/remove. | LOW | **Zero production Lua scripts under `data/` or `data-otservbr-global/` call this** — only a dead comment block (FM-020) references it |
| FM-020 | `data/modules/lib/modules.lua:15-28` `Player.updateFightModes()` | read (Lua) | **Entirely commented out** (`--[[ ... ]]`), never executed. | Delete freely. | LOW | None — dead comment |
| FM-021 (informational) | `imbuements.cpp:481,488`, `protocolgame.cpp:10663,10669` `isInFightMode` locals | read | **Naming collision, not a fightMode consumer** — reads `CONDITION_INFIGHT` (an unrelated in-combat flag), matched the grep only by variable name. | None — untouched by any fightMode change. | N/A | Flagged so it isn't miscounted |
| FM-022 (informational) | `src/io/*` (IOLoginData/Load/Save) | absent | `fightMode` is confirmed **never persisted** to the database (zero matches for `fightMode`/`chaseMode`/`secureMode` in `src/io/`) despite `IOLoginData*` all being granted friend access. Every login resets to `FIGHTMODE_ATTACK`. | No persistence code to remove. | LOW | None |

**Summary:** 7 `src/` files touch the symbol total — narrow in file-count, but two consumers are load-bearing for the live combat formula rather than cosmetic: `Player::getAttackFactor()` (FM-004, feeding 7 real damage-calculation sites) and `PlayerWheel::calculateMitigation()`'s `fightFactor` (FM-008, feeding the universal incoming-damage-mitigation path). Any removal that doesn't also redesign those two formulas would silently change every player's effective DPS and damage taken. Everything else is LOW/MEDIUM because it's either already unreachable (FM-007, FM-016, FM-020) or purely serializes a number outward. `Player::getSpeed()` and health/mana regeneration were checked explicitly and have **zero** fightMode references — no hidden cross-domain coupling was found. `fightMode` is never persisted (FM-022) and `sendFightModes()`/opcode `0xA7` is fully dead (FM-016) — the client apparently learns about mode-driven stat changes only indirectly via the `sendStats()`/`sendSkills()` calls `setFightMode()` triggers.

## 4. A001 — mitigation slot assumption

`PlayerWheel::calculateMitigation()` reads `inventory[CONST_SLOT_RIGHT]` as "the shield" and `inventory[CONST_SLOT_LEFT]` as "the weapon" directly, without type-checking.

1. **Weapon in RIGHT?** `Player::queryAdd`'s `CONST_SLOT_RIGHT` case (`player.cpp:4544-4585`) unconditionally returns `RETURNVALUE_CANNOTBEDRESSED` for any item where `getWeaponType() != WEAPON_SHIELD && !isQuiver()`, as long as the item's `slotPosition` still has its default `SLOTP_RIGHT` bit (true for every item unless explicitly overridden via `slotType="left-hand"` in XML). Repo-wide grep of `data*/items/items.xml` for `slotType="left-hand"`: **0 occurrences**. So no weapon in the current dataset can ever legally occupy RIGHT.
2. **Shield in LEFT?** `queryAdd`'s `CONST_SLOT_LEFT` case (`player.cpp:4587-4629`) explicitly rejects `type == WEAPON_SHIELD` (which also covers spellbooks, mapped to `WEAPON_SHIELD` in `WeaponTypesMap`) whenever `slotPosition & SLOTP_LEFT` is set (the default, confirmed for `steel shield`/`wooden shield`). No shield can legally occupy LEFT.
3. **Migration/legacy bypass?** Yes — `Player::internalAddThing` (`player.cpp:5987-6006`), used by the character-load path (`iologindata_load_player.cpp:568-570`), performs **zero type/slot validation**, placing an item into whatever `pid` slot the `player_items` DB row specifies. This is the only reachable bypass — via a stale DB row (a prior items.xml `weaponType` reclassification, direct DB edit, or bad migration/import), not any live in-game action. The scripted `Player:addItem` Lua API was independently confirmed to route through `Game::internalAddItem` → `queryAdd`, so it cannot bypass validation.
4. **Auto-correction makes the convention correct-by-construction for normal play**: `Game::getSlotType` auto-routes non-shield items toward LEFT and `WEAPON_SHIELD`-type items to RIGHT; `Game::playerEquipItem` actively force-unequips a conflicting two-hander/shield on equip. Both reinforce, not merely coincide with, the RIGHT=shield/LEFT=weapon assumption.
5. **Reachable misclassification?** None under any queryAdd-gated action (interactive or scripted). Only reachable via a stale legacy inventory row loaded through `internalAddThing`.

**Verdict: A001_EDGE_CASE_ONLY** — safe for all normal play; only breakable via a legacy/DB-load inconsistency outside live gameplay.

## 5. A002 — armor-only hits consume blockCount

1. `Creature::blockHit`'s `--blockCount;` (`creature.cpp:962`) is gated on `checkDefense || checkArmor`, with no dependency on `checkDefense` specifically — confirmed by direct quote (see pass 01/02 shared citation).
2. A `checkDefense=false` hit never enters `if (checkDefense && hasDefense && canUseDefense)`, so it gets no defense roll of its own — confirmed, no alternate path exists in either `Player::blockHit` or `Monster::blockHit`.
3. **Real sources of `checkDefense=false, checkArmor=true`**: `WeaponDistance`'s constructor (`weapons.cpp:666-670`) sets `params.blockedByArmor = true` and never sets `blockedByShield` — every ranged/distance weapon attack is such a hit. Any Lua spell/rune script calling `setCombatParam(combat, COMBAT_PARAM_BLOCKARMOR, true)` without the shield equivalent produces the same state. By contrast, melee (`WeaponMelee` ctor, bare fist) sets both flags together.
4. **`blockCount` is a single per-defender pooled counter** (`creature.hpp:898`, regenerated +1/1000ms capped at 2 in `Creature::onThink`), shared across every attacker and attack type hitting that defender — confirmed by grep that no other assignment site exists anywhere (not in spawn/login/respawn code), and initialization is uniformly `0` via the in-class default member initializer for every `Creature`-derived object.
5. A concrete, source-faithful sequence was traced: defender at `blockCount==1` → a distance hit lands (`checkDefense=false, checkArmor=true`) → consumes the sole charge, uses none of it (`hasDefense` becomes true but is never read since `checkDefense` is false) → a melee hit from the same or another attacker lands before the next 1000ms regen → `blockCount==0` → `hasDefense` stays false → the melee hit's own `checkDefense=true` path is starved, receiving zero shield/weapon-defense mitigation for that swing (armor still applies independently).

**Verdict: A002_SUPPORTED**

## 6. A003 — DISABLE_MONSTER_ARMOR multiplier fold-in

`Monster::getDefense()` returns `mtypeDefense * getDefenseMultiplier()`; `Monster::getArmor()` returns `info.armor * getDefenseMultiplier()` — both **already** scaled by the multiplier in their own return statements. `Monster::getMitigation()`'s `DISABLE_MONSTER_ARMOR` branch then computes `ceil((getDefense()+getArmor())/100) * getDefenseMultiplier() * 2.f` — applying the same multiplier a second time to values that already carry it once.

Numeric table (raw base defense=100, armor=100, i.e. sum=200 before any multiplier):

| multiplier | getDefense() | getArmor() | sum | ceil(sum/100) | fold-in contribution |
|---|---|---|---|---|---|
| 1.0 | 100.0 | 100.0 | 200.0 | 2 | 2 × 1.0 × 2 = **4.0** |
| 1.1 | 110.0 | 110.0 | 220.0 | 3 | 3 × 1.1 × 2 = **6.6** |
| 1.5 | 150.0 | 150.0 | 300.0 | 3 | 3 × 1.5 × 2 = **9.0** |
| 2.0 | 200.0 | 200.0 | 400.0 | 4 | 4 × 2.0 × 2 = **16.0** |

Growth from multiplier 1.0→2.0 is 4.0→16.0 (4× for a 2× multiplier increase) — matching a `4·m²` quadratic trend (a purely-linear relationship would predict 8.0, not 16.0), with the `ceil()` producing step-function noise on top of that trend rather than a smooth parabola. `Monster::getMitigation()`'s final `std::min<float>(mitigation, 30.f)` cap does not mask this for the realistic single-digit-base range shown (values sit well under 30); it only masks the effect once the fold-in itself pushes past ~30 at higher multipliers/bases.

**Verdict: A003_SUPPORTED**

## 7. A004 — secondary reflection component bug

`Game::combatBlockHit`'s secondary-reflect branch (`game.cpp:7973-8028`) splits into two sub-cases on whether primary reflect already fired (`canReflect`).

**`!canReflect` sub-case** (secondary reflect is the only one active) — the percent calculation is:
```cpp
int32_t reflectPercent = std::ceil(damage.primary.value * secondaryReflectPercent / 100.);
```
This is a verbatim copy of the primary branch's own line with only the percent variable swapped — `damage.primary.value` was left unchanged, i.e. it should read `damage.secondary.value` to be self-consistent with its own naming/type-tagging (`damageReflected.primary.type = damage.secondary.type` two lines later correctly uses secondary). A second leftover-primary reference exists at `damageReflectedParams.combatType = damage.primary.type` (unchanged from the copy-pasted primary branch).

Traced component matrix (post-mitigation values as basis):
- **Row 1** (primary=100, secondary=50, only `secondaryReflectPercent=20` active): code computes `ceil(100*20/100)=20`; self-consistent basis would give `ceil(50*20/100)=10` — a **2× overstatement**.
- **Row 2** (primary=0, secondary=50, `secondaryReflectPercent=20`): code computes `ceil(0*20/100)=0`; self-consistent basis would give `10`. **The bug can silently suppress an active elemental reflect to exactly zero** when the physical component happens to be zero.
- **Row 3** (both `primaryReflectPercent=10` and `secondaryReflectPercent=20` active): the primary block computes `damageReflected.primary.value=10` first (`canReflect=true`); the secondary block then enters the **`else` sub-case**, which **overwrites** (not sums) `damageReflected.primary.value = ceil(50*20/100) + max(-reflectLimit, max(50,0)) = 10+50 = 60` — the primary contribution of 10 is discarded entirely, and a second, separate composition error inflates the result by the raw (not percent-scaled) secondary damage value.
- **Row 4** (components have different post-reduction values due to unequal resistance): the `!canReflect` path mixes components (uses the OTHER component's post-reduction value); the `else` path uses the correct own-component value for its percent term but then corrupts the composition as shown in Row 3.

No downstream compensation was found — `Combat::doCombatHealth` processes the resulting `damageReflected` object as-is against the original attacker; the erroneous magnitude flows through uncorrected.

**Verdict: A004_SUPPORTED**

## 8. A005 — pre-mitigation blockType callback

`Creature::blockHit` calls `attacker->onAttackedCreatureBlockHit(blockType)` (`creature.cpp:997`) **before** `mitigateDamage(combatType, blockType, damage)` (`creature.cpp:1001`), and `mitigateDamage` can itself promote `blockType` to `BLOCK_ARMOR` if the Wheel mitigation % reduces the remaining damage to exactly 0.

`Player::onAttackedCreatureBlockHit` (the only non-trivial override — `Monster` has none, inheriting the empty base no-op) materially consumes its `blockType` argument: sets `lastAttackBlockType`, and on `BLOCK_NONE` unconditionally sets `addAttackSkillPoint=true` plus **resets** `bloodHitCount`/`shieldBlockCount` to 30, versus on `BLOCK_DEFENSE`/`BLOCK_ARMOR` only conditionally setting the skill flag and **decrementing** those same counters. `WeaponDistance::getSkillType` further branches directly on `lastAttackBlockType`, granting 2 skill points for `BLOCK_NONE` vs. 1 for `BLOCK_DEFENSE`/`BLOCK_ARMOR`.

Traced scenario: armor+defense alone leave `damage>0` (`blockType` stays `BLOCK_NONE` at the callback call site) → callback receives `BLOCK_NONE`, resets both counters to 30, grants the skill point unconditionally (2 points if a distance weapon) → **then** `mitigateDamage` reduces the remainder to 0 and promotes the LOCAL `blockType` to `BLOCK_ARMOR` → `Creature::blockHit` returns `BLOCK_ARMOR` → `Game::combatBlockHit` reads this returned (corrected) value directly for `InternalGame::sendBlockEffect`, so the **visual effect shows BLOCK_ARMOR** while the **attacker's skill-training bookkeeping was already computed against BLOCK_NONE**. These two consumers of "what block type was this hit" observably disagree for every hit fitting this pattern, only when the attacker is a `Player` (Monster's override is a no-op).

**Verdict: A005_SUPPORTED**

## 9. C-012 — native element + elemental imbuement applicability

The imbuement "Elemental Damage" category (id 0, `data/XML/imbuements.xml`) is gated onto an item purely by whether that item's `items.xml` `imbuementslot` sub-attributes whitelist the category (`Item::hasImbuementType`) and whether the item doesn't already carry another imbuement of the same category — **no check anywhere in the application path cross-references the item's own native/inherent elemental attack attribute** (`elementfire`/`elementice`/etc., set by `ItemParse::parseElement`). The rule and the native-element data are structurally independent.

Concrete, currently-shipped examples where both coexist:
- **Item 34155 "lion longsword"** — native `elementearth="44"`, `imbuementslot value="2"` explicitly whitelisting `"elemental damage"` (alongside life leech/mana leech/critical hit/skillboost sword).
- **Item 49523 "inferniarch battleaxe"** — native `elementfire="44"`, imbuement slots whitelist `"elemental damage"`.
- **Item 49876 "rending inferniarch blade"** — native `elementfire="44"`, imbuement slot whitelists `"elemental damage"`.

Runtime reachability was confirmed for the "lion longsword" case specifically: its native split (primary=physical, secondary=earth) passes `Combat::applyImbuementElementalDamage`'s `if (damage.primary.type != COMBAT_PHYSICALDAMAGE) break;` guard, so slotting a fire/death/etc. "Elemental Damage" imbuement would overwrite `damage.secondary.type`/`value` per the mechanism COMBAT-C-012 (pass 01) described — with real, shipped data, not a hypothetical. Not every native-elemental weapon whitelists this category (several checked items whitelist only leech/critical/skillboost), so the combination is item-specific, not universal, but a real non-trivial subset of shipped weapons permit it. The ammo/quiver path carries the identical rule but is currently data-inert: all 8 quiver items in `data/items/items.xml` have zero `imbuementslot` attribute.

**Verdict: CAN_COEXIST_LIVE** (with the `ONLY_SPECIFIC_CASES` nuance noted — permitted by rule for a real subset of items, not all)

## 10. C-013 — element resist clamp bypass surface

Consistent with section 2 (A5): the sole Lua binding for setting a monster's elemental resistance is `MonsterType:addElement(type, percent)` (`monster_type_functions.cpp:87,1087`), which performs **no clamping at the C++ level**. The `[minElementalResistance, maxElementalResistance]` clip (default `[-200,200]`) exists **only** inside `data/scripts/lib/register_monster_type.lua`'s own `elements` handler. A repo-wide grep for `:addElement(` across both `data/` and `data-otservbr-global/` found **exactly one caller**: that same registration library. No monster file in the current dataset calls `addElement` directly, and the only other repo-wide hit for the bare substring `addElement` (`weapon_proficiency.cpp`'s `addElementCritical`) is unrelated.

**Verdict: CURRENT_DATA_SAFE** — no live bypass exists in this repository's current monster data; every monster's elemental resistance is registered through the clamped path. Structural caveat (not a data-safety issue, a separate architectural fact): the clamp is enforced entirely by Lua-library convention, not by the engine itself — the C++ binding has **no guard of its own**, so the safety depends on every future monster file continuing to go through `register_monster_type.lua` rather than calling `addElement` directly or via some other future registration path.

## 11. Harness corrections

All seven required corrections (J1-J7) were implemented in `docs/ai-dev/combat/combat_harness.py` on this branch:

- **J1**: `cpp_round_half_away(x)` and `cpp_lround(x)` added, implementing round-half-away-from-zero (matching `std::round`/`std::lround`) — every prior bare `round()` call in the formula-mirror functions was replaced. `python_bankers_round_for_contrast()` is kept explicitly to demonstrate the divergence in the microtests.
- **J2**: `mitigate_cpp_exact(damage, mitigation_pct)` now computes `damage - reduction` fully in floating point and truncates the **final combined result** toward zero exactly once, matching the compound-assignment semantics of `creature.cpp:914`. The pass-01 buggy version (which truncated the reduction alone before subtracting) is kept, deliberately renamed `mitigate_PASS01_BUGGY_reference`, purely as a labeled contrast for microtest 2.
- **J3**: `BlockCountPool` now starts at `block_count=0`/`block_ticks=0` (matching `creature.hpp:898`'s default member initializer, corrected from pass 01's incorrect "starts full" assumption), and `advance(interval_ms)` implements the exact `blockTicks += interval; if >=1000: blockCount=min(+1,2); blockTicks=0` reset-to-exactly-0 behavior (not a modulo), preserving the same partial-tick drift the real engine has.
- **J4**: `DiscreteEventTimeline`/`build_attacker_schedule`/`run_discrete_event_timeline` replace the pass-01 "fewer samples per attacker count" approximation with a real time-ordered event simulation: configurable attacker count/interval/phase-offset, one shared `BlockCountPool` advanced by actual elapsed time between consecutive events, explicit event ordering. Demonstrated deterministically in microtest 10 (section 12).
- **J5**: `player_item_absorb_pipeline` now mirrors `player.cpp:3861-3919`'s exact nesting — per item, each imbuement slot's absorb is applied **individually** with `std::ceil`, sequentially against the shrinking damage; only after all of that item's imbuement slots does the item's own ability absorb (`absorbPercent+fieldAbsorbPercent`, summed once) apply as a separate `std::round`-rounded subtraction; the next item then repeats. Imbuement and item-ability percentages are no longer collapsed into one artificial group. `wheel_resistance_adjustment` is applied once, after all items, using `std::ceil` per `player_wheel.cpp:4024-4031`.
- **J6**: `RNG_LABEL = "DISTRIBUTION_SHAPE_APPROXIMATION"` added at module scope; the module docstring and `normal_random`'s own docstring now explicitly state that the underlying PRNG stream is not reproduced, only the distribution's shape (rejection-sampled-to-[0,1], mean 0.5, sd 0.25) is approximated — "byte-for-byte port" is no longer claimed anywhere.
- **J7**: `run_microtests()` implements exactly the required assertion set (10 microtests, all passing — see section 12) — no probabilistic campaign runs by default; `run_probabilistic_sanity_check()` (pass 01's scenarios, updated to call the corrected functions) is kept in the module but is not invoked from `__main__`, per this pass's "no large campaign" instruction.

## 12. Exact microtest outputs

Full output (from `python combat_harness.py`, saved verbatim to `docs/ai-dev/combat/02_harness_microtests.txt`):

```
=== J7 MICROTEST 1: C++ half-away rounding vs Python banker's rounding ===
[PASS] cpp_round_half_away(2.5) == 3
[PASS] cpp_round_half_away(-2.5) == -3
[PASS] cpp_round_half_away(0.5) == 1
[PASS] cpp_round_half_away(-0.5) == -1
[PASS] python round(2.5) == 2 (demonstrates the divergence this fix corrects)
[PASS] cpp_round_half_away(2.5) != python round(2.5) -- proves the bug pass-02 asked to fix

=== J7 MICROTEST 2: mitigation fractional-truncation-order case ===
[PASS] mitigate_cpp_exact(100, 33.7%) == 66 -- got 66
[PASS] mitigate_PASS01_BUGGY_reference(100, 33.7%) == 67 (the bug being demonstrated) -- got 67
[PASS] corrected and buggy mitigation functions disagree on this fractional case -- correct=66 buggy=67

=== J7 MICROTEST 3: blockCount starts at 0 ===
[PASS] BlockCountPool starts with block_count == 0
[PASS] BlockCountPool starts with block_ticks == 0

=== J7 MICROTEST 4: charge appears at exactly 1000ms ===
[PASS] no charge yet at 999ms -- got 0
[PASS] charge appears at 1000ms cumulative -- got 1
[PASS] block_ticks resets to exactly 0 (not -=1000) on threshold cross

=== J7 MICROTEST 5: blockCount caps at 2 ===
[PASS] block_count caps at 2 after many 1000ms advances -- got 2

=== J7 MICROTEST 6 (A002): an armor-only hit (checkDefense=False, checkArmor=True) consumes a charge ===
[PASS] 1 charge available before the armor-only hit
[PASS] armor-only hit IS counted as consuming an attempt
[PASS] armor-only hit receives NO defense roll for itself
[PASS] the shared charge was actually spent (pool now at 0) -- got 0
[PASS] a later melee hit in the same window is starved of its defense roll by the earlier armor-only hit

=== J7 MICROTEST 7: defense+armor path applies both, defense first ===
[PASS] defense then armor reduces sequentially (not summed independently) -- dmg=1000 defense_reduction=90 armor_reduction=47 expected_after_both=863

=== J7 MICROTEST 8: elemental hit bypasses defense+armor entirely (monsters.cpp:111-121) ===
[PASS] elemental path (is_physical=False) never consumes/uses defense+armor, so it takes MORE damage than the physical path at identical raw/mitigation -- physical=357 elemental=410
[PASS] elemental hit did not touch the blockCount pool at all -- pool_elem.block_count=1

=== J7 MICROTEST 9: J5 non-collapsed item/imbuement absorb order ===
[PASS] player_item_absorb_pipeline matches the hand-traced per-item nested order (imbuements sequentially, THEN item ability once) -- hand-traced=787 harness=787

=== J7 MICROTEST 10: discrete-event timeline mechanism (deterministic, no damage RNG) ===
  t=    0ms attacker=melee_A chargeAvailable=False gotDefenseRoll=False poolAfter=0
  t=   50ms attacker=ranged_C chargeAvailable=False gotDefenseRoll=False poolAfter=0
  t=  133ms attacker=melee_B chargeAvailable=False gotDefenseRoll=False poolAfter=0
  t=  400ms attacker=melee_A chargeAvailable=False gotDefenseRoll=False poolAfter=0
  t=  533ms attacker=melee_B chargeAvailable=False gotDefenseRoll=False poolAfter=0
  t=  800ms attacker=melee_A chargeAvailable=False gotDefenseRoll=False poolAfter=0
  t=  933ms attacker=melee_B chargeAvailable=False gotDefenseRoll=False poolAfter=0
  t=  950ms attacker=ranged_C chargeAvailable=False gotDefenseRoll=False poolAfter=0
  t= 1200ms attacker=melee_A chargeAvailable=True gotDefenseRoll=True poolAfter=0
  t= 1333ms attacker=melee_B chargeAvailable=False gotDefenseRoll=False poolAfter=0
  t= 1600ms attacker=melee_A chargeAvailable=False gotDefenseRoll=False poolAfter=0
  t= 1733ms attacker=melee_B chargeAvailable=False gotDefenseRoll=False poolAfter=0
  t= 1850ms attacker=ranged_C chargeAvailable=False gotDefenseRoll=False poolAfter=0
[PASS] discrete-event timeline produced a deterministic, non-empty, time-ordered event list
[PASS] defense-roll opportunities are bounded by the shared 2-cap regenerating pool, not by attacker count
  total_events=13 got_defense_roll_count=1 final_pool_block_count=0

ALL MICROTESTS PASSED
```

Microtest 10 is a concrete, deterministic demonstration of A002/COMBAT-C-003's mechanism: with 3 staggered attackers (two melee at 400ms intervals, one ranged at 900ms) over a 2000ms window, only **1 of 13** attack events received a defense-roll opportunity — not because of randomness, but because the shared, regenerating 2-charge pool is genuinely starved under this arrival pattern. This is a mechanism demonstration, not a balance conclusion — no damage values were rolled in this test.

## 13. Mantra runtime order and combat-type coverage

**Types accepted by `Combat::applyMantraAbsorb`** (`combat.cpp:630-650`): exactly `COMBAT_FIREDAMAGE`, `COMBAT_ICEDAMAGE`, `COMBAT_ENERGYDAMAGE`, `COMBAT_EARTHDAMAGE` — 4 types.
**Types excluded**: `COMBAT_PHYSICALDAMAGE`, `COMBAT_HOLYDAMAGE`, `COMBAT_DEATHDAMAGE`, `COMBAT_LIFEDRAIN`, `COMBAT_MANADRAIN`, `COMBAT_HEALING`, `COMBAT_DROWNDAMAGE`, `COMBAT_AGONYDAMAGE`, `COMBAT_NEUTRALDAMAGE`, `COMBAT_UNDEFINEDDAMAGE`.

Mantra's value source: `Player::getMantra()` sums a per-item `mantra` attribute across 7 equipment slots (purely item-data-derived, not a Wheel node directly), plus a party-shared component — `Party::updateMantraHolder`/`applyGuidingPresence` (`party.cpp:308-351`) elects the highest-mantra Monk with the Wheel "Guiding Presence" instant active as the party's `m_mantraHolder`, and grants every other member half that holder's mantra via `BUFF_MANTRA` (offset +100, hence `applyMantraAbsorb`'s `getBuff(BUFF_MANTRA) - 100`).

Exact runtime order, confirmed by direct quotation of `Game::combatBlockHit` (`game.cpp:7860-8000`) for both primary and secondary components independently: raw damage → `BUFF_DAMAGEDEALT`(attacker)/`BUFF_DAMAGERECEIVED`(target) buffs → **`Combat::applyMantraAbsorb` + the post-buff `std::max(...,0)` floor clamp, both inside `if (!condition) {...}`** → `target->blockHit(...)`, which internally runs `applyAbsorbDamageModifications` (generic condition-driven absorb) → defense/armor → `mitigateDamage` (Wheel %) → (Player only) the item/imbuement absorb loop → Wheel elemental-resistance adjustment. This matches the schematic given in the task exactly, with Mantra confirmed to run **strictly first**, entirely before `target->blockHit()` is even invoked — not interleaved with any of the later layers.

DoT/condition-tick hits (`condition=true`) skip Mantra and the floor clamp entirely via the confirmed `if (!condition) {...}` guard, for both primary and secondary components independently. `COMBAT_LIFEDRAIN`/`COMBAT_MANADRAIN` hits are **not** affected by Mantra (both types absent from the accepted-type check).

## 14. Unresolved questions

- Whether the A004 secondary-reflect mismatch and the A003 multiplier-squaring were introduced together (e.g. both from a single refactor pass) or independently — not determinable from source alone, no commit-history archaeology was performed this pass (out of scope for a source-only read).
- Whether A001's only reachable bypass (a stale `player_items` DB row surviving an items.xml `weaponType` reclassification) has ever actually occurred on this specific dataset's live history — not checked (would require DB/save-file inspection, not source archaeology).
- Whether any *out-of-tree* custom Lua script (not present in this repository) references `FIGHTMODE_*` globals or `player:getFightMode()` — cannot be determined from this repository alone (FM-018/FM-019).
- The exact intended relationship between the C-012 native-element/imbuement overwrite and design intent remains a question for ChatGPT/owner (not re-litigated here — this pass only answered the narrower "can they coexist in current data" question, confirming CAN_COEXIST_LIVE).
- Whether A004's Row 3 `else`-branch composition error (raw-value inflation via the `max(damage.secondary.value, -flat)` term) was intended to be a second, different clamp pattern that was implemented incorrectly, or something else entirely — flagged as observed, not diagnosed further (implementation-intent question, not a source-fact question).

## 15. No-authority statement

Every verdict in this document (A001-A005, C012, C013, A1-A5) is a CLAUDE-origin finding based on direct source citation, not a ChatGPT-validated conclusion. No severity was assigned. No claim was made about real Tibia Global's actual behavior (explicitly out of scope per the task's own instruction — Mantra's documented Global behavior, in particular, was deliberately not researched or referenced this pass). No fix was proposed or implemented anywhere in this document or the harness. No project directive was changed. All items remain `Status: UNVALIDATED` pending ChatGPT's independent review, exactly as in pass 01.
