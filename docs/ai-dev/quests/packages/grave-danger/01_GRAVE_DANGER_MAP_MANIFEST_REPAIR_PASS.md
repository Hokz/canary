# Grave Danger — Map Manifest (Repair Pass)

Read-only map policy in effect for this pass: no OTBM edits were made or attempted.

## MAP_AUDIT_NOT_RUN

The configured map for the active datapack (`dataPackDirectory = "data-otservbr-global"` in
`config.lua.dist`, `mapName = "otservbr"`) is **`data-otservbr-global/world/otservbr.otbm`**. That
file is explicitly listed in `.gitignore` (line 383) and is genuinely absent from this working
tree - confirmed by directory listing and a bounded filesystem search of the user's home directory
(only a `data-canary/world/canary.otbm`, belonging to the *other*, non-configured `data-canary`
datapack, and an old backup copy of the same, were found; neither is the configured otservbr-global
map).

Per this pass's own instructions: substituting `data-canary/world/canary.otbm` (a different
datapack's map) would be exactly the "substitute another map" this contract prohibits, so it was not
used. **Section 36's full physical-surface audit could not be run this pass.** Every item below is
classified using only code-level evidence (existing script references to AIDs/UIDs/positions),
never independently re-confirmed against the live map.

This mirrors the situation an earlier engagement (Heart of Destruction, see
`docs/ai-dev/quests/packages/heart-of-destruction/10_HOD_MAP_MANIFEST_REPAIR_PASS.md`) resolved with
direct OTBM parsing tooling that is not present in, or was not carried into, this environment/session.

## Status matrix (executor contract, section 36)

| # | Surface | Code evidence | Classification |
|---|---|---|---|
| 1 | 12 grave physical interactions | 7 via `actions_grave_sanctify.lua` (item id 31612 used on proven `Position`s: DarkCathedral (32644,32394,8), FemorHills (32542,31846,6), Ankrahmun (33376,32806,8), Vengoth (32959,31534,7), Orclands (32776,31817,8), IceIslands (32012,31558,7), Kilmaresh (33813,31624,9)); 5 credited via boss kill (Edron/Ghostlands/Cormaya/Darashia/Thais - no separate grave-item interaction, credit follows the boss room fight itself) | STARTUP_WIRING_SUFFICIENT (code-proven positions/item id; live-map re-confirmation NOT_PROVEN this pass) |
| 2 | Five Lich boss entrances | `movements_enter_tps.lua`, AIDs 14562 (Lord Azaram), 14563 (Duke Krule), 14564 (Sir Baeloc/Nictros), 14565 (Earl Osam), 14566 (Count Vlarkorth) - proven teleport-target `Position`s per boss | STARTUP_WIRING_SUFFICIENT (NOT_PROVEN this pass) |
| 3 | Boss levers/staging (5 Lich bosses) | `actions_lord_azaram.lua`/`actions_duke_krule.lua`/`actions_baeloc_nictros.lua`/`actions_earl_osam.lua`/`actions_count_vlarkorth_.lua` - each `lever:position(...)` set to a proven coordinate | STARTUP_WIRING_SUFFICIENT (NOT_PROVEN this pass) |
| 4 | Darashia three Sacred Statues | Repo-wide grep for "Sacred Statue"/"Statue"/"extinguish" returns **zero hits** anywhere in `data-otservbr-global` | NOT_PROVEN / MAP_EDIT_REQUIRED (see Manual RME below) |
| 5 | Darashia Sundial | Repo-wide grep for "Sundial" returns **zero hits** | NOT_PROVEN / MAP_EDIT_REQUIRED (see Manual RME below) |
| 6 | King Zelos quest door | `npc/jack_springer.lua` comment references `startup/tables/door_quest.lua`, position (32173,31922,8), keyed on `Bosses.KingZelos.Room` (now correctly set at the "threat" dialogue - see the code repair section) | STARTUP_WIRING_SUFFICIENT (NOT_PROVEN this pass) |
| 7 | King Zelos lever/staging | `actions_king_zelos.lua`, `lever:position(Position(33484, 31546, 13))` | STARTUP_WIRING_SUFFICIENT (NOT_PROVEN this pass) |
| 8 | Four Zelos wing rooms | `actions_king_zelos.lua`/`creaturescripts_king_zelos.lua` - proven wing-boss positions (Red Knight 33423,31562,13; Nargol 33423,31529,13; Magnor 33463,31529,13; Rewar 33463,31562,13) and `specPos` arena bounds | STARTUP_WIRING_SUFFICIENT (NOT_PROVEN this pass) |
| 9 | Wing teleports | Implicit in the lever's `playerPositions`/room bounds; no separate dedicated wing-entry teleport script found beyond the lever itself | STARTUP_WIRING_SUFFICIENT (NOT_PROVEN this pass) |
| 10 | Final green teleport | `movements_zelos_tp.lua`, AID 14579, proven target `Position(33443, 31536, 13)` | STARTUP_WIRING_SUFFICIENT (NOT_PROVEN this pass) |
| 11 | King Zelos cleanse vortex | Confirmed **absent** before this pass (no vortex/cleanse/"Unleashed Hex" reference anywhere). This pass wrote the gameplay logic (`movements_king_zelos_cleanse_vortex.lua`) bound to a **newly allocated** AID 14580 (following this quest's own 14562-14567/14579 numbering) - no physical object carries that AID yet | MAP_EDIT_REQUIRED (see Manual RME below) |
| 12 | Gaffir route | `movements_cobra_mini_bosses.lua` references the Custodian fire-barrier crossing (AID 36568) but no dedicated "Gaffir route"/Key 0303 script was found anywhere in the quest directory | NOT_PROVEN |
| 13 | Custodian route | `actions_custodian_door.lua` (AID 36569, gated on `GaffirKilled`) and `movements_cobra_mini_bosses.lua` (AID 36568, the fire barrier) - proven AIDs, positions not independently re-confirmed | STARTUP_WIRING_SUFFICIENT (NOT_PROVEN this pass) |
| 14 | Cobra fire barriers | `movements_cobra_mini_bosses.lua`, AID 36568 - proven AID, made one-use-per-crossing this pass (see the code repair section) | STARTUP_WIRING_SUFFICIENT (NOT_PROVEN this pass) |
| 15 | Cart Packed With Gold | Repo-wide grep for "cart"/"Cobra Assassin"/"Clutter" in the quest directory returns **zero hits** - confirmed entirely absent, not merely unwired | MAP_EDIT_REQUIRED (see Manual RME below) |
| 16 | Cart route | Same as above - no waypoint/path data exists to reference | NOT_PROVEN |
| 17 | Clutter blockers | Same as above | NOT_PROVEN |
| 18 | Quaid route | `movements_quaidDen.lua`, UID/item 31733, gated on `CustodianKilled` | STARTUP_WIRING_SUFFICIENT (NOT_PROVEN this pass) |
| 19 | Roof rope | Repo-wide grep for "rope" in the quest directory returns no dedicated roof-rope teleport script | NOT_PROVEN |
| 20 | Green-handle/chess access | No script found | NOT_PROVEN |
| 21 | Chess board | Repo-wide grep for "chess"/"Roaring Lion"/"Cheesy Figurine" in the quest directory returns **zero hits** - confirmed entirely absent | MAP_EDIT_REQUIRED (see Manual RME below) |
| 22 | Chess pieces | Same as above | NOT_PROVEN |
| 23 | Scarlett staging | `cobra_bastion/actions_scarlett.lua`, `lever:position(Position(33395, 32660, 6))`, proven `playerPositions`/`specPos` | STARTUP_WIRING_SUFFICIENT (NOT_PROVEN this pass) |
| 24 | Scarlett Cobra/statue start trigger | The only proven physical trigger found is the generic `graveScarlettAid` item interaction (AID 40003, mirror pillars/chestplate/metal wall) plus the `BossLever` itself - no distinct "Cobra statue" object was found. Per section 31, a generic lever was NOT preferred over a proven physical trigger, but no *additional* proven trigger exists to prefer instead - the lever + AID 40003 combination is what this pass hardened (attempt token, full-roster validation) | STARTUP_WIRING_SUFFICIENT (NOT_PROVEN this pass) |
| 25 | Scarlett mirrors | `cobra_bastion/actions_scarlett.lua`/`creaturescripts_scarlett.lua`, proven mirror item ids (31474-31477) and room bounds (`rooms` table, 9 sub-rooms) | STARTUP_WIRING_SUFFICIENT (NOT_PROVEN this pass) |
| 26 | Galthen's Chestplate | `cobra_bastion/actions_scarlett.lua`, item id 31482, proven respawn position (33398,32640,6) | STARTUP_WIRING_SUFFICIENT (NOT_PROVEN this pass) |

## Manual RME Manifest

### 1. Darashia — three Sacred Statues + Sundial

- **Gameplay purpose:** per the owner reference, extinguishing three Sacred Statues and then using a
  central Sundial opens passage toward Sir Nictros/Sir Baeloc's grave.
- **Expected region:** Darashia, graveyard area (exact tile positions NOT_PROVEN).
- **Exact position:** NOT_PROVEN - no coordinate found anywhere in the repository.
- **z-level:** NOT_PROVEN.
- **Object/item identity:** NOT_PROVEN - no "Sacred Statue" or "Sundial" item id exists anywhere in
  this codebase to reuse; a real one must be identified from client data by whoever has map access.
- **Current tile contents / current AID / current UID:** NOT_PROVEN (no OTBM access this pass).
- **Required AID/UID:** none allocated - allocating one without a real object to attach it to would
  be inventing map wiring ahead of the object existing.
- **Teleport destination:** the existing physical access into the Sir Baeloc/Nictros fight already
  works via `movements_enter_tps.lua` (AID 14564, storage-timer gated) - this statue/sundial mechanic,
  if implemented later, would presumably be an *additional* earlier gate, not a replacement.
- **Why runtime wiring is insufficient:** action ids are read from the map tile's item attributes; a
  script cannot invent the item or its placement.
- **Exact manual RME operation:** place three "Sacred Statue"-equivalent items (extinguishable, e.g.
  via a fire-source interaction) at their real Darashia positions, plus one Sundial item, each
  carrying a newly-chosen AID; record the exact coordinates back into this document.
- **Post-edit QA steps:** as a level-250+ Premium character with `GraveDanger.Questline >= 1`,
  confirm each statue can be extinguished exactly once, confirm the Sundial only opens passage once
  all three are extinguished, and confirm the existing Sir Baeloc/Nictros entry teleport (AID 14564)
  still functions unchanged.

### 2. King Zelos cleanse vortex

- **Gameplay purpose:** lets a current-run Greater-Hexed participant remove their Hex, healing King
  Zelos ~15,000 HP and spawning one Unleashed Hex.
- **Expected region:** the King Zelos final-phase room, north side, per the owner reference
  ("wchodzimy w p�lnocny, czerwony wir" - "we step into the northern red vortex"). The room's
  code-proven bounds are `specPos` `(33414,31520,13)`-`(33474,31574,13)` and King Zelos's own spawn
  at `(33443,31545,13)` - the vortex should sit north of that, i.e. lower `y`, inside those bounds.
- **Exact position:** NOT_PROVEN.
- **Object/item identity:** NOT_PROVEN. The source describes a red/green colour-changing vortex; no
  such item pair exists anywhere in this repository to reuse.
- **Current tile contents / current AID / current UID:** NOT_PROVEN.
- **Required AID/UID:** **14580** - this pass already wrote and registered the full gameplay logic
  (`movements_king_zelos_cleanse_vortex.lua`, a `MoveEvent:onStepIn` bound to this AID) against the
  existing `KingZelosRun` state, but no physical object on the map carries this AID yet, so the
  script currently has nothing to attach to.
- **Teleport destination:** not applicable (step-in trigger, not a teleport).
- **Why runtime wiring is insufficient:** the AID is a script-hook identifier this pass owns and can
  freely allocate; the physical tile/item carrying that AID is a map fact this pass cannot invent.
- **Exact manual RME operation:** place one vortex-style item at the real northern position with
  action id 14580. The red/green two-state visual described by the source was deliberately NOT
  implemented in code this pass (no proven item id pair for the two states) - if RME places a
  transformable red/green item pair, a small follow-up script change can toggle it based on
  `KingZelosRun.hex` state; until then a single static item is sufficient for the gameplay logic to
  function.
- **Post-edit QA steps:** with an active King Zelos run and a Greater-Hexed participant, step onto the
  tile and confirm: the Hex condition is removed, King Zelos's health increases by ~15,000, one
  "Unleashed Hex" monster appears at the vortex tile, and a non-Hexed or non-participant player
  stepping on the tile gets an appropriate rejection message with no effect.

### 3. Cobra Bastion — Cart Packed With Gold (escort mechanic)

- **Gameplay purpose:** escort a cart from the Custodian's fire barrier to Guard Captain Quaid's den,
  fighting off Cobra Assassins and destroying Clutter blocking the route.
- **Expected region:** Cobra Bastion, between the Custodian's area (fire barrier around
  `x=33385`/`x=33387`, per `movements_cobra_mini_bosses.lua`) and Quaid's den (UID 31733, per
  `movements_quaidDen.lua`).
- **Exact position / waypoint path:** NOT_PROVEN - no waypoint coordinates exist anywhere in the
  repository; this mechanic is entirely unimplemented (recon confirmed zero references to "cart",
  "Cobra Assassin", or "Clutter" anywhere in the quest directory).
- **Object/item identity:** NOT_PROVEN (no "Cart Packed With Gold" item exists to reuse).
- **Current tile contents / current AID / current UID:** NOT_PROVEN.
- **Required AID/UID:** none allocated - a whole waypoint path needs real coordinates before any
  script logic can be written against it; inventing one would fabricate map facts.
- **Teleport destination:** not applicable.
- **Why runtime wiring is insufficient:** an escort state machine needs a real, ordered list of
  waypoint positions and real Clutter/obstacle positions; none can be produced without map access.
- **Exact manual RME operation:** place the Cart item and its full waypoint path, Cobra Assassin spawn
  points, and Clutter obstacle items along the real in-game route; record every coordinate back into
  this document so the escort state machine (attempt-owned: cart, current waypoint/progress,
  participants, Clutter, events, success/failure state - per section 28) can then be written against
  proven positions.
- **Post-edit QA steps:** once implemented, confirm the cart cannot be silently bypassed (Quaid's den
  access currently requires only `CustodianKilled >= 1`, pre-existing behavior this pass did not
  change since blocking it further with no way to ever satisfy a Cart-completion storage would brick
  the quest) - this is the current, honestly-documented gap. Downstream progression already does NOT
  claim Cart completion anywhere (no questlog entry was added for it, see the code repair section).

### 4. Cobra Bastion — Chess puzzle (roof rope, green-handle room, board, Roaring Lion)

- **Gameplay purpose:** reach the bastion roof via a rope, pass through a green-handled door into a
  chess room, place the Cheesy Figurine as the missing piece, execute the correct move sequence
  (e2-e4, d7-d6, d2-d4, Ng8-f6, Nb1-c3, Nb8-d7), which spawns a Roaring Lion and updates the
  questlog, unlocking further Scarlett access.
- **Expected region:** Cobra Bastion upper floors/roof (level +6 per the owner reference).
- **Exact position:** NOT_PROVEN - no rope, chess board, or chess piece coordinates exist anywhere in
  the repository; this entire mechanic is confirmed absent (zero hits for "chess", "Roaring Lion",
  "Cheesy Figurine" anywhere in the quest directory).
- **Object/item identity:** NOT_PROVEN (no chess piece item ids, no rope item id, no green-handle door
  item id exist to reuse).
- **Current tile contents / current AID / current UID:** NOT_PROVEN.
- **Required AID/UID:** none allocated.
- **Teleport destination:** the rope's destination room is undocumented; NOT_PROVEN.
- **Why runtime wiring is insufficient:** chess-piece placement/move validation needs real board-tile
  coordinates and real piece item ids; the storage used to record completion should be allocated from
  the established `Storage.Quest.U12_20.GraveDanger` range (free tail starting at 46928, per the
  storage table gathered during this pass's recon) once the real board is known - not invented now.
- **Exact manual RME operation:** place the roof rope, the green-handle door, the chess board tiles,
  and the full chess piece set (including the missing-piece socket for the Cheesy Figurine) at their
  real positions; record every coordinate and item id back into this document.
- **Post-edit QA steps:** once implemented, confirm Scarlett access still correctly requires
  Gaffir+Custodian+Quaid+chess (this pass's Scarlett lever validation deliberately omits the chess
  check today - see the code repair section - specifically because the storage it would check can
  never be set; that omission must be closed once this manual RME lands, by adding the chess-completion
  check to `cobra_bastion/actions_scarlett.lua`'s `validateParticipant`).
