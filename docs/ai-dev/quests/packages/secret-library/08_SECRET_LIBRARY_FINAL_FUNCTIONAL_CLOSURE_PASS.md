# Secret Library — Final Functional Closure Pass

PR #37, branch `ai-dev/secret-library-full-repair-v2`. Executor-only pass. Scope: functional skeleton
closure only (story → NPC → mission state → questlog → required objective/item → boss/event →
completion credit → reward/progression → next mission → final epilogue → quest complete), per the
owner-clarified Definition of Done. P2/P3 (map/graphics/HUD/sprite/exact SQM/AID/UID/object identity/
generic combat-balance polish) explicitly out of scope for this pass and recorded as backlog only.

## 1. Verified start SHA / PR state

- Branch: `ai-dev/secret-library-full-repair-v2`, working tree clean at pass start.
- HEAD at pass start: `6527dea63a1fb135f1dca9431d6f97778b320e7b` — matches the expected starting head
  exactly (`git rev-parse HEAD`).
- PR #37: draft, open, not merged (unchanged by this pass; this executor never merges/marks ready).

## 2. P0 fixes — Cerebrir / true quest completion

**Reference evidence (PROVEN_REFERENCE):** live-fetched this pass (TibiaWiki main quest page, `curl`
with a browser User-Agent — the previously-established working method; WebFetch also succeeded this
pass). Confirmed:
- Exact post-kill message (3 lines, quoted verbatim in-game text), triggered by defeating the Scourge of
  Oblivion.
- Cerebrir is present in the central hall from the start (a genuine NPC, not merely a plot reference).
- A full, linear, keyword-advance dialogue transcript with Cerebrir, ending in the quest being marked
  complete.

**Implemented:**
- `creaturescripts_scourge_of_oblivion_phases.lua` (`scourgeDeath.onDeath`): for every current-run
  participant still physically present in the room at the legitimate kill (same eligibility scope
  already used for Library Liberator credit — no new eligibility surface introduced), emits the exact
  reference post-kill message, sets a persistent per-player `epiloguePending` flag via
  `player:kv():scoped("secret-library-cerebrir")` (DB-backed — survives logout/relog by construction,
  same convention as `actions_master_debater_documents.lua`'s `documentsKV`), and advances
  `Storage.Quest.U11_80.TheSecretLibrary.Library.Questline` to `1`. Library Liberator (achievement)
  remains completely independent — granting one never implies or blocks the other.
- `npc/cerebrir.lua` (previously a bare, non-functional NPC skeleton — `Game.createNpcType` boilerplate
  only, no keywords, no dialogue): implemented the full 8-step reference conversation
  (`Hi → lost → someone → unnoticed → suspects → candidates → seven → betrayal`) via the project's
  standard `NpcHandler`/`KeywordHandler` + per-player `npcHandler:setTopic(playerId, …)` convention
  (matching `gareth.lua`'s established pattern). Gated end-to-end on the player's own `epiloguePending`/
  `epilogueComplete` KV state — a non-participant gets only a neutral greeting and no keyword branch ever
  fires for them (topic never advances past 0). On reaching the final line, sets `epilogueComplete`,
  clears `epiloguePending`, and advances `Library.Questline` to `2` (final completion).

**Requirement-by-requirement:**
- Persistent epilogue-pending state: **done** (KV, DB-backed).
- Reference post-kill message: **done** (exact quoted text, emitted to eligible participants).
- Run cleanup still completes normally: **unchanged** — `SecretLibraryInvasionRunTerminate(token,
  "success", …)` still called exactly where it always was, after (not blocking on) the new participant
  loop body.
- Logout/relog preserves pending state: **done by construction** — `player:kv()` is the project's own
  established DB-backed per-player store (confirmed real native API in earlier passes:
  `src/lua/functions/creatures/player/player_functions.cpp`), not a runtime table.
- Cerebrir NPC exists through standard Canary NPC architecture: **unchanged/confirmed** — the file
  already used `Game.createNpcType`/`NpcHandler`/`FocusModule` boilerplate; only the keyword/dialogue
  body was added.
- Epilogue dialogue functional, follows Global story: **done** — every line is the fetched reference
  transcript, not paraphrased.
- Dialogue completion advances questlog/final state: **done** (`Library.Questline = 2`).
- One player's conversation cannot complete teammates: **done by construction** — both the KV flags and
  `npcHandler:getTopic(playerId)` are keyed per player id.
- Non-participant cannot falsely claim completion: **done** — `creatureSayCallback` re-checks
  `epiloguePending`/`epilogueComplete` on every message, not only at greet.
- Repeated dialogue idempotent: **done** — `greetCallback` short-circuits to a fixed "nothing more to
  add" line once `epilogueComplete` is set; no further writes occur.
- Library Liberator separate from final completion: **unchanged/confirmed** — no code path ties the two
  together.

**MAP_INTEGRATION_REQUIRED (not a code blocker):** Cerebrir's exact spawn tile inside the central hall is
not placed in this pass (no coordinate invented, none needed for the code to be correct) — recorded in
section 11.

## 3. P1 fixes

**Spellstealer (P1 section 2).** PROVEN_REFERENCE: "The Spellstealer é inicialmente invulnerável a todos
os ataques" (starts invulnerable to all attacks) — the encounter was spawning the plain vulnerable "The
Spellstealer" type and leaving it that way until the existing `InvasionSpellstealerColorSwap` random
timer eventually colored it. Fixed in `movements_invasion_start.lua`'s `spawnWingTransactional`: the
freshly-spawned boss is immediately transformed into a random initial green/red colored (immune) form via
the same `setType` + current-HP-reapply technique already proven safe for every other Spellstealer color
transform in this file — `getId()` (ownership) is unaffected by `setType`, so no ownership wiring changed.
Vortex interaction (correct vortex clears immunity, wrong vortex does not), return-to-colored cycling,
stale-callback safety, and Demon Slave's ownership-safe/bounded ambient-add model (`wingAddIds`, cleared
on wing end by the existing `InvasionWingBossDied` removal loop) were all already correct — confirmed by
inspection, not modified.

**Scion of Havoc fire-heal (P1 section 3).** PROVEN_REFERENCE, newly confirmed via the Scion's own
dedicated TibiaWiki monster page (`-100% Cura-se quando atacado com Fogo` — heals when attacked with
Fire), distinct from the already-implemented Spawn-of-Havoc-explosion heal. Implemented as
`InvasionScionHealFire` (`creaturescripts_invasion_wings.lua`), an `onHealthChange` redirect on
`COMBAT_FIREDAMAGE`/secondary fire — the exact same pattern already used for the Brothers' ice-heal
(`InvasionBrothersHealIce`), since this engine clamps an elements-table percent at 100% rather than
converting it into a real heal. Non-fire damage passes through unmodified. Ownership-gated via
`SecretLibraryInvasionRunOwnsWingBoss("scionOfHavoc", …)` — a stale/foreign same-name Scion cannot be
affected. Registered in `the_scion_of_havoc.lua`'s `monster.events`.

**Brothers / Biting Cold healing (P1 section 4).** PROVEN_REFERENCE: "Os bosses e os Biting Colds se
curam" (the bosses AND the Biting Colds heal [each other]) — the prior mechanic only had the two bosses
healing each other; Biting Cold adds took no part. Rebuilt `InvasionBrothersHealEachOther`
(`creaturescripts_invasion_wings.lua`) around a shared current-wing-generation pool (`brothersHealPoolIds`)
containing both alive bosses and every currently-owned Biting Cold add id; each tick, an owned pool member
heals a random other pool member. Registered on all three monster types (`brother_chill.lua`,
`brother_freeze.lua`, `biting_cold.lua` — the last previously had no `monster.events` at all). Ownership
is checked via `SecretLibraryInvasionRunOwnsWingBoss`/`OwnsWingAdd("brothers", …)` for both boss and add
callers — current-run and current-wing-generation only; stops naturally when the wing ends (adds are
removed by the existing `InvasionWingBossDied` cleanup, after which ownership checks fail for any
survivor). Exact proximity-gating ("mantê-los afastados um do outro") is not reproduced — disclosed as
`CUSTOM_GLOBAL_LIKE_PENDING_EXACT_TIMING/VALUE`, non-blocking per the task's own instruction not to turn
uncertain timings/values into closure blockers; the required mechanic itself (mutual healing including
the adds) is fully present.

## 4. Horizontal functional-chain matrix

| Surface | Verdict | Notes |
|---|---|---|
| A. Prerequisites/access | OK | `validateParticipant` (unchanged, re-inspected): Premium, `LibraryPermission >= 7`, all 4 inner bosses defeated. No bypass found. |
| B. NPC/story flow | OK | Dedoras/Charles/Spectulus/Gareth/Gail/Cerebrir all present; every reachable dialogue branch advances a real storage. No dead-end NPC found. |
| C. Mission/state order | OK | Storages/KVs advance monotonically; inner-boss defeat flags (`Library.{Lokathmor,Gorzindel,Mazzinor,Ghulosh}Defeated`) confirmed set exactly where earned (grep-verified, section 6) and read only as gates, never regressed. |
| D. Questlog | OK | The 6 catalogued missions are unchanged and match the reference's own stated mission count exactly (re-confirmed against the live quest page this pass — no 7th catalog mission exists in Global either). The final chapter's progress/completion is now represented via `Library.Questline` (0/1/2), not a fabricated 7th catalog entry. |
| E. Required objectives/items | OK | Master Debater (prior passes), inner bosses, wing bosses — all functional. Wing/vortex exact tiles remain `MAP_INTEGRATION_REQUIRED`, not a code defect (`InvasionMapReady()` fails closed, unchanged). |
| F. Bosses/events | OK | All required bosses spawn transactionally with exact-id ownership; kill credit is roster/room-restricted; timeout/technical-abort paths allow retry (unchanged, re-confirmed). |
| G. Rewards/progression | OK | Master Debater book reward and Battle Mage outfit reward both already transactional (weight/backpack check before `addItem`/storage commit). No required resource can be burned before commit. |
| H. Final chain | **Closed this pass** | Scourge death → betrayal message → `epiloguePending` → Cerebrir dialogue → `epilogueComplete`/`Library.Questline = 2`. Previously entirely missing (sections 2-3). |

No already-accepted subsystem was reopened without a concrete P0/P1 defect.

## 5. NPC/story verdict

All NPCs required to start, advance, or finish any mission (including the final chapter) exist in code
and are reachable. Cerebrir was the one genuine gap (a registered but non-functional stub) — now
implemented. No other dead-end found in this pass's horizontal sweep.

## 6. Questlog/state verdict

Storages/KVs advance in the intended order; relog does not destroy permanent progress (Lua-table run
state resets on server restart by design — same as every other boss in this quest — but per-player
storages and KV are DB-backed and unaffected). No impossible state found. `Library.Questline` (0/1/2) is
the new, honest representation of final-chapter progress; it was a reserved-but-dead storage id before
this pass, not a repurposed live one.

## 7. Boss/mechanic verdict

Every required boss (4 inner + 4 wing + Scourge) can be initiated by code, has kill credit restricted to
the legitimate current run/roster, and allows retry on failure/timeout (all pre-existing, re-confirmed).
Spellstealer/Scion/Brothers-Biting Cold mechanics corrected this pass per section 3. No cross-run/
cross-party corruption path found.

## 8. Reward/progression verdict

No required resource can be permanently burned before a reward commits (Master Debater book,
Battle Mage outfit — both already transactional from prior work, re-confirmed, unchanged). Optional/
cosmetic rewards (loot, Fleeting Knowledge Mount) do not gate closure and were not investigated further
per governance section 6.

## 9. Final completion verdict

**Chain now complete end-to-end:** final invasion → Scourge → participant credit (Library Liberator,
unchanged) → Cerebrir pending state → Cerebrir dialogue → `Library.Questline = 2` (final completion).
This was the single largest gap carried over from document 07 (section 23) — closed this pass.

## 10. P2/P3 backlog (non-blocking, not implemented)

- Master Debater reward book sprite/appearance; exact decorative text fidelity beyond the already-cited
  Oberon-cross-validated quotes.
- Wooden Trunk / Ashes / Remains of a Mummy (Master Debater II/III/VIII) exact object identity —
  `NOT_PROVEN`, unchanged.
- Exact wing/vortex/add SQMs, AID/UID/map decoration — see section 11.
- Graphical effects/HUD; exact visual Magic Discharge representation (`NOT_PROVEN`, unchanged).
- Masterbook/golden-orb — not corroborated as required to progress to Scourge; not implemented
  (unchanged).
- Exact central-wave replenishment cadence/count; exact generic boss attack damage numbers (combat
  balancing, separate scope per governance).
- Cerebrir's "seven" keyword step: the fetched transcript's own player-side line at that point in the
  conversation reads literally as "Seven" with no clearly-highlighted antecedent earlier in the same
  fetched page — most plausibly a coded reference to "one of the seven" (stated two lines later) rather
  than a scrape artifact, and implemented as given; flagged here in case a cleaner primary source
  surfaces later. Not a functional blocker — the keyword is reachable and advances the conversation
  correctly either way.
- Brothers/Biting Cold healing: exact proximity-gating, not implemented (section 3).

## 11. Map integration backlog

Unchanged from documents 02/05/06/07, plus one new item:
- Four wing rooms' exact boss/add spawn tiles, Spellstealer vortex tiles — `NOT_PROVEN`,
  `InvasionMapReady()` still fails closed.
- **New:** Cerebrir's exact spawn tile inside the already-proven central hall (`ROOM_FROM`/`ROOM_TO`
  rectangle, `creaturescripts_scourge_of_oblivion_phases.lua`) — code/NPC/state are ready;
  `MAP_INTEGRATION_REQUIRED` for physical placement only, per governance section 1's explicit allowance
  not to block on this.

## 12. Validation/CI

```
luaparser.ast.parse on all 7 changed files -> OK, 0 failures
git diff --check -> clean (only benign core.autocrlf LF->CRLF working-tree notices)
python -m tools.canary_audit validate-schemas -> All Canary audit schemas are valid
python -m unittest discover -s tools/canary_audit/tests -t . -p "test_*.py" -> Ran 72 tests, OK (skipped=3, environment-only)
python -m tools.canary_audit scan --profile otservbr-global --fail-on error
  -> Findings: 823 (error: 4, warning: 484, info: 335) - IDENTICAL totals to every prior pass's baseline
  -> 4 blocking findings, all 4 the pre-existing baseline (item ids 2874, 3452, 6276, 12724) - zero new
     (individually re-confirmed by rule/file/line this pass via --github-annotations output)
```

No executable Lua gameplay-test harness and no local server build exist in this repository (unchanged
limitation, disclosed identically in every prior document) — not fabricated. GitHub Actions CI results
for the commit this pass produces were not available at document-authoring time (written immediately
before push); not fabricated here.

## 13. Code classification

**QUEST_CODE_COMPLETE**

No known P0: the previously entirely-missing Cerebrir epilogue/true-completion chain is now implemented
and idempotent/participant-safe. No known P1: Spellstealer's initial-state defect, the Scion fire-heal
gap, and the Biting Cold healing-participation gap are all closed. The complete functional chain now
exists from first required stage (Dedoras' clue-gathering) through final completion
(`Library.Questline = 2`). Remaining open items (section 10) are P2/P3/polish/backlog only — none of them
block legitimate progression or completion.

## 14. Map classification

**MAP_INTEGRATION_REQUIRED**

Unchanged: the four wing rooms' exact boss/add/vortex tiles remain unplaced, so `InvasionMapReady()`
still fails closed and the encounter cannot physically start end-to-end without an owner-provided
OTBM/RME pass. Cerebrir's own placement is a small addition to the same backlog (section 11). No
coordinate was invented anywhere in this pass.
