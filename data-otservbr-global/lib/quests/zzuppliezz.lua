-- "Zzuppliezz" - a repeatable Children of the Revolution supply task given by Zalamon.
--
-- PROVENANCE - stated precisely, because an earlier revision of this branch overstated it:
--
--   * That a post-Children task exists at Zalamon, that Zzuppliezz is one such task, and that the
--     minimal qualifying task is "the fish task" - OWNER WOTE REFERENCE (Tibiopedia WOTE page:
--     "wykonany 1 task u [Zalamon] (np. Zzupliezz)" and "taska z rybami").
--   * Weapons crate / corned fish item ids (10247, 10218) - PROJECT DATA (data/items/items.xml:
--     "This crate contains a set of weapons", "prepared as provision for soldiers").
--   * "Vive la Resistance" achievement - PROJECT DATA (data/scripts/lib/register_achievements.lua,
--     description: "Supplying prisoners, caring for outcasts..." - matches the prisoner feeding).
--   * KV-backed task state - PROJECT CONVENTION (npc/a_sweaty_cyclops.lua's koshei-amulet-done/-timer).
--   * Small-gem reward pool - PROJECT DATA for the item ids; that gems are the reward at all is
--     GLOBAL_LIKE_IMPLEMENTATION.
--   * 20-hour cooldown, the exact step order, dialogue wording, and the three physical trigger
--     locations - GLOBAL_LIKE_IMPLEMENTATION / NOT_PROVEN. The owner WOTE reference does not specify
--     any of them; it only names the task.
--
-- WOTE Mission 05 does NOT depend on this task specifically - see lib/quests/children_tasks.lua.

Zzuppliezz = Zzuppliezz or {}

-- Offered once Children of the Revolution is finished.
Zzuppliezz.REQUIRED_CHILDREN_QUESTLINE = 21

Zzuppliezz.KEY_ACTIVE = "zzuppliezz-active"
Zzuppliezz.KEY_TIMER = "zzuppliezz-timer"
Zzuppliezz.KEY_EVER_COMPLETED = "zzuppliezz-ever-completed"
-- Per-run progress. All three are cleared when a run starts, so nothing carries between runs.
Zzuppliezz.KEY_CRATE_TAKEN = "zzuppliezz-crate-taken"
Zzuppliezz.KEY_FISH_TAKEN = "zzuppliezz-fish-taken"
Zzuppliezz.KEY_PRISONERS_FED = "zzuppliezz-prisoners-fed"

Zzuppliezz.REPEAT_INTERVAL = 20 * 60 * 60 -- GLOBAL_LIKE: not specified by the owner reference

Zzuppliezz.ITEM_WEAPONS_CRATE = 10247
Zzuppliezz.ITEM_CORNED_FISH = 10218
Zzuppliezz.FISH_REQUIRED = 2 -- one fed to the prisoners, one returned to Zalamon

Zzuppliezz.GEM_REWARDS = { 3028, 3029, 3030, 3032, 3033 }

local function flag(player, key)
	return player:kv():get(key) == true
end

---@param player Player
---@return boolean
function Zzuppliezz.hasEverCompleted(player)
	return player ~= nil and flag(player, Zzuppliezz.KEY_EVER_COMPLETED)
end

---@param player Player
---@return boolean
function Zzuppliezz.isActive(player)
	return player ~= nil and flag(player, Zzuppliezz.KEY_ACTIVE)
end

---@param player Player
---@return boolean
function Zzuppliezz.hasFedPrisoners(player)
	return player ~= nil and flag(player, Zzuppliezz.KEY_PRISONERS_FED)
end

---@param player Player
---@return boolean
function Zzuppliezz.hasTakenCrate(player)
	return player ~= nil and flag(player, Zzuppliezz.KEY_CRATE_TAKEN)
end

---@param player Player
---@return boolean
function Zzuppliezz.hasTakenFish(player)
	return player ~= nil and flag(player, Zzuppliezz.KEY_FISH_TAKEN)
end

---@param player Player
function Zzuppliezz.markCrateTaken(player)
	player:kv():set(Zzuppliezz.KEY_CRATE_TAKEN, true)
end

---@param player Player
function Zzuppliezz.markFishTaken(player)
	player:kv():set(Zzuppliezz.KEY_FISH_TAKEN, true)
end

---@param player Player
function Zzuppliezz.markPrisonersFed(player)
	player:kv():set(Zzuppliezz.KEY_PRISONERS_FED, true)
end

---Seconds until the task may be taken again; 0 when available.
---@param player Player
---@return number
function Zzuppliezz.cooldownRemaining(player)
	if not player then
		return 0
	end

	local finishTime = player:kv():get(Zzuppliezz.KEY_TIMER)
	if type(finishTime) ~= "number" then
		return 0
	end

	local remaining = finishTime - os.time()
	return remaining > 0 and remaining or 0
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

	return not Zzuppliezz.isActive(player) and Zzuppliezz.cooldownRemaining(player) == 0
end

---@param player Player
---@return boolean
function Zzuppliezz.start(player)
	if not player then
		return false
	end

	-- Clear per-run progress so a previous run can never satisfy this one.
	player:kv():set(Zzuppliezz.KEY_CRATE_TAKEN, false)
	player:kv():set(Zzuppliezz.KEY_FISH_TAKEN, false)
	player:kv():set(Zzuppliezz.KEY_PRISONERS_FED, false)
	player:kv():set(Zzuppliezz.KEY_ACTIVE, true)
	return true
end

---Why the turn-in cannot be completed, or nil when it can. Lets the NPC explain the actual problem.
---@param player Player
---@return string|nil
function Zzuppliezz.blockingReason(player)
	if not player or not Zzuppliezz.isActive(player) then
		return "inactive"
	end

	-- CONFIRMED BUG (found in review): completion previously checked only "1 crate + 1 fish", so a
	-- player could take the crate and both fish, never visit the prisoners, and hand in. The prisoner
	-- step is the whole point of the task, so it is now proven state rather than assumed.
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

---Transactional completion.
---
---Every precondition is verified first. The reward is created BEFORE the required items are consumed,
---so a player whose inventory is too full to receive the gem loses nothing and can simply retry - the
---previous revision consumed both items and then ignored addItem's result entirely, which could
---silently destroy the run's work. If the second removal ever fails, the first item is restored.
---@param player Player
---@return boolean
function Zzuppliezz.complete(player)
	if Zzuppliezz.blockingReason(player) ~= nil then
		return false
	end

	local gem = Zzuppliezz.GEM_REWARDS[math.random(#Zzuppliezz.GEM_REWARDS)]
	if not player:addItem(gem, 1, false) then
		return false
	end

	if not player:removeItem(Zzuppliezz.ITEM_WEAPONS_CRATE, 1) then
		player:removeItem(gem, 1)
		return false
	end

	if not player:removeItem(Zzuppliezz.ITEM_CORNED_FISH, 1) then
		-- Roll back so the player is never left having paid the crate for nothing.
		player:addItem(Zzuppliezz.ITEM_WEAPONS_CRATE, 1, false)
		player:removeItem(gem, 1)
		return false
	end

	player:kv():set(Zzuppliezz.KEY_ACTIVE, false)
	player:kv():set(Zzuppliezz.KEY_EVER_COMPLETED, true)
	player:kv():set(Zzuppliezz.KEY_TIMER, os.time() + Zzuppliezz.REPEAT_INTERVAL)
	return true
end

ChildrenTasks.register({
	name = "Zzuppliezz",
	isActive = Zzuppliezz.isActive,
	hasEverCompleted = Zzuppliezz.hasEverCompleted,
})
