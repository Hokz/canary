local timeGuardianFormFreezing = CreatureEvent("TimeGuardianFormFreezing")

function timeGuardianFormFreezing.onDeath(creature)
	if creature:getName():lower() ~= "the time guardian" then
		return true
	end

	Game.createMonster("The Freezing Time Guardian", creature:getPosition(), true, true)
	return true
end

timeGuardianFormFreezing:register()
