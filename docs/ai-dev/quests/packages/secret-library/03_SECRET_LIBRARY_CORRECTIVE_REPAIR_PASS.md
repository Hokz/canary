# Secret Library — Corrective Verification & Repair Pass

Role note: written by the technical executor, in response to an independent reviewer rejecting the
prior pass's `CODE_COMPLETE_MAP_BLOCKED` classification. This document reports implementation and
evidence only. It is **not** an independent validation, grants no approval, and authorizes no merge.

## 1. Starting branch / base / head / dirty state

- Repository: `Hokz/canary`, PR #37, branch `ai-dev/secret-library-full-repair-v2`.
- Fetched `origin/main` and `origin/ai-dev/secret-library-full-repair-v2` before any action.
- Expected starting head `0e560120b5baf7df60951a3f21face61d9fcf43c` — **confirmed exact match**
  (local `HEAD`, remote branch head, and `gh pr view 37 --json headRefOid` all agreed).
- Expected base `02ddd28b70a79116f02c44cb6f1096bdea8a9e6b` — **confirmed exact match**; main has not
  moved since the previous pass.
- `gh pr view 37`: `state=OPEN`, `isDraft=true`, `mergeable=MERGEABLE` — confirmed before any action.
- Working tree was clean at start. No discrepancy from the expected state was found; nothing needed
  to be reconciled before beginning work.

## 2. Commits produced

One commit on `ai-dev/secret-library-full-repair-v2`, containing:
- Two code fixes (Master Debater document discovery, central-hall invasion raid waves).
- This handoff document and a superseding note added to document 02.

See section 21 for the exact validation run against this commit, and the PR itself for the exact
commit SHA and message (this document is part of that same commit, so its own final SHA cannot be
self-referenced here — see `git log` on the branch).

## 3. Exact OTBM artifact provenance, size, SHA-256

Re-verified identical to the previous pass, from the same project-declared source
(`config.lua.dist` line 425, `docker/data/start.sh`, `.github/scripts/release_metadata.py`):

- URL: `https://github.com/opentibiabr/canary/releases/download/v3.6.1/otservbr.otbm`
- Size: 184,776,037 bytes
- SHA-256: `a80de1dda6a9aca3956a9d5b7fb2e0caebb451570d26853fc21beb40d5f31da2`

Re-downloaded fresh for this pass (the previous session's copy had been cleaned up) and the hash
matched exactly, confirming stable identity of the artifact across both passes. Used strictly
read-only; no OTBM write/re-save was made or attempted.

## 4. Corrected Master Debater reference matrix

| # | Achievement-marker position (previous pass) | Corrected documented container position | Object class |
|---|---|---|---|
| I | `(33369,31347,3)` | `(33369,31348,3)` | Writing Desk |
| II | `(33362,31317,3)` | `(33362,31317,3)` (unchanged) | Wooden Trunk |
| III | `(33373,31349,6)` | `(33373,31349,6)` (unchanged) | Ashes |
| IV | `(33374,31336,3)` | `(33374,31336,3)` (unchanged) | Writing Desk |
| V | `(33369,31325,6)` | `(33368,31325,6)` | Pile of Bones |
| VI | `(33369,31327,6)` | `(33368,31327,6)` | Pile of Bones |
| VII | `(33387,31285,7)` | `(33387,31285,7)` (unchanged) | Pile of Bones |
| VIII | `(33371,31349,7)` | `(33371,31349,7)` (unchanged) | Remains of a Mummy |
| IX | `(33369,31343,8)` | `(33369,31343,8)` (unchanged) | Chest |

## 5. Exact OTBM item-stack evidence for all nine interactive containers

All nine corrected positions were re-inspected, plus the immediate previous-pass positions for I/V/VI
for a direct before/after comparison, plus a wide surrounding-radius sweep for II/III/VIII:

| # | Position | Ground item | Item(s) physically present | AID/UID/text |
|---|---|---|---|---|
| I | `(33369,31348,3)` | 16484 | **27880** | none |
| I (old, uncorrected) | `(33369,31347,3)` | 16484 | *(none — empty)* | — |
| II | `(33362,31317,3)` | 16489 | *(none on the exact tile)* | none |
| III | `(33373,31349,6)` | 16487 | *(none on the exact tile)* | none |
| IV | `(33374,31336,3)` | 16489 | **27880**, 2697 (unresolved) | none |
| V | `(33368,31325,6)` | 16485 | **4285** | none |
| V (old, uncorrected) | `(33369,31325,6)` | 16484 | 6381 (unresolved) | — |
| VI | `(33368,31327,6)` | 16485 | **4285** | none |
| VI (old, uncorrected) | `(33369,31327,6)` | 16486 | 3126 = "rubbish" (confirmed, but wrong prop) | — |
| VII | `(33387,31285,7)` | 18458 | 16294 (unresolved), **4285**, 3122 = "dirty cape" (confirmed, but unrelated) | none |
| VIII | `(33371,31349,7)` | 499 | 24985, 16631 (both unresolved) | none |
| IX | `(33369,31343,8)` | 6388 | 15212 (unresolved), **2472** | none |

Item names were resolved two independent ways, cross-checked against each other: the tracked
`data/items/items.xml` (server-side overrides) and a hand-written decoder against
`data/items/appearances.dat` (this repository's own Appearances protobuf, per
`src/protobuf/appearances.proto`'s `Appearance{id=1, name=4, description=5}` field layout). Both
sources agree exactly where both have data: item 4285 = "pile of bones", item 2472 = "chest", item
3122 = "dirty cape". Item 27880 has no name in either source but its identity as "the Writing Desk
object" is established by a different, equally strong signal: it is the **only** item that recurs at
both independently-labeled Writing Desk positions (I and IV) and appears nowhere else near either
position.

**II (Wooden Trunk) and III (Ashes)**: a wide-radius sweep (a ~10×10 box around each) found dozens of
nearby items, none of which resolve (by name or by cross-position recurrence) to a "trunk" or "ashes"
identity. The closest thematic candidates found were items in the "burnt wall" range (8793-8798, near
III but 1-5 tiles off) and items in the "mountain"/"debris" ranges near II — neither is a confident
match. **Not wired.**

**VIII (Remains of a Mummy)**: two items present (24985, 16631), neither resolves via either name
source, and neither recurs anywhere else to provide a cross-position identity signal the way item
27880 or 4285 did. **Not wired.**

## 6. Loose-pages-I REFERENCE_CONFLICT analysis

The achievement-marker position `(33372,31337,3)` and the claimed book-location cluster around
`(33374-33376,31338-31340,3)` were physically inspected. Findings:

- `(33372,31337,3)`: ground 16489, one item (17872, unresolved).
- The `33374-33376 × 31338-31340` cluster: ground uniformly 416 (a distinct floor type from the
  desk/bones/chest positions above); items present resolve via `items.xml` to **"ornate carpet"**
  (17396-17404 range) and **"small mudpit"** (10675-10681 range) — both purely cosmetic ground
  decoration, not book/shelf objects. No bookshelf, book stack, or reading-object item was found
  anywhere in this cluster.

**Conclusion: REFERENCE_CONFLICT, not resolved.** The physical evidence does not confirm a book
object at either candidate position for "Knightly Successor Orders of Tibia, loose pages I". Per this
pass's own instruction, the nine incontrovertible-where-provable debate volumes were implemented (six
of nine — see section 8) without adding a tenth requirement; the loose-pages item remains undecided
and is **not** part of `MasterDebaterRequiredDocumentKeys`. If future evidence proves it is a genuine
tenth prerequisite, it can be added as one more entry in that same list without restructuring the
mechanism.

## 7. Repository item/action identity findings

- `data/items/items.xml` and `data/items/appearances.dat` were used as the two authoritative,
  already-tracked, in-repository sources for item identity (no external database or remembered item
  IDs were used).
- `Player:kv()` / `KV:scoped()` / `KV:get()` / `KV:set()` confirmed as real, natively-registered Lua
  methods (`src/lua/functions/creatures/player/player_functions.cpp:467`,
  `src/lua/functions/core/libs/kv_functions.cpp:20-29`) before being used in the implementation.
- `Action:position(...)` confirmed as an already-used, real registration pattern in this exact
  codebase (`data-otservbr-global/scripts/actions/object/rope_down.lua`), matching the convention this
  pass's implementation follows.
- The `"Master Debater"` achievement (id 445) was confirmed still registered and unchanged in
  `data/scripts/lib/register_achievements.lua:446`.
- The seven central-raid monster type files (`imp_intruder.lua`, `invading_demon.lua`,
  `ravenous_beyondling.lua`, `rift_breacher.lua`, `rift_minion.lua`, `rift_spawn.lua`,
  `yalahari_despoiler.lua`) were confirmed present under
  `data-otservbr-global/monster/quests/the_secret_library/`, and their exact
  `Game.createMonsterType(...)` name strings were read directly from each file and used verbatim in
  the new roster table (no invented/guessed casing).

## 8. Master Debater implementation contract and exact files changed

New file: `data-otservbr-global/scripts/quests/the_secret_library_quest/the_order_of_the_falcon/actions_master_debater_documents.lua`

- `DOCUMENTS` table: the six confirmed positions (section 4/5), each with a stable `key`.
- `MasterDebaterRequiredDocumentKeys` (global): all nine keys, including the three unresolved ones
  (`wooden_trunk`, `ashes`, `remains_of_a_mummy`) whose keys can never be set by anything in this
  codebase yet — the achievement gate is honest about requiring nine, not silently downgraded to six.
- One `Action()` object registered at all six confirmed positions via `:position(...)` (matching the
  already-used pattern in `rope_down.lua`) — narrow by construction, cannot affect any unrelated desk/
  bones/chest object elsewhere even though the underlying item ids are generic decoration classes.
- `onUse`: resolves the exact document by `item:getPosition()` equality against the `DOCUMENTS` table,
  checks/sets a per-player KV flag, sends a flavor message, and (only on first discovery) calls
  `MasterDebaterCheckAchievement`.

Modified file: `data-otservbr-global/scripts/quests/the_secret_library_quest/creaturescripts_kill.lua`

- One line added inside the existing `monsterStorage.lastBoss` branch (Oberon's own kill-credit path):
  a call to `MasterDebaterCheckAchievement(p)`, so the achievement also re-evaluates the moment Oberon
  is legitimately killed, not only on a document Use.

## 9. Persistence/KV design

- Storage: `player:kv():scoped("secret-library-master-debater"):scoped("documents"):get/set(key)` —
  DB-backed (`src/kv/kv_sql.cpp`), survives logout/restart, matches this project's own established
  convention for equally-granular per-player discovery state
  (`lib/quests/measuring_tibia.lua`'s own header comment cites the same rationale: this repo's
  achievement system and quest tracker already use this exact pattern).
- **Idempotent**: `onUse` checks `kv:get(doc.key)` before setting; a repeat Use is a safe no-op past
  the first discovery (distinct flavor message, no re-trigger of the achievement check's side effects
  beyond its own `hasAchievement` guard).
- **No cross-slot substitution**: each of the six wired documents has its own distinct `key`, resolved
  by exact position match against the `DOCUMENTS` table — one object cannot satisfy another slot.
- **No party/nearby-player cross-credit**: the KV flag is set only on the `player` parameter `onUse`
  is called with (the actual user), never broadcast to a room/party/damage-map.
- **No global storage authority**: per-player KV only: no `Game.setStorageValue` or shared Lua table
  is used for document state.

## 10. Achievement evaluation logic

`MasterDebaterCheckAchievement(player)`:
1. Returns immediately if the player already has the achievement (idempotent, no duplicate grant).
2. Returns immediately if any of the nine `MasterDebaterRequiredDocumentKeys` is not yet set in that
   player's own KV scope (three of which can currently never be set — see section 5/6).
3. Returns immediately unless `FalconBastion.KillingBosses >= 6` for that player — the project's own
   existing signal for "this exact player legitimately killed Oberon as sequential stage 6", not a new
   storage.
4. Grants the achievement.

Called from two independent trigger points (document discovery, Oberon kill) so the grant is
**order-independent**: whichever of "collect the last discoverable document" or "kill Oberon"
happens second is the one that actually triggers the grant, and both call the identical function so
there is exactly one code path to reason about, not two divergent ones. `Millennial Falcon` is
untouched — it is still granted unconditionally on Oberon's own `achievements` list in
`creaturescripts_kill.lua`, independent of Master Debater.

Because three of the nine required keys are currently unwireable, **the achievement cannot currently
be granted to anyone** — this is a disclosed, correct consequence of "must not grant unconditionally
that must not grant unconditionally" combined with genuinely incomplete map evidence, not a bug. It
is a strict improvement over the previous state: previously, the achievement was either always
falsely granted (before the very first repair pass in this whole engagement) or never granted with no
tracking infrastructure at all (the immediately preceding pass); now it has correct, real,
persistent, idempotent tracking for six of nine requirements and will become grantable the moment a
future map pass resolves the remaining three, with no further code change to the gate itself.

## 11. Central invasion reference evidence

Per the reviewer-supplied reference (`https://www.tibiawiki.com.br/index.php?stableid=307904&title=The_Secret_Library_Quest`),
taken as given for this pass (not independently re-fetched — no live web access was used or is
available to verify the exact wiki revision content beyond what was provided in the task):

- Players enter the central hall; invasion creatures begin appearing "about 1 minute after entry".
- Central-hall combat continues until a wing is breached.
- After a wing boss dies, players return to the central hall and a new central attack wave begins
  before the next wing breach — central-hall phases and the four wing bosses **alternate**, they do
  not run concurrently with breach messages alone.
- After the Spellstealer (first) wing, Invading Demons are added to the central attack roster.
- Central raid creature family: Imp Intruder, Invading Demon, Ravenous Beyondling, Rift Breacher,
  Rift Minion, Rift Spawn, Yalahari Despoiler — all seven already exist as monster type files in this
  repository (section 7), none invented.

No exact per-round roster table beyond the one confirmed escalation point (Invading Demon from round
2), no exact wave duration, and no exact spawn count/cadence were available in the reference as
supplied. These are disclosed as `CUSTOM_GLOBAL_LIKE_PENDING_EXACT_COUNT` /
`CUSTOM_GLOBAL_LIKE_PENDING_EXACT_TIMING` — see section 15.

## 12. Central hall physical spawn-surface evidence

Reused this pass's own already-captured z=11 central-hall tile data (from the previous verification
pass's OTBM scan, re-confirmed still valid against the freshly re-downloaded, hash-identical
artifact). Seven tiles were selected from within the central hall's proven-real, proven-walkable
floor footprint (`attr_item_id` in the confirmed library-floor set `{101, 11417, 11424, 28284-28290}`,
not a wall/mountain/void tile), spread across the hall's core rather than clustered on one spot:

```
Position(32716, 32729, 11)
Position(32723, 32729, 11)
Position(32730, 32729, 11)
Position(32737, 32729, 11)
Position(32722, 32730, 11)
Position(32729, 32730, 11)
Position(32736, 32730, 11)
```

317 candidate real floor tiles were available in the scanned core region; these seven were selected
as a representative, non-clustered spread, not an exhaustive or exact CipSoft-matching set. Labeled
`CUSTOM_GLOBAL_LIKE_PENDING_EXACT_POSITION` in-code and here — proven real and walkable, not proven to
be the exact intended spawn SQMs. This is explicitly **not** used as license to guess the four wing
boss/Spellstealer vortex positions, which remain fully unresolved (section 17-18) — the central hall
itself was already `PROVEN_PRESENT` in the previous pass, unlike the wing rooms.

## 13. Central wave state machine

Implemented in `movements_invasion_start.lua` and `actions_the_scourge_of_oblivion.lua`:

```
lever pulled -> createInvasionEncounter()
    -> (60s delay, CUSTOM_GLOBAL_LIKE_PENDING_EXACT_TIMING)
    -> InvasionStartCentralWaveRound(token, 1)
        -> spawnCentralWave(token, 1)   [roster round 1, generation N]
        -> (60s duration) -> clearCentralWave(generation N) -> InvasionAdvanceWing(token, 1)
            -> NE Spellstealer wing (unchanged wing-ownership machinery)
            -> InvasionWingBossDied(token, "spellstealer")
                -> (30s grace, WING_TRANSITION_DELAY, unchanged constant)
                -> InvasionStartCentralWaveRound(token, 2)
                    -> spawnCentralWave(token, 2)  [roster round 2: + Invading Demon]
                    -> ... -> InvasionAdvanceWing(token, 2) -> SE Scion of Havoc -> ...
                        -> InvasionStartCentralWaveRound(token, 3) -> ... -> SW Brothers -> ...
                            -> InvasionStartCentralWaveRound(token, 4) -> ... -> NW Devourer -> ...
                                -> InvasionStartCentralWaveRound(token, 5)  [final roster, all 7 types]
                                    -> (60s duration) -> clearCentralWave -> InvasionActivateScourge(token)
```

`SecretLibraryInvasionRun` gained two fields: `centralWaveGeneration` (int, bumped once per round) and
`centralWaveCreatureIds` (set: creatureId → true, current-round-only). `spawnCentralWave` returns the
generation it just committed; the round's own end-of-duration callback captures that exact generation
value and passes it to `clearCentralWave`, which only clears if `SecretLibraryInvasionRun.centralWaveGeneration`
still equals that captured value — the same generation-guard pattern already used throughout this
project (wing generations, Scourge phase generations, Lokathmor trap generations, etc.), so a stale
clear from an earlier round can never remove a later round's creatures.

`SecretLibraryInvasionRunTerminate` (unchanged function, one addition): the non-success cleanup branch
now also iterates and removes every id in `centralWaveCreatureIds`, and the full-reset tail now also
zeroes `centralWaveGeneration`/`centralWaveCreatureIds` — so a technical-abort or timeout mid-central-
wave cannot leave orphaned raid creatures behind, exactly like every other owned-entity set in this
run.

`InvasionMapReady()` was **not modified**. It still gates the whole encounter on the four wing rooms'
`roomCenter`/`spawnPositions`/Spellstealer teleport tiles, all still `nil`. The central-wave repair
does not and cannot make the encounter startable — the lever still refuses to pull while wing geometry
is unresolved, per section 5.5 of the corrective task and unchanged from the previous pass.

## 14. Monster composition and timing evidence

See section 11 (reference) and section 13 (implementation). Roster escalation (round → added type):
round 1 = Imp Intruder + Rift Minion + Rift Spawn; round 2 = + Invading Demon (the one reference-
confirmed escalation point); round 3 = + Rift Breacher; round 4 = + Ravenous Beyondling; round 5
(final, pre-Scourge) = + Yalahari Despoiler, i.e. the full seven-type roster. Rounds 3/4/5's added
types are a disclosed, undocumented-exact escalation choice (see section 15) built only from the
seven monster types the reference and repository both confirm exist for this raid family — no new
monster type was invented or guessed.

## 15. Every approximation with CUSTOM_GLOBAL_LIKE label

- `CUSTOM_GLOBAL_LIKE_PENDING_EXACT_TIMING`: initial central-wave delay (60s, replacing the previous
  pass's 30s value, now matching the reference's own "about 1 minute" more closely but still not
  exact); each central-wave round's duration (60s, reused for every round, not individually sourced);
  the existing 30s inter-wing grace delay (`WING_TRANSITION_DELAY`, unchanged, not re-evaluated this
  pass beyond confirming it still makes sense as the gap between a wing's death and the next central
  round starting).
- `CUSTOM_GLOBAL_LIKE_PENDING_EXACT_COUNT`: the exact per-round monster roster/count beyond the one
  confirmed escalation point (Invading Demon at round 2) — rounds 3-5's added types (Rift Breacher,
  Ravenous Beyondling, Yalahari Despoiler) and the fixed "one of each roster type" spawn count are a
  disclosed approximation, not sourced numbers.
- `CUSTOM_GLOBAL_LIKE_PENDING_EXACT_POSITION`: the seven central-wave spawn tiles (section 12) — real
  and walkable, not proven to be the exact intended SQMs.
- Unchanged from the previous pass (not re-litigated, still standing): Lokathmor's 90s trap interval,
  Mazzinor's 45s charge interval, Scourge phase durations, Devourer damage-reduction stacking, etc. —
  full list in the PR body and document 02.

## 16. Run-token/generation/owned-ID lifecycle analysis

- **Exact current run token**: every new function (`spawnCentralWave`, `clearCentralWave`,
  `InvasionStartCentralWaveRound`, `InvasionActivateScourge`) checks
  `SecretLibraryInvasionRunIsCurrent(token)` before acting, identical to every pre-existing function in
  this file.
- **Central-wave generation token**: `centralWaveGeneration`, bumped once per `spawnCentralWave` call;
  `clearCentralWave` compares against the exact generation it was given, not the live value at call
  time from some other source — a stale round's clear cannot fire against a newer round's creatures.
- **Owned creature IDs**: `centralWaveCreatureIds` set, populated only from this round's own
  `Game.createMonster(...)` return values — no name-based lookup, no global scan.
- **No foreign creature with the same name can mutate state**: the central-wave creatures are never
  looked up by name anywhere in this implementation; only by the ids captured at spawn time, and only
  for removal (there is no health/death handler on them at all — they are pure flavor combat, not
  wired to any credit/progression path, so there is no name-based credit surface to exploit either).
- **Spawn transaction/failure behavior is bounded**: `spawnCentralWave` is explicitly non-mandatory
  (ambient) per this project's own established mandatory-vs-ambient distinction (documented in the
  code) — a partial spawn (some `Game.createMonster` calls returning nil) does not abort the
  encounter, matching the reference's own framing of these as flavor raid pressure, not a progression
  gate the way a wing boss is.
- **Cleanup removes only owned central-invasion creatures**: `clearCentralWave` and
  `SecretLibraryInvasionRunTerminate`'s non-success branch both iterate `centralWaveCreatureIds`
  exclusively.
- **Technical abort / normal timeout clear owned entities and preserve the cooldown-refund contract**:
  unchanged `SecretLibraryInvasionRunTerminate` function, extended (not replaced) to also sweep
  `centralWaveCreatureIds` — the existing `technical_abort` cooldown-refund branch and the existing
  event-sweep (`for eventId in pairs(SecretLibraryInvasionRun.events)`) already cover every `addEvent`
  this pass added, since every new delayed call is registered through the same
  `SecretLibraryInvasionRunTrackEvent(token, addEvent(...))` convention as the rest of the file.
- **A new attempt cannot inherit an older one's callbacks/entities**: `createInvasionEncounter` resets
  `centralWaveGeneration = 0` and `centralWaveCreatureIds = {}` at the start of every fresh run, and
  the token bump (`SecretLibraryInvasionRun.token = SecretLibraryInvasionRun.token + 1`) already
  invalidates every `IsCurrent(token)` check for the previous run's in-flight callbacks regardless.
- **No global cross-run contamination**: all new state lives inside the single
  `SecretLibraryInvasionRun` table, never a `Game.setStorageValue`.

## 17. Current four-wing map blockers

**Unchanged from document 02, not re-investigated this pass** (out of this pass's scope — the
reviewer's two required fixes were Master Debater and the central raid, not the wing rooms). Still
`PROVEN_PRESENT_CODE_WIRING_REQUIRED` at the room level (two large real halls flanking the central
hall, confirmed in the previous pass), still `NOT_PROVEN` for the exact per-wing boss-spawn tile and
which compass half of each hall corresponds to which named wing. `InvasionMapReady()` still correctly
refuses to start the encounter while these remain nil (section 13).

## 18. Spellstealer vortex status

**Unchanged, still `NOT_PROVEN`.** No green/red teleport tile evidence was found in the previous
pass's sweep of both flanking halls, and this pass did not re-sweep them (out of scope this pass —
see section 17). Not wired; not guessed.

## 19. Gorzindel AID status

**Unchanged, kept qualified exactly as instructed.** The previous pass's finding stands: the five
Stolen Knowledge side rooms are real, intentional, portal-only topology (not incomplete coverage) —
`PROVEN_PRESENT`. The `movements_gorzindel.lua` teleport-in mechanic's own AID 4952 trigger tile was
not found in a 150×140-tile sweep of the whole Library complex in the previous pass. Per this pass's
explicit instruction, this is **not** re-classified `MAP_EDIT_REQUIRED` and nothing was fabricated —
it remains `NOT_PROVEN`, disclosed as a possible artifact/extractor limitation (this exact downloaded
map appears to carry no action/unique ids anywhere at all, in any of the ~75,000+ tiles decoded across
both passes combined, not just near Gorzindel — see document 02 section C for the full caveat and the
positive control that ruled out a wholesale extractor bug, e.g. the "Isle of the Kings" sign's `text`
attribute decoded correctly). No Gorzindel code change was made this pass.

## 20. Full progression trace

Falcon documents (6 of 9 discoverable, KV-tracked, order-independent) → Falcon bosses (6, sequential,
`FalconBastion.KillingBosses` 1→6, unchanged from the previous pass) → Oberon/debate (9Q/9A mechanic,
unchanged, re-confirmed correct in the previous pass's audit, not re-touched this pass) → Master
Debater evaluated on whichever of {last document, Oberon kill} completes second → library permission
(`LibraryPermission`, unchanged) → library entrance (unchanged) → inner bosses (Lokathmor, Gorzindel,
Mazzinor, Ghulosh — all unchanged, all previously rebuilt on run-token ownership) → four persistent
per-player completion flags (unchanged) → final invasion lever eligibility (unchanged: Premium +
`LibraryPermission>=7` + all four inner bosses + `InvasionMapReady()`) → **central wave round 1**
(new) → NE Spellstealer (unchanged wing machinery) → **central wave round 2** (new, adds Invading
Demon) → SE Scion of Havoc → **central wave round 3** (new) → SW Brothers → **central wave round 4**
(new) → NW Devourer → **central wave round 5** (new, full roster) → Scourge activation (unchanged) →
Scourge 3-phase cycle + beam (unchanged) → success credit / Library Liberator (unchanged, roster +
room-presence based) → Master Debater / Millennial Falcon achievements (unchanged grant paths, Master
Debater now backed by real tracking instead of either false-unconditional or entirely absent).

No new soft-lock, storage gap, monotonic-jump, or credit-leak surface was introduced: the two new
subsystems (document KV tracking, central waves) are strictly additive and do not gate, skip, or
short-circuit any existing storage/ownership check.

## 21. Validation commands/results

```
python -c "from luaparser import ast; ..." over all 4 touched/new files -> all OK, 0 failures
git diff --check -> clean (only benign core.autocrlf LF->CRLF working-tree notices)
python -m tools.canary_audit validate-schemas -> All Canary audit schemas are valid
python -m unittest discover -s tools/canary_audit/tests -t . -p "test_*.py" -> Ran 72 tests, OK (skipped=3, environment-only)
python -m tools.canary_audit scan --profile otservbr-global --fail-on error
  -> Findings: 823 (error: 4, warning: 484, info: 335) - IDENTICAL totals to the pre-change baseline
  -> 4 blocking findings, all 4 the pre-existing baseline (action.duplicate-registration on item ids
     2874, 3452, 6276, 12724 - fluids.lua, rake.lua, baking.lua, action_raid_catapult.lua) - zero new
```

Targeted test harnesses (section 10.C of the corrective task): this repository has no automated
Lua gameplay-test framework for live-server mechanics (Actions/CreatureEvents/MoveEvents require a
running Canary server + game state to execute) - consistent with every other boss/encounter rebuild
across this entire multi-pass engagement, none of which added executable Lua gameplay tests either.
Rather than fabricate a test run that could not actually execute, the required invariants (document
idempotency/isolation/no-cross-slot, central-wave ownership/generation/cleanup) are instead traced
against the actual code in sections 9-10 and 16 above, referencing exact function names and guard
conditions - a manual, reviewable proof rather than a claimed-but-nonexistent automated one.

No local server binary/build was available in this environment to run startup/datapack smoke
validation this pass either; not fabricated.

## 22. GitHub CI run IDs/results

Not yet available at document-authoring time (this document is written before the corrective commit
is pushed). The independent reviewer can inspect the actual run results directly on PR #37 after the
push described in section 2 - this executor does not claim a CI result it has not observed.

## 23. New failures vs baseline failures

- **New regressions from this pass**: none observed. Audit scan totals (errors/warnings/info) are
  byte-for-byte identical before and after this pass's changes.
- **Pre-existing baseline**: the same 4 `action.duplicate-registration` findings (item ids
  2874/3452/6276/12724), all in files this pass and every prior Secret Library pass has never touched.
- **Environment/tooling limitations**: no Lua gameplay-test framework (section 21); no local server
  build to smoke-test; GitHub CI results not observed at authoring time (section 22).

## 24. Remaining blockers

1. Wooden Trunk, Ashes, and Remains of a Mummy document objects — physically unidentified; Master
   Debater cannot be granted to anyone until these are resolved (section 5, 10).
2. Loose-pages-I — unresolved `REFERENCE_CONFLICT`, deliberately not implemented (section 6).
3. Four wing rooms' exact boss-spawn tiles and the Spellstealer green/red teleport tiles — unchanged,
   still blocking `InvasionMapReady()` (section 17-18).
4. Gorzindel's AID 4952 physical trigger — still unconfirmed against this artifact (section 19).
5. Central-wave exact roster/timing/count beyond the one reference-confirmed escalation point — a
   disclosed approximation, not exact (section 15); would benefit from a more complete reference
   excerpt if one becomes available.

## 25. Final classification

**REPAIR_REQUIRED**

Rationale: both defects the independent review identified were addressed with real, evidence-backed
implementation (Master Debater discovery tracking for 6 of 9 documents with an honest 9-of-9 gate;
a full central-hall raid-wave state machine integrated into the existing run/generation ownership
model, replacing the `NOT_APPLICABLE` misclassification). This is **not** promoted to
`CODE_COMPLETE_MAP_BLOCKED` because genuine, disclosed approximations remain in the central-wave
timing/roster (section 15) that a stronger reference excerpt could tighten, and three of nine Master
Debater documents plus the loose-pages conflict remain physically unresolved (sections 5-6) - these
are evidence gaps this executor could not close from within this pass, not merely inherited map
blockers identical in kind to the wing-room problem. `InvasionMapReady()` remains untouched and still
fails closed; no fake completion path was introduced anywhere.
