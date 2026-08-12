--[[
Storages (centrally registered as Storage.HeartOfDestructionFinalBattle):
The Hunger = 14334 (HungerTeam)
The Destruction = 14335 (DestructionTeam)
The Rage = 14336 (RageTeam)
]]
--

-- ===== RUN OWNERSHIP (executor contract, sections A-E) =====
-- A single shared runtime table making every final-battle timer/monster provably belong to the
-- CURRENT attempt. Only one final run may be active at a time. Every scheduled callback the final
-- encounter creates captures the run's token and re-checks HODFinalRunIsCurrent before doing
-- anything; a callback whose token no longer matches the active run is a silent no-op.
--
-- Every terminal path (technical spawn failure after commit, normal 45/30-minute timeout, or a
-- legitimate World Devourer kill) funnels through the single HODFinalRunTerminate function below,
-- which distinguishes exactly 3 kinds and applies only the behavior each one is owed:
--   "technical_abort" - only this kind refunds the 5 charges paid at commit and rolls back the
--                        World Devourer cooldown, since it's the only kind caused by something
--                        other than the participants' own choices/outcome.
--   "normal_timeout"  - encounter time expired or the room was abandoned; no refund, the cost was
--                        legitimately spent on a real attempt.
--   "success"         - World Devourer was legitimately killed; no refund, and cleanup of the
--                        room/participants is deferred (see creaturescripts_heart_boss_death.lua)
--                        rather than immediate, to preserve the existing reward/exit flow.
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

-- Used by creaturescripts_heart_minion_death.lua and creaturescripts_heart_boss_death.lua so a
-- stale/unowned monster from an aborted or already-finished run can never mutate a newer run's
-- state or be credited toward a run it doesn't belong to.
function HODFinalRunOwnsMonster(monster)
	if not monster then
		return false
	end
	return HODFinalRun.monsters[monster:getId()] == true
end

-- Registers a just-created monster to whichever run is CURRENTLY active, if any. No token
-- parameter is needed here (unlike event tracking) - at the moment of creation, "the active run"
-- is unambiguous. Exposed globally so the 3 final-battle summon spells (hunger_summon.lua,
-- rage_summon.lua, destruction_summon.lua) and the Disruption escalation transforms
-- (creaturescripts_disruption_transform.lua, creaturescripts_charged_disruption_transform.lua) can
-- register the minions they create without needing to know the run's internals.
function HODFinalRunTrackMonster(monster)
	if not HODFinalRun.active or not monster then
		return
	end
	HODFinalRun.monsters[monster:getId()] = true
end

local function trackEvent(token, eventId)
	if HODFinalRunIsCurrent(token) and eventId then
		HODFinalRun.events[eventId] = true
	end
end

-- Forward declarations - these are mutually referential.
local sweepHungerRoom, sweepDestructionRoom, sweepRageRoom, sweepDevourerRoom
local changeArea, spawnWorldDevourer, sparkDevourerSpawn, attemptMinibossRespawn
local minibossPhaseTimeout, worldDevourerPhaseTimeout

-- ===== SINGLE TERMINAL LIFECYCLE PATH (executor contract, section A) =====
-- kind: "technical_abort" | "normal_timeout" | "success"
-- Order is contract-mandated: verify token -> invalidate active state FIRST -> (technical_abort
-- only) refund charges/roll back cooldown -> stop every owned event -> release team storages/
-- unregister DevourerStorage for this run's participants -> (non-success only) teleport
-- participants out and physically sweep all 4 rooms -> clear runtime collections.
function HODFinalRunTerminate(token, kind, reason)
	if not HODFinalRunIsCurrent(token) then
		return false
	end

	logger.error("HeartOfDestruction: final run {} terminated ({}) - {}", token, kind, reason)

	local participantIds = {}
	for playerId in pairs(HODFinalRun.participants) do
		participantIds[#participantIds + 1] = playerId
	end

	-- Invalidate FIRST (contract-mandated order) so any callback racing in after this point and
	-- re-checking HODFinalRunIsCurrent sees the run as already gone.
	HODFinalRun.active = false

	-- CUSTOM_GLOBAL_LIKE_FAILURE_RECOVERY (executor contract, section C): only a genuine internal
	-- spawn failure after commit refunds the charges/cooldown a participant already legitimately
	-- paid. Normal timeout, abandonment, and legitimate success never refund - those are the
	-- outcomes the cost was always meant to gate. Initial Hunger/Destruction/Rage creation failure
	-- is NOT this path - it happens pre-commit (see heartDestructionFinal.onUse), before any charge
	-- is ever deducted, so there is nothing to refund there.
	if kind == "technical_abort" then
		for _, playerId in ipairs(participantIds) do
			local participant = Player(playerId)
			if participant then
				local charges = math.min(math.max(participant:getStorageValue(Storage.Quest.U10_94.HeartOfDestruction.DestructiveCharges), 0) + 5, 5)
				participant:setStorageValue(Storage.Quest.U10_94.HeartOfDestruction.DestructiveCharges, charges)
				participant:setBossCooldown("World Devourer", 0)
			end
		end
	end

	for eventId in pairs(HODFinalRun.events) do
		stopEvent(eventId)
	end

	for _, playerId in ipairs(participantIds) do
		local participant = Player(playerId)
		if participant then
			participant:setStorageValue(Storage.HeartOfDestructionFinalBattle.HungerTeam, -1)
			participant:setStorageValue(Storage.HeartOfDestructionFinalBattle.DestructionTeam, -1)
			participant:setStorageValue(Storage.HeartOfDestructionFinalBattle.RageTeam, -1)
			participant:unregisterEvent("DevourerStorage")
		end
	end

	if kind ~= "success" then
		-- Abort/timeout release players immediately. A legitimate win intentionally does NOT
		-- release them here - the existing reward/exit flow
		-- (creaturescripts_heart_boss_death.lua's finalRunSuccessCleanup) keeps them in the room
		-- briefly first, operating on a snapshot taken before this function ever runs, so it can
		-- never be confused with a later run.
		for _, playerId in ipairs(participantIds) do
			local participant = Player(playerId)
			if participant then
				participant:teleportTo({ x = 32208, y = 31372, z = 14 })
				participant:getPosition():sendMagicEffect(CONST_ME_TELEPORT)
				if kind == "technical_abort" then
					participant:sendTextMessage(MESSAGE_EVENT_ADVANCE, "The heart of destruction's power falters and releases you - the attempt failed due to an internal error. Your charges and cooldown have been restored; you may try again.")
				else
					participant:sendTextMessage(MESSAGE_EVENT_ADVANCE, "Time has run out - the heart of destruction releases you.")
				end
			end
		end
		sweepHungerRoom()
		sweepDestructionRoom()
		sweepRageRoom()
		sweepDevourerRoom()
	end

	HODFinalRun.participants = {}
	HODFinalRun.events = {}
	HODFinalRun.monsters = {}
	HODFinalRun.pendingRespawns = {}

	return true
end

-- ===== FUNCTIONS =====

-- CORRECTION (executor contract, section B): replaces the previous 3 independent 45-minute
-- per-room timeouts (which only swept their own room and stopped their own event id, leaving
-- HODFinalRun itself active) with ONE run-owned phase timeout that terminates the entire run
-- through the single lifecycle path above.
minibossPhaseTimeout = function(token)
	HODFinalRunTerminate(token, "normal_timeout", "45-minute miniboss phase timeout")
end

worldDevourerPhaseTimeout = function(token)
	HODFinalRunTerminate(token, "normal_timeout", "30-minute World Devourer phase timeout")
end

spawnWorldDevourer = function(token, retriesLeft)
	if not HODFinalRunIsCurrent(token) then
		return
	end
	local monster = Game.createMonster("World Devourer", { x = 32271, y = 31347, z = 14 }, false, true)
	if monster then
		HODFinalRunTrackMonster(monster)
		return
	end
	logger.error("HeartOfDestruction: failed to create World Devourer (retries left: {})", retriesLeft)
	if retriesLeft > 0 then
		trackEvent(token, addEvent(spawnWorldDevourer, 5000, token, retriesLeft - 1))
	else
		HODFinalRunTerminate(token, "technical_abort", "World Devourer failed to spawn after bounded retries")
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
			HODFinalRunTrackMonster(Game.createMonster("Spark of Destruction2", positions[i], false, true))
		end
		sparkSpawnCount = 0
	end
	local eventId = addEvent(sparkDevourerSpawn, 10000, token)
	areaDevourer6 = eventId
	trackEvent(token, eventId)
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

-- CORRECTION (executor contract, section D): a mandatory miniboss respawn attempts creation,
-- verifies it, and only then registers the monster and updates the counter/flag. On failure,
-- bounded retry (3 attempts, 3s apart); if retries are exhausted, the whole run is cleanly
-- terminated (technical_abort - refunds charges/cooldown) rather than let the encounter continue
-- with that room permanently bossless. `pendingRespawns` prevents a second occupied tile in the
-- same room-sweep tick (or a later tick, while a retry is still in flight) from triggering a
-- duplicate concurrent respawn attempt for the same boss.
attemptMinibossRespawn = function(token, name, position, setKilled, retriesLeft)
	retriesLeft = retriesLeft or 3
	if not HODFinalRunIsCurrent(token) then
		return
	end
	local monster = Game.createMonster(name, position, false, true)
	if monster then
		HODFinalRunTrackMonster(monster)
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
		HODFinalRunTerminate(token, "technical_abort", "mandatory miniboss respawn (" .. name .. ") failed after bounded retries")
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
		stopEvent(areaDevourer4)

		-- CORRECTION (micro-correction, section A): the 45-minute miniboss-phase timeout governs
		-- ONLY that phase. Without stopping it here, it kept counting down through the World
		-- Devourer phase too, so the encounter could expire at whichever fired first - the stale
		-- remainder of the 45-minute timer or the fresh 30-minute World-Devourer-phase timer.
		if areaDevourerMinibossTimeout then
			stopEvent(areaDevourerMinibossTimeout)
			HODFinalRun.events[areaDevourerMinibossTimeout] = nil
			areaDevourerMinibossTimeout = nil
		end

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

		-- CONFIRMED GAP (executor contract, section E of the prior pass): these 4 initial Spark of
		-- Destruction2 are checked and logged, but not abort-worthy (World Devourer itself, checked
		-- above, is the mandatory encounter-defining spawn; these are supplementary hazards).
		local sparkPositions = {
			{ x = 32268, y = 31341, z = 14 },
			{ x = 32275, y = 31342, z = 14 },
			{ x = 32269, y = 31352, z = 14 },
			{ x = 32277, y = 31351, z = 14 },
		}
		for i = 1, #sparkPositions do
			local spark = Game.createMonster("Spark of Destruction2", sparkPositions[i], false, true)
			if spark then
				HODFinalRunTrackMonster(spark)
			else
				logger.error("HeartOfDestruction: failed to create initial Spark of Destruction2 #{}", i)
			end
		end

		sparkSpawnCount = 0
		devourerSummon = 0

		-- CORRECTION (executor contract, section B): one run-owned World Devourer-phase timeout
		-- (30 minutes, unchanged budget) replaces the previous clearDevourer-as-timeout, which only
		-- swept the room and stopped 3 event ids without ever touching HODFinalRun.active.
		areaDevourer5 = addEvent(worldDevourerPhaseTimeout, 30 * 60000, token)
		trackEvent(token, areaDevourer5)
		areaDevourer6 = addEvent(sparkDevourerSpawn, 10000, token)
		trackEvent(token, areaDevourer6)
	end
end

-- The 4 room-sweep helpers below are PURE physical hygiene - no token, no run-lifecycle logic, no
-- stopEvent calls (event teardown is now handled uniformly and exactly once by
-- HODFinalRunTerminate). Used for two distinct purposes that must not be confused with each other
-- (executor contract, section B): (1) synchronous pre-run hygiene, called unconditionally at
-- lever-pull time before a fresh attempt is even started - there is no run yet at that point; and
-- (2) as part of HODFinalRunTerminate's own non-success teardown.
sweepHungerRoom = function()
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
end

sweepDestructionRoom = function()
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
end

sweepRageRoom = function()
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
end

sweepDevourerRoom = function()
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

				-- Independently revalidates EVERY participant - access gates, level, Premium, final
				-- boss cooldown, and charges. No side effects run before this passes for everyone.
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
					sweepHungerRoom()
					sweepDestructionRoom()
					sweepRageRoom()
					sweepDevourerRoom()

					-- Create and verify the ONLY copy of the mandatory trio here, before any player
					-- is moved or any state committed. A creation failure aborts cleanly: this
					-- happens PRE-COMMIT (no run has been started, no charge deducted, no cooldown
					-- set yet), so only the bosses this attempt created are removed and nothing
					-- needs to be refunded - the room is simply left retryable.
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

					HODFinalRunTrackMonster(theHunger)
					HODFinalRunTrackMonster(theDestruction)
					HODFinalRunTrackMonster(theRage)

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

					-- 45 minutes total for the mini-boss phase (Hunger/Destruction/Rage combined), per
					-- reference - now a SINGLE run-owned phase timeout (see section B) rather than 3
					-- independent per-room ones. The World Devourer room itself gets its own separate
					-- 30-minute budget once the encounter reaches that phase (see changeArea above).
					areaDevourerMinibossTimeout = addEvent(minibossPhaseTimeout, 45 * 60000, token)
					trackEvent(token, areaDevourerMinibossTimeout)
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
