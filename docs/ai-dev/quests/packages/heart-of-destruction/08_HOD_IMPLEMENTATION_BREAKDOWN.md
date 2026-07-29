# 08 — Heart of Destruction Implementation Breakdown

Future PR scoping, building on [[09_FIRST_QUEST_PACKAGES_ROADMAP]] Package 9 and this package's (HOD-02) findings. Each item below is an independent, separately-approvable package — none should be started without explicit owner scoping approval, per [[06_QUEST_IMPLEMENTATION_PROTOCOL]].

## HOD-01 — World Devourer cooldown duration (DONE)

Merged via PR #4. 13 days 20 hours, confirmed present on `main` and inherited by this branch. No further action.

## HOD-02 — This package (Quest Bible + Contracts)

Documentation and evidence-gathering only, plus any safe fixes found (see [[09_HOD_SAFE_FIXES_APPLIED]] for the outcome — none were found to meet the strict safe-fix bar this pass).

## HOD-03 — Messenger of Heaven dialogue (blocked on owner reference)

**Scope**: implement the missing quest-start dialogue for `messenger_of_heaven.lua` (and determine `lesser_messenger_of_heaven.lua`'s actual role).
**Blocked on**: exact dialogue text and required keywords ([[01_HOD_NPC_DIALOGUE_CONTRACT]]).
**Files**: `data-otservbr-global/npc/messenger_of_heaven.lua`, possibly `lesser_messenger_of_heaven.lua`.
**Risk once unblocked**: Low — purely additive, same shape as the successful Zizzle/Wyrdin dialogue fixes.
**Cannot start until**: owner pastes reference dialogue/keywords, per the explicit "do not invent" rule.

## HOD-04 — Questlog catalog entry (blocked on owner reference)

**Scope**: create `data-otservbr-global/lib/core/quests/catalog/0XX_heart_of_destruction.lua`, populating the currently-empty `Storage.Quest.U10_94.HeartOfDestruction` table with real mission storages, and wiring the catalog module per the standard shape ([[02_HOD_QUESTLOG_CONTRACT]]).
**Blocked on**: exact quest/mission names and state text.
**Risk once unblocked**: Low-medium — additive, but needs care mapping existing mechanical storages (14320-14354 family) to the new catalog's mission storages without breaking the existing gameplay logic that already reads/writes those raw numbers.
**Cannot start until**: owner pastes reference mission text.

## HOD-05 — Outer vortex access system (largest, most uncertain)

**Scope**: implement (or explicitly decide not to implement) the rotating 3-city vortex + 10-kill permanent access layer described in the owner's reference ([[04_HOD_PORTAL_ACCESS_CONTRACT]] §1, §3).
**Blocked on**: an owner decision, not just reference text — is this genuinely supposed to exist on this server, or was the current fixed-entrance design an intentional simplification? This determination should come before any implementation work, since it changes the shape of the whole package (new globalevent, three map entry points, new per-player kill-tracked storage vs. "no work needed, current design is correct").
**Risk once scoped**: High — new globalevent, new world-map interaction points, new storage namespace, largest single change in the whole quest.
**Explicitly excluded from HOD-02's safe-fix scope** ("new boss room system," "map/teleport placement requiring coordinates not proven").

## HOD-06 — Boss-defeat credit attribution hardening

**Scope**: change `creaturescripts_heart_boss_death.lua`'s `setStorage()` from room-presence-at-death to tracked participation, for Anomaly/Rupture/Realityquake's Eradicator/Outburst-unlock flags ([[04_HOD_PORTAL_ACCESS_CONTRACT]] §5).
**Blocked on**: live-testing confirmation this is a practical problem worth fixing (§5 of [[07_HOD_QA_GAMEPLAY_CHECKLIST]]), and a design decision on what "participation" should mean (damage dealt? presence for X% of the fight? something else?).
**Risk**: Medium — touches shared death-handling logic used by all three first-tier bosses at once; a careless change could break all three simultaneously.

## HOD-07 — `actions_devourer_access.lua` cooldown-bypass review

**Scope**: fix or confirm-as-intended the possibly-inverted logic in this file ([[05_HOD_BOSS_MECHANICS_CONTRACT]]).
**Blocked on**: live-testing confirmation of current behavior (§6 of [[07_HOD_QA_GAMEPLAY_CHECKLIST]]).
**Risk once confirmed broken**: Low — likely a small conditional fix, similar scale to the Zizzle/Wyrdin/World-Devourer-cooldown fixes.
**Cannot start until**: the live test confirms what the item currently does and whether that's wrong.

## HOD-08 — Undeclared-global hardening (largest code-quality item)

**Scope**: convert the ~20 undeclared Lua globals across `actions_charges_lever.lua`, `actions_cracklers_lever.lua`, `actions_sparks_lever.lua`, `movements_vortex_crackler.lua`, `movements_vortex_hunger.lua`, and `actions_final_lever.lua` to properly scoped state ([[03_HOD_STORAGE_CONTRACT]] §4).
**Blocked on**: nothing reference-wise (this is a pure code-quality/reliability issue, not a reference-parity gap), but requires very careful, incremental, heavily-tested work given the cross-file coordination involved.
**Risk**: High — this is explicitly the kind of "large mechanical rewrite" excluded from HOD-02's safe-fix scope. Recommend tackling one puzzle-room's worth of globals at a time (e.g., just the Cracklers/Rupture path first) rather than all four rooms in one PR, with live testing after each.

## HOD-09 — Storage registry hygiene

**Scope**: formally register the 14320-14354 range in `storages.lua` (documentation/registry only — not changing any values, per [[04_QUEST_STORAGE_REGISTRY]] Rule 4), and resolve the dual-use action-id/storage-key number collisions identified in [[03_HOD_STORAGE_CONTRACT]] §3 if any prove to be an actual (not just theoretical) risk.
**Risk**: Low if scoped as pure registration (adding comments/table entries, not changing behavior); Medium if it extends to actually renumbering colliding values (would need to touch every file that references the renumbered key).

## Suggested sequencing

1. **HOD-03 and HOD-04** can start in parallel, as soon as the owner supplies reference text — both are additive, low-risk, well-understood patterns.
2. **HOD-07** can start as soon as the live test in [[07_HOD_QA_GAMEPLAY_CHECKLIST]] §6 is done — independent of everything else.
3. **HOD-06** after its live test (§5) confirms practical impact.
4. **HOD-09** (registry-only variant) is safe to do any time, low priority.
5. **HOD-05** and **HOD-08** are the largest, riskiest items — recommend deferring until HOD-03/04/06/07 are done and the owner has had a chance to weigh in on whether HOD-05's outer-access system is even wanted.
