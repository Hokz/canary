# 05 — Heart of Destruction Boss Mechanics Contract

**Correction notice (HOD-02)**: an earlier same-session investigation pass initially suspected that only Realityquake had a working cooldown, based on seeing an explicit `setBossCooldown` call in `actions_foreshock.lua` and no equivalent explicit call in the other four first-tier/second-tier boss lever files. Reading `data/libs/functions/boss_lever.lua` in full disproved this: **`BossLever:onUse()` unconditionally applies a cooldown to every participant for every boss registered through it** (line 250: `lever:setCooldownAllPlayers(self.name, os.time() + self.timeToFightAgain)`), using the server's configured default (`bossDefaultTimeToFightAgain = 20 * 60 * 60`, confirmed in `config.lua.dist:607`) unless a boss's config overrides `timeToFightAgain`. Realityquake's explicit call is redundant, not compensating for a gap. This contract reflects the corrected understanding.

**Correction notice (HOD-03)**: HOD-02 flagged `actions_devourer_access.lua` as having "possibly inverted" cooldown-clearing logic. **This is retracted.** Item id 23686 is named `"devourer core"` in `data/items/items.xml:46876`, and the owner's reference explicitly states: *"Player can also use Devourer Core to reset the cooldown."* The file's behavior — clearing a player's World Devourer cooldown when the item is used while on cooldown — is the **correct, intended implementation** of this exact mechanic, not a bug. No fix needed; §"World Devourer" below is updated accordingly.

## General requirements (HOD-03, newly documented)

Per the owner's reference: minimum character level 150 (recommended 250), Premium account required, group of up to 5 players for the five non-final bosses. **Not verified against code in this pass** — level/premium gating likely lives in the `BossLever` config (`requiredLevel`) or the entry teleport/lever position checks, none of which were re-read specifically for a level-150 value this session. Flagged for a future targeted check, not asserted as correct or incorrect here.

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
- **Cooldown trigger point**: confirmed (HOD-02) to fire at lever-pull/engage time for all three teams (lines 424/433/442 in `actions_final_lever.lua`), consistent with `BossLever`'s own engage-time pattern (§ above) — **this is the existing, consistent design across the whole quest, not a World-Devourer-specific deviation.** A failed/wiped attempt burns the same cooldown as a successful clear, by design, matching how every other HOD boss already behaves.
- **Cleanup**: `clearHunger`/`clearDestruction`/`clearRage`/`clearDevourer` each independently teleport players out and remove monsters in their respective bounding boxes; `clearDevourer` also stops all three remaining sub-arena timers.
- **Total time budget (HOD-03 discrepancy)**: the owner's reference states the entire final battle (Hunger + Destruction + Rage + World Devourer) has a **45-minute total budget**. Code implements this as three independent 30-minute sub-arena timers (`areaDevourer1/2/3`) plus a separate 30-minute World Devourer room timer (`areaDevourer5`) — not a single unified 45-minute clock. Whether these timers are sequential (sub-arena timers stop once you transition to World Devourer, effectively resetting the budget) or could theoretically stack past 45 minutes wasn't traced fully in this pass. **Flagged as a discrepancy requiring live testing**, not fixed — timing/sequencing changes to this encounter would be exactly the kind of "large mechanical rewrite" excluded from safe-fix scope.
- **"Devourer Core" reset item (HOD-03 correction)**: `actions_devourer_access.lua` (item id 23686, confirmed named "devourer core" in `items.xml`) lets a player on cooldown clear it early — this is the reference's own documented mechanic (*"Player can also use Devourer Core to reset the cooldown"*), not a bug. HOD-02's "possibly inverted logic" concern is retracted; no fix applied or needed.
- **Missing: the "5 destructive charges" entry gate.** Per the reference, entering World Devourer should also require spending 5 accumulated "destructive charges" (gained by killing "higher minions of destruction"), independent of the cooldown/Devourer Core system. No charge-counter storage or kill-tracking for this exists anywhere in the codebase (confirmed via repo-wide search for "charges"/"Devourer Core"/"destructive charges" — only the item-name match for Devourer Core itself was found). **Status: Missing.** **Risk: Medium** (reference-parity gap, not a regression). **Not a safe fix** — this is new mechanic design (a kill-tracked counter across multiple monster types, spent on entry), explicitly excluded from this package's scope. See [[08_HOD_IMPLEMENTATION_BREAKDOWN]] for future scoping.

**Status: Implemented (core encounter), with one confirmed-correct mechanic previously misdiagnosed, one confirmed-missing sub-mechanic (charges), and one unresolved timing discrepancy (45min vs 30min×N).** **Risk: Medium** — primarily from scale (6 interacting local functions, ~15 undeclared globals coordinating across them — see [[03_HOD_STORAGE_CONTRACT]] §4), not from proven functional defects.

## Per-boss mechanic detail (HOD-03, spot-checked against creaturescripts)

Two of the five first-tier/second-tier bosses' HP-threshold transform logic were read in full this pass and compare favorably against the reference:

- **Anomaly** (`creaturescripts_anomaly_transform.lua`): the reference describes Charged Anomaly transforming and requiring the vortex-crossing kill mechanic, repeating "about 3 to 4 times until the boss dies." Code implements exactly **4 HP thresholds** (75%, 50%, 25%, 5%) via `GlobalStorage.HeartOfDestruction.ChargedAnomaly`, each removing and respawning the boss with 4 fresh Spark of Destructions. Matches the reference closely. The actual "must cross the room vortex to damage it" immunity mechanic lives elsewhere (not traced this pass — likely `actions_anomaly.lua`'s room vortex item or a separate creaturescript) and was not independently verified.
- **Rupture** (`creaturescripts_rupture_resonance.lua`): the reference describes "Damage Resonance appears several times" and warns against attacking Rupture while it's active (or it heals ~5000 HP). Code implements **5 HP thresholds** (80/60/40/25/10%) that spawn a "Damage Resonance" monster plus 4 Spark of Destructions each time. Matches the reference's general shape. **The actual heal-on-hit-while-active penalty was not located in this pass** (likely lives in a different script tied to the Rupture monster's own combat/health-change hook) — not confirmed present or absent, not claimed as either.

Eradicator's "red form" transform, Outburst's "Charging Outburst" elemental-immunity-except-physical + explosion mechanic, and the mini-boss-specific mechanics (Hunger/Greed vortex, Destruction/Disruption escalation, Rage/Frenzy) described in the reference were **not independently re-verified against their creaturescripts this pass** — only the lever/entry files for these were read (see [[04_HOD_PORTAL_ACCESS_CONTRACT]], HOD-02). No claim is made about their correctness either way; flagged for a future targeted pass if the owner wants deeper mechanic verification.

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
| `actions_devourer_access.lua` (Devourer Core) | **Implemented correctly** (HOD-03 correction — was misflagged in HOD-02) | Low | N/A — not broken | No |
| "5 destructive charges" entry gate | **Missing** (HOD-03 new finding) | Medium | No — new mechanic, excluded from safe-fix scope | N/A — confirmed absent by static search |
| 45-min total vs 30-min×N sub-timers | Discrepancy, unresolved | Low-Medium | No — timing change to a large encounter | Yes |
| Room-presence-at-death credit attribution | Implemented as designed(?) | Medium | No — touches core boss-death handling for 3 bosses at once | Recommended to gauge practical impact |
