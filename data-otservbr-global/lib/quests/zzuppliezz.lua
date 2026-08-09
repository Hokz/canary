-- "Zzuppliezz" - daily repeatable Children of the Revolution supply task.
--
-- PROVENANCE:
--   * Task exists, name, dialogue keyword family, and the three-step objective (weapons crate,
--     corned fish, feed prisoners) - OWNER REFERENCE (Children of the Revolution PDF, Task 1).
--   * 20-hour repeat interval - CURRENT TIBIA / CipSoft patch evidence (bounded research).
--   * Weapons crate / corned fish item ids (10247, 10218) - PROJECT DATA (items.xml descriptions
---    match: "This crate contains a set of weapons", "prepared as provision for soldiers").
--   * "Vive la Resistance" achievement on first prisoner feeding - OWNER REFERENCE.
--   * Reward pool (Red/Green/Blue Gem, or very rarely Zaoan Armor) - OWNER REFERENCE reward image
--     names this exact pool. An earlier draft of this PR used a five-gem pool (adding Yellow and
--     Violet Gem) that does not match the owner reference and has been corrected. All four item ids
--     resolved by exact PROJECT DATA name (items.xml): Red Gem 3039, Green Gem 3038, Blue Gem 3041,
--     Zaoan armor 10384.
--   * Reward probability - exact CipSoft odds NOT_PROVEN; the owner reference only establishes
--     Zaoan Armor as "very rare" relative to the three gems. Authorized GLOBAL-like fallback: 1%
--     Zaoan Armor, 33% each gem - CUSTOM_GLOBAL_LIKE_PENDING_EXACT_REWARD_PROBABILITY. The choice
--     is rolled once and persisted for the run (KEY_REWARD_CHOICE below), not re-rolled on every
--     report attempt, so a player cannot deliberately induce a delivery failure to re-roll for a
--     more convenient reward.
--   * Cooldown anchor (starts on successful REPORT, not on acceptance) - NOT independently proven
--     from any source; CUSTOM_GLOBAL_LIKE_COOLDOWN_ANCHOR. "Repeatable after N hours" most
--     naturally reads as N hours after the previous completion, and starting the clock at
--     acceptance would let a player hold a stale task open indefinitely and then finish it right
--     as an acceptance-based cooldown was about to expire, effectively shortening the interval.
--   * The cooldown is the SHARED daily-lane timer (ChildrenTasks.dailyCooldownRemaining/
--     markDailyReported), not a Zzuppliezz-only timer - completing Zzuppliezz must also block
--     Forbidden Fruit for the same 20 hours, since only one daily task may be done per interval.
--   * Physical world-trigger positions - see actions_zzuppliezz.lua / startup wiring; PROJECT-
--     NATIVE position-first OTBM evidence, not guessed.
--   * Per-run interaction proof, one-time-per-cycle sources, and NO on-demand restart or "abandon"
--     command - CUSTOM_GLOBAL_LIKE_ZZUPPLIEZZ_CYCLE. Exact CipSoft handling of a mid-run lost
--     physical item (traded/stashed after legitimately taking it from its source) is NOT_PROVEN and
--     intentionally left unresolved: an on-demand restart that re-opens the source flags would let
--     a player collect crate+fish, move them away, "restart", and repeat indefinitely before ever
--     reporting - a proven farming exploit, since these items are movable/marketable and the
--     20-hour cooldown only begins on successful report. If a required physical item is lost after
--     being legitimately collected, the run stays active with its source-proof intact but
--     unreportable until the item is reacquired through whatever legitimate means the source
--     itself allows next cycle - no infinite replacement, no abandon path.

Zzuppliezz = Zzuppliezz or {}

Zzuppliezz.REQUIRED_CHILDREN_QUESTLINE = 21
Zzuppliezz.REPEAT_INTERVAL = 20 * 60 * 60 -- 20 hours, CURRENT_SOURCE_PROVEN

Zzuppliezz.ITEM_WEAPONS_CRATE = 10247
Zzuppliezz.ITEM_CORNED_FISH = 10218
Zzuppliezz.FISH_REQUIRED = 2 -- one fed to the prisoners, one returned to the task giver

Zzuppliezz.REWARD_RED_GEM = 3039
Zzuppliezz.REWARD_GREEN_GEM = 3038
Zzuppliezz.REWARD_BLUE_GEM = 3041
Zzuppliezz.REWARD_ZAOAN_ARMOR = 10384

local KEY_ACTIVE = "zzuppliezz-active"
local KEY_ORIGIN = "zzuppliezz-origin"
local KEY_EVER_COMPLETED_ZALAMON = "zzuppliezz-ever-completed-zalamon"
local KEY_EVER_COMPLETED_CHARTAN = "zzuppliezz-ever-completed-chartan"
-- Per-cycle progress. Reset whenever a run starts, so nothing carries between cycles.
local KEY_CRATE_TAKEN = "zzuppliezz-crate-taken"
local KEY_FISH_TAKEN = "zzuppliezz-fish-taken"
local KEY_PRISONERS_FED = "zzuppliezz-prisoners-fed"
-- The reward chosen for this run's completion attempt, persisted so a failed delivery retry reuses
-- the same reward instead of re-rolling (see PROVENANCE).
local KEY_REWARD_CHOICE = "zzuppliezz-reward-choice"

local function flag(player, key)
	return player:kv():get(key) == true
end

---@param player Player
---@return boolean
function Zzuppliezz.isActive(player)
	return player ~= nil and flag(player, KEY_ACTIVE)
end

---Origin, once set by start(), is fixed for the life of the active run: start() refuses to touch
---an already-active run (see its own doc comment), getOrigin() only ever reads back the stored
---value, and complete() derives its "ever completed" flag from THIS value rather than from any
---parameter a caller could pass - so a task accepted at Zalamon and later reported to Chartan after
---the WOTE handoff keeps origin == ZALAMON for that entire run, with no code path able to rewrite
---it in between.
---@param player Player
---@return string|nil
function Zzuppliezz.getOrigin(player)
	if not player then
		return nil
	end
	local origin = player:kv():get(KEY_ORIGIN)
	return type(origin) == "string" and origin or nil
end

---@param player Player
---@param origin string
---@return boolean
function Zzuppliezz.hasEverCompletedFromOrigin(player, origin)
	if not player then
		return false
	end
	if origin == ChildrenTasks.ORIGIN_ZALAMON then
		return flag(player, KEY_EVER_COMPLETED_ZALAMON)
	end
	return flag(player, KEY_EVER_COMPLETED_CHARTAN)
end

---@param player Player
---@return boolean
function Zzuppliezz.hasFedPrisoners(player)
	return player ~= nil and flag(player, KEY_PRISONERS_FED)
end

---@param player Player
---@return boolean
function Zzuppliezz.hasTakenCrate(player)
	return player ~= nil and flag(player, KEY_CRATE_TAKEN)
end

---@param player Player
---@return boolean
function Zzuppliezz.hasTakenFish(player)
	return player ~= nil and flag(player, KEY_FISH_TAKEN)
end

---@param player Player
function Zzuppliezz.markCrateTaken(player)
	player:kv():set(KEY_CRATE_TAKEN, true)
end

---@param player Player
function Zzuppliezz.markFishTaken(player)
	player:kv():set(KEY_FISH_TAKEN, true)
end

---@param player Player
function Zzuppliezz.markPrisonersFed(player)
	player:kv():set(KEY_PRISONERS_FED, true)
end

---Seconds until the task may be taken again; 0 when available. Delegates to the SHARED daily-lane
---timer - see ChildrenTasks.dailyCooldownRemaining - so a Forbidden Fruit completion blocks this
---task too, and vice versa.
---@param player Player
---@return number
function Zzuppliezz.cooldownRemaining(player)
	return ChildrenTasks.dailyCooldownRemaining(player)
end

---@param player Player
---@return boolean
function Zzuppliezz.canAccept(player)
	if not player then
		return false
	end

	if player:getStorageValue(Storage.Quest.U8_54.ChildrenOfTheRevolution.Questline) < Zzuppliezz.REQUIRED_CHILDREN_QUESTLINE then
		return false
	end

	if ChildrenTasks.hasActiveDailyTask(player) and not Zzuppliezz.isActive(player) then
		-- The other daily task (Forbidden Fruit) is active - the two daily lanes are exclusive.
		return false
	end

	return not Zzuppliezz.isActive(player) and Zzuppliezz.cooldownRemaining(player) == 0
end

---Starts a NEW run. Refuses to touch an already-active run - there is no on-demand restart/abandon
---path (see PROVENANCE: Corned Fish and Weapons Crate are movable/marketable, so an on-demand reset
---of source-proof flags would let a player farm unlimited supplies before ever reporting). This
---also guarantees ORIGIN can never be rewritten once a run is accepted, even by a later call from a
---different NPC after the WOTE handoff.
---@param player Player
---@param origin string
---@return boolean
function Zzuppliezz.start(player, origin)
	if not player or Zzuppliezz.isActive(player) then
		return false
	end

	player:kv():set(KEY_CRATE_TAKEN, false)
	player:kv():set(KEY_FISH_TAKEN, false)
	player:kv():set(KEY_PRISONERS_FED, false)
	player:kv():set(KEY_ACTIVE, true)
	player:kv():set(KEY_ORIGIN, origin)
	player:kv():remove(KEY_REWARD_CHOICE)
	return true
end

---Why the turn-in cannot be completed, or nil when it can.
---@param player Player
---@return string|nil
function Zzuppliezz.blockingReason(player)
	if not player or not Zzuppliezz.isActive(player) then
		return "inactive"
	end

	-- Both per-cycle interaction proof AND the physical items are required, so stashed items from
	-- an earlier cycle (or bought/traded ones) can never skip the world interactions.
	if not Zzuppliezz.hasTakenCrate(player) then
		return "crate-source"
	end

	if not Zzuppliezz.hasTakenFish(player) then
		return "fish-source"
	end

	if not Zzuppliezz.hasFedPrisoners(player) then
		return "prisoners"
	end

	if player:getItemCount(Zzuppliezz.ITEM_WEAPONS_CRATE) < 1 then
		return "crate"
	end

	if player:getItemCount(Zzuppliezz.ITEM_CORNED_FISH) < 1 then
		return "fish"
	end

	return nil
end

---Rolls a NEW reward - only ever called once per run by selectedReward() below.
---@return number itemId
local function rollReward()
	-- CUSTOM_GLOBAL_LIKE_PENDING_EXACT_REWARD_PROBABILITY: exact CipSoft odds could not be
	-- recovered; the owner reference only establishes Zaoan Armor as "very rare" relative to the
	-- three gems. Authorized fallback: 1% armor, 33% each gem (roll 1..100: 1 -> armor,
	-- 2..34 -> red, 35..67 -> green, 68..100 -> blue).
	local roll = math.random(100)
	if roll == 1 then
		return Zzuppliezz.REWARD_ZAOAN_ARMOR
	elseif roll <= 34 then
		return Zzuppliezz.REWARD_RED_GEM
	elseif roll <= 67 then
		return Zzuppliezz.REWARD_GREEN_GEM
	else
		return Zzuppliezz.REWARD_BLUE_GEM
	end
end

---Selects this run's reward on the FIRST completion attempt and persists it, so a later retry
---(e.g. after a delivery failure) always reuses the same reward instead of re-rolling.
---@param player Player
---@return number itemId
local function selectedReward(player)
	local choice = player:kv():get(KEY_REWARD_CHOICE)
	if type(choice) ~= "number" then
		choice = rollReward()
		player:kv():set(KEY_REWARD_CHOICE, choice)
	end
	return choice
end

---Transactional completion. The reward is granted before the required items are consumed, so a
---player whose inventory is too full to receive the reward loses nothing and can simply retry. If
---the second removal ever fails, the first item is restored, so a partial consumption never
---happens. The reward itself was already chosen and persisted (selectedReward), so retrying after a
---failure can never re-roll for a more convenient one. Which "ever completed" flag is set is
---decided by the ORIGIN RECORDED AT ACCEPTANCE, not by which NPC this call happens to be reported
---to - a task started at Zalamon must still count as a Zalamon-origin completion even when reported
---to Chartan after the WOTE handoff.
---@param player Player
---@return boolean
function Zzuppliezz.complete(player)
	if Zzuppliezz.blockingReason(player) ~= nil then
		return false
	end

	local reward = selectedReward(player)
	if not player:addItem(reward, 1, false) then
		return false
	end

	if not player:removeItem(Zzuppliezz.ITEM_WEAPONS_CRATE, 1) then
		player:removeItem(reward, 1)
		return false
	end

	if not player:removeItem(Zzuppliezz.ITEM_CORNED_FISH, 1) then
		player:addItem(Zzuppliezz.ITEM_WEAPONS_CRATE, 1, false)
		player:removeItem(reward, 1)
		return false
	end

	player:kv():set(KEY_ACTIVE, false)
	local origin = Zzuppliezz.getOrigin(player)
	if origin == ChildrenTasks.ORIGIN_ZALAMON then
		player:kv():set(KEY_EVER_COMPLETED_ZALAMON, true)
	else
		player:kv():set(KEY_EVER_COMPLETED_CHARTAN, true)
	end
	player:kv():remove(KEY_REWARD_CHOICE)
	ChildrenTasks.markDailyReported(player)
	return true
end

ChildrenTasks.register({
	name = "Zzuppliezz",
	lane = ChildrenTasks.LANE_DAILY,
	qualifiesForWote = true,
	isActive = Zzuppliezz.isActive,
	getOrigin = Zzuppliezz.getOrigin,
	hasEverCompletedFromOrigin = Zzuppliezz.hasEverCompletedFromOrigin,
})
