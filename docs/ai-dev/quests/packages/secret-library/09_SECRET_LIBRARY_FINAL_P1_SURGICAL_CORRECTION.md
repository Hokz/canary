# Secret Library — Final P1 Surgical Correction

PR #37, branch `ai-dev/secret-library-full-repair-v2`. Executor-only pass. Scope: exactly the three P1
functional-mechanic defects the independent reviewer identified. No P2/P3/map/polish/Master Debater/
masterbook/central-wave-cadence/generic-combat-balance work performed.

## 0. Verified start state

- Branch: `ai-dev/secret-library-full-repair-v2`, working tree clean at pass start.
- HEAD at pass start: `42eff85808b2cfed13509dca28c80e1a4820d281` — matches the expected starting head
  exactly.
- PR #37: draft, open, not merged (unchanged by this pass).

## 1. Spellstealer Demon Slave active summon (P1)

**Evidence:** PROVEN_REFERENCE, the Spellstealer's own dedicated TibiaWiki monster page ability list —
`Summon Creature (4-5 Demon Slave)`, distinct from the generic elite-boss ability filler entries around
it (Fire Beam, Death Beam, etc. — all `(0-0)`, unproven/out of scope, not touched).

**Implemented** (`creaturescripts_invasion_wings.lua`, new `InvasionSpellstealerSummon` CreatureEvent,
`onThink`): re-verifies exact current-run + current-wing-generation ownership on every tick via
`SecretLibraryInvasionRunOwnsWingBoss("spellstealer", creature)` — this check is inherently
generation-scoped already (a new wing generation gets a fresh boss creature id via
`spawnWingTransactional`, so a stale boss from an earlier generation or a finished/reset run fails the
check immediately; no separate generation counter was needed). On a bounded random per-tick chance, spawns
4-5 Demon Slaves at positions relative to the boss's own current position (not a fixed map coordinate —
works before wing room coordinates ever arrive, not map work) and inserts every one into
`SecretLibraryInvasionRun.wingAddIds.spellstealer` — the **same** set the pre-existing static ambient add
already uses. This means cleanup required zero new code: `InvasionWingBossDied`
(`movements_invasion_start.lua`) already removes every `wingAddIds[key]` entry on legitimate wing
completion, and `SecretLibraryInvasionRunTerminate`'s non-success branch already removes every
`wingAddIds` entry on timeout/technical_abort — both paths were re-inspected and confirmed unchanged and
still cover the new spawns. Simultaneous population is capped at 10 alive Demon Slaves (counted from the
same set) before any new summon event fires. Registered on all three Spellstealer monster types
(`the_spellstealer.lua`, `the_spellstealer_green.lua`, `the_spellstealer_red.lua` — the latter two
previously had no `monster.events` at all) since no evidence restricts the ability to one color state;
`InvasionSpellstealerColorSwap` and the vortex `colorTeleports` `MoveEvent`
(`movements_invasion_start.lua`) were not touched.

`CUSTOM_GLOBAL_LIKE_PENDING_EXACT_CHANCE`/`_TIMING`: no exact summon cooldown/chance is given by the
reference — reuses this file's own established periodic-chance idiom
(`spellstealerColorSwap.onThink`'s ~4%/tick pattern, here ~3%/tick). `CUSTOM_GLOBAL_LIKE_PENDING_EXACT_CAP`:
the population cap (10) is a disclosed, conservative judgment call, not a reference-given number. Both
non-blocking per the task's own instruction.

## 2. Scion/Brothers mixed-component fire/ice heal (P1)

**Root cause, confirmed by direct source inspection** (`src/lua/creature/creatureevent.cpp:435-478`,
`CreatureEvent::executeHealthChange`):

```cpp
damage.primary.value = std::abs(LuaScriptInterface::getNumber<int32_t>(L, -4));
damage.primary.type = LuaScriptInterface::getNumber<CombatType_t>(L, -3);
damage.secondary.value = std::abs(LuaScriptInterface::getNumber<int32_t>(L, -2));
damage.secondary.type = LuaScriptInterface::getNumber<CombatType_t>(L, -1);
if (damage.primary.type != COMBAT_HEALING) {
	damage.primary.value = -damage.primary.value;
	damage.secondary.value = -damage.secondary.value;
}
```

The engine takes `abs()` of whatever primary/secondary values the Lua `onHealthChange` handler returns,
then decides whether to (re-)negate **both** of them together based **only** on the returned
`primary.type` — there is no independent per-component sign decision. The previous handlers treated
"primary OR secondary is fire/ice" as one combined branch: heal from `primary + secondary`, return `0, 0`
for both. On a mixed hit (e.g. physical primary + fire secondary), this zeroed the physical component too
— erasing real incoming damage and converting it into healing, exactly the bug the task described.

**Fix (`InvasionScionHealFire`, `InvasionBrothersHealIce`):** each component is now converted/zeroed
**independently**. A component matching the heal-trigger type (fire for the Scion, ice for the Brothers)
is folded into a single manual `creature:addHealth(heal)` call and its own return value zeroed; a
component that does **not** match is returned completely untouched (same value, same type). Because the
engine's negation is driven only by `primary.type`, and a passed-through component's own type is
essentially always a non-`COMBAT_HEALING` damage type, the "negate both" branch still fires — but since an
untouched component's value is already correctly signed, `abs()` then re-negate reproduces it exactly
(a no-op), while a zeroed component's `abs(0)` stays `0` regardless of sign. Verified against every
required case:

| Case | Primary | Secondary | Result |
|---|---|---|---|
| A | physical | — | unchanged, passes through untouched |
| B | fire/ice | — | heals (single-component heal, `addHealth`) |
| C | physical | fire/ice | physical still damages (untouched), fire/ice still heals |
| D | fire/ice | physical | fire/ice still heals, physical still damages (untouched) |
| E | fire/ice | fire/ice | both fold into one `addHealth` call — no double-heal, single sum |
| F | foreign/stale Scion or Brothers | — | unaffected — `SecretLibraryInvasionRunOwnsWingBoss` guard unchanged, still the first check in both handlers |

`InvasionBrothersHealIce` had the byte-for-byte identical bug pattern, per the task's own instruction to
check it — fixed in the same surgical change, same technique, same evidence.

## 3. Brothers/Biting Cold proximity (P1)

**Evidence:** PROVEN_REFERENCE, unchanged from document 08 — "Os bosses e os Biting Colds se curam...
para derrotá-los, você deve mantê-los afastados um do outro" (the bosses and the Biting Colds heal each
other; to defeat them you must keep them apart). This explicitly frames distance as part of the essential
mechanic — a heal that fired regardless of distance made "keeping them apart" mechanically meaningless.

**Research for an exact radius:** re-checked the main quest page and all three dedicated monster pages
(Brother Chill, Brother Freeze, Biting Cold) this pass — none state an exact tile radius. No stronger
evidence than document 08 found.

**Implemented** (`brothersHealEachOther.onThink`): candidate selection now additionally requires
`selfPosition:getDistance(otherPosition) <= HEAL_RADIUS` before a pool member is eligible to be healed.
`Position:getDistance` is this engine's real, native, already-used-elsewhere distance metric — confirmed
via `src/lua/functions/map/position_functions.cpp`'s `luaPositionGetDistance`
(`std::max(|dx|, |dy|, |dz|)`, i.e. standard Tibia square/Chebyshev range), the same method already used
in `data-otservbr-global/lib/quests/soul_war.lua:1250`, not invented. `HEAL_RADIUS = 5`, labeled
`CUSTOM_GLOBAL_LIKE_PENDING_EXACT_RADIUS` — non-blocking per the task's own instruction. Ownership
(current run/wing-generation via `SecretLibraryInvasionRunOwnsWingBoss`/`OwnsWingAdd`), dead/removed
exclusion (`other:getHealth() > 0`, already present, unchanged), and wing-end cutoff (pool membership
comes from `wingAddIds.brothers`/`brothersAlive`, both cleared on wing end, unchanged) were already
correct from document 08 and were not modified beyond adding the distance check.

| Case | Result |
|---|---|
| inside radius | eligible |
| outside radius | no heal (filtered out of `candidates` before selection) |
| foreign add | no heal (`SecretLibraryInvasionRunOwnsWingAdd` guard, unchanged) |
| stale add (older wing generation) | no heal (same guard — `wingAddIds` is regenerated per wing) |
| dead brother | excluded (`other:getHealth() > 0` check, unchanged) |
| wing ended | no heal (pool empties as adds are removed / `brothersAlive` flips false) |

## 4. Regression check — preserved subsystems

Re-inspected by diff, not merely by assumption:
- Cerebrir epilogue/completion (`npc/cerebrir.lua`, `creaturescripts_scourge_of_oblivion_phases.lua`) and
  `Library.Questline` 0/1/2 — zero lines touched this pass.
- Library Liberator — zero lines touched.
- Spellstealer initial colored state (`movements_invasion_start.lua`'s `spawnWingTransactional`
  color-transform block) and the vortex `colorTeleports` `MoveEvent` — zero lines touched; the new summon
  event is additive (a new `CreatureEvent`/`monster.events` entry) and does not call `setType` or
  interact with `SecretLibraryInvasionRun.wingBossIds` at all.
- Devourer exact-4-Books transaction (`spawnWingTransactional`'s mandatory-add block, `InvasionBookDeath`,
  `InvasionDevourerDamageGate`) — zero lines touched.
- Scion ownership guard (`SecretLibraryInvasionRunOwnsWingBoss("scionOfHavoc", …)`) — unchanged, still the
  first check in `scionHealFire`.
- Lifecycle/hard timeout/technical abort (`SecretLibraryInvasionRunTerminate`,
  `createInvasionEncounter`'s 26:20 deadline event) — zero lines touched.
- Previously-accepted NPC/mission/questlog flow — zero lines touched outside the four files listed in
  section 5.

## 5. Validation

```
luaparser.ast.parse on all 4 changed files -> OK, 0 failures
git diff --check -> clean (only benign core.autocrlf LF->CRLF working-tree notices)
CreatureEvent/monster.events cross-check -> every CreatureEvent("Invasion...") name in
  creaturescripts_invasion_wings.lua matches exactly one registration site; InvasionSpellstealerSummon
  confirmed present in all 3 Spellstealer monster.events lists and nowhere else spuriously
python -m tools.canary_audit validate-schemas -> All Canary audit schemas are valid
python -m unittest discover -s tools/canary_audit/tests -t . -p "test_*.py" -> Ran 72 tests, OK (skipped=3, environment-only)
python -m tools.canary_audit scan --profile otservbr-global --fail-on error
  -> Findings: 823 (error: 4, warning: 484, info: 335) - IDENTICAL totals to every prior pass's baseline
  -> 4 blocking findings, all 4 the pre-existing baseline (item ids 2874, 3452, 6276, 12724) - zero new
```

Changed files this pass (4): `data-otservbr-global/scripts/quests/the_secret_library_quest/library_area/
creaturescripts_invasion_wings.lua`, `data-otservbr-global/monster/quests/the_secret_library/
the_spellstealer.lua`, `..._the_spellstealer_green.lua`, `..._the_spellstealer_red.lua`.

No executable Lua gameplay-test harness and no local server build exist in this repository (unchanged
limitation, disclosed identically in every prior document) — not fabricated. GitHub Actions CI results
for the commit this pass produces were not available at document-authoring time (written immediately
before push); not fabricated here.

## 6. Final classification

**QUEST_CODE_COMPLETE**

All three reported P1 defects are resolved with no regression to any preserved subsystem (section 4).

**MAP_INTEGRATION_REQUIRED**

Unchanged — wing/vortex/add exact tiles and Cerebrir's own spawn tile remain unplaced;
`InvasionMapReady()` still fails closed. No coordinate was invented anywhere in this pass (the
Spellstealer summon's spawn positions are boss-relative offsets, not map coordinates).
