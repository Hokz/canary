# 01 — Quest Architecture Audit

Source: repository research against `C:\Users\dgarc\canary-dev` (read-only audit, no files modified). Paths are relative to repo root.

## 0. Repository layout — three data trees

The repo ships **three separate data trees**, which is the single most important fact for anyone working on quests here:

| Tree | Purpose |
|---|---|
| `data/` | Engine-level defaults/libs, world-agnostic (NPC system framework, generic quest-door action, questlog loader/runtime). |
| `data-otservbr-global/` | The "Global" world content — **where nearly all real, playable quests live** (~106 quest folders, 51 questlog catalog entries, 1035 NPC files). This is the tree referenced by issues #618 and #599. |
| `data-canary/` | An alternate/minimal world dataset. Mirrors the folder structure of `data-otservbr-global` but has no populated quest content yet (one example catalog stub). |

**Rule of thumb: quest work happens in `data-otservbr-global/`, using shared libraries from `data/`.**

## 1. Quest script folder layout

- `data-otservbr-global/scripts/quests/` — one subfolder per questline (106 folders as of this audit — see [[05_QUEST_IMPLEMENTATION_STATUS]] for the full list). Examples: `ferumbras_ascension/`, `soul_war/`, `wrath_of_the_emperor/`, `the_secret_library_quest/`, `oramond/`, `heart_of_destruction/`, `others/` (catch-all for small one-off quests).
- Some quests nest sub-quest folders, e.g. `oramond/probing`, `oramond/the_ancient_sewers`, `the_secret_library_quest/liquid_death`, `grave_danger_quest/cobra_bastion`.
- **Within a quest folder, all script types live together flatly** — no `actions/`/`movements/` subfolders. Scripts are distinguished by filename prefix: `actions_*.lua`, `movements_*.lua`, `creaturescripts_*.lua`, `globalevents_*.lua`, occasionally `spell-*.lua`, `eventcallback_*.lua`.
- Generic (non-quest-specific) action/movement/creaturescript/globalevent/spell scripts live in `data-otservbr-global/scripts/actions/`, `.../movements/`, `.../creaturescripts/`, `.../globalevents/`, `.../spells/`, `.../systems/`.
- Quest-adjacent generic scripts: `actions/system/` (generic reward-chest handler — see §9) and `actions/other/others/` (legacy monolithic quest scripts covering many old quests in one file).
- `data/scripts/` — engine-default shared scripts: `actions/doors/quest_door.lua` (generic quest-door handler), `lib/quests.lua`, `eventcallbacks/player/on_request_quest_log.lua`, `eventcallbacks/player/on_storage_update.lua`.
- NPC dialogue lives separately in `data-otservbr-global/npc/` — **not** under `scripts/quests/`.

## 2. NPC folders and dialogue patterns

- NPC Lua files: `data-otservbr-global/npc/*.lua` — flat directory, 1035 files, one per NPC. `data-canary/npc/` mirrors this.
- Framework: the classic **"Advanced NPC System" (`KeywordHandler` + `NpcHandler`)** lives at `data/npclib/npc_system/` (`npc_handler.lua`, `keyword_handler.lua`, `modules.lua`, `bank_system.lua`, `custom_modules.lua`), loaded via `data/npclib/npc.lua`/`load.lua`.
- **This is the only NPC framework in the codebase.** `KeywordHandler:new()` appears in 1028 of 1035 NPC files — old and "modern" quest dialogue use the same API; the difference is state-machine complexity, not the underlying framework. There is no newer/alternate NPC scripting API to migrate to.
- Representative pattern:

```lua
local keywordHandler = KeywordHandler:new()
local npcHandler = NpcHandler:new(keywordHandler)
...
if MsgContains(message, "mission") then
    if player:getStorageValue(Storage.Quest.U8_54.ChildrenOfTheRevolution.Questline) < 1 then
        npcHandler:say({...}, npc, creature)
        npcHandler:setTopic(playerId, 1)
    elseif ... == 6 then
        player:setStorageValue(Storage.Quest.U8_54.ChildrenOfTheRevolution.Questline, 8)
        player:setStorageValue(Storage.Quest.U8_54.ChildrenOfTheRevolution.Mission02, 5) --Questlog, "Mission 2: ..."
    end
end
```

- Newer quests (e.g. Soul War) use the **KV player-scope API** (`player:questKV(questName)`) instead of raw numeric `Storage` keys inside NPC/action scripts (see §4).
- **Common failure mode observed in this audit** (see [[03_QUEST_ISSUE_599_FIX_AUDIT]] Bug 2): dialogue state machines with no `else`/fallback branch silently say nothing when the player's storage doesn't match any handled value.

## 3. Questlog definitions

Questlog entries are **not** an XML/JSON file — they're a Lua catalog module system:

- `data/lib/core/quests/loader.lua` — custom `package.searchers` loader that lazily `require()`s catalog files.
- `data/lib/core/quests/catalog.lua` — `buildCatalog()` validates uniqueness of `missionId`s and `startStorageId`s across all quests.
- `data-otservbr-global/lib/core/quests/catalog/` — one file per questline, named `NNN_quest_name.lua` (51 files as of this audit, indexed by `catalog/init.lua`).
- Loaded at startup: `data-otservbr-global/lib/core/load.lua` → `require("...lib.core.quests")` → `quests.lua` → `loader.load(...)`.
- Module shape:

```lua
-- data-otservbr-global/lib/core/quests/catalog/001_the_queen_of_the_banshees.lua
local quest = {
    name = "The Queen of the Banshees",
    startStorageId = Storage.Quest.U7_2.TheQueenOfTheBanshees.FirstSeal,
    startStorageValue = 1,
    missions = {
        [1] = { name = "The Hidden Seal", storageId = Storage.Quest.U7_2.TheQueenOfTheBanshees.FirstSeal,
                missionId = 1, startValue = 1, endValue = 1, description = "You broke the first seal." },
    },
}
```

- Runtime logic: `data/libs/functions/quests.lua` (~1300 lines) — `Game.getQuest/getMission/isValidQuest`, `Player.questIsStarted/questIsCompleted/missionIsStarted/missionIsCompleted/getMissionName/getMissionDescription`, `Player:sendQuestLog()`/`sendQuestLine()`, plus a full client-side quest tracker subsystem (`sendTrackedQuests`, auto-track/auto-untrack via KV, packet `0xD0`).
- Entry point: `Game::playerShowQuestLog` (`src/game/game.cpp:7373`) → event callback → `data/scripts/eventcallbacks/player/on_request_quest_log.lua` → `player:sendQuestLog()`.
- Storage changes flow through `Player.updateStorage` (`data/scripts/eventcallbacks/player/on_storage_update.lua`), which detects quest-relevant storages via `Game.isQuestStorage`/`isQuestStorageKey` and drives questlog "updated" messages + the tracker.
- **There is no C++ `Quest`/`Mission` class** — the entire questlog/mission model is Lua-side; C++ only proxies the show-log/show-questline requests.
- **Implication for new quests**: implementing a quest's *scripts* without adding a matching catalog entry means the quest will work in-game but never appear in the player's Quest Log UI. This is an easy, silent gap to leave — check for it explicitly (see [[06_QUEST_IMPLEMENTATION_PROTOCOL]] checklist).

## 4. Storage value system

Two systems coexist, and the project is **actively migrating from the first to the second**:

### 4a. Legacy numeric `Storage` table
- `data-otservbr-global/lib/core/storages.lua` (3111 lines) + `data-canary/lib/core/storages.lua` counterpart.
- Patterns found:
  - Flat: `Storage.Dragonfetish = 30003`
  - Nested per-quest: `Storage.DeeplingsWorldChange = { -- Reserved storage from 50000 - 50009 ... }`
  - **Modern nested convention**: `Storage.Quest.<UpdateTag>.<QuestName>.<Key>`, grouped by the Tibia client update the quest shipped with (`U6_1`, `U7_2`, `U8_54`, `U8_6`, `U10_90`, ...), each block commented with its reserved numeric range:

```lua
Storage.Quest = {
    U8_54 = { -- update 8.54 - Reserved Storages 42551 - 42950
        ChildrenOfTheRevolution = {
            Questline = 42601,
            Mission00 = 42602, -- Prove Your Worzz!
            Mission01 = 42603,
            ChestTomeOfKnowledge1 = 42613,
        },
    },
}
```
  - Sub-namespacing within a questline table for `Rewards = {...}`, `Bosses = {...}`, `TeleportAccess = {...}`, per-monster kill counters.
  - `GlobalStorage` table (bottom of file) — **non-player (world-scoped) storages** for shared quest state (raid counters, world bosses). `startupGlobalStorages` array lists globals reset on server startup.
  - **Risk observed live**: `GlobalStorage.Inquisition` is a world-scoped counter guarding a shared map object (the Shadow Nexus) — see [[03_QUEST_ISSUE_599_FIX_AUDIT]] Bug 1 for how this class of storage causes cross-player/party interference.

### 4b. KV system (current standard for new work)
- `src/kv/` (`kv.hpp/.cpp`, `kv_sql.hpp/.cpp`), documented in `src/kv/README.md`.
- Lua binding: `player:kv()` (`src/lua/functions/core/libs/kv_functions.cpp`, `luaPlayerKV` in `player_functions.cpp`).
- Quest wrapper: `data/libs/functions/player.lua:819` — `Player:questKV(questName)` returns `self:kv():scoped("quests"):scoped(questName)`. Usage: `player:questKV("mySoulWarStage"):set("completed", true)`.
- **`CONTRIBUTING.md` explicitly forbids new features from using the legacy numeric `Storage` system** — contributors must adopt the KV system.
- A migration script exists: `data-otservbr-global/scripts/game_migrations/20241715984294_quests_storages_to_kv.lua`, mapping old `storageOld` values to `questName` KV scopes for dozens of legacy one-off quests.

### 4c. Practical rule for this project
See [[04_QUEST_STORAGE_REGISTRY]] for the binding convention going forward. Summary: **new/rewritten quest work should use KV** (`player:questKV(...)`) per `CONTRIBUTING.md`; legacy `Storage.*` values are only touched when fixing an existing quest that already uses them, and even then, prefer not introducing new legacy storage IDs.

### 4d. Reserved action/unique-ID ranges
Separate from storages — used for map action IDs/unique IDs on doors, chests, teleport items, corpses, tiles, levers. Documented in `data-otservbr-global/startup/README.md`.

## 5. Action / movement scripts for quests

- **Generic quest door** (storage-gated, reusable): `data/scripts/actions/doors/quest_door.lua`, driven by a `QuestDoorTable` of open/closed item-id pairs:

```lua
if value.closedDoor == item.itemid then
    if item.actionid > 0 and player:getStorageValue(item.actionid) ~= -1 then
        item:transform(value.openDoor)
        player:teleportTo(toPosition, true)
    end
end
```

- **Per-quest action scripts** (levers, statues, teleport rods, gem puzzles) live directly in each quest folder, e.g. `ferumbras_ascension/actions_ferumbras_lever.lua`, `actions_color_levers.lua`, `actions_teleportation_rod.lua`.
- **Movement/step-in scripts** for quest entrances/teleports: `movements_entrance.lua`, `movements_boss_teleport.lua` — typically a `MoveEvent()` of `type("stepin")` gated by level + a set of `Storage`/KV checks before `player:teleportTo(...)`.

## 6. Global events used by quests

No central "quest reset" globalevents registry. Globalevents for quests are embedded **inside each quest's own folder**, prefixed `globalevents_*`/`globalevent-*`:
- `ferumbras_ascension/globalevents_ferumbras_ascendant_effect_1.lua`/`_2.lua` — periodic visual/state effects.
- `soul_war/globalevent-ebb_and_flow_change_maps.lua` — cycles the Soul War map between states on an interval (`GlobalEvent(...).onThink`), reloads sub-maps via `Game.loadMap`.
- `data-otservbr-global/scripts/globalevents/others/` holds unrelated infra globalevents (not quest-specific).
- **No dedicated "daily quest reset" globalevent framework exists** — per-quest cooldowns are handled reactively via storage/KV timers, not scheduled resets.

## 7. Boss room / access systems

- **`BossLever`** library: `data/libs/functions/boss_lever.lua` — fluent builder (`BossLever(config):position(pos):register()`) wiring a lever `Action` to: level requirement, participant-position checks, min player count, zone occupancy check, boss cooldown check (via KV — §8), monster/boss spawn, party teleport-in, auto-timeout room clear. Built on the shared `Lever` primitive (`data/libs/functions/lever.lua`, multi-tile lever coordination via `setPositions`/`setCondition`/`checkConditions`/`teleportPlayers`).
- Real usage example: `ferumbras_ascension/actions_ferumbras_lever.lua` — `BossLever{ boss = {...}, timeToFightAgain=..., playerPositions={...}, monsters={...}, onUseExtra=function(player) ... end }`.
- Door/room access otherwise gated the same way as any quest door (§5) — a storage/KV check on step-in or lever use.
- Zones: `Zone("boss." .. bossName)` used for occupancy/monster-clear checks.
- **This is the modern, preferred pattern for new boss rooms.** Quests that instead hand-roll their own storage-gated portals with bare magic-number storage IDs (see [[03_QUEST_ISSUE_599_FIX_AUDIT]] Bug 3 — Heart of Destruction) are harder to maintain and more failure-prone.

## 8. Cooldown systems

- **Boss cooldown** (shared, generic, KV-backed): `data/libs/functions/player.lua` — `Player:getBossCooldown/setBossCooldown/canFightBoss`, scoped as `"boss.cooldown." .. toKey(raceId)`. `BossLever` and `Lever:setCooldownAllPlayers` call into this automatically.
- **Per-quest timers** (non-boss) are ad hoc: individual `Storage.Quest.<...>.<X>Timer` keys storing `os.time() + duration`, checked manually.
- No standalone "daily reset" scheduler for quests specifically (`data/modules/scripts/daily_reward/daily_reward.lua` is the unrelated daily-login-reward system).

## 9. Reward chest systems

Two competing patterns:

- **Generic, reusable (preferred)**: `data-otservbr-global/scripts/actions/system/quest_reward_common.lua` — a single `Action` registered across unique-id ranges `5000-9000`, `10000-12000`, plus `14092`. Reward contents are **not hardcoded in the script** — pulled from `data-otservbr-global/startup/tables/chest.lua`:

```lua
-- Legacy: [xxxx] = { itemId=, itemPos=, container=, reward={{xxxx,x}}, storage=xxxxx }
-- KV:     [xxxx] = { useKV=true, itemId=, itemPos=, container=, reward={{xxxx,x}}, questName="testkv" }
```

  Adding a new quest chest with this system is a **table entry, not a new script**.

- **Per-quest / legacy**: many older quests ship bespoke reward action scripts (`ferumbras_ascension/actions_reward.lua`, `soul_war/action-reward_soul_war.lua`); `actions/other/others/quest_system1.lua`/`quest_system2.lua` are large monolithic legacy files covering many unrelated old quests' chests.
- Reward-key/action/unique-ID ranges documented in `data-otservbr-global/startup/README.md` and repeated as a header comment in `chest.lua` (chests 5000–12000, custom chests 12001–15000, reward keys 5000–6000).

## 10. Quest helper libraries

| Library | Purpose |
|---|---|
| `data/lib/core/quests/loader.lua`, `catalog.lua` | Questlog catalog loading/validation |
| `data/libs/functions/quests.lua` | Runtime quest/mission/tracker API on `Player`/`Game` |
| `data/libs/functions/player.lua` | `questKV`, `canGetReward`, boss cooldown helpers |
| `data/libs/functions/boss_lever.lua`, `lever.lua` | Boss-room/lever framework |
| `data/scripts/lib/quests.lua` | Thin engine-default shim |
| `data/scripts/lib/register_lever_tables.lua` | Static per-boss lever config tables |
| `data-otservbr-global/scripts/lib/` | `monster_functions.lua`, `register_actions.lua` (generic) |
| Per-quest mechanics modules | e.g. `soul_war/soul_war_mechanics.lua` defines a `SoulWarQuest` global used by that quest's own scripts |

`data/XML/storages.xml` exists but is a legacy/unrelated action-id↔storage mapping table — **not** the quest storage source of truth (`storages.lua` is).

## 11. Naming conventions

- **Quest folders**: `snake_case` matching the in-universe title (`ferumbras_ascension/`, `children_of_the_revolution/`).
- **Script files**: `<type>_<description>.lua`, underscore-joined, type-prefixed — dominant convention (`actions_*` ×430, `movements_*` ×214, `creaturescripts_*` ×156, `globalevents_*` ×10). A **less common hyphenated convention** also exists in newer quests (`action-*` ×51, `movement-*`/`moveevent-*` ×54, `globalevent-*`), e.g. Soul War's `action-reward_soul_war.lua`. A handful of files have typos (`moviments_*`, `creaturescritps_*`) — naming is organic, not lint-enforced.
- **Storage keys**: strict PascalCase, nested `Storage.Quest.<UpdateTag>.<QuestNamePascalCase>.<KeyPascalCase>`. Mission keys: `Mission01`, `Mission02`, ... (zero-padded two digits). Questline progress key: conventionally `Questline`/`QuestLine`. Door/access keys: `...Door`, `...Access`, `...Teleport`. Rewards nest under `Rewards = {...}`.
- **KV quest names** (`player:questKV(questName)`): free-form lowercase/camel strings, no strict enum (unlike the `Storage` table these are just string literals — see [[04_QUEST_STORAGE_REGISTRY]] for the naming rule this project adds on top).
- **Update-tag namespacing**: `U<major>_<minor>` (e.g. `U6_1`, `U7_24`, `U8_54`, `U10_90`) groups quests by the Tibia client version they were added for, with a reserved storage-id range commented on the same line.

## 12. Existing documentation

No dedicated quest-authoring guide exists in `docs/` prior to this package. Quest-relevant documentation is scattered:
- `CONTRIBUTING.md` (root) — mandates KV over legacy storages for new features; "No Complex Lua Scripts" (heavy logic should go to C++).
- `src/kv/README.md` — full KV library API reference (C++ and Lua).
- `data-otservbr-global/startup/README.md` — reserved action/unique-ID ranges for chests, doors, levers, teleports, corpses.
- Small per-quest `README.md` files with map-position notes only: `data-otservbr-global/world/quest/ferumbras_ascendant/README.md`, `.../world/quest/soul_war/ebb_and_flow/README.md`, `.../world/quest/cults_of_tibia/misguided/README.md`.
- Inline comments in `chest.lua` / `quest_reward_common.lua` document the reward-table format.
- `data/scripts/eventcallbacks/README.md` documents the eventcallback registration pattern.
- `docs/systems/README.md`, `docs/architecture.md`, `docs/development.md` cover general engine architecture but don't mention quests specifically.

**This audit (`01_QUEST_ARCHITECTURE_AUDIT.md`) is now the closest thing to a quest-authoring architecture reference in this repo — keep it updated as the codebase evolves.**
