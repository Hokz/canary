-- Single owner of the "heavy stone" (12724) Action registration.
--
-- Two quests arm catapults with this same item: The Rookie Guard's Mission02 roof catapults
-- (action ids 40006-40009) and A Pirate's Tail's ship-raid catapults (action id 45911). Both used
-- to call :id(12724) from their own script, and Actions::registerLuaItemEvent keeps only the first
-- registration for a given item id and rejects the second with a "Duplicate registered item with
-- id" warning. Because both files live under data-otservbr-global/scripts, which the loader walks
-- with an unsorted recursive_directory_iterator, which quest survived startup was down to raw
-- filesystem order - and the surviving handler returned true unconditionally, so the losing quest
-- did not even fall back to the engine's built-in item handling: its catapult step was silently
-- inert.
--
-- Each quest keeps its own logic, storages, experience, bitmasks and messages in its own file and
-- exposes it as one entry point. This file only decides which quest a use belongs to, from the
-- target's action id, and returns false for anything else so that normal engine handling applies
-- instead of the old silent swallow.
local ROOKIE_GUARD_CATAPULT_AIDS = { [40006] = true, [40007] = true, [40008] = true, [40009] = true }
local PIRATES_TAIL_CATAPULT_AID = 45911

local heavyStone = Action()

function heavyStone.onUse(player, item, fromPosition, target, toPosition, isHotkey)
	if not target or type(target.getActionId) ~= "function" then
		return false
	end

	local targetActionId = target:getActionId()
	if targetActionId == PIRATES_TAIL_CATAPULT_AID and type(APiratesTailLoadHeavyStone) == "function" then
		return APiratesTailLoadHeavyStone(player, item, target)
	end
	if ROOKIE_GUARD_CATAPULT_AIDS[targetActionId] and type(RookieGuardLoadHeavyStone) == "function" then
		return RookieGuardLoadHeavyStone(player, item, target)
	end

	return false
end

heavyStone:id(12724)
heavyStone:register()
