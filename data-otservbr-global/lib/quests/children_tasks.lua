-- Shared state/registry layer for the Zalamon/Chartan repeatable task family, offered after
-- Children of the Revolution is complete (Storage...ChildrenOfTheRevolution.Questline == 21).
--
-- Scoped intentionally to this task family only - this is NOT a generic server-wide quest/task
-- framework. Uses the project's existing player KV convention (see npc/a_sweaty_cyclops.lua's
-- koshei-amulet-done/-timer) rather than inventing dozens of numeric Storage IDs, since there are
-- no pre-existing task storages on main that need preserving.
--
-- Family:
--   DAILY lane (mutually exclusive - only one daily task may be active at a time):
--     Zzuppliezz
--     Forbidden Fruit
--   WEEKLY lane (independent of the daily lane; a daily and a weekly task may coexist):
--     Zze Art of War
--
-- Origin/reporting: a task's ORIGIN (who it was accepted from) is fixed at acceptance and is
-- never changed by which NPC later reports it - external references confirm a task started at
-- Zalamon may be reported to Chartan after the WOTE Mission 05 handoff.
--
-- WOTE qualification API (consumed by a future WOTE PR, NOT wired into WOTE here):
--   ChildrenTasks.hasQualifyingZalamonCompletion(player)
--   ChildrenTasks.firstIncompleteZalamonTask(player)
-- Qualifying task types: Zzuppliezz, Zze Art of War (origin ZALAMON only). Forbidden Fruit never
-- qualifies, regardless of origin.

ChildrenTasks = ChildrenTasks or {}

ChildrenTasks.LANE_DAILY = "daily"
ChildrenTasks.LANE_WEEKLY = "weekly"

ChildrenTasks.ORIGIN_ZALAMON = "zalamon"
ChildrenTasks.ORIGIN_CHARTAN = "chartan"

ChildrenTasks.registry = ChildrenTasks.registry or {}

---Register a task family member.
---@param task table {
---  name = string,
---  lane = ChildrenTasks.LANE_DAILY | ChildrenTasks.LANE_WEEKLY,
---  qualifiesForWote = boolean,
---  isActive = fun(Player):boolean,
---  getOrigin = fun(Player):string|nil,          -- origin of the CURRENT active/last run
---  hasEverCompletedFromOrigin = fun(Player, string):boolean,
---}
function ChildrenTasks.register(task)
	if not task or not task.name or not task.lane then
		return false
	end

	for _, existing in ipairs(ChildrenTasks.registry) do
		if existing.name == task.name then
			return false
		end
	end

	table.insert(ChildrenTasks.registry, task)
	return true
end

---@param player Player
---@param lane string
---@return boolean
local function hasActiveInLane(player, lane)
	if not player then
		return false
	end

	for _, task in ipairs(ChildrenTasks.registry) do
		if task.lane == lane and task.isActive and task.isActive(player) then
			return true
		end
	end

	return false
end

---Daily lane exclusivity: true when a daily task (Zzuppliezz or Forbidden Fruit) is already active.
---@param player Player
---@return boolean
function ChildrenTasks.hasActiveDailyTask(player)
	return hasActiveInLane(player, ChildrenTasks.LANE_DAILY)
end

---@param player Player
---@return boolean
function ChildrenTasks.hasActiveWeeklyTask(player)
	return hasActiveInLane(player, ChildrenTasks.LANE_WEEKLY)
end

-- Historical audited WOTE state (VERIFIED present on current main: storages.lua reserves
-- Storage.Quest.U8_6.WrathOfTheEmperor.Questline/Mission05, even though the WOTE quest scripts
-- that would ever WRITE to them remain in the frozen, unmerged PR #30). Questline 12 -> 13 /
-- Mission05 = 1 is when Zalamon offers the WOTE Mission 05 continuation. Used ONLY to select which
-- NPC currently offers NEW tasks - this PR does not write to or otherwise modify this storage.
local WOTE_HANDOFF_QUESTLINE = 13

---True once WOTE Mission 05 has started: Zalamon stops offering new tasks and Chartan takes over.
---Always false on current main until WOTE itself is merged and begins writing this storage.
---@param player Player
---@return boolean
function ChildrenTasks.hasWoteHandoffOccurred(player)
	if not player then
		return false
	end
	return player:getStorageValue(Storage.Quest.U8_6.WrathOfTheEmperor.Questline) >= WOTE_HANDOFF_QUESTLINE
end

---WOTE Mission 05 requirement, half A: has the player ever completed a qualifying task whose
---origin was Zalamon? Forbidden Fruit never qualifies, regardless of origin.
---@param player Player
---@return boolean
function ChildrenTasks.hasQualifyingZalamonCompletion(player)
	if not player then
		return false
	end

	for _, task in ipairs(ChildrenTasks.registry) do
		if task.qualifiesForWote and task.hasEverCompletedFromOrigin and task.hasEverCompletedFromOrigin(player, ChildrenTasks.ORIGIN_ZALAMON) then
			return true
		end
	end

	return false
end

---WOTE Mission 05 requirement, half B: name of a qualifying task that was started at Zalamon and
---is still active/unfinished, or nil when nothing is outstanding.
---@param player Player
---@return string|nil
function ChildrenTasks.firstIncompleteZalamonTask(player)
	if not player then
		return nil
	end

	for _, task in ipairs(ChildrenTasks.registry) do
		if task.qualifiesForWote and task.isActive and task.isActive(player) and task.getOrigin and task.getOrigin(player) == ChildrenTasks.ORIGIN_ZALAMON then
			return task.name
		end
	end

	return nil
end
