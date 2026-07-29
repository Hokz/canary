# 08 — Heart of Destruction Implementation Breakdown

Future PR scoping, building on [[09_FIRST_QUEST_PACKAGES_ROADMAP]] Package 9 and this package's (HOD-02) findings. Each item below is an independent, separately-approvable package — none should be started without explicit owner scoping approval, per [[06_QUEST_IMPLEMENTATION_PROTOCOL]].

## HOD-01 — World Devourer cooldown duration (DONE)

Merged via PR #4. 13 days 20 hours, confirmed present on `main` and inherited by this branch. No further action.

## HOD-02 — Quest Bible + Contracts (DONE)

Documentation and evidence-gathering only; no safe fixes met the strict bar that pass (see [[09_HOD_SAFE_FIXES_APPLIED]]).

## HOD-03 — This package (Reference Sync + Safe Fixes) (DONE)

Incorporated a much more detailed owner reference; corrected two HOD-02 misdiagnoses (reward chest was already complete; `actions_devourer_access.lua`/Devourer Core was already correct); fixed Yana's incomplete/placeholder "worth" dialogue using exact owner-authorized text. See [[09_HOD_SAFE_FIXES_APPLIED]] for the full accounting. **HOD-07 (below) is now resolved as a byproduct of this package's correction — no longer a blocked future item.**

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

## HOD-07 — `actions_devourer_access.lua` cooldown-bypass review (RESOLVED, no longer needed)

**Original scope**: fix or confirm-as-intended the possibly-inverted logic in this file.
**Resolution (HOD-03)**: item 23686 is named "devourer core" in `items.xml`, and the owner's reference explicitly documents this exact reset-cooldown mechanic. No bug exists; no fix needed. Live testing (§6 of [[07_HOD_QA_GAMEPLAY_CHECKLIST]]) is still worthwhile to confirm in-game behavior matches, but this is no longer a blocked/uncertain item.

## HOD-10 — "5 destructive charges" World Devourer entry gate (new, HOD-03)

**Scope**: implement the charge-accumulation system described in the owner's reference — players gain charges by killing "higher minions of destruction," spend 5 to enter World Devourer, with exact questlog text already available ([[02_HOD_QUESTLOG_CONTRACT]]).
**Blocked on**: design decisions not fully specified by the reference — which monsters count as "higher minions of destruction" (Disruption/Frenzy/Greed? the mini-bosses themselves? something else), whether charges are per-player or per-party, whether they persist across sessions.
**Risk**: Medium-high — new storage/KV namespace, new kill-tracking creaturescript hooks across potentially many monster files, changes to the World Devourer entry check in `movements_teleport_heart.lua`.
**Dependency**: should be scoped together with HOD-04 (questlog) since the exact re-entry message text is already available and describes this exact mechanic.

## HOD-08 — Undeclared-global hardening (largest code-quality item)

**Scope**: convert the ~20 undeclared Lua globals across `actions_charges_lever.lua`, `actions_cracklers_lever.lua`, `actions_sparks_lever.lua`, `movements_vortex_crackler.lua`, `movements_vortex_hunger.lua`, and `actions_final_lever.lua` to properly scoped state ([[03_HOD_STORAGE_CONTRACT]] §4).
**Blocked on**: nothing reference-wise (this is a pure code-quality/reliability issue, not a reference-parity gap), but requires very careful, incremental, heavily-tested work given the cross-file coordination involved.
**Risk**: High — this is explicitly the kind of "large mechanical rewrite" excluded from HOD-02's safe-fix scope. Recommend tackling one puzzle-room's worth of globals at a time (e.g., just the Cracklers/Rupture path first) rather than all four rooms in one PR, with live testing after each.

## HOD-09 — Storage registry hygiene

**Scope**: formally register the 14320-14354 range in `storages.lua` (documentation/registry only — not changing any values, per [[04_QUEST_STORAGE_REGISTRY]] Rule 4), and resolve the dual-use action-id/storage-key number collisions identified in [[03_HOD_STORAGE_CONTRACT]] §3 if any prove to be an actual (not just theoretical) risk.
**Risk**: Low if scoped as pure registration (adding comments/table entries, not changing behavior); Medium if it extends to actually renumbering colliding values (would need to touch every file that references the renumbered key).

## Suggested sequencing (updated HOD-03)

1. **HOD-03 done.** Messenger of Heaven dialogue (formerly "HOD-03" in HOD-02's numbering, now folded into the still-open item below) remains the top priority once the owner supplies Messenger of Heaven's actual spoken lines — the exact keyword chain is already known, only the NPC's side is missing.
2. **HOD-04 (questlog)** can start once enough mission text is supplied — one exact piece (World Devourer re-entry text) is already banked.
3. **HOD-07 resolved** — no longer blocking anything.
4. **HOD-06 (credit attribution)** after its live test confirms practical impact.
5. **HOD-09** (registry-only variant) is safe to do any time, low priority.
6. **HOD-05** (outer vortex system) and **HOD-10** (5-charges gate) are the largest, riskiest items, and HOD-10 has a natural dependency on HOD-04's questlog work since the exact re-entry text describes the charges mechanic. Recommend deferring both until the owner confirms these systems are actually wanted at all, given how much of the quest already works without them.
7. **HOD-08** (undeclared-global hardening) — lowest urgency, do incrementally whenever capacity allows, independent of the above.
