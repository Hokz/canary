# 08 — Heart of Destruction Implementation Breakdown

Future PR scoping, building on [[09_FIRST_QUEST_PACKAGES_ROADMAP]] Package 9 and this package's (HOD-02) findings. Each item below is an independent, separately-approvable package — none should be started without explicit owner scoping approval, per [[06_QUEST_IMPLEMENTATION_PROTOCOL]].

## HOD-01 — World Devourer cooldown duration (DONE)

Merged via PR #4. 13 days 20 hours, confirmed present on `main` and inherited by this branch. No further action.

## HOD-02 — Quest Bible + Contracts (DONE)

Documentation and evidence-gathering only; no safe fixes met the strict bar that pass (see [[09_HOD_SAFE_FIXES_APPLIED]]).

## HOD-03 — This package (Reference Sync + Safe Fixes) (DONE)

Incorporated a much more detailed owner reference; corrected two HOD-02 misdiagnoses (reward chest was already complete; `actions_devourer_access.lua`/Devourer Core was already correct); fixed Yana's incomplete/placeholder "worth" dialogue using exact owner-authorized text. See [[09_HOD_SAFE_FIXES_APPLIED]] for the full accounting. **HOD-07 (below) is now resolved as a byproduct of this package's correction — no longer a blocked future item.**

## HOD-04 — This package (Messenger of Heaven Quest Start) (DONE)

**Note on numbering**: HOD-02 originally planned this as "HOD-03," but HOD-03 was repurposed for the broader reference-sync package before this work started — this item was renumbered to HOD-04 to match the package that actually delivered it, and the questlog item below (originally "HOD-04") was renumbered to HOD-11 to avoid a collision. No content was lost, only headings renumbered.

**Scope delivered**: full 13-keyword dialogue tree for `messenger_of_heaven.lua`, implemented verbatim from the owner's exact reference text, following the established `KeywordHandler`/`NpcHandler` topic-chain pattern. Both the full narrative chain and the `hi → strong → yes` shortcut are supported. See [[01_HOD_NPC_DIALOGUE_CONTRACT]] for the full keyword table and [[09_HOD_SAFE_FIXES_APPLIED]] for the safe-fix justification.
**Not delivered**: exact text for the "yes" response (not provided by the owner — implemented as a silent topic-reset instead of inventing a line); any storage/access grant (investigated and confirmed unnecessary — see [[04_HOD_PORTAL_ACCESS_CONTRACT]]); `lesser_messenger_of_heaven.lua` (no evidence found connecting it to this flow, left untouched).

## HOD-FULL — Full autonomous implementation pass (DONE, this package)

Owner explicitly authorized moving past the conservative "defer if not proven" posture: implement functional systems now, mark exact text TODO instead of blocking. Delivered: the outer vortex system (HOD-12, below — code complete, map placement pending), the destructive charges system (HOD-10, below — done), the questlog catalog (HOD-11, below — done, functional text), the final-battle 45-minute timing fix, and Messenger of Heaven's "yes" wiring. Deliberately NOT attempted: HOD-06 (credit attribution) and HOD-08 (undeclared-global hardening) — both still judged too large/risky to rush inside an already-large package without live testing between incremental steps. See [[09_HOD_SAFE_FIXES_APPLIED]] for full per-system reasoning.

## HOD-11 — Questlog catalog entry (DONE — HOD-FULL, functional text, TODO exact wording)

**Scope**: create `data-otservbr-global/lib/core/quests/catalog/0XX_heart_of_destruction.lua`, populating the currently-empty `Storage.Quest.U10_94.HeartOfDestruction` table with real mission storages, and wiring the catalog module per the standard shape ([[02_HOD_QUESTLOG_CONTRACT]]).
**Delivered (HOD-FULL)**: `052_heart_of_destruction.lua`, 7 missions, functional (not verbatim) text, `TODO_EXACT_TEXT` notice at the top of the file. `missionId`s 20001-20007, a clean unused block. No collision with the existing 14320-14354 legacy family — mission `storageId`s reference those existing flags read-only for display purposes, no new writes.

## HOD-05 — This package (Completion Pass) (DONE)

**Note on numbering**: HOD-02 originally planned "HOD-05" as the outer vortex access system — that item is renumbered to HOD-12 below to avoid colliding with this package (same situation as the HOD-03/HOD-04 renumbering in the prior package). No content lost.

**Scope delivered**: investigated all 7 remaining priority areas from the owner's task. Applied one narrow, proven storage-hygiene fix (registered 4 collision-free storage numbers as named constants — see [[09_HOD_SAFE_FIXES_APPLIED]]). Re-confirmed Devourer Core and World Devourer access checks are already correct with fresh, targeted evidence. Sharpened the final-battle timing finding from "discrepancy, unresolved" to a precisely-traced sequential-timer mechanism. Re-confirmed (not just re-asserted) that destructive charges, questlog catalog, and credit attribution remain correctly deferred, each for a specific, documented reason.

## HOD-07 — `actions_devourer_access.lua` cooldown-bypass review (RESOLVED, unchanged)

Item 23686 is named "devourer core" in `items.xml`; the owner's reference confirms this is the intended reset-cooldown mechanic. No bug, no fix needed, re-verified unchanged through HOD-FULL.

## HOD-10 — "5 destructive charges" World Devourer entry gate (DONE — HOD-FULL)

**Scope**: implement the charge-accumulation system described in the owner's reference — players gain charges by killing "higher minions of destruction," spend 5 to enter World Devourer, with exact questlog text already available ([[02_HOD_QUESTLOG_CONTRACT]]).
**Delivered (HOD-FULL)**: the previously-blocking monster classification was resolved by inference (Frenzy, Charged Disruption, Overcharged Disruption — documented in-code and in [[05_HOD_BOSS_MECHANICS_CONTRACT]]), charges are per-player (matching every other HOD storage's scope), and persist via standard storage (no session-reset logic added, matching how every other HOD progress flag behaves). Gated to repeat visits only (`hasAchievement("Ender of the End")`), leaving first-time entry unaffected.

## HOD-08 — Undeclared-global hardening (largest code-quality item)

**Scope**: convert the ~20 undeclared Lua globals across `actions_charges_lever.lua`, `actions_cracklers_lever.lua`, `actions_sparks_lever.lua`, `movements_vortex_crackler.lua`, `movements_vortex_hunger.lua`, and `actions_final_lever.lua` to properly scoped state ([[03_HOD_STORAGE_CONTRACT]] §4).
**Blocked on**: nothing reference-wise (this is a pure code-quality/reliability issue, not a reference-parity gap), but requires very careful, incremental, heavily-tested work given the cross-file coordination involved.
**Risk**: High — this is explicitly the kind of "large mechanical rewrite" excluded from HOD-02's safe-fix scope. Recommend tackling one puzzle-room's worth of globals at a time (e.g., just the Cracklers/Rupture path first) rather than all four rooms in one PR, with live testing after each.

## HOD-09 — Storage registry hygiene (PARTIALLY DONE — HOD-05)

**Scope**: formally register the 14320-14354 range in `storages.lua` (documentation/registry only — not changing any values, per [[04_QUEST_STORAGE_REGISTRY]] Rule 4), and resolve the dual-use action-id/storage-key number collisions identified in [[03_HOD_STORAGE_CONTRACT]] §3 if any prove to be an actual (not just theoretical) risk.
**Risk**: Low if scoped as pure registration (adding comments/table entries, not changing behavior); Medium if it extends to actually renumbering colliding values (would need to touch every file that references the renumbered key).
**HOD-05 delivered the low-risk slice**: the 4 numbers in this range with zero action-id collisions (`14334`-`14337`) are now registered as `Storage.HeartOfDestructionFinalBattle.*`, with all consuming files updated to use the named constants. Values unchanged. **Remaining scope** (the rest of the range, ~16 numbers, all with dual-use collisions) is still deferred — resolving those requires deciding which of the two colliding uses to renumber, which is the "broad migration" this package's rules exclude.

## HOD-12 — Outer vortex access system (CODE DONE — HOD-FULL; map placement still required)

**Scope**: implement the rotating 3-city vortex + 10-kill permanent access layer described in the owner's reference ([[04_HOD_PORTAL_ACCESS_CONTRACT]] §1, §3).
**Delivered (HOD-FULL)**: `globalevents_vortex_rotation.lua`, `movements_vortex_route_entrances.lua`, `creaturescripts_vortex_route_kills.lua`, plus `monster.events` registration on the 3 `extra_dimensional` monster files. **Owner decision was resolved implicitly** by this package's explicit instruction to implement everything possible without blocking — the code now exists either way, and remains inert (safe, no-op) until placed.
**Remaining**: 3 action ids need physical map placement (exact instructions in [[04_HOD_PORTAL_ACCESS_CONTRACT]]), and the 3 kill-tracked monsters need spawns added (currently unplaced anywhere).

## Remaining deferred items (unchanged by HOD-FULL, by deliberate choice)

### HOD-06 — Boss-defeat credit attribution hardening
**Scope**: change `creaturescripts_heart_boss_death.lua`'s `setStorage()` from room-presence-at-death to tracked participation.
**Why still deferred even under HOD-FULL's broad authorization**: this touches shared death-handling logic for all three first-tier bosses simultaneously, with no existing participation-tracking pattern anywhere in the quest to build on — a careless implementation risks breaking three already-working boss fights at once, and HOD-FULL's other systems already carry meaningful live-testing risk on their own. Recommend as a focused follow-up package with dedicated live-testing time between each boss's change, not bundled into an already-large diff.

### HOD-08 — Undeclared-global hardening
**Scope**: convert ~20 undeclared Lua globals across 6 files to properly scoped state.
**Why still deferred**: explicitly flagged in every prior package as needing incremental, individually-tested work across 6 interacting files — the risk profile doesn't change just because other systems were authorized for full implementation. Recommend one puzzle-room at a time, each with live testing before the next.

## Suggested sequencing (updated HOD-FULL)

1. **HOD-01 through HOD-05, HOD-10, HOD-11, HOD-12 (code) all done.**
2. **Map setup is now the critical path** — nothing further can be tested end-to-end until the 3 vortex action ids and 3 monster spawns are placed (see [[04_HOD_PORTAL_ACCESS_CONTRACT]]).
3. **Live testing** of every HOD-FULL system, per the expanded [[07_HOD_QA_GAMEPLAY_CHECKLIST]] — especially the inferred decisions (charges classification, 45-minute split) that may need adjustment based on real play.
4. **HOD-06 and HOD-08** remain the two intentionally-deferred items — recommend as focused, individually-tested follow-up packages once the map setup and live testing above are complete.
