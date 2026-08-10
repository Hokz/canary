-- CORRECTION (executor contract, section E): the previous 60-second delayed cleanup scheduled a
-- bare addEvent with no run token and outside HODFinalRun.events - a full, generation-blind sweep
-- of the room by POSITION. If a new run had already started in the 60-second window (unlikely
-- given normal play, but not impossible), this would have removed that NEWER run's own players
-- and monsters. This replacement operates ONLY on a snapshot of the completed run's own
-- participant ids and owned monster ids, captured by the caller BEFORE HODFinalRunTerminate clears
-- HODFinalRun's collections - it is intentionally independent of any mutable current-run state, so
-- it can never touch anything belonging to a run that starts later. Corpses/dropped items are
-- still swept by room position, since an item can never be mistaken for a newer run's own player
-- or monster the way a creature could.
local function finalRunSuccessCleanup(participantIds, ownedMonsterIds)
	local exitPosition = { x = 32208, y = 31372, z = 14 }

	for _, playerId in ipairs(participantIds) do
		local participant = Player(playerId)
		if participant then
			participant:teleportTo(exitPosition)
			participant:getPosition():sendMagicEffect(CONST_ME_TELEPORT)
		end
	end

	for _, monsterId in ipairs(ownedMonsterIds) do
		local monster = Monster(monsterId)
		if monster then
			monster:remove()
		end
	end

	local upConer = { x = 32260, y = 31336, z = 14 } -- upLeftCorner
	local downConer = { x = 32283, y = 31360, z = 14 } -- downRightCorner
	for i = upConer.x, downConer.x do
		for j = upConer.y, downConer.y do
			for k = upConer.z, downConer.z do
				local tile = Tile(i, j, k)
				if tile then
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
		-- CORRECTION (executor contract, section D): World Devourer success is only accepted if
		-- this exact creature belongs to the currently active final run. A stale/unowned World
		-- Devourer (e.g. a leftover from an already-terminated run that somehow still exists) must
		-- not transform the vortex, grant completion, or terminate whatever run IS currently
		-- active - it isn't that run's boss.
		if not HODFinalRunOwnsMonster(creature) then
			return true
		end

		local token = HODFinalRun.token
		local participantIds = {}
		for playerId in pairs(HODFinalRun.participants) do
			participantIds[#participantIds + 1] = playerId
		end
		local ownedMonsterIds = {}
		for monsterId in pairs(HODFinalRun.monsters) do
			ownedMonsterIds[#ownedMonsterIds + 1] = monsterId
		end

		local vortex = Tile({ x = 32281, y = 31348, z = 14 }):getItemById(23483)
		if vortex then
			vortex:transform(23482)
			vortex:setActionId(14354)
		end

		-- Completion storages and "Ender of the End" go only to this exact run's own legitimate
		-- participants (HODFinalRun.participants, the authoritative roster of players still
		-- committed to this run) - not to bystanders who happen to occupy the room.
		for _, playerId in ipairs(participantIds) do
			local participant = Player(playerId)
			if participant then
				participant:setStorageValue(60835, 1)
				participant:setStorageValue(60814, 1)
				participant:setStorageValue(60828, 1)
				participant:addAchievement("Ender of the End")
			end
		end

		-- SUCCESS lifecycle: stops every event this run owns, releases team storages/
		-- DevourerStorage, but (unlike abort/timeout) does NOT refund charges, does NOT roll back
		-- the cooldown, and does NOT immediately teleport participants out - the existing
		-- reward/exit flow gets a short window first, via the snapshot-based cleanup below.
		HODFinalRunTerminate(token, "success", "World Devourer defeated")

		addEvent(finalRunSuccessCleanup, 60 * 1000, participantIds, ownedMonsterIds)
	end
	return true
end

heartBossDeath:register()
