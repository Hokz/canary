# 03 — Issue #599 Fix Audit: The Three Priority Broken Quests

Source: `github.com/opentibiabr/canary/issues/599` ("Many quests do not work properly"), state **CLOSED**, opened 2022-02-09. Labels: `Type: Bug`, `Priority: Low`, `Area: Datapack Global`, `Type: Missing Content`, `Status: Pending Test`. Closed without a linked fix commit found in this audit — the underlying bugs should be treated as **still open** until verified otherwise.

This is a **static-code root-cause audit** (read-only, no files modified). None of the three hypotheses below have been confirmed against a running server. **Live-server reproduction is required before writing any fix.**

---

## Bug 1 — The Inquisition Quest (Shadow Nexus / Henricus mission completion)

**Reported repro**: get the "special flask" (item 7494) from Henricus → go to `33115, 31703, 12` → use the flask repeatedly on the wall to grow a fire to its biggest form → using the flask again destroys "the Nexus" and shows a message → return to Henricus, say "mission" then "yes" → **nothing happens**.

### Files
- NPC: `data-otservbr-global/npc/henricus.lua`
- Nexus growth/destroy action: `data-otservbr-global/scripts/quests/others/actions_holy_water.lua`
- Item decay chain: `data/items/items.xml` (lines 21232–21256, items 7925–7931)
- Storages: `data-otservbr-global/lib/core/storages.lua` line 1059 (`TheInquisitionQuest`), line 3073 (`GlobalStorage.Inquisition = 65013`)

### Evidence

`henricus.lua`:
```lua
180  elseif player:getStorageValue(...Questline) == 20 then
181      npcHandler:say("Destroy the shadow nexus using this vial of holy water and kill all demon lords.", ...)
182      player:setStorageValue(...Questline, 21)
183      player:setStorageValue(...Mission07, 1)
186  elseif ...Questline == 21 or ...Questline == 22 then
187      npcHandler:say("Your current mission is to destroy the shadow nexus... Are you done?", ...)
188      npcHandler:setTopic(playerId, 6)
...
231  elseif npcHandler:getTopic(playerId) == 6 then
232      if player:getStorageValue(...Questline) == 22 then   -- completion check
237          player:setStorageValue(...Questline, 23)
```

`actions_holy_water.lua`:
```lua
2    local shadowNexusPosition = Position(33115, 31702, 12)
106  elseif table.contains({ 7925, 7927, 7929 }, target.itemid) then   -- "grow the fire"
108      if target.itemid == 7929 then Game.setStorageValue(GlobalStorage.Inquisition, math.random(4, 5)) end
119  elseif target.itemid == 7931 then                                -- "biggest form" / destroy
120      if Game.getStorageValue(GlobalStorage.Inquisition) > 0 then
121          Game.setStorageValue(GlobalStorage.Inquisition, Game.getStorageValue(GlobalStorage.Inquisition) - 1)
122          if player:getStorageValue(...Questline) < 22 then
123              player:setStorageValue(...Mission07, 2)
124              player:setStorageValue(...Questline, 22)
131          player:setStorageValue(...Questline, 22)   -- redundant with 124
134      else
135          target:transform(7925)   -- silently resets, no storage set, no message
```

`items.xml` 21249–21256: item 7930 decays to 7931 in **30s**; item 7931 (biggest-form) decays back to 7925 in only **20s**.

### Root-cause hypothesis
Taken purely as dialogue/storage logic, Henricus's checks (`Questline == 21/22` → topic 6 → `Questline == 22` on "yes") are internally consistent with what `actions_holy_water.lua` sets on success — **this is not a simple keyword or off-by-one bug**. The most defensible failure mode is a **concurrency/timing defect**:

1. `GlobalStorage.Inquisition` is **world-scoped, not per-player** — it guards a single shared map object. On a populated server, concurrent players/parties growing the same Nexus can decrement each other's counters, silently routing the "destroy" attempt into the `else` branch (line 134: reset, no message, no storage set) — which looks exactly like "using the flask does nothing."
2. Item 7931 only exists for **20 seconds** before auto-decaying back to 7925. Henricus's own instruction ("destroy the nexus **and** kill all demon lords") may cause players to miss this window while fighting, resetting progress silently.
3. Minor: the bug report's repro position (`33115,31703,12`) is 1 tile off from `shadowNexusPosition = Position(33115, 31702, 12)` — worth checking against the live map, though this alone wouldn't explain the reported symptom (using the flask on the wall clearly did visibly work per the report).

### Fix classification
**(d) Deeper architectural issue** — primarily a shared/global-vs-per-player storage misuse plus a fragile short decay timer, not a missing branch or single mismatched constant.

### Future patch plan
1. Reproduce live: have 2 characters attempt the Nexus sequence back-to-back / concurrently and see if one desyncs the other via `GlobalStorage.Inquisition`.
2. If confirmed: convert the Nexus destroy-progress counter to per-player (or per-party) tracking instead of a single `GlobalStorage` value, OR add explicit locking/ownership so only the player who grew the fire can destroy it.
3. Evaluate lengthening the 7930→7931→7925 decay window so players have realistic time to use the flask on 7931 without racing a 20s timer.
4. Re-verify the `33115,31703,12` vs `33115,31702,12` position discrepancy against the actual map tile.
5. Do not touch Henricus's dialogue branches unless live testing shows they are actually unreachable — current evidence suggests the dialogue logic is correct and the bug is upstream in the action script.

### Validation checklist
- [ ] Single player, full solo run: get flask → grow fire → destroy Nexus → talk to Henricus ("mission", "yes") → mission advances.
- [ ] Two players attempt the Nexus sequence concurrently — confirm neither desyncs the other.
- [ ] Time the flask-use sequence against the 20s decay window under realistic (non-GM) conditions.
- [ ] Confirm the exact map tile position the wall/Nexus interaction requires.

### What the project owner must test in-game
1. Get the special flask from Henricus (Thais).
2. Go to the Demon Forge area, use the flask on the wall repeatedly until the fire grows to its biggest form, then use the flask once more — confirm you get the "you destroyed the Nexus" message.
3. Return to Henricus, say "mission" then "yes" — **expected**: he acknowledges completion and moves you to the next step. **Currently reported**: nothing happens.
4. If possible, repeat with a second character at the same time to see if that changes the outcome.

---

## Bug 2 — Wrath of the Emperor Quest (Zizzle mission dialogue)

**Reported repro**: talk to Zizzle, say "mission" then "yes" — nothing happens.

### Files
- NPC: `data-otservbr-global/npc/zizzle.lua`
- Framework: `data/npclib/npc_system/keyword_handler.lua`, `npc_handler.lua` — confirmed the **same** KeywordHandler/NpcHandler pattern the old community-submitted snippet used; framework is not the issue.
- Adjacent NPCs: `data-otservbr-global/npc/zlak.lua`, `data-otservbr-global/npc/a_sleeping_dragon.lua`
- Storages: `data-otservbr-global/lib/core/storages.lua` line 1563 (`Storage.Quest.U8_6.WrathOfTheEmperor`)
- Questlog catalog: `data-otservbr-global/lib/core/quests/catalog/034_wrath_of_the_emperor.lua`

### Evidence

`zizzle.lua` — entire "mission" handler:
```lua
58   if MsgContains(message, "mission") then
59       if player:getStorageValue(Storage.Quest.U8_6.WrathOfTheEmperor.Questline) == 25 then
...      player:setStorageValue(...Questline, 26)
66       elseif ...Questline == 26 then
...      npcHandler:setTopic(playerId, 1)
77       elseif ...Questline == 29 then
78           if player:getStorageValue(...Questline) < 30 then   -- always true given line 77 — dead branch
...              player:setStorageValue(...Questline, 30)
95           else
96               npcHandler:say({ "Now go to the north of Sleeping Dragon room..." })
97           end
98       end
       -- NO else/fallback for any other Questline value → dialogue produces nothing
99   elseif MsgContains(message, "yes") then
100      if npcHandler:getTopic(playerId) == 1 then ... end
       -- again no fallback if topic ~= 1
113  end
```

The 2022 community comment (Mirkaanks, on issue #599) pasted an **old TFS-style full NPC script** that deliberately comments out the `==25`/`==26` branches and replaces `elseif ...Questline == 29` with a top-level `if ...Questline < 29`. The current repo's code shows the strict `== 29` outer check **plus** a dead nested `< 30` check — a signature of a partially/incorrectly merged port of that community fix.

`zlak.lua:93-94` confirms `Questline` is correctly set to `25` (with `Mission08=1`) before reaching Zizzle. `a_sleeping_dragon.lua:221` confirms `Questline` is correctly set to `29` after the dream sequence. So the `==29` check numerically matches what's set upstream — **the break is not a storage mismatch**.

### Root-cause hypothesis
Zizzle's `creatureSayCallback` has **no default/fallback branch** for "mission" or "yes" — it only responds to exactly three `Questline` values (25, 26, 29). Any player whose storage isn't exactly one of those (fresh character, GM/QA character with no storage set, or a player mid-way through an adjacent sub-step at 27/28) gets **zero response**, matching "says mission then yes — nothing happens." Additionally, the old community-fix snippet references `Storage.WrathoftheEmperor.*` (flat), which **does not exist** in this repo's registry (`Storage.Quest.U8_6.WrathOfTheEmperor.*`) — pasting that snippet verbatim would error, confirming it's not directly reusable.

### Fix classification
**(b) Missing dialogue branch/keyword** — needs a catch-all response, plus cleanup of the dead nested conditional left over from an incomplete merge.

### Future patch plan
1. Reproduce live with a normal player character at the exact expected `Questline` value (29, per `a_sleeping_dragon.lua`) to confirm the dialogue does fire correctly at that value.
2. Add an `else` branch inside the "mission" handler (and the "yes"/topic handler) that gives a sensible default response for any unhandled `Questline` state, instead of silence.
3. Remove or fix the dead `if ...Questline < 30 then ... else ...` nested conditional at line 78 (redundant given the outer `== 29` check) — clarify what state it was meant to distinguish.
4. Do **not** reintroduce the old flat `Storage.WrathoftheEmperor` keys — keep using `Storage.Quest.U8_6.WrathOfTheEmperor.*`.

### Validation checklist
- [ ] Fresh character with `Questline` unset — Zizzle gives a sensible "come back later" style response instead of silence.
- [ ] Character at `Questline == 25` — "mission" advances to 26 as coded.
- [ ] Character at `Questline == 26` — "mission" then "yes" at topic 1 advances to 27, grants items.
- [ ] Character at `Questline == 29` (post-dream-sequence, via `a_sleeping_dragon.lua`) — "mission" advances to 30, grants `BossStatus`/`Mission10` updates and item 12318.
- [ ] Character at any other value (27, 28, 30+) — dialogue gives an intentional response, not silence.

### What the project owner must test in-game
1. Progress a character through Wrath of the Emperor up to the point of talking to Zalamon/dream sequence (or use an admin command to set the questline storage if testing mid-quest is impractical — note the exact value used).
2. Talk to Zizzle, say "mission" — **expected**: a response advancing the quest. **Currently reported**: nothing at any point.
3. If a response is received, say "yes" and confirm items/messages match the intended flow (freeing the dragon, receiving the sceptre replica, etc.).

---

## Bug 3 — Heart of Destruction Quest (storages, puzzles, portals, boss mechanics)

**Reported repro**: at `32091, 31329, 12`, use the lever, solve the puzzle — the portals that should grant boss access don't work afterward.

### Files (all under `data-otservbr-global/scripts/quests/heart_of_destruction/`)
- Lever puzzles: `actions_charges_lever.lua`, `actions_cracklers_lever.lua`, `actions_sparks_lever.lua`, `actions_final_lever.lua`
- Portal gating: `movements_teleport_heart.lua`
- Kill-count → storage grants: `creaturescripts_overcharge_death.lua`, `creaturescripts_depolarized_death.lua`, `creaturescripts_spark_death.lua`, `creaturescripts_heart_boss_death.lua`
- Registry: `data-otservbr-global/lib/core/storages.lua` lines 2204 & 3040-3054 (`Storage.HeartOfDestruction` — used only for **in-boss-fight** mechanics like `ChargedAnomaly`/`ForeshockStage`, **not** for access/portal gating)

### Evidence

`actions_charges_lever.lua:206-210` — lever at `pushPos = {x=32091, y=31327, z=12}` (repro reports `32091,31329,12`, ~2 tiles off), spawns 10 "Charger" + 5 "Overcharge" monsters, resets `Game.setStorageValue(14321, 0) -- Overcharge Count`.

`creaturescripts_overcharge_death.lua:49-60`:
```lua
51  Game.setStorageValue(14321, Game.getStorageValue(14321) + 1)
53  if Game.getStorageValue(14321) == 5 then
54      setStorage()                       -- grants player storage 14320 (Anomaly access)
56      Game.setStorageValue(14321, -1)
```

`movements_teleport_heart.lua:18-22,68-69`:
```lua
18  [14323] = { position = Position(32246, 31252, 14), storage = 14320, boss = "Anomaly" },
...
68  elseif data.storage then
69      if player:getStorageValue(data.storage) >= 1 then ...
```

Access-gating storage IDs (14320–14354) traced across all boss chains (Anomaly, Eradicator, Outburst, World Devourer) — setter/checker pairs are **numerically self-consistent**; no simple off-by-N mismatch found. Architectural weaknesses found instead:

1. **None of the access-gating storages (14320-14354) are registered in the centralized `Storage.*`/`GlobalStorage.*` table** — contrast with `Storage.HeartOfDestruction` (line 3040), which only covers boss-internal mechanics. These are bare magic numbers duplicated across ~9 files.
2. **Copy-paste comment bug**: `creaturescripts_depolarized_death.lua:16` and `creaturescripts_spark_death.lua:14` both say `-- Access to boss Anomaly` despite actually granting Rupture/Realityquake access respectively — a strong signal of rushed porting in this exact area.
3. **Strict equality on shared, world-scoped kill counters** is the strongest functional-bug candidate: `Game.getStorageValue(14321) == 5`, `Game.getStorageValue(14323) == 10`, and a bare Lua global `unstableSparksCount` compared with `== 10` are **not per-player/per-party**. Monsters removed via `Creature:remove()` inside each lever's `clearArea()` function (fired when a second party enters mid-attempt) do **not** trigger `onDeath`, so those "kills" never increment the counter — permanently desyncing it from the exact threshold needed, silently withholding the access grant.

### Root-cause hypothesis
The lever→portal chain is logically wired correctly end-to-end, but relies on **fragile, non-namespaced, world-scoped exact-match kill counters** that are easily desynced by monster removal during room resets or by concurrent parties sharing the same global counters — producing "solved the puzzle but the portal doesn't work" without any single obviously-wrong line.

### Fix classification
**(d) Deeper architectural issue** (shared mutable global counters + un-registered magic-number storages), with **(a) storage mismatch** as a plausible secondary contributor once a specific desynced counter is identified live. This quest has 32 files — recommend live-server reproduction with logging on storages 14320-14332 before writing a fix, since the exact trigger could not be confirmed statically.

### Future patch plan
1. Reproduce live with logging/print statements on storages 14320-14332 to catch the exact counter that fails to reach its threshold.
2. Specifically test the "second party interrupts a solo attempt" scenario (`clearArea()` triggering `Creature:remove()` mid-kill-sequence) as the leading hypothesis.
3. Register the 14320-14354 range formally in `Storage.HeartOfDestruction` (or migrate to KV per `CONTRIBUTING.md`) so future maintainers aren't working with bare magic numbers.
4. Fix the mismatched comments in `creaturescripts_depolarized_death.lua:16` and `creaturescripts_spark_death.lua:14`.
5. Consider migrating the boss-access gating to the `BossLever` library (`data/libs/functions/boss_lever.lua`, see [[01_QUEST_ARCHITECTURE_AUDIT]] §7) which has built-in zone occupancy and cooldown handling designed to avoid exactly this class of bug — this is a larger change and should be scoped separately from the immediate bug fix.

### Validation checklist
- [ ] Solo player: pull the Charges lever, kill exactly 5 Overcharge monsters, confirm storage 14320 is granted and the Anomaly portal (`movements_teleport_heart.lua`) works.
- [ ] Repeat for the Cracklers and Sparks levers (their respective thresholds/storages).
- [ ] Attempt the puzzle with two separate parties overlapping in the area — confirm `clearArea()` doesn't silently eat kills from an in-progress attempt.
- [ ] Confirm final boss portal access after all sub-puzzles are solved.
- [ ] Confirm the exact lever position (`32091,31327,12` in code vs `32091,31329,12` in the report) against the live map.

### What the project owner must test in-game
1. Go to the Heart of Destruction entrance, pull the first lever (Charges), and fight through the spawned monsters until the room clears.
2. Check whether the portal tied to that lever's boss becomes usable — note exactly which portal does/doesn't work.
3. Repeat for the Cracklers and Sparks levers.
4. If possible, try this with a second group nearby (not necessarily fighting) to see if their presence affects your progress.
5. Report the exact lever position you used, and any Lua console errors visible to server admins during the attempt (these get logged even if not shown to the player).

---

## Cross-cutting notes for whoever implements these fixes

- All three bugs share a pattern: **world-scoped or globally-shared storage counters used for what should be per-player/per-party state.** This is worth calling out as a systemic risk in [[04_QUEST_STORAGE_REGISTRY]], not just three isolated bugs.
- None of these fixes should be attempted without live-server reproduction first — the static analysis narrows the search space but does not confirm the exact failure trigger for Bugs 1 and 3.
- Bug 2 is the most actionable without live reproduction (missing fallback branch is a clear, low-risk fix), but should still be tested against all reachable `Questline` values before merge.
