-- "Zze Art of War" (dialogue keyword "strike") - weekly repeatable task that reuses the Phantom
-- Army survival encounter (Children of the Revolution Mission 5) rather than a second arena
-- implementation. See scripts/quests/children_of_the_revolution/movements_click.lua for the
-- formation/wave/session-token logic this task plugs into.
--
-- PROVENANCE:
--   * Task exists, name, dialogue keyword, "repeats Mission 5", 10,000 XP reward - OWNER
--     REFERENCE (Children of the Revolution PDF, Task 2).
--   * 6 days 20 hours repeat interval - CURRENT TIBIA / CipSoft patch evidence (bounded research).
--   * Extra Tome of Knowledge claim opportunity - CURRENT TIBIA reference (bounded research). The
--     Tome is a physical pickup from the EXISTING Tome chest inside the Phantom Army arena (uid
--     6291, ~(33264,31130,7), see startup/tables/chest.lua), not an NPC-report reward - a player
--     who skips grabbing it during the encounter has simply missed that opportunity for this run
--     and it is never compensated afterward. The permanent Children of the Revolution claim
--     storage (ChildrenOfTheRevolution.ChestTomeOfKnowledge2) is never reset or overwritten; a
--     separate per-run KV flag (see ZzeArtOfWar.tryClaimWeeklyTome) gates exactly one ADDITIONAL
--     weekly claim through that same chest, wired as a small scoped extension of the existing
--     generic reward-chest dispatcher (scripts/actions/system/quest_reward_common.lua) rather than
--     a second, conflicting Action registered on the same uid.

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

---Attempts the ONE weekly claim of the bonus Tome of Knowledge through the EXISTING physical Tome
---chest (uid 6291). Returns false without granting anything when the player isn't an active weekly
---participant, when this run's claim is already used, or when the item fails to fit - a failed
---grant does NOT burn the claim, so a player with a full inventory may simply come back and retry.
---Only ever grants ONE item per call, regardless of whether the permanent Children of the
---Revolution claim was already used - the caller (scripts/actions/system/quest_reward_common.lua)
---additionally marks that permanent storage used (if it wasn't already) whenever this call
---succeeds, specifically to prevent a weekly participant who never claimed the original Tome from
---getting a SECOND one out of the normal permanent path immediately afterward.
---@param player Player
---@return boolean
function ZzeArtOfWar.tryClaimWeeklyTome(player)
	if not player or not ZzeArtOfWar.isActive(player) then
		return false
	end

	if flag(player, KEY_WEEKLY_TOME_CLAIMED) then
		return false
	end

	if not player:addItem(ZzeArtOfWar.WEEKLY_TOME_ITEM, 1, false) then
		return false
	end

	player:kv():set(KEY_WEEKLY_TOME_CLAIMED, true)
	player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "You find a spare Tome of Knowledge left behind for the resistance.")
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

---Reward sequence: 10,000 XP (owner reference) ONLY. The bonus Tome of Knowledge is never granted
---here - see ZzeArtOfWar.tryClaimWeeklyTome for the physical-chest claim path.
---@param player Player
---@return boolean
function ZzeArtOfWar.complete(player)
	if ZzeArtOfWar.blockingReason(player) ~= nil then
		return false
	end

	player:addExperience(ZzeArtOfWar.REWARD_EXPERIENCE, true)

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
