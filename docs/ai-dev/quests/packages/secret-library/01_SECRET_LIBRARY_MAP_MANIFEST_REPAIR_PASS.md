# Secret Library — Map Manifest (Full Repair v2)

Read-only map policy in effect for this pass: no OTBM edits were made or attempted.

## MAP_AUDIT_NOT_RUN

The configured map for the active datapack (`dataPackDirectory = "data-otservbr-global"` in
`config.lua.dist`, `mapName = "otservbr"`) is **`data-otservbr-global/world/otservbr.otbm`**. That
file is explicitly listed in `.gitignore` (line 383) and is genuinely absent from
`data-otservbr-global/world/` (only `otservbr-house.xml`, `otservbr-monster.xml`,
`otservbr-npc.xml`, `otservbr-zones.xml` are present — no `.otbm`). No substitute map
(`data-canary/world/canary.otbm` or any other) was used in its place, per this pass's own
instructions. **Section 36's full physical-surface audit could not be run this pass.** Every item
below is classified using only code-level evidence (existing script references to AIDs/positions/item
ids), never independently re-confirmed against the live map. This mirrors the same
MAP_AUDIT_NOT_RUN situation this engagement already documented for Grave Danger
(`docs/ai-dev/quests/packages/grave-danger/01_GRAVE_DANGER_MAP_MANIFEST_REPAIR_PASS.md`).

## Status matrix (executor contract, section 36)

| # | Surface | Code evidence | Classification |
|---|---|---|---|
| 1 | Isle of Kings scythe entrance trigger | `scripts/lib/register_actions.lua` `onUseScythe`, proven trigger `Position(32177, 31925, 7)`, now gated on level 250 + Premium + `LibraryPermission >= 7` (this pass's own fix, section 11) | STARTUP_WIRING_SUFFICIENT (NOT_PROVEN this pass) |
| 2 | Isle of Kings monument/scythe object itself | No "monument" reference exists anywhere in the quest directory; only the trigger *position* above is code-proven, not the physical object/its AID | NOT_PROVEN |
| 3 | Library entry destination | `register_actions.lua` `onUseScythe`, proven teleport target `Position(32515, 32535, 12)` | STARTUP_WIRING_SUFFICIENT (NOT_PROVEN this pass) |
| 4 | Lokathmor lever/staging | `actions_lokathmor.lua`, `lever:position(Position(32720, 32749, 10))` | STARTUP_WIRING_SUFFICIENT (NOT_PROVEN this pass) |
| 5 | Lokathmor arena bounds | `actions_lokathmor.lua` `specPos` `(32742,32681,10)`-`(32758,32696,10)`, boss `CENTER_POSITION(32751,32689,10)` | STARTUP_WIRING_SUFFICIENT (NOT_PROVEN this pass) |
| 6 | Lokathmor mechanic geometry (Force Field cage, Dark Knowledge, parchment desk) | `actions_lokathmor.lua`, Force Fields at 4 cardinal offsets from `CENTER_POSITION` (±2 tiles), Dark Knowledge at `(CENTER_POSITION.x, CENTER_POSITION.y-4, z)` — derived relative to the already-proven boss position, not independently surveyed | NOT_PROVEN (relative derivation, no dedicated tile-level confirmation; does not gate progression on any single tile) |
| 7 | Gorzindel lever/staging | `actions_gorzindel.lua`, `lever:position(Position(32746, 32749, 10))` | STARTUP_WIRING_SUFFICIENT (NOT_PROVEN this pass) |
| 8 | Gorzindel arena bounds | `actions_gorzindel.lua` `specPos` `(32680,32711,10)`-`(32695,32726,10)`, boss `CENTER_POSITION(32687,32715,10)` | STARTUP_WIRING_SUFFICIENT (NOT_PROVEN this pass) |
| 9 | Gorzindel side-room Stolen Knowledge positions (5) | Confirmed this pass (section 15.1 recon): current action spawns entities outside the file's own `specPos` rectangle — the side rooms are real but their positions were never independently re-surveyed against the OTBM | MAP_EDIT_REQUIRED / NOT_PROVEN — existing hardcoded positions kept live (not widened with a guessed rectangle) since no replacement is proven either |
| 10 | Mazzinor lever/staging | `actions_mazzinor.lua`, `lever:position(Position(32720, 32773, 10))` | STARTUP_WIRING_SUFFICIENT (NOT_PROVEN this pass) |
| 11 | Mazzinor arena bounds | `actions_mazzinor.lua` `specPos` `(32716,32713,10)`-`(32732,32728,10)`, boss `CENTER_POSITION(32725,32719,10)` | STARTUP_WIRING_SUFFICIENT (NOT_PROVEN this pass) |
| 12 | Mazzinor mechanic geometry (Wild Knowledge adds, vortex spawn) | `actions_mazzinor.lua` — Wild Knowledge adds spawned relative to `CENTER_POSITION`; vortex items are created at each Wild Knowledge's own death position (runtime-derived, not a fixed map tile) | NOT_PROVEN for the ambient add positions (relative derivation); vortex spawn position is inherently runtime, not a map fact |
| 13 | Ghulosh lever/staging | `actions_ghulosh.lua`, `lever:position(Position(32746, 32773, 10))` | STARTUP_WIRING_SUFFICIENT (NOT_PROVEN this pass) |
| 14 | Ghulosh arena bounds | `actions_ghulosh.lua` `specPos` `(32748,32713,10)`-`(32763,32729,10)`, boss `BOSS_POSITION(32756,32720,10)` | STARTUP_WIRING_SUFFICIENT (NOT_PROVEN this pass) |
| 15 | Ghulosh mechanic geometry (Book of Death spawn / desk) | `actions_ghulosh.lua`, `BOOK_POSITION(32756,32718,10)` — proven relative to the already-proven boss position | STARTUP_WIRING_SUFFICIENT (NOT_PROVEN this pass) |
| 16 | Final invasion lever/staging (10-player positions) | `actions_the_scourge_of_oblivion.lua`, 10 `playerPositions` entries around `(32676-32677, 32741-32745, 11)`, all pre-existing and unchanged this pass | STARTUP_WIRING_SUFFICIENT (NOT_PROVEN this pass) |
| 17 | Final invasion central hall | `Position(32726, 32733, 11)` — the lever's own proven `teleport` destination, unchanged from the pre-existing implementation | STARTUP_WIRING_SUFFICIENT (NOT_PROVEN this pass) |
| 18 | Final central raid spawn areas | Repo-wide search found **no** distinct "central raid" monster type or spawn position anywhere — the encounter's central-hall behavior has only ever been breach *messages*, never physical central-raid monsters | NOT_PROVEN / MAP_REQUIRED — not invented this pass |
| 19 | Final central message-book | No physical book/readable item tied to the central hall exists anywhere in the repo — the "book-message" is implemented as `sendTextMessage` broadcasts only | NOT_PROVEN / MAP_REQUIRED — not invented this pass |
| 20 | NE wing room (Spellstealer) | `movements_invasion_start.lua` `WINGS[1].roomCenter`/`spawnPositions` — both `nil`, honest pre-existing "MAP SETUP REQUIRED" placeholder carried forward | MAP_EDIT_REQUIRED |
| 21 | Spellstealer green teleport tile | `WINGS[1].greenTeleport` — `nil` | MAP_EDIT_REQUIRED |
| 22 | Spellstealer red teleport tile | `WINGS[1].redTeleport` — `nil` | MAP_EDIT_REQUIRED |
| 23 | SE wing room (Scion of Havoc) + Spawn of Havoc add positions | `WINGS[2].roomCenter`/`spawnPositions`/`addSpawnPositions` — all `nil` | MAP_EDIT_REQUIRED |
| 24 | SW wing room (Brother Chill & Brother Freeze) | `WINGS[3].roomCenter`/`spawnPositions` — both `nil` | MAP_EDIT_REQUIRED |
| 25 | NW wing room (Devourer of Secrets) + book/tome add positions | `WINGS[4].roomCenter`/`spawnPositions`/`addSpawnPositions` — all `nil` | MAP_EDIT_REQUIRED |
| 26 | Final Scourge of Oblivion position | `Position(32726, 32727, 11)` — proven, pre-existing, unchanged this pass | STARTUP_WIRING_SUFFICIENT (NOT_PROVEN this pass) |
| 27 | Southern exit (post-victory) | `config.exit = Position(32480, 32599, 15)` — proven, pre-existing, unchanged this pass | STARTUP_WIRING_SUFFICIENT (NOT_PROVEN this pass) |
| 28 | Deep Desert Furious Scorpion room bounds | `movements_scorpion_room_adds.lua`, `roomFrom(32943,32303,8)`/`roomTo(32960,32315,8)` | STARTUP_WIRING_SUFFICIENT (NOT_PROVEN this pass; see the Deep Desert map-policy comment in the code itself) |
| 29 | Deep Desert Scorpion trigger tiles (2) | `westTrigger(32955,32309,8)`, `deepTrigger(32949,32309,8)` — kept live per this pass's own section-9 classification (gates no quest-progression storage) | NOT_PROVEN (kept live, non-gating) |
| 30 | Deep Desert elite warrior spawn positions (4) | `movements_scorpion_room_adds.lua` lines 54-57 | NOT_PROVEN (kept live, non-gating) |
| 31 | Deep Desert elite gladiator spawn positions (2) | `movements_scorpion_room_adds.lua` lines 97-98 | NOT_PROVEN (kept live, non-gating) |
| 32 | Deep Desert puzzle door thresholds (2) | `actions_doors.lua`, both doors now gated on `#puzzle >= 39` (this pass's own fix, section 9) — code-level thresholds, not a physical-surface question | ALREADY_WIRED (code fix only, no map dependency) |

## Manual RME Manifest

### 1. Final invasion — four wing rooms + Spellstealer color teleports

- **Gameplay purpose:** the sequential 26:20 final invasion (`actions_the_scourge_of_oblivion.lua` /
  `movements_invasion_start.lua`) breaches NE → SE → SW → NW in order; each wing needs its own room for
  its boss(es)/adds to spawn in, and the Spellstealer wing additionally needs two teleport tiles
  (green/red) that revert its colored immune phase back to vulnerable.
- **Expected region:** four rooms surrounding the central hall (`Position(32726, 32733, 11)`), one per
  compass direction per the breach messages ("NORTH EASTERN WING", "SOUTH EASTERN WING", "SOUTH WESTERN
  WING", "NORTH WESTERN WING").
- **Exact position:** NOT_PROVEN for all four rooms and both Spellstealer teleport tiles — no
  coordinate exists anywhere in the repository or the reference text (only directional/narrative
  description, e.g. "go northeast").
- **z-level:** presumably `11` (matching the central hall/Scourge/lever), NOT_PROVEN.
- **Object/item identity:** the 5 wing-boss monster types and 3 add types already exist in the
  repository (`The Spellstealer`, `The Scion of Havoc` + `Spawn of Havoc`, `Brother Chill` + `Brother
  Freeze`, `The Devourer of Secrets` + `The Book of Secrets` + `Stolen Tome of Portals`) — no new
  monster asset is required, only their spawn positions.
- **Current tile contents / current AID / current UID:** NOT_PROVEN (no OTBM access this pass).
- **Required AID/UID:** none — this pass's wing state machine (`InvasionAdvanceWing`,
  `spawnWingTransactional`) reads `WINGS[n].roomCenter`/`spawnPositions`/`addSpawnPositions` directly as
  `Position` literals, not AID-triggered; once real coordinates are known they are a direct code edit to
  `movements_invasion_start.lua`, not a new map trigger object.
- **Teleport destination:** not applicable for the four wing rooms themselves (players fight in place
  after each breach); the two Spellstealer color teleports are step-in `MoveEvent` tiles with no separate
  destination — stepping on them transforms the monster in place.
- **Why runtime wiring is insufficient:** `InvasionMapReady()` (`movements_invasion_start.lua`)
  mechanically checks every one of these fields for `nil` before the lever is allowed to start the
  encounter at all — this is intentional fail-closed behavior per the owner contract's explicit "do NOT
  start an inert 26-minute encounter" instruction, not an oversight. The encounter is currently 100%
  code-complete and will function correctly the moment these seven values are filled in.
- **Exact manual RME operation:** determine the four wing room areas around the central hall, record
  each room's boss spawn tile(s) as `Position` literals into `WINGS[n].spawnPositions` (and
  `addSpawnPositions` for the Scion/Devourer wings), record two teleport tiles inside the Spellstealer
  room as `greenTeleport`/`redTeleport`, and set each `roomCenter` for reference.
- **Post-edit QA steps:** with a full eligible 10-player roster, pull the lever and confirm: the
  encounter fails closed with no teleport/cooldown consumed until all seven values are set; once set,
  confirm strict sequential breach order (SE never spawns before NE's Spellstealer is dead, etc.),
  confirm the Spellstealer reverts to vulnerable only when its owned instance steps on its own matching
  teleport, confirm Brothers wing requires both deaths, confirm Scion/Devourer adds are ownership-scoped
  to their own wing generation, and confirm the Scourge only activates after all four wings are cleared.

### 2. Final invasion — central raid spawn areas + central message-book

- **Gameplay purpose:** per the owner contract section 23, the ~30s central-invasion start and each
  inter-wing interval should present "central raid" activity and a message source distinct from the
  wing breaches themselves.
- **Expected region:** the central hall, `Position(32726, 32733, 11)`.
- **Exact position / object identity:** NOT_PROVEN — no distinct central-raid monster type or physical
  book/readable item tied to the central hall exists anywhere in this repository; the reference gives no
  exact monster types or coordinates either. Rather than invent a monster type or item id, this pass
  implements the central-hall beats as `sendTextMessage` broadcasts only ("The central hall shudders as
  the invasion begins!"), matching the pre-existing disclosed design this repair inherited ("framed as
  message events, not visual reveals").
- **Why runtime wiring is insufficient:** a monster type or item id that does not exist cannot be
  spawned/read without inventing an asset, which this pass's instructions explicitly prohibit.
- **Exact manual RME operation:** if a physical central-raid presence and/or a readable central book are
  intended, the owner must identify the exact monster type(s)/item id and coordinates; until then the
  message-only implementation is the functional, disclosed stand-in.
- **Post-edit QA steps:** if added later, confirm any central-raid monsters are spawned/owned exactly
  like a wing's adds (current-run-token-scoped) and that killing them has no unintended effect on wing
  progression.

### 3. Gorzindel — five side-room Stolen Knowledge positions

- **Gameplay purpose:** Gorzindel is invulnerable until all five Stolen Knowledge (in side rooms off the
  main arena) are destroyed; the boss-room Stolen Tome of Portals exposes access toward them.
- **Expected region:** side rooms adjoining Gorzindel's arena (`specPos` `(32680,32711,10)`-
  `(32695,32726,10)`).
- **Exact position:** the five hardcoded Stolen Knowledge positions predate this pass and were found
  (section 15.1 recon) to spawn entities *outside* the file's own `specPos` rectangle — this could be
  intentional topology (side rooms are legitimately outside the main arena bounds) or incomplete cleanup
  coverage; NOT_PROVEN either way without OTBM access, so this pass did **not** blindly widen `specPos`
  to a guessed rectangle.
- **Why runtime wiring is insufficient:** confirming whether these five positions sit in real,
  walkable side-rooms (vs. inside a wall, or in an unintended void) requires reading the actual map.
- **Exact manual RME operation:** verify the five existing Stolen Knowledge coordinates against the real
  map; if any fall outside a legitimate walkable side-room, correct them, and widen `specPos` only to
  the degree the real room geometry requires (not a guess).
- **Post-edit QA steps:** confirm all five Stolen Knowledge are reachable and killable, confirm
  Gorzindel remains invulnerable until the exact fifth current-run kill, and confirm no add spawns
  outside the corrected zone bounds.

## What was NOT touched by this Manual RME Manifest

Item 32 (Deep Desert puzzle door thresholds) and the already-`STARTUP_WIRING_SUFFICIENT`/`ALREADY_WIRED`
rows above required no map edit — only the code-level fixes already described in the execution report.
No OTBM file was opened, read, or modified at any point in this pass.
