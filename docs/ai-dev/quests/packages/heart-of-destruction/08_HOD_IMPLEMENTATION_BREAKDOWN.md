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

## HOD-11 — Questlog catalog entry (blocked on owner reference, renumbered from HOD-04)

**Scope**: create `data-otservbr-global/lib/core/quests/catalog/0XX_heart_of_destruction.lua`, populating the currently-empty `Storage.Quest.U10_94.HeartOfDestruction` table with real mission storages, and wiring the catalog module per the standard shape ([[02_HOD_QUESTLOG_CONTRACT]]).
**Blocked on**: exact quest/mission names and state text (one piece — the World Devourer re-entry text — is already banked, per [[02_HOD_QUESTLOG_CONTRACT]]).
**Risk once unblocked**: Low-medium — additive, but needs care mapping existing mechanical storages (14320-14354 family) to the new catalog's mission storages without breaking the existing gameplay logic that already reads/writes those raw numbers.
**Cannot start until**: owner pastes the remaining reference mission text.

## HOD-05 — This package (Completion Pass) (DONE)

**Note on numbering**: HOD-02 originally planned "HOD-05" as the outer vortex access system — that item is renumbered to HOD-12 below to avoid colliding with this package (same situation as the HOD-03/HOD-04 renumbering in the prior package). No content lost.

**Scope delivered**: investigated all 7 remaining priority areas from the owner's task. Applied one narrow, proven storage-hygiene fix (registered 4 collision-free storage numbers as named constants — see [[09_HOD_SAFE_FIXES_APPLIED]]). Re-confirmed Devourer Core and World Devourer access checks are already correct with fresh, targeted evidence. Sharpened the final-battle timing finding from "discrepancy, unresolved" to a precisely-traced sequential-timer mechanism. Re-confirmed (not just re-asserted) that destructive charges, questlog catalog, and credit attribution remain correctly deferred, each for a specific, documented reason.

## HOD-06 — Boss-defeat credit attribution hardening

**Scope**: change `creaturescripts_heart_boss_death.lua`'s `setStorage()` from room-presence-at-death to tracked participation, for Anomaly/Rupture/Realityquake's Eradicator/Outburst-unlock flags ([[04_HOD_PORTAL_ACCESS_CONTRACT]] §5).
**Blocked on**: live-testing confirmation this is a practical problem worth fixing (§5 of [[07_HOD_QA_GAMEPLAY_CHECKLIST]]), and a design decision on what "participation" should mean (damage dealt? presence for X% of the fight? something else?).
**Risk**: Medium — touches shared death-handling logic used by all three first-tier bosses at once; a careless change could break all three simultaneously.
**HOD-05 status**: re-investigated, no change in conclusion — still blocked on the same live-test + design decision. No participation-tracking mechanism exists anywhere in this quest to build on.

## HOD-07 — `actions_devourer_access.lua` cooldown-bypass review (RESOLVED, no longer needed)

**Original scope**: fix or confirm-as-intended the possibly-inverted logic in this file.
**Resolution (HOD-03)**: item 23686 is named "devourer core" in `items.xml`, and the owner's reference explicitly documents this exact reset-cooldown mechanic. No bug exists; no fix needed. Live testing (§6 of [[07_HOD_QA_GAMEPLAY_CHECKLIST]]) is still worthwhile to confirm in-game behavior matches, but this is no longer a blocked/uncertain item.
**HOD-05 status**: re-verified unchanged since HOD-03 (file untouched by any PR in between). Resolution stands.

## HOD-10 — "5 destructive charges" World Devourer entry gate (new, HOD-03)

**Scope**: implement the charge-accumulation system described in the owner's reference — players gain charges by killing "higher minions of destruction," spend 5 to enter World Devourer, with exact questlog text already available ([[02_HOD_QUESTLOG_CONTRACT]]).
**Blocked on**: design decisions not fully specified by the reference — which monsters count as "higher minions of destruction" (Disruption/Frenzy/Greed? the mini-bosses themselves? something else), whether charges are per-player or per-party, whether they persist across sessions.
**Risk**: Medium-high — new storage/KV namespace, new kill-tracking creaturescript hooks across potentially many monster files, changes to the World Devourer entry check in `movements_teleport_heart.lua`.
**Dependency**: should be scoped together with HOD-11 (questlog) since the exact re-entry message text is already available and describes this exact mechanic.
**HOD-05 status**: re-investigated with an exhaustive search (not just a narrower grep) — confirmed zero partial implementation exists. Same blockers, same scope. This and HOD-11 remain the two largest, most valuable next steps once the owner can clarify the monster classification and supply the remaining mission text.

## HOD-08 — Undeclared-global hardening (largest code-quality item)

**Scope**: convert the ~20 undeclared Lua globals across `actions_charges_lever.lua`, `actions_cracklers_lever.lua`, `actions_sparks_lever.lua`, `movements_vortex_crackler.lua`, `movements_vortex_hunger.lua`, and `actions_final_lever.lua` to properly scoped state ([[03_HOD_STORAGE_CONTRACT]] §4).
**Blocked on**: nothing reference-wise (this is a pure code-quality/reliability issue, not a reference-parity gap), but requires very careful, incremental, heavily-tested work given the cross-file coordination involved.
**Risk**: High — this is explicitly the kind of "large mechanical rewrite" excluded from HOD-02's safe-fix scope. Recommend tackling one puzzle-room's worth of globals at a time (e.g., just the Cracklers/Rupture path first) rather than all four rooms in one PR, with live testing after each.

## HOD-09 — Storage registry hygiene (PARTIALLY DONE — HOD-05)

**Scope**: formally register the 14320-14354 range in `storages.lua` (documentation/registry only — not changing any values, per [[04_QUEST_STORAGE_REGISTRY]] Rule 4), and resolve the dual-use action-id/storage-key number collisions identified in [[03_HOD_STORAGE_CONTRACT]] §3 if any prove to be an actual (not just theoretical) risk.
**Risk**: Low if scoped as pure registration (adding comments/table entries, not changing behavior); Medium if it extends to actually renumbering colliding values (would need to touch every file that references the renumbered key).
**HOD-05 delivered the low-risk slice**: the 4 numbers in this range with zero action-id collisions (`14334`-`14337`) are now registered as `Storage.HeartOfDestructionFinalBattle.*`, with all consuming files updated to use the named constants. Values unchanged. **Remaining scope** (the rest of the range, ~16 numbers, all with dual-use collisions) is still deferred — resolving those requires deciding which of the two colliding uses to renumber, which is the "broad migration" this package's rules exclude.

## HOD-12 — Outer vortex access system (largest, most uncertain; renumbered from HOD-05)

**Scope**: implement (or explicitly decide not to implement) the rotating 3-city vortex + 10-kill permanent access layer described in the owner's reference ([[04_HOD_PORTAL_ACCESS_CONTRACT]] §1, §3).
**Blocked on**: an owner decision, not just reference text — is this genuinely supposed to exist on this server, or was the current fixed-entrance design an intentional simplification? This determination should come before any implementation work, since it changes the shape of the whole package (new globalevent, three map entry points, new per-player kill-tracked storage vs. "no work needed, current design is correct").
**Risk once scoped**: High — new globalevent, new world-map interaction points, new storage namespace, largest single change in the whole quest.
**Explicitly excluded from HOD-02's safe-fix scope** ("new boss room system," "map/teleport placement requiring coordinates not proven").

## Suggested sequencing (updated HOD-05)

1. **HOD-01 through HOD-05 done.** Messenger of Heaven's dialogue is implemented; World Devourer cooldown, Yana, and a narrow storage-hygiene slice are all shipped. Only the "yes" response text and a possible future outer-access storage remain open on Messenger of Heaven, both `OWNER_REFERENCE_REQUIRED`.
2. **HOD-09 registry-only slice done** — the collision-free 4-number subset is registered; the rest of the range remains deferred (see HOD-09 above).
3. **HOD-07 resolved** — no longer blocking anything, re-confirmed stable in HOD-05.
4. **HOD-11 (questlog, formerly HOD-04)** can start once enough mission text is supplied — one exact piece (World Devourer re-entry text) is already banked, and HOD-05 confirmed the catalog system's dynamic-text mechanism (`description = function(player) ... end`) already works elsewhere, so no new engine capability is needed once text arrives.
5. **HOD-06 (credit attribution)** after its live test confirms practical impact — re-confirmed still blocked in HOD-05, no change.
6. **HOD-12** (outer vortex system, formerly HOD-05) and **HOD-10** (5-charges gate) remain the largest, riskiest items, and HOD-10 has a natural dependency on HOD-11's questlog work since the exact re-entry text describes the charges mechanic. Recommend deferring both until the owner confirms these systems are actually wanted at all, given how much of the quest already works without them.
7. **HOD-08** (undeclared-global hardening) — lowest urgency, do incrementally whenever capacity allows, independent of the above.
