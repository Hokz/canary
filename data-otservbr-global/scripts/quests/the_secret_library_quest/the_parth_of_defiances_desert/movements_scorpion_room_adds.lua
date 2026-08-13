-- Furious Scorpion boss room - the reference describes two extra add-waves inside this room
-- ("entering the room spawns 4 skeleton elite warriors when moving left, moving deeper spawns 2
-- undead elite gladiators") that the pre-existing implementation (movements_teleportTo.lua's
-- startBattle) never spawned at all - the room was just the boss alone. The existing, already-working
-- boss-spawn/5-minute-timer/20h-cooldown mechanic in that file is untouched (only 2 reset lines added
-- there, see the end of that file); this adds the two supplementary one-time add-waves inside the
-- same, already-real room bounds.
--
-- MAP POLICY (Secret Library repair v2, section 6.1): the six coordinates below (2 walk-in triggers +
-- 4 Skeleton Elite Warrior spots + 2 Undead Elite Gladiator spots) are NOT_PROVEN - the configured
-- OTBM was unavailable this session (MAP_AUDIT_NOT_RUN) and no source gives exact tile-level
-- coordinates, only the narrative "moving left"/"moving deeper" description. They are kept LIVE
-- (not disabled) rather than removed, for three specific, disclosed reasons: (1) they gate no quest-
-- progression storage - Furious Scorpion's own death is what completes the Path of Defiance branch,
-- entirely independent of whether these supplementary adds ever spawn, so "fail closed where
-- progression depends on it" does not apply here; (2) disabling an owner-required mechanic outright
-- would silently drop required content with no path back to correctness; (3) the transactional/
-- ownership defect this section is actually about (see below) is independent of exact position
-- accuracy. See the Manual RME Manifest for the formal NOT_PROVEN classification; if a future pass
-- proves these coordinates wrong, only the Position() literals below need to change.
local ScorpionRoomAdds = Storage.Quest.U11_80.TheSecretLibrary.ScorpionRoomAdds
local roomFrom = Position(32943, 32303, 8)
local roomTo = Position(32960, 32315, 8)
local westTrigger = Position(32955, 32309, 8) -- "moving left" from the entry point
local deepTrigger = Position(32949, 32309, 8) -- "moving deeper", just past the boss's spawn point

local function isScorpionAttemptActive()
	local spectators = Game.getSpectators(roomFrom, false, false, 0, 0, 0, 0, roomTo)
	for _, spectator in ipairs(spectators) do
		if spectator:isMonster() and spectator:getName():lower() == "furious scorpion" then
			return true
		end
	end
	return false
end

-- CORRECTION (Secret Library repair v2, section 6.2): validate -> create full generation -> verify ->
-- commit "spawned" state, replacing the previous flag-set-before-spawn ordering (which permanently
-- marked a wave "done" even if some/all Game.createMonster calls silently failed) and the unchecked
-- Game.createMonster calls. "4 Skeleton Elite Warriors" / "2 Undead Elite Gladiators" both mean ALL
-- of that wave, never a partial 1-3 or 1. On exhausted bounded retry, the "spawned" flag is NEVER set
-- - so it is not a false/permanent completion, and stepping on the trigger tile again later (a
-- legitimate retry) re-attempts the full wave from scratch rather than being permanently skipped.
local function attemptEliteWarriors(triggerPosition, retriesLeft)
	retriesLeft = retriesLeft or 3
	if not isScorpionAttemptActive() then
		return
	end
	if Game.getStorageValue(ScorpionRoomAdds.EliteWarriorsSpawned) >= 1 then
		return
	end

	local spawnPositions = {
		Position(32954, 32307, 8),
		Position(32954, 32308, 8),
		Position(32954, 32310, 8),
		Position(32954, 32311, 8),
	}
	local spawned = {}
	local allOk = true
	for _, spawnPosition in ipairs(spawnPositions) do
		local monster = Game.createMonster("Skeleton Elite Warrior", spawnPosition, true, true)
		if monster then
			table.insert(spawned, monster)
		else
			allOk = false
		end
	end

	if allOk then
		Game.setStorageValue(ScorpionRoomAdds.EliteWarriorsSpawned, 1)
		triggerPosition:sendMagicEffect(CONST_ME_TELEPORT)
		return
	end

	for _, monster in pairs(spawned) do
		monster:remove()
	end
	logger.error("SecretLibrary/Desert: Skeleton Elite Warriors wave failed to fully spawn (retries left: {})", retriesLeft)
	if retriesLeft > 0 then
		addEvent(attemptEliteWarriors, 1000, triggerPosition, retriesLeft - 1)
	else
		logger.error("SecretLibrary/Desert: technical failure - Skeleton Elite Warriors wave not consumed, legitimate retry remains possible")
	end
end

local function attemptEliteGladiators(triggerPosition, retriesLeft)
	retriesLeft = retriesLeft or 3
	if not isScorpionAttemptActive() then
		return
	end
	if Game.getStorageValue(ScorpionRoomAdds.EliteGladiatorsSpawned) >= 1 then
		return
	end

	local spawnPositions = {
		Position(32948, 32308, 8),
		Position(32948, 32310, 8),
	}
	local spawned = {}
	local allOk = true
	for _, spawnPosition in ipairs(spawnPositions) do
		local monster = Game.createMonster("Undead Elite Gladiator", spawnPosition, true, true)
		if monster then
			table.insert(spawned, monster)
		else
			allOk = false
		end
	end

	if allOk then
		Game.setStorageValue(ScorpionRoomAdds.EliteGladiatorsSpawned, 1)
		triggerPosition:sendMagicEffect(CONST_ME_TELEPORT)
		return
	end

	for _, monster in pairs(spawned) do
		monster:remove()
	end
	logger.error("SecretLibrary/Desert: Undead Elite Gladiators wave failed to fully spawn (retries left: {})", retriesLeft)
	if retriesLeft > 0 then
		addEvent(attemptEliteGladiators, 1000, triggerPosition, retriesLeft - 1)
	else
		logger.error("SecretLibrary/Desert: technical failure - Undead Elite Gladiators wave not consumed, legitimate retry remains possible")
	end
end

local addsRoom = MoveEvent()

function addsRoom.onStepIn(creature, item, position, fromPosition)
	local player = creature:getPlayer()
	if not player then
		return true
	end
	if not isScorpionAttemptActive() then
		return true
	end

	if position == westTrigger then
		if Game.getStorageValue(ScorpionRoomAdds.EliteWarriorsSpawned) < 1 then
			attemptEliteWarriors(position, 3)
		end
	elseif position == deepTrigger then
		if Game.getStorageValue(ScorpionRoomAdds.EliteGladiatorsSpawned) < 1 then
			attemptEliteGladiators(position, 3)
		end
	end
	return true
end

addsRoom:position(westTrigger)
addsRoom:position(deepTrigger)
addsRoom:register()
