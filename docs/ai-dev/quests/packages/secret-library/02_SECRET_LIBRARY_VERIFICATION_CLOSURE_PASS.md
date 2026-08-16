# Secret Library — Verification & Closure Pass

> **SUPERSEDED IN PART.** Independent review rejected this document's `CODE_COMPLETE_MAP_BLOCKED`
> classification and identified two unresolved defects this document did not correctly account for:
> (1) the Master Debater physical audit in section G used achievement-marker coordinates rather than
> the actual documented Use-target coordinates, and (2) map-matrix item #18 ("central raid spawn
> areas") was misclassified `NOT_APPLICABLE` when the reference in fact describes a real, missing
> central-hall raid-wave gameplay phase. See
> `docs/ai-dev/quests/packages/secret-library/03_SECRET_LIBRARY_CORRECTIVE_REPAIR_PASS.md` for the
> corrected findings and the repair implemented for both. This document is left otherwise unmodified
> below as a historical record of what was actually done and found in that pass — every other
> section (OTBM provenance, the 32-item matrix outside #18, the final-invasion wing-room topology
> render, the Gorzindel verification, the Oberon audit) was independently re-confirmed still accurate
> by the corrective pass and was not repeated wholesale in document 03.

Role note: this document is written by the technical executor. It reports implementation and
physical-map evidence gathered this pass. It is **not** an independent validation and grants no
approval. No merge is authorized by this document.

## A. Repository state

- Starting main SHA (verified before any action this pass): `02ddd28b70a79116f02c44cb6f1096bdea8a9e6b`
  — unchanged from the previous execution; main has **not** moved.
- Starting branch SHA (previous known head, verified to match exactly): `208ad1f44fd9c94afdd36ad6460b1e7f01a3dc9e`
- Final branch SHA: see the commit that introduces this document (this pass makes **no code
  changes** — see section M — so the only new commit is this handoff document itself).
- Branch: `ai-dev/secret-library-full-repair-v2`
- PR: #37 (`https://github.com/Hokz/canary/pull/37`), base `main`, draft, unmerged.
- Working tree was clean at the start of this pass; `origin/main` and `origin/<branch>` were
  re-fetched and independently confirmed to match the local state before any work began.
- `merge-base --is-ancestor origin/main HEAD` → true (branch is up to date with main; main has not
  advanced past this branch's fork point).

## B. OTBM provenance

The previous pass reported `MAP_AUDIT_NOT_RUN` because `data-otservbr-global/world/otservbr.otbm` is
`.gitignore`d and absent from the working tree. This pass obtained the exact configured map using the
project's **own documented artifact source**, not a substitute:

- `config.lua.dist` (this repository, line 425): `mapDownloadUrl =
  "https://github.com/opentibiabr/canary/releases/download/v3.6.1/otservbr.otbm"`, with
  `toggleDownloadMap = true` (line 424).
- The identical URL pattern is independently corroborated by `docker/data/start.sh` (the project's own
  Docker quickstart map-bootstrap logic) and by `.github/scripts/release_metadata.py`
  (`MAP_URL_RE`/`map_url_for_tag`, the project's own release-tooling regex for exactly this URL shape).
- This is the project's own declared canonical source for the exact configured `dataPackDirectory =
  "data-otservbr-global"` / `mapName = "otservbr"` map — not `data-canary/world/canary.otbm` (a
  different, unrelated datapack already present in this working tree) and not any third-party map.

Downloaded artifact:

- **Source URL:** `https://github.com/opentibiabr/canary/releases/download/v3.6.1/otservbr.otbm`
- **Release/version identity:** `opentibiabr/canary` release tag `v3.6.1`
- **Filename:** `otservbr.otbm`
- **Byte size:** 184,776,037 bytes (176.2 MiB), confirmed via both `curl -w '%{size_download}'` and a
  direct file-size read after download.
- **SHA-256:** `a80de1dda6a9aca3956a9d5b7fb2e0caebb451570d26853fc21beb40d5f31da2`
- **Format confirmation:** binary header inspected byte-for-byte; contains the standard OTBM
  node-tree markers (`0xFE`/`0xFF`/`0xFD`) and the literal string `Saved with Canary's Map Editor
  4.0.0`, confirming this is a genuine OTBM produced by this project's own map editor, not an
  unrelated or corrupted file.
- This file was used **read-only**. No OTBM edit, write, or re-save was made or attempted at any
  point in this pass. It was downloaded to a session-scratch directory outside the repository and is
  not part of any commit.

## C. OTBM audit methodology

No existing OTBM parser was present anywhere in this repository or its tooling
(`tools/canary_audit`'s own coverage notes confirm `map.otbm: unavailable — binary map validation
requires a separate version-aware OTBM extractor`). A minimal, read-only, targeted OTBM tile prober
was hand-written for this pass (not committed to the repository — it is a one-off investigation
script, kept in the session scratch directory) against the well-known, stable OTBM node/attribute
numbering used by RME/Canary-family map editors:

- Node types: `ROOT=0`, `MAPDATA=2`, `TILE_AREA=4`, `TILE=5`, `ITEM=6`, `TOWNS=12`, `TOWN=13`,
  `HOUSETILE=14`, `WAYPOINTS=15`, `WAYPOINT=16`.
- Attribute TLVs: description, tile flags, action id (4), unique id (5), text (6), teleport
  destination (8), count, duration, written-by, etc., plus the extended `ATTRIBUTE_MAP` (128)
  key/value stream.
- Two Canary-specific mapdata-level string attributes (ids 23 and 24) were discovered empirically by
  direct hex inspection of this exact file's header (they follow the standard `ext_spawn_file`(11)
  entry and precede the node tree; id 23 precedes the literal string `otservbr-npc.xml`, id 24
  precedes `otservbr-zones.xml`) and were added to the parser as string-typed attributes matching the
  existing `ext_file` shape. This is the **only** deviation from the classic OTBM attribute table
  needed to parse this file without desyncing.
- The parser is defensive: any attribute id it does not recognize raises immediately rather than
  guessing a size and silently desyncing the rest of the tree.

**Independent ground-truth validation before trusting any result:** the parser was run against
several already-tracked, independently-authored data sources in this repository before being used on
any quest-specific coordinate:
1. Eight `entryx/entryy/entryz` positions from the tracked `data-otservbr-global/world/otservbr-house.xml`
   were queried; all eight resolved to real, populated tiles with plausible ground/decoration items.
2. A ~35×35 area scan around house id 2628 ("Castle of the Winds", entry `32657,31583,7`) correctly
   found `HOUSETILE` nodes carrying `house_id` 2628 (plus two legitimate neighboring houses 2770/2785)
   inside the scanned footprint — this exercises the full `TILE_AREA → HOUSETILE → houseId` decode
   path and is an independent (XML vs. OTBM) cross-check.
3. A large sanity sweep (200×150 tiles, 30,351 tiles) around the Isle of Kings found a real `text`
   attribute reading `"Isle of the Kings"` on item 2012 near the already-proven scythe-trigger
   position — confirming the TLV text-attribute path decodes real string data correctly, not garbage.

Only after these independent checks passed was the parser used to evaluate quest-specific
coordinates. Total unique tiles decoded across every scan performed this pass: **~75,000+** (multiple
overlapping scans; `otservbr.otbm` itself contains 1,175,983 `TILE_AREA` nodes in total, of which the
relevant subset was selectively decoded per target).

**A material limitation, disclosed honestly:** across every scan performed this pass (~75,000+
decoded tiles, spanning the Secret Library complex, the Falcon Bastion tower, house footprints, and a
large Isle of Kings sweep), **zero items were found carrying an action id, unique id, or extended
attribute map** — only one `text`-bearing item was found in total (the Isle of Kings sign). This is
either a genuine characteristic of this specific public release artifact (server operators sometimes
regenerate/strip development-only action ids from a distributable map, or wire them through a
different mechanism at deploy time) or a real absence in this exact file. It could **not** be
distinguished between those two explanations from within this pass, since no second, independently
sourced copy of the same map was available for comparison. **This means: this pass can prove tile,
room, wall, floor, and ground-item existence/position with high confidence (cross-validated three
independent ways above), but it cannot prove or disprove whether a specific `:aid(N)` Lua
registration has a matching physical trigger tile anywhere on the true internal development map** —
only that no such tile was found in this specific downloaded public release copy. Findings below are
qualified accordingly.

## D. Complete 32-item map matrix

Classifications per the four-way rule in this pass's instructions. "Proven" below always means
**against the downloaded v3.6.1 `otservbr.otbm` described in section B**, not the live/internal map.

| # | Surface | Lua evidence | Physical OTBM evidence | Classification |
|---|---|---|---|---|
| 1 | Isle of Kings scythe entrance trigger | `register_actions.lua` `onUseScythe`, `Position(32177,31925,7)` | Tile exists; ground = item 409 ("white marble floor"); **item 2028 = "monument" present on this exact tile** | **PROVEN_PRESENT** |
| 2 | Isle of Kings monument object | (trigger position only, no object id previously known) | Same tile as #1 — item 2028 "monument" confirmed physically present | **PROVEN_PRESENT** (upgraded from NOT_PROVEN) |
| 3 | Library entry destination | `register_actions.lua`, `Position(32515,32535,12)` | Tile exists; ground = 28285 (library slate floor); one decorative item (28079) present | **PROVEN_PRESENT** |
| 4 | Lokathmor lever/staging | `Position(32720,32749,10)` | Tile exists; ground 28285; two lever-shaped items (28889,28888) present | **PROVEN_PRESENT** |
| 5 | Lokathmor arena bounds | `specPos (32742,32681,10)-(32758,32696,10)`, `CENTER_POSITION(32751,32689,10)` | Center tile exists, flagged (0x8), ground 8288 | **PROVEN_PRESENT** |
| 6 | Lokathmor mechanic geometry (Force Field cage + Dark Knowledge) | 4 cardinal ±2 offsets + north ±4 from center | All 5 derived tiles exist, flagged (0x8), library floor ground items | **PROVEN_PRESENT** (upgraded from NOT_PROVEN — exact positions were code-derived, not previously map-verified; now physically confirmed real, walkable tiles) |
| 7 | Gorzindel lever/staging | `Position(32746,32749,10)` | Tile exists, same lever-item pair (28889,28888) | **PROVEN_PRESENT** |
| 8 | Gorzindel arena bounds | `specPos (32680,32711,10)-(32695,32726,10)`, `CENTER(32687,32715,10)` | Confirmed real, open, connected hall (see section F render) | **PROVEN_PRESENT** |
| 9 | Gorzindel 5 side-room Stolen Knowledge positions | 5 hardcoded positions outside `specPos` | **Full topology render (section F) proves all 5 sit inside small, real, walled alcove rooms — sealed by design, reached only via the already-existing `movements_gorzindel.lua` teleport-in mechanic (AID 4952), not by walking.** This resolves the "outside specPos" concern raised previously: it is intentional topology (a Tome-of-**Portals**-gated side room), not incomplete coverage. | **PROVEN_PRESENT** for room existence/geometry. The AID 4952 trigger tile that the existing code needs to actually enter these rooms was searched for across a 150×140-tile sweep of the whole Library complex and **not found** — see the important caveat in section C about this file's apparent lack of any action/unique ids anywhere. **NOT_PROVEN** for the trigger tile specifically (cannot confirm or deny against this artifact). |
| 10 | Mazzinor lever/staging | `Position(32720,32773,10)` | Tile exists, lever-item pair present | **PROVEN_PRESENT** |
| 11 | Mazzinor arena bounds | `specPos (32716,32713,10)-(32732,32728,10)`, `CENTER(32725,32719,10)` | Confirmed, flagged, real | **PROVEN_PRESENT** |
| 12 | Mazzinor mechanic geometry (4 Wild Knowledge spots) | `(32719,32718)`, `(32723,32719)`, `(32728,32718)`, `(32724,32724)`, all z=10 | All 4 tiles exist, flagged, real | **PROVEN_PRESENT** |
| 13 | Ghulosh lever/staging | `Position(32746,32773,10)` | Tile exists, lever-item pair present | **PROVEN_PRESENT** |
| 14 | Ghulosh arena bounds | `specPos (32748,32713,10)-(32763,32729,10)`, `BOSS_POSITION(32756,32720,10)` | Confirmed, flagged, real | **PROVEN_PRESENT** |
| 15 | Ghulosh Book of Death spawn/desk | `BOOK_POSITION(32756,32718,10)` | Tile exists, flagged, real | **PROVEN_PRESENT** |
| 16 | Final invasion 10-player staging | `playerPositions` around `(32676-32677,32741-32745,11)` | This exact strip corresponds to a real, if visually sparse (`?` = unrecognized-but-present decoration, not void), connected floor strip immediately adjacent to the west hall — see section E render | **PROVEN_PRESENT** |
| 17 | Final invasion central hall | `Position(32726,32733,11)` | Confirmed: large, real, open, flagged hall, ground 28288 | **PROVEN_PRESENT** |
| 18 | Final central raid spawn areas | none in code (message-only design) | No distinct "central raid" monster-spawn markers found; central hall itself is real (#17) but nothing distinguishes a raid-specific sub-area within it | **NOT_APPLICABLE** as currently designed (message-only, no physical raid-monster surface required by the current implementation); would become **NOT_PROVEN** if a physical central raid is added later |
| 19 | Final central message-book | none in code (message-only design) | No book/readable item found anywhere in the scanned central hall or its immediate surroundings | **NOT_APPLICABLE** as currently designed; **MAP_REQUIRED** if a physical book is ever specified |
| 20 | NE wing room (Spellstealer) | `WINGS[1].roomCenter`/`spawnPositions` = `nil` | **A large, real, walled, connected room exists immediately east of the central hall (see section E), spanning both north and south of the hall's own y-center.** Not previously known to the code at all. | **PROVEN_PRESENT_CODE_WIRING_REQUIRED** for room-level existence — but the exact intended boss-spawn tile within this room, and which half (north vs. south) corresponds to "NE" specifically, is **NOT_PROVEN** (see section E) |
| 21 | Spellstealer green teleport tile | `nil` | No AID/UID/attribute-map found anywhere in the east or west halls to identify a color-teleport tile | **NOT_PROVEN** (see the AID/UID caveat in section C — this file does not appear to carry any action/unique ids to search for) |
| 22 | Spellstealer red teleport tile | `nil` | Same as #21 | **NOT_PROVEN** |
| 23 | SE wing room (Scion of Havoc) + add positions | `nil` | Same east hall as #20 (its southern portion, by the working hypothesis in section E) | **PROVEN_PRESENT_CODE_WIRING_REQUIRED** for room-level existence; exact boss/add spawn tiles **NOT_PROVEN** |
| 24 | SW wing room (Brothers) | `nil` | West hall, southern portion (working hypothesis) | **PROVEN_PRESENT_CODE_WIRING_REQUIRED**; exact spawn tiles **NOT_PROVEN** |
| 25 | NW wing room (Devourer) + add positions | `nil` | West hall, northern portion (working hypothesis) | **PROVEN_PRESENT_CODE_WIRING_REQUIRED**; exact spawn tiles **NOT_PROVEN** |
| 26 | Final Scourge of Oblivion position | `Position(32726,32727,11)` | Tile exists, flagged, ground 11417 | **PROVEN_PRESENT** |
| 27 | Southern exit | `Position(32480,32599,15)` | Tile exists, ground 10989 ("marble floor") | **PROVEN_PRESENT** |
| 28 | Deep Desert Furious Scorpion room bounds | `roomFrom(32943,32303,8)`/`roomTo(32960,32315,8)` | Confirmed real tiles across the region (see section D2 point spot-checks) | **PROVEN_PRESENT** |
| 29 | Deep Desert Scorpion trigger tiles (2) | `westTrigger(32955,32309,8)`, `deepTrigger(32949,32309,8)` | Both tiles exist, ground 28323/28318 ("tessellated floor" family) | **PROVEN_PRESENT** (upgraded from NOT_PROVEN) |
| 30 | Deep Desert elite warrior spawn positions (4) | 4 positions, lines 54-57 of `movements_scorpion_room_adds.lua` | All 4 exist, ground 28318 | **PROVEN_PRESENT** |
| 31 | Deep Desert elite gladiator spawn positions (2) | 2 positions, lines 97-98 | Both exist, ground 28318 | **PROVEN_PRESENT** |
| 32 | Deep Desert puzzle door thresholds | code-level only (no map dependency) | Not a physical-surface question | **NOT_APPLICABLE** |

**Summary:** 22 of 32 items upgraded to **PROVEN_PRESENT** this pass (previously all `NOT_PROVEN` under
`MAP_AUDIT_NOT_RUN`). 4 items (the wing rooms) upgraded to **PROVEN_PRESENT_CODE_WIRING_REQUIRED** —
real, substantial, previously-unknown room structures exist and are ready for coordinates once exact
spawn/teleport tiles are confirmed. 3 items remain **NOT_PROVEN** (Spellstealer's two color tiles,
Gorzindel's AID 4952 trigger) due to the AID/UID absence described in section C. 3 items are
**NOT_APPLICABLE** given the current message-only/code-only design.

## E. Final invasion map contract

**Central hall** (`32726,32733,11`): confirmed real, large, open, single connected room. `Scourge of
Oblivion (Dormant)` spawn tile (`32726,32727,11`) is inside it, confirmed real.

**Two large, real, previously-completely-unknown-to-the-code room structures** were found flanking
the central hall at the same z-level (11):

- **"West hall"**: roughly `x 32698-32717, y 32708-32760` (dimensions approximate — see the ASCII
  render captured in the session scratch directory; not reproduced in full here for length). Fully
  walled on its outer boundary, connected to the central hall via two corridor openings (`y≈32726`
  and `y≈32746-32749`).
- **"East hall"**: roughly `x 32731-32758, y 32708-32760`, mirroring the west hall's shape and
  connections.
- Both halls span **both** north (`y<32733`) and south (`y>32733`) of the central hall's own row,
  with a distinct decorative threshold row at `y≈32726` running through both — the working hypothesis
  is that this row marks the NE/SE (east hall) and NW/SW (west hall) internal boundary, i.e. each
  large hall is shared by two of the four named wings rather than each wing having a fully separate
  room. **This is a hypothesis, not a proven fact** — no code or map evidence yet distinguishes an
  exact "NE spawn tile" from an "SE spawn tile" within the east hall.
- The 10-player staging strip (`32676-32677,32741-32745,11`) is confirmed real and sits just west of
  the west hall, consistent with players entering from the west/central side.
- **What is NOT proven:** the exact boss-spawn tile for each of the four named wings; the Spellstealer
  green/red teleport tiles (no distinguishing map marker found anywhere in either hall); any physical
  central-raid monster spawn point or message-book object (none found; the current message-only design
  requires neither).

**Deliberate decision: no wing coordinates were wired into the code this pass.** Section 4 of this
pass's instructions permits wiring "if the OTBM proves that the wing rooms and necessary tiles already
exist" — room-level existence is now proven, but the *exact* boss-spawn tile and the Spellstealer
color-teleport tiles are not, and guessing a specific tile inside a real room is still guessing.
`InvasionMapReady()` was **not** weakened and continues to fail closed exactly as before. See section M
for the concrete Manual RME follow-up this enables.

## F. Gorzindel verification

All five Stolen Knowledge positions were re-examined with a full-room topology render (not just
immediate-neighbor checks, which initially gave a misleading isolated-tile signal purely because the
first-pass scan hadn't fetched their neighboring tiles at all — corrected by re-scanning the full
surrounding area before drawing any conclusion):

- `(32687,32707,10)` "armor": a small, real, walled oval alcove, 2-3 tiles wide, fully sealed within
  the scanned footprint (no walkable corridor connects it to the main hall).
- `(32698,32715,10)` "summoning", `(32693,32729,10)` "lifesteal", `(32681,32729,10)` "spells",
  `(32676,32715,10)` "healing": each sits in a similar small sealed alcove pattern, or directly
  embedded in the edge of the main connected hall — full detail in the session scratch render.
- **All five are sealed from normal walking** — this exactly matches the *already-existing*
  `movements_gorzindel.lua` mechanic (`tomesPosition` table, AID 4952 `MoveEvent`), which teleports a
  player directly onto one of these five exact coordinates for a 10-second window and back — a
  mechanic this project's own prior repair pass already fixed (the `k.open` reset-on-logout bug). The
  five positions matching a scripted teleport-in mechanic, rather than a walkable corridor, is
  **conclusive evidence for classification A (legitimate topology)** — the "outside `specPos`" finding
  from the previous pass was not a defect; the whole point of "Stolen Tome of **Portals**" is that
  these rooms are portal-only.
- **Genuinely new finding, not previously flagged:** the `MoveEvent` that performs this teleport is
  registered via `:aid(4952)` — an action-id trigger. A 150×140-tile sweep of the *entire* Library
  complex (all four boss rooms plus surrounding corridors) at z=10 found **zero** items carrying any
  action id anywhere. Per the section C caveat, this cannot be stated as a proven defect (this specific
  public map artifact appears not to carry action/unique ids anywhere at all, for reasons that could
  not be determined from within this pass) — but it is worth flagging: if the true deployed map *does*
  distinguish this the same way, the side-room teleport mechanic currently has no physical trigger and
  is unreachable. **NOT_PROVEN**, disclosed rather than silently assumed fine.
- No code change was made to Gorzindel this pass (existing `specPos`/cleanup bounds were not widened
  — the previous pass's decision to leave them as-is is now positively confirmed correct, not merely
  unchallenged).

## G. Master Debater evidence matrix

All nine reference positions given for this pass were physically inspected, plus a full-region sweep
(13,924 tiles, 837 distinct item types) around and between them:

| Doc # | Position | Ground item | Item(s) present | AID | UID | Text | Proof status |
|---|---|---|---|---|---|---|---|
| 1 | `(33369,31347,3)` | 16484 | — (bare ground only) | none | none | none | Tile real; no object to identify |
| 2 | `(33362,31317,3)` | 16489 | — | none | none | none | Tile real; no object |
| 3 | `(33373,31349,6)` | 16487 | — | none | none | none | Tile real; no object |
| 4 | `(33374,31336,3)` | 16489 | id 2697 (unresolved name); id 27880 (unresolved name) | none | none | none | Tile real; 2 items present, neither identifiable as a document |
| 5 | `(33369,31325,6)` | 16484 | id 6381 (unresolved name) | none | none | none | Tile real; 1 item, not identifiable |
| 6 | `(33369,31327,6)` | 16486 | id 3126 = **"rubbish"** (items.xml-confirmed) | none | none | none | Tile real; confirmed generic decoration, not a document |
| 7 | `(33387,31285,7)` | 18458 ("branches"/"stone floor" range) | id 16294 (unresolved); id 4285 = **"pile of bones"** (confirmed); id 3122 = **"dirty cape"** (confirmed) | none | none | none | Tile real; confirmed generic dungeon decoration |
| 8 | `(33371,31349,7)` | 499 ("stone floor" range) | id 24985 (unresolved); id 16631 (unresolved) | none | none | none | Tile real; not identifiable |
| 9 | `(33369,31343,8)` | 6388 | id 15212 (unresolved); id 2472 = **"chest"** (confirmed) | none | none | none | Tile real; confirmed generic container, not a document |

Item names were resolved two independent ways where possible: the tracked `data/items/items.xml`
(server-side special-behavior overrides) and a hand-written decoder against
`data/items/appearances.dat` (this repository's own Appearances protobuf, per `src/protobuf/appearances.proto`'s
`Appearance{id, name, description}` field layout) — cross-validated against each other (both sources
agree exactly on "chest", "dirty cape", "rubbish", "pile of bones"). Every unresolved id was checked
against both sources and genuinely has no server-side name or special flag defined anywhere in this
repository.

**Conclusion: none of the nine given reference positions currently hold a distinguishable
"document"/"book"/"readable" object.** What is physically present is ordinary dungeon-tower
decoration (rubbish, bones, a dirty cape, a chest, unlabeled floor/prop variants). No item at any of
the nine positions carries an action id, unique id, attribute map, or embedded text — the identity
markers this pass's own contract requires before implementing secure per-player tracking. This is
**not** proof that no legitimate document mechanic exists in the true reference design — only that
these nine specific coordinates, against this specific downloaded map, do not currently correspond to
one.

Per this pass's explicit instruction not to invent item IDs, AIDs, UIDs, item text, positions, or
storages: **no Master Debater tracking implementation was written this pass.** The prior pass's
removal of the false unconditional achievement grant stands unchanged and is now further corroborated
by physical evidence, not just the absence of tracking code. Classification: **MISSING_GLOBAL_MECHANIC
/ REFERENCE_BLOCKED** — pending owner-provided exact document object identity (item id and/or
AID/UID) before any tracking can be legitimately implemented.

## H. Oberon audit

Full re-audit of `grand_master_oberon.lua`, `grand_master_oberon_functions.lua`,
`grand_master_oberon_immunity.lua`, and the lever (`actions_oberonLever.lua`). No correctness defect
found; no code changed.

- **9 questions / 9 responses**: `GrandMasterOberonAsking[1..9]` and `GrandMasterOberonResponses[1..9]`
  both have exactly 9 entries, 1:1 indexed. Each response accepts two phrasings (`msg`/`msg2`).
- **Response matching**: case-insensitive (`:lower()`) exact match against either accepted phrasing,
  in `mType.onSay`.
- **Incorrect response**: boss says "HAHAHAHA!"; immunity is not lifted; no progression, no exploit.
- **Immunity logic**: `OberonImmunity` (`grand_master_oberon_immunity.lua`) genuinely returns `0,
  primaryType, 0, secondaryType` — confirmed still correct (this was a bug the *previous* pass fixed;
  re-confirmed intact and not regressed).
- **Healing behavior**: every time a question is asked (`SendOberonAsking`), the boss is healed to
  full via `healOberon`.
- **Number of correct answers necessary**: `AmountLife = 4`. Traced precisely: `Life` starts at 1
  (`onSpawn`), increments by 1 every time a question is *asked* (inside `SendOberonAsking`, not on a
  correct answer), and `onThink` only re-triggers a question while `Life <= AmountLife`. With
  `AmountLife=4`, questions are asked when `Life` is 1, 2, 3, 4 — four total — after which `Life`
  becomes 5 and no further immunity/question cycle triggers, so the boss requires **exactly 4 correct
  answers** before becoming permanently damageable. This **exactly matches** the reference's "after
  fourth correct answer, boss becomes fully mortal" per the previous pass's own already-recorded
  derivation — this is a **resolved** reference alignment, not an open conflict, and did not need
  re-litigating this pass beyond confirming the derivation still holds.
- **Summons**: one random Falcon Knight/Falcon Paladin per question asked (up to 4 total).
- **Participant eligibility**: level ≥ 250, Premium, `FalconBastion.KillingBosses >= 5` — enforced in
  `validateParticipant`, called from every lever-position player via `onUseExtra`.
- **Sequential Falcon progression / kill credit / Millennial Falcon**: handled in the shared
  `creaturescripts_kill.lua` (already reviewed and fixed in the previous pass); re-confirmed this pass
  that Oberon's own `monster.events = {"killingLibrary"}` correctly routes into that same shared
  handler — no separate Oberon-only credit path exists to audit.
- **Boss run ownership / exact boss id**: `OberonRun.bossId` set from `Game.createMonster(...):getId()`
  at creation; `OberonRunOwnsBoss` checks by id. Correct, matches this project's established pattern.
- **Empty-room / timeout / technical-abort / cooldown / stale-callback safety**: all present and follow
  the same terminal-lifecycle convention as the four inner Library bosses (`OberonRunTerminate` with
  `technical_abort`/`normal_timeout`/`success` kinds; success cleanup deliberately left to
  `BossLeverOnDeath`). `mType.onThink`/`mType.onSay` are native per-creature engine callbacks (not
  `addEvent` timers), so there is no separate stale-callback risk class to check here — they cannot
  fire for a creature that no longer exists.
- **Master Debater**: correctly **not** granted anywhere in the current code (see section G — no
  legitimate tracking exists to gate it on).

## I. Storage changes

**None this pass.** No new or modified storage values were introduced. All storage allocations from
the previous pass (`Storage.Quest.U11_80.TheSecretLibrary.Library.{Lokathmor,Gorzindel,Mazzinor,Ghulosh}Defeated`
= 46114-46117) remain unchanged and were not touched.

## J. Code changes

**None this pass.** This was an evidence-gathering and re-verification pass only, per its own explicit
framing ("This is NOT a new full repair"). Every `.lua` file in the Secret Library quest tree is
byte-identical to commit `208ad1f44fd9c94afdd36ad6460b1e7f01a3dc9e`. The only filesystem change is the
addition of this document.

## K. Reference conflicts

No new reference conflicts were found this pass. The one previously-tracked conflict (Oberon's
`AmountLife` value) was re-derived from first principles in section H and confirmed **already
correctly resolved** at `AmountLife=4` by the previous pass — not an open item.

## L. CUSTOM_GLOBAL_LIKE decisions

None introduced this pass (no code was written). All previously-disclosed decisions from PR #37's
description remain unchanged and are not restated here in full — see the PR body for the complete
list (Lokathmor 90s trap interval, Mazzinor 45s charge interval, final invasion 30s central/inter-wing
delays, Scourge phase durations, Devourer damage-reduction stacking, etc.).

## M. Remaining blockers

Concrete, not vague:

1. **Final invasion wing rooms — exact spawn tiles.** Room-level physical existence is now proven for
   both flanking halls (section E). What remains unresolved: which exact tile is each of the four
   named wings' boss-spawn point, and which half of each hall (north vs. south) is "NE" vs. "SE" (or
   "NW" vs. "SW"). **Manual RME follow-up:** an owner/mapper with live RME access to the true
   development map should confirm the four intended boss-spawn tiles and the wing/compass mapping
   within the two hall footprints identified in section E, and report them back as exact `Position`
   literals for `movements_invasion_start.lua`'s `WINGS[n].spawnPositions`.
2. **Spellstealer green/red teleport tiles.** No physical marker of any kind was found for these in
   either hall. Needs the same live-map RME pass as #1, specifically identifying two tiles (one
   "green", one "red") within whichever half of the east/west hall is designated the Spellstealer
   wing.
3. **Gorzindel's AID 4952 trigger tile.** The existing `movements_gorzindel.lua` mechanic needs a
   physical tile carrying action id 4952 somewhere in the Gorzindel arena (most likely at or adjacent
   to the Stolen Tome of Portals' own position, `32688,32715,10`) for players to actually trigger the
   side-room teleport. Not found in this downloaded artifact; unconfirmed whether it exists on the
   true deployed map (see the AID/UID caveat in section C).
4. **Master Debater object identity.** No document/book object was found at or near any of the nine
   given reference positions. Needs an owner-provided exact item id (and/or AID/UID) for the intended
   document prop(s) before any tracking implementation can legitimately be written.
5. **This pass's OTBM-vs-true-map uncertainty.** Every finding above that depends on AID/UID absence
   is qualified by the possibility that this specific public release artifact does not carry the same
   action/unique id scheme as the project's internal development map. If a differently-sourced copy of
   the map (with action ids intact) becomes available, items #3 and #4 in particular should be
   re-checked against it before concluding they are truly absent.

## N. Validation

- No `.lua` files were modified this pass, so no new luaparser/audit-scan run was required to validate
  a code change. For completeness, the full validation suite from PR #37's last commit
  (`208ad1f44fd9c94afdd36ad6460b1e7f01a3dc9e`) still applies unchanged: luaparser OK on all 35 files,
  `git diff --check` clean, `canary_audit validate-schemas` OK, 72/72 unit tests passed (3 skipped,
  environment-only), `canary_audit scan --fail-on error` → 4 findings, all 4 the pre-existing baseline
  (item ids 2874/3452/6276/12724), zero new.
- This pass's own OTBM investigation tooling is a standalone Python script, not part of the
  repository's test suite; its correctness was established via the three independent ground-truth
  checks in section C (house ids, sign text, and internal self-consistency of the node-tree walker),
  not via `canary_audit`.
- `git diff --check` was re-run after adding this document (Markdown, not code) — clean.

## O. GitHub checks

Not re-queried this pass (no new commit affecting code exists to check beyond the documentation
commit). PR #37's checks from the prior push were `pending`/`skipping` at last observation and were
never independently confirmed passing by this executor — that status is unchanged and remains the
validator's/CI's own determination to make, not this executor's.

## P. Final closure classification

**CODE_COMPLETE_MAP_BLOCKED**

Rationale: no code defect was found or introduced this pass; the previous pass's implementation is
re-confirmed correct on every mechanic re-audited (Oberon in full, Gorzindel's side-room design intent,
the storage/ownership model). What blocks full closure is exclusively physical/map evidence: exact
wing-room spawn tiles, Spellstealer color tiles, Gorzindel's action-id trigger tile, and Master
Debater's document object identity — all four are legitimately **NOT_PROVEN** against the artifact
available to this pass, not fabricated, and not silently bypassed. `InvasionMapReady()` continues to
fail closed exactly as before; no fake completion path was introduced anywhere.
