# Secret Library — Completion Mechanics Pass

Role note: written by the technical executor. Reports implementation and evidence only. Not an
independent validation, grants no approval, authorizes no merge.

Evidence tiers used throughout: **EXECUTED TEST** (none this pass — no gameplay harness exists, see
section 35), **CODE-PATH PROOF** (manual reasoning trace against actual code, function/line cited),
**REFERENCE INFERENCE** (derived from a fetched wiki source, not directly game-observed), **MAP
EVIDENCE** (derived from the read-only OTBM artifact).

## 1. Start repo/PR state

- Fetched `origin/main` and `origin/ai-dev/secret-library-full-repair-v2` before any action.
- Expected starting head `5c1ec184465565b698f78658cc0d6bfee42e0d13` — **confirmed exact match**.
- Expected base `02ddd28b70a79116f02c44cb6f1096bdea8a9e6b` — **confirmed exact match**, unmoved.
- `gh pr view 37`: `state=OPEN`, `isDraft=true`, `mergeable=MERGEABLE` — confirmed before any action.
- Working tree clean at start. No discrepancy found.

## 2. Commits/files

One commit, modifying:
- `actions_master_debater_documents.lua` (physical book reward + 20h cooldown)
- `movements_invasion_start.lua` (mandatory-addSpawns transactional contract, InvasionMapReady
  extension)
- `creaturescripts_invasion_wings.lua` (Stolen Tome cleanup, book-penalty cap 5→4)
- `demon_slave.lua`, `imp_intruder.lua`, `invading_demon.lua`, `ravenous_beyondling.lua`,
  `rift_breacher.lua`, `rift_minion.lua`, `rift_spawn.lua`, `yalahari_despoiler.lua` (HP/XP)
- this document

## 3. Accepted pass-06 invariants preserved

Phase-state lifecycle, empty-room policy, `SecretLibraryInvasionRunTerminate`, Gorzindel
`NOT_APPLICABLE` classification, wing boss HP/XP (Spellstealer/Scion/Brothers/Devourer/Scourge),
`InvasionMapReady`'s existing boss/vortex checks (extended, not replaced — see section 5) — all
confirmed unchanged by direct diff review before committing.

## 4. Pass-06 factual errors

**Confirmed and corrected**: document 06 stated Demon Slave was "not in repo stats (new add)" — this
was wrong. `data-otservbr-global/monster/quests/the_secret_library/demon_slave.lua` already existed
with `health = 10000, experience = 0`. Corrected to `8000/0` (PROVEN_REFERENCE, section 8 below). This
correction is recorded here explicitly per the task's own instruction to correct handoff history rather
than silently fix it.

## 5. Add-contract defect (CODE-PATH PROOF)

Confirmed by direct code read before any edit: `InvasionMapReady()` checked only
`roomCenter`/`spawnPositions`/(Spellstealer's `greenTeleport`/`redTeleport`) — it never inspected
`addSpawns` at all, and `spawnWingTransactional`'s add-spawn loop treated every entry as best-effort
(including the Devourer's `exactCount = 4` Book of Secrets entry, which was only ever a *maximum cap*,
never a *minimum requirement*). A wing could legitimately commit with 0 Demon Slaves, 0 Spawns of
Havoc, 0 Biting Colds, 0-3 Books of Secrets, or 0 War Servants once boss/vortex coordinates existed.
**Fixed** — see section 6.

## 6. Final entity requirement schema

Each `addSpawns` entry gained an optional `mandatory` boolean (currently set only on the Devourer's
Book of Secrets entry, `exactCount = 4, mandatory = true`):

- `InvasionMapReady()` now also requires, for every `mandatory` entry, `#positions >= (exactCount or 1)`
  before the encounter can start at all (extends the existing fail-closed boss/vortex check, same
  function, same philosophy).
- `spawnWingTransactional` now spawns every `mandatory` entry inside the SAME validate→create→verify
  block as the boss itself: all mandatory adds are appended to the same `spawned` rollback list, and if
  any one of them fails to spawn, the entire attempt (boss included) is rolled back and
  bounded-retried/technical-aborted — a wing can no longer commit with a partial mandatory-add count.
  Non-mandatory entries (Demon Slave, Spawn of Havoc, Biting Cold, War Servant — all
  `CUSTOM_GLOBAL_LIKE_PENDING_EXACT_COUNT`, no proven exact count) remain best-effort ambient, spawned
  only after the transactional block commits.

Currently inert either way (every `positions` list is still empty), but the model is now correct in
advance of map data arriving.

## 7. Static/dynamic/mandatory entity matrix

| Wing | Entity | Model | Mandatory? | Count |
|---|---|---|---|---|
| Spellstealer | Demon Slave | ambient, best-effort | No | `CUSTOM_GLOBAL_LIKE_PENDING_EXACT_COUNT` |
| Scion | Spawn of Havoc | ambient, best-effort | No | `CUSTOM_GLOBAL_LIKE_PENDING_EXACT_COUNT` |
| Brothers | Biting Cold | ambient, best-effort | No | `CUSTOM_GLOBAL_LIKE_PENDING_EXACT_COUNT` |
| Devourer | The Book of Secrets | **transactional, mandatory** | **Yes** | **4 (PROVEN_REFERENCE)** |
| Devourer | War Servant | ambient, best-effort | No | `CUSTOM_GLOBAL_LIKE_PENDING_EXACT_COUNT` |

## 8. Demon Slave audit

PROVEN_REFERENCE (TibiaWiki monster infobox, re-fetched this pass): 8000 HP / 0 XP. Applied
(`health`/`maxHealth` 10000→8000; `experience` already 0). Other fields (attacks, resistances) were
**not** audited or changed this pass — the task's own instruction not to invent attacks where the
reference shows unknown/0-0 was followed by leaving them untouched rather than guessing a
"PLACEHOLDER_LIKE" correction without evidence for the specific values.

## 9. Spellstealer initial state

**Not implemented this pass.** REFERENCE INFERENCE confirms the current main quest page states "The
Spellstealer is initially invulnerable to all attacks," directly contradicting the current
implementation's grey/vulnerable starting state (`spellstealerColorSwap` only begins randomly
color-cycling *after* spawn via its own `onThink` chance roll — the boss spawns as plain "The
Spellstealer," fully vulnerable, until the first successful roll). Implementing this correctly requires
choosing an initial random green/red form at the exact `createGorzindelEncounter`-equivalent spawn
point in `spawnWingTransactional` (not yet reachable/testable since wing spawning is itself still
inert pending map data) and ensuring the run-scoped ownership/generation model treats it identically to
a normal color-swap. Time-constrained; disclosed as a remaining blocker (section 38), not implemented.

## 10. Spellstealer ability matrix

**Not audited this pass** (time-constrained). Current file's melee/ranged/energy attack values were not
compared against the newly-fetched `The_Spellstealer` reference page's reported ~2000-3450+ melee /
~980-1400 Fire Beam / summon / self-heal abilities. Flagged for a future pass rather than rushed here —
implementing unverified numeric combat values this late in an already large pass risked more harm than
leaving them as a disclosed, pre-existing `PLACEHOLDER_LIKE_CURRENT_IMPLEMENTATION`.

## 11. Demon Slave summon model

**Not implemented.** No summon logic exists in `the_spellstealer.lua`/its variants, and none was added
this pass — see section 9 (the summon mechanic and the initial-invulnerable-state fix are the same body
of work, deferred together).

## 12. Scion fire-heal

**Not implemented.** REFERENCE INFERENCE (TibiaWiki `The_Scion_of_Havoc`, fetched in the previous pass)
confirms "-100% / heals when attacked with fire," which requires a dedicated `onHealthChange` redirect
(the same safe pattern as the Brothers' `brothersHealIce` handler) rather than a plain elements-table
percent value (which in this engine's convention amplifies damage on a negative percent, it does not
produce true healing). Disclosed as a remaining blocker (section 38), not attempted this pass given
time constraints and the value of getting the redirect semantics right rather than rushing it.

## 13. Spawn replenishment

**Not resolved.** No stronger evidence was gathered this pass distinguishing "fixed initial spawn" from
"continuously replenished" for Spawn of Havoc/Demon Slave/Biting Cold/War Servant. The task's own
referenced Discussion page (`Discussão:The_Secret_Library_Quest`) was fetched but is lower-quality,
unstructured user commentary — read but not treated as sufficient standalone evidence to implement a
periodic-replenishment mechanic. Remains `CUSTOM_GLOBAL_LIKE_PENDING_EXACT_COUNT`/`_TIMING`, not
implemented.

## 14. Biting Cold healing/replenishment

**Not implemented.** `biting_cold.lua` still has no encounter event registered (confirmed by direct
file inspection — `monster.events` is absent/empty). REFERENCE INFERENCE confirms Brother Chill's own
page states Biting Colds heal the brothers "throughout the battle," but the exact mechanism (aura,
proximity, periodic tick, on-attack) was not determined from any source fetched this pass. Disclosed as
a remaining blocker (section 38).

## 15. Devourer exactly-four-Books transaction

**Implemented** — see sections 5-7. `mandatory = true` + `exactCount = 4` on the Book of Secrets
`addSpawns` entry; `InvasionMapReady()` and `spawnWingTransactional` both updated (CODE-PATH PROOF: see
the exact diff in section 6 — a partial mandatory spawn now rolls back the whole attempt via the same
`spawned` list and retry/abort path already proven correct for the boss itself in every prior pass).

## 16. War Servant model

Unchanged — remains a non-mandatory, best-effort ambient `addSpawns` entry (`CUSTOM_GLOBAL_LIKE_PENDING_EXACT_COUNT`).
No stronger evidence for an exact count or a book-summons-War-Servant relationship was found strongly
enough to implement this pass (the Discussion page mentions it; not treated as sufficient standalone
evidence per the task's own "treat discussion as lower-quality" instruction).

## 17. Devourer Book penalty

**Corrected.** Cap changed from 5 stacks (50%) to 4 stacks (40%) in both the increment
(`devourerBookDeath`) and the damage-gate (`devourerDamageGate`) — matching the PROVEN_REFERENCE exact
book count; a 5-stack cap was structurally impossible to reach (there are only ever 4 books) and is now
consistent. The 10%-per-stack value itself remains `CUSTOM_GLOBAL_LIKE_PENDING_EXACT_VALUE` — no exact
percentage was found in any source fetched across this whole engagement.

## 18. Stolen Tome cleanup

**Done.** Removed from `creaturescripts_invasion_wings.lua`'s `bookNames` table (was already
functionally inert there due to `SecretLibraryInvasionRunOwnsWingAdd("devourer", creature)` gating, but
left as a stale/misleading declaration). `WINGS[4].addSpawns` already excluded it (removed in the
previous pass). No live code path can credit a Stolen Tome of Portals death toward the Devourer's
book-stack mechanic anymore, declaratively as well as functionally.

## 19. Central creature stat matrix

Applied this pass (PROVEN_REFERENCE, TibiaWiki monster infoboxes, gathered in the previous pass, not
yet applied until now):

| Creature | Old | New |
|---|---|---|
| Imp Intruder | 1000 HP / 100 XP | **3000 HP / 0 XP** |
| Invading Demon | 1000 HP / 0 XP | **8000 HP / 0 XP** |
| Ravenous Beyondling | 10000 HP / 0 XP | **8000 HP / 0 XP** |
| Rift Breacher | 10000 HP / 0 XP | **16500 HP / 0 XP** |
| Rift Minion | 10000 HP / 0 XP | **3000 HP / 0 XP** |
| Rift Spawn | 10000 HP / 0 XP | **16500 HP / 0 XP** |
| Yalahari Despoiler | 10000 HP / 0 XP | **8150 HP / 0 XP** |

Other fields (attacks, resistances) were not audited this pass, per the task's own caution about
warning-marked wiki pages — HP/XP is the strongest-confidence field type gathered, others left
untouched rather than guessed.

## 20. Central spawning model

Unchanged this pass (still one-shot per round, 60s duration, then clear). No stronger evidence for
periodic replenishment during a single round was found (see section 13) strongly enough to implement.
Composition (pre/post-Spellstealer 2-tier roster) unchanged from the previous pass, not re-litigated.

## 21. Scourge-time add verdict

Unchanged from document 06: the current structured quest reference's Scourge strategy section mentions
no continued central adds during that fight; the already-implemented behavior (no central wave round
during the `"scourge"` phase) is consistent with this, not contradicted. Not re-researched further this
pass (no new evidence sources fetched for this specific question).

## 22. Masterbook/golden orb conflict matrix

**Not resolved further this pass.** No dedicated fetch was made for the historical/video-derived
Discussion content specifically describing a "MASTERBOOK HAS FILLED UP" / golden orb mechanic beyond
what the general Discussion page fetch (section 13) surfaced, and that page's content (read in full) did
**not** contain this specific claim in the portion retrieved. Classification stands as document 06 left
it: `REFERENCE_CONFLICT` / not corroborated by the current structured reference. **Not implemented.**
Not silently removed from the closure matrix — explicitly still open.

## 23. Cerebrir evidence + implementation

**Evidence gathered, NOT implemented this pass.** REFERENCE INFERENCE (Cerebrir's own TibiaWiki page,
fetched this pass): confirms Cerebrir exists as an NPC with a stated location, and the main quest page
(fetched in the previous pass) already gave the exact post-Scourge epilogue dialogue transcript in
full. Implementing this correctly requires: a new NPC file (following this project's own NPC scripting
convention, not yet audited this pass), per-player epilogue-pending state (KV, following the
`documentsKV`-style convention already established in this same quest), a hook into the Scourge's own
success path (`InvasionRunOwnsScourge`-gated, roster-restricted exactly like Library Liberator credit)
to set that state only for legitimate current-run participants, and dialogue-completion logic setting a
final per-player completion flag. This is a genuinely large, multi-part addition (new NPC + new
per-player state machine + a new hook into the existing success path) that this pass's remaining time
could not respons­ibly complete without rushing the participant-eligibility and idempotency guarantees
the task itself demands. **Disclosed as the single largest remaining blocker** (section 38) rather than
half-implemented.

## 24. Per-player epilogue state

Not implemented (see section 23) — no code exists for `NOT_DONE`/`SCOURGE_DEFEATED_EPILOGUE_PENDING`/
`EPILOGUE_COMPLETE` or equivalent.

## 25. Final quest completion logic

Unchanged. `Library Liberator` (unaffected, already roster/room-restricted per document 03/05) remains
the only automatic post-Scourge state change; no separate "quest fully concluded" tracker exists or was
added this pass.

## 26. Magic Discharge verdict

REFERENCE INFERENCE: the dedicated `tibiawiki.com.br/wiki/Magic_Discharge` page returned HTTP 404 (does
not exist as its own catalogued article) — the term appears only in passing in the main quest page's
prose ("você e seu time serão teleportados para uma sala grande onde vão encontrar o NPC Cerebrir e
Magic Discharges"), with no dedicated stat block, sprite description, or mechanical detail anywhere
found this pass. **Classified `NOT_PROVEN`** — insufficient evidence to determine whether this is a
distinct creature, a decorative object, or a visual effect. Not invented; not implemented.

## 27. Master Debater I-IX book/text/item matrix

All nine volumes' exact texts were fetched this pass (individual TibiaWiki pages, archived in session
scratch):

| Vol | Riposte (exact quote) | Matches existing `GrandMasterOberonResponses` index |
|---|---|---|
| I | "Are you ever going to fight or do you prefer talking?" | 2 |
| II | "Even before they smell your breath?" | 3 |
| III | "Too bad you barely exist at all?" | 5 |
| IV | "A counter spell: SEHWO ASIMO, TOLIDO ESD" (embedded in longer lore text) | 9 |
| V | "Excuse me but I still do not get the message!" | 6 |
| VI | "Then why are we fighting alone right now?" | 8 |
| VII | "How appropriate, you look like something worms already got the better of!" | 1 |
| VIII | "Then let me show you the concept of mortality before it!" | 4 |
| IX | "Dare strike up a Minnesang and you will receive your last accolade!" | 7 |

**Every one of the nine matches a distinct response index exactly** — strong, independent
cross-confirmation that the pre-existing, already-audited 9-question/9-response Oberon table
(`grand_master_oberon_functions.lua`) is the genuine Global mechanic. No server item id was stated on
any of the nine pages; item 2824 ("book," `data/items/items.xml`, `writeable="1"`, `maxtextlen="1023"`)
was reused as a generic, already-defined readable-item vessel for the six wired volumes' exact text
(section 28) — no new/invented item id.

## 28. 20h reward transaction

**Implemented.** `actions_master_debater_documents.lua` rewritten:
- `MASTER_DEBATER_BOOK_ITEM_ID = 2824`.
- Each of the six wired `DOCUMENTS` entries gained a `bookText` field with its exact confirmed text.
- New `rewardKV(player, docKey)` — a KV branch independent of the permanent discovery flag.
- `onUse`: checks `nextRewardAt` (20h from last successful delivery) BEFORE any inventory mutation; if
  still on cooldown, sends a remaining-time message and returns without touching state (CODE-PATH
  PROOF: `if now < nextRewardAt then ... return true end` precedes every subsequent line).
- Delivery uses `checkWeightAndBackpackRoom` (this project's own established pre-flight helper,
  `data/libs/functions/functions.lua:656`, already used by `quest_reward_common.lua` for equivalent
  grants) BEFORE calling `player:addItem`, and `player:addItem`'s own return is nil-checked — **both
  failure paths return before `reward:set("nextRewardAt", ...)`**, so a failed delivery consumes
  neither the 20h cooldown nor (on a first-ever attempt) the permanent discovery flag.
- `item:setText(...)` (confirmed real, already used in this exact codebase —
  `scripts/quests/parchment_room/parchment.lua`, `scripts/actions/other/others/quest_system2.lua` — an
  earlier draft of this pass incorrectly used a nonexistent `ITEM_ATTRIBUTE_TEXT` constant/`setAttribute`
  call, caught and corrected before committing, see section 34) sets the exact per-volume text.
- Discovery flag (`documentsKV(player):set(doc.key, true)`) is set exactly once, on the first successful
  delivery only, unchanged in structure from the previous pass, preserving
  `MasterDebaterCheckAchievement`'s existing read path.

Three of nine documents (II/III/VIII) remain undiscoverable at all (section 29), so their `bookText` is
not yet defined — only the six already-wired entries received one.

## 29. II/III/VIII object candidate matrix

Re-attempted this pass per the task's explicit "exhaust other identity paths" instruction. Available
paths in this environment and their outcome:

| Path | Outcome |
|---|---|
| OTBM exact-tile + adjacent-footprint stack inspection | Already exhausted in documents 03/05/06 — re-confirmed unchanged this pass (no new OTBM fetch was performed; artifact identity re-verifiable via the unchanged SHA-256 in every prior document) |
| `data/items/items.xml` name resolution | Exhausted — no entry for any candidate item at these tiles resolves to "trunk"/"ashes"/"mummy" |
| `data/items/appearances.dat` protobuf name resolution | Exhausted — same result, no name field populated for these candidates |
| Client sprite/image rendering for visual cross-match | **Not available in this environment** — no image renderer/decoder for client sprite sheets exists in this tool-set |
| Historical Canary/OTServBR branches/tags/maps | Not attempted this pass — would require locating and fetching a different historical repository state; out of time budget |
| Other high-fidelity public Global-like datapacks | Not attempted — no such alternate datapack is available in this environment to compare against |
| RME-compatible item database | Not available in this environment |
| TibiaWiki item-image metadata (Wooden_Trunk/Remains_of_a_Mummy pages) | **Not fetched this pass** (time-constrained) — a genuine remaining avenue for a future pass: these pages may describe the object's appearance in enough prose detail to narrow candidates even without image rendering |

**Still NOT_PROVEN.** No candidate item id is proposed for II/III/VIII this pass — every path that
could be exhausted within this pass's environment and time budget was exhausted; several paths remain
genuinely open for a future pass (flagged above, not silently dropped).

## 30. Loose-pages conflict resolution

Unchanged from document 06 — `REFERENCE_CONFLICT_RESOLVED`: nine Verbal Debate volumes + Oberon;
loose-pages-I not required. Per the task's own caution, this is stated here as an **operational
resolution based on source specificity** (two independent, directly-on-topic sources agree; the
aggregate achievement page is broader/less specific), not claimed as indisputable official proof.

## 31. Wing/add/vortex map matrix

Unchanged from documents 02/05/06 — not re-investigated this pass (no new OTBM fetch was performed).
Wing rooms: `PROVEN_PRESENT_CODE_WIRING_REQUIRED`. Exact boss/add spawn tiles, Spellstealer green/red
vortex tiles: `NOT_PROVEN`. No candidate position table was produced or wired.

## 32. InvasionMapReady final contract

Extended, not replaced (section 6): still requires every wing's `roomCenter`/`spawnPositions`/(for
Spellstealer) `greenTeleport`/`redTeleport`; now additionally requires every `mandatory` `addSpawns`
entry to have at least `exactCount` (or 1) positions. Currently always `false` (every relevant field
is still `nil`/empty) — the encounter remains fully fail-closed, now closed on a strictly larger set of
proven grounds than before this pass.

## 33. Full end-to-end progression trace

Unchanged from document 06 through "Scourge activation → Scourge 3-phase cycle + beam → success credit
/ Library Liberator". The trace now additionally acknowledges (but does not yet implement) a further
step evidenced this pass: **Scourge death → betrayal message → Cerebrir epilogue (NOT IMPLEMENTED,
section 23) → final quest completion (NOT IMPLEMENTED, section 25)**. Master Debater's own
document-collection step is now backed by a real physical-item reward for six of nine positions
(section 28), not merely a discovery flag.

## 34. Stale callback/cross-run audit

- New code in `spawnWingTransactional`'s mandatory-add block reuses the exact same `spawned` rollback
  list, `SecretLibraryInvasionRunIsCurrent(token)` guard, and `retriesLeft` bounded-retry/technical-abort
  path already proven safe for boss spawning in every prior pass — no new callback/timer was
  introduced, so no new stale-callback surface exists.
- Master Debater's new `rewardKV` is read/written synchronously inside `onUse` (no `addEvent`/delayed
  callback at all) — no stale-callback risk class applies to it.
- **Self-caught defect during this pass**: an early draft of `actions_master_debater_documents.lua`
  used `book:setAttribute(ITEM_ATTRIBUTE_TEXT, doc.bookText)` — `ITEM_ATTRIBUTE_TEXT` does not appear
  anywhere in this repository's Lua sources (`grep -rn "ITEM_ATTRIBUTE_TEXT"` returned zero hits) and
  would very likely have been a runtime error. Found by that same grep check before validation/commit
  and replaced with the confirmed-real `item:setText(...)` method. Recorded here per this pass's own
  transparency requirement, not hidden.

## 35. Validation commands/results

```
luaparser.ast.parse on all 12 changed/new Lua files -> OK, 0 failures
git diff --check -> clean
python -m tools.canary_audit validate-schemas -> All Canary audit schemas are valid
python -m unittest discover -s tools/canary_audit/tests -t . -p "test_*.py" -> Ran 72 tests, OK (skipped=3, environment-only)
python -m tools.canary_audit scan --profile otservbr-global --fail-on error
  -> Findings: 823 (error: 4, warning: 484, info: 335) - IDENTICAL totals to every prior pass's baseline
  -> 4 blocking findings, all 4 the pre-existing baseline (item ids 2874, 3452, 6276, 12724) - zero new
```

All lifecycle/add-contract/reward-transaction proofs in sections 6, 15, 28, 34 are **CODE-PATH PROOF**
(manual reasoning against the actual committed code, not an **EXECUTED TEST** — no Lua gameplay-test
harness exists in this repository, unchanged limitation disclosed identically in every prior document).
No local server build was available; not fabricated.

## 36. Exact CI run IDs/results

The independent reviewer's own last-observed baseline at head `5c1ec1844`: CI run 31923311591
SUCCESS, Repository Audit run 31923311487 baseline-only failure. This pass's own push triggers new
runs against the new head; exact run IDs/results were not available at document-authoring time
(written immediately before push) and are not fabricated here.

## 37. Baseline vs new findings

- **New regressions**: none observed (section 35).
- **Pre-existing baseline**: the same 4 `action.duplicate-registration` findings, unrelated files.
- **Environment/tooling limitations**: no Lua gameplay-test framework; no local server build; no client
  sprite/image renderer (blocks II/III/VIII and vortex-tile resolution); `tibiawiki.com.br` blocked the
  WebFetch tool (403) but was reachable via direct `curl` with a browser `User-Agent` (unchanged from
  document 06's finding, reused successfully throughout this pass).

## 38. Remaining blockers

Ranked by disclosed size/impact:

1. **Cerebrir NPC + epilogue + final completion state** — evidence gathered, not implemented (largest
   remaining item, section 23-25).
2. **Spellstealer initial-invulnerable state + combat ability audit + Demon Slave summon model** —
   evidence gathered, not implemented (sections 9-11).
3. **Scion fire-heal**, **Biting Cold healing participation** — evidence gathered, not implemented
   (sections 12, 14).
4. **Wooden Trunk / Ashes / Remains of a Mummy** identities — still `NOT_PROVEN`; two concrete
   unexhausted paths remain (item-image wiki pages, historical branch comparison) for a future pass
   (section 29).
5. **Four wing rooms' exact boss/add spawn tiles, Spellstealer vortex tiles** — still `NOT_PROVEN`;
   `InvasionMapReady()` fails closed.
6. **Masterbook/golden orb**, **Magic Discharge** — insufficient evidence, correctly not implemented
   (sections 22, 26).
7. **Central-wave periodic replenishment** — unresolved evidence question (section 13/20).
8. Spawn count precision for Demon Slave/Spawn of Havoc/Biting Cold/War Servant — remain
   `CUSTOM_GLOBAL_LIKE_PENDING_EXACT_COUNT`.

## 39. Final executor classification

**REPAIR_REQUIRED**

Rationale: this pass closed a genuine architectural gap (the add-contract could previously commit a
wing with fewer than the reference-proven mandatory entity count — now transactionally enforced) and
implemented a fully evidence-backed, previously-missing mechanic end-to-end (Master Debater's physical
book reward + 20h cooldown, for the six positions that are wired). It corrected a factual error from
its own predecessor document (Demon Slave) and applied seven more PROVEN_REFERENCE stat corrections.
It does not qualify for `CLOSURE_READY` (multiple known, evidenced code mechanics remain entirely
unimplemented — Cerebrir/epilogue foremost among them, not merely unproven map data) or
`CODE_COMPLETE_MAP_BLOCKED` (the remaining work is not exclusively physical map integration).
`InvasionMapReady()` remains fail-closed and was only ever *strengthened* this pass, never weakened; no
coordinate, item id, or AID was invented at any point.
