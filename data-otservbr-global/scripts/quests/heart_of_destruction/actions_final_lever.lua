--[[
Storages (centrally registered as Storage.HeartOfDestructionFinalBattle):
The Hunger = 14334 (HungerTeam)
The Destruction = 14335 (DestructionTeam)
The Rage = 14336 (RageTeam)
]]
--

-- ===== RUN OWNERSHIP (executor contract, section C) =====
-- A single shared runtime table making every final-battle timer/monster provably belong to the
-- CURRENT attempt. Only one final run may be active at a time. Every addEvent callback the final
-- encounter schedules captures the run's token and re-checks HODFinalRunIsCurrent before doing
-- anything; a callback whose token no longer matches the active run is a silent no-op. This is the
-- same run-token shape already proven in the_new_frontier/action_arena.lua, adapted for a
-- multi-phase, multi-room encounter (this one owns events AND temporary monsters, not just a lock).
HODFinalRun = HODFinalRun or {
	token = 0,
	active = false,
	participants = {}, -- set: playerId -> true
	events = {}, -- set: eventId -> true
	monsters = {}, -- set: creatureId -> true
	pendingRespawns = {}, -- set: monster name -> true, guards against duplicate concurrent respawn attempts
}

function HODFinalRunIsCurrent(token)
	return token ~= nil and token > 0 and HODFinalRun.active and HODFinalRun.token == token
end

-- Used by creaturescripts_heart_minion_death.lua so a stale Hunger/Destruction/Rage instance from
-- an aborted or already-finished run can't mutate a newer run's counters.
function HODFinalRunOwnsMonster(monster)
	if not monster then
		return false
	end
	return HODFinalRun.monsters[monster:getId()] == true
end

local function trackEvent(token, eventId)
	if HODFinalRunIsCurrent(token) and eventId then
		HODFinalRun.events[eventId] = true
	end
end

local function trackMonster(token, monster)
	if HODFinalRunIsCurrent(token) and monster then
		HODFinalRun.monsters[monster:getId()] = true
	end
end

-- Forward declarations - these are mutually referential (changeArea's respawn helper can abort
-- the run, abortRun uses the room-sweep helpers, spawnWorldDevourer can also abort the run).
local clearHunger, clearDestruction, clearRage, clearDevourer, changeArea, spawnWorldDevourer, sparkDevourerSpawn, abortRun, attemptMinibossRespawn

-- All cleanup/abort paths (success, abort, timeout, internal spawn failure) funnel through here:
-- invalidates the token first, stops every owned event, clears this run's participants' team
-- storages, removes only this run's own temporary monsters, and releases this run's own
-- participants - leaving the next run clean. Never touches a different run's state.
abortRun = function(token, reason)
	if not HODFinalRunIsCurrent(token) then
		return
	end
	logger.error("HeartOfDestruction: final battle run {} aborted - {}", token, reason)

	-- Invalidate first (contract-mandated order) so any callback racing in after this point and
	-- re-checking HODFinalRunIsCurrent sees the run as already gone.
	HODFinalRun.active = false

	for eventId in pairs(HODFinalRun.events) do
		stopEvent(eventId)
	end

	for _, online in ipairs(Game.getPlayers()) do
		if online:isPlayer() and HODFinalRun.participants[online:getId()] then
			online:setStorageValue(Storage.HeartOfDestructionFinalBattle.HungerTeam, -1)
			online:setStorageValue(Storage.HeartOfDestructionFinalBattle.DestructionTeam, -1)
			online:setStorageValue(Storage.HeartOfDestructionFinalBattle.RageTeam, -1)
			online:unregisterEvent("DevourerStorage")
			online:teleportTo({ x = 32208, y = 31372, z = 14 })
			online:getPosition():sendMagicEffect(CONST_ME_TELEPORT)
			online:sendTextMessage(MESSAGE_EVENT_ADVANCE, "The heart of destruction's power falters and releases you - the attempt has failed. You may try again.")
		end
	end

	for monsterId in pairs(HODFinalRun.monsters) do
		local monster = Monster(monsterId)
		if monster then
			monster:remove()
		end
	end

	HODFinalRun.participants = {}
	HODFinalRun.events = {}
	HODFinalRun.monsters = {}
	HODFinalRun.pendingRespawns = {}
end

-- ===== FUNCTIONS =====

-- CORRECTION (executor contract, section E): World Devourer's creation is bounded-retried and
-- run-owned. By the point this runs, all 15 players have already been rotated into the World
-- Devourer room and the 30-second rotation timer has already been stopped - a silent creation
-- failure here would leave a full room of committed players with no boss. If every retry fails,
-- the run is aborted immediately (release players/room) rather than leaving them to wait out the
-- unrelated 30-minute failsafe, which is a backstop for abandonment, not a response to a failed
-- mandatory spawn.
spawnWorldDevourer = function(token, retriesLeft)
	if not HODFinalRunIsCurrent(token) then
		return
	end
	local monster = Game.createMonster("World Devourer", { x = 32271, y = 31347, z = 14 }, false, true)
	if monster then
		trackMonster(token, monster)
		return
	end
	logger.error("HeartOfDestruction: failed to create World Devourer (retries left: {})", retriesLeft)
	if retriesLeft > 0 then
		trackEvent(token, addEvent(spawnWorldDevourer, 5000, token, retriesLeft - 1))
	else
		abortRun(token, "World Devourer failed to spawn after bounded retries")
	end
end

sparkDevourerSpawn = function(token)
	if not HODFinalRunIsCurrent(token) then
		return
	end
	local positions = {
		{ x = 32268, y = 31341, z = 14 },
		{ x = 32275, y = 31342, z = 14 },
		{ x = 32269, y = 31352, z = 14 },
		{ x = 32277, y = 31351, z = 14 },
	}

	if sparkSpawnCount > 0 then
		for i = 1, sparkSpawnCount do
			trackMonster(token, Game.createMonster("Spark of Destruction2", positions[i], false, true))
		end
		sparkSpawnCount = 0
	end
	areaDevourer6 = addEvent(sparkDevourerSpawn, 10000, token)
	trackEvent(token, areaDevourer6)
end

local function doCheckArea()
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
							local player = Player(creature)
							if player then
								return true
							end
						end
					end
				end
			end
		end
	end

	for _, online in ipairs(Game.getPlayers()) do
		if online:isPlayer() then
			if online:getStorageValue(Storage.HeartOfDestructionFinalBattle.HungerTeam) >= 1 or online:getStorageValue(Storage.HeartOfDestructionFinalBattle.DestructionTeam) >= 1 or online:getStorageValue(Storage.HeartOfDestructionFinalBattle.RageTeam) >= 1 then
				return true
			end
		end
	end

	return false
end

-- CORRECTION (executor contract, section D): a mandatory miniboss respawn used to decrement
-- devourerBossesKilled and flip theXKilled=false unconditionally, before ever checking whether
-- Game.createMonster actually succeeded. Now: attempt create, and only on success register the
-- monster to the run and update the counter/flag. On failure, bounded retry (3 attempts, 3s
-- apart); if retries are exhausted, cleanly abort the whole run rather than let the encounter
-- continue with that room permanently bossless. `pendingRespawns` prevents a second occupied tile
-- in the same room-sweep tick (or a later tick, while a retry is still in flight) from triggering
-- a duplicate concurrent respawn attempt for the same boss.
attemptMinibossRespawn = function(token, name, position, setKilled, retriesLeft)
	retriesLeft = retriesLeft or 3
	if not HODFinalRunIsCurrent(token) then
		return
	end
	local monster = Game.createMonster(name, position, false, true)
	if monster then
		trackMonster(token, monster)
		devourerBossesKilled = devourerBossesKilled - 1
		setKilled(false)
		HODFinalRun.pendingRespawns[name] = nil
		return
	end
	logger.error("HeartOfDestruction: failed to respawn {} (retries left: {})", name, retriesLeft)
	if retriesLeft > 0 then
		trackEvent(token, addEvent(attemptMinibossRespawn, 3000, token, name, position, setKilled, retriesLeft - 1))
	else
		HODFinalRun.pendingRespawns[name] = nil
		abortRun(token, "mandatory miniboss respawn (" .. name .. ") failed after bounded retries")
	end
end

changeArea = function(token)
	if not HODFinalRunIsCurrent(token) then
		return
	end

	local function organizeHunger()
		local upConer = { x = 32233, y = 31360, z = 14 } -- upLeftCorner
		local downConer = { x = 32256, y = 31384, z = 14 } -- downRightCorner
		for i = upConer.x, downConer.x do
			for j = upConer.y, downConer.y do
				for k = upConer.z, downConer.z do
					local tile = Tile(i, j, k)
					if tile then
						local creatures = tile:getCreatures()
						if creatures and #creatures > 0 then
							if theHungerKilled == false then
								for _, creature in pairs(creatures) do
									local monster = Monster(creature)
									if monster then
										monster:teleportTo({ x = 32244, y = 31369, z = 14 })
									end
								end
							elseif not HODFinalRun.pendingRespawns["The Hunger"] then
								HODFinalRun.pendingRespawns["The Hunger"] = true
								attemptMinibossRespawn(token, "The Hunger", { x = 32244, y = 31372, z = 14 }, function(v)
									theHungerKilled = v
								end)
							end
						end
					end
				end
			end
		end
	end

	local function organizeDestruction()
		local upConer = { x = 32260, y = 31304, z = 14 } -- upLeftCorner
		local downConer = { x = 32283, y = 31328, z = 14 } -- downRightCorner
		for i = upConer.x, downConer.x do
			for j = upConer.y, downConer.y do
				for k = upConer.z, downConer.z do
					local tile = Tile(i, j, k)
					if tile then
						local creatures = tile:getCreatures()
						if creatures and #creatures > 0 then
							if theDestructionKilled == false then
								for _, creature in pairs(creatures) do
									local monster = Monster(creature)
									if monster then
										monster:teleportTo({ x = 32271, y = 31313, z = 14 })
									end
								end
							elseif not HODFinalRun.pendingRespawns["The Destruction"] then
								HODFinalRun.pendingRespawns["The Destruction"] = true
								attemptMinibossRespawn(token, "The Destruction", { x = 32271, y = 31316, z = 14 }, function(v)
									theDestructionKilled = v
								end)
							end
						end
					end
				end
			end
		end
	end

	local function organizeRage()
		local upConer = { x = 32288, y = 31360, z = 14 } -- upLeftCorner
		local downConer = { x = 32311, y = 31384, z = 14 } -- downRightCorner
		for i = upConer.x, downConer.x do
			for j = upConer.y, downConer.y do
				for k = upConer.z, downConer.z do
					local tile = Tile(i, j, k)
					if tile then
						local creatures = tile:getCreatures()
						if creatures and #creatures > 0 then
							if theRageKilled == false then
								for _, creature in pairs(creatures) do
									local monster = Monster(creature)
									if monster then
										monster:teleportTo({ x = 32299, y = 31369, z = 14 })
									end
								end
							elseif not HODFinalRun.pendingRespawns["The Rage"] then
								HODFinalRun.pendingRespawns["The Rage"] = true
								attemptMinibossRespawn(token, "The Rage", { x = 32299, y = 31372, z = 14 }, function(v)
									theRageKilled = v
								end)
							end
						end
					end
				end
			end
		end
	end

	if devourerBossesKilled < 3 then
		for _, online in ipairs(Game.getPlayers()) do
			if online:isPlayer() then
				-- Teleport players from The Hunger to The Rage
				if online:getStorageValue(Storage.HeartOfDestructionFinalBattle.HungerTeam) >= 1 then
					online:setStorageValue(Storage.HeartOfDestructionFinalBattle.HungerTeam, -1)
					online:setStorageValue(Storage.HeartOfDestructionFinalBattle.RageTeam, 1)
					online:teleportTo({ x = 32299, y = 31372, z = 14 })
					online:say("A polarity shift moves you into another part of the heart of destruction.", TALKTYPE_MONSTER_SAY)
					Position({ x = 32299, y = 31372, z = 14 }):sendMagicEffect(11)
					-- Teleport players from The Destruction to The Hunger
				elseif online:getStorageValue(Storage.HeartOfDestructionFinalBattle.DestructionTeam) >= 1 then
					online:setStorageValue(Storage.HeartOfDestructionFinalBattle.DestructionTeam, -1)
					online:setStorageValue(Storage.HeartOfDestructionFinalBattle.HungerTeam, 1)
					online:teleportTo({ x = 32244, y = 31372, z = 14 })
					online:say("A polarity shift moves you into another part of the heart of destruction.", TALKTYPE_MONSTER_SAY)
					Position({ x = 32244, y = 31372, z = 14 }):sendMagicEffect(11)
					-- Teleport players from The Rage to The Destruction
				elseif online:getStorageValue(Storage.HeartOfDestructionFinalBattle.RageTeam) >= 1 then
					online:setStorageValue(Storage.HeartOfDestructionFinalBattle.RageTeam, -1)
					online:setStorageValue(Storage.HeartOfDestructionFinalBattle.DestructionTeam, 1)
					online:teleportTo({ x = 32271, y = 31316, z = 14 })
					online:say("A polarity shift moves you into another part of the heart of destruction.", TALKTYPE_MONSTER_SAY)
					Position({ x = 32271, y = 31316, z = 14 }):sendMagicEffect(11)
				end
			end
		end
		organizeHunger()
		organizeDestruction()
		organizeRage()
		areaDevourer4 = addEvent(changeArea, 30000, token)
		trackEvent(token, areaDevourer4)
	else
		stopEvent(areaDevourer1)
		stopEvent(areaDevourer2)
		stopEvent(areaDevourer3)
		stopEvent(areaDevourer4)
		for _, online in ipairs(Game.getPlayers()) do
			if online:isPlayer() then
				if online:getStorageValue(Storage.HeartOfDestructionFinalBattle.HungerTeam) >= 1 then
					online:setStorageValue(Storage.HeartOfDestructionFinalBattle.HungerTeam, -1)
					online:unregisterEvent("DevourerStorage")
					online:teleportTo({ x = 32271, y = 31357, z = 14 })
					Position({ x = 32271, y = 31357, z = 14 }):sendMagicEffect(11)
				elseif online:getStorageValue(Storage.HeartOfDestructionFinalBattle.DestructionTeam) >= 1 then
					online:setStorageValue(Storage.HeartOfDestructionFinalBattle.DestructionTeam, -1)
					online:unregisterEvent("DevourerStorage")
					online:teleportTo({ x = 32272, y = 31357, z = 14 })
					Position({ x = 32272, y = 31357, z = 14 }):sendMagicEffect(11)
				elseif online:getStorageValue(Storage.HeartOfDestructionFinalBattle.RageTeam) >= 1 then
					online:setStorageValue(Storage.HeartOfDestructionFinalBattle.RageTeam, -1)
					online:unregisterEvent("DevourerStorage")
					online:teleportTo({ x = 32273, y = 31357, z = 14 })
					Position({ x = 32273, y = 31357, z = 14 }):sendMagicEffect(11)
				end
			end
		end
		local spectators = Game.getSpectators(Position(32271, 31348, 14), false, true, 10, 10, 10, 10)
		if #spectators > 0 then
			for i = 1, #spectators do
				spectators[i]:say("With the Rage, Hunger and Destruction gone, you're sucked into the heart of destruction!! THE WORLD DEVOURER AWAITS YOU!", TALKTYPE_MONSTER_YELL, false, spectators[i], Position(32271, 31348, 14))
			end
		end

		spawnWorldDevourer(token, 3)

		-- CONFIRMED GAP (executor contract, section E): these 4 initial Spark of Destruction2 were
		-- unchecked. Not treated as abort-worthy (World Devourer itself, checked above, is the
		-- mandatory encounter-defining spawn; these are supplementary hazards, matching the
		-- non-mandatory "Spark of Destruction" adds used by the other 5 boss rooms) - checked and
		-- logged only, so a failure is visible rather than silently committing an incomplete phase.
		local sparkPositions = {
			{ x = 32268, y = 31341, z = 14 },
			{ x = 32275, y = 31342, z = 14 },
			{ x = 32269, y = 31352, z = 14 },
			{ x = 32277, y = 31351, z = 14 },
		}
		for i = 1, #sparkPositions do
			local spark = Game.createMonster("Spark of Destruction2", sparkPositions[i], false, true)
			if spark then
				trackMonster(token, spark)
			else
				logger.error("HeartOfDestruction: failed to create initial Spark of Destruction2 #{}", i)
			end
		end

		sparkSpawnCount = 0
		devourerSummon = 0
		areaDevourer5 = addEvent(clearDevourer, 30 * 60000, token)
		trackEvent(token, areaDevourer5)
		areaDevourer6 = addEvent(sparkDevourerSpawn, 10000, token)
		trackEvent(token, areaDevourer6)
	end
end

-- The 4 room-sweep functions below double as both run-owned SCHEDULED callbacks (token supplied,
-- checked against HODFinalRunIsCurrent) and unconditional PRE-RUN hygiene sweeps (token omitted,
-- used once at lever-pull time to physically clear any leftover players/monsters before a fresh
-- attempt is even started - there is no run yet at that point, so there's nothing to check
-- ownership against).
clearHunger = function(token)
	if token ~= nil and not HODFinalRunIsCurrent(token) then
		return
	end
	local upConer = { x = 32233, y = 31360, z = 14 } -- upLeftCorner
	local downConer = { x = 32256, y = 31384, z = 14 } -- downRightCorner

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
									creature:teleportTo({ x = 32208, y = 31372, z = 14 })
								elseif creature:isMonster() and creature:getName() ~= "Spark of Destruction" then
									creature:remove()
								end
							end
						end
					end
				end
			end
		end
	end
	stopEvent(areaDevourer1)
end

clearDestruction = function(token)
	if token ~= nil and not HODFinalRunIsCurrent(token) then
		return
	end
	local upConer = { x = 32260, y = 31304, z = 14 } -- upLeftCorner
	local downConer = { x = 32283, y = 31328, z = 14 } -- downRightCorner

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
									creature:teleportTo({ x = 32208, y = 31372, z = 14 })
								elseif creature:isMonster() and creature:getName() ~= "Spark of Destruction" then
									creature:remove()
								end
							end
						end
					end
				end
			end
		end
	end
	stopEvent(areaDevourer2)
end

clearRage = function(token)
	if token ~= nil and not HODFinalRunIsCurrent(token) then
		return
	end
	local upConer = { x = 32288, y = 31360, z = 14 } -- upLeftCorner
	local downConer = { x = 32311, y = 31384, z = 14 } -- downRightCorner

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
									creature:teleportTo({ x = 32208, y = 31372, z = 14 })
								elseif creature:isMonster() and creature:getName() ~= "Spark of Destruction" then
									creature:remove()
								end
							end
						end
					end
				end
			end
		end
	end
	stopEvent(areaDevourer3)
end

clearDevourer = function(token)
	if token ~= nil and not HODFinalRunIsCurrent(token) then
		return
	end
	local upConer = { x = 32260, y = 31336, z = 14 } -- upLeftCorner
	local downConer = { x = 32283, y = 31360, z = 14 } -- downRightCorner

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
									creature:teleportTo({ x = 32208, y = 31372, z = 14 })
								elseif creature:isMonster() then
									creature:remove()
								end
							end
						end
					end
				end
			end
		end
	end
	stopEvent(areaDevourer4)
	stopEvent(areaDevourer5)
	stopEvent(areaDevourer6)
end

-- FUNCTIONS END

local heartDestructionFinal = Action()
function heartDestructionFinal.onUse(player, item, fromPosition, itemEx, toPosition)
	local config = {
		hungerPositions = {
			Position(32271, 31374, 14),
			Position(32271, 31375, 14),
			Position(32271, 31376, 14),
			Position(32271, 31377, 14),
			Position(32271, 31378, 14),
		},

		destructionPositions = {
			Position(32272, 31374, 14),
			Position(32272, 31375, 14),
			Position(32272, 31376, 14),
			Position(32272, 31377, 14),
			Position(32272, 31378, 14),
		},

		ragePositions = {
			Position(32273, 31374, 14),
			Position(32273, 31375, 14),
			Position(32273, 31376, 14),
			Position(32273, 31377, 14),
			Position(32273, 31378, 14),
		},

		hungerNewPos = { x = 32244, y = 31381, z = 14 },
		destructionNewPos = { x = 32271, y = 31325, z = 14 },
		rageNewPos = { x = 32299, y = 31381, z = 14 },
	}

	local pushPos = { x = 32272, y = 31374, z = 14 }

	if item.actionid == 14332 then
		if item.itemid == 8911 then
			if player:getPosition().x == pushPos.x and player:getPosition().y == pushPos.y and player:getPosition().z == pushPos.z then
				local storeHunger, hungerTile = {}
				local storeDestruction, destructionTile = {}
				local storeRage, rageTile = {}

				for i = 1, #config.hungerPositions do
					hungerTile = Tile(config.hungerPositions[i]):getTopCreature()
					if hungerTile and hungerTile:isPlayer() then
						storeHunger[#storeHunger + 1] = hungerTile
					end
				end

				for i = 1, #config.destructionPositions do
					destructionTile = Tile(config.destructionPositions[i]):getTopCreature()
					if destructionTile and destructionTile:isPlayer() then
						storeDestruction[#storeDestruction + 1] = destructionTile
					end
				end

				for i = 1, #config.ragePositions do
					rageTile = Tile(config.ragePositions[i]):getTopCreature()
					if rageTile and rageTile:isPlayer() then
						storeRage[#storeRage + 1] = rageTile
					end
				end

				if #storeHunger < 1 or #storeDestruction < 1 or #storeRage < 1 then
					player:sendTextMessage(19, "You need at least 3 players, each in a column.")
					return true
				end

				-- CORRECTION (executor contract, section A.2): the lever independently revalidates
				-- EVERY participant - access gates, level, Premium, final boss cooldown, and charges -
				-- rather than trusting that reaching this room already proves eligibility (a
				-- participant could have arrived by any means other than the green portal's own
				-- checks). No side effects run before this passes for every single participant.
				for _, columnPlayers in ipairs({ storeHunger, storeDestruction, storeRage }) do
					for _, participant in ipairs(columnPlayers) do
						if participant:getLevel() < 150 then
							player:sendTextMessage(19, "All participants must be at least level 150.")
							return true
						end
						if not participant:isPremium() then
							player:sendTextMessage(19, "All participants must have a premium account.")
							return true
						end
						if participant:getStorageValue(14330) < 1 or participant:getStorageValue(14332) < 1 then
							player:sendTextMessage(19, "All participants must have defeated the Eradicator and the Outburst.")
							return true
						end
						if not participant:canFightBoss("World Devourer") then
							player:sendTextMessage(19, "One of the participants must wait before facing the World Devourer again.")
							return true
						end
						if math.max(participant:getStorageValue(Storage.Quest.U10_94.HeartOfDestruction.DestructiveCharges), 0) < 5 then
							player:sendTextMessage(19, "All participants need 5 destructive charges to enter.")
							return true
						end
					end
				end

				if doCheckArea() == false then
					clearHunger()
					clearDestruction()
					clearRage()
					clearDevourer()

					-- CORRECTION (executor contract, sections A.3-A.6 and B): create and verify the
					-- ONLY copy of the mandatory trio here, before any player is moved or any state
					-- committed - the previous duplicate/unverified second creation block further
					-- below has been removed. A creation failure aborts cleanly: only the bosses this
					-- attempt created are removed, nobody is teleported/committed, no charge is
					-- deducted, no cooldown is set, and the room is left retryable.
					local theHunger = Game.createMonster("The Hunger", { x = 32244, y = 31372, z = 14 }, false, true)
					local theDestruction = Game.createMonster("The Destruction", { x = 32271, y = 31316, z = 14 }, false, true)
					local theRage = Game.createMonster("The Rage", { x = 32299, y = 31372, z = 14 }, false, true)
					if not theHunger or not theDestruction or not theRage then
						if theHunger then
							theHunger:remove()
						end
						if theDestruction then
							theDestruction:remove()
						end
						if theRage then
							theRage:remove()
						end
						logger.error("HeartOfDestruction: failed to create initial Hunger/Destruction/Rage trio")
						player:sendTextMessage(19, "The heart of destruction resists your assault. Try again.")
						return true
					end

					-- COMMIT POINT: the complete encounter has passed validation and all 3 mandatory
					-- bosses exist. Only now: start the run, deduct 5 charges from every participant,
					-- set the final cooldown, assign teams, and teleport.
					local participantIds = {}
					for _, columnPlayers in ipairs({ storeHunger, storeDestruction, storeRage }) do
						for _, participant in ipairs(columnPlayers) do
							participantIds[#participantIds + 1] = participant:getId()
						end
					end

					HODFinalRun.token = HODFinalRun.token + 1
					local token = HODFinalRun.token
					HODFinalRun.active = true
					HODFinalRun.participants = {}
					for _, id in ipairs(participantIds) do
						HODFinalRun.participants[id] = true
					end
					HODFinalRun.events = {}
					HODFinalRun.monsters = {}
					HODFinalRun.pendingRespawns = {}

					trackMonster(token, theHunger)
					trackMonster(token, theDestruction)
					trackMonster(token, theRage)

					local teamHunger
					local teamDestruction
					local teamRage

					for i = 1, #storeHunger do
						teamHunger = storeHunger[i]
						config.hungerPositions[i]:sendMagicEffect(CONST_ME_POFF)
						teamHunger:teleportTo(config.hungerNewPos)
						teamHunger:setBossCooldown("World Devourer", os.time() + 13 * 24 * 60 * 60 + 20 * 60 * 60)
						teamHunger:setStorageValue(Storage.HeartOfDestructionFinalBattle.HungerTeam, 1) --storage Hunger
						teamHunger:registerEvent("DevourerStorage")
						teamHunger:setStorageValue(Storage.Quest.U10_94.HeartOfDestruction.DestructiveCharges, math.max(teamHunger:getStorageValue(Storage.Quest.U10_94.HeartOfDestruction.DestructiveCharges), 0) - 5)
					end

					for i = 1, #storeDestruction do
						teamDestruction = storeDestruction[i]
						config.destructionPositions[i]:sendMagicEffect(CONST_ME_POFF)
						teamDestruction:teleportTo(config.destructionNewPos)
						teamDestruction:setBossCooldown("World Devourer", os.time() + 13 * 24 * 60 * 60 + 20 * 60 * 60)
						teamDestruction:setStorageValue(Storage.HeartOfDestructionFinalBattle.DestructionTeam, 1) --storage Destruction
						teamDestruction:registerEvent("DevourerStorage")
						teamDestruction:setStorageValue(Storage.Quest.U10_94.HeartOfDestruction.DestructiveCharges, math.max(teamDestruction:getStorageValue(Storage.Quest.U10_94.HeartOfDestruction.DestructiveCharges), 0) - 5)
					end

					for i = 1, #storeRage do
						teamRage = storeRage[i]
						config.ragePositions[i]:sendMagicEffect(CONST_ME_POFF)
						teamRage:teleportTo(config.rageNewPos)
						teamRage:setBossCooldown("World Devourer", os.time() + 13 * 24 * 60 * 60 + 20 * 60 * 60)
						teamRage:setStorageValue(Storage.HeartOfDestructionFinalBattle.RageTeam, 1) --storage Rage
						teamRage:registerEvent("DevourerStorage")
						teamRage:setStorageValue(Storage.Quest.U10_94.HeartOfDestruction.DestructiveCharges, math.max(teamRage:getStorageValue(Storage.Quest.U10_94.HeartOfDestruction.DestructiveCharges), 0) - 5)
					end

					Position(config.hungerNewPos):sendMagicEffect(11)
					Position(config.destructionNewPos):sendMagicEffect(11)
					Position(config.rageNewPos):sendMagicEffect(11)

					-- 45 minutes total for the mini-boss phase (Hunger/Destruction/Rage combined), per reference.
					-- The World Devourer room itself (areaDevourer5, below in changeArea()) keeps its own
					-- separate 30-minute budget, since the reference doesn't specify how 45 minutes should
					-- split between the two phases and this is the more conservative reading.
					areaDevourer1 = addEvent(clearHunger, 45 * 60000, token)
					trackEvent(token, areaDevourer1)
					areaDevourer2 = addEvent(clearDestruction, 45 * 60000, token)
					trackEvent(token, areaDevourer2)
					areaDevourer3 = addEvent(clearRage, 45 * 60000, token)
					trackEvent(token, areaDevourer3)
					areaDevourer4 = addEvent(changeArea, 30000, token) --mudar
					trackEvent(token, areaDevourer4)

					--Variables
					devourerBossesKilled = 0
					theHungerKilled = false
					theDestructionKilled = false
					theRageKilled = false

					hungerSummon = 0
					rageSummon = 0
					destructionSummon = 0
					devourerSummon = 0

					local vortex = Tile({ x = 32281, y = 31348, z = 14 })
					local vortexId = vortex:getItemById(23482)
					if vortex and vortexId then
						vortexId:transform(23483)
						vortexId:setActionId(14352)
					end
				else
					player:sendTextMessage(19, "Someone is in the area.")
				end
			else
				return true
			end
		end
		item:transform(item.itemid == 8911 and 8912 or 8911)
	end
	return true
end

heartDestructionFinal:aid(14332)
heartDestructionFinal:register()
