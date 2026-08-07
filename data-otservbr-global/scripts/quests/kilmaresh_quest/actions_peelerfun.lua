local peelerfun = Action()

-- CONFIRMED BUG (found in review): target.itemid was indexed with no proof that `target` exists or is
-- an Item. Lua::pushThing (lua_functions_loader.cpp:190-213) pushes Item userdata for item targets,
-- Creature userdata for creatures, and a plain metatable-less table {uid=0, itemid=0, ...} when there
-- is no target at all - so ground use, self use and creature targets all reached this line. On a
-- Creature, revscriptsys.lua's CreatureIndex returns a hardcoded itemid of 1, which would have been
-- compared against the config list; on the no-target sentinel it reads 0. Neither crashed here purely
-- because the comparison is against a fixed list, but the same shape crashed in actions_scissorsfun,
-- and nothing guaranteed that. Now uses the same proven pattern as the corrected scissors handler:
-- type is established before the target is touched, and a non-Item target falls through to `false` so
-- other handlers still get their chance.
local peelTargets = { 31376 }

function peelerfun.onUse(player, item, fromPosition, target, toPosition, isHotkey)
	if not target or type(target) ~= "userdata" or not target.isItem or not target:isItem() then
		return false
	end

	if not table.contains(peelTargets, target.itemid) then
		return false
	end

	if player:getStorageValue(Storage.Quest.U12_20.KilmareshQuest.Eighth.Tefrit) ~= 2 then
		player:sendTextMessage(MESSAGE_FAILURE, "Sorry, not possible.")
		return true
	end

	player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "You are peeling a piece of tark off the again tree.")
	player:addItem(31329, 1)

	return true
end

peelerfun:id(31328)
peelerfun:register()
