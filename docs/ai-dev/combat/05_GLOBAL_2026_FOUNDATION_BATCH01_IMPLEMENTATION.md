# Global 2026 Vocation/Combat — Production Foundation Batch 01

**PRODUCTION IMPLEMENTATION. DRAFT PR. NOT MERGED. NOT MARKED READY.**

This batch intentionally does **not** claim the Global 2026 combat/vocation update is complete. It
implements only the closed-spec, safe-foundation items explicitly authorized in this pass. Every item
listed as EXPLICITLY DEFERRED in the governing task was left untouched — this document does not revisit
that list.

## Base / branch / commits

- Required base: `main @ 4209ba583a4dcb2ae528750dcfeb2e7c0109863a` — verified exact match via `git rev-parse origin/main` before branching. No deviation.
- Branch: `ai-dev/global-combat-2026-foundation-01`, created directly from `main` (not from the analysis branch — `docs/ai-dev/combat` passes 01-04 were not pulled into this branch's history; this handoff document is the only file added under that path, in its own commit).
- Commits (in order): **A** "GLOBAL 2026: current-client tactics protocol compatibility", **B** "GLOBAL 2026: proven foundation numeric/system deltas", **C** "GLOBAL 2026: targeted tests and handoff corrections" (this document).

## Changed files (15 total)

Commit A (4 files): `src/server/network/protocol/protocol_profile.hpp`, `protocol_profile.cpp`, `protocolgame.cpp`, `tests/unit/server/network/protocol/multiprotocol_test.cpp`.

Commit B (11 files): `src/io/io_wheel.cpp`, `src/creatures/players/components/wheel/wheel_gems.cpp`, `data/events/scripts/party.lua`, `data/scripts/actions/items/potions.lua`, `data/scripts/runes/explosion.lua`, `data/scripts/runes/intense_healing_rune.lua`, `data/scripts/runes/ultimate_healing_rune.lua`, `data/scripts/spells/healing/wound_cleansing.lua`, `data/scripts/spells/healing/fair_wound_cleansing.lua`, `data/scripts/spells/healing/intense_wound_cleansing.lua`, `data/scripts/spells/support/blood_rage.lua`.

Commit C (1 file): this document.

## A. Current-client (15.25) tactics protocol compatibility

**Not a blind cherry-pick.** Upstream commit `f7ae4d17ed1eb58621a9bed3e0a7d912b9eb9c32` was inspected directly (pass 03 already had its full diff on file); the Hokz baseline at this exact code region was independently re-read this pass and confirmed byte-identical to upstream's own pre-fix state, so the same verified behavior was manually re-typed into our own file structure/history rather than applied as a patch.

**Before:** `ProtocolGame::parseFightModes` always read 3 bytes as `fightMode, chaseMode, secureMode` for every protocol profile, including the modern client — but the real 15.25 client sends `chaseMode, secureMode, pvpMode` instead. Reading those 3 bytes under the wrong layout meant the server interpreted the client's Secure byte as the Chase byte (e.g. Stand+Secure got misread as Chase enabled). `ProtocolGame::sendFightModes` had the symmetric bug on the write side.

**After:** a new `ProtocolFeature::TacticsWithoutFightMode` flag (`protocol_profile.hpp`) is added to the `"current"` profile's feature mask only (`protocol_profile.cpp`) — no other profile's feature mask was touched. `parseFightModes` now branches: if the connecting client's profile has this feature, it reads exactly `chaseMode, secureMode, (discarded pvpMode byte)` and calls `Game::playerSetFightModes` with the internal `fightMode` hardcoded to `FIGHTMODE_ATTACK` (matching upstream's own verified compatibility choice — this batch does **not** rework `FightMode_t` or its consumers, per the explicit boundary; `FIGHTMODE_ATTACK` is simply the pre-existing default value, passed through unchanged). `sendFightModes` gets the symmetric write-side branch. Every other protocol profile (Tibia 11.00, 8.60 variants) is completely unaffected — `TacticsWithoutFightMode` was added to zero other profiles' feature masks, so `hasProtocolFeature` returns `false` for them and they take the original, unmodified code path.

**Boundary respected:** `FightMode_t` was not removed. `Player::getAttackFactor`/`getDefenseFactor` were not touched. Mitigation architecture was not touched. This is wire-format compatibility only.

**Tests:** ported the two assertion lines upstream added to `tests/unit/server/network/protocol/multiprotocol_test.cpp`'s existing `CurrentAnd1100UseDifferentInitialWireBehavior` test: `EXPECT_TRUE(current.hasFeature(ProtocolFeature::TacticsWithoutFightMode))` and `EXPECT_FALSE(tibia1100->hasFeature(ProtocolFeature::TacticsWithoutFightMode))`.

## B. Proven foundation numeric/system deltas

**B1 — Wheel Dedication mitigation multiplier** (`src/io/io_wheel.cpp:19`): `#define MITIGATION_INCREASE 0.03` → `0.075`. Type/accumulation path traced before editing: `bonusData.mitigation` is `float` (`wheel_definitions.hpp:290`); every one of the 8 call sites computes `MITIGATION_INCREASE * points` in pure floating-point arithmetic (`points` is `uint16_t`, promoted to `double` by the literal, narrowed to `float` on assignment) — no integer truncation anywhere in the chain. A single shared macro edit updates all 8 consuming Wheel-slot handlers uniformly; no other `0.03`-valued mitigation constant exists elsewhere.

**B2 — Lesser Gem mitigation multiplier** (`src/creatures/players/components/wheel/wheel_gems.cpp:157`): the `WheelGemBasicModifier_t::General_MitigationMultiplier` case's base value `500` → `2000`. This is a dedicated `case` for this one modifier only (verified not shared with any other stat). Combined with the existing, unmodified grade-multiplier table (`1.0/1.1/1.2/1.5`) and the existing, unmodified `getStat(...)/100` consumption in `PlayerWheel::getMitigationMultiplier()`, this produces exactly `20/22/24/30%` at grades 0-3 (`2000×{1.0,1.1,1.2,1.5}/100`). The base mitigation formula itself (`PlayerWheel::calculateMitigation`) was not touched.

**C — Explosion rune area** (`data/scripts/runes/explosion.lua:6`): `AREA_CIRCLE1X1` (a 5-tile plus/cross shape — center + 4 orthogonal neighbors) → `AREA_SQUARE1X1` (`register_spells.lua:488-492`), an **already-existing** true 3×3 block matrix (8 surrounding tiles + center = 9 tiles) — no new area constant was defined, per the task's own preference for reuse. Damage formula, mana, level, and every other rune property untouched.

**D — Group XP diversity bonus** (`data/events/scripts/party.lua`): confirmed this is the sole runtime source of truth — `Party::shareExperience` (C++) only dispatches to this Lua callback and applies stamina boosts; no duplicate formula exists in C++. `Party::getUniqueVocationsCount()` (`party.cpp:77-94`) was independently confirmed to already correctly deduplicate same-vocation party members (an `unordered_set` keyed on `vocation->getBaseId()`, capped at 4) — no change needed there. The prior quadratic formula (`0.1n²-0.2n+1.3`, with an ad hoc `-0.1` correction at partySize≥4) was replaced with a direct lookup table `{1:1.2, 2:1.35, 3:1.70, 4:2.0}` — the 1- and 4-vocation results are unchanged from the old formula's own output; only 2 and 3 were adjusted to the required 35%/70%. The lookup approach was chosen because the four target points (1.2/1.35/1.70/2.0) are not smoothly quadratic, so no coefficient-only edit to the old formula could hit all four exactly; the table is provably exhaustive since `getUniqueVocationsCount()` is hard-capped at 4.

**E — Ultimate/Intense Healing Rune self-only** (`data/scripts/runes/{ultimate,intense}_healing_rune.lua`): both scripts already read the target creature id via `var:getNumber(1073762188)` for their existing Monster-rejection check (this call ignores its argument — `Variant:getNumber()` takes none — the constant is a pre-existing, functionally-inert artifact in the original code, left untouched). Added one additional check immediately after the existing Monster check: if a target id was resolved (`targetId ~= 0`) and it differs from the caster's own id, reject with `"You can only use this rune on yourself."` and the existing `CONST_ME_POFF` feedback pattern. Self-cast (`targetId == player:getId()`) and the no-explicit-target case (`targetId == 0`, relevant given `COMBAT_PARAM_TARGETCASTERORTOPMOST` is already set) both remain allowed. All other restrictions/cooldowns/mana/charges/formulas untouched.

**F — Great Mana Potion vocation access** (`data/scripts/actions/items/potions.lua:48`, item id 238): removed the `vocations = {SORCERER, DRUID, PALADIN, MONK}` restriction entirely (Knight was the only excluded vocation) and updated the rejection-message `description` field to drop the now-inapplicable vocation phrasing (it only fires on the level-too-low path now, matching the phrasing convention of sibling vocation-unrestricted entries like item 237). Level requirement (80), mana range (150-250), and flask id (284) all unchanged. **Traced and confirmed no other gate exists**: the great mana keg (id 25910) and cask (id 25891) refill mechanic (`data/scripts/actions/objects/cask_and_kegs.lua`) has **no vocation check anywhere** — it already worked for any vocation, transforming empty flasks into item 238 regardless of who used it; the only vocation gate in the whole Great Mana pipeline was the one just removed (the drink action). No daily-reward or store gate references this item's vocation restriction. No other potion family was touched.

**G — Knight healing mana costs**: `wound_cleansing.lua` 40→60, `fair_wound_cleansing.lua` 90→135, `intense_wound_cleansing.lua` 200→300. Single `spell:mana(...)` literal changed in each file — formulas, cooldowns, shielding/magic-level scaling, and proficiency perks all untouched, per the explicit boundary.

**H — Blood Rage numeric hotfix only** (`data/scripts/spells/support/blood_rage.lua:4`): `CONDITION_PARAM_SKILL_MELEEPERCENT` `135` (+35%) → `125` (+25%). **Only this literal changed.** Duration (10000ms), damage-received modifier (115/+15%), `CONDITION_PARAM_DISABLE_DEFENSE`, and the Blood Rage/Protector mutual-exclusion subid are all untouched.

**`BLOOD_RAGE_NUMERIC_MATCH_ONLY` — stance architecture still pending.** This edit makes the existing legacy `CONDITION_ATTRIBUTES`-based implementation grant the numerically-correct +25% bonus; it does **not** convert Blood Rage into a proper Global-2026 stance (persistent, session-surviving, no-fight-mode-dependent). That architecture work is explicitly deferred (see the governing task's EXPLICITLY DEFERRED list — "Knight stance architecture").

## I — Chained Penance initial range: PARAMETER_COUPLING_BLOCKER

**Not implemented, per the task's own explicit escape hatch.** Traced the full chain-targeting call path before touching anything:

- `chained_penance.lua`'s `getChainValue(creature)` returns `targets, 3, false` — the second value is `chainDistance`, a single scalar.
- `Combat::doCombatChain` (`combat.cpp:1294-1304`) calls `params.chainCallback->getChainValues(caster, maxTargets, chainDistance, backtracking)` **once** per cast, producing one `chainDistance` value.
- That single value is passed into `Combat::pickChainTargets` (`combat.cpp:1727`), whose internal `while` loop (`combat.cpp:1748-1789`) uses the **exact same `chainDistance` variable, unconditionally, on every iteration** — the very first hop (from the caster/initial target) and every subsequent hop all share the identical radius. There is no per-iteration or first-vs-later distinction anywhere in this function.
- `ChainCallback` (`combat.cpp:2007-2058`, `combat.hpp:60-75`) stores exactly one `m_chainDistance` member — there is no `initialChainDistance`/`hopChainDistance` pair, and the Lua `CALLBACK_PARAM_CHAINVALUE` contract (consumed identically by `chained_penance.lua` and other chain-spells, e.g. Spiritual Outburst) only ever returns one distance value.

**Verdict:** the current Canary architecture does **not** already support a clean initial-vs-hop separation — implementing one would require extending `ChainCallback`'s constructor/storage, `getChainValues`' output signature, `pickChainTargets`' parameter list and loop logic to use a different radius on the first iteration, and the shared Lua `CALLBACK_PARAM_CHAINVALUE` contract every chain-spell relies on. This is new shared-engine architecture, not a surgical single-spell fix, and the task explicitly instructs to STOP and report `PARAMETER_COUPLING_BLOCKER` rather than silently assume both should become 4 (which would also raise Chained Penance's *every subsequent hop* range from 3 to 4, an unauthorized, unverified change beyond "initial range" alone) or attempt new architecture outside this batch's closed scope. **`chained_penance.lua` was not modified.** `spiritual_outburst.lua` was not touched, per the explicit instruction.

## Validation

```
git diff --check -> clean
Changed files: 15 (4 protocol/test, 11 content/wheel)
luaparser.ast.parse on all 9 changed Lua files -> OK, 0 failures
python -m tools.canary_audit validate-schemas -> All Canary audit schemas are valid
python -m unittest discover -s tools/canary_audit/tests -t . -p "test_*.py" -> Ran 72 tests, OK (skipped=3, environment-only)
python -m tools.canary_audit scan --profile otservbr-global --fail-on error
  -> Findings: 823 (error: 4, warning: 484, info: 335) - IDENTICAL to established baseline
  -> 4 blocking findings, all 4 the pre-existing baseline (item ids 2874, 3452, 6276, 12724) - zero new
```

**No C++ build toolchain is available in this environment** (no `cmake`/`ninja`/`g++`/`clang++` on PATH — confirmed this pass, consistent with every prior pass's disclosure). The 5 C++/test file edits (protocol_profile.hpp/.cpp, protocolgame.cpp, io_wheel.cpp, wheel_gems.cpp, multiprotocol_test.cpp) were **not compiled or executed** — validated instead by: (a) direct byte-for-byte comparison against the upstream-proven pattern for the protocol change, (b) manual diff review for balanced braces/syntax, (c) explicit type/accumulation tracing for both mitigation numeric edits (sections B1/B2 above) confirming no truncation or shared-constant collision. This is disclosed honestly, not fabricated as a passing build.

### Behavioral matrix (static/source-verified — no live server exists to execute these at runtime)

| # | Case | Result |
|---|---|---|
| 1 | Current-client Stand+Secure does not become Chase | PASS — new branch reads `chaseMode` then `secureMode` in the verified correct order (was previously misreading `secureMode` as `chaseMode` under the old 3-byte layout) |
| 2 | Wheel Dedication 0.075 | PASS |
| 3 | Lesser Gems 20/22/24/30 | PASS (2000×{1.0,1.1,1.2,1.5}/100) |
| 4 | Explosion 9 tiles | PASS (`AREA_SQUARE1X1` matrix: 8+center=9) |
| 5 | party 2 voc = 35% | PASS |
| 6 | party 3 voc = 70% | PASS |
| 7 | party 4 voc unchanged = 100% | PASS (table value 2.0, identical to prior formula's own output) |
| 8 | UH self allowed | PASS |
| 9 | UH other-player blocked | PASS |
| 10 | IH self allowed | PASS |
| 11 | IH other-player blocked | PASS |
| 12 | Knight Great Mana allowed | PASS (vocation restriction removed) |
| 13 | old Great Mana users remain allowed | PASS (no restriction at all now — strict superset) |
| 14 | Wound mana 60 | PASS |
| 15 | Fair mana 135 | PASS |
| 16 | Intense mana 300 | PASS |
| 17 | legacy Blood Rage numeric bonus 25% | PASS |
| 18 | Chained Penance initial radius 4 | **PARAMETER_COUPLING_BLOCKER** — not implemented, reported per section I above |

## Unresolved / deferred items

Every item in the governing task's EXPLICITLY DEFERRED list remains untouched — not re-enumerated here in full; see that task for the complete list. Two items warrant explicit callouts beyond the deferred list itself:

- **Item I (Chained Penance)**: blocked, not deferred by choice — see section I. Resolving it requires a scoped architecture decision (extend `ChainCallback`/`pickChainTargets`/the Lua chain-value contract) that ChatGPT should authorize as its own follow-up item, not silently absorbed into a future vocation-mechanics batch without the same scrutiny.
- **Blood Rage (item H)**: numerically correct now, but `BLOOD_RAGE_NUMERIC_MATCH_ONLY` — the underlying legacy `CONDITION_ATTRIBUTES` implementation is not a stance and does not persist across sessions; full Knight stance architecture remains a separate, larger, deferred item.

No claim is made that the Global 2026 combat/vocation update is complete. This is a foundation batch only.

## Draft PR

Opened as a **draft** PR from `ai-dev/global-combat-2026-foundation-01` into `main`. Not marked ready for review. Not merged.
