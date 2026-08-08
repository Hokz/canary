local setting = {
	arenaPosition = Position(33154, 31415, 7),
	successPosition = Position(33145, 31419, 7),
}
local TheNewFrontier = Storage.Quest.U8_54.TheNewFrontier

local function completeTest(cid)
	local player = Player(cid)
	if not player then
		return false
	end
	-- CONFIRMED BUG (found in review): this only checked Questline==17, which stays true even if the
	-- player died during the 2-minute wait. Dying inside the arena respawns the player at their temple
	-- far away, but the scheduled event still fired 2 minutes later and granted credit regardless -
	-- "surviving" was never actually verified, only that 2 minutes of real time had passed. Requiring
	-- the player to still be inside the arena area when the timer fires closes this: death (or any other
	-- way of leaving) means the timer finds them elsewhere and the test silently fails instead of
	-- granting a false pass. A legitimate survivor is still standing in the arena when the timer ends.
	if player:getStorageValue(TheNewFrontier.Questline) == 17 and player:getPosition():getDistance(setting.arenaPosition) <= 3 then
		player:teleportTo(setting.successPosition)
		player:setStorageValue(TheNewFrontier.Questline, 18)
		player:setStorageValue(TheNewFrontier.Mission06, 3) --Questlog, The New Frontier Quest "Mission 06: Days Of Doom"
		player:say("You have braved the tiral of the Mooh'tah master.", TALKTYPE_MONSTER_SAY)
	end
end

local minotaurBoss = MoveEvent()

function minotaurBoss.onStepIn(creature, item, position, fromPosition)
	local player = creature:getPlayer()
	if not player then
		return false
	end

	if roomIsOccupied(setting.arenaPosition, true, 6, 6) or player:getStorageValue(TheNewFrontier.Questline) ~= 17 then
		player:teleportTo(fromPosition)
		fromPosition:sendMagicEffect(CONST_ME_TELEPORT)
		return player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "You don't have access to this area.")
	end

	addEvent(completeTest, 2 * 60 * 1000, player.uid)
	player:teleportTo(setting.arenaPosition)
	setting.arenaPosition:sendMagicEffect(CONST_ME_TELEPORT)
	return true
end

minotaurBoss:position(Position(33146, 31413, 6))
minotaurBoss:register()
