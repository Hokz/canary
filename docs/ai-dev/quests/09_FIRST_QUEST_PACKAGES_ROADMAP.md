# 09 — First 10 Quest Packages Roadmap

Priority order set by the project owner: (1) #599 fixes first, (2) simple chest/reward quests, (3) exchange quests, (4) NPC dialogue quests, (5) addon/outfit quests, (6) multi-mission questlines, (7) boss/puzzle/endgame quests. Packages below are ordered accordingly, front-loading small blast-radius fixes and pushing architecturally risky work to the end.

**"Autonomous implementation allowed" answers whether an AI agent may write and test code for this package without a new round of owner scoping approval.** It never means autonomous merge/push/PR — per [[06_QUEST_IMPLEMENTATION_PROTOCOL]] §9, that always requires explicit owner approval regardless of this column.

---

## Package 1 — Fix the Three #599 Priority Bugs

**Quests included**: The Inquisition (Henricus/Shadow Nexus), Wrath of the Emperor (Zizzle), Heart of Destruction (lever puzzle/portal access).

**Why early**: Explicitly prioritized by the owner; these are fixes to existing, already-scripted content (smaller blast radius than new implementation); root causes are already partially diagnosed in [[03_QUEST_ISSUE_599_FIX_AUDIT]], so implementation can start from live-repro rather than cold investigation.

**Files expected to inspect**: `data-otservbr-global/npc/henricus.lua`, `data-otservbr-global/npc/zizzle.lua`, `data-otservbr-global/npc/zlak.lua`, `data-otservbr-global/npc/a_sleeping_dragon.lua`, `data-otservbr-global/scripts/quests/others/actions_holy_water.lua`, `data-otservbr-global/scripts/quests/heart_of_destruction/*`, `data-otservbr-global/lib/core/storages.lua`, `data/items/items.xml`.

**Files expected to modify later**: `zizzle.lua` (add fallback branch — low risk); `actions_holy_water.lua` and/or `items.xml` decay timing (medium risk — verify against live multi-player behavior first); Heart of Destruction creaturescripts/actions files (medium-high risk — 9 files, shared counters).

**Dependencies**: Live dev server access for reproduction (see [[03_QUEST_ISSUE_599_FIX_AUDIT]] — none of the three hypotheses are confirmed without it).

**Risk**: Medium. Bug 2 (Zizzle) is low-risk (additive fallback branch). Bugs 1 and 3 touch shared/global storage patterns — a wrong fix could newly break currently-working edge cases.

**Test plan**: [[03_QUEST_ISSUE_599_FIX_AUDIT]] validation checklists per bug, converted to owner-facing format via [[08_QUEST_QA_CHECKLIST]].

**Rollback plan**: Each bug fixed as an independent commit; revert the specific commit if the owner's test fails. No shared-library changes anticipated for Zizzle; Bug 1/3 fixes should avoid touching `BossLever`/`quest_reward_common.lua` to keep rollback scoped to the quest folder.

**Autonomous implementation allowed**: Yes for Bug 2 (Zizzle fallback branch — low risk, clearly scoped). For Bugs 1 and 3, implementation should wait for a live-repro session (agent with server access, or owner-assisted) before writing the fix — investigate autonomously, implement only after repro confirms the hypothesis.

---

## Package 2 — Quick Comment-Sourced Bug Fixes

**Quests included**: The Ape City (Mission 9 teleport wrong `item.uid`), The Thieves Guild (Black Bert wrong storage comparison).

**Why early**: Both are single-line, precisely-diagnosed fixes reported directly in issue comments with exact file/line and exact correct value — about as low-risk as a quest fix gets.

**Files expected to inspect/modify**: `data-otservbr-global/scripts/quests/the_ape_city/*teleport*.lua` (path may have shifted since the 2020 report — locate via `item.uid` search), `data-otservbr-global/npc/black_bert.lua` (or current path).

**Dependencies**: None beyond confirming current file paths (repo has moved things since the 2020 reports).

**Risk**: Low — single-value corrections, exact fix already specified by the reporter.

**Test plan**: Verify each teleport/trade step referenced in the original comments now works as described.

**Rollback plan**: Single-line reverts.

**Autonomous implementation allowed**: Yes — locate current file, confirm the reported line still shows the same bug, apply the reporter's exact suggested value, test.

---

## Package 3 — Chest/Reward Quest Fixes

**Quests included**: Svargrond Barbarian Arena (Ultimate Challenges reward chests + trophy tile), Liquid Black (missing questlog entry after Spectulus).

**Why this position**: First "simple chest/reward" category package per owner priority; both are scoped, single-mechanism fixes (a chest/trophy trigger, a questlog entry) rather than full questline logic.

**Files expected to inspect**: `data-otservbr-global/scripts/quests/svargrond_arena/*`, `data-otservbr-global/scripts/quests/liquid_black/*`, `data-otservbr-global/lib/core/quests/catalog/` (check for a Liquid Black entry — none found in the current 51-entry list, see [[05_QUEST_IMPLEMENTATION_STATUS]] §2).

**Files expected to modify later**: Svargrond Arena reward-chest/trophy-tile action scripts; Liquid Black's Spectulus NPC dialogue and/or a new questlog catalog entry.

**Dependencies**: Package 4's exchange-quest research may reveal shared reward-chest infrastructure worth reusing (`quest_reward_common.lua` — see [[01_QUEST_ARCHITECTURE_AUDIT]] §9); not a hard blocker.

**Risk**: Low-medium.

**Test plan**: Complete each Ultimate Challenge and confirm chest/trophy; talk to Spectulus and confirm Quest Log updates.

**Rollback plan**: Scoped to each quest's own files; independent commits per quest.

**Autonomous implementation allowed**: Yes.

---

## Package 4 — Exchange Quest Research & Implementation

**Quests included**: Newbie Islands Exchange set (Pick, Present, Short Sword, Small Health Potion, Studded Legs, Studded Shield) + Mainland Exchange set (Marlin Trophy, Obsidian Knife, The Mermaid Marina, The Sweaty Cyclops).

**Why this position**: Matches owner's "exchange quests" priority tier; these are structurally the simplest quest type (trade item A for item B via one NPC interaction), good for validating the KV-based implementation pattern on genuinely new content before tackling harder categories.

**Files expected to inspect**: No matching folders found in this audit ([[02_QUEST_ISSUE_618_AUDIT]] §C) — start with a targeted grep across `data-otservbr-global/npc/` for NPCs plausibly tied to these trades, and check `actions/other/others/quest_system1.lua`/`quest_system2.lua` for legacy monolithic handling before assuming these are unimplemented.

**Files expected to modify/create**: Likely new NPC trade-dialogue branches or new small action scripts under a new `data-otservbr-global/scripts/quests/others/` addition, using `player:questKV`.

**Dependencies**: None blocking; benefits from [[01_QUEST_ARCHITECTURE_AUDIT]] §9's reward-table pattern if any of these turn out to be chest-based rather than NPC-trade-based.

**Risk**: Low (self-contained, no shared state with other quests) but **research-heavy** — actual scope unknown until the "no folder found" quests are confirmed genuinely missing vs. misfiled.

**Test plan**: For each quest, trade the documented item and confirm the correct reward item + any relevant message.

**Rollback plan**: New, additive content — revert is simply removing the new script/dialogue branch.

**Autonomous implementation allowed**: Research phase yes. Implementation yes once research confirms a quest is genuinely missing (not just misfiled) — flag any "actually already exists" findings back into [[02_QUEST_ISSUE_618_AUDIT]] instead of implementing a duplicate.

---

## Package 5 — NPC Dialogue Quest Fixes

**Quests included**: The New Frontier (Wyrdin, Mission 05 keyword bug), Demon Oak (Oldrak skip bug), Lion's Rock (trial/tile ordering).

**Why this position**: Matches owner's "NPC dialogue quests" priority tier; all three are dialogue/sequencing bugs in otherwise-implemented multi-mission quests, a good fit right after the simpler categories and before full new-questline work.

**Files expected to inspect**: `data-otservbr-global/npc/wyrdin.lua` (or current name), `data-otservbr-global/npc/oldrak.lua`, `data-otservbr-global/scripts/quests/lions_rock/*`.

**Files expected to modify later**: Wyrdin's keyword-matching logic (per [[07_QUEST_NPC_DIALOGUE_PROTOCOL]] — likely a `MsgContains` mismatch against the documented keyword list); Oldrak's Demon Oak branch (missing requirement check + missing questlog write); Lion's Rock trial-order gating logic.

**Dependencies**: None.

**Risk**: Low-medium — dialogue logic changes are usually additive/corrective, but Demon Oak's "skips the 6666-demon requirement" needs care not to make the quest *harder* than intended while fixing the skip.

**Test plan**: Exact keyword sequences and expected NPC responses per [[08_QUEST_QA_CHECKLIST]]; for Lion's Rock, test both documented "any order" claims from the wiki against actual required order.

**Rollback plan**: Independent commits per NPC/quest.

**Autonomous implementation allowed**: Yes.

---

## Package 6 — Newbie Islands Quest Pack

**Quests included**: Bear Room, Captain Iglue's Treasure, Child of Destiny, Combat Knife, Doublet, Dragon Corpse, Goblin Temple, Katana, Minotaur Hell, Rapier, Sanctuary of the Lizard God, Tutorial.

**Why this position**: These are simple/early-game quests (mostly chest or single-NPC), high value for new-player experience, and a natural "simple quest" batch to implement once the fix-focused packages establish working patterns. Positioned before addon/outfit and multi-mission work per the owner's general simple-before-complex preference, even though it's technically a mixed bag of chest/NPC types.

**Files expected to inspect**: No matching folders found ([[02_QUEST_ISSUE_618_AUDIT]] §C) — requires research pass first (same caveat as Package 4) to confirm genuinely missing vs. misfiled.

**Files expected to modify/create**: Likely new quest folders under `data-otservbr-global/scripts/quests/`, new/edited NPC files, possible new questlog catalog entries.

**Dependencies**: Research findings from Package 4 (shared methodology) are useful context but not a hard blocker.

**Risk**: Low individually; medium in aggregate (12 quests in one package — consider splitting into 2-3 sub-batches during actual implementation rather than one giant PR, per [[06_QUEST_IMPLEMENTATION_PROTOCOL]] §3 scope discipline).

**Test plan**: Full walkthrough per quest (short, since these are newbie-tier), via [[08_QUEST_QA_CHECKLIST]].

**Rollback plan**: New additive content, one commit per quest recommended for independent revert.

**Autonomous implementation allowed**: Research yes. Implementation yes, but recommend splitting into per-quest or small sub-batch PRs rather than one 12-quest package, to keep rollback scope tight.

---

## Package 7 — Addon/Outfit Quest Pack (Round 1)

**Quests included**: Newbie Islands Addon set (Citizen Outfits on Rook, Druid Outfits on Rook); verification pass on existing `assassin_outfit`, `druid_outfits_quest`, `hunter_outfits_quest` folders.

**Why this position**: Matches owner's "addon/outfit quests" priority tier — placed after the simpler categories, before full multi-mission questlines, per the given order.

**Files expected to inspect**: `data-otservbr-global/scripts/quests/assassin_outfit/*`, `druid_outfits_quest/*`, `hunter_outfits_quest/*` (verify these are complete/correct); research pass for the two missing Newbie Islands addon quests.

**Files expected to modify/create**: Addon-granting action/dialogue scripts; possibly `player:addOutfit`/`addOutfitAddon` calls tied to quest completion storage/KV.

**Dependencies**: None blocking.

**Risk**: Low — addon grants are simple, well-understood API calls; main risk is granting the wrong addon (2 vs 1) or granting without checking prior completion (duplicate-grant bugs).

**Test plan**: Confirm correct addon (not just outfit) unlocks in the outfit selection menu after quest completion; confirm re-running the quest doesn't duplicate-grant or error.

**Rollback plan**: Independent commits per quest.

**Autonomous implementation allowed**: Yes.

---

## Package 8 — Multi-Mission Questline Fixes (Complex Content)

**Quests included**: The Secret Library (wrong chest rewards), Threatened Dreams (broken prop + unverified partial PR), Ferumbras' Ascension (multiple reported Lua errors: NPC spawn, lever `setStorageValue` nil-index errors, gem-puzzle nil-index errors, unresponsive doors).

**Why this position**: Matches owner's "multi-mission questlines" priority tier; deliberately placed after the simpler categories because these are large, already-partially-implemented questlines with multiple independent reported defects — higher research and coordination cost than the earlier packages.

**Files expected to inspect**: `data-otservbr-global/scripts/quests/the_secret_library_quest/*`, `threatened_dreams/*`, `ferumbras_ascension/*` (largest of the three — multiple lever/gem/door/NPC files implicated).

**Files expected to modify later**: Secret Library chest-reward table entries (`startup/tables/chest.lua` if using the generic system, or per-quest reward scripts); Threatened Dreams prop action script (cross-check `otservbr-global#633` for prior work before redoing it); Ferumbras' Ascension lever/gem scripts — the reported `table index is nil` errors in `plagirath_lever.lua`/`zamulosh_lever.lua` and `blue_gem.lua`/`red_gem.lua`/`green_gem.lua` suggest a shared state table is never initialized — trace its definition before patching call sites.

**Dependencies**: Verify whether `otservbr-global#633` (a separate repo/PR referenced in comments) was ever merged — avoid redoing already-completed work.

**Risk**: Medium-high — Ferumbras' Ascension in particular has multiple interacting bugs across boss/lever/puzzle systems; a partial fix could leave the questline in a worse, harder-to-diagnose state than before.

**Test plan**: Full puzzle-room walkthrough for Ferumbras' Ascension (levers, gem tiles, door sequence, boss spawn) — this needs either a coordinated multi-character test or GM-assisted state manipulation, document clearly in the QA checklist which steps need help.

**Rollback plan**: Strongly recommend splitting Ferumbras' Ascension into separate commits per subsystem (lever fix / gem-puzzle fix / door fix / NPC spawn fix) so a bad fix to one subsystem doesn't force reverting all four.

**Autonomous implementation allowed**: Research and diagnosis yes. Implementation should proceed incrementally (one subsystem at a time) with owner check-ins between subsystems for Ferumbras' Ascension specifically, given the error count and interaction risk. Secret Library and Threatened Dreams fixes are lower-risk and can proceed autonomously.

---

## Package 9 — Boss/Puzzle/Endgame: Heart of Destruction Architecture Fix

**Quests included**: Heart of Destruction (follow-up to Package 1's live-repro fix) — formal storage registration, comment-mismatch cleanup, evaluation of migrating access-gating to `BossLever`.

**Why late**: Matches owner's "boss/puzzle/endgame quests" priority tier (last); this package is explicitly the **architectural hardening follow-up** to Package 1's tactical fix, not a new bug hunt — it should only start once Package 1's live-repro has identified the actual desyncing counter.

**Files expected to inspect**: All 32 files in `data-otservbr-global/scripts/quests/heart_of_destruction/`, `data/libs/functions/boss_lever.lua`, `data/libs/functions/lever.lua`.

**Files expected to modify later**: `storages.lua` (formally register the 14320-14354 range), the two mismatched comments (`creaturescripts_depolarized_death.lua:16`, `creaturescripts_spark_death.lua:14`), and — if the owner approves the larger scope — migrating access gating onto `BossLever`.

**Dependencies**: Hard dependency on Package 1's Heart of Destruction fix and live-repro findings.

**Risk**: High if the `BossLever` migration is included (touches a shared library used by many other boss quests — see [[06_QUEST_IMPLEMENTATION_PROTOCOL]] §10 on shared-library blast radius); low if scoped to just registry documentation + comment fixes.

**Test plan**: Full Heart of Destruction walkthrough (all 3+ levers, all boss portals) plus regression check on at least one other `BossLever`-based quest (e.g. Ferumbras' Ascension boss room) if the migration is done.

**Rollback plan**: Split into two independent PRs — (a) low-risk registry/comment cleanup, (b) high-risk `BossLever` migration — so (a) can ship even if (b) is deferred or reverted.

**Autonomous implementation allowed**: Yes for (a) registry/comment cleanup. **No** for (b) the `BossLever` migration — requires explicit owner go-ahead given the shared-library blast radius, per [[06_QUEST_IMPLEMENTATION_PROTOCOL]] §10.

---

## Package 10 — Issue #618 "Unknown" Bucket Triage (Research Package)

**Quests included**: Systematic research pass over the ~150 wiki-listed quests with no matched folder/catalog entry ([[02_QUEST_ISSUE_618_AUDIT]] §C).

**Why last**: This is a **research package, not an implementation package** — its output is an updated, much more precise version of [[02_QUEST_ISSUE_618_AUDIT]] and [[05_QUEST_IMPLEMENTATION_STATUS]] that will define quest packages 11+. It belongs at the end of the *first* 10 because everything before it can proceed on already-identified, concrete work; this one produces the backlog for what comes next.

**Files expected to inspect**: Broad — likely needs live-server exploration (does the NPC exist? does the item exist? does the map location exist?) in addition to static code search, since many classic quests are wired via generic scripts (`quest_system1.lua`/`quest_system2.lua`, `quest_door.lua`, `chest.lua` reward table) rather than dedicated quest folders.

**Files expected to modify**: None directly — output is updated documentation ([[02_QUEST_ISSUE_618_AUDIT]], [[05_QUEST_IMPLEMENTATION_STATUS]]) plus a proposed Package 11+ roadmap addendum.

**Dependencies**: None — can run in parallel with Packages 1-9 if agent capacity allows, though sequencing it last avoids splitting attention during the higher-priority fix work.

**Risk**: None (docs-only), but time-boxing risk — 150 quests is a lot to research; recommend batching by era/category (Newbie Islands first, since smallest and highest new-player value) rather than attempting all at once.

**Test plan**: N/A (research package) — success criterion is an updated, actionable backlog, not a tested quest.

**Rollback plan**: N/A (docs-only).

**Autonomous implementation allowed**: Yes (it's research, not implementation) — but the *output* (a proposed Package 11+ roadmap) should go back to the owner for prioritization before any of that follow-on work begins, same as this initial package did.

---

## Summary table

| # | Package | Category | Risk | Autonomous impl. |
|---|---|---|---|---|
| 1 | #599 priority bug fixes | Fix | Medium | Zizzle: yes / Inquisition, Heart of Destruction: after live repro |
| 2 | Quick comment-sourced fixes | Fix | Low | Yes |
| 3 | Chest/reward quest fixes | Chest | Low-medium | Yes |
| 4 | Exchange quest research & implementation | Exchange | Low | Yes (post-research) |
| 5 | NPC dialogue quest fixes | NPC | Low-medium | Yes |
| 6 | Newbie Islands quest pack | Mixed (mostly simple) | Low-medium | Yes, in sub-batches |
| 7 | Addon/outfit quest pack (round 1) | Addon | Low | Yes |
| 8 | Multi-mission questline fixes | Multi | Medium-high | Incremental, owner check-ins for Ferumbras' Ascension |
| 9 | Heart of Destruction architecture fix | Boss/Puzzle | High (if `BossLever` migration included) | Registry cleanup: yes / `BossLever` migration: no |
| 10 | #618 "Unknown" bucket triage | Research | None | Yes |

## Recommended first implementation package

**Package 1**, starting with the Zizzle fallback-branch fix (lowest risk, clearest diagnosis, no live-repro dependency), then Bugs 1 and 3 once server access enables reproduction. This directly matches the project owner's explicit priority order and produces the fastest visible win.
