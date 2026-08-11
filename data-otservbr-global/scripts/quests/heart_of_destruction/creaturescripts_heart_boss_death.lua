local WD_ROOM_FROM = { x = 32260, y = 31336, z = 14 }
local WD_ROOM_TO = { x = 32283, y = 31360, z = 14 }
local WD_EXIT = { x = 32208, y = 31372, z = 14 }

local function isInsideWorldDevourerRoom(creature)
	local pos = creature:getPosition()
	return pos.x >= WD_ROOM_FROM.x and pos.x <= WD_ROOM_TO.x and pos.y >= WD_ROOM_FROM.y and pos.y <= WD_ROOM_TO.y and pos.z >= WD_ROOM_FROM.z and pos.z <= WD_ROOM_TO.z
end

-- CORRECTION (micro-correction, section C): the 60-second delayed cleanup operates on a snapshot
-- of the run that just succeeded, captured by the caller BEFORE HODFinalRunTerminate clears
-- HODFinalRun's collections. That snapshot alone isn't enough to guarantee this cleanup can never
-- touch a later run's own state, so every action below is additionally conditioned on present-tense
-- facts checked at the moment this callback actually fires, 60 seconds later:
--   PLAYER  - only teleports a snapshotted participant who is STILL physically inside the room;
--             someone who already left through the legitimate exit/reward flow is left alone,
--             never yanked back from wherever they went.
--   MONSTER - removes a snapshotted monster id UNLESS that exact id has since been reclaimed by a
--             currently-active newer run (defensive against creature-id reuse across runs).
--   ROOM SWEEP - a positional fallback for anything neither snapshot could have known about (e.g.
--             a Disruption that transformed into a Charged Disruption after this run's own token
--             was already invalidated, and so was never registered as anyone's owned monster at
--             all) - but ONLY runs when no newer HOD run is active. If a newer run IS active, its
--             own pre-run hygiene sweep already cleared this room before it committed, and a
--             positional sweep here could otherwise remove that newer run's own players/monsters.
local function finalRunSuccessCleanup(participantIds, ownedMonsterIds)
	for _, playerId in ipairs(participantIds) do
		local participant = Player(playerId)
		if participant and isInsideWorldDevourerRoom(participant) then
			participant:teleportTo(WD_EXIT)
			participant:getPosition():sendMagicEffect(CONST_ME_TELEPORT)
		end
	end

	for _, monsterId in ipairs(ownedMonsterIds) do
		if not (HODFinalRun.active and HODFinalRun.monsters[monsterId]) then
			local monster = Monster(monsterId)
			if monster then
				monster:remove()
			end
		end
	end

	if not HODFinalRun.active then
		for i = WD_ROOM_FROM.x, WD_ROOM_TO.x do
			for j = WD_ROOM_FROM.y, WD_ROOM_TO.y do
				for k = WD_ROOM_FROM.z, WD_ROOM_TO.z do
					local tile = Tile(i, j, k)
					if tile then
						local creatures = tile:getCreatures()
						if creatures and #creatures > 0 then
							for _, creatureUid in pairs(creatures) do
								local creature = Creature(creatureUid)
								if creature and creature:isMonster() then
									creature:remove()
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

		-- CORRECTION (micro-correction, section B): completion storages and "Ender of the End" go
		-- only to players who are BOTH a member of HODFinalRun.participants (the authoritative
		-- roster - a bystander in the room who isn't on this roster still receives nothing) AND
		-- still physically inside the World Devourer room at the moment it actually dies. A run
		-- participant who already died, left, or teleported out earlier does not get credit for a
		-- kill they weren't present for.
		for _, playerId in ipairs(participantIds) do
			local participant = Player(playerId)
			if participant and isInsideWorldDevourerRoom(participant) then
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
