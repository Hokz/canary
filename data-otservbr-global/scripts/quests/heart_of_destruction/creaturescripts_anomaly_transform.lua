-- CONFIRMED BUG (found during the HOD repair audit): this used to remove the live Anomaly BEFORE
-- attempting to create Charged Anomaly, with the creation result never checked. A creation failure
-- (e.g. Monster.createMonster returning nil for any reason) left the room permanently bossless -
-- unrecoverable, since the original was already gone. Game.createMonster's "force" argument (used
-- throughout this quest) bypasses tile-occupancy checks (see Map::placeCreature/placeCreature's
-- forceLogin short-circuit), so creating the replacement on the original's own tile while it's
-- still alive is safe. Creating first and only removing the original on success means a transient
-- failure just leaves the current form alive for this tick; onThink retries automatically next tick.
local function createSpawnAnomalyRoom(valueGlobalStorage, position)
	local chargedAnomaly = Game.createMonster("Charged Anomaly", position, false, true)
	if not chargedAnomaly then
		return false
	end
	Game.createMonster("Spark of Destruction", Position(32267, 31253, 14), false, true)
	Game.createMonster("Spark of Destruction", Position(32274, 31255, 14), false, true)
	Game.createMonster("Spark of Destruction", Position(32274, 31249, 14), false, true)
	Game.createMonster("Spark of Destruction", Position(32267, 31249, 14), false, true)
	Game.setStorageValue(GlobalStorage.HeartOfDestruction.ChargedAnomaly, valueGlobalStorage + 1)
	return true
end

local anomalyTransform = CreatureEvent("AnomalyTransform")

function anomalyTransform.onThink(creature)
	if not creature then
		return false
	end

	local anomalyGlobalStorage = Game.getStorageValue(GlobalStorage.HeartOfDestruction.ChargedAnomaly)
	local hpPercent = (creature:getHealth() / creature:getMaxHealth()) * 100
	local position = creature:getPosition()

	if hpPercent <= 75 and anomalyGlobalStorage == 0 then
		if createSpawnAnomalyRoom(anomalyGlobalStorage, position) then
			creature:remove()
		end
	elseif hpPercent <= 50 and anomalyGlobalStorage == 1 then
		if createSpawnAnomalyRoom(anomalyGlobalStorage, position) then
			creature:remove()
		end
	elseif hpPercent <= 25 and anomalyGlobalStorage == 2 then
		if createSpawnAnomalyRoom(anomalyGlobalStorage, position) then
			creature:remove()
		end
	elseif hpPercent <= 5 and anomalyGlobalStorage == 3 then
		if createSpawnAnomalyRoom(anomalyGlobalStorage, position) then
			creature:remove()
		end
	end
	return true
end

anomalyTransform:register()
