# 09 — Heart of Destruction Safe Fixes Applied

## HOD-05 update: one code fix applied (storage hygiene)

**Files changed**: `data-otservbr-global/lib/core/storages.lua`, `actions_final_lever.lua`, `actions_reward.lua`, `creaturescripts_devourer_player_death.lua`, `movements_teleport_heart.lua`.

**What was done**: registered 4 raw storage numbers (`14334`, `14335`, `14336`, `14337` — the final battle's per-player Hunger/Destruction/Rage team-tracking flags and the reward-claimed flag) as named constants under a new `Storage.HeartOfDestructionFinalBattle` table in `storages.lua`, and updated every consuming file to reference the named constants instead of bare numbers.

**Why this passed the safe-fix bar**:
1. Clearly proven by current code — these 4 exact numbers and their exact usages were read in full across all 4 files.
2. Expected behavior (they should be named/registered) is directly supported by the already-merged [[03_HOD_STORAGE_CONTRACT]] and [[04_QUEST_STORAGE_REGISTRY]], which both call unregistered magic numbers a known risk.
3. Fully local to HOD — no other quest touches these numbers.
4. No map, src, or NPC dialogue involved.
5. Values are **unchanged** — verified via `grep` that no bare `14334`-`14337` reference remains in executable code, and the registered values exactly match the pre-existing usage. This is testable by simply playing through the final battle and confirming identical behavior.

**Why only these 4 and not the rest of the 14320-14354 range**: every other number in that range was checked and found to have a **dual-use collision** — the same number serves as both a lever action id and a storage key in different files (e.g., `14320` is `actions_charges_lever.lua:aid(14320)` *and* the Anomaly-access storage granted by `creaturescripts_overcharge_death.lua`). Registering those under a single clean name would misrepresent what the number means depending on context, and properly resolving the collision (renumbering one of the two uses) is a migration — explicitly excluded from this package's "no broad migration" rule. Only `14334`-`14337`, verified collision-free, were touched.

**Risk**: Low. Purely a naming/registry change with a mechanical, verifiable "no value changed" guarantee.

## HOD-05 update: re-confirmed findings, no new code changes needed

- **Devourer Core** (`actions_devourer_access.lua`) — re-verified unchanged since HOD-03 (confirmed via `git log`, no PR has touched this file since). Still correctly implements the reference's cooldown-reset mechanic. No fix needed.
- **World Devourer access checks** (`movements_teleport_heart.lua`) — re-verified against the HOD-05 investigation checklist point by point: enforces cooldown ✅, checks Eradicator+Outburst ✅, does not check charges ✅ (correct, since charges don't exist), Devourer Core bypass supported ✅ (via the separate action). No fix needed.
- **Messenger of Heaven "yes" response** — re-checked per HOD-05's explicit instruction to only implement if current code clearly proves an expected storage/action. No such evidence found (same conclusion as HOD-04, now re-verified rather than assumed). Left as a silent topic-reset.

## HOD-05 update: confirmed still deferred, with sharper reasoning

- **Questlog/catalog entry** — confirmed the catalog system's dynamic-text mechanism (`description = function(player) ... end`, already used in `034_wrath_of_the_emperor.lua`) would support the exact "X of 5 charges" text once the underlying charges storage exists — but that storage doesn't exist, so wiring the text now would silently always show 0. Deferred until the charges system (HOD-10) is built, or until enough of the other ~7 mission states' text is supplied to create a catalog entry without the charges text.
- **Destructive charges system** — exhaustive re-search (not just a repeat of the HOD-03 grep) confirms zero trace of any partial implementation. Blocked on an undetermined monster classification ("higher minion of destruction" has no defined meaning in this codebase) — a design decision, not a code gap.
- **Final battle timing** — upgraded from "discrepancy, unresolved" to a precisely-traced finding: the code implements two **sequential** 30-minute windows (mini-boss phase, then a fresh World Devourer phase), confirmed via the exact `stopEvent`/`addEvent` sequence in `changeArea()`. Not fixed because the reference's single 45-minute figure doesn't specify how it should split across the two phases — changing either timer would mean guessing an unstated design decision.
- **Boss credit attribution** — re-confirmed unchanged: `creaturescripts_heart_boss_death.lua` still grants unlock credit by room-presence-at-death, and no participation/damage-tracking mechanism exists anywhere in this quest to build a safer check on top of. Still requires new tracking architecture (HOD-06).

---

## HOD-04 update: one code fix applied (largest so far)

**File changed**: `data-otservbr-global/npc/messenger_of_heaven.lua`

**What was wrong**: the file had zero dialogue logic at all — no `creatureSayCallback`, no keyword handling, no greeting message. The NPC was completely inert.

**What was implemented**: the full 13-keyword conversation tree (`hi → alive → peril → thing → past → name → ferumbras → damage → stopped → destroying → destroying (again) → heart of destruction → strong`), plus the `hi → strong → yes` shortcut, using the owner's exact provided dialogue transcribed verbatim (including preserving the reference's own inconsistent use of trailing "..." markers line-by-line, rather than normalizing them — a deliberate choice to avoid even stylistic paraphrasing).

**Why this passed the safe-fix bar**:
1. Every response line has owner-authorized exact text — no invention.
2. The topic-gated `elseif` chain follows the exact same proven pattern already used successfully in `henricus.lua`, `zizzle.lua`, and `wyrdin.lua` — not a new pattern.
3. Investigated and confirmed (see [[04_HOD_PORTAL_ACCESS_CONTRACT]]) that no existing portal/access code expects any storage from this NPC — so no storage write was added, avoiding an unproven mechanic change.
4. The one gap — no exact text for "yes" — was handled by *not* inventing a line: `yes` is recognized and closes the conversation silently (topic reset to 0) rather than falling through as an error or getting a made-up response.
5. Fully testable with clear player steps (say each keyword in order, or use the shortcut, and compare against the exact expected line).

**What was NOT touched**: `lesser_messenger_of_heaven.lua` (no evidence it's part of this flow); any storage/catalog file; Yana (referenced only for pattern-consistency, not modified).

**Risk**: Low. Purely additive on a previously-inert NPC — nothing could regress. See [[01_HOD_NPC_DIALOGUE_CONTRACT]] for the full before/after and [[07_HOD_QA_GAMEPLAY_CHECKLIST]] for verification steps.

---

## HOD-03 update: one code fix applied

**File changed**: `data-otservbr-global/npc/yana.lua`

**What was wrong**: the "worth" dialogue branch contained a literal developer TODO (`-- to do: check if Heart of Destruction was killed`) and never actually checked whether the player had completed the quest — every player got the same generic instructional text regardless of progress. That text also enumerated only 3 of the reference's 8 "Powerful" imbuements, and contained a stray Lua comment marker (`--'Powerful Vampirism'`) that would have rendered literally in the player-visible string. No greeting message was configured at all.

**Why this passed the safe-fix bar** (package rule #10 — *"implement or correct Yana dialogue only if existing Yana/imbuement logic clearly supports it and the exact dialogue above is enough"*):
1. The "worth" keyword branch already existed — this is a correction, not new dialogue invention.
2. The exact success-case text was provided verbatim by the owner.
3. The completion check uses `player:hasAchievement("Ender of the End")` — an already-proven pattern used identically elsewhere in this codebase (`iskan.lua:60`), not a new mechanism.
4. Confirmed via `data/XML/imbuements.xml` that "Powerful" is a plain price/duration tier with no per-player access flag anywhere in the engine — so no new "grant access" mechanic needed to be invented; the fix is purely dialogue + a proven read-only check.
5. Fully testable with clear player steps (talk to Yana, say "worth," before and after defeating World Devourer).

**What was NOT touched**: the "trade"/"tokens" gold-token shop flow (unrelated, pre-existing, working feature); no new storage was created; no imbuement-granting mechanism was invented.

**Risk**: Low. See [[01_HOD_NPC_DIALOGUE_CONTRACT]] for the full before/after text and [[07_HOD_QA_GAMEPLAY_CHECKLIST]] §6b for the verification steps.

## HOD-03 update: two HOD-02 findings corrected (no code change needed)

- **Reward chest** (`actions_reward.lua`): all 7 item names verified against `items.xml` — exact match to the owner's reference. No fix needed; HOD-02's "unverified identity" note is resolved. See [[06_HOD_REWARD_CONTRACT]].
- **`actions_devourer_access.lua`**: item 23686 confirmed named "devourer core," matching the reference's documented reset-cooldown mechanic exactly. HOD-02's "possibly inverted logic" flag is retracted — no fix needed. See [[05_HOD_BOSS_MECHANICS_CONTRACT]].

## Confirmed still missing, not attempted (would exceed safe-fix scope)

- **Messenger of Heaven "yes" response text** (HOD-04) — the shortcut chain's final keyword is recognized but produces no spoken line, since no exact text was provided for it.
- **Messenger of Heaven's possible future outer-access storage grant** (HOD-04) — investigated and confirmed no existing code expects one today; deferred until the outer vortex/cave system (if ever built) needs it.
- `lesser_messenger_of_heaven.lua` (HOD-04) — no evidence connects it to this dialogue flow; left untouched.
- The "5 destructive charges" World Devourer entry gate — a genuinely new mechanic (kill-tracked counter across monster types, spend-on-entry check), not a fix to existing code.
- Questlog catalog entry — one exact mission-state text is now banked, but a valid catalog module needs the other ~7 states' text too.
- The 45-minute vs. 30-minute×N final-battle timing discrepancy — needs live-testing to even confirm as a real issue before any change is considered.

---

## HOD-02 baseline: no new code fixes applied in that package

This package's primary deliverable is documentation (the Quest Bible + 7 contracts). Every finding surfaced during the audit was checked against the package's 7-condition safe-fix test:

1. The issue is clearly proven by current code.
2. The expected behavior is clearly supported by repository evidence or the provided reference summary.
3. The fix is local to Heart of Destruction.
4. The fix does not require rewriting boss mechanics.
5. The fix does not require unknown exact NPC dialogue.
6. The fix does not change database schema, map, src, or unrelated quests.
7. The fix can be tested with clear player steps.

None of the findings from this audit pass all seven conditions simultaneously:

| Finding | Fails condition(s) | Why |
|---|---|---|
| Messenger of Heaven has no dialogue | #5 | Requires exact dialogue/keyword text not present in the repo or provided by the owner — writing it would be inventing dialogue, explicitly disallowed |
| Missing questlog catalog entry | #2, #5 | Requires exact mission names/state text not present anywhere |
| Missing outer vortex/10-kill access system | #1 (partially), #4, #6 | Not a "fix" at all — it's new-feature implementation (new globalevent, new map entry points), explicitly excluded as "new boss room system" / "map/teleport placement requiring coordinates not proven" |
| Room-presence-at-death credit attribution | #1, #7 | Not proven to be a practical problem without live testing; fixing it touches shared boss-death logic for 3 bosses at once, which risks being a "boss mechanic rewrite" |
| `actions_devourer_access.lua` possibly-inverted cooldown logic | #1, #4 | Current behavior not confirmed live — could be intentional; fixing blind risks changing boss-mechanic behavior without proof |
| Undeclared Lua globals (~20 across 6 files) | #3 (scale), #4, #6 | Explicitly called out in the package rules as excluded ("large mechanical rewrites," "large storage migration"); cross-file coordination risk is high |
| Unregistered storage range (14320-14354) | #7 (partially) | Pure registry documentation would be safe, but doing it properly surfaces the dual-use action-id/storage-key collisions, which raised more questions than this package could resolve without risking scope creep into "storage migration" |

## What was NOT reapplied

Per your instruction, the World Devourer cooldown fix (13 days 20 hours) from PR #4 was **not reapplied** — verified present on this branch via `git log` (commit `4114e4e77` / merge `baba6c0d7` are both ancestors of the current branch tip, since this branch was created from `main` after that merge).

## What this package DID produce

- 9 documentation files (the Quest Bible + 7 contracts + this file) under `docs/ai-dev/quests/packages/heart-of-destruction/`.
- A fully evidence-backed correction to an earlier (same-session) misreading of the cooldown mechanism — avoided writing "4 of 5 bosses have no cooldown" into permanent documentation by verifying against `boss_lever.lua` before publishing, which would have been a false claim.
- A clear `OWNER_REFERENCE_REQUIRED` list (dialogue text, keywords, questlog mission text) blocking HOD-03 and HOD-04.
- A live-testing checklist ([[07_HOD_QA_GAMEPLAY_CHECKLIST]]) targeting exactly the findings that need player-side confirmation before any further code change.
- A sequenced implementation breakdown ([[08_HOD_IMPLEMENTATION_BREAKDOWN]]) for every future HOD package, each scoped independently so none of them need to wait on each other except where a genuine dependency exists (HOD-03/04 on owner text; HOD-06/07 on live testing).

## Recommendation for the next HOD package

Per [[08_HOD_IMPLEMENTATION_BREAKDOWN]], the lowest-friction next step is **HOD-07** (the `actions_devourer_access.lua` review) — it only needs one live-test result (§6 of [[07_HOD_QA_GAMEPLAY_CHECKLIST]]) before a fix can be safely scoped and is likely a small, low-risk conditional change once confirmed, matching the pattern of every successfully-shipped fix so far in this project (Zizzle, Wyrdin, World Devourer cooldown).
