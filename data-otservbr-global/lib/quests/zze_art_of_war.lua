-- "Zze Art of War" (dialogue keyword "strike") - weekly repeatable task that reuses the Phantom
-- Army survival encounter (Children of the Revolution Mission 5) rather than a second arena
-- implementation. See scripts/quests/children_of_the_revolution/movements_click.lua for the
-- formation/wave/session-token logic this task plugs into.
--
-- PROVENANCE:
--   * Task exists, name, dialogue keyword, "repeats Mission 5", 10,000 XP reward - OWNER
--     REFERENCE (Children of the Revolution PDF, Task 2).
--   * 6 days 20 hours repeat interval - CURRENT TIBIA / CipSoft patch evidence (bounded research).
--   * Extra Tome of Knowledge claim opportunity - CURRENT TIBIA reference (bounded research); the
--     permanent Children of the Revolution chest storage
--     (ChildrenOfTheRevolution.ChestTomeOfKnowledge2) is never touched by this task - a separate
--     per-run KV flag gates one weekly claim instead, granted directly on report rather than by
--     re-registering an Action on the same physical chest (which would collide with the existing,
--     already-proven main-quest registration).

ZzeArtOfWar = ZzeArtOfWar or {}

ZzeArtOfWar.REQUIRED_CHILDREN_QUESTLINE = 21
ZzeArtOfWar.REPEAT_INTERVAL = (6 * 24 * 60 * 60) + (20 * 60 * 60) -- 6 days 20 hours, CURRENT_SOURCE_PROVEN
ZzeArtOfWar.REWARD_EXPERIENCE = 10000
ZzeArtOfWar.WEEKLY_TOME_ITEM = 10217 -- Tome of Knowledge, matches the existing main-quest reward

local KEY_ACTIVE = "zze-art-of-war-active"
local KEY_ORIGIN = "zze-art-of-war-origin"
local KEY_TIMER = "zze-art-of-war-timer"
local KEY_EVER_COMPLETED_ZALAMON = "zze-art-of-war-ever-completed-zalamon"
local KEY_EVER_COMPLETED_CHARTAN = "zze-art-of-war-ever-completed-chartan"
-- Set by the Phantom Army encounter on successful 10-minute survival; cleared on report.
local KEY_OBJECTIVE_COMPLETE = "zze-art-of-war-objective-complete"
-- Per-run claim flag for the bonus Tome of Knowledge (see provenance above).
local KEY_WEEKLY_TOME_CLAIMED = "zze-art-of-war-weekly-tome-claimed"

local function flag(player, key)
	return player:kv():get(key) == true
end

---@param player Player
---@return boolean
function ZzeArtOfWar.isActive(player)
	return player ~= nil and flag(player, KEY_ACTIVE)
end

---@param player Player
---@return string|nil
function ZzeArtOfWar.getOrigin(player)
	if not player then
		return nil
	end
	local origin = player:kv():get(KEY_ORIGIN)
	return type(origin) == "string" and origin or nil
end

---@param player Player
---@param origin string
---@return boolean
function ZzeArtOfWar.hasEverCompletedFromOrigin(player, origin)
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
function ZzeArtOfWar.isObjectiveComplete(player)
	return player ~= nil and flag(player, KEY_OBJECTIVE_COMPLETE)
end

---Called by the Phantom Army encounter (movements_click.lua) when an active Zze Art of War
---participant survives the full 10 minutes. Does NOT touch Children of the Revolution's own
---Questline - that progression belongs only to Questline == 19 main-quest participants.
---@param player Player
function ZzeArtOfWar.markObjectiveComplete(player)
	if not player then
		return
	end
	player:kv():set(KEY_OBJECTIVE_COMPLETE, true)
end

---@param player Player
---@return number
function ZzeArtOfWar.cooldownRemaining(player)
	if not player then
		return 0
	end

	local finishTime = player:kv():get(KEY_TIMER)
	if type(finishTime) ~= "number" then
		return 0
	end

	local remaining = finishTime - os.time()
	return remaining > 0 and remaining or 0
end

---@param player Player
---@return boolean
function ZzeArtOfWar.canAccept(player)
	if not player then
		return false
	end

	if player:getStorageValue(Storage.Quest.U8_54.ChildrenOfTheRevolution.Questline) < ZzeArtOfWar.REQUIRED_CHILDREN_QUESTLINE then
		return false
	end

	-- Weekly lane is independent of the daily lane - no cross-lane exclusivity check here.
	return not ZzeArtOfWar.isActive(player) and ZzeArtOfWar.cooldownRemaining(player) == 0
end

---@param player Player
---@param origin string
---@return boolean
function ZzeArtOfWar.start(player, origin)
	if not player then
		return false
	end

	player:kv():set(KEY_ACTIVE, true)
	player:kv():set(KEY_ORIGIN, origin)
	player:kv():set(KEY_OBJECTIVE_COMPLETE, false)
	player:kv():set(KEY_WEEKLY_TOME_CLAIMED, false)
	return true
end

---@param player Player
---@return string|nil
function ZzeArtOfWar.blockingReason(player)
	if not player or not ZzeArtOfWar.isActive(player) then
		return "inactive"
	end

	if not ZzeArtOfWar.isObjectiveComplete(player) then
		return "survive"
	end

	return nil
end

---Reward sequence: 10,000 XP (owner reference), plus one Tome of Knowledge if this run hasn't
---already claimed it. No additional reward invented.
---@param player Player
---@return boolean
function ZzeArtOfWar.complete(player)
	if ZzeArtOfWar.blockingReason(player) ~= nil then
		return false
	end

	player:addExperience(ZzeArtOfWar.REWARD_EXPERIENCE, true)

	if not flag(player, KEY_WEEKLY_TOME_CLAIMED) then
		if player:addItem(ZzeArtOfWar.WEEKLY_TOME_ITEM, 1, false) then
			player:kv():set(KEY_WEEKLY_TOME_CLAIMED, true)
		end
		-- A failed grant (e.g. no capacity) is not fatal to completion - the XP and cooldown still
		-- apply, matching the transactional-but-not-item-blocking nature of a pure bonus reward.
	end

	player:kv():set(KEY_ACTIVE, false)
	player:kv():set(KEY_OBJECTIVE_COMPLETE, false)
	local origin = ZzeArtOfWar.getOrigin(player)
	if origin == ChildrenTasks.ORIGIN_ZALAMON then
		player:kv():set(KEY_EVER_COMPLETED_ZALAMON, true)
	else
		player:kv():set(KEY_EVER_COMPLETED_CHARTAN, true)
	end
	player:kv():set(KEY_TIMER, os.time() + ZzeArtOfWar.REPEAT_INTERVAL)
	return true
end

ChildrenTasks.register({
	name = "Zze Art of War",
	lane = ChildrenTasks.LANE_WEEKLY,
	qualifiesForWote = true,
	isActive = ZzeArtOfWar.isActive,
	getOrigin = ZzeArtOfWar.getOrigin,
	hasEverCompletedFromOrigin = ZzeArtOfWar.hasEverCompletedFromOrigin,
})
