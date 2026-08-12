local function setStorage()
	--Room 1
	local upConer = { x = 32133, y = 31341, z = 14 } -- upLeftCorner
	local downConer = { x = 32174, y = 31375, z = 14 } -- downRightCorner

	for i = upConer.x, downConer.x do
		for j = upConer.y, downConer.y do
			for k = upConer.z, downConer.z do
				local room = { x = i, y = j, z = k }
				local tile = Tile(room)
				if tile then
					local creatures = tile:getCreatures()
					if creatures and #creatures > 0 then
						for _, creature in pairs(creatures) do
							if creature:isPlayer() and creature:getStorageValue(14320) < 1 then
								creature:setStorageValue(14320, 1) -- Access to boss Anomaly
							end
						end
					end
				end
			end
		end
	end

	--Room 2
	local upConer2 = { x = 32140, y = 31340, z = 15 } -- upLeftCorner
	local downConer2 = { x = 32174, y = 31375, z = 15 } -- downRightCorner

	for f = upConer2.x, downConer2.x do
		for g = upConer2.y, downConer2.y do
			for h = upConer2.z, downConer2.z do
				local room = { x = f, y = g, z = h }
				local tile = Tile(room)
				if tile then
					local creatures = tile:getCreatures()
					if creatures and #creatures > 0 then
						for _, creature in pairs(creatures) do
							if creature:isPlayer() and creature:getStorageValue(14320) < 1 then -- hardcoded storges
								creature:setStorageValue(14320, 1) -- Access to boss Anomaly
							end
						end
					end
				end
			end
		end
	end
end

-- Same 5 tiles actions_charges_lever.lua already spawns Overcharge on (proven-valid, not guessed).
local overchargePositions = {
	{ x = 32152, y = 31355, z = 15 },
	{ x = 32154, y = 31360, z = 15 },
	{ x = 32160, y = 31360, z = 15 },
	{ x = 32162, y = 31356, z = 15 },
	{ x = 32158, y = 31352, z = 15 },
}

-- CORRECTION (executor contract, section G): the 6th Overcharge's creation is checked, with a
-- small bounded retry, and is now owned by the SAME attempt token as the pre-mission that spawned
-- the original 5 (actions_charges_lever.lua's HODAnomalyPremission) - a stale retry from an
-- already-cleared attempt can no longer act on (or abort) a newer attempt that has since started.
-- If it still can't be created, the pre-mission is released promptly via the namespaced
-- HODAnomalyPremissionAbort instead of leaving a room that can never reach 6 kills sitting on its
-- full 15-minute timer.
local function attemptSixthOvercharge(token, retriesLeft)
	retriesLeft = retriesLeft or 3
	if not HODAnomalyPremissionIsCurrent(token) then
		return
	end
	local pos = overchargePositions[math.random(1, #overchargePositions)]
	local monster = Game.createMonster("Overcharge", pos, false, true)
	if monster then
		return
	end
	logger.error("HeartOfDestruction: failed to create the 6th Overcharge (retries left: {})", retriesLeft)
	if retriesLeft > 0 then
		addEvent(attemptSixthOvercharge, 3000, token, retriesLeft - 1)
	else
		Game.setStorageValue(14321, -1)
		HODAnomalyPremissionAbort(token, "6th Overcharge failed to spawn after bounded retries")
	end
end

local overchargeDeath = CreatureEvent("OverchargeDeath")
function overchargeDeath.onDeath(creature)
	local count = Game.getStorageValue(14321) + 1
	Game.setStorageValue(14321, count)

	if count == 6 then
		setStorage()
		creature:say("You have reached enough charges to pass further into the destruction!", TALKTYPE_MONSTER_YELL, isInGhostMode, pid, { x = 32162, y = 31356, z = 15 })
		Game.setStorageValue(14321, -1)
		-- CORRECTION (micro-correction, section D): terminate this attempt's token on success so
		-- it doesn't remain active (and its phase/timeout callbacks alive) until the full
		-- 15-minute timeout - without sweeping the room or teleporting the successful party.
		HODAnomalyPremissionFinish(HODAnomalyPremissionCurrentToken())
	elseif count == 5 then
		attemptSixthOvercharge(HODAnomalyPremissionCurrentToken())
	end

	return true
end

overchargeDeath:register()
