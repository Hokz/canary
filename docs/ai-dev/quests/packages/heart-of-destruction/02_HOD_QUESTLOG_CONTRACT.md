# 02 — Heart of Destruction Questlog Contract

**HOD-04 note**: Messenger of Heaven's dialogue is now implemented (see [[01_HOD_NPC_DIALOGUE_CONTRACT]]), but it does not write any storage or advance any quest-log-relevant state — the conversation is confirmed to be flavor/lore text only, not a progression trigger. This section's findings are otherwise unchanged. See [[08_HOD_IMPLEMENTATION_BREAKDOWN]] HOD-11 (renumbered from HOD-04) for the still-pending catalog work.

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
| Per-mission state descriptions | Exact text, per state (one piece now available — see below) |
| Whether vortex-route progress (if implemented later) should appear as its own mission or sub-state | Design decision |

## HOD-03 update — one exact mission-state text now available

The owner supplied exact text for the World Devourer re-entry state:

> *"To face the heart of destruction again, you have to gather destructive charges to enter its lair. You gain charges by killing any higher minion of destruction. You have gathered X of 5 charges."*

**Not implemented in HOD-03**, for two reasons:
1. This text describes the **"5 destructive charges" entry-gate mechanic**, which is separate from (and currently absent alongside) the cooldown/Devourer Core system already implemented — see [[03_HOD_STORAGE_CONTRACT]] and [[05_HOD_BOSS_MECHANICS_CONTRACT]] for the corrected understanding of what's already implemented (cooldown + Devourer Core reset item) versus what's still missing (the charge-accumulation gate itself). Displaying this exact text without the underlying charge system existing would show players an instruction for a mechanic that doesn't function.
2. A single populated mission state isn't enough to safely create a valid catalog module — `data/lib/core/quests/catalog.lua`'s `buildCatalog()` validates the whole quest structure (unique `missionId`s, `startStorageId`, etc.), and the other 7+ mission states (quest start, first three boss missions, Eradicator/Outburst, World Devourer itself) still have no exact text.

This exact text is preserved here so it isn't lost, and is ready to use verbatim once (a) the charge-accumulation mechanic is implemented (a future package) and (b) enough of the remaining mission states are supplied to build a complete, valid catalog module.

## Risk level

**Medium** — this is a real, confirmed gap, but it's a missing-content gap, not a broken-mechanic gap. It doesn't block quest completion; it only blocks Quest Log visibility. No live testing needed to confirm this finding (it's fully verifiable from static code — the catalog file simply doesn't exist).
