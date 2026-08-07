-- Repeatable tasks given by Zalamon after Children of the Revolution.
--
-- WHY THIS IS GENERIC RATHER THAN HARD-CODED TO ONE TASK:
--
-- The owner reference lists, among the general Wrath of the Emperor requirements,
--   "ukonczony Children of the Revolution Quest oraz wykonany 1 task u [Zalamon] (np. Zzupliezz)"
-- where "np." is "na przyklad" - FOR EXAMPLE. Zzuppliezz is an illustration of a qualifying task, not
-- the requirement itself. A reader comment on the same page states the Mission 05 rule directly:
--   "Przed rozpoczeciem tej misji musimy skonczyc wszystkie taski rozpoczete u NPC Zalamon ... jezeli
--    nie robilismy zadnych taskow ... npc nie bedzie rozmawial ... dopoki nie zrobimy choćby taska z rybami"
--   ("Before starting this mission we must finish every task started at Zalamon ... if we have done no
--    tasks at all, the NPC will not discuss the new mission until we do at least the fish task.")
--
-- So the rule has two independent halves, and neither names a specific task:
--   A) at least ONE qualifying task has ever been completed, and
--   B) no qualifying task that was STARTED is still unfinished.
--
-- An earlier revision of this branch hard-coded Zzuppliezz as the Mission 05 prerequisite. That was
-- stricter than the reference and is corrected here. Tasks register themselves below, so adding a
-- second qualifying task later requires no change to the Wrath of the Emperor gate.

ChildrenTasks = ChildrenTasks or {}

ChildrenTasks.registry = ChildrenTasks.registry or {}

---Register a qualifying post-Children task.
---@param task table { name = string, isActive = fun(Player):boolean, hasEverCompleted = fun(Player):boolean }
function ChildrenTasks.register(task)
	if not task or not task.name then
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

---Requirement A: has the player ever finished any qualifying task?
---@param player Player
---@return boolean
function ChildrenTasks.hasCompletedAny(player)
	if not player then
		return false
	end

	for _, task in ipairs(ChildrenTasks.registry) do
		if task.hasEverCompleted and task.hasEverCompleted(player) then
			return true
		end
	end

	return false
end

---Requirement B: does the player still owe Zalamon a task they already started?
---@param player Player
---@return boolean
function ChildrenTasks.hasIncompleteActiveTask(player)
	if not player then
		return false
	end

	for _, task in ipairs(ChildrenTasks.registry) do
		if task.isActive and task.isActive(player) then
			return true
		end
	end

	return false
end

---Name of the first unfinished task, for NPC feedback. nil when nothing is outstanding.
---@param player Player
---@return string|nil
function ChildrenTasks.firstIncompleteName(player)
	if not player then
		return nil
	end

	for _, task in ipairs(ChildrenTasks.registry) do
		if task.isActive and task.isActive(player) then
			return task.name
		end
	end

	return nil
end
