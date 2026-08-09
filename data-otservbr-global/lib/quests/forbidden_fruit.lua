-- "Forbidden Fruit" (dialogue keyword "collect") - daily repeatable Chartan task, NOT the
-- similarly-named collectible item that appears elsewhere in the game (different content
-- entirely - do not confuse the two).
--
-- PROVENANCE:
--   * Task name, dialogue keyword, NPC (Chartan), the seven required samples, the eat-then-report
--     completion sequence, first-completion achievement, and the four owner reward groups per
--     vocation - OWNER REFERENCE (Children of the Revolution PDF, Task 3 "Collect").
--   * 20-hour repeat interval - CURRENT TIBIA / CipSoft patch evidence (bounded research).
--   * The seven sample item ids - PROJECT DATA (items.xml, resolved by exact name).
--   * Equal-probability reward group selection - NOT independently proven; bounded research found
--     no documented exact distribution. CUSTOM_GLOBAL_LIKE_PENDING_EXACT_REWARD_PROBABILITY.
--   * MAP_REQUIRED: the seven physical plant/seed source objects. A full, unbounded scan of the
--     exact configured OTBM (otservbr.otbm v3.6.1) for all seven sample item ids (12229-12235)
--     found zero placements anywhere on the map, and bounded external research did not surface
--     usable coordinates either. This is expected if the items are granted by interacting with a
--     generic decorative plant (the same pattern used throughout this project for other one-time
--     quest pickups), but no candidate decoration could be identified with the confidence this
--     project's standing "no guessed coordinate" rule requires - there was no reliable way to
--     distinguish "the" seven correct plants from the very large number of unrelated decorative
--     plants across the region. The task's dialogue and state machine are implemented in full and
--     ready to use; the seven world interactions are NOT implemented and must be wired once the
--     physical anchors are proven (see the PR body for the exact manual RME manifest).

ForbiddenFruit = ForbiddenFruit or {}

ForbiddenFruit.REQUIRED_CHILDREN_QUESTLINE = 21
ForbiddenFruit.REPEAT_INTERVAL = 20 * 60 * 60 -- 20 hours, CURRENT_SOURCE_PROVEN

-- 1 Toxic Tulip Seed, 2 Screaming Cherry, 3 Rotten Witches' Cauldron Seed, 4 Tonguefruit,
-- 5 Sprocketwhip Cone, 6 Meaty Vortex, 7 Witherblossom (order matches the owner reference).
ForbiddenFruit.SAMPLES = { 12233, 12229, 12232, 12231, 12234, 12230, 12235 }

ForbiddenFruit.ACHIEVEMENT = "Extreme Degustation"

-- OWNER REFERENCE reward table, resolved to current project item ids by exact name. Group C/D are
-- pure experience; Groups A/B each grant TWO items - the vocation-specific stack plus a bonus item
-- (Terra Amulet for Group A, Dwarven Ring for Group B) shared across all three vocation tables.
ForbiddenFruit.REWARDS = {
	["knight"] = {
		{ experience = 12000, items = { { id = 268, count = 100 }, { id = 814, count = 1 } } }, -- 100 mana potions + terra amulet
		{ experience = 12000, items = { { id = 239, count = 25 }, { id = 3097, count = 1 } } }, -- 25 great health potions + dwarven ring
		{ experience = 20000 },
		{ experience = 25000 },
	},
	["paladin"] = {
		{ experience = 12000, items = { { id = 7368, count = 50 }, { id = 814, count = 1 } } }, -- 50 assassin stars + terra amulet
		{ experience = 12000, items = { { id = 7642, count = 25 }, { id = 3097, count = 1 } } }, -- 25 great spirit potions + dwarven ring
		{ experience = 20000 },
		{ experience = 25000 },
	},
	["druid/sorcerer"] = {
		{ experience = 12000, items = { { id = 3155, count = 45 }, { id = 814, count = 1 } } }, -- 45 sudden death runes + terra amulet
		{ experience = 12000, items = { { id = 238, count = 40 }, { id = 3097, count = 1 } } }, -- 40 great mana potions + dwarven ring
		{ experience = 20000 },
		{ experience = 25000 },
	},
}

local KEY_ACTIVE = "forbidden-fruit-active"
local KEY_ORIGIN = "forbidden-fruit-origin"
local KEY_TIMER = "forbidden-fruit-timer"
local KEY_EVER_COMPLETED = "forbidden-fruit-ever-completed"
-- Per-cycle progress: which of the 7 samples were collected THIS cycle and which were eaten THIS
-- cycle, so an old/stashed sample (collected on a previous cycle, or bought/traded) can never
-- silently satisfy a new cycle's requirement.
local KEY_COLLECTED_PREFIX = "forbidden-fruit-collected-"
local KEY_EATEN_PREFIX = "forbidden-fruit-eaten-"

local function flag(player, key)
	return player:kv():get(key) == true
end

---@param player Player
---@return boolean
function ForbiddenFruit.isActive(player)
	return player ~= nil and flag(player, KEY_ACTIVE)
end

---@param player Player
---@return string|nil
function ForbiddenFruit.getOrigin(player)
	if not player then
		return nil
	end
	local origin = player:kv():get(KEY_ORIGIN)
	return type(origin) == "string" and origin or nil
end

---Forbidden Fruit never qualifies for the WOTE Mission 05 requirement, regardless of origin.
---@return boolean
function ForbiddenFruit.hasEverCompletedFromOrigin()
	return false
end

---@param player Player
---@return boolean
function ForbiddenFruit.hasEverCompleted(player)
	return player ~= nil and flag(player, KEY_EVER_COMPLETED)
end

---@param player Player
---@param itemId number
---@return boolean
function ForbiddenFruit.hasCollected(player, itemId)
	return player ~= nil and flag(player, KEY_COLLECTED_PREFIX .. itemId)
end

---@param player Player
---@param itemId number
function ForbiddenFruit.markCollected(player, itemId)
	player:kv():set(KEY_COLLECTED_PREFIX .. itemId, true)
end

---@param player Player
---@param itemId number
---@return boolean
function ForbiddenFruit.hasEaten(player, itemId)
	return player ~= nil and flag(player, KEY_EATEN_PREFIX .. itemId)
end

---@param player Player
---@param itemId number
function ForbiddenFruit.markEaten(player, itemId)
	player:kv():set(KEY_EATEN_PREFIX .. itemId, true)
end

---@param player Player
---@return number
function ForbiddenFruit.cooldownRemaining(player)
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
function ForbiddenFruit.canAccept(player)
	if not player then
		return false
	end

	if player:getStorageValue(Storage.Quest.U8_54.ChildrenOfTheRevolution.Questline) < ForbiddenFruit.REQUIRED_CHILDREN_QUESTLINE then
		return false
	end

	if ChildrenTasks.hasActiveDailyTask(player) and not ForbiddenFruit.isActive(player) then
		return false
	end

	return not ForbiddenFruit.isActive(player) and ForbiddenFruit.cooldownRemaining(player) == 0
end

---@param player Player
---@param origin string
---@return boolean
function ForbiddenFruit.start(player, origin)
	if not player then
		return false
	end

	for _, itemId in ipairs(ForbiddenFruit.SAMPLES) do
		player:kv():set(KEY_COLLECTED_PREFIX .. itemId, false)
		player:kv():set(KEY_EATEN_PREFIX .. itemId, false)
	end
	player:kv():set(KEY_ACTIVE, true)
	player:kv():set(KEY_ORIGIN, origin)
	return true
end

---@param player Player
---@return boolean
function ForbiddenFruit.hasCollectedAll(player)
	for _, itemId in ipairs(ForbiddenFruit.SAMPLES) do
		if not ForbiddenFruit.hasCollected(player, itemId) then
			return false
		end
	end
	return true
end

---@param player Player
---@return boolean
function ForbiddenFruit.hasEatenAll(player)
	for _, itemId in ipairs(ForbiddenFruit.SAMPLES) do
		if not ForbiddenFruit.hasEaten(player, itemId) then
			return false
		end
	end
	return true
end

---Why the turn-in cannot be completed, or nil when it can. Collecting all seven is not enough -
---the owner reference explicitly requires eating all seven during the same run before reporting.
---@param player Player
---@return string|nil
function ForbiddenFruit.blockingReason(player)
	if not player or not ForbiddenFruit.isActive(player) then
		return "inactive"
	end

	if not ForbiddenFruit.hasCollectedAll(player) then
		return "collect"
	end

	if not ForbiddenFruit.hasEatenAll(player) then
		return "eat"
	end

	return nil
end

---@param vocation string
---@return table|nil
local function pickRewardGroup(vocation)
	local table_ = ForbiddenFruit.REWARDS[vocation]
	if not table_ then
		return nil
	end
	-- CUSTOM_GLOBAL_LIKE_PENDING_EXACT_REWARD_PROBABILITY: equal chance among the four groups, no
	-- documented exact distribution found.
	return table_[math.random(#table_)]
end

---@param player Player
---@param vocation string
---@return boolean
function ForbiddenFruit.complete(player, vocation)
	if ForbiddenFruit.blockingReason(player) ~= nil then
		return false
	end

	local group = pickRewardGroup(vocation)
	if not group then
		return false
	end

	if group.items then
		for _, rewardItem in ipairs(group.items) do
			if not player:addItem(rewardItem.id, rewardItem.count, false) then
				return false
			end
		end
	end

	player:addExperience(group.experience, true)

	if not player:hasAchievement(ForbiddenFruit.ACHIEVEMENT) then
		player:addAchievement(ForbiddenFruit.ACHIEVEMENT)
	end

	player:kv():set(KEY_ACTIVE, false)
	player:kv():set(KEY_EVER_COMPLETED, true)
	player:kv():set(KEY_TIMER, os.time() + ForbiddenFruit.REPEAT_INTERVAL)
	return true
end

ChildrenTasks.register({
	name = "Forbidden Fruit",
	lane = ChildrenTasks.LANE_DAILY,
	qualifiesForWote = false,
	isActive = ForbiddenFruit.isActive,
	getOrigin = ForbiddenFruit.getOrigin,
	hasEverCompletedFromOrigin = ForbiddenFruit.hasEverCompletedFromOrigin,
})
