# 04 — Heart of Destruction Portal / Access Contract

## 1. Quest start → outer vortex access (owner reference layer)

**Owner reference expects:** talk to Messenger of Heaven → gain access progression → travel to one of three rotating vortex locations (Ankrahmun, Svargrond, Zao; rotates ~every 2 hours from server save) → kill 10 themed creatures at that location for **permanent** access to that route → route leads to the corresponding first-tier boss (Ankrahmun→Anomaly, Svargrond→Realityquake, Zao→Rupture).

**Repository evidence:**
- No dialogue exists to gate quest start (see [[01_HOD_NPC_DIALOGUE_CONTRACT]]).
- No globalevent, movement script, or storage anywhere in the `heart_of_destruction` folder implements a rotating multi-city portal. Searched explicitly for "vortex" across all globalevents and for any Heart-of-Destruction-named globalevent file — zero matches.
- No storage or script tracks kills against Dread Intruders, Breach Broods, or Reality Reavers (the three themed creatures named in the owner's reference) anywhere in the quest folder, despite these monsters existing elsewhere in the codebase (`data-otservbr-global/monster/extra_dimensional/`).

**Status: MISSING.**
**Files involved:** none exist for this layer — this is an absence, not a bug in an existing file.
**Storages involved:** none exist for this layer.
**Risk: Critical for reference-parity, but Low for current playability** — the quest is fully playable today without this layer, because access into the boss-room network happens some other way (see §2). This is a "different design was implemented instead" situation, not a "this used to work and broke" situation.
**Safe patch candidate:** none. Building this layer is new-feature implementation (a rotation globalevent, three world-map entry points, a permanent per-player kill-tracked unlock storage), explicitly excluded from this package's safe-fix scope ("new boss room system," "map/teleport placement requiring coordinates not proven").
**Owner gameplay test:** confirm whether, on the live/reference server this project is modeling, players actually experience three separate rotating outdoor entrances — if the intended Canary design was always meant to be simpler (a fixed always-open entrance), this entire "missing" classification may be moot and should be downgraded to "intentionally simplified." This determination requires your input, not code archaeology.

## 2. Actual current entry point (repository evidence)

Not fully traced to a specific outdoor map location in this pass (would require reading the `.otbm` map data or live-server walking, both out of scope for a docs-only audit). What's confirmed: the boss-room network is reached via a fixed, always-available set of step-in teleport tiles (`movements_teleport_heart.lua`, action ids 14320-14354), gated by the storage/cooldown checks below — not by any city-specific rotating portal.

**Status: Implemented (mechanism), UNKNOWN (map entry point).**
**Risk: Low** for the mechanism itself; **Medium** for player-facing confusion if the owner's reference and the actual map don't agree on how players are supposed to first arrive.
**Requires live testing:** yes — walk from a logical starting point (e.g., near Ankrahmun/Svargrond/Zao, or wherever the Messenger of Heaven NPCs are physically placed on the map) to confirm what a player currently encounters.

## 3. Permanent route access via themed-creature kills

**Status: MISSING** — see §1. No storage, no kill-counter, no monster reference exists for this in the quest folder.

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
