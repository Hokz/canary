# 07 — Heart of Destruction QA / Gameplay Checklist

Owner-facing test steps, following the template in [[08_QUEST_QA_CHECKLIST]]. This checklist consolidates every "requires live testing" item raised across the HOD-02 contracts — it does not require you to complete the quest, only to confirm specific, targeted behaviors so future fix packages can be scoped correctly.

## Admin/tester setup notes

Several checks below need a character positioned deep into the quest (e.g., already having defeated Anomaly/Rupture/Realityquake) to reach later gates. If you don't want to grind there normally, an admin/GM account can set the relevant storage directly:
- Anomaly defeated: storage `14326` = 1
- Rupture defeated: storage `14327` = 1
- Realityquake defeated: storage `14328` = 1
- Eradicator defeated: storage `14330` = 1
- Outburst defeated: storage `14332` = 1

These are raw numeric storages (see [[03_HOD_STORAGE_CONTRACT]]), settable via standard GM storage-editing commands if your server build supports them.

## Checklist

### 1. Quest start — Messenger of Heaven
- [ ] Find and talk to the "Messenger of Heaven" NPC. Try "hi," then try any keyword you'd naturally guess (e.g., "heart," "destruction," "mission," "quest").
- **Expected per code today**: no response to anything (the NPC has no dialogue configured at all — see [[01_HOD_NPC_DIALOGUE_CONTRACT]]).
- **What we need from you**: confirm this matches what you see live. If the NPC *does* respond to something, that's important — it means dialogue exists somewhere this audit didn't find, and we need to know what you said and what it replied.

### 2. Outer vortex access
- [ ] Check whether there's currently any way to reach the Heart of Destruction boss network from Ankrahmun, Svargrond, or Zao specifically (a portal, a hole, an NPC-given teleport — anything city-specific).
- [ ] Note where you actually enter the quest area from today, if you know a path.
- **Expected per code today**: no rotating city-based entrance exists. Confirm whether the actual entrance is a single fixed location instead, and if so, where.

### 3. First-tier boss room — player limit and team size
- [ ] Try pulling one of the first-tier levers (Anomaly/Rupture/Realityquake) **solo** (alone, no group).
- **Expected per code today**: the lever should activate even solo — `minPlayers` is not overridden above its default of 1 in any of the three configs. Confirm whether this matches what you see, or whether it actually blocks you and requires more players.

### 4. First-tier boss room — time limit
- [ ] Time how long you have in a first-tier boss room before being auto-removed if you don't finish (or deliberately let the timer run out once, if safe to do so).
- **Expected per code today**: this uses a shared server-wide default we did not look up in this pass — could be more or less than 15 minutes. Report the actual observed duration.

### 5. Second-tier unlock — credit attribution
- [ ] With a group, have one player NOT participate in a first-tier boss fight but stand somewhere in the room when the boss dies. Check whether that non-participating player still gets Eradicator/Outburst portal access afterward.
- **Expected per code today**: yes, they would — credit is granted by room presence at the moment of death, not by tracked participation. Confirm whether this is actually a problem worth fixing, or acceptable as-is.

### 6. World Devourer — cooldown item
- [ ] While on a World Devourer cooldown (i.e., you've fought it recently and are waiting), use the item associated with `actions_devourer_access.lua` (item id 23686 — describe/identify what this item is in-game if you can).
- **Expected per code today**: this might clear your cooldown entirely, letting you fight again immediately. Confirm whether that's what happens, and whether that's intended (a deliberate "skip the wait" item) or a bug.

### 7. World Devourer — cooldown duration (post-PR#4 confirmation)
- [ ] Trigger the World Devourer encounter (pull the final lever) and check your boss cooldown for World Devourer immediately after.
- **Expected**: approximately 13 days, 20 hours (already fixed in PR #4, present on `main`). Confirm the displayed value matches.

### 8. Reward chest
- [ ] After defeating World Devourer, open the reward chest.
- **Expected**: an "energetic backpack" container with several items, 20 of one currency-like item, 5 of another, and the achievement "Ender of the End."
- [ ] Try opening it a second time.
- **Expected**: "The chest is empty."
- [ ] Separately, check whether anything in the post-quest flow grants access to "powerful imbuements" — note where/how if you find it.

### 9. Lesser Messenger of Heaven
- [ ] If you can find this NPC (likely near the main Messenger of Heaven or inside the quest area), try talking to it the same way as step 1.
- **Expected per code today**: same as Messenger of Heaven — no configured response.

## After testing

Send back which items matched expectations and which didn't, plus any exact wording you saw for the ones that did respond (NPC dialogue especially — exact text is valuable and will be preserved per the owner dialogue rule in this package, not paraphrased). This feeds directly into scoping the next HOD implementation package ([[08_HOD_IMPLEMENTATION_BREAKDOWN]]).
