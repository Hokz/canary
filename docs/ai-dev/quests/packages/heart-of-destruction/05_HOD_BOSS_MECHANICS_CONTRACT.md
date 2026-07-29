# 05 — Heart of Destruction Boss Mechanics Contract

**Correction notice**: an earlier same-session investigation pass initially suspected that only Realityquake had a working cooldown, based on seeing an explicit `setBossCooldown` call in `actions_foreshock.lua` and no equivalent explicit call in the other four first-tier/second-tier boss lever files. Reading `data/libs/functions/boss_lever.lua` in full disproved this: **`BossLever:onUse()` unconditionally applies a cooldown to every participant for every boss registered through it** (line 250: `lever:setCooldownAllPlayers(self.name, os.time() + self.timeToFightAgain)`), using the server's configured default (`bossDefaultTimeToFightAgain = 20 * 60 * 60`, confirmed in `config.lua.dist:607`) unless a boss's config overrides `timeToFightAgain`. Realityquake's explicit call is redundant, not compensating for a gap. This contract reflects the corrected understanding.

## Per-boss table

| Boss | Access mechanism | Cooldown | Room player limit | Time limit | Cleanup on fail/timeout | Status | Risk |
|---|---|---|---|---|---|---|---|
| Anomaly | `BossLever`, `actions_anomaly.lua` | 20h, automatic via `BossLever` | 5 (`playerPositions`, 5 entries) | `BossLever` default `timeToDefeat` (config-driven, not overridden here — see note below) | `BossLever`'s built-in zone timeout (`zn:refresh(); zn:removePlayers()`) | Implemented | Low |
| Realityquake ("Foreshock"/"Aftershock") | `BossLever`, `actions_foreshock.lua` | 20h, automatic + redundant explicit call | 5 | Same as above | Same as above | Implemented | Low |
| Rupture | `BossLever`, `actions_rupture.lua` | 20h, automatic | 5 | Same as above | Same as above | Implemented | Low |
| Eradicator | `BossLever`, `actions_eradicator.lua` | 20h, automatic | 5 | Same as above | Same as above | Implemented | Low |
| Outburst | `BossLever`, `actions_outburst.lua` | 20h, automatic | 5 | Same as above | Same as above | Implemented | Low |
| World Devourer | Hand-rolled, `actions_final_lever.lua` (not `BossLever`) | 13d20h, fixed in PR #4 (confirmed present on this branch) | 3 columns × 5 positions = up to 15 across 3 sub-arenas, converging to 1 final fight | 30 min per sub-arena (`30 * 60000`); sub-arenas cycle every 30s via `changeArea` | Hand-rolled `clearHunger`/`clearDestruction`/`clearRage`/`clearDevourer`, each teleporting players out and removing monsters | Implemented | Medium (see below) |

## `BossLever`'s generic room rules (applies to Anomaly, Realityquake, Rupture, Eradicator, Outburst)

Read in full from `data/libs/functions/boss_lever.lua`:
- **Player limit**: enforced by `playerPositions` array length (5 in every HOD config) — a player must be standing on one of the 5 designated tiles when the lever is pulled to be teleported in; `minPlayers` defaults to 1 (none of the HOD configs override this), so a solo player *can* pull the lever, contradicting a strict "needs a team" reading of the owner's reference — worth flagging as a possible mismatch, not confirmed either way without an explicit reference minimum.
- **Failure/cooldown check**: `Lever:setCondition` (inside `BossLever:onUse`) checks every currently-positioned player's `lastEncounterTime`; if anyone is still on cooldown, the pull is rejected for the whole group with a clear "you have to wait Xh Ym to face `<boss>` again" message — cooldown is checked *before* the fight starts, not just applied after.
- **Time limit / cleanup**: `self.timeoutEvent = addEvent(function(zn) zn:refresh(); zn:removePlayers() end, self.timeToDefeat * 1000, zone)` — `timeToDefeat` defaults to `configManager.getNumber(configKeys.BOSS_DEFAULT_TIME_TO_DEFEAT)`; **none of the five HOD `BossLever` configs override this value**, so all five first/second-tier bosses share whatever the server-wide default is. This value was not looked up in this pass (out of the approved file list — `config.lua.dist`'s `BOSS_DEFAULT_TIME_TO_DEFEAT` key was not searched); recommend confirming it matches the owner's "~15 minutes" expectation before assuming parity.
- **Occupancy check**: `zone:countPlayers(IgnoredByMonsters) > 0` blocks a second party from pulling the lever while a fight is active — "There's already someone fighting with `<boss>`."

**Status: Implemented, consistent across all 5 `BossLever` bosses.** **Risk: Low**, with one open question (the shared default `timeToDefeat` value, unverified against the owner's ~15-minute expectation) and one possible mismatch (`minPlayers` not enforced to require a full team) flagged for live confirmation.

## World Devourer — hand-rolled encounter (not `BossLever`)

This is the most complex mechanic in the quest: three simultaneous 5-position sub-arenas (Hunger/Destruction/Rage), each needing at least 1 player, cycling every 30 seconds via `changeArea()` (which rotates surviving sub-bosses and rescues/kills-tracks players across arenas), converging into the final World Devourer fight once `devourerBossesKilled >= 3`.

- **Player limit**: minimum 1 per column (`#storeHunger < 1 or #storeDestruction < 1 or #storeRage < 1` rejects the pull), no explicit maximum beyond the 5-position arrays per column (15 total across 3 columns) — matches the owner's reference loosely ("5 players" likely refers to the *converged final fight* room, not the 3-column staging approach, but this is an inference, not confirmed).
- **Time limit**: 30 minutes per sub-arena (`areaDevourer1/2/3`, `30 * 60000`), separate from the final World Devourer room's own 30-minute clear timer (`areaDevourer5`).
- **Cooldown trigger point**: confirmed (this session) to fire at lever-pull/engage time for all three teams (lines 424/433/442 in `actions_final_lever.lua`), consistent with `BossLever`'s own engage-time pattern (§ above) — **this is the existing, consistent design across the whole quest, not a World-Devourer-specific deviation.** A failed/wiped attempt burns the same cooldown as a successful clear, by design, matching how every other HOD boss already behaves.
- **Cleanup**: `clearHunger`/`clearDestruction`/`clearRage`/`clearDevourer` each independently teleport players out and remove monsters in their respective bounding boxes; `clearDevourer` also stops all three remaining sub-arena timers.

**Status: Implemented.** **Risk: Medium** — not because anything is provably broken, but because of scale (6 interacting local functions, ~15 undeclared globals coordinating across them — see [[03_HOD_STORAGE_CONTRACT]] §4) and because `actions_devourer_access.lua` (a separate, smaller action tied to this encounter) has logic that reads as potentially inverted:

```lua
if not player:canFightBoss("World Devourer") then
    player:setBossCooldown("World Devourer", 0)
    player:sendTextMessage(19, "You access to World Devourer was released!")
    item:transform(23687)
else
    player:sendTextMessage(19, "You access to World Devourer is already released!")
end
```

Read literally: if a player currently **cannot** fight World Devourer (on cooldown), using this item **clears their cooldown**. This could be an intentional one-time "unlock item" (distinct from the repeatable boss fight), or it could be an unintended full cooldown bypass. **Not proven either way by current code** — the messaging is internally consistent with *some* intended behavior, just not confirmably the *correct* one. Per package rules ("do not change boss mechanics unless clearly proven by current code + reference"), **not treated as a safe fix in this package.**

**Requires live testing:** yes — use this item while on a World Devourer cooldown and confirm whether the cooldown actually clears, and whether that's desired.

## Boss unlock chain (cross-reference to [[04_HOD_PORTAL_ACCESS_CONTRACT]])

Anomaly + Rupture + Realityquake (all three) → unlocks Eradicator AND Outburst (both, same three-flag requirement) → both defeated → unlocks World Devourer. Structurally matches the owner's reference. Credit-attribution risk (room-presence-at-death, not tracked participation) already documented in [[04_HOD_PORTAL_ACCESS_CONTRACT]] §5 — applies identically to all three first-tier bosses' death handling in `creaturescripts_heart_boss_death.lua`.

## Summary — status/risk per component

| Component | Status | Risk | Safe patch this package? | Live testing needed? |
|---|---|---|---|---|
| 20h cooldown, first/second-tier bosses | Implemented, confirmed correct | Low | N/A | No |
| 13d20h cooldown, World Devourer | Implemented (PR #4) | Low | N/A — already done | Recommended to confirm display |
| 5-player room limit, first/second-tier | Implemented | Low | N/A | No |
| Shared `timeToDefeat` default (~15min expectation) | Unverified exact value | Low-Medium | No — needs a config lookup + owner confirmation, not a code change | Recommended |
| `minPlayers` not enforced (solo pull allowed) | Confirmed by code | Low-Medium | No — design question | Recommended |
| World Devourer 3-column encounter | Implemented | Medium (scale/fragility, not proven-broken) | No — excluded by "no large mechanical rewrites" | Recommended for the undeclared-global risk generally |
| `actions_devourer_access.lua` possible inverted logic | Unproven | Medium | No — excluded by "do not change boss mechanics unless clearly proven" | Yes, required before any fix |
| Room-presence-at-death credit attribution | Implemented as designed(?) | Medium | No — touches core boss-death handling for 3 bosses at once | Recommended to gauge practical impact |
