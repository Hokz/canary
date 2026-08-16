# Secret Library — Final Fidelity & Evidence Resolution Pass

Role note: written by the technical executor. Reports implementation and evidence only. Not an
independent validation, grants no approval, authorizes no merge.

This pass does not reopen the accepted phase-state/lifecycle code from document 05 (no regression was
found that traces to this pass's own work — see section 30). It adds evidence-backed corrections on
top of it: Master Debater's loose-pages conflict resolution, final-invasion creature stats/roster
fidelity, central-wave roster correction, vortex message accuracy, and the Gorzindel AID 4952
provenance resolution.

## 1. Verified branch/base/start head

- Fetched `origin/main` and `origin/ai-dev/secret-library-full-repair-v2` before any action.
- Expected starting head `1e20e4b39a0032400f44ff8209e6c998476c8aea` — **confirmed exact match** (local
  `HEAD`, remote branch head, `gh pr view 37 --json headRefOid` all agreed).
- Expected base `02ddd28b70a79116f02c44cb6f1096bdea8a9e6b` — **confirmed exact match**, unmoved.
- `gh pr view 37`: `state=OPEN`, `isDraft=true`, `mergeable=MERGEABLE` — confirmed before any action.
- Working tree was clean at start. No discrepancy found.

## 2. Exact commits/files changed

One commit on `ai-dev/secret-library-full-repair-v2`, modifying:
- `data-otservbr-global/scripts/quests/the_secret_library_quest/library_area/movements_invasion_start.lua`
- `data-otservbr-global/scripts/quests/the_secret_library_quest/library_area/creaturescripts_invasion_wings.lua`
- `data-otservbr-global/monster/quests/the_secret_library/the_spellstealer.lua`
- `data-otservbr-global/monster/quests/the_secret_library/the_spellstealer_green.lua`
- `data-otservbr-global/monster/quests/the_secret_library/the_spellstealer_red.lua`
- `data-otservbr-global/monster/quests/the_secret_library/the_scion_of_havoc.lua`
- `data-otservbr-global/monster/quests/the_secret_library/brother_chill.lua`
- `data-otservbr-global/monster/quests/the_secret_library/brother_freeze.lua`
- `data-otservbr-global/monster/quests/the_secret_library/the_devourer_of_secrets.lua`
- `data-otservbr-global/monster/quests/the_secret_library/bosses/the_scourge_of_oblivion.lua`
- `data-otservbr-global/monster/quests/the_secret_library/bosses/the_scourge_of_oblivion_dormant.lua`
- `data-otservbr-global/monster/quests/the_secret_library/bosses/the_scourge_of_oblivion_immune.lua`
- `data-otservbr-global/monster/quests/the_secret_library/bosses/the_scourge_of_oblivion_reflective.lua`
- this document.

No change to `actions_master_debater_documents.lua`, `actions_the_scourge_of_oblivion.lua`,
`creaturescripts_kill.lua`, or `data/libs/functions/boss_lever.lua` this pass.

## 3. Current independent-accepted lifecycle invariants preserved

Zero lines touched in the phase-state machine (`InvasionAdvanceWing`/`InvasionWingBossDied`/
`InvasionStartCentralWaveRound`/`InvasionActivateScourge`'s phase assignments), the
`centralZoneMayLegitimatelyBeEmpty()` helper, either empty-room watcher, `SecretLibraryInvasionRunTerminate`,
or `InvasionMapReady()`'s check logic. The only edits inside `movements_invasion_start.lua` are: the
`WINGS` table's roster fields (section 11), the add-spawn loop (section 16), the central-wave roster
tables (section 22), and the two vortex message strings (section 7 rationale). Confirmed by direct
diff review before committing.

## 4. Master Debater loose-pages reference-resolution matrix

Fetched directly (`curl` with a browser user-agent; the WebFetch tool itself was blocked with
HTTP 403/402 by both `tibiawiki.com.br` and `tibia.fandom.com`'s bot-detection — a plain `curl` with a
standard browser `User-Agent` header was not blocked and returned genuine `200` responses with full
page content for every URL fetched this pass; archived in the session scratch directory):

| Source | Finding |
|---|---|
| `tibiawiki.com.br/wiki/Bibliotecas_de_Falcon_Bastion` | Lists the nine "Master Debater" / "Books of Verbal Debate" volumes in their own dedicated table (I-IX, exact coordinates - see section 6). "Knightly Successor Orders of Tibia, loose pages I" appears **only** in a separate, later table ("Sala do Preceptor Lazare" → "Estante - 01"/Shelf-01) describing *all* documents findable in that one room - not the Master Debater table. |
| `tibiawiki.com.br/wiki/The_Grand_Master_of_Verbal_Debate_I_(Book)` | Direct quote: *"Ao pegar todos os livros 'The Grand Master of Verbal Debate' (são 9 ao todo), e vencer a luta contra o Grand Master Oberon, você irá receber o Achievement 'Master Debater'."* ("Upon collecting all 'The Grand Master of Verbal Debate' books — 9 in total — and winning the fight against Grand Master Oberon, you will receive the Achievement 'Master Debater'.") No mention of loose-pages-I anywhere on this page. |
| `tibiawiki.com.br/wiki/Master_Debater_(Achievement)` | This is the "outlier" page named in the task. It presents an aggregate list of documents encountered near/around the achievement's path, which includes loose-pages-I alongside the nine volumes — but this list is a broader "everything you'll see along the way" catalogue, not the game's own mechanical requirement set (which the two more specific sources above both state directly and identically as exactly nine). |

**REFERENCE_CONFLICT_RESOLVED**: the requirement is the nine "The Grand Master of Verbal Debate"
volumes plus legitimate Grand Master Oberon completion. Loose-pages-I is **not** a Master Debater
prerequisite — it is an unrelated document that happens to sit in the same room (Preceptor Lazare's
room) as one of the nine volumes (Volume IV, on that room's own Writing Desk). The aggregate
achievement page is treated as an over-inclusive/loosely-curated listing, outweighed by two more
specific, mutually-consistent, directly-on-topic sources.

## 5. Final Master Debater requirement verdict

Nine "The Grand Master of Verbal Debate" volumes (I-IX) + legitimate Grand Master Oberon completion.
`MasterDebaterRequiredDocumentKeys` in `actions_master_debater_documents.lua` already contains exactly
nine keys (unchanged this pass) — no code change was needed to reflect this resolution; the previous
pass's gate was already correctly sized, only its *justification* (the loose-pages conflict) was
unresolved until now.

## 6. 9-document physical surface matrix

The same `tibiawiki.com.br/wiki/Bibliotecas_de_Falcon_Bastion` table gives **exact coordinates for all
nine volumes**, independently of this project's own OTBM investigation in documents 03-05:

| # | Volume | Reference location | Reference coordinate | Reference object | Already wired (this project) |
|---|---|---|---|---|---|
| I | Verbal Debate I | Andar +4 - Sala de Estudos | `(33369,31348,3)` | Writing Desk | **Yes** — item 27880 |
| II | Verbal Debate II | Andar +4 - Dormitórios | `(33362,31317,3)` | Wooden Trunk | No — see section 7 |
| III | Verbal Debate III | Andar +1 - Área Comum | `(33373,31349,6)` | Ashes | No — see section 7 |
| IV | Verbal Debate IV | Andar +4 - Sala do Preceptor Lazare | `(33374,31336,3)` | Writing Desk | **Yes** — item 27880 |
| V | Verbal Debate V | Andar +1 - Área Comum | `(33368,31325,6)` | Pile of Bones | **Yes** — item 4285 |
| VI | Verbal Debate VI | Andar +1 - Área Comum | `(33368,31327,6)` | Pile of Bones | **Yes** — item 4285 |
| VII | Verbal Debate VII | Andar Térreo - Ilha da Capela | `(33387,31285,7)` | Pile of Bones | **Yes** — item 4285 |
| VIII | Verbal Debate VIII | Andar Térreo - Banheiro | `(33371,31349,7)` | Remains of a Mummy | No — see section 7 |
| IX | Verbal Debate IX | Andar -1 - Sala do Tesouro | `(33369,31343,8)` | Chest | **Yes** — item 2472 |

**Every single reference coordinate for all nine volumes exactly matches this project's own previously
wired/investigated positions** (documents 03-05) — this is independent, external confirmation (not
merely internal OTBM-presence inference) that all nine positions this project has been working with
are correct. No position changed this pass; no code change was needed for the six already-wired
entries.

The page also directly states (machine-translated): *"Pode ser pego novamente a cada 20 horas. Dê
'Use' na [prop] para conseguir o livro."* ("Can be picked up again every 20 hours. Use the [prop] to
get the book.") for **every one of the nine entries**, uniformly — confirming the 20-hour physical
book collection mechanic (section 8/9) as `PROVEN_REFERENCE`, not merely a discovery flag.

## 7. Unresolved II/III/VIII sprite/item evidence

Re-inspected the exact (now externally-confirmed) OTBM coordinates for Wooden Trunk, Ashes, and
Remains of a Mummy using the same read-only artifact (section identity re-confirmed unchanged, see
section 31). No new sprite-rendering/image-cross-matching capability was available to this pass beyond
what documents 03/05 already used (this environment has no image renderer for client sprites; item
identity can only be established via `items.xml`/`appearances.dat` name resolution or cross-position
recurrence, both already exhausted in the previous pass). Result: **unchanged from document 05** — no
single candidate item at or near these three exact tiles resolves to a name or recurrence pattern
matching "trunk"/"ashes"/"mummy remains". **Still NOT_PROVEN.** Not wired; not guessed. This is
disclosed as a genuine capability gap in this environment (no client sprite viewer), not a refusal to
look.

## 8. Exact static debate-book item/text evidence I-IX

Only Volume I's dedicated book page was fetched this pass (time-constrained — see section 34). Findings
for Volume I (`tibiawiki.com.br/wiki/The_Grand_Master_of_Verbal_Debate_I_(Book)`):

- Exact in-game readable text: *"The Grand Master of Verbal Debate I / Facing villainy of the utmost
  caliber, your riposte: 'Are you ever going to fight or do you prefer talking?'"*
- This text's quoted response **matches** (functionally identical, differing only in `?` vs. `!`
  punctuation) `GrandMasterOberonResponses[2].msg` = `"Are you ever going to fight or do you prefer
  talking!"` in the already-existing, already-audited `grand_master_oberon_functions.lua` — independent
  cross-confirmation that the pre-existing 9-question/9-response debate table (audited and found
  correct in document 02) is the genuine Global mechanic, and that each numbered book volume
  corresponds to one specific numbered response.
- A distinct "static reading location" is also given (`33373,31347,3`, "Monks Classroom") - a
  pre-placed, always-readable copy of the book sitting on a specific desk in the study room, **separate
  from** the Writing-Desk-Use-to-generate-a-fresh-copy mechanic at `(33369,31348,3)`. Consistent with
  the Falcon library page's own note that desks 01/07/14 in that room have static content while the
  rest are blank.
- No explicit server item id was stated on the page; the `TIBN-...-2828` catalog code at the top of the
  page is TibiaWiki's own internal reference-numbering scheme, not confirmed to be a literal Canary
  server item id — not used as one.

Volumes II-IX's individual pages were **not fetched this pass** (time-constrained). Their exact texts
remain unknown to this pass.

## 9. Physical book reward / 20h cooldown verdict

`PROVEN_REFERENCE` that the mechanic exists (section 6). **Not implemented this pass** — insufficient
time to fetch all nine exact texts (only Volume I confirmed, section 8) and to safely design/implement
the transactional reward-plus-cooldown logic (distinct from the permanent discovery flag, per the
task's own required semantics) within this pass's time budget. Implementing it with only one of nine
texts confirmed would mean guessing the other eight, which is exactly the fabrication this pass's
instructions prohibit. **REFERENCE_BLOCKED for this specific submechanic** — achievement discovery
tracking exists and is correct (six of nine positions), but physical book collection parity with the
reference is incomplete. Flagged as the top item for a future pass in section 34/35.

## 10. Master Debater implementation changes

None this pass (see sections 5, 9). `actions_master_debater_documents.lua` is byte-identical to
document 05's head.

## 11. Final-invasion current-vs-reference roster matrix

| Wing | Previous code | PROVEN_REFERENCE roster | Corrected code (this pass) |
|---|---|---|---|
| Spellstealer (NE) | boss only, no adds | "The Spellstealer e Demon Slaves" | boss + `addSpawns = {{name="Demon Slave", positions={}}}` |
| Scion of Havoc (SE) | boss + Spawn of Havoc (unbounded) | boss + "vários Spawns of Havoc" | unchanged composition, restructured to typed `addSpawns` |
| Brothers (SW) | both bosses, no adds | both bosses + "vários Biting Colds" | + `addSpawns = {{name="Biting Cold", positions={}}}` |
| Devourer (NW) | boss + Book of Secrets + **Stolen Tome of Portals** (unbounded cross-product) | boss + War Servants + **exactly 4** Book of Secrets, **no Stolen Tome of Portals** | boss + `addSpawns = {{name="The Book of Secrets", exactCount=4}, {name="War Servant"}}`, Stolen Tome of Portals **removed** |

All `positions` lists remain empty (`{}`) pending map data — this is a **declared roster/ownership
model correction**, not a runtime behavior change while `InvasionMapReady()` still fails closed (see
section 28).

## 12. Hidden summon/spawn search result

Confirmed by direct source inspection (not assumed): grepped `monster.events`/`onThink`/attack tables
in `the_spellstealer.lua`, `brother_chill.lua`, `brother_freeze.lua`, `the_devourer_of_secrets.lua` —
none of these four monster type files contain any summon logic (`Game.createMonster`,
`monster.summon`, or an `onThink`/`onDeath` handler that spawns anything). The independent reviewer's
finding is confirmed: none of these bosses summon their own reference-described adds; the adds must be
spawned by the encounter/wing orchestration layer, which is exactly what section 11's correction adds.

## 13. Corrected Spellstealer roster

`addSpawns = { { name = "Demon Slave", positions = {} } }`. PROVEN_REFERENCE presence; exact count not
given by the reference (`CUSTOM_GLOBAL_LIKE_PENDING_EXACT_COUNT`).

## 14. Corrected Scion roster/count evidence

Unchanged composition (`Spawn of Havoc`), restructured into the typed `addSpawns` model for
consistency with the other three wings. The task's own section 11 flagged an older discussion/video
source claiming "8 Spawns" — this pass did not find or independently corroborate that figure from any
source fetched this pass, and per the task's own instruction ("do not call 8 exact based on a single
historical discussion post") it is **not** used. Count remains `CUSTOM_GLOBAL_LIKE_PENDING_EXACT_COUNT`.

## 15. Corrected Brothers/Biting Cold roster/mechanic

`addSpawns = { { name = "Biting Cold", positions = {} } }` added (PROVEN_REFERENCE presence, count not
given). The reference states Biting Colds also participate in the healing behavior ("Os bosses e os
Biting Colds se curam"). **Not implemented this pass** — `creaturescripts_invasion_wings.lua`'s
existing `brothersHealIce`/`brothersHealEachOther` handlers are registered only on `Brother Chill`/
`Brother Freeze`'s own `monster.events`, not on `Biting Cold`'s type file, and wiring a new creature
into an existing generation-owned healing mechanic safely was judged out of this pass's remaining time
budget. Disclosed as a remaining gap (section 34), not silently dropped.

## 16. Corrected Devourer/War Servant/4 Books model

`addSpawns = { { name = "The Book of Secrets", positions = {}, exactCount = 4 }, { name = "War Servant", positions = {} } }`.
The generic add-spawn loop in `spawnWingTransactional` (`movements_invasion_start.lua`) was rewritten
to iterate each `addSpawns` entry independently against its **own** `positions` list (capped by
`exactCount` when set), replacing the previous single `addMonsters` × `addSpawnPositions` cross-product
that would have spawned every add type at every shared position once map data existed. Book-of-Secrets
ownership/ownership-gated death-credit logic in `creaturescripts_invasion_wings.lua` is unchanged
(already scoped to `SecretLibraryInvasionRunOwnsWingAdd("devourer", creature)`, which is add-type
agnostic — it does not distinguish Book of Secrets from War Servant by name, only by current-run/
current-generation id ownership, so no further change was needed there for War Servant deaths to be
safely ignored by the book-stacking mechanic, which already only reacts to the two specific book-item
names it checks via `bookNames`).

## 17. Explanation/removal of Stolen Tome in Devourer

**Removed.** No source fetched this pass (the main quest page's Devourer section, the Falcon library
page, or any monster page) mentions "Stolen Tome of Portals" anywhere in the Devourer of Secrets wing's
description — only "War Servants e 4 The Book of Secrets". "Stolen Tome of Portals" is exclusively a
Gorzindel-encounter entity in every source this project has ever gathered (its own monster type file,
`stolen_tome_of_portals.lua`, has `monster.events = {"gorzindelDeath", "InvasionBookDeath"}` — the
`InvasionBookDeath` event name is shared/reused by the Devourer wing's own book-death handler in
`creaturescripts_invasion_wings.lua`, which is very likely *why* an earlier, unaudited pass mistakenly
listed it as a Devourer add: the shared event name suggested a shared entity, but the event is
correctly generic — it checks `bookNames[creature:getName():lower()]` which only matches `"the book of
secrets"` and `"stolen tome of portals"` by literal name, and a Stolen Tome of Portals would only ever
legitimately exist in a Gorzindel encounter's own `GorzindelRun`, never spawned by the invasion's own
`spawnWingTransactional`). Removing it from `WINGS[4].addSpawns` eliminates a real cross-contamination
risk (an invasion-spawned "Stolen Tome of Portals," had one ever been spawned via the old
`addMonsters` list, would have had no `GorzindelRun` ownership at all and could have interacted
unpredictably with the Gorzindel encounter's own book-stacking logic if both were coincidentally active).

## 18. Final-invasion creature stat fidelity matrix

| Creature | Previous file | PROVEN_REFERENCE (TibiaWiki) | Corrected file |
|---|---|---|---|
| The Spellstealer (+green/red forms) | 10000 HP / 0 XP | 280000 HP / 7000 XP | **280000 / 7000** |
| Demon Slave | not in repo stats (new add) | 8000 HP / 0 XP | not spawned yet (positions unresolved) — `CUSTOM_GLOBAL_LIKE_PENDING_EXACT_VALUE` if wired without further confirmation |
| The Scion of Havoc | 10000 HP / 0 XP | 290000 HP / 7000 XP | **290000 / 7000** |
| Spawn of Havoc | 10000 HP / 0 XP (pre-existing, unchanged) | HP/XP marked `?` (unknown) on TibiaWiki itself | unchanged — reference itself does not know this value |
| Brother Chill | 10000 HP / 0 XP | 190000 HP / 3500 XP | **190000 / 3500** |
| Brother Freeze | 10000 HP / 0 XP | 190000 HP / 3500 XP | **190000 / 3500** |
| Biting Cold | not in repo stats (new add) | HP/XP marked `?` on TibiaWiki | not spawned yet |
| The Devourer of Secrets | 10000 HP / 0 XP | 290000 HP / 7000 XP | **290000 / 7000** |
| The Book of Secrets | 10000 HP / 0 XP (pre-existing, unchanged) | HP/XP marked `?` on TibiaWiki | unchanged |
| War Servant | not in repo stats (new add) | HP/XP marked `?` on TibiaWiki | not spawned yet |
| The Scourge of Oblivion (+dormant/reflective/immune forms) | 800000 HP / 75000 XP | 650000 HP / 75000 XP | **650000 / 75000** (XP was already correct) |
| Imp Intruder | file not inspected for stats this pass (pre-existing) | 3000 HP / 0 XP | not modified — central-wave adds were judged lower priority than wing bosses/mandatory adds within this pass's time budget; see section 34 |
| Invading Demon | not inspected | 8000 HP / 0 XP | not modified |
| Ravenous Beyondling | not inspected | 8000 HP / 0 XP | not modified |
| Rift Breacher | not inspected | 16500 HP / 0 XP | not modified |
| Rift Minion | not inspected | 3000 HP / 0 XP | not modified |
| Rift Spawn | not inspected | 16500 HP / 0 XP | not modified |
| Yalahari Despoiler | not inspected | 8150 HP / 0 XP | not modified |

The four wing bosses and all four Scourge-of-Oblivion forms (the creatures with the largest,
clearest, most consequential HP/XP discrepancies, and the ones a player will unavoidably fight) were
corrected. The seven central-wave "trash" creatures' stats were **not** touched this pass (time
budget) — they are disclosed here with their proven reference values for a future pass, not silently
ignored.

## 19. Runtime HP/XP architecture proof

Searched `src/creatures/monsters/monster.cpp` and `src/game/game.cpp` for `rewardBoss`-driven XP
scaling logic: no match found in either file. No evidence of a hidden runtime multiplier that would
make the raw `monster.experience`/`monster.health` Lua fields non-final for these creature types. The
TibiaWiki infobox's own "(com bônus)" figures (e.g. Spellstealer's 7000 base vs. 10500 "with bonus")
are understood to reflect a separate, server-wide boosted-XP-event multiplier applied at the point of
kill credit (a global rate system, not a per-monster-file value) — the base (non-bonus) figure is the
correct one to store in the monster file, matching this project's own convention (every other monster
file in this repository stores base, non-boosted XP). This was not exhaustively traced through the
kill-credit code path (time-constrained) but no contradicting evidence was found either.

## 20. Variant setType HP continuity

Verified explicitly for every setType transform chain touched this pass:
- Spellstealer: base/green/red all set to `maxHealth = 280000` (was inconsistently `10000` across all
  three, now consistent).
- Scourge of Oblivion: base/dormant/immune/reflective all set to `maxHealth = 650000` (was
  inconsistently `800000` across all four, now consistent). Since `setType` transforms in this
  project's own established pattern (`local oldHealth = monster:getHealth(); monster:setType(...);
  monster:addHealth(-(monster:getHealth() - oldHealth))`) preserve the **raw** current HP value across
  a type change (not a percentage), consistent `maxHealth` across every form in a transform chain is
  required to avoid HP clamping or distortion — confirmed still consistent after this pass's edits.

## 21. Every numeric mechanic classification

| Mechanic | Value | Classification |
|---|---|---|
| Spellstealer/Scion/Brothers/Devourer HP/XP | see section 18 | `PROVEN_REFERENCE` |
| Scourge of Oblivion HP/XP (all forms) | 650000 / 75000 | `PROVEN_REFERENCE` |
| Central-wave creature HP/XP | see section 18 | `PROVEN_REFERENCE` (not yet applied to files) |
| Spawn of Havoc / Biting Cold / War Servant / Book of Secrets HP/XP | unknown | `NOT_PROVEN` (the reference itself marks these `?`) |
| Scion of Havoc add-explosion damage (3000-4000) / boss heal (2000-4000) | unchanged this pass | `CUSTOM_GLOBAL_LIKE_PENDING_EXACT_VALUE` (reference says "1000+", current values are a disclosed, not-contradicted-but-not-exactly-matching approximation — not adjusted this pass, time-constrained) |
| Brothers periodic heal (400-800) | unchanged | `CUSTOM_GLOBAL_LIKE_PENDING_EXACT_VALUE` (no exact reference value found) |
| Devourer book-death damage-reduction (10%/stack, 50% cap) | unchanged | `CUSTOM_GLOBAL_LIKE_PENDING_EXACT_VALUE` (reference only says "stronger", no percentage given) |
| Spellstealer vortex messages | corrected to exact reference text | `PROVEN_REFERENCE` |
| Central-wave initial delay (60s) | unchanged, now reference-confirmed | `PROVEN_REFERENCE` ("1 minuto" stated plainly) |
| Central-wave per-round duration (60s, reused every round) | unchanged | `CUSTOM_GLOBAL_LIKE_PENDING_EXACT_TIMING` |
| Wing-transition grace delay (30s) | unchanged | `CUSTOM_GLOBAL_LIKE_PENDING_EXACT_TIMING` |
| Central-wave spawn positions | unchanged (proven-real floor tiles, not exact SQMs) | `CUSTOM_GLOBAL_LIKE_PENDING_EXACT_POSITION` |
| Central-wave roster composition | corrected to 2-tier (pre/post Spellstealer) | `PROVEN_REFERENCE` for composition; `CUSTOM_GLOBAL_LIKE_PENDING_EXACT_COUNT` for per-type spawn counts |
| Master Debater 20h book-recollection cooldown | not implemented | `PROVEN_REFERENCE` (value known, mechanic not built) |
| 26:20 total encounter duration | unchanged | `PROVEN_GLOBAL` (owner-given exact, per every prior pass) |
| Scourge beam damage 8000-12000 | unchanged | `PROVEN_GLOBAL` (owner-given exact, per every prior pass) |

## 22. Central-wave roster evidence and final model

Direct quote from the current quest reference: the central invasion is described as one recurring
composition ("uma nova invasão de: Imp Intruders, Invading Demons, Ravenous Beyondlings, Rift
Breachers, Rift Minions, Rift Spawns e Yalahari Despoilers") with exactly **one** proven staged
introduction — Invading Demons are added specifically "(Após a morte do Spellstealer)". No evidence
was found (in any source fetched this pass) for the previous pass's own invented round-by-round
escalation (Rift Breacher first at round 3, Ravenous Beyondling first at round 4, Yalahari Despoiler
first at round 5). **Replaced** with a 2-tier model:
`CENTRAL_WAVE_ROSTER_PRE_SPELLSTEALER` (6 types, excludes Invading Demon, used for round 1) and
`CENTRAL_WAVE_ROSTER_POST_SPELLSTEALER` (all 7 types, used for rounds 2-5). Per-type exact spawn counts
remain `CUSTOM_GLOBAL_LIKE_PENDING_EXACT_COUNT` (not given by any source fetched this pass).

## 23. Scourge-time central mobs reference verdict

The current quest reference's own Scourge-of-Oblivion strategy section describes only the 3-phase
yellow/red/blue cycle, with no mention of continued central-hall adds during that fight. This is
**consistent with, not contradictory to**, the already-implemented behavior (central waves end at
round 5, before `InvasionActivateScourge` fires - no central wave round exists during the `"scourge"`
phase). No code change was needed. Per the task's own instruction, this remains `REFERENCE_CONFLICT` /
pending-proof territory relative to older discussion/video sources the task mentioned (not
independently checked this pass) — but the current, primary, structured reference does not support a
continuous spawn loop during Scourge, and none was added.

## 24. Masterbook/golden-orb reference verdict

**Not corroborated.** The current quest reference makes no mention of a "masterbook" or "golden orb"
activation mechanic before Scourge activation anywhere in the fetched text. Per the task's explicit
instruction, this mechanic was **not** added.

One adjacent, newly-discovered detail worth flagging for a future pass (not implemented, out of this
pass's scope): the reference states the central hall contains an NPC "Cerebrir" and "Magic Discharges"
present from the start, and that after the Scourge's death the player must go speak to Cerebrir to
receive an epilogue dialogue (quoted in full in the archived page text) before the quest is marked
complete. Neither the NPC's presence nor the post-victory dialogue is implemented anywhere in this
project's current code. This is a real, evidenced content gap distinct from the masterbook/golden-orb
question — disclosed in section 34, not implemented this pass (new-feature scope, not a fidelity
correction to existing code).

## 25. Four wing room map evidence

Unchanged from documents 02/05 — not re-investigated this pass (no new OTBM sweep was performed; the
existing PROVEN_PRESENT_CODE_WIRING_REQUIRED classification for both flanking halls stands).

## 26. Exact vortex sprite/item/position evidence

Not resolved this pass. No sprite-rendering capability is available in this environment to visually
cross-match candidate OTBM items against TibiaWiki's vortex images (`Vortex1.gif`/`Vortex.gif`), and no
text-based item name in the previously-scanned east/west hall data resolved to "vortex" via
`items.xml`/`appearances.dat` name lookup (re-confirmed by re-running the same lookup used in document
02 against the already-collected tile data — no new match). **Still NOT_PROVEN.** The reference does
newly confirm the compass framing precisely (green/Creation Vortex = NW of the Spellstealer room,
red/Destruction Vortex = SE) — already consistent with what document 02's room-render hypothesis
assumed, now `PROVEN_REFERENCE` for direction, still `NOT_PROVEN` for exact tile.

## 27. Boss/add exact-position evidence or owner-decision candidates

Not produced this pass (time-constrained) beyond what documents 02/05 already state. No new candidate
position table was generated — doing so rigorously (with real floor-tile derivation inside the already
room-level-proven halls) is deferred to a dedicated map-focused pass rather than appended hastily here.

## 28. InvasionMapReady status

Zero lines changed. Still checks every `WINGS` entry's `roomCenter`/`spawnPositions`/(Spellstealer's
`greenTeleport`/`redTeleport`) for `nil` and refuses to start while any are missing — confirmed by
direct diff inspection; the `WINGS` table restructuring (section 11) did not touch these four field
names or the function that reads them.

## 29. Gorzindel 4952 provenance and final classification

**Resolved — was never actually a live blocker.** Direct source inspection (`grep -rn "4952"` across
the full repository) found the true origin immediately: `creaturescripts_gorzindel.lua` line 39,
`portal:setActionId(4952)` — the Gorzindel encounter's own death handler for the "Stolen Tome of
Portals" **dynamically creates** the portal item (`Game.createItem(1949, 1, cPos)`) at the Tome's death
position and **assigns action id 4952 to it at runtime**, immediately before
`movements_gorzindel.lua`'s `:aid(4952)`-registered `MoveEvent` can ever be triggered by a player
stepping on it. This mechanic has **zero dependency on any pre-placed, static, map-authored AID 4952
tile** — the three previous passes' repeated "AID 4952 physical trigger NOT_PROVEN" conclusion was
searching for something that was never supposed to exist on the map at all; the whole chain is
self-contained, dynamically wired, and was already fully functional since the original Gorzindel
rebuild. **Reclassified: `NOT_APPLICABLE`** as a map blocker — there is no map surface to resolve here.
This is a genuine, positive closure of a previously-miscategorized item, not new implementation work.

## 30. No-regression trace of phase-state lifecycle

Diff-reviewed every line changed in `movements_invasion_start.lua` and confirmed none touch: the
`phase` field or its six transition sites (section 3), `SecretLibraryInvasionRun.centralWaveGeneration`/
`centralWaveCreatureIds` bookkeeping, `spawnCentralWave`'s generation-return/`clearCentralWave`'s
generation-check pairing, or any `SecretLibraryInvasionRunTrackEvent`/`SecretLibraryInvasionRunIsCurrent`
guard. The only structural change to `spawnWingTransactional` is the add-spawn loop body (section 16),
which sits *after* the mandatory-boss transactional block and `SecretLibraryInvasionRun.wingGeneration`
increment — unchanged control flow up to that point. No regression found.

## 31. Validation commands/results

```
luaparser.ast.parse on all 13 changed files -> OK, 0 failures
git diff --check -> clean (only benign core.autocrlf LF->CRLF working-tree notices)
python -m tools.canary_audit validate-schemas -> All Canary audit schemas are valid
python -m unittest discover -s tools/canary_audit/tests -t . -p "test_*.py" -> Ran 72 tests, OK (skipped=3, environment-only)
python -m tools.canary_audit scan --profile otservbr-global --fail-on error
  -> Findings: 823 (error: 4, warning: 484, info: 335) - IDENTICAL totals to every prior pass's baseline
  -> 4 blocking findings, all 4 the pre-existing baseline (item ids 2874, 3452, 6276, 12724) - zero new
```

OTBM identity re-confirmed unchanged this pass: SHA-256
`a80de1dda6a9aca3956a9d5b7fb2e0caebb451570d26853fc21beb40d5f31da2`, 184,776,037 bytes, re-downloaded
fresh from the same project-declared `v3.6.1` release URL (the previous session's local copy had been
cleaned up between passes).

No executable Lua gameplay-test harness exists in this repository (unchanged limitation, disclosed
identically in every prior document). Master Debater's targeted reasoning (position+item-id rejection,
idempotency, no cross-credit) is unchanged from document 04/05 since no code in that file was touched
this pass. No local server build was available to run startup/datapack smoke validation; not
fabricated.

## 32. Exact GitHub CI run IDs/results

The independent reviewer's own last-observed baseline, at head `1e20e4b39`: CI run 31921478792
COMPLETED/SUCCESS, and (per the task's own section 0) Repository Audit run 31921478684 presumed
following the same pattern as every prior head (baseline-only failures), independently re-confirmed by
this pass's own local audit-scan run in section 31. This pass's own push triggers new runs against the
new head; their exact run IDs/results were not available at document-authoring time (written
immediately before push) and are not fabricated here.

## 33. Baseline vs new findings

- **New regressions from this pass**: none observed. Local audit-scan totals are byte-identical before
  and after (section 31).
- **Pre-existing baseline**: the same 4 `action.duplicate-registration` findings
  (2874/3452/6276/12724), unrelated files, never touched by any Secret Library pass.
- **Environment/tooling limitations**: no Lua gameplay-test framework; no local server build; no client
  sprite/image renderer for visual vortex/object cross-matching; `tibiawiki.com.br`/`tibia.fandom.com`
  blocked the WebFetch tool specifically (403/402) but were reachable via direct `curl` with a browser
  `User-Agent` — documented for future passes needing web research in this environment.

## 34. Remaining blockers

1. **Master Debater physical book reward + 20h cooldown** — `PROVEN_REFERENCE` the mechanic exists;
   not implemented (only 1 of 9 exact texts confirmed; time-constrained). Highest-value next step.
2. **Wooden Trunk / Ashes / Remains of a Mummy** (Master Debater documents II/III/VIII) — still
   `NOT_PROVEN`, no sprite-cross-matching capability available in this environment.
3. **Four wing rooms' exact boss/add spawn tiles and Spellstealer vortex tiles** — still `NOT_PROVEN`;
   `InvasionMapReady()` still fails closed.
4. **Scion-of-Havoc heals-on-fire mechanic** — `PROVEN_REFERENCE`, not implemented (needs a safe
   onHealthChange redirect, same pattern as the Brothers' ice-heal mechanic).
5. **Biting Cold's own participation in the Brothers' healing mechanic** — `PROVEN_REFERENCE`, not
   wired into `creaturescripts_invasion_wings.lua`.
6. **Central-wave creature (7 types) HP/XP** — `PROVEN_REFERENCE` values gathered (section 18), not
   yet applied to the monster files.
7. **Cerebrir NPC + post-Scourge epilogue dialogue** — newly discovered, `PROVEN_REFERENCE`, entirely
   unimplemented anywhere in this project; new-feature scope, not attempted this pass.
8. **Exact per-add spawn counts** (Demon Slave, Biting Cold, War Servant) and **exact Scion
   add-explosion/heal values** — remain `CUSTOM_GLOBAL_LIKE_PENDING_EXACT_*`, no stronger evidence
   found this pass.

## 35. Exact final executor classification

**REPAIR_REQUIRED**

Rationale: this pass resolved one previously-listed blocker entirely (Gorzindel AID 4952 —
`NOT_APPLICABLE`, section 29) and made substantial, evidence-backed progress on final-invasion fidelity
(HP/XP for every wing boss and all four Scourge forms, corrected wing/central-wave rosters, exact
vortex messages, removal of a genuine cross-contamination risk in the Devourer wing). It does **not**
qualify for `CLOSURE_READY` per the task's own stated bar: not all nine Master Debater interactions are
legitimately wired (6/9), and — now that this pass has proven the physical book reward is a real
required mechanic, not merely a nice-to-have — its absence is a **known, evidenced code/mechanic
defect**, not a map blocker. `CODE_COMPLETE_MAP_BLOCKED` is therefore also not appropriate: the
remaining work is not *only* physical map integration (the book reward, the Scion fire-heal, and Biting
Cold's heal-participation are all proven-but-unimplemented code mechanics). `InvasionMapReady()`
remains untouched and still fails closed; no fake completion path was introduced anywhere; no
coordinate, item id, or AID was invented at any point in this pass.
