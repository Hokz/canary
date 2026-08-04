-- A Pirate's Tail - world-shared pirat raid scheduler. A new raid (random type, random location)
-- starts 30 minutes after the previous one ends; each raid has a 15-minute hard timeout.
-- Location config lives in lib/quests/a_pirates_tail.lua (loaded before this script).

local RAID_CHECK_INTERVAL = 30 * 1000 -- poll every 30 seconds
local RAID_COOLDOWN = 30 * 60 -- 30 minutes between raids, in seconds
local RAID_TIMEOUT = 15 * 60 -- 15-minute hard cap per raid, in seconds
local RAID_WAVE_SIZE = 5

local function configuredLocationIndexes()
	local indexes = {}
	for i, loc in ipairs(APiratesTailRaidLocations) do
		if loc.landSpawn or loc.waterZone or loc.shipCatapult then
			table.insert(indexes, i)
		end
	end
	return indexes
end

local function spawnLandRaid(location)
	if not location.landSpawn then
		return
	end
	for _ = 1, RAID_WAVE_SIZE do
		local name = APiratesTailLandPirats[math.random(1, #APiratesTailLandPirats)]
		Game.createMonster(name, location.landSpawn, true, true)
	end
end

local function spawnWaterRaid(location)
	if not location.waterZone then
		return
	end
	for _ = 1, RAID_WAVE_SIZE do
		local name = APiratesTailWaterPirats[math.random(1, #APiratesTailWaterPirats)]
		Game.createMonster(name, location.waterZone.from, true, true)
	end
end

local function startNewRaid()
	local indexes = configuredLocationIndexes()
	local locationIndex = #indexes > 0 and indexes[math.random(1, #indexes)] or math.random(1, #APiratesTailRaidLocations)
	local raidType = math.random(1, 3)
	local location = APiratesTailRaidLocations[locationIndex]

	Game.setStorageValue(GlobalStorage.APiratesTailRaid.Active, 1)
	Game.setStorageValue(GlobalStorage.APiratesTailRaid.Type, raidType)
	Game.setStorageValue(GlobalStorage.APiratesTailRaid.Location, locationIndex)
	Game.setStorageValue(GlobalStorage.APiratesTailRaid.EndsAt, os.time() + RAID_TIMEOUT)
	Game.setStorageValue(GlobalStorage.APiratesTailRaid.ShipPoints, 0)

	if raidType == 1 then
		spawnLandRaid(location)
		Game.setStorageValue(GlobalStorage.APiratesTailRaid.RemainingMonsters, location.landSpawn and RAID_WAVE_SIZE or 0)
	elseif raidType == 2 then
		spawnWaterRaid(location)
		Game.setStorageValue(GlobalStorage.APiratesTailRaid.RemainingMonsters, location.waterZone and RAID_WAVE_SIZE or 0)
	else
		-- Ship attack has no spawn step - entirely player-driven through the stone/catapult/
		-- lever action chain, see action_raid_catapult.lua
		Game.setStorageValue(GlobalStorage.APiratesTailRaid.RemainingMonsters, 0)
	end
end

local function endCurrentRaid()
	Game.setStorageValue(GlobalStorage.APiratesTailRaid.Active, 0)
	Game.setStorageValue(GlobalStorage.APiratesTailRaid.NextRaidAt, os.time() + RAID_COOLDOWN)
end

local raidStartup = GlobalEvent("APiratesTailRaidStartup")
function raidStartup.onStartup()
	if Game.getStorageValue(GlobalStorage.APiratesTailRaid.Active) ~= 1 then
		Game.setStorageValue(GlobalStorage.APiratesTailRaid.Active, 0)
	end
	if Game.getStorageValue(GlobalStorage.APiratesTailRaid.NextRaidAt) <= 0 then
		Game.setStorageValue(GlobalStorage.APiratesTailRaid.NextRaidAt, os.time() + RAID_COOLDOWN)
	end
	return true
end
raidStartup:register()

local raidScheduler = GlobalEvent("APiratesTailRaidScheduler")
function raidScheduler.onThink(interval)
	local active = Game.getStorageValue(GlobalStorage.APiratesTailRaid.Active)
	if active == 1 then
		local raidType = Game.getStorageValue(GlobalStorage.APiratesTailRaid.Type)
		local timedOut = os.time() >= Game.getStorageValue(GlobalStorage.APiratesTailRaid.EndsAt)
		local waveCleared = (raidType == 1 or raidType == 2) and Game.getStorageValue(GlobalStorage.APiratesTailRaid.RemainingMonsters) <= 0
		local shipCapped = raidType == 3 and Game.getStorageValue(GlobalStorage.APiratesTailRaid.ShipPoints) >= 300
		if timedOut or waveCleared or shipCapped then
			endCurrentRaid()
		end
	else
		if os.time() >= Game.getStorageValue(GlobalStorage.APiratesTailRaid.NextRaidAt) then
			startNewRaid()
		end
	end
	return true
end
raidScheduler:interval(RAID_CHECK_INTERVAL)
raidScheduler:register()
