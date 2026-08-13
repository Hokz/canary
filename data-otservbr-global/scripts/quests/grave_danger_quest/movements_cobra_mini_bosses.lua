local FireWall = MoveEvent()

function FireWall.onStepIn(creature, item, position, fromPosition)
	if creature:isMonster() then
		return true
	end

	if fromPosition.y == 32691 then
		if creature:getStorageValue(Storage.Quest.U12_20.GraveDanger.FireWall) >= 1 then
			-- CORRECTION (executor contract, section 27): one-use per crossing, not a permanent
			-- authorization. Consuming the flag here means the next outward crossing needs a fresh
			-- pass through the x==33385 gate below - which CustodianKilled (a permanent flag) always
			-- allows, but only grants ONE further outward crossing at a time, matching "if the player
			-- returns behind the barrier, they must again qualify (re-cross the gate) before crossing
			-- outward again" rather than an infinite FireWall=1 authorization.
			creature:setStorageValue(Storage.Quest.U12_20.GraveDanger.FireWall, 0)
			creature:teleportTo(Position(position.x, position.y + 2, position.z))
		else
			creature:teleportTo(fromPosition)
		end
	elseif fromPosition.y == 32693 then
		creature:teleportTo(Position(position.x, position.y - 2, position.z))
	elseif fromPosition.x == 33385 then
		-- CONFIRMED BUG (pre-existing): the "pass through" teleport sat OUTSIDE the else, so it ran
		-- unconditionally - a player who had never killed the Custodian was bounced back by the else
		-- branch and then immediately teleported through anyway on the very next line. The fire
		-- barrier gate did nothing at all.
		--
		-- CORRECTION (correction pass section L): gated on FireWall (ephemeral, minted only by a fresh
		-- Custodian kill - see grave_danger_death in creaturescripts_boss_kill.lua) instead of the
		-- permanent CustodianKilled flag. Minting FireWall here off the permanent flag let a player
		-- re-cross indefinitely after a single kill, ever since, with no need to ever fight the
		-- Custodian again - this leg no longer mints FireWall at all, it only spends the pass that a
		-- fresh kill already granted; the actual one-use consumption still happens at the y==32691 leg
		-- above, unchanged from the prior pass.
		if creature:getStorageValue(Storage.Quest.U12_20.GraveDanger.FireWall) >= 1 then
			creature:sendTextMessage(MESSAGE_EVENT_ADVANCE, "You pass the fire without taking any damage. It's now or never...")
			creature:teleportTo(Position(position.x + 2, position.y, position.z))
		else
			creature:sendTextMessage(MESSAGE_EVENT_ADVANCE, "The searing flames drive you back. Something here must be dealt with first.")
			creature:teleportTo(fromPosition)
		end
	elseif fromPosition.x == 33387 then
		creature:teleportTo(Position(position.x - 2, position.y, position.z))
	end
	creature:getPosition():sendMagicEffect(CONST_ME_HITBYFIRE)

	return true
end

FireWall:aid(36568)
FireWall:register()
