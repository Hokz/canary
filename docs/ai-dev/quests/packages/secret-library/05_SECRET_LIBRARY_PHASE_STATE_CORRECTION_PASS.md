# Secret Library — Phase-State Correction Pass

Role note: written by the technical executor. Reports implementation and evidence only. Not an
independent validation, grants no approval, authorizes no merge.

This pass supersedes only document 04's phase/empty-room conclusion (the `phase == "wing"` guard was
correct for the wing-false-abort defect it targeted, but incomplete: it also silently suppressed
genuine central-hall abandonment during central-wave rounds 2-5, and left an unaddressed ordering gap
between the two independent watchers). Every other conclusion across documents 02-04 (OTBM provenance,
the 32-item matrix, Master Debater evidence/identity fix, central-wave design, remaining wing/Gorzindel
blockers) is unchanged and not repeated in full here.

## 1. Verified starting SHA/PR/base

- Fetched `origin/main` and `origin/ai-dev/secret-library-full-repair-v2` before any action.
- Expected starting head `f544cbf7b1bbea8e7ac24448ba146b2538556854` — **confirmed exact match** (local
  `HEAD`, remote branch head, `gh pr view 37 --json headRefOid` all agreed).
- Expected base `02ddd28b70a79116f02c44cb6f1096bdea8a9e6b` — **confirmed exact match**, unmoved.
- `gh pr view 37`: `state=OPEN`, `isDraft=true`, `mergeable=MERGEABLE` — confirmed before any action.
- Working tree was clean at start. No discrepancy found.

## 2. Exact files changed

One commit on `ai-dev/secret-library-full-repair-v2`, modifying:
- `data-otservbr-global/scripts/quests/the_secret_library_quest/library_area/actions_the_scourge_of_oblivion.lua`
- `data-otservbr-global/scripts/quests/the_secret_library_quest/library_area/movements_invasion_start.lua`
- this document.

No other file was touched. `data/libs/functions/boss_lever.lua` remains untouched (unchanged from
document 04).

## 3. Reproduced defect

Traced the exact phase-write sites before making any change:
- `InvasionAdvanceWing` (movements_invasion_start.lua): sets `phase = "wing"`.
- `InvasionWingBossDied`: schedules the delayed `InvasionStartCentralWaveRound` call after
  `WING_TRANSITION_DELAY` but did **not** change `phase`.
- `InvasionStartCentralWaveRound`: spawned central-hall combat but also did **not** change `phase`.

Confirmed: after a wing began, `phase` stayed `"wing"` through the wing fight, the 30s grace delay,
and the entire following 60s central-wave round, until the *next* `InvasionAdvanceWing` call
overwrote it again. Both empty-room watchers' `phase == "wing"` guard (document 04) therefore
suppressed abandonment detection during central-wave rounds 2-5 as well as the wing fight itself -
confirmed by direct code inspection, not merely asserted.

## 4. Old phase timeline

```
central_intro (createInvasionEncounter)
  -> [60s] -> InvasionStartCentralWaveRound(1)   -- phase still "central_intro", never set to anything else
  -> [60s] -> InvasionAdvanceWing(1)              -- phase = "wing"
       wing 1 fight                                -- phase = "wing"  (correctly guarded)
  -> InvasionWingBossDied                          -- phase = "wing"  (unchanged)
  -> [30s grace] -> InvasionStartCentralWaveRound(2)  -- phase = "wing"  (WRONG: central combat again, but still "wing")
       central wave round 2                        -- phase = "wing"  (WRONGLY guarded/suppressed)
  -> [60s] -> InvasionAdvanceWing(2)               -- phase = "wing"
       ... repeats through round 5 / Scourge ...
```

## 5. Final phase vocabulary

`idle | central_intro | central_wave | wing | wing_transition | scourge`, documented directly on the
`SecretLibraryInvasionRun.phase` field declaration in `actions_the_scourge_of_oblivion.lua`.

## 6. Exact transition table

| Event | Function (file) | Transition |
|---|---|---|
| Run starts | `createInvasionEncounter` (actions_the_scourge_of_oblivion.lua) | `idle -> central_intro` |
| Central wave round begins (1, or 2-5 after a wing) | `InvasionStartCentralWaveRound` (movements_invasion_start.lua) | `central_intro / wing_transition -> central_wave` |
| Wing begins | `InvasionAdvanceWing` (movements_invasion_start.lua) | `central_wave -> wing` |
| Wing boss dies | `InvasionWingBossDied` (movements_invasion_start.lua) | `wing -> wing_transition` |
| Final (5th) central wave ends | `InvasionActivateScourge` (movements_invasion_start.lua) | `central_wave -> scourge` |
| Run ends (any kind) | `SecretLibraryInvasionRunTerminate` (actions_the_scourge_of_oblivion.lua) | `* -> idle` |

All six transitions were implemented at the exact call sites listed - no transition is inferred or
implicit.

## 7. Shared empty-room policy

One local helper, `centralZoneMayLegitimatelyBeEmpty()` (`actions_the_scourge_of_oblivion.lua`, defined
once, used by both watchers via normal Lua upvalue closure - no duplication):

```lua
local function centralZoneMayLegitimatelyBeEmpty()
	local phase = SecretLibraryInvasionRun.phase
	return phase == "wing" or phase == "wing_transition"
end
```

## 8. Behavior of each watcher by phase

Both the quest-specific `local function watchEmptyRoom(token)` and the per-instance
`function lever:watchEmptyRoom(zone)` override call this exact same helper before evaluating
`zone:countPlayers() == 0`:

| Phase | `centralZoneMayLegitimatelyBeEmpty()` | Empty-central abandonment check |
|---|---|---|
| `central_intro` | false | **evaluated** - genuine abandonment terminates |
| `central_wave` | false | **evaluated** - genuine abandonment terminates |
| `wing` | true | **skipped** - reschedules unconditionally |
| `wing_transition` | true | **skipped** - reschedules unconditionally |
| `scourge` | false | **evaluated** - genuine abandonment terminates |

## 9. Central-wave abandonment proof

`InvasionStartCentralWaveRound` sets `phase = "central_wave"` as its first action after the
`SecretLibraryInvasionRunIsCurrent(token)` guard, before sending the wave message or spawning any
creature. From that exact statement onward, `centralZoneMayLegitimatelyBeEmpty()` returns `false` for
both watchers, so a genuinely empty central zone during any of rounds 1-5 (not just round 1) now
correctly reaches the `zone:countPlayers() == 0` check and terminates the run - closing exactly the
gap the reviewer identified.

## 10. Wing false-abort regression proof

`InvasionAdvanceWing` still sets `phase = "wing"` as before (unchanged line). Both watchers'
`centralZoneMayLegitimatelyBeEmpty()` still returns `true` for `"wing"`, so the original Defect B fix
(document 04) - a real wing fight emptying the central-only `specPos` zone must not false-abort - is
fully preserved, not regressed.

## 11. wing_transition safety

`InvasionWingBossDied` now sets `phase = "wing_transition"` immediately after marking
`wingDefeated[key] = true` and before scheduling the delayed `InvasionStartCentralWaveRound` call via
`WING_TRANSITION_DELAY` (30s, unchanged constant). `centralZoneMayLegitimatelyBeEmpty()` returns `true`
for `"wing_transition"`, so the entire 30s walk-back grace window remains protected, exactly as
required - players legitimately have not yet returned to the central hall during this window.

## 12. Round 1 and rounds 2-5 behavior

- **Round 1**: `createInvasionEncounter` leaves `phase = "central_intro"` for the initial 60s delay
  (players are expected to already be in the central hall at this point - the lever's own
  `playerPositions[i].teleport` places them there at pull time - so abandonment detection is correctly
  active here too, unchanged from document 04's original round-1 behavior). `InvasionStartCentralWaveRound(token, 1)`
  then sets `phase = "central_wave"`.
- **Rounds 2-5**: reached via `InvasionWingBossDied -> wing_transition -> (30s) -> InvasionStartCentralWaveRound -> central_wave`.
  Each round now correctly re-enables abandonment detection the instant it starts, per section 9 -
  this is the exact behavior that was missing before this pass.

## 13. Scourge behavior

`InvasionActivateScourge` still sets `phase = "scourge"` (unchanged line).
`centralZoneMayLegitimatelyBeEmpty()` returns `false` for `"scourge"`, so genuine abandonment during
the final boss fight still terminates normally - unaffected by this pass, re-verified intact.

## 14. Hard timeout

`createInvasionEncounter`'s `(26 * 60 + 20) * 1000` `addEvent` calling
`SecretLibraryInvasionRunTerminate(token, "normal_timeout", "26:20 encounter time limit exceeded")` is
untouched this pass, shares no code path with either watcher or with `phase`, and remains authoritative
regardless of phase.

## 15. Technical-abort/cooldown refund

`SecretLibraryInvasionRunTerminate`'s `kind == "technical_abort"` branch is untouched this pass -
still refunds `player:setBossCooldown("the scourge of oblivion (dormant)", 0)` for every participant,
unaffected by the phase/watcher changes (which only ever gate *whether* a `normal_timeout` fires from
empty-room detection, never the refund logic inside an already-decided termination, and
`technical_abort` is never reached through either watcher at all - it is only ever raised from
`spawnWingTransactional`'s bounded-retry exhaustion or `InvasionActivateScourge`'s
dormant-creature-not-found path).

## 16. Stale callbacks/token verification

Unchanged guards on both watchers (`SecretLibraryInvasionRunIsCurrent(token)` for the quest-specific
one; `self.bossAlive` for the generic one, itself cleared by `SecretLibraryInvasionRunTerminate`'s
non-success branch) remain in place, now combined with (not replaced by) the phase check. A stale
watcher from an ended run still cannot terminate a new one - the token/bossAlive checks run first and
independently of the phase logic.

## 17. Dual-watcher ordering/coherence analysis

Both watchers are independently scheduled 20s polls with no engine-guaranteed relative fire order (two
separate `addEvent` registrations, not a single synchronized timer). Both cases were traced explicitly:

- **Quest-specific watcher fires first** (unchanged from document 04): on genuine abandonment it calls
  `SecretLibraryInvasionRunTerminate`, whose non-success branch explicitly locates
  `BossLever["the scourge of oblivion (dormant)"]` and calls `stopEvent(bossLever.emptyRoomEvent)` -
  cancelling the generic watcher's pending scheduled call outright before it can ever fire for that
  tick. No double-fire possible.
- **Generic watcher fires first** (the concrete ordering defect this pass fixes): previously called
  `self:handleEmptyRoom(zone)` directly, which only resets `BossLever`/zone-level state (`bossAlive`,
  `emptyRoomEvent`/`timeoutEvent`, `zone:refresh()`/`cleanRoom()`) - it does **not** touch
  `SecretLibraryInvasionRun.active`, does **not** stop the quest run's own tracked events (the 26:20
  hard-timeout event, the quest-specific watcher's own next poll, central-wave/wing owned-creature
  cleanup), does **not** refund participant cooldown, and does **not** remove owned wing/central-wave/
  Scourge creatures. This is exactly the "`SecretLibraryInvasionRun.active=true` with BossLever already
  reset / orphaned central-wave monsters / half-terminated encounter" risk the task described. **Fixed**:
  the instance override now calls `SecretLibraryInvasionRunTerminate(token, "normal_timeout", ...)`
  instead (using `SecretLibraryInvasionRunCurrentToken()` to obtain the live token), which is a strict
  superset of what `handleEmptyRoom` did (it performs the identical `bossAlive`/event-stop/
  `zone:refresh+removePlayers+cleanRoom` sequence via the same `BossLever["the scourge of oblivion (dormant)"]`
  lookup, plus the full quest-level cleanup) - so regardless of which watcher observes the empty room
  first, exactly one coherent termination happens through the single authoritative
  `SecretLibraryInvasionRunTerminate` path, and the other watcher's pending call is cancelled by it.
  `self:handleEmptyRoom(zone)` is retained only as a defensive fallback for the case where
  `SecretLibraryInvasionRunCurrentToken()` returns `nil` while `bossAlive` is still `true` (a
  should-not-happen desync this pass does not otherwise rely on).

## 18. Master Debater no-regression + accurate return-false semantics

No code change to Master Debater this pass, per the task's explicit instruction. Documentation
precision acknowledged and recorded: `Actions::getAction(item)` selects a position-registered `Action`
before any UID/AID/item-id-registered one; when the selected Lua callback returns `false`,
`internalUseItem()` does **not** perform a second `getAction()` lookup - it proceeds only to built-in
handling (bed/container/read-text/etc.) for that item, not to a different Lua item `Action`. Document
04's phrasing ("falls through to that item's own default handling") is corrected here to mean built-in
engine handling, not another registered Lua action. The security invariant itself is unaffected and
re-confirmed correct: wrong item + correct document position still returns before any Master Debater
KV/message/achievement mutation runs (`actions_master_debater_documents.lua`'s `if not doc then return false end`
guard, unchanged this pass).

## 19. InvasionMapReady no-regression

`InvasionMapReady()` (movements_invasion_start.lua) has zero lines changed this pass. Still checks
every `WINGS` entry's `roomCenter`/`spawnPositions`/(Spellstealer's `greenTeleport`/`redTeleport`) for
`nil` and still refuses to start the encounter while any are missing - confirmed by direct diff
inspection (the only edits to this file are the two `phase = ...` assignments described in sections
9-11).

## 20. Validation commands/results

```
luaparser.ast.parse on both changed files -> OK, 0 failures
git diff --check -> clean (only benign core.autocrlf LF->CRLF working-tree notices)
python -m tools.canary_audit validate-schemas -> All Canary audit schemas are valid
python -m unittest discover -s tools/canary_audit/tests -t . -p "test_*.py" -> Ran 72 tests, OK (skipped=3, environment-only)
python -m tools.canary_audit scan --profile otservbr-global --fail-on error
  -> Findings: 823 (error: 4, warning: 484, info: 335) - IDENTICAL totals to every prior pass's baseline
  -> 4 blocking findings, all 4 the pre-existing baseline (item ids 2874, 3452, 6276, 12724) - zero new
```

Sections 9-17's targeted lifecycle proof is a manual, reviewable reasoning trace against the actual
code (exact function names, exact guard order, exact transition sites cited throughout), not an
executed automated test run - this repository has no Lua gameplay-test harness for live-server
`Action`/`BossLever`/`CreatureEvent` mechanics, an unchanged limitation disclosed identically in
documents 03 and 04. No local server build was available to run startup/datapack smoke validation;
not fabricated.

## 21. Exact CI runs/results

The independent reviewer's own last-observed baseline, at head `f544cbf7b`: CI run 31920661516
COMPLETED/SUCCESS, Repository Audit run 31920661420 COMPLETED/FAILURE (confirmed by the reviewer as
only the same four pre-existing baseline findings). This pass's own push triggers new runs against the
new head; their exact run IDs/results were not available at document-authoring time (written
immediately before push) and are not fabricated here - the independent reviewer can read them directly
from PR #37 after the push described in section 2.

## 22. New vs baseline failures

- **New regressions from this pass**: none observed. Local audit-scan totals are byte-identical before
  and after (section 20).
- **Pre-existing baseline**: the same 4 `action.duplicate-registration` findings
  (2874/3452/6276/12724), unrelated files, never touched by any Secret Library pass.
- **Environment/tooling limitations**: no Lua gameplay-test framework; no local server build; CI
  results for this exact push not observed at authoring time (section 21).

## 23. Remaining blockers

Unchanged from document 04 (out of scope this pass): Wooden Trunk / Ashes / Remains of a Mummy
document identities unresolved; loose-pages-I unresolved `REFERENCE_CONFLICT`; four wing rooms' exact
boss/add spawn tiles and Spellstealer green/red teleport tiles unresolved (`InvasionMapReady()` still
fails closed); Gorzindel's AID 4952 physical trigger unconfirmed; central-wave exact roster/timing
beyond the one reference-confirmed escalation point remains a disclosed approximation.

## 24. Final classification

**REPAIR_REQUIRED**

Rationale: the one lifecycle defect the independent review identified in this specific pass (the
`"wing"` phase label incorrectly also covering central-wave combat, plus the unaddressed
generic-watcher ordering gap) was fixed with an explicit 6-state phase model and a single shared
empty-room policy used identically by both watchers, plus routing the generic watcher's abandonment
path through the same authoritative `SecretLibraryInvasionRunTerminate` function the quest-specific
watcher already used - eliminating the half-terminated-encounter risk regardless of which watcher
fires first. `data/libs/functions/boss_lever.lua` remains untouched; no other boss lever in the
codebase is affected. Not promoted to `CODE_COMPLETE_MAP_BLOCKED` because the remaining blockers
(section 23) are genuine, unresolved physical/reference evidence gaps this executor could not close
from within this pass, not merely inherited map-integration items of the same single kind.
`InvasionMapReady()` remains untouched and still fails closed; no fake completion path was introduced
anywhere.
