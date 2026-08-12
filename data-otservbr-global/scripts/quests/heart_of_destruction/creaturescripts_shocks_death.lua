local function createSparksOfDestruction()
	Game.createMonster("Spark Of Destruction", Position(32203, 31246, 14), false, true)
	Game.createMonster("Spark Of Destruction", Position(32205, 31251, 14), false, true)
	Game.createMonster("Spark Of Destruction", Position(32210, 31251, 14), false, true)
	Game.createMonster("Spark Of Destruction", Position(32212, 31246, 14), false, true)
end

local REALITYQUAKE_ROOM_FROM = { x = 32197, y = 31236, z = 14 }
local REALITYQUAKE_ROOM_TO = { x = 32220, y = 31260, z = 14 }
local REALITYQUAKE_EXIT = { x = 32230, y = 31358, z = 11 }

-- CUSTOM_GLOBAL_LIKE_FAILURE_RECOVERY (executor contract, section I of the prior pass; token
-- ownership added in section H of this pass): logging alone is not recovery for a mandatory
-- encounter handoff. Both Foreshock->Aftershock and Aftershock->Realityquake are bounded-retried
-- below, every retry captures and re-checks the encounter token from
-- actions_foreshock.lua's HODRealityquakeEncounter, and a stale retry from an already-finished or
-- aborted encounter can never spawn into (or abort) a newer one. On exhaustion, the encounter is
-- cleanly aborted: token invalidated FIRST, remaining temporary monsters removed, current
-- participants moved to the established exit, the relevant global stage/health state reset, and
-- the Realityquake boss cooldown rolled back (actions_foreshock.lua's BossLever commits it up
-- front, at lever-pull time, before the player ever reaches the real Realityquake - without
-- rolling it back, an internal spawn failure here would lock affected players out of a fight they
-- never actually got to have).
local function abortRealityquakeEncounter(token, reason)
	if not HODRealityquakeEncounterIsCurrent(token) then
		return
	end
	logger.error("HeartOfDestruction: Realityquake encounter {} aborted - {}", token, reason)

	-- Invalidate first (contract-mandated order) so any retry racing in after this point is a
	-- no-op.
	HODRealityquakeEncounterFinish(token)

	for i = REALITYQUAKE_ROOM_FROM.x, REALITYQUAKE_ROOM_TO.x do
		for j = REALITYQUAKE_ROOM_FROM.y, REALITYQUAKE_ROOM_TO.y do
			for k = REALITYQUAKE_ROOM_FROM.z, REALITYQUAKE_ROOM_TO.z do
				local tile = Tile(i, j, k)
				if tile then
					local creatures = tile:getCreatures()
					if creatures and #creatures > 0 then
						for _, creatureUid in pairs(creatures) do
							local creature = Creature(creatureUid)
							if creature then
								if creature:isPlayer() then
									creature:setBossCooldown("Realityquake", 0)
									creature:teleportTo(REALITYQUAKE_EXIT)
									creature:getPosition():sendMagicEffect(CONST_ME_TELEPORT)
									creature:sendTextMessage(MESSAGE_EVENT_ADVANCE, "The Realityquake encounter falters and releases you - the attempt has failed. You may try again.")
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

	Game.setStorageValue(GlobalStorage.HeartOfDestruction.ForeshockHealth, 0)
	Game.setStorageValue(GlobalStorage.HeartOfDestruction.AftershockHealth, 0)
	Game.setStorageValue(GlobalStorage.HeartOfDestruction.ForeshockStage, -1)
	Game.setStorageValue(GlobalStorage.HeartOfDestruction.AftershockStage, -1)
end

local function attemptAftershockSpawn(token, retriesLeft)
	retriesLeft = retriesLeft or 3
	if not HODRealityquakeEncounterIsCurrent(token) then
		return
	end
	local monster = Game.createMonster("Aftershock", Position(32208, 31248, 14), false, true)
	if monster then
		local aftershockHealth = Game.getStorageValue(GlobalStorage.HeartOfDestruction.AftershockHealth) > 0 and Game.getStorageValue(GlobalStorage.HeartOfDestruction.AftershockHealth) or 0
		monster:addHealth(-monster:getHealth() + aftershockHealth, COMBAT_PHYSICALDAMAGE)
		createSparksOfDestruction()
		return
	end
	logger.error("HeartOfDestruction: failed to create Aftershock (retries left: {})", retriesLeft)
	if retriesLeft > 0 then
		-- CORRECTION (micro-correction, section E): the retry's own event id is registered to the
		-- encounter so HODRealityquakeEncounterFinish can positively cancel it instead of merely
		-- relying on the token check the callback would otherwise perform on its own.
		HODRealityquakeEncounterTrackEvent(token, addEvent(attemptAftershockSpawn, 3000, token, retriesLeft - 1))
	else
		abortRealityquakeEncounter(token, "Aftershock failed to spawn after bounded retries")
	end
end

local function attemptRealityquakeSpawn(token, position, retriesLeft)
	retriesLeft = retriesLeft or 3
	if not HODRealityquakeEncounterIsCurrent(token) then
		return
	end
	local monster = Game.createMonster("Realityquake", position, false, true)
	if monster then
		createSparksOfDestruction()
		-- The chain is complete - nothing further will ever retry under this token, so it's
		-- finished cleanly rather than left inertly "active" (executor contract, section H).
		HODRealityquakeEncounterFinish(token)
		return
	end
	logger.error("HeartOfDestruction: failed to create Realityquake (retries left: {})", retriesLeft)
	if retriesLeft > 0 then
		HODRealityquakeEncounterTrackEvent(token, addEvent(attemptRealityquakeSpawn, 3000, token, position, retriesLeft - 1))
	else
		abortRealityquakeEncounter(token, "Realityquake failed to spawn after bounded retries")
	end
end

local shocksDeath = CreatureEvent("ShocksDeath")

function shocksDeath.onDeath(creature)
	if not creature or not creature:isMonster() then
		return true
	end

	local creatureName = creature:getName():lower()
	local token = HODRealityquakeEncounterCurrentToken()
	if creatureName == "foreshock" then
		attemptAftershockSpawn(token)
	elseif creatureName == "aftershock" then
		attemptRealityquakeSpawn(token, creature:getPosition())
	end
	return true
end

shocksDeath:register()
