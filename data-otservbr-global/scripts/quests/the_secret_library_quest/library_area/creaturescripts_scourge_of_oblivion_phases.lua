-- Secret Library final invasion - The Scourge of Oblivion's 3-phase cycle.
--
-- Yellow (vulnerable, the_scourge_of_oblivion.lua) <-> Red ("reflective shields",
-- the_scourge_of_oblivion_reflective.lua) <-> Blue ("prepares a devastating attack" then fires a
-- 4-directional beam, the_scourge_of_oblivion_immune.lua).
--
-- CORRECTION (Secret Library repair v2, sections 29-31): phase state and the delayed beam callback
-- previously lived entirely on Game-global storages (Invasion.ScourgePhase) with a raw
-- addEvent(fireBeam, ..., creature) guarded only by isRemoved() - a stale beam from a finished/reset
-- attempt could still fire, and any monster typed "The Scourge of Oblivion..." anywhere would drive the
-- shared phase counter. Rebuilt on SecretLibraryInvasionRun (actions_the_scourge_of_oblivion.lua):
-- exact current-run token, exact owned creature id (constant across every setType transform), and a
-- phase generation bumped on every transition - a delayed beam now verifies all three before it can
-- deal damage.
local Invasion = Storage.Quest.U11_80.TheSecretLibrary.SecretLibraryInvasion

-- CUSTOM_GLOBAL_LIKE_PENDING_EXACT_TIMING: no exact phase-duration timings are given anywhere in the
-- reference (only "after several turns changes form") - the intervals below are a disclosed,
-- reasonable judgment call, unchanged from the pre-existing values, not sourced numbers.
local YELLOW_DURATION = 25 * 1000
local RED_DURATION = 15 * 1000
local BLUE_PREPARE_DURATION = 5 * 1000
-- Owner-given exact range (section 30): "four-direction beam ~8000-12000 damage".
local BEAM_DAMAGE = { 8000, 12000 }

local PHASE_YELLOW, PHASE_RED, PHASE_BLUE = 1, 2, 3

local function fireBeam(token, generation, creatureId)
	if not SecretLibraryInvasionRunIsCurrent(token) then
		return
	end
	if SecretLibraryInvasionRun.scourgePhaseGeneration ~= generation then
		return -- stale: the phase already changed (boss died, timed out, or cycled again) since this was scheduled
	end
	local monster = Creature(creatureId)
	if not monster or monster:isRemoved() or not SecretLibraryInvasionRunOwnsScourge(monster) then
		return
	end
	local position = monster:getPosition()
	local directions = {
		{ x = 0, y = -1 }, -- north
		{ x = 0, y = 1 }, -- south
		{ x = -1, y = 0 }, -- west
		{ x = 1, y = 0 }, -- east
	}
	for _, dir in ipairs(directions) do
		for step = 1, 8 do
			local tilePos = Position(position.x + dir.x * step, position.y + dir.y * step, position.z)
			tilePos:sendMagicEffect(CONST_ME_ENERGYHIT)
			for _, spectator in ipairs(Game.getSpectators(tilePos, false, true, 0, 0, 0, 0)) do
				spectator:addHealth(-math.random(BEAM_DAMAGE[1], BEAM_DAMAGE[2]))
			end
		end
	end
end

local function swapScourge(monster, newName)
	local oldHealth = monster:getHealth()
	monster:setType(newName)
	monster:addHealth(-(monster:getHealth() - oldHealth))
	return monster
end

local scourgePhaseCycle = CreatureEvent("InvasionScourgePhaseCycle")
function scourgePhaseCycle.onThink(creature, interval)
	local token = SecretLibraryInvasionRunCurrentToken()
	if not token or not SecretLibraryInvasionRunOwnsScourge(creature) then
		return true
	end
	local name = creature:getName():lower()
	if not name:find("the scourge of oblivion") then
		return true
	end

	local phase = SecretLibraryInvasionRun.scourgePhase
	local now = os.time()

	if phase < 1 then
		-- First tick after activation (dormant -> yellow, movements_invasion_start.lua).
		SecretLibraryInvasionRun.scourgePhase = PHASE_YELLOW
		Game.setStorageValue(Invasion.ScourgePhase, PHASE_YELLOW)
		creature:setStorageValue(2, now + math.floor(YELLOW_DURATION / 1000))
		return true
	end

	local phaseUntil = creature:getStorageValue(2)
	if phaseUntil > now then
		return true
	end

	if phase == PHASE_YELLOW then
		-- Yellow -> Red or Blue (2-in-3 chance red, matching red being the more frequent phase per
		-- the reference's description order).
		if math.random(1, 3) == 1 then
			swapScourge(creature, "The Scourge of Oblivion (Immune)")
			SecretLibraryInvasionRun.scourgePhase = PHASE_BLUE
			SecretLibraryInvasionRun.scourgePhaseGeneration = SecretLibraryInvasionRun.scourgePhaseGeneration + 1
			local generation = SecretLibraryInvasionRun.scourgePhaseGeneration
			creature:setStorageValue(2, now + math.floor(BLUE_PREPARE_DURATION / 1000) + 1)
			for _, spectator in ipairs(Game.getSpectators(creature:getPosition(), false, true, 10, 10, 10, 10)) do
				spectator:sendTextMessage(MESSAGE_EVENT_ADVANCE, "The Scourge of Oblivion prepares a devastating attack!")
			end
			SecretLibraryInvasionRunTrackEvent(token, addEvent(fireBeam, BLUE_PREPARE_DURATION, token, generation, creature:getId()))
		else
			swapScourge(creature, "The Scourge of Oblivion (Reflective)")
			SecretLibraryInvasionRun.scourgePhase = PHASE_RED
			SecretLibraryInvasionRun.scourgePhaseGeneration = SecretLibraryInvasionRun.scourgePhaseGeneration + 1
			creature:setStorageValue(2, now + math.floor(RED_DURATION / 1000))
			for _, spectator in ipairs(Game.getSpectators(creature:getPosition(), false, true, 10, 10, 10, 10)) do
				spectator:sendTextMessage(MESSAGE_EVENT_ADVANCE, "The Scourge of Oblivion activated its reflective shields!")
			end
		end
	elseif phase == PHASE_RED or phase == PHASE_BLUE then
		swapScourge(creature, "The Scourge of Oblivion")
		SecretLibraryInvasionRun.scourgePhase = PHASE_YELLOW
		SecretLibraryInvasionRun.scourgePhaseGeneration = SecretLibraryInvasionRun.scourgePhaseGeneration + 1
		creature:setStorageValue(2, now + math.floor(YELLOW_DURATION / 1000))
	end
	Game.setStorageValue(Invasion.ScourgePhase, SecretLibraryInvasionRun.scourgePhase)
	return true
end
scourgePhaseCycle:register()

-- CORRECTION (section 32): success credit restricted to this run's own roster, still physically
-- present in the central hall at the moment of the legitimate kill - not a damage-map scan of every
-- nonparticipant who ever hit the boss.
local ROOM_FROM = Position(32712, 32723, 11)
local ROOM_TO = Position(32738, 32748, 11)

local function isInsideRoom(player)
	local pos = player:getPosition()
	return pos.x >= ROOM_FROM.x and pos.x <= ROOM_TO.x and pos.y >= ROOM_FROM.y and pos.y <= ROOM_TO.y and pos.z == ROOM_FROM.z
end

local scourgeDeath = CreatureEvent("InvasionScourgeDeath")
function scourgeDeath.onDeath(creature, corpse, lasthitkiller, mostdamagekiller)
	local token = SecretLibraryInvasionRunCurrentToken()
	if not token or not SecretLibraryInvasionRunOwnsScourge(creature) then
		return true
	end
	for playerId in pairs(SecretLibraryInvasionRun.participants) do
		local player = Player(playerId)
		if player and isInsideRoom(player) and not player:hasAchievement("Library Liberator") then
			player:addAchievement("Library Liberator")
		end
	end
	SecretLibraryInvasionRunTerminate(token, "success", "The Scourge of Oblivion defeated")
	return true
end
scourgeDeath:register()
