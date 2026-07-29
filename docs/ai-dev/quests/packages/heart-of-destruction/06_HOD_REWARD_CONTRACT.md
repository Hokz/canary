# 06 — Heart of Destruction Reward Contract

Per package rules: comparison only, no reward implementation in this package.

**HOD-03 correction**: HOD-02 could not confirm the exact identity of 4 reward items (23512, 23538, 23536, 23509) and flagged "powerful imbuement access" as missing from this file. Both concerns are now resolved:
- All 4 items were cross-referenced against `data/items/items.xml` and **exactly match** the owner's reference item names (Spying Eye, Vibrant Egg, Folded Void Carpet, Mysterious Remains — see updated table below).
- "Powerful imbuement access" is **not supposed to be in this file** — the reference clearly describes it as a separate post-quest step (*"After killing World Devourer, player talks to Yana"*), which was fixed this package (see [[01_HOD_NPC_DIALOGUE_CONTRACT]] and [[09_HOD_SAFE_FIXES_APPLIED]]).

**The reward chest is now confirmed fully correct** — no gap remains in this component.

**HOD-05 note**: the reward-claimed flag (storage `14337`) was renamed to `Storage.HeartOfDestructionFinalBattle.RewardClaimed` as part of this package's storage-hygiene pass — value unchanged, purely a naming/registry improvement. See [[03_HOD_STORAGE_CONTRACT]]. No other change to this component; reward priority item was otherwise out of scope for HOD-05 per the owner's instruction to leave it untouched unless a clear bug is found (none was).

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

## Comparison against owner's reference (HOD-03: all items verified against `items.xml`)

| Owner reference item | Repository evidence | Status |
|---|---|---|
| 01 Energetic Backpack | `player:addItem(23525)` — `items.xml:46529` confirms `name="energetic backpack"` | **Implemented, verified** |
| 01 Spying Eye | `container:addItem(23512, 1)` — `items.xml:46471` confirms `name="spying eye"` | **Implemented, verified** |
| 01 Vibrant Egg | `container:addItem(23538, 1)` — `items.xml:46689` confirms `name="vibrant egg"` | **Implemented, verified** |
| 01 Folded Void Carpet | `container:addItem(23536, 1)` — `items.xml:46677` confirms `name="folded void carpet"` | **Implemented, verified** |
| 01 Mysterious Remains | `container:addItem(23509, 1)` — `items.xml:46458` confirms `name="mysterious remains"` | **Implemented, verified** |
| 20 Crystal Coins | `container:addItem(3043, 20)` — `items.xml:6845` confirms `name="crystal coin"` | **Implemented, verified, exact quantity match** |
| 05 Gold Tokens | `container:addItem(22721, 5)` — `items.xml:45101` confirms `name="gold token"` | **Implemented, verified, exact quantity match** |
| Powerful imbuement access | Not in this file — confirmed to be a **separate step via Yana**, per reference structure | **Correctly out-of-scope for this file; implemented elsewhere (Yana, fixed this package)** |
| Achievement: Ender Of The End | `player:addAchievement("Ender of the End")` — `data/scripts/lib/register_achievements.lua:414` confirms this exact achievement (id 413) is registered | **Implemented, verified** (casing difference is display convention, not a mismatch) |

## One-time claim logic

Storage 14337 gates the reward to a single claim per player (`< 1` check, then set to `1`). This is a **per-player storage** (correct scope — `player:getStorageValue`, not `Game.getStorageValue`), consistent with a one-time reward. **Status: Implemented correctly** for the claim-gating mechanism itself. **Risk: Low** for the mechanism; the storage number (14337) is unregistered in `storages.lua`, same registry-hygiene note as the rest of the quest (see [[03_HOD_STORAGE_CONTRACT]] §3) — not a functional risk on its own.

## What triggers the reward

Gated by `item.uid == 1038` — a specific, presumably unique map object (likely the reward chest itself, reached after defeating World Devourer per the quest's structure). This wasn't traced back to confirm it's only reachable post-World-Devourer (would require map data); flagging as an assumption, not a verified fact.

## Summary (updated HOD-03)

| Component | Status | Risk | Safe patch candidate |
|---|---|---|---|
| Energetic Backpack + items + currency | **Implemented, fully verified against items.xml** | Low | N/A |
| Achievement | **Implemented, verified against achievement registry** | Low | N/A |
| One-time claim gating | Implemented correctly | Low | N/A |
| Powerful imbuement access | **Implemented via Yana (fixed this package)** — correctly not part of this file | Low | N/A — resolved |
| Reward-chest reachability (post-World-Devourer only?) | Unverified | Low-Medium | N/A — requires live/map testing, not a code change |

**No remaining gaps in this component.**

**Owner gameplay test**: after defeating World Devourer, confirm (a) the reward chest is reached and gives the described backpack/items/achievement, (b) whether "powerful imbuement access" is granted anywhere in the post-quest flow that this audit didn't locate, and (c) that re-opening the chest a second time correctly shows "The chest is empty."
