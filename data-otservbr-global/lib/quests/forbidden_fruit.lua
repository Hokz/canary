-- "Forbidden Fruit" (dialogue keyword "collect") - daily repeatable Chartan task, NOT the
-- similarly-named collectible item that appears elsewhere in the game (different content
-- entirely - do not confuse the two).
--
-- PROVENANCE:
--   * Task name, dialogue keyword, NPC (Chartan), the seven required samples, the eat-then-report
--     completion sequence, first-completion achievement, and the four owner reward groups per
--     vocation - OWNER REFERENCE (Children of the Revolution PDF, Task 3 "Collect").
--   * 20-hour repeat interval - CURRENT TIBIA / CipSoft patch evidence (bounded research).
--   * FORBIDDEN_FRUIT_AVAILABILITY = REFERENCE_CONFLICT: the owner reference shows Forbidden Fruit
--     starting at Chartan after the WOTE Mission 05 handoff, but external sources disagree with
--     each other on the exact progression boundary (one says "after WOTE has started", another
--     says "only after WOTE is completed"; the confirmed CipSoft patch establishes Chartan as the
--     contractor and the 20h interval but doesn't resolve this). ForbiddenFruit.REQUIRED_CHILDREN_
--     QUESTLINE plus ChildrenTasks.hasWoteHandoffOccurred (checked in npc/chartan.lua, not in this
--     file) implements the OWNER REFERENCE reading (WrathOfTheEmperor.Questline >= 13) as this
--     project's authoritative implementation contract - labeled OWNER_REFERENCE_IMPLEMENTATION, not
--     claimed as an independently Global-exact match.
--   * The seven sample item ids - PROJECT DATA (items.xml, resolved by exact name).
--   * Equal-probability reward group selection - NOT independently proven; bounded research found
--     no documented exact distribution. CUSTOM_GLOBAL_LIKE_PENDING_EXACT_REWARD_PROBABILITY.
--   * The reward group is selected once and persisted for the run (KEY_REWARD_GROUP below) rather
--     than re-rolled on every report attempt, so a player cannot deliberately induce a delivery
--     failure (e.g. a full inventory) to re-roll for a more convenient group.
--   * PARTIALLY MAP_REQUIRED: 1 of the 7 physical plant/seed source objects. Four audit rounds
--     progressively corrected earlier errors: round 1 incorrectly searched the OTBM for the seven
--     SAMPLE item ids (12229-12235) instead of the plants themselves; round 2 required each plant
--     to be the ONLY instance of its item id within a +/-5 tile radius of its marker; round 3
--     relaxed that for Witherstem once habitat corroboration existed; round 4 corrected the Rotten
--     Witches' Cauldron identity (the marker tile holds a proven hedge-row/border decoration, not
--     the plant - the real Rotten Plant object sits one tile away) and accepted Wraithtongue's
--     externally-confirmed identity at a reachable instance within the documented task area rather
--     than requiring it to sit on the exact marker tile. Sprocketwhip (10718), Carnivortex (10716),
--     Toxic Tulip (10717), Witherstem (10715), Rotten Plant (9886), and Wraithtongue (10720) are
--     PROVEN - wired below via actions_forbidden_fruit_collect.lua. Screaming Cherry Tree is the
--     one remaining sample: its marker resolves to item 10000, which a full-map check shows is the
--     generic background tree used at ~40 different positions throughout the entire Northern Zao
--     region (not a distinctively-placed quest object), and no better candidate was found in a
--     final bounded search of the marker's neighborhood, the wider task route, and every other
--     unnamed object nearby. See the PR body for the full 7-position audit matrix and Screaming
--     Cherry Tree's manual map manifest. Collecting the 6 wired samples is necessary but not
--     sufficient - ForbiddenFruit.hasCollectedAll still requires all 7, so the task remains
--     uncompletable until Screaming Cherry Tree's anchor is proven. Rather than ship an acceptable-
--     but-uncompletable task (a permanent daily-lane soft-lock), player-facing acceptance is gated
--     off entirely via WORLD_READY/isWorldReady() below until that seventh source is wired - all
--     other code, state, and rewards in this file are already complete and are not affected by
--     that gate.

ForbiddenFruit = ForbiddenFruit or {}

-- SAFETY GATE: false because the seventh physical sample source (Screaming Cherry Tree) is not
-- proven/wired - see PROVENANCE above and the PR body's manual map manifest. Without this gate,
-- Chartan's canAccept() check would let a player accept the task, collect the 6 available samples,
-- and never be able to reach ForbiddenFruit.hasCollectedAll() - a PERMANENT daily-lane soft-lock,
-- since the shared daily cooldown (ChildrenTasks.markDailyReported) never starts without a
-- successful report, leaving Zzuppliezz blocked indefinitely too. Flip to true ONLY once Screaming
-- Cherry Tree is wired via actions_forbidden_fruit_collect.lua (all other state/rewards/samples
-- below are already correct and complete - no other change is expected to be needed at that time).
ForbiddenFruit.WORLD_READY = false

---Whether Forbidden Fruit may currently be accepted by any player. See WORLD_READY above.
---@return boolean
function ForbiddenFruit.isWorldReady()
	return ForbiddenFruit.WORLD_READY
end

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
local KEY_EVER_COMPLETED = "forbidden-fruit-ever-completed"
-- Per-cycle progress: which of the 7 samples were collected THIS cycle and which were eaten THIS
-- cycle, so an old/stashed sample (collected on a previous cycle, or bought/traded) can never
-- silently satisfy a new cycle's requirement.
local KEY_COLLECTED_PREFIX = "forbidden-fruit-collected-"
local KEY_EATEN_PREFIX = "forbidden-fruit-eaten-"
-- The reward group chosen for this run's completion attempt, persisted so a failed delivery retry
-- reuses the same group instead of re-rolling (see provenance note above).
local KEY_REWARD_GROUP = "forbidden-fruit-reward-group"

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

---Delegates to the SHARED daily-lane timer - see ChildrenTasks.dailyCooldownRemaining - so a
---Zzuppliezz completion blocks this task too, and vice versa.
---@param player Player
---@return number
function ForbiddenFruit.cooldownRemaining(player)
	return ChildrenTasks.dailyCooldownRemaining(player)
end

---Fails closed while the world isn't ready (see WORLD_READY), regardless of caller - the library
---itself is the enforcement point, not just the NPC dialogue that happens to call this today.
---@param player Player
---@return boolean
function ForbiddenFruit.canAccept(player)
	if not player or not ForbiddenFruit.isWorldReady() then
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

---Starts a NEW run. Refuses to touch an already-active run - matching Zzuppliezz.start()'s
---invariant - so per-run collection/consumption progress and ORIGIN can never be reset or rewritten
---mid-run, even if a future caller is added later. There is no restart/abandon behavior here; this
---is purely a defensive guard, since canAccept() already prevents this from being reachable through
---the current dialogue.
---@param player Player
---@param origin string
---@return boolean
function ForbiddenFruit.start(player, origin)
	if not player or ForbiddenFruit.isActive(player) then
		return false
	end

	for _, itemId in ipairs(ForbiddenFruit.SAMPLES) do
		player:kv():set(KEY_COLLECTED_PREFIX .. itemId, false)
		player:kv():set(KEY_EATEN_PREFIX .. itemId, false)
	end
	player:kv():set(KEY_ACTIVE, true)
	player:kv():set(KEY_ORIGIN, origin)
	player:kv():remove(KEY_REWARD_GROUP)
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

---Selects this run's reward group on the FIRST completion attempt and persists it, so a later
---retry (e.g. after a delivery failure) always reuses the same group instead of re-rolling.
---@param player Player
---@param vocation string
---@return table|nil
local function selectedRewardGroup(player, vocation)
	local groups = ForbiddenFruit.REWARDS[vocation]
	if not groups then
		return nil
	end

	local index = player:kv():get(KEY_REWARD_GROUP)
	if type(index) ~= "number" or not groups[index] then
		-- CUSTOM_GLOBAL_LIKE_PENDING_EXACT_REWARD_PROBABILITY: equal chance among the four groups,
		-- no documented exact distribution found.
		index = math.random(#groups)
		player:kv():set(KEY_REWARD_GROUP, index)
	end

	return groups[index]
end

---Transactional completion: either every required item is granted or none are. A failed item grant
---rolls back everything already granted THIS attempt and leaves the task fully reportable - no
---partial reward, no EXP, no achievement, no cooldown. The reward group itself was already chosen
---and persisted (selectedRewardGroup), so retrying after a failure can never re-roll for a more
---convenient one.
---@param player Player
---@param vocation string
---@return boolean
function ForbiddenFruit.complete(player, vocation)
	if ForbiddenFruit.blockingReason(player) ~= nil then
		return false
	end

	local group = selectedRewardGroup(player, vocation)
	if not group then
		return false
	end

	if group.items then
		local granted = {}
		for _, rewardItem in ipairs(group.items) do
			if player:addItem(rewardItem.id, rewardItem.count, false) then
				granted[#granted + 1] = rewardItem
			else
				for _, rollbackItem in ipairs(granted) do
					player:removeItem(rollbackItem.id, rollbackItem.count)
				end
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
	player:kv():remove(KEY_REWARD_GROUP)
	ChildrenTasks.markDailyReported(player)
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
