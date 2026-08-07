-- "Zzuppliezz" - the repeatable Children of the Revolution supply task given by Zalamon.
--
-- This exists because Wrath of the Emperor Mission 05 ("New in Town") requires the task to have been
-- completed at least once. Zalamon previously advanced WOTE straight past that gate with no check,
-- because the task itself was never implemented anywhere in this repository.
--
-- Two DIFFERENT concepts are tracked, and they must not be conflated:
--
--   * the CURRENT task state (accepted / on cooldown) - transient, resets every run;
--   * EVER COMPLETED - permanent, one-way, and the only thing WOTE Mission 05 is allowed to gate on.
--
-- Gating Mission 05 on the transient state would let a player who completed the task months ago be
-- blocked again the moment their daily cooldown rolled over.
--
-- State lives in the player KV store rather than a raw legacy storage number, matching the convention
-- this repository already uses for repeatable tasks (see npc/a_sweaty_cyclops.lua's
-- "koshei-amulet-done" / "koshei-amulet-timer" keys). No arbitrary storage id was invented.

Zzuppliezz = Zzuppliezz or {}

-- Task is offered only once the player has finished Children of the Revolution, which is the point at
-- which the reference says the daily becomes available.
Zzuppliezz.REQUIRED_CHILDREN_QUESTLINE = 21

Zzuppliezz.KEY_ACTIVE = "zzuppliezz-active"
Zzuppliezz.KEY_TIMER = "zzuppliezz-timer"
Zzuppliezz.KEY_EVER_COMPLETED = "zzuppliezz-ever-completed"

Zzuppliezz.REPEAT_INTERVAL = 20 * 60 * 60 -- 20 hours, per the reference

Zzuppliezz.ITEM_WEAPONS_CRATE = 10247 -- "This crate contains a set of weapons" (data/items/items.xml)
Zzuppliezz.ITEM_CORNED_FISH = 10218 -- "prepared as provision for soldiers"
Zzuppliezz.FISH_REQUIRED = 2 -- one is given to the prisoners, one is returned to Zalamon

-- Authoritative five-gem reward pool, resolved from this project's own item data rather than assumed:
-- the classic 2145-2150 ids are NOT gems in this client version (they are "slits", "blades" and
-- reserved sprites), so the real small-gem ids are used.
Zzuppliezz.GEM_REWARDS = { 3028, 3029, 3030, 3032, 3033 }

---@param player Player
---@return boolean
function Zzuppliezz.hasEverCompleted(player)
	if not player then
		return false
	end

	return player:kv():get(Zzuppliezz.KEY_EVER_COMPLETED) == true
end

---@param player Player
---@return boolean
function Zzuppliezz.isActive(player)
	if not player then
		return false
	end

	return player:kv():get(Zzuppliezz.KEY_ACTIVE) == true
end

---Seconds remaining before the task may be taken again; 0 when it is available.
---@param player Player
---@return number
function Zzuppliezz.cooldownRemaining(player)
	if not player then
		return 0
	end

	local finishTime = player:kv():get(Zzuppliezz.KEY_TIMER)
	if not finishTime or type(finishTime) ~= "number" then
		return 0
	end

	local remaining = finishTime - os.time()
	return remaining > 0 and remaining or 0
end

---@param player Player
---@return boolean true when the player may accept the task right now
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
function Zzuppliezz.start(player)
	if not player then
		return false
	end

	player:kv():set(Zzuppliezz.KEY_ACTIVE, true)
	return true
end

---Transactional completion. Verifies EVERY required item before consuming ANY of them, so a player
---who is missing the fish never loses the crate (or vice versa) and can simply come back.
---@param player Player
---@return boolean
function Zzuppliezz.complete(player)
	if not player or not Zzuppliezz.isActive(player) then
		return false
	end

	-- getItemCount is genuinely count-aware; getItemById's second argument is deepSearch, not a count.
	if player:getItemCount(Zzuppliezz.ITEM_WEAPONS_CRATE) < 1 or player:getItemCount(Zzuppliezz.ITEM_CORNED_FISH) < 1 then
		return false
	end

	if not player:removeItem(Zzuppliezz.ITEM_WEAPONS_CRATE, 1) then
		return false
	end

	if not player:removeItem(Zzuppliezz.ITEM_CORNED_FISH, 1) then
		return false
	end

	player:kv():set(Zzuppliezz.KEY_ACTIVE, false)
	player:kv():set(Zzuppliezz.KEY_EVER_COMPLETED, true)
	player:kv():set(Zzuppliezz.KEY_TIMER, os.time() + Zzuppliezz.REPEAT_INTERVAL)

	-- canDropOnMap = false: the gem is the task reward, so a truthy result proves it reached the
	-- player's inventory rather than the floor.
	local gem = Zzuppliezz.GEM_REWARDS[math.random(#Zzuppliezz.GEM_REWARDS)]
	player:addItem(gem, 1, false)

	return true
end
