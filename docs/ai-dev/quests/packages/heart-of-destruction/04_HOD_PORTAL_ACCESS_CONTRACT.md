# 04 — Heart of Destruction Portal / Access Contract

## HOD-FULL update — outer vortex system implemented (code complete, map placement pending)

The rotating vortex + permanent-access system previously documented as entirely missing (§1, §3 below) is now **implemented in full on the code side**. This is the single largest change in the HOD-FULL package. Summary:

- **Rotation**: `globalevents_vortex_rotation.lua` — a world-scoped `GlobalStorage.HeartOfDestruction.ActiveVortex` (1=Ankrahmun, 2=Svargrond, 3=Zao) rotates randomly every 2 hours, with a startup handler that picks an initial value on server boot.
- **Permanent access**: `creaturescripts_vortex_route_kills.lua` — registered on `Dread Intruder`, `Breach Brood`, and `Reality Reaver` (via a new `monster.events` entry added to each of their definition files under `data-otservbr-global/monster/extra_dimensional/`), tracking per-player kills (0-10) and granting a permanent per-route unlock flag at 10.
- **Entry gating**: `movements_vortex_route_entrances.lua` — a step-in movement keyed to three new action ids (see MAP SETUP below), checking `CaveAccess` (from Messenger of Heaven — see [[01_HOD_NPC_DIALOGUE_CONTRACT]]) and then either permanent access or the currently-active rotation, teleporting the player to that route's existing minigame room entrance.
- **New storages**: all under `Storage.Quest.U10_94.HeartOfDestruction` (previously reserved, empty) — see [[03_HOD_STORAGE_CONTRACT]].

### ⚠️ MAP SETUP REQUIRED — this cannot be completed without a map editor

The code above is fully written and internally consistent, but **three physical map locations do not exist yet** — nothing in this repository can place them; they require a human with the map editor. Until this is done, the vortex system is inert (dead code, safe, but non-functional).

| # | What | Required action id | Behavior once placed | Destination (already real, in-game coordinates) |
|---|---|---|---|---|
| 1 | Vortex entrance tile/item **north of Ankrahmun** | `14361` | Step-in teleport, gated by `CaveAccess` + (permanent access or active rotation = Ankrahmun) | `Position(32093, 31327, 12)` — adjacent to the existing, working Anomaly-path Charges lever room |
| 2 | Vortex entrance tile/item **northwest of Zao Steppe** | `14362` | Same, gated for the Zao/Rupture route | `Position(32081, 31313, 13)` — adjacent to the existing Cracklers lever room |
| 3 | Vortex entrance tile/item **southwest of Svargrond** | `14363` | Same, gated for the Svargrond/Realityquake route | `Position(32229, 31343, 11)` — adjacent to the existing Sparks lever room |

**What the map editor needs to do**: place a usable tile or item (a "vortex" graphic, if one exists in the sprite set — otherwise any walkable/steppable tile) at each of the three approximate real-world locations above, and set its **action ID** to the corresponding number in the table. No unique ID, no separate destination teleport item is needed — the destination is handled entirely in script (`movements_vortex_route_entrances.lua`), keyed only off the action id. The exact tile position within "north of Ankrahmun" / "northwest of Zao Steppe" / "southwest of Svargrond" is intentionally not more specific than the owner's own reference — pick a sensible spot; the script doesn't care exactly where, only that the action id matches.

**The three destination positions are NOT placeholders** — they were taken from this repository's already-existing, already-working lever room entrances (documented in earlier HOD packages), so no map work is needed on the destination side, only the three entrance points above.

### Design decision: no separate "cave" step

The owner's reference describes talking to Messenger of Heaven granting access to "a cave near the NPC with a Glowing Vortex," implying a possible fourth, intermediate location before reaching the three city vortexes. **This was deliberately simplified**: rather than invent a fourth unmapped location, `CaveAccess` (granted by finishing the Messenger of Heaven conversation) directly gates all three city vortex entrances. This preserves the functional requirement ("must talk to Messenger of Heaven first") without fabricating an additional unmapped position. If the owner has an exact location for the cave itself, a follow-up can insert it as a literal fourth gate between Messenger of Heaven and the three vortexes.

## HOD-03 update — expanded reference detail

The owner's fuller reference (this pass) adds precise directional detail not previously available:
- **Ankrahmun**: enter via the vortex **north of Ankrahmun** → Anomaly path.
- **Svargrond**: enter via the vortex **southwest of Svargrond** → Realityquake path.
- **Zao**: enter via the vortex **northwest of Zao Steppe** → Rupture path.
- Access requires killing **10 creatures in that vortex region** to pass through once; **permanent** access to a route requires killing 10 creatures **from each respective location** (i.e., the one-time 10-kill unlock is per-route, not shared).
- After the Messenger of Heaven conversation, the player should be able to access **a cave near the NPC with a Glowing Vortex** — this is the very first gate, before the three rotating city vortexes even come into play.
- Confirms a **"central HUB"**: after defeating Anomaly, Rupture, and Realityquake, Eradicator and Outburst become accessible "through the central HUB teleport" — this matches the `movements_teleport_heart.lua` "Main Room" teleport (action id 14325) already found in HOD-02, now confirmed to be this HUB.
- Explicit tactical note (not a bug, gameplay advice): *"It is recommended to kill the active vortex boss so the team can do 3 bosses in one trip."* — implies the *active* rotating vortex's boss should be prioritized since its access is time-limited to the current 2-hour rotation window, while the other two routes (once permanently unlocked via the 10-kill requirement) remain reachable regardless of rotation. This only makes sense if permanent unlock and the rotation are two separate, coexisting mechanics — reinforcing that both the rotation AND the per-route 10-kill permanent-unlock are intended as real, separate systems, not alternatives to each other.

None of this changes the core finding from HOD-02: **the vortex rotation, the cave/Glowing Vortex first gate, and the 10-kill permanent-access system still do not exist anywhere in the current codebase.** The extra detail sharpens what a future implementation needs to build, but doesn't change the missing/implemented classification.

## HOD-04 update — confirmed no storage gate exists between Messenger of Heaven and the boss network

This package needed to determine (per investigation requirements 5-8 of the HOD-04 task) whether any existing portal/access code expects a storage flag that Messenger of Heaven's dialogue should set. Full trace of the storage chain, confirming **no such expectation exists**:

- The first-tier boss portals (`movements_teleport_heart.lua`, action ids `14323`/`14342`/`14344` for Anomaly/Rupture/Realityquake) check storages `14320`/`14322`/`14324` respectively, plus `player:canFightBoss(...)`.
- Those three storages are **not** set by any NPC — they're granted by completing each path's own pre-boss minigame: `creaturescripts_overcharge_death.lua` grants `14320` after 5 Overcharge kills (Anomaly path), and the equivalent completion handlers for the Cracklers (Rupture) and Sparks (Realityquake) minigames grant `14322`/`14324` the same way (see [[03_HOD_STORAGE_CONTRACT]] and [[05_HOD_BOSS_MECHANICS_CONTRACT]] for the full minigame chain).
- Physical entry into those minigame rooms (i.e., reaching and using the `actions_charges_lever.lua`/`actions_cracklers_lever.lua`/`actions_sparks_lever.lua` lever items) is gated **only by map geography** — whether a player can walk to the lever's position — not by any storage check in those action files.

**Conclusion: the entire boss-progression chain is self-contained and storage-gates itself from the first minigame onward. Nothing in current code reads a storage that Messenger of Heaven could plausibly be expected to write.** This confirms HOD-04's dialogue-only implementation was the correct choice (package rule 7 — "if exact storage behavior is unclear, implement dialogue only and document access-storage as deferred"; here it wasn't even unclear, it was clearly absent). If the missing outer layer (cave/Glowing Vortex, rotating city vortexes, 10-kill permanent access — see §1 below) is ever built, **that** is where a Messenger-of-Heaven-granted storage would naturally belong, gating the player's first walk into the cave rather than anything already implemented today.

## 1. Quest start → outer vortex access (owner reference layer)

**Owner reference expects:** talk to Messenger of Heaven → gain access progression → travel to one of three rotating vortex locations (Ankrahmun, Svargrond, Zao; rotates ~every 2 hours from server save) → kill 10 themed creatures at that location for **permanent** access to that route → route leads to the corresponding first-tier boss (Ankrahmun→Anomaly, Svargrond→Realityquake, Zao→Rupture).

**Repository evidence:**
- No dialogue exists to gate quest start (see [[01_HOD_NPC_DIALOGUE_CONTRACT]]).
- No globalevent, movement script, or storage anywhere in the `heart_of_destruction` folder implements a rotating multi-city portal. Searched explicitly for "vortex" across all globalevents and for any Heart-of-Destruction-named globalevent file — zero matches.
- No storage or script tracks kills against Dread Intruders, Breach Broods, or Reality Reavers (the three themed creatures named in the owner's reference) anywhere in the quest folder, despite these monsters existing elsewhere in the codebase (`data-otservbr-global/monster/extra_dimensional/`).

**Status: HOD-FULL — code implemented, map placement pending.** See the MAP SETUP section above.
**Files involved:** `globalevents_vortex_rotation.lua`, `movements_vortex_route_entrances.lua`, `creaturescripts_vortex_route_kills.lua`, plus `monster.events` additions to the 3 `extra_dimensional` monster files.
**Storages involved:** `Storage.Quest.U10_94.HeartOfDestruction.{CaveAccess,AnkrahmunKills,AnkrahmunPermanent,SvargrondKills,SvargrondPermanent,ZaoKills,ZaoPermanent}`, `GlobalStorage.HeartOfDestruction.ActiveVortex`.
**Risk: Medium** — new code, not yet live-tested, and functionally inert until the 3 action ids are placed on the map. Once placed, this changes how players first enter the quest (previously: walk directly to a lever room; now: gated by Messenger of Heaven + vortex rotation/permanent access) — recommend thorough live testing before this is the only entry path relied upon.
**Owner gameplay test:** once the 3 action ids are placed, confirm each vortex correctly denies entry when inactive/no permanent access, correctly teleports when active or permanently unlocked, and that the rotation actually changes which vortex is active every ~2 hours.

## 2. Actual current entry point (repository evidence)

Not fully traced to a specific outdoor map location in this pass (would require reading the `.otbm` map data or live-server walking, both out of scope for a docs-only audit). What's confirmed: the boss-room network is reached via a fixed, always-available set of step-in teleport tiles (`movements_teleport_heart.lua`, action ids 14320-14354), gated by the storage/cooldown checks below — not by any city-specific rotating portal.

**Status: Implemented (mechanism), UNKNOWN (map entry point).**
**Risk: Low** for the mechanism itself; **Medium** for player-facing confusion if the owner's reference and the actual map don't agree on how players are supposed to first arrive.
**Requires live testing:** yes — walk from a logical starting point (e.g., near Ankrahmun/Svargrond/Zao, or wherever the Messenger of Heaven NPCs are physically placed on the map) to confirm what a player currently encounters.

## 3. Permanent route access via themed-creature kills

**Status: HOD-FULL — implemented.** `creaturescripts_vortex_route_kills.lua` tracks per-player kills of Dread Intruder (Ankrahmun), Breach Brood (Svargrond), and Reality Reaver (Zao), granting permanent route access at 10 kills each. **Caveat**: these three monsters have no existing spawn anywhere on the map (confirmed — they're defined but unplaced), so this is currently unreachable content until spawns are added. This is a separate, smaller map task from the vortex entrance placement above — spawn locations were not specified by the owner's reference beyond "in that vortex region," so exact spawn points are left to the map editor's judgment near each city's vortex entrance.

## 4. First-tier boss lever access (Anomaly / Rupture / Realityquake)

**Implemented**, via `BossLever` (Anomaly, Rupture) and directly via `actions_foreshock.lua`'s `BossLever` config (Realityquake, internally named "Foreshock"). Each lever:
- Requires the pulling player to physically stand at an exact `pushPos`/lever position.
- Checks `zone:countPlayers() > 0` to reject a second party while one fight is active (per-boss, via `BossLever:getZone()` → `Zone("boss."..name)`).
- Applies the 20-hour cooldown automatically via `lever:setCooldownAllPlayers` (`boss_lever.lua:250`) to all participants at engage time.

**Files:** `actions_anomaly.lua`, `actions_rupture.lua`, `actions_foreshock.lua`.
**Storages:** none directly (cooldown is KV-backed per §5 of the storage contract; `GlobalStorage.HeartOfDestruction.*` for in-fight mechanics only).
**Risk: Low.** This layer is solid — matches the reference's implied "boss room access gated by lever + cooldown" model closely.

## 5. Second-tier unlock (Eradicator, Outburst)

**Implemented** via `movements_teleport_heart.lua:78-87` — both portals require `storage1`/`storage2`/`storage3` (14326/14327/14328 — the three first-tier defeat flags) to all be `>= 1`, plus the player's own cooldown to be clear for that specific boss.

**Files:** `movements_teleport_heart.lua`, `creaturescripts_heart_boss_death.lua` (grants the flags).
**Storages:** 14326, 14327, 14328 — see [[03_HOD_STORAGE_CONTRACT]] §3.
**Status: Implemented, matches reference structurally** ("later bosses become accessible after progression through the first boss stage").
**Risk: Medium** — not because the gating logic is wrong, but because of *how* the flags are granted: `creaturescripts_heart_boss_death.lua`'s `setStorage()` grants the flag to **every player physically standing in the room's bounding box at the moment the boss dies**, not to players who tracked meaningful participation. A player who wandered in at the last second gets full credit for Eradicator/Outburst access; a player who did the whole fight but stepped one tile outside the box at the wrong moment gets nothing.
**Safe patch candidate:** none in this package — fixing participation tracking would require redesigning how `heartBossDeath.onDeath` attributes credit, which touches core boss-mechanic logic across all three first-tier bosses simultaneously. Excluded by "do not change boss mechanics unless clearly proven by current code + reference" (the reference doesn't specify credit-attribution rules, so there's nothing to prove the *correct* behavior against).
**Requires live testing:** yes, to confirm whether this is a real practical problem (e.g., does the room's bounding box tightly match the actual playable arena, making "wandering in accidentally" implausible?) or a theoretical one.

## 6. Final unlock (World Devourer)

**Implemented** via `movements_teleport_heart.lua:88-97` — requires both 14330 (Eradicator defeated) and 14332 (Outburst defeated) `>= 1`, plus `player:canFightBoss("World Devourer")`.

**Status: Implemented, matches reference.** **Risk: Low** for the gating logic itself. The cooldown *duration* was already corrected in PR #4 (HOD-01); confirmed present on this branch (inherited from `main`, verified via `git log` showing `4114e4e77`/`baba6c0d7` in this branch's history — not reapplied, per your instruction).

**HOD-05 re-verification (per its explicit investigation checklist)**:
- ✅ Enforces cooldown — `player:canFightBoss("World Devourer")` check confirmed present.
- ✅ Checks Eradicator + Outburst completion — storages 14330/14332 confirmed checked.
- ❌ Does **not** check "5 destructive charges" — confirmed absent, correctly so, since that mechanic doesn't exist anywhere in the codebase (see [[05_HOD_BOSS_MECHANICS_CONTRACT]]). Adding a charges check here without the corresponding kill-tracking/spend system would lock every player out of World Devourer entirely — explicitly avoided.
- ✅ Devourer Core bypass supported — via the separate `actions_devourer_access.lua` action (item 23686), not through this portal file; confirmed unchanged since HOD-03.

No code change was needed or made to this file in HOD-05 — the existing checks are correct for what currently exists in the quest.

## Summary table

| Component | Status | Risk | Files | Storages | Live testing needed? |
|---|---|---|---|---|---|
| Messenger of Heaven quest start | Missing | High (ref-parity) / Low (playability) | `messenger_of_heaven.lua` | none | No — static absence |
| Rotating vortex (3 cities) | Missing | Critical (ref-parity) / Low (playability) | none exist | none exist | Yes, to confirm intended design with owner |
| 10-kill permanent access | Missing | Critical (ref-parity) / Low (playability) | none exist | none exist | Yes, same as above |
| Fixed boss-network entry | Implemented (mechanism) | Low / Medium (map clarity) | `movements_teleport_heart.lua` | 14320-14354 | Yes, to map actual entry point |
| First-tier lever access | Implemented | Low | `actions_anomaly.lua`, `actions_rupture.lua`, `actions_foreshock.lua` | KV cooldown | No |
| Second-tier unlock (Eradicator/Outburst) | Implemented, credit-attribution risk | Medium | `movements_teleport_heart.lua`, `creaturescripts_heart_boss_death.lua` | 14326/14327/14328 | Yes, to confirm practical impact |
| Final unlock (World Devourer) | Implemented | Low | `movements_teleport_heart.lua` | 14330/14332 + KV cooldown | No |
