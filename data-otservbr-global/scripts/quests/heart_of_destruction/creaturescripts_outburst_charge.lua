-- CONFIRMED GAP (found during the HOD repair audit): Charging Outburst's creation result was
-- entirely unchecked (worst-ordering case of the 5 bosses - the original was always removed first,
-- unconditionally). A creation failure left the room with no boss and no path forward. Creating the
-- replacement first (force=true bypasses tile occupancy, same as the other 4 boss transforms) and
-- only removing the original — and only committing OutburstStage — on success means a transient
-- failure just leaves the current form alive; onThink retries automatically next tick.
local function createSpawnChargingOutburst(stage, position)
	local chargingOutburst = Game.createMonster("Charging Outburst", position, false, true)
	if not chargingOutburst then
		return false
	end
	Game.createMonster("Spark of Destruction", Position(32229, 31282, 14), false, true)
	Game.createMonster("Spark of Destruction", Position(32230, 31287, 14), false, true)
	Game.createMonster("Spark of Destruction", Position(32237, 31287, 14), false, true)
	Game.createMonster("Spark of Destruction", Position(32238, 31282, 14), false, true)

	Game.setStorageValue(GlobalStorage.HeartOfDestruction.OutburstStage, stage)
	Game.setStorageValue(GlobalStorage.HeartOfDestruction.OutburstChargingKilled, -1)
	return true
end

local outburstCharge = CreatureEvent("OutburstCharge")

function outburstCharge.onThink(creature)
	if not creature or not creature:isMonster() then
		return false
	end

	local outburstStage = Game.getStorageValue(GlobalStorage.HeartOfDestruction.OutburstStage) > 0 and Game.getStorageValue(GlobalStorage.HeartOfDestruction.OutburstStage) or 0
	Game.setStorageValue(GlobalStorage.HeartOfDestruction.OutburstHealth, creature:getHealth())

	local hpPercent = (creature:getHealth() / creature:getMaxHealth()) * 100
	local position = creature:getPosition()
	if hpPercent <= 80 and outburstStage == 0 then
		if createSpawnChargingOutburst(1, position) then
			creature:remove()
		end
	elseif hpPercent <= 60 and outburstStage == 1 then
		if createSpawnChargingOutburst(2, position) then
			creature:remove()
		end
	elseif hpPercent <= 40 and outburstStage == 2 then
		if createSpawnChargingOutburst(3, position) then
			creature:remove()
		end
	elseif hpPercent <= 20 and outburstStage == 3 then
		if createSpawnChargingOutburst(4, position) then
			creature:remove()
		end
	end
	return true
end

outburstCharge:register()
