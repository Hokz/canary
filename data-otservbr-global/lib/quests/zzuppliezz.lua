-- "Zzuppliezz" - daily repeatable Children of the Revolution supply task.
--
-- PROVENANCE:
--   * Task exists, name, dialogue keyword family, and the three-step objective (weapons crate,
--     corned fish, feed prisoners) - OWNER REFERENCE (Children of the Revolution PDF, Task 1).
--   * 20-hour repeat interval - CURRENT TIBIA / CipSoft patch evidence (bounded research).
--   * Weapons crate / corned fish item ids (10247, 10218) - PROJECT DATA (items.xml descriptions
---    match: "This crate contains a set of weapons", "prepared as provision for soldiers").
--   * "Vive la Resistance" achievement on first prisoner feeding - OWNER REFERENCE.
--   * Gem reward pool (red/yellow/green/blue/violet) - OWNER REFERENCE names the pool; PROJECT
--     DATA for the exact item ids.
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
--   * Per-run interaction proof, transactional turn-in, and cycle-reacquisition instead of an
--     "abandon" command or per-source replacement counters - CUSTOM_GLOBAL_LIKE_ZZUPPLIEZZ_CYCLE.
--     Exact CipSoft handling of a mid-run lost item is not documented anywhere found. Each source
--     grants its item(s) exactly once per cycle (never a farmable repeat-click); a player who
--     starts fresh (re-accepting the task while it's already active, an explicit choice offered by
--     the NPC, not a separate invented "abandon" keyword) simply reacquires proof from scratch.

Zzuppliezz = Zzuppliezz or {}

Zzuppliezz.REQUIRED_CHILDREN_QUESTLINE = 21
Zzuppliezz.REPEAT_INTERVAL = 20 * 60 * 60 -- 20 hours, CURRENT_SOURCE_PROVEN

Zzuppliezz.ITEM_WEAPONS_CRATE = 10247
Zzuppliezz.ITEM_CORNED_FISH = 10218
Zzuppliezz.FISH_REQUIRED = 2 -- one fed to the prisoners, one returned to the task giver

Zzuppliezz.GEM_REWARDS = { 3039, 3037, 3038, 3041, 3036 } -- red, yellow, green, blue, violet

local KEY_ACTIVE = "zzuppliezz-active"
local KEY_ORIGIN = "zzuppliezz-origin"
local KEY_EVER_COMPLETED_ZALAMON = "zzuppliezz-ever-completed-zalamon"
local KEY_EVER_COMPLETED_CHARTAN = "zzuppliezz-ever-completed-chartan"
-- Per-cycle progress. Reset whenever a run starts, so nothing carries between cycles.
local KEY_CRATE_TAKEN = "zzuppliezz-crate-taken"
local KEY_FISH_TAKEN = "zzuppliezz-fish-taken"
local KEY_PRISONERS_FED = "zzuppliezz-prisoners-fed"

local function flag(player, key)
	return player:kv():get(key) == true
end

---@param player Player
---@return boolean
function Zzuppliezz.isActive(player)
	return player ~= nil and flag(player, KEY_ACTIVE)
end

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

---Starts (or restarts) a run. Restarting an already-active run is an explicit player choice
---offered by the NPC dialogue - not a separate invented "abandon" command - and simply clears
---per-cycle proof so a new cycle's completion can never be satisfied by an old cycle's leftovers.
---@param player Player
---@param origin string
---@return boolean
function Zzuppliezz.start(player, origin)
	if not player then
		return false
	end

	player:kv():set(KEY_CRATE_TAKEN, false)
	player:kv():set(KEY_FISH_TAKEN, false)
	player:kv():set(KEY_PRISONERS_FED, false)
	player:kv():set(KEY_ACTIVE, true)
	player:kv():set(KEY_ORIGIN, origin)
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

---Transactional completion. The reward is granted before the required items are consumed, so a
---player whose inventory is too full to receive the gem loses nothing and can simply retry. If the
---second removal ever fails, the first item is restored, so a partial consumption never happens.
---Which "ever completed" flag is set is decided by the ORIGIN RECORDED AT ACCEPTANCE, not by which
---NPC this call happens to be reported to - a task started at Zalamon must still count as a
---Zalamon-origin completion even when reported to Chartan after the WOTE handoff.
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
		player:addItem(Zzuppliezz.ITEM_WEAPONS_CRATE, 1, false)
		player:removeItem(gem, 1)
		return false
	end

	player:kv():set(KEY_ACTIVE, false)
	local origin = Zzuppliezz.getOrigin(player)
	if origin == ChildrenTasks.ORIGIN_ZALAMON then
		player:kv():set(KEY_EVER_COMPLETED_ZALAMON, true)
	else
		player:kv():set(KEY_EVER_COMPLETED_CHARTAN, true)
	end
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
