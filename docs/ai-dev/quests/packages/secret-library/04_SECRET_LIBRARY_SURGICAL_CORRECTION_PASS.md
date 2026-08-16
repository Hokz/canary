# Secret Library — Surgical Correction Pass

Role note: written by the technical executor. Reports implementation and evidence only. Not an
independent validation, grants no approval, authorizes no merge.

This pass supersedes two specific implementation details from the previous pass (document 03): the
Master Debater `Action` matching logic in `actions_master_debater_documents.lua`, and the two
empty-room watchers in `actions_the_scourge_of_oblivion.lua`. Every other conclusion in documents 02
and 03 (OTBM provenance, the 32-item matrix, the Master Debater evidence matrix itself, the central
wave design, the wing/Gorzindel blockers) is unchanged and not repeated in full here.

## 1. Verified starting PR/repo state

- Fetched `origin/main` and `origin/ai-dev/secret-library-full-repair-v2` before any action.
- Expected starting head `6a94e3d6e2b14724a0165315383180f9c7a159a7` — **confirmed exact match**
  (local `HEAD`, remote branch head, `gh pr view 37 --json headRefOid` all agreed).
- Expected base `02ddd28b70a79116f02c44cb6f1096bdea8a9e6b` — **confirmed exact match**, unmoved.
- `gh pr view 37`: `state=OPEN`, `isDraft=true`, `mergeable=MERGEABLE` — confirmed before any action.
- Working tree was clean at start. No discrepancy found.

## 2. Exact files/commits changed

One commit on `ai-dev/secret-library-full-repair-v2`, modifying:
- `data-otservbr-global/scripts/quests/the_secret_library_quest/the_order_of_the_falcon/actions_master_debater_documents.lua`
  (Defect A fix)
- `data-otservbr-global/scripts/quests/the_secret_library_quest/library_area/actions_the_scourge_of_oblivion.lua`
  (Defect B fix)
- this document, and (see `git log`) the commit message for the exact SHA.

No other file was touched. `data/libs/functions/boss_lever.lua` (the shared framework) was **not**
modified — see section 10.

## 3. Defect A root cause

`Action:position(doc.pos)` registers a pure position selector; the engine dispatches to this handler
for **any** usable item whose target tile matches, not only the one item id this document's discovery
logic was written to expect. The previous `onUse` matched `DOCUMENTS` entries by `d.pos == pos` only —
it never compared `item:getId()`. A different, legitimately-existing usable item sharing one of these
six exact tiles (e.g. `2697`, the second, unresolved item already observed co-located with the desk
item at position IV in the previous pass's own evidence table) would have matched by position, been
silently swallowed by `return true` with no matching `doc`... actually re-reading the previous
version: `doc` would have been assigned (position matched), so it *would* have incorrectly been
treated as a legitimate document discovery for whichever `key` shared that position, regardless of
which of the (possibly multiple) items on that tile was actually used.

## 4. Canary positional dispatch evidence

- `src/lua/functions/events/action_functions.cpp`: `Action:position(...)` registers a position-based
  selector for the action.
- `src/lua/creature/actions.cpp`: positional dispatch selects an action when the used item's position
  matches a registered position selector, independent of the specific item id at that position.

Both confirmed present in this repository's own source tree before relying on this behavior.

## 5. Exact item+position identity fix

`DOCUMENTS` entries now carry an explicit `itemId` (27880 for both Writing Desk entries, 4285 for all
three Pile of Bones entries, 2472 for the Chest entry — the exact ids already established as
identity-confirmed in the previous pass's evidence matrix, not newly invented). `onUse` now requires
`d.pos == pos and d.itemId == itemId` to select a `doc`; if no entry matches both, it returns `false`
(not `true`), letting the engine fall through to that item's own default handling instead of silently
consuming the Use with no effect. No KV mutation, message, or achievement check happens on a
non-matching item — the entire body after the `if not doc then return false end` guard is unchanged
and only runs once both position and item id are confirmed.

## 6. Master Debater targeted tests

Deterministic reasoning trace (this repository has no automated Lua gameplay-test framework for
live-server `Action`/`CreatureEvent` mechanics — consistent with every prior pass in this engagement;
not fabricated as an executed test run):

1. **Correct item + correct position**: `d.pos == pos and d.itemId == itemId` true for exactly one
   `DOCUMENTS` entry → `doc` set → KV flag set (if not already) → achievement re-checked. ✓
2. **Wrong item + correct position**: for every entry, either `d.pos ~= pos` or `d.itemId ~= itemId`
   → `doc` stays `nil` → `return false` before any KV/message/achievement code runs. No credit, no
   reward path exists to fire (this mechanic was already discovery-only, no physical reward — see
   document 03 section 8), no side effect. ✓
3. **Correct item + wrong position**: `Action:position(...)` is only registered at the six exact
   `DOCUMENTS` positions to begin with, so this handler is never invoked for a position outside that
   set at all — the position filter is enforced by the engine's own registration, before this code
   ever runs. ✓ (structurally impossible to reach with a "wrong position", not merely checked)
4. **Repeat legitimate use is idempotent**: unchanged from the previous pass — `kv:get(doc.key)`
   checked before `kv:set`; a second correct Use sends the "already studied" message and returns
   without re-setting or re-triggering achievement side effects beyond `MasterDebaterCheckAchievement`'s
   own `hasAchievement` guard. ✓ (not modified this pass, re-verified still correct)
5. **No player cross-credit**: unchanged — `documentsKV(player)` is always scoped to the exact
   `player` parameter `onUse` received (the actual user), never broadcast. ✓ (not modified this pass,
   re-verified still correct)

## 7. Defect B root cause

The Scourge lever's own `config.specPos` — `(32712,32723,11)` to `(32738,32748,11)` — covers only the
central hall. `BossLever:register()` calls `zone:addArea(self.area.from, self.area.to)` using exactly
this rectangle, and `BossLever:getZone()` returns `Zone("boss." .. toKey(self.name))`, the same zone
key both empty-room watchers query via `zone:countPlayers()`. The previous pass's own OTBM evidence
(document 02, section E) proved the flanking wing halls extend physically outside this rectangle, and
no code in this encounter teleports players into a wing room — they walk there over the proven
corridor connections once a wing breaches. During a genuine, in-progress wing fight, every participant
is therefore legitimately outside the registered zone, and `zone:countPlayers()` legitimately returns
0 — not because the attempt was abandoned.

## 8. BossLever zone construction/specPos evidence

Confirmed directly in `data/libs/functions/boss_lever.lua`:
- `BossLever:register()`: `zone:addArea(self.area.from, self.area.to)` where `self.area = config.specPos`.
- `BossLever:getZone()`: `return Zone("boss." .. toKey(self.name))`.
- `BossLever:onUse()`: unconditionally schedules `self.emptyRoomEvent = addEvent(function(bossLever, zn) bossLever:watchEmptyRoom(zn) end, BossLever.emptyRoomCheckInterval, self, zone)` after a successful start, regardless of `createFunction` vs. plain `boss.position` usage.
- `BossLever:watchEmptyRoom(zone)`: `if zone:countPlayers() == 0 then self:handleEmptyRoom(zone) end`.
- `BossLever:handleEmptyRoom(zone)`: sets `bossAlive = false`, stops `emptyRoomEvent`/`timeoutEvent`, `zone:refresh()`, `zone:cleanRoom()`.

This generic watcher runs **independently** of `SecretLibraryInvasionRunTrackEvent`'s own event set —
it is scheduled directly by the framework via `self.emptyRoomEvent`, not through this quest's run-token
bookkeeping, so it could not previously be suppressed by anything in this quest's own code.

## 9. Why legitimate wing occupancy empties the central zone

Confirmed by construction, not merely asserted: the wing spawn code (`spawnWingTransactional` in
`movements_invasion_start.lua`) creates the wing boss/adds at `wing.spawnPositions` (currently `nil`,
unresolved — see document 03 section 17), and no function anywhere in this encounter calls
`player:teleportTo(...)` toward a wing room. The only player teleport in this whole file is the
lever's own `playerPositions[i].teleport = Position(32726, 32733, 11)` (into the central hall, at pull
time). Players reaching a wing therefore do so by walking there, physically leaving the
`(32712,32723,11)-(32738,32748,11)` zone — consistent with the previous pass's OTBM render showing the
flanking halls connected to, but geographically outside, the central hall's own bounds.

## 10. Final encounter-aware watcher design

Two independent fixes, chosen as the narrowest sound design per the task's option (A):

1. **Quest-specific watcher** (`local function watchEmptyRoom(token)` in
   `actions_the_scourge_of_oblivion.lua`): now skips its `zone:countPlayers() == 0` check entirely
   while `SecretLibraryInvasionRun.phase == "wing"`, always rescheduling itself regardless. Every other
   branch (token validity check, the 20s reschedule interval, the exact `normal_timeout` termination
   call) is byte-identical to before.
2. **Generic BossLever watcher**: overridden **per-instance only** — `function lever:watchEmptyRoom(zone) ... end`
   assigned directly on the `lever` table returned by `BossLever(config)`, before `lever:register()`.
   Lua's normal instance-before-metatable lookup order means this shadows the shared
   `BossLever:watchEmptyRoom` method for this one lever object only; every other `BossLever(...)`
   instance in the entire codebase (all of which construct their own separate instance table via the
   same `setmetatable(..., {__index = BossLever})` pattern in `boss_lever.lua`'s `__call` metamethod)
   is completely unaffected, and `data/libs/functions/boss_lever.lua` itself has zero lines changed.
   The override's body is the original `BossLever:watchEmptyRoom` logic verbatim, with one inserted
   guard: while `SecretLibraryInvasionRun.active and SecretLibraryInvasionRun.phase == "wing"`, it
   reschedules without evaluating `zone:countPlayers()` or calling `self:handleEmptyRoom(zone)`.
   `self:handleEmptyRoom` itself is **not** overridden — outside the wing-phase window, termination
   behavior (setting `bossAlive=false`, stopping events, `zone:refresh()`/`cleanRoom()`) is exactly the
   stock framework behavior, unchanged.

Both guards key off the exact same `SecretLibraryInvasionRun.phase == "wing"` condition, which is set
by `InvasionAdvanceWing` the instant a wing starts and only changed by the next
`InvasionAdvanceWing`/`InvasionActivateScourge` call (`movements_invasion_start.lua`) — meaning it
already covers the wing fight itself, the post-wing `WING_TRANSITION_DELAY` grace period, and every
central-wave round that follows before the next wing/Scourge transition, satisfying the task's
explicit requirement that the post-wing window (still represented as phase `"wing"`) also be
protected. During that trailing window players are legitimately back in the central hall for the next
raid wave anyway, so the guard is a safe no-op there, not a loosened check — it only ever changes
behavior during the genuinely-unsafe window where the zone is legitimately emptied by wing combat.

## 11. Proof neither generic nor quest-specific path false-aborts wing phase

- Quest-specific: `if SecretLibraryInvasionRun.phase ~= "wing" then ... end` wraps the entire
  `zone:countPlayers()`/`SecretLibraryInvasionRunTerminate` block; when phase is `"wing"` that whole
  block is skipped unconditionally, so no possible zone player count can trigger a terminate call
  during that window.
- Generic: the `SecretLibraryInvasionRun.active and SecretLibraryInvasionRun.phase == "wing"` branch
  in the instance override returns *before* the `zone:countPlayers() == 0` check is even evaluated,
  so `self:handleEmptyRoom(zone)` is structurally unreachable from this call while the guard holds.

## 12. Shared BossLever regression analysis

`data/libs/functions/boss_lever.lua` has zero lines changed this pass. Every other boss built on
`BossLever(...)` (Lokathmor, Gorzindel, Mazzinor, Ghulosh, Oberon, every non-Secret-Library boss lever
in the repository) constructs its own separate instance via the same constructor and never receives
this quest's `lever:watchEmptyRoom` assignment — their instances retain the shared metatable's
original `BossLever.watchEmptyRoom` unchanged, with byte-identical default empty-room-abort semantics
to before this pass. No shared-framework regression is possible because no shared-framework file was
touched.

## 13. Lifecycle tests (reasoning trace, same disclosure as section 6)

1. Active run, `phase="wing"`, central zone empty → both watchers reschedule without evaluating
   abandonment; `SecretLibraryInvasionRun.active` stays `true`, `bossAlive` stays `true`, no
   `terminate`/`handleEmptyRoom` call occurs. ✓ (section 11)
2. Post-wing transition, still `phase="wing"` (grace delay + central-wave rounds before the next
   `InvasionAdvanceWing`/`InvasionActivateScourge` call): same guard, same result — phase has not yet
   changed, so both watchers still skip. ✓ (section 10)
3. `phase="central_intro"` genuinely abandoned (all participants leave before round 1 even starts):
   guard condition is false (`phase ~= "wing"`), original abandonment logic runs unmodified in both
   watchers → legitimate `normal_timeout`/`handleEmptyRoom`. ✓
4. `phase="scourge"` genuinely abandoned: same as above, guard false, unmodified abandonment logic
   applies. ✓
5. Hard 26:20 timeout: entirely separate `addEvent` scheduled once in `createInvasionEncounter`
   (unchanged, untouched this pass), not gated by either watcher or by `phase` at all — still fires
   regardless of wing-phase suppression. ✓
6. `technical_abort` cooldown refund: unchanged code path (`SecretLibraryInvasionRunTerminate`'s
   `kind == "technical_abort"` branch, not modified this pass) — still refunds
   `player:setBossCooldown(..., 0)` for every participant. ✓
7. Stale callback/run-token safety: both watchers still open with
   `if not SecretLibraryInvasionRunIsCurrent(token) then return end` (quest-specific) or check
   `self.bossAlive`/operate only through the same `lever`/`bossAlive` state that
   `SecretLibraryInvasionRunTerminate`'s non-success branch already clears (generic) — a stale
   watcher from an ended run cannot terminate a new one, unchanged from before this pass. ✓
8. Ordinary unrelated `BossLever` behavior: unchanged — see section 12. ✓

## 14. Hard-timeout verification

Re-read `createInvasionEncounter` (unchanged lines): the `(26 * 60 + 20) * 1000` `addEvent` calling
`SecretLibraryInvasionRunTerminate(token, "normal_timeout", "26:20 encounter time limit exceeded")` is
untouched by this pass and shares no code path with either empty-room watcher.

## 15. Technical-abort/cooldown verification

`SecretLibraryInvasionRunTerminate`'s `kind == "technical_abort"` branch (untouched this pass) still
iterates `SecretLibraryInvasionRun.participants` and calls
`player:setBossCooldown("the scourge of oblivion (dormant)", 0)` for each — unaffected by the watcher
changes, which only ever gate whether a `normal_timeout`/`handleEmptyRoom` call happens, never the
refund logic inside an already-decided termination.

## 16. Stale callback/run-token verification

Both watchers retain their pre-existing guards (`SecretLibraryInvasionRunIsCurrent(token)` for the
quest-specific one; `self.bossAlive` — cleared by `SecretLibraryInvasionRunTerminate`'s non-success
branch and by `handleEmptyRoom` itself — for the generic one). The new phase check is an additional
`and`-ed condition on top of these, not a replacement, so no previously-safe stale-callback path was
weakened.

## 17. Central-wave regression check

No line inside `movements_invasion_start.lua`'s central-wave functions (`spawnCentralWave`,
`clearCentralWave`, `InvasionStartCentralWaveRound`, `InvasionAdvanceWing`, `InvasionActivateScourge`,
`InvasionWingBossDied`) was touched this pass. `SecretLibraryInvasionRun`'s `centralWaveGeneration`/
`centralWaveCreatureIds` fields and their cleanup in `SecretLibraryInvasionRunTerminate` are unchanged.
The 5-round structure, generation-guarded cleanup, and disclosed `CUSTOM_GLOBAL_LIKE` timing/roster/
position labels from document 03 all stand exactly as implemented.

## 18. Unresolved Master Debater items/conflict

Unchanged from document 03: Wooden Trunk, Ashes, and Remains of a Mummy remain physically
unidentified (not re-investigated this pass — out of this pass's scope, which was the item-id
verification defect, not new document discovery). The achievement gate still honestly requires all
nine and remains ungrantable to anyone until those three are resolved. Loose-pages-I remains an
unresolved `REFERENCE_CONFLICT`, not implemented.

## 19. Wing/vortex blockers

Unchanged from document 02/03: four wing rooms `PROVEN_PRESENT_CODE_WIRING_REQUIRED` at the room
level, exact boss-spawn/add-spawn tiles and the Spellstealer green/red teleport tiles remain
`NOT_PROVEN`. `InvasionMapReady()` was not touched this pass and still fails closed.

## 20. Gorzindel AID status

Unchanged, still `NOT_PROVEN`, not re-investigated this pass.

## 21. Validation commands/results

```
luaparser.ast.parse on both changed files -> OK, 0 failures
git diff --check -> clean (only benign core.autocrlf LF->CRLF working-tree notices)
python -m tools.canary_audit validate-schemas -> All Canary audit schemas are valid
python -m unittest discover -s tools/canary_audit/tests -t . -p "test_*.py" -> Ran 72 tests, OK (skipped=3, environment-only)
python -m tools.canary_audit scan --profile otservbr-global --fail-on error
  -> Findings: 823 (error: 4, warning: 484, info: 335) - IDENTICAL totals to both prior passes' baseline
  -> 4 blocking findings, all 4 the pre-existing baseline (item ids 2874, 3452, 6276, 12724) - zero new
```

Section 6/13's targeted coverage is a manual, reviewable reasoning trace against the actual code, not
an executed automated test suite — this repository has no Lua gameplay-test harness for live-server
`Action`/`BossLever` mechanics (unchanged limitation, disclosed identically in document 03 section 21).
No local server build was available to run startup/datapack smoke validation; not fabricated.

## 22. GitHub CI runs/results

The independent reviewer's own last-observed baseline at head `6a94e3d6e`: CI run 31917360505
SUCCESS, Repository Audit run 31917360373 FAILURE (the same four pre-existing baseline findings,
confirmed independently by this pass's own local audit-scan run in section 21). This pass's own push
triggers new runs against the new head; their exact run IDs/results were not available at
document-authoring time (written immediately before push) and are not fabricated here — the
independent reviewer can read them directly from PR #37 after the push in section 2.

## 23. New failures vs baseline failures

- **New regressions from this pass**: none observed. Local audit-scan totals are byte-identical
  before and after (section 21).
- **Pre-existing baseline**: the same 4 `action.duplicate-registration` findings (2874/3452/6276/12724),
  unrelated files, never touched by any Secret Library pass.
- **Environment/tooling limitations**: no Lua gameplay-test framework; no local server build; CI
  results for this exact push not observed at authoring time (section 22).

## 24. Remaining blockers

1. Wooden Trunk / Ashes / Remains of a Mummy document identities — unresolved.
2. Loose-pages-I — unresolved `REFERENCE_CONFLICT`.
3. Four wing rooms' exact boss/add spawn tiles and Spellstealer green/red teleport tiles — unresolved,
   `InvasionMapReady()` still fails closed.
4. Gorzindel's AID 4952 physical trigger — still unconfirmed against the downloaded artifact.
5. Central-wave exact roster/timing/count beyond the one reference-confirmed escalation point —
   disclosed approximation, unchanged this pass.

## 25. Final classification

**REPAIR_REQUIRED**

Rationale: both defects the independent review identified in this specific pass (Defect A: missing
item-id verification in position-scoped Master Debater actions; Defect B: two empty-room watchers
capable of false-aborting a legitimate wing fight) were fixed with narrow, evidence-backed changes
that do not touch the shared `boss_lever.lua` framework and do not weaken any existing safety
invariant (hard timeout, technical-abort refund, stale-callback safety, fail-closed map gate all
independently re-verified intact). Not promoted to `CODE_COMPLETE_MAP_BLOCKED` because the remaining
blockers (section 24) include genuine, unresolved physical/reference evidence gaps this executor could
not close from within this pass, not merely map-integration items structurally identical to a single
inherited blocker class. `InvasionMapReady()` remains untouched and still fails closed; no fake
completion path was introduced anywhere.
