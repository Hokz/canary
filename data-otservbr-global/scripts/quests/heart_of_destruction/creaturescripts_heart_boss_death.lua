-- Runs 60 seconds after World Devourer's death: kicks any remaining players to the same
-- exit position used by the sibling Hunger/Destruction/Rage rooms, and removes leftover
-- monsters/summons. Named distinctly (not `clearDevourer`) to avoid the pre-existing global
-- function name collision with actions_final_lever.lua's own `clearDevourer` (used there for
-- the 30-minute failsafe and for clearing stale state before a fresh attempt).
local function finalBattleRoomCleanup()
	local upConer = { x = 32260, y = 31336, z = 14 } -- upLeftCorner
	local downConer = { x = 32283, y = 31360, z = 14 } -- downRightCorner
	local exitPosition = { x = 32208, y = 31372, z = 14 }

	for i = upConer.x, downConer.x do
		for j = upConer.y, downConer.y do
			for k = upConer.z, downConer.z do
				local tile = Tile(i, j, k)
				if tile then
					local creatures = tile:getCreatures()
					if creatures and #creatures > 0 then
						for _, creatureUid in pairs(creatures) do
							local creature = Creature(creatureUid)
							if creature then
								if creature:isPlayer() then
									creature:teleportTo(exitPosition)
									creature:getPosition():sendMagicEffect(CONST_ME_TELEPORT)
								elseif creature:isMonster() then
									creature:remove()
								end
							end
						end
					end
					for _, item in ipairs(tile:getItems() or {}) do
						if not item:hasAttribute("aid") and not item:hasAttribute("uid") then
							local itemType = ItemType(item:getId())
							if itemType:isMagicField() or itemType:isCorpse() or (itemType:isMovable() and itemType:isPickupable()) then
								item:remove()
							end
						end
					end
				end
			end
		end
	end
end

-- CORRECTION (executor contract, section J): "Ender of the End" is granted here, on the actual
-- World Devourer kill, to every legitimate participant still in the room - not in
-- actions_reward.lua on chest delivery. A player who legitimately defeats World Devourer must not
-- lose the achievement just because their inventory couldn't accept the reward backpack afterward.
local function setStorageDevourer()
	local upConer = { x = 32260, y = 31336, z = 14 } -- upLeftCorner
	local downConer = { x = 32283, y = 31360, z = 14 } -- downRightCorner

	for i = upConer.x, downConer.x do
		for j = upConer.y, downConer.y do
			for k = upConer.z, downConer.z do
				local tile = Tile(i, j, k)
				if tile then
					local creatures = tile:getCreatures()
					if creatures and #creatures > 0 then
						for _, creature in pairs(creatures) do
							if creature:isPlayer() then -- éPlayer
								creature:setStorageValue(60835, 1)
								creature:setStorageValue(60814, 1)
								creature:setStorageValue(60828, 1)
								creature:addAchievement("Ender of the End")
							end
						end
					end
				end
			end
		end
	end
end

-- CORRECTION (executor contract, section F): charge attribution moved from killer/mostDamageKiller
-- only to every legitimate player in the boss's room, using the exact same room-participant scope
-- already used for that boss's completion credit (the fromPos/toPos sweep below) - so progression
-- credit and charge recipient can no longer diverge. Capped at 5, one grant per player per death.
-- Also wires section L: once a player holds BOTH Eradicator (14330) and Outburst (14332) storages,
-- Mission 7 becomes visible in the questlog for the first time (RewardClaimed initialized to 0,
-- from its unset -1 - never regressed if already 1 from an earlier World Devourer kill).
local function creditBossRoomParticipants(fromPos, toPos, storage)
	local upConer = fromPos -- upLeftCorner
	local downConer = toPos -- downRightCorner

	for i = upConer.x, downConer.x do
		for j = upConer.y, downConer.y do
			for k = upConer.z, downConer.z do
				local room = { x = i, y = j, z = k }
				local tile = Tile(room)
				if tile then
					local creatures = tile:getCreatures()
					if creatures and #creatures > 0 then
						for _, creature in pairs(creatures) do
							if creature:isPlayer() then
								if creature:getStorageValue(storage) < 1 then
									creature:setStorageValue(storage, 1) -- Access to boss Anomaly
								end

								local charges = math.min(math.max(creature:getStorageValue(Storage.Quest.U10_94.HeartOfDestruction.DestructiveCharges), 0) + 1, 5)
								creature:setStorageValue(Storage.Quest.U10_94.HeartOfDestruction.DestructiveCharges, charges)

								if creature:getStorageValue(14330) >= 1 and creature:getStorageValue(14332) >= 1 and creature:getStorageValue(Storage.HeartOfDestructionFinalBattle.RewardClaimed) == -1 then
									creature:setStorageValue(Storage.HeartOfDestructionFinalBattle.RewardClaimed, 0)
								end
							end
						end
					end
				end
			end
		end
	end
end

local bosses = {
	["anomaly"] = {
		tile = { x = 32261, y = 31250, z = 14 },
		actionId = 14325,
		fromPos = { x = 32258, y = 31237, z = 14 },
		toPos = { x = 32284, y = 31262, z = 14 },
		storage = 14326,
	},
	["rupture"] = {
		tile = { x = 32326, y = 31250, z = 14 },
		actionId = 14325,
		fromPos = { x = 32324, y = 31239, z = 14 },
		toPos = { x = 32347, y = 31263, z = 14 },
		storage = 14327,
	},
	["realityquake"] = {
		tile = { x = 32199, y = 31248, z = 14 },
		actionId = 14325,
		fromPos = { x = 32197, y = 31236, z = 14 },
		toPos = { x = 32220, y = 31260, z = 14 },
		storage = 14328,
	},
	["eradicator"] = {
		tile = { x = 32318, y = 31284, z = 14 },
		actionId = 14325,
		fromPos = { x = 32297, y = 31272, z = 14 },
		toPos = { x = 32321, y = 31296, z = 14 },
		storage = 14330,
	},
	["outburst"] = {
		tile = { x = 32225, y = 31285, z = 14 },
		actionId = 14325,
		fromPos = { x = 32223, y = 31273, z = 14 },
		toPos = { x = 32246, y = 31297, z = 14 },
		storage = 14332,
	},
}

local heartBossDeath = CreatureEvent("HeartBossDeath")

function heartBossDeath.onDeath(creature, corpse, killer, mostDamageKiller, unjustified, mostDamageUnjustified)
	if not creature or not creature:getMonster() then
		return true
	end

	local monsterName = creature:getName():lower()
	local bossName = bosses[monsterName]
	if bossName then
		local vortex = Tile(bossName.tile):getItemById(23483)
		if vortex then
			vortex:transform(23482)
			vortex:setActionId(bossName.actionId)
		end
		creditBossRoomParticipants(bossName.fromPos, bossName.toPos, bossName.storage)
		if monsterName == "eradicator" then
			-- CONFIRMED GAP (found during the HOD repair audit): creaturescripts_eradicator_transform.lua
			-- schedules a recurring release timer (eradicatorEvent) for as long as the fight is
			-- ongoing. Without stopping it here, the timer keeps firing after the boss is already
			-- dead and the room reset, flipping a stale EradicatorReleaseT storage for no live boss.
			stopEvent(eradicatorEvent)
		end
	elseif monsterName == "world devourer" then
		local vortex = Tile({ x = 32281, y = 31348, z = 14 }):getItemById(23483)
		if vortex then
			vortex:transform(23482)
			vortex:setActionId(14354)
		end
		setStorageDevourer()
		-- Stop the failsafe timers immediately (the fight is over), but wait 60 seconds
		-- before kicking players/removing monsters so reward and exit logic has time to run.
		stopEvent(areaDevourer4)
		stopEvent(areaDevourer5)
		stopEvent(areaDevourer6)
		addEvent(finalBattleRoomCleanup, 60 * 1000)
	end
	return true
end

heartBossDeath:register()
