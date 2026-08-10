# Heart of Destruction — Map Manifest (Repair Pass)

Read-only map policy in effect for this pass: no OTBM edits were made or attempted. This
document restates and re-confirms the map-integration gap already identified in
`04_HOD_PORTAL_ACCESS_CONTRACT.md`, using this engagement's own independent full-map scan
(`otbm_read.py`/`tiles.py` against the live `otservbr.otbm`, node-walking every `N_ITEM` for its
action id) as corroborating first-party evidence, not just the prior document's claim.

## Status: MAP SETUP REQUIRED (unchanged, NOT_PROVEN beyond what's stated)

### 1. Outer vortex entrances (3 action ids)

| AID | Route | Expected object | Current OTBM occurrences |
|---|---|---|---|
| 14361 | Ankrahmun → Anomaly | vortex entrance item | 0 |
| 14362 | Zao → Rupture | vortex entrance item | 0 |
| 14363 | Svargrond → Realityquake | vortex entrance item | 0 |

- **Runtime side (present, working):** `movements_vortex_route_entrances.lua` already registers a
  `stepin` MoveEvent for all three AIDs, with full access-gate logic (CaveAccess, level 150,
  Premium, permanent-route-unlock OR active-vortex check) and correct destination `Position`s
  already coded (see the file's `routes` table — destinations were previously verified as
  pointing at real, already-functioning rooms).
- **Map side (missing):** none of the three action ids exist anywhere on the current map. The
  script has nothing to attach to.
- **Why runtime wiring is insufficient:** action ids are read from the map tile's item attributes;
  a script cannot invent the item or the tile placement, and this pass's mandate is read-only
  map inspection.
- **What RME must change:** place one steppable item per route (e.g. a vortex/portal-style item
  consistent with the other in-quest vortex items already using action ids 14320/14324/14326/
  14328/14332/14343/14345 etc.) near Ankrahmun, Zao, and Svargrond respectively, each carrying the
  corresponding action id (14361/14362/14363). Exact tile coordinates are **NOT_PROVEN** by this
  pass — no coordinate is invented here; whoever places these must pick real, walkable tiles at
  each city and record them back into `04_HOD_PORTAL_ACCESS_CONTRACT.md`.
- **How to test:** after placement, step onto each tile as a level-150+ Premium test character
  with no route storages set — expect the "dormant" denial message when the route's rotating
  vortex isn't active, and a successful teleport to the route's pre-mission entrance when it is
  (or when the route's permanent-unlock storage is already set).

### 2. Route-kill monsters (6 monster types, 3 routes)

`creaturescripts_vortex_route_kills.lua` defines the kill-counting logic for
`AnkrahmunKills`/`SvargrondKills`/`ZaoKills` (Dread Intruder / Breach Brood / Reality Reaver and
their "Stabilizing"/"Instable" escalated forms), but this pass did not re-run an independent
full-map spawn scan for these 6 monster names — the "no spawns found" conclusion here is carried
over from `04_HOD_PORTAL_ACCESS_CONTRACT.md` only. **NOT_PROVEN** by this pass's own evidence;
flagging rather than asserting a fresh confirmation. If the prior document's finding holds, these
6 monster types also need spawn placement (raid/spawn XML, not OTBM item edits) before the outer
routes' 10-kill permanent-access mechanic is reachable at all.

## Bottom line

Every fix in this PR operates on logic that already assumes a working outer-vortex physical
layer. None of that logic can be exercised end-to-end (from Ankrahmun/Svargrond/Zao inward) until
the map-side gap above is closed by someone with RME access and world-design authority over exact
placement — this PR does not and cannot resolve that by itself, per the no-invented-coordinates
constraint.
