# 07 — Heart of Destruction QA / Gameplay Checklist

Owner-facing test steps, following the template in [[08_QUEST_QA_CHECKLIST]]. This checklist consolidates every "requires live testing" item raised across the HOD-02 contracts — it does not require you to complete the quest, only to confirm specific, targeted behaviors so future fix packages can be scoped correctly.

## HOD-FULL new systems — test these first (once map setup is done)

These systems are brand new this package. **Items 1-3 require the map editor placement documented in [[04_HOD_PORTAL_ACCESS_CONTRACT]] MAP SETUP before they're testable at all** — until then, expect these specific tiles/behaviors to simply not exist in-game.

### N1. Vortex entrance gating (requires map setup)
- [ ] Before talking to Messenger of Heaven and finishing the conversation, try stepping on any of the 3 vortex entrance tiles (once placed). Expected: "The vortex does not react to you..." and you're pushed back.
- [ ] After finishing Messenger of Heaven's conversation (through "yes"), try the vortex entrance matching whichever city is *not* currently active (check via GM tools or trial and error). Expected: "The vortex to X is dormant right now..." and pushed back.
- [ ] Try the vortex entrance matching the currently active city. Expected: teleported to that route's existing minigame room (Charges/Cracklers/Sparks lever area).

### N2. Vortex rotation (requires map setup + time, or GM storage inspection)
- [ ] Check `GlobalStorage.HeartOfDestruction.ActiveVortex` (via GM tools) shortly after server start — should be 1, 2, or 3, never 0 or unset.
- [ ] Wait ~2 hours (or check across multiple sessions) and confirm the value changes.

### N3. Permanent vortex access via kills (requires map setup + monster spawns — see below)
- [ ] **Prerequisite**: Dread Intruder, Breach Brood, and Reality Reaver have no map spawns yet (confirmed absent) — this specific test cannot run until spawns are added, which is a separate map task from the vortex entrances themselves.
- [ ] Once spawned: kill 10 Dread Intruders as one character. Expected: a message about permanent access, and the Ankrahmun vortex should now work even when that city isn't the active rotation.

### N4. Destructive charges (testable now — no map dependency)
- [ ] Kill a Frenzy, a Charged Disruption, or an Overcharged Disruption (all reachable in the existing final battle / World Devourer fight). Confirm no errors occur (this hooks into the same shared `HeartMinionDeath` event already used for other final-battle bookkeeping).
- [ ] After defeating World Devourer once (achievement "Ender of the End" obtained), try to re-enter World Devourer with fewer than 5 accumulated charges. Expected: denied with the exact message *"To face the heart of destruction again, you have to gather destructive charges to enter its lair. You gain charges by killing any higher minion of destruction. You have gathered X of 5 charges."*
- [ ] Accumulate 5 charges and confirm entry succeeds, and that charges reset to 0 (or drop by exactly 5) afterward.
- [ ] Confirm a **first-time** (pre-"Ender of the End") entry is NOT blocked by charges — only repeat visits should check this.

### N5. Final battle timing (45 minutes)
- [ ] Time the mini-boss phase (Hunger/Destruction/Rage) specifically — should now allow up to 45 minutes before auto-clearing, not 30. Report back if this feels wrong (e.g., if the intended split was meant to include the World Devourer phase too, rather than being mini-boss-phase-only).

### N6. Messenger of Heaven "yes" (functional TODO text)
- [ ] Complete the full keyword chain through "strong," then say "yes." Expected: a short line ("Go now. The cave nearby holds a way into the incursion...") — **not exact wiki text**, flagged as TODO — plus (invisibly) the `CaveAccess` grant that N1 depends on.

### N7. Questlog (new catalog entry)
- [ ] Open your Quest Log after starting Heart of Destruction (post Messenger of Heaven). Confirm a "Heart of Destruction" entry now appears with 7 missions, and that it advances as you defeat each boss. **Text will read as functional/generic, not polished wiki wording** — that's expected and flagged as TODO in the source file.

## Admin/tester setup notes

Several checks below need a character positioned deep into the quest (e.g., already having defeated Anomaly/Rupture/Realityquake) to reach later gates. If you don't want to grind there normally, an admin/GM account can set the relevant storage directly:
- Anomaly defeated: storage `14326` = 1
- Rupture defeated: storage `14327` = 1
- Realityquake defeated: storage `14328` = 1
- Eradicator defeated: storage `14330` = 1
- Outburst defeated: storage `14332` = 1

These are raw numeric storages (see [[03_HOD_STORAGE_CONTRACT]]), settable via standard GM storage-editing commands if your server build supports them.

## Checklist

### 1. Quest start — Messenger of Heaven (HOD-04: dialogue now implemented — verify it)
- [ ] Greet the "Messenger of Heaven" NPC ("hi"). Expected: *"Greetings, [your name]! It's good to see you alive."*
- [ ] Say the full chain, one word at a time, waiting for a response after each: `alive → peril → thing → past → name → ferumbras → damage → stopped → destroying → destroying (again) → heart of destruction → strong`. Confirm each step responds and that saying the *next* keyword out of order (e.g., skipping ahead) does nothing until you say the correct one.
- [ ] Separately, on a fresh conversation, try the shortcut: `hi → strong`. Expected: same final response as reaching "strong" via the full chain.
- [ ] After "strong," say "yes." Expected per code today: **no spoken response** — the conversation just resets/closes. This is intentional (no exact text was available for this step), but please flag if you have or can obtain the correct line.
- **What we still need from you**: the exact text Messenger of Heaven should say after "yes," if you can obtain it — this is the one remaining gap in this NPC's dialogue.

### 1b. Level / Premium / group requirements (unverified)
- [ ] Confirm whether attempting to pull a first-tier boss lever below level 150 is blocked, and whether a non-Premium account is blocked from entering at all.
- **Why this matters**: not verified against code in this pass — flagged in [[05_HOD_BOSS_MECHANICS_CONTRACT]] as needing confirmation.

### 1b. Level / Premium / group requirements (HOD-03, unverified)
- [ ] Confirm whether attempting to pull a first-tier boss lever below level 150 is blocked, and whether a non-Premium account is blocked from entering at all.
- **Why this matters**: not verified against code in this pass — flagged in [[05_HOD_BOSS_MECHANICS_CONTRACT]] as needing confirmation.

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

### 6. World Devourer — Devourer Core item (HOD-03: re-scoped from "possible bug" to "confirm intended mechanic")
- [ ] While on a World Devourer cooldown, use the "Devourer Core" (item id 23686).
- **Expected per code + reference today**: this should clear your cooldown, letting you fight again immediately — this is the reference's documented mechanic, not a bug. Confirm this actually works in-game as described.
- [ ] Separately, confirm whether entering World Devourer currently requires spending "5 destructive charges" as the reference describes, or whether it's purely cooldown/Devourer-Core gated today.
- **Expected per code today**: no charge system exists — entry should be gated only by the Eradicator/Outburst completion flags and your cooldown, with no charge requirement. If you observe a charge requirement in-game, that's important — it means a mechanic exists that this audit didn't find.

### 6b. Yana — imbuement dialogue (HOD-03: verify the fix applied this package)
- [ ] Before defeating World Devourer, talk to Yana and say "worth."
- **Expected after this fix**: an instructional response describing what's needed, listing all 8 "Powerful" imbuements (not the old, incomplete 3-item text).
- [ ] After defeating World Devourer (achievement "Ender of the End" obtained), talk to Yana again and say "worth."
- **Expected after this fix**: the exact congratulatory text ("I see, you disrupted the Heart of Destruction...") followed by the full 8-imbuement grant line.
- [ ] Greet Yana normally ("hi") and confirm the new greeting text displays.

### 6c. World Devourer — total encounter time budget (HOD-05: mechanism now precisely known)
- [ ] Time the mini-boss phase separately from the World Devourer phase: how long from pulling the final lever until all 3 mini-bosses (Hunger/Destruction/Rage) are dead, and separately how long you have once World Devourer itself begins.
- **Expected per reference**: 45 minutes total for the whole sequence.
- **Expected per code (HOD-05 confirmed)**: up to 30 minutes for the mini-boss phase, then a **fresh, separate** up-to-30-minutes for the World Devourer phase — two sequential windows, not one 45-minute clock. If you actually observe roughly 30+30, that confirms our reading of the code; report back either way.

### 6d. Storage rename regression check (HOD-05 — internal change, should be invisible)
- [ ] Run through the full final battle (all 3 mini-bosses, then World Devourer) end to end at least once.
- **Why**: this package renamed 4 internal storage numbers to named constants (team-tracking for Hunger/Destruction/Rage, and the reward-claimed flag) — values were not changed, but please confirm the mini-boss room rotation, exit-cleanup, and reward chest all still behave exactly as before. Any deviation here would indicate a typo in the rename, not a reference-parity issue.

### 7. World Devourer — cooldown duration (post-PR#4 confirmation)
- [ ] Trigger the World Devourer encounter (pull the final lever) and check your boss cooldown for World Devourer immediately after.
- **Expected**: approximately 13 days, 20 hours (already fixed in PR #4, present on `main`). Confirm the displayed value matches.

### 8. Reward chest
- [ ] After defeating World Devourer, open the reward chest.
- **Expected**: an "energetic backpack" container with several items, 20 of one currency-like item, 5 of another, and the achievement "Ender of the End."
- [ ] Try opening it a second time.
- **Expected**: "The chest is empty."
- [ ] Separately, check whether anything in the post-quest flow grants access to "powerful imbuements" — note where/how if you find it.

### 9. Lesser Messenger of Heaven (unchanged — still has no dialogue)
- [ ] If you can find this NPC (likely near the main Messenger of Heaven or inside the quest area), try talking to it and using the same keyword chain as step 1.
- **Expected per code today**: no response at all — unlike the main Messenger of Heaven (fixed in HOD-04), this NPC was left untouched since nothing in the codebase confirms it shares the same dialogue role. If it turns out to need the same chain, let us know.

## After testing

Send back which items matched expectations and which didn't, plus any exact wording you saw for the ones that did respond (NPC dialogue especially — exact text is valuable and will be preserved per the owner dialogue rule in this package, not paraphrased). This feeds directly into scoping the next HOD implementation package ([[08_HOD_IMPLEMENTATION_BREAKDOWN]]).
