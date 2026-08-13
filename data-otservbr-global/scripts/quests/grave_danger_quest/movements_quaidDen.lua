local quaidDen = MoveEvent()

function quaidDen.onStepIn(creature, item, position, fromPosition)
	if creature:isMonster() then
		return true
	end

	if creature:getStorageValue(Storage.Quest.U12_20.GraveDanger.CustodianKilled) < 1 then
		creature:teleportTo(Position(33401, 32658, 3))
		creature:sendTextMessage(MESSAGE_EVENT_ADVANCE, "With the power of the dark Custodian still holding away, the fog is keeping you from entering Quaid's den.")
		return true
	end

	-- CORRECTION (correction pass section K): the Cart Packed With Gold escort is a mandatory Order of
	-- the Cobra mechanic per the owner reference, gating progression toward Guard Captain Quaid. Its
	-- physical surface (waypoints/route) is MAP_REQUIRED and not yet implemented against a proven map
	-- (see the Manual RME Manifest) - CartComplete is therefore never set by any code path yet, so this
	-- fails closed rather than silently skipping a mandatory mechanic. This intentionally blocks Quaid's
	-- den until the Cart mechanic is built.
	if creature:getStorageValue(Storage.Quest.U12_20.GraveDanger.CobraBastion.CartComplete) < 1 then
		creature:teleportTo(Position(33401, 32658, 3))
		creature:sendTextMessage(MESSAGE_EVENT_ADVANCE, "The cart packed with gold still needs to be secured before you can proceed.")
		return true
	end

	return true
end

quaidDen:id(31733)
quaidDen:register()
