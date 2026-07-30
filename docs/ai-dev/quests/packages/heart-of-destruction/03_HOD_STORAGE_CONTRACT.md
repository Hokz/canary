# 03 — Heart of Destruction Storage Contract

Full inventory of every storage/state mechanism found referencing Heart of Destruction, across both this session and the prior gap-analysis session. Each entry includes files involved, scope (per-player vs. world-scoped), and risk.

**HOD-04 note**: no new storage was added by the Messenger of Heaven dialogue implementation. A full trace confirmed no existing portal/access code (see [[04_HOD_PORTAL_ACCESS_CONTRACT]]) expects a storage from this NPC — the entire inventory below is unchanged by HOD-04.

**HOD-05 update — 4 storages now centrally registered (values unchanged)**: `14334` (Hunger team flag), `14335` (Destruction team flag), `14336` (Rage team flag), and `14337` (reward-claimed flag) were verified to have **zero action-id/unique-id collisions** anywhere in the quest folder (unlike most of the range documented in §3 below, which is heavily dual-use). They are now registered as `Storage.HeartOfDestructionFinalBattle.{HungerTeam,DestructionTeam,RageTeam,RewardClaimed}` in `storages.lua`, and the 4 consuming files (`actions_final_lever.lua`, `actions_reward.lua`, `creaturescripts_devourer_player_death.lua`, `movements_teleport_heart.lua`) now reference the named constants instead of bare numbers. This was a pure naming/registry change — **no runtime value changed**, confirmed by grepping for any remaining bare `14334`-`14337` reference in executable code (none found; only an updated informational comment remains).

**HOD-05 investigation — why the rest of the 14320-14354 range was NOT touched**: every other number in this range was checked for the same collision-free property that made 14334-14337 safe to register, and all of them fail it — e.g., `14320` is simultaneously a lever action id (`actions_charges_lever.lua:aid(14320)`) and a storage key (granted by `creaturescripts_overcharge_death.lua`), and this dual-use pattern repeats for `14321`, `14322`/`14323`, `14325`, `14326`, `14328`, `14332`. Registering these under clean single-purpose names in `storages.lua` without first resolving the dual-use collision would misrepresent what the number actually means in context — that's a larger migration (renumbering one of the two conflicting uses), explicitly excluded from this package's "small local constant, no broad migration" scope. Deferred to a future package if the owner wants this properly untangled.

## 1. Centrally registered — `GlobalStorage.HeartOfDestruction` (world-scoped)

`data-otservbr-global/lib/core/storages.lua:3040-3054`, range 60172-60190 (60172-60183 used, 60184-60190 unused headroom).

| Key | Value | Used in | Purpose |
|---|---|---|---|
| `ChargedAnomaly` | 60172 | `actions_anomaly.lua` | Anomaly boss-internal mechanic reset |
| `ForeshockHealth` | 60173 | `actions_foreshock.lua` | Realityquake phase-1 health tracking |
| `AftershockHealth` | 60174 | `actions_foreshock.lua` | Realityquake phase-2 health tracking |
| `ForeshockStage` | 60175 | `actions_foreshock.lua` | Realityquake phase-1 stage |
| `AftershockStage` | 60176 | `actions_foreshock.lua` | Realityquake phase-2 stage |
| `RuptureResonanceStage` | 60177 | `actions_rupture.lua` | Rupture resonance mechanic stage |
| `RuptureResonanceActive` | 60178 | `actions_rupture.lua` | Rupture resonance mechanic active flag |
| `EradicatorWeak` | 60179 | `actions_eradicator.lua` | Eradicator weak-phase flag |
| `EradicatorReleaseT` | 60180 | `actions_eradicator.lua` | Eradicator release timer |
| `OutburstStage` | 60181 | `actions_outburst.lua` | Outburst mechanic stage |
| `OutburstHealth` | 60182 | `actions_outburst.lua` | Outburst health tracking |
| `OutburstChargingKilled` | 60183 | (referenced by outburst mechanic chain; not directly observed in the files read this pass) | Outburst charging-add kill tracking |

**Status: Implemented, correctly registered.** **Scope: World-scoped by design** (`Game.setStorageValue`/`Game.getStorageValue`) — appropriate here since each of these keys tracks *one active boss encounter's* internal state, and the room/zone system (via `BossLever`'s `Zone("boss."..name)` occupancy check) already prevents two concurrent fights of the *same* boss. **Risk: Low** for this specific block — the single-instance-per-boss assumption is enforced elsewhere (`BossLever:onUse` rejects a second party while `zone:countPlayers() > 0`).

## 2. `Storage.Quest.U10_94.HeartOfDestruction` — HOD-FULL: now populated

Previously reserved and empty (range 45351-45450). **HOD-FULL populated it** with 9 new per-player storages:

| Key | Value | Purpose |
|---|---|---|
| `CaveAccess` | 45351 | Granted on completing Messenger of Heaven's conversation; gates all 3 vortex entrances |
| `AnkrahmunKills` | 45352 | Dread Intruder kills, 0-10 |
| `AnkrahmunPermanent` | 45353 | Anomaly route permanently unlocked |
| `SvargrondKills` | 45354 | Breach Brood kills, 0-10 |
| `SvargrondPermanent` | 45355 | Realityquake route permanently unlocked |
| `ZaoKills` | 45356 | Reality Reaver kills, 0-10 |
| `ZaoPermanent` | 45357 | Rupture route permanently unlocked |
| `DestructiveCharges` | 45358 | 0-5, spent 5-at-a-time on World Devourer repeat entry |

All within the documented reserved range (45351-45450), all newly minted (no collision with anything). **Status: Implemented.** **Risk: Low** — clean, unused numbers, no dual-use concern (these are new, not renumbered legacy values).

Also added: `GlobalStorage.HeartOfDestruction.ActiveVortex = 60184` (world-scoped, within the already-reserved 60172-60190 headroom) — the rotating vortex indicator, added to `startupGlobalStorages` so it initializes cleanly on server boot.

## 3. NOT centrally registered — raw magic numbers, `14320`-`14354`

**None of these appear anywhere in `storages.lua`.** Full map, reconstructed from reading every file that references them:

| Number | Meaning | Set in | Read in | Scope |
|---|---|---|---|---|
| 14320 | Anomaly lever action id / Anomaly access-granted flag (dual use) | `creaturescripts_heart_boss_death.lua` (`setStorage`, after Anomaly dies) | `movements_teleport_heart.lua` (portal check) | Per-player (area-grant, see §4 risk) |
| 14321 | Charges lever action id / Overcharge kill counter (dual use — same number used as both an action id in `actions_charges_lever.lua:aid(14320)`'s `pushPos` config **and** as `Game.setStorageValue(14321, 0) -- Overcharge Count`) | `actions_charges_lever.lua` | `creaturescripts_overcharge_death.lua` | **World-scoped** (`Game.*`) |
| 14322 | Rupture access-granted flag / Charger Exit teleport id (dual use) | `creaturescripts_heart_boss_death.lua` | `movements_teleport_heart.lua` | Per-player (area-grant) |
| 14323 | Realityquake access-granted flag / Depolarized Cracklers Count (dual use) | `creaturescripts_heart_boss_death.lua`; also `Game.setStorageValue(14323, 0)` in `actions_cracklers_lever.lua` | `movements_teleport_heart.lua`; `creaturescripts_depolarized_death.lua` | Mixed — per-player grant AND world-scoped counter share this number |
| 14324 | Anomaly Exit teleport id | `movements_teleport_heart.lua` | — | Teleport-only |
| 14325 | Main Room teleport id / boss.actionId assigned post-kill (dual use across multiple bosses) | `creaturescripts_heart_boss_death.lua` (`bosses` table `actionId = 14325` for anomaly/rupture/realityquake) | `movements_teleport_heart.lua` | Teleport-only |
| 14326 | Cracklers lever action id / Anomaly-defeated flag (dual use) | `actions_cracklers_lever.lua:aid`; `creaturescripts_heart_boss_death.lua` (`bosses.anomaly.storage`) | `movements_teleport_heart.lua` (Eradicator/Outburst gate, `storage1`) | Mixed |
| 14327 | Rupture-defeated flag | `creaturescripts_heart_boss_death.lua` (`bosses.rupture.storage`) | `movements_teleport_heart.lua` (`storage2`) | Per-player (area-grant) |
| 14328 | Sparks lever action id / Realityquake-defeated flag (dual use) | `actions_sparks_lever.lua:aid`; `creaturescripts_heart_boss_death.lua` (`bosses.realityquake.storage`) | `movements_teleport_heart.lua` (`storage3`) | Mixed |
| 14330 | Eradicator-defeated flag | `creaturescripts_heart_boss_death.lua` (`bosses.eradicator.storage`) | `movements_teleport_heart.lua` (World Devourer gate) | Per-player (area-grant) |
| 14332 | Outburst-defeated flag / Final lever action id (dual use) | `creaturescripts_heart_boss_death.lua` (`bosses.outburst.storage`); `actions_final_lever.lua:aid` | `movements_teleport_heart.lua` (World Devourer gate) | Mixed |
| 14334, 14335, 14336 | Per-player "which sub-arena am I in" flags (Hunger/Destruction/Rage) during the World Devourer approach | `actions_final_lever.lua` | `actions_final_lever.lua`, `movements_teleport_heart.lua` (exit cleanup) | Per-player — **HOD-05: now `Storage.HeartOfDestructionFinalBattle.{HungerTeam,DestructionTeam,RageTeam}`** |
| 14337 | Reward chest claimed flag | `actions_reward.lua` | `actions_reward.lua` | Per-player — **HOD-05: now `Storage.HeartOfDestructionFinalBattle.RewardClaimed`** |
| 14340-14354 | Exit/main-room teleport ids (no game-state meaning, pure navigation) | `movements_teleport_heart.lua` | `movements_teleport_heart.lua` | Teleport-only |

**Status: Implemented but unregistered.** **Risk: Medium-high.** Two concrete problems beyond "not in the central file":
1. **Numbers are reused for two unrelated purposes** (action id vs. storage key) in at least 5 cases (14321, 14322/14323, 14325, 14326, 14328, 14332) — this works today because action ids and storage values are read through different APIs (`item.actionid` vs. `getStorageValue`), but it's exactly the kind of collision-prone pattern [[04_QUEST_STORAGE_REGISTRY]] Rule 1 exists to prevent, and makes future maintenance error-prone.
2. **Boss-defeat flags (14320/14322/14323/14326/14327/14328/14330/14332) are granted by room-presence-at-death, not by tracked participation** — see [[05_HOD_BOSS_MECHANICS_CONTRACT]] for the gameplay implication.

## 4. Undeclared Lua globals (not storage at all — process-memory only)

Confirmed via direct code reading, **no `local` keyword anywhere in the declaring file** for each of these:

| Variable(s) | File(s) | Purpose |
|---|---|---|
| `spawningCharge`, `areaHeart1`, `areaHeart2`, `areaHeart3` | `actions_charges_lever.lua` | Room-clear timers, spawn-in-progress flag |
| `cracklerTransform`, `vortexPositions`, `areaCrackler1`, `areaCrackler2` | `actions_cracklers_lever.lua`, `movements_vortex_crackler.lua` | Polarity-tile puzzle state, room-clear timers |
| `unstableSparksCount`, `areaSparks1`-`areaSparks4`, `pid`, `isInGhostMode` | `actions_sparks_lever.lua` | Spark spawn-cycle counter, room-clear timers; `pid`/`isInGhostMode` appear to be used as call arguments without ever being assigned anywhere in this file |
| `sparkSpawnCount`, `devourerBossesKilled`, `theHungerKilled`, `theDestructionKilled`, `theRageKilled`, `hungerSummon`, `rageSummon`, `destructionSummon`, `devourerSummon`, `areaDevourer1`-`areaDevourer6` | `actions_final_lever.lua` | World Devourer multi-team encounter state |
| `hungerSummon`, `devourerSummon` | `movements_vortex_hunger.lua` | Summon-count adjustments (reads/writes the same names as `actions_final_lever.lua` above) |

**Status: Implemented, functioning (empirically, since the quest is playable), but architecturally fragile.**
**Risk: High.** These are not `GlobalStorage` (which is at least a documented, intentional, persisted mechanism) — they are raw Lua interpreter globals. Specific concerns:
- **Not persisted** across server restarts, unlike storage — mid-encounter state is lost on any restart.
- **Not namespaced** — nothing prevents an unrelated script from declaring a global with the same name (e.g., `pid`, `areaDevourer1` are generic-sounding names).
- **Cross-file coupling is implicit** — e.g., `hungerSummon`/`devourerSummon` are written in `actions_final_lever.lua` and read/decremented in `movements_vortex_hunger.lua`, with no explicit contract between the two files beyond "hope both are loaded and the name matches exactly."
- Confirms and generalizes the exact risk pattern already flagged in [[03_QUEST_ISSUE_599_FIX_AUDIT]] Bug 3 for this same quest.

**Not a safe fix in this package** — converting these to proper local/persisted state touches the coordination logic across 4+ interacting files per puzzle room; a careless conversion could silently break the cross-file signaling. This is explicitly excluded by the package rules ("large mechanical rewrites," "full boss mechanic rewrites").

## 5. Modern, correctly-implemented pattern — KV-backed boss cooldowns

`player:canFightBoss(name)` / `player:setBossCooldown(name, expiry)`, backed by `player:kv():scoped(...)` (see [[01_QUEST_ARCHITECTURE_AUDIT]] §8). Used consistently across `actions_foreshock.lua`, `actions_devourer_access.lua`, `actions_final_lever.lua`, `movements_teleport_heart.lua`, and internally by every `BossLever`-registered boss (`data/libs/functions/boss_lever.lua:250`). **Status: Implemented correctly.** **Risk: Low** — this is the one storage-adjacent mechanism in this quest that fully follows the modern, per-player, documented pattern.

## Summary table

| Storage class | Status | Risk | Safe to fix this package? |
|---|---|---|---|
| `GlobalStorage.HeartOfDestruction.*` | Implemented | Low | N/A — not broken |
| `Storage.Quest.U10_94.HeartOfDestruction` | Reserved, empty | Medium (missing content) | No — needs owner reference text |
| `Storage.HeartOfDestructionFinalBattle.*` (14334-14337) | **Registered HOD-05** | Low | N/A — done |
| Remaining raw `14320-14332`/14340-14354 range | Implemented, unregistered | Medium-high | No — dual-use collisions (action id vs. storage key), needs careful live-tested migration |
| Undeclared Lua globals | Implemented, fragile | High | No — large, cross-file, excluded by package rules |
| Boss cooldown KV | Implemented | Low | N/A — not broken |
