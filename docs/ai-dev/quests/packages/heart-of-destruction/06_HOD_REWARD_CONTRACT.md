# 06 — Heart of Destruction Reward Contract

Per package rules: comparison only, no reward implementation in this package.

## Current repository evidence

`data-otservbr-global/scripts/quests/heart_of_destruction/actions_reward.lua`, read in full:

```lua
local heartDestructionReward = Action()
function heartDestructionReward.onUse(player, item, fromPosition, target, toPosition, isHotkey)
    if item.uid == 1038 then
        if player:getStorageValue(14337) < 1 then
            local container = player:addItem(23525)
            container:addItem(23512, 1)
            container:addItem(23538, 1)
            container:addItem(23536, 1)
            container:addItem(23509, 1)
            container:addItem(3043, 20)
            container:addItem(22721, 5)
            player:setStorageValue(14337, 1)
            player:addAchievement("Ender of the End")
            player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "You have found an energetic backpack.")
        else
            player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "The chest is empty.")
        end
    end
    return true
end
```

## Comparison against owner's reference

| Owner reference item | Repository evidence | Status |
|---|---|---|
| Energetic Backpack | `player:addItem(23525)` — container item, message says "You have found an energetic backpack" | **Implemented**, item id not independently verified against the client item database in this pass |
| Decorative/quest items | 4 items added at qty 1 each: 23512, 23538, 23536, 23509 (exact item names not looked up — out of scope, would require an items.xml cross-reference) | **Implemented**, exact identity unverified |
| Crystal coins / gold tokens | 3043 ×20, 22721 ×5 (item 3043 is very likely a currency item given the pattern; 22721 unverified) | **Implemented**, exact identity unverified |
| Powerful imbuement access | Not present anywhere in this file or elsewhere in the HOD quest folder (searched) | **MISSING** — or granted through a mechanism not located in this pass (e.g., a separate imbuement-shrine NPC check elsewhere in the codebase, outside the approved scope for this package) |
| Achievement | `player:addAchievement("Ender of the End")` | **Implemented** |

## One-time claim logic

Storage 14337 gates the reward to a single claim per player (`< 1` check, then set to `1`). This is a **per-player storage** (correct scope — `player:getStorageValue`, not `Game.getStorageValue`), consistent with a one-time reward. **Status: Implemented correctly** for the claim-gating mechanism itself. **Risk: Low** for the mechanism; the storage number (14337) is unregistered in `storages.lua`, same registry-hygiene note as the rest of the quest (see [[03_HOD_STORAGE_CONTRACT]] §3) — not a functional risk on its own.

## What triggers the reward

Gated by `item.uid == 1038` — a specific, presumably unique map object (likely the reward chest itself, reached after defeating World Devourer per the quest's structure). This wasn't traced back to confirm it's only reachable post-World-Devourer (would require map data); flagging as an assumption, not a verified fact.

## Summary

| Component | Status | Risk | Safe patch candidate |
|---|---|---|---|
| Energetic Backpack + items + currency | Implemented | Low | N/A |
| Achievement | Implemented | Low | N/A |
| One-time claim gating | Implemented correctly | Low | N/A |
| Powerful imbuement access | Missing (or elsewhere, unconfirmed) | Medium | None — per package rules, "reward redesign" is explicitly excluded; also `OWNER_REFERENCE_REQUIRED` to confirm this is actually meant to be part of *this* reward action rather than a separate system |
| Reward-chest reachability (post-World-Devourer only?) | Unverified | Low-Medium | N/A — requires live/map testing, not a code change |

**Owner gameplay test**: after defeating World Devourer, confirm (a) the reward chest is reached and gives the described backpack/items/achievement, (b) whether "powerful imbuement access" is granted anywhere in the post-quest flow that this audit didn't locate, and (c) that re-opening the chest a second time correctly shows "The chest is empty."
