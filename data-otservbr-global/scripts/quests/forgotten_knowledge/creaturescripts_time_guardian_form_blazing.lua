local timeGuardianFormBlazing = CreatureEvent("TimeGuardianFormBlazing")

function timeGuardianFormBlazing.onDeath(creature)
	if creature:getName():lower() ~= "the freezing time guardian" then
		return true
	end

	Game.createMonster("The Blazing Time Guardian", creature:getPosition(), true, true)
	return true
end

timeGuardianFormBlazing:register()
