# 04 — Quest Storage Registry Proposal

This document defines the binding convention for any future quest PR that adds, changes, or fixes storage/KV state. **Every future quest PR must update the relevant section of this registry as part of the same PR** — a quest PR that changes storage usage without updating this doc is incomplete.

## 1. Current state (as found by audit)

Two systems coexist in this codebase today (see [[01_QUEST_ARCHITECTURE_AUDIT]] §4 for full detail):

1. **Legacy numeric `Storage` table** — `data-otservbr-global/lib/core/storages.lua` (3111 lines), nested `Storage.Quest.<UpdateTag>.<QuestName>.<Key>`, plus a `GlobalStorage` table for world-scoped values.
2. **KV system** — `player:questKV(questName)` (`data/libs/functions/player.lua:819`), backed by `src/kv/`. **`CONTRIBUTING.md` mandates KV for all new features** — the legacy `Storage` system is explicitly deprecated for new work.

A migration script (`data-otservbr-global/scripts/game_migrations/20241715984294_quests_storages_to_kv.lua`) already converts some legacy storages to KV scopes — new quest work should follow that direction, not reverse it.

## 2. Binding rules for this project

### Rule 1 — Do not create duplicate storages
Before adding any new `Storage.*` entry or KV scope, search `data-otservbr-global/lib/core/storages.lua` and existing quest folders for an existing entry that already represents the same state. If a questline already has a `Questline`/`Mission0X` key that fits, reuse it — do not add a parallel key with the same meaning.

### Rule 2 — Reuse existing storages when they are already correct
If a quest fix only requires changing *logic* (a dialogue branch, a comparison operator, a missing fallback) and the existing storage key already represents the right state correctly, **do not touch the storage registry** — fix the logic in place. Only touch the registry when the storage itself is missing, mis-scoped, or genuinely needs a new key.

### Rule 3 — New quest work uses KV, not new legacy `Storage` entries
Per `CONTRIBUTING.md`, any **new** quest (not an existing legacy quest being patched) must use `player:questKV(questName)` for player-scoped state. Only touch the legacy `Storage` table when **fixing** a quest that already uses it — and even then, prefer not to introduce brand-new legacy storage IDs; extend the existing quest's KV usage if the surrounding code already has some, or leave a note in [[05_QUEST_IMPLEMENTATION_STATUS]] recommending a future full KV migration for that quest.

### Rule 4 — Reserve storage ranges per questline only when a new legacy-style questline is unavoidable
If a fix genuinely requires new legacy numeric storages (e.g. extending an existing `Storage.Quest.U8_x.SomeQuest` block), reserve a contiguous range and document it with a comment in `storages.lua` in the same style as existing entries:
```lua
SomeQuest = { -- Reserved storage from NNNNN - NNNNN
    Questline = NNNNN,
    Mission01 = NNNNN,
}
```
Check the top-of-file range documentation in `storages.lua` and the `Storage.Quest.<UpdateTag>` block comments to avoid colliding with an already-reserved range.

### Rule 5 — Never reuse a world-scoped (`GlobalStorage`) key for per-player state
The #599 audit ([[03_QUEST_ISSUE_599_FIX_AUDIT]]) found **world-scoped storages used to gate per-player progress** (Inquisition's Shadow Nexus, Heart of Destruction's kill counters) as a likely root cause of multiple bugs. Any new quest state that tracks an individual player's or party's progress must be per-player (`player:getStorageValue`/`setStorageValue` or `player:questKV`), never `GlobalStorage`/`Game.setStorageValue`, unless the state is genuinely meant to be shared across all players on the server (e.g. a world-boss respawn timer).

### Rule 6 — Document mission states, separately from temporary/puzzle/boss/access/cooldown storages
Split storage documentation into two conceptual buckets per questline:
- **Mission states** — the player-visible questline progression (`Questline`, `Mission01`...`MissionNN`), what feeds the questlog catalog (`data-otservbr-global/lib/core/quests/catalog/`).
- **Mechanism storages** — everything else: puzzle state (lever sequences, gem colors), boss-access gates, boss-fight-internal mechanics, cooldown timers. These should NOT be mixed into the same nested table as mission states without a clear sub-key (e.g. `Bosses = {...}`, `TeleportAccess = {...}`, as already done in some existing quests — see [[01_QUEST_ARCHITECTURE_AUDIT]] §4a).

This split matters because mission-state storages are read by the generic questlog runtime (`Game.isQuestStorage`) — polluting that namespace with puzzle/cooldown storages can cause spurious questlog "updated" notifications.

### Rule 7 — Naming conventions (binding)
- Legacy `Storage` keys: PascalCase, nested `Storage.Quest.<UpdateTag>.<QuestNamePascalCase>.<KeyPascalCase>`. Mission keys zero-padded two digits (`Mission01`...`Mission99`). Questline progress key named `Questline`.
- KV quest names (`player:questKV(questName)`): lowercase, `snake_case`, matching the quest folder name under `data-otservbr-global/scripts/quests/` (e.g. folder `heart_of_destruction` → `player:questKV("heart_of_destruction")`). This project adds this convention on top of the existing free-form KV usage in the codebase, specifically to keep KV quest names discoverable and grep-able against folder names.
- KV keys within a quest scope: lowercase `snake_case` (`questKV("heart_of_destruction"):get("anomaly_access")`), mirroring the mission/mechanism split from Rule 6 with a key prefix (`mission_01_state`, `access_anomaly`, `cooldown_lever_charges`).

## 3. Known systemic risk (carried from #599 audit)

Flagging here so it isn't lost: at least **two of the three #599 priority bugs** trace back to world-scoped storages/counters being used where per-player/per-party state was needed (`GlobalStorage.Inquisition`, the un-namespaced 14320-14354 range in Heart of Destruction). Any future audit of an "existing quest reported broken" should check this pattern first — it's cheap to check and has already explained 2 of 3 priority bugs.

## 4. Storage range map (as documented in `storages.lua`, for quick reference)

This is a **pointer**, not a duplicate — always check the live file for the authoritative, current state before reserving a new range.

| Update tag | Approx. range (see file comments) | Example questlines |
|---|---|---|
| `U6_1` – `U7_x` | Legacy low ranges, various | Classic-era quests |
| `U8_2` | ~ | The Inquisition |
| `U8_54` | 42551–42950 | Children of the Revolution, and others |
| `U8_6` | ~ | Wrath of the Emperor |
| `U10_90`+ | Higher ranges | Ferumbras' Ascension-era and later |
| (uncategorized) | `GlobalStorage.*` | World-scoped quest state — audit any new addition here against Rule 5 |
| (uncategorized) | 14320–14354 (Heart of Destruction access gates) | **Not currently registered in `Storage.*`** — flagged as tech debt in [[03_QUEST_ISSUE_599_FIX_AUDIT]] Bug 3; a future fix should formally register this range |

## 5. Process — what every future quest PR must include

1. State whether the quest change is a **fix to an existing legacy-storage quest** (may touch `Storage.*`, following Rules 1-2, 4-7) or **new quest work** (must use `player:questKV`, following Rule 3, 6-7).
2. If any new storage/KV key was added: update this file's §4 (or add a new entry) describing the key, its purpose, and which bucket (mission state vs. mechanism) it belongs to.
3. If a range was reserved: add the range comment in `storages.lua` in the existing style, and update §4 here.
4. Confirm (in the PR description) that no duplicate storage was created — name the existing storage that was reused, if applicable.
5. Update [[05_QUEST_IMPLEMENTATION_STATUS]] to reflect the quest's new status.
