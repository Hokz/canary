# 02 — Heart of Destruction Questlog Contract

## Current repository evidence

- `data-otservbr-global/lib/core/quests/catalog/` — 51 catalog files (`001_...` through `051_...` plus `init.lua`). **No file references Heart of Destruction, in name or content** (confirmed via `grep -ril "HeartOfDestruction|heart_of_destruction" data-otservbr-global/lib/core/quests/catalog/` — zero matches).
- `data-otservbr-global/lib/core/storages.lua:2204` — `Storage.Quest.U10_94.HeartOfDestruction = {}`, inside the properly-namespaced, range-reserved `U10_94` block ("update 10.94 - Reserved Storages 45351 - 45450"). **This is the correct, conventional location for this quest's mission/questline storages** (matching the pattern documented in [[01_QUEST_ARCHITECTURE_AUDIT]] §3-4), but the table is empty — no `Questline`, no `Mission01`...`MissionNN` keys defined.
- `data-canary/lib/core/quests/catalog/` — only `001_example.lua` exists; no Heart of Destruction content in the alternate datapack either.

## Status: MISSING

Heart of Destruction has **zero Quest Log integration**. A player progressing through this quest today gets no Quest Log entry, no mission text, no progress tracking visible in the client UI — despite the quest being substantially implemented mechanically (bosses, levers, portals, rewards all function). The reserved-but-empty `U10_94.HeartOfDestruction` table is a strong signal that questlog integration was planned but never completed.

## Why this isn't a safe fix in this package

Per the package rules: *"Do not invent exact questlog text if not available... Mark missing exact text as OWNER_REFERENCE_REQUIRED."* Writing a questlog catalog module requires:
- A quest `name`
- Per-mission `name`, `missionId` (must be globally unique across all 51+ existing quests — verified at server startup by `data/lib/core/quests/catalog.lua`'s `buildCatalog()`), `startValue`/`endValue`, and `states` text describing each progress state to the player.

None of this text exists in the repository, and the reference pages that would normally supply it are inaccessible (see [[00_HOD_QUEST_BIBLE]] §Reference status). Inventing plausible-sounding mission text would violate the owner's explicit instruction not to invent quest log text.

## What IS knowable without invented text

The **storage keys that would back each mission** can be reasonably inferred from the existing mechanical implementation, since the quest already tracks meaningful state via the raw `14320-14354` range and `GlobalStorage.HeartOfDestruction`. A future catalog module could reuse these signals structurally even before exact mission wording is supplied — see [[03_HOD_STORAGE_CONTRACT]] for the full inventory. This is a scoping note for [[08_HOD_IMPLEMENTATION_BREAKDOWN]], not a fix applied in this package.

## Contract placeholder — `OWNER_REFERENCE_REQUIRED`

| Field | Needed |
|---|---|
| Quest name (as shown in Quest Log) | Exact text |
| Mission list (count, names, order) | Exact text, per mission |
| Per-mission state descriptions | Exact text, per state |
| Whether vortex-route progress (if implemented later) should appear as its own mission or sub-state | Design decision |

## Risk level

**Medium** — this is a real, confirmed gap, but it's a missing-content gap, not a broken-mechanic gap. It doesn't block quest completion; it only blocks Quest Log visibility. No live testing needed to confirm this finding (it's fully verifiable from static code — the catalog file simply doesn't exist).
