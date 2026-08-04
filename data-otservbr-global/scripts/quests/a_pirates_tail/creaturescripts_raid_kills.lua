-- A Pirate's Tail - land/water raid kill tracking. 3 points per land-raid pirat, 5 points per
-- water-raid pirat. A kill only counts if a matching raid is currently active AND the kill
-- happened within APiratesTailRaidKillRadius tiles of that raid's configured zone position -
-- these monster types also spawn normally in several cities, so an unscoped kill (a wild pirat
-- killed while some unrelated raid happens to be active elsewhere) must not be credited.
local raidKill = CreatureEvent("APiratesTailRaidKill")

local landNames = {}
for _, name in ipairs(APiratesTailLandPirats) do
	landNames[name:lower()] = true
end
local waterNames = {}
for _, name in ipairs(APiratesTailWaterPirats) do
	waterNames[name:lower()] = true
end

function raidKill.onDeath(creature, corpse, lasthitkiller, mostdamagekiller)
	local active = Game.getStorageValue(GlobalStorage.APiratesTailRaid.Active)
	if active ~= 1 then
		return true
	end
	local raidType = Game.getStorageValue(GlobalStorage.APiratesTailRaid.Type)
	if raidType ~= 1 and raidType ~= 2 then
		return true
	end

	local monsterName = creature:getName():lower()
	local matchesType = (raidType == 1 and landNames[monsterName]) or (raidType == 2 and waterNames[monsterName])
	if not matchesType then
		return true
	end

	local location = getAPiratesTailActiveLocation()
	local zonePosition = raidType == 1 and location.landSpawn or (location.waterZone and location.waterZone.from)
	if not zonePosition or not creature:getPosition():isInRange(zonePosition, APiratesTailRaidKillRadius, APiratesTailRaidKillRadius) then
		return true
	end

	local points = raidType == 1 and 3 or 5
	onDeathForDamagingPlayers(creature, function(_creature, player)
		local total = math.max(player:getStorageValue(Storage.Quest.U12_60.APiratesTail.Mission01.RaidPoints), 0)
		player:setStorageValue(Storage.Quest.U12_60.APiratesTail.Mission01.RaidPoints, total + points)
	end)

	local remaining = math.max(Game.getStorageValue(GlobalStorage.APiratesTailRaid.RemainingMonsters) - 1, 0)
	Game.setStorageValue(GlobalStorage.APiratesTailRaid.RemainingMonsters, remaining)
	return true
end

raidKill:register()
