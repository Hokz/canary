local function createSparksOfDestruction()
	Game.createMonster("Spark Of Destruction", Position(32203, 31246, 14), false, true)
	Game.createMonster("Spark Of Destruction", Position(32205, 31251, 14), false, true)
	Game.createMonster("Spark Of Destruction", Position(32210, 31251, 14), false, true)
	Game.createMonster("Spark Of Destruction", Position(32212, 31246, 14), false, true)
end

local shocksDeath = CreatureEvent("ShocksDeath")

function shocksDeath.onDeath(creature)
	if not creature or not creature:isMonster() then
		return true
	end

	local creatureName = creature:getName():lower()
	if creatureName == "foreshock" then
		local monster = Game.createMonster("Aftershock", Position(32208, 31248, 14), false, true)
		if monster then
			local aftershockHealth = Game.getStorageValue(GlobalStorage.HeartOfDestruction.AftershockHealth) > 0 and Game.getStorageValue(GlobalStorage.HeartOfDestruction.AftershockHealth) or 0
			monster:addHealth(-monster:getHealth() + aftershockHealth, COMBAT_PHYSICALDAMAGE)
			createSparksOfDestruction()
		else
			-- CONFIRMED GAP (found during the HOD repair audit): this handoff is already order-safe
			-- (Foreshock is already dead/removed by the time this runs, so there's no tile-occupancy
			-- risk), but a creation failure previously vanished silently, leaving players with no
			-- Aftershock and no diagnostic trail. Logged only — no automatic retry is safe here since
			-- there's no periodic onThink driving this handoff to retry from (unlike the 5 boss
			-- transforms above).
			logger.error("HeartOfDestruction: ShocksDeath failed to create Aftershock at Foreshock's death position")
		end
	elseif creatureName == "aftershock" then
		local monster = Game.createMonster("Realityquake", creature:getPosition(), false, true)
		if monster then
			createSparksOfDestruction()
		else
			logger.error("HeartOfDestruction: ShocksDeath failed to create Realityquake at Aftershock's death position")
		end
	end
	return true
end

shocksDeath:register()
