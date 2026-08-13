-- ================================================================
-- LOKATHMOR RUN OWNERSHIP (Secret Library repair v2, section 14)
-- ================================================================
-- Confirmed pre-existing state: the entire trap/prison phase trigger mechanism did not exist in code
-- at all - nothing ever set Lokathmor's speed to 0 (the one condition actions_parchment.lua's own
-- isStuck() checks for), and neither Force Field nor Dark Knowledge was ever spawned anywhere. Item
-- 28488 ("parchment of dark knowledge") could only ever be created on a Dark Knowledge's death, which
-- never happened - so the whole book/desk sub-mechanic was entirely dead. This builds the missing
-- orchestration using ONLY the monster types already defined in this repository (Force Field, Dark
-- Knowledge) - no new monster/item asset is invented, matching the explicit "do not invent missing
-- entities" instruction; only their spawn/trigger wiring was missing.
LokathmorRun = {
	token = 0,
	active = false,
	bossId = nil, -- the one Lokathmor instance this run owns
	participants = {}, -- set: playerId -> true
	trapGeneration = 0, -- bumped once per trap-phase trigger
	forceFieldIds = {}, -- set: creatureId -> true, current generation's owned Force Fields
	darkKnowledgeIds = {}, -- set: creatureId -> true, current generation's owned Dark Knowledge
	trapped = false, -- true while the current generation's trap phase is active
	events = {}, -- set: eventId -> true
}

function LokathmorRunIsCurrent(token)
	return token ~= nil and token > 0 and LokathmorRun.active and LokathmorRun.token == token
end

function LokathmorRunCurrentToken()
	if LokathmorRun.active then
		return LokathmorRun.token
	end
	return nil
end

function LokathmorRunOwnsBoss(creature)
	return creature ~= nil and LokathmorRun.active and LokathmorRun.bossId == creature:getId()
end

function LokathmorRunIsParticipant(token, playerId)
	return LokathmorRunIsCurrent(token) and LokathmorRun.participants[playerId] == true
end

function LokathmorRunTrackEvent(token, eventId)
	if LokathmorRunIsCurrent(token) and eventId then
		LokathmorRun.events[eventId] = true
	end
end

function LokathmorRunOwnsForceField(creature)
	return creature ~= nil and LokathmorRun.active and LokathmorRun.forceFieldIds[creature:getId()] == true
end

function LokathmorRunOwnsDarkKnowledge(creature)
	return creature ~= nil and LokathmorRun.active and LokathmorRun.darkKnowledgeIds[creature:getId()] == true
end

function LokathmorRunCurrentGeneration()
	if LokathmorRun.active then
		return LokathmorRun.trapGeneration
	end
	return nil
end

function LokathmorRunIsTrapped(token)
	return LokathmorRunIsCurrent(token) and LokathmorRun.trapped == true
end

local EXIT_POSITION = Position(32466, 32654, 12)
local CENTER_POSITION = Position(32751, 32689, 10)

-- Single terminal lifecycle path. kind is one of "technical_abort", "normal_timeout", "success".
-- Success cleanup is left entirely to BossLeverOnDeath (registered directly on Lokathmor, since
-- custom createFunction bosses never go through boss_lever.lua's generic registration path) - this
-- terminator must not race ahead of it on success, only on the two non-success paths.
function LokathmorRunTerminate(token, kind, reason)
	if not LokathmorRunIsCurrent(token) then
		return
	end
	logger.info("SecretLibrary/Lokathmor: run {} terminated ({}) - {}", token, kind, reason or "")

	LokathmorRun.active = false
	for eventId in pairs(LokathmorRun.events) do
		stopEvent(eventId)
	end

	if kind == "technical_abort" then
		for playerId in pairs(LokathmorRun.participants) do
			local player = Player(playerId)
			if player then
				player:setBossCooldown("lokathmor", 0)
			end
		end
	end

	if kind ~= "success" then
		for creatureId in pairs(LokathmorRun.forceFieldIds) do
			local monster = Creature(creatureId)
			if monster then
				monster:remove()
			end
		end
		for creatureId in pairs(LokathmorRun.darkKnowledgeIds) do
			local monster = Creature(creatureId)
			if monster then
				monster:remove()
			end
		end
		local boss = Creature(LokathmorRun.bossId)
		if boss then
			boss:remove()
		end

		local bossLever = BossLever["lokathmor"]
		if bossLever and bossLever.bossAlive then
			bossLever.bossAlive = false
			if bossLever.emptyRoomEvent then
				stopEvent(bossLever.emptyRoomEvent)
				bossLever.emptyRoomEvent = nil
			end
			if bossLever.timeoutEvent then
				stopEvent(bossLever.timeoutEvent)
				bossLever.timeoutEvent = nil
			end
			local zone = bossLever:getZone()
			zone:refresh()
			zone:removePlayers()
			zone:cleanRoom()
		end
	end

	LokathmorRun.bossId = nil
	LokathmorRun.participants = {}
	LokathmorRun.trapGeneration = 0
	LokathmorRun.forceFieldIds = {}
	LokathmorRun.darkKnowledgeIds = {}
	LokathmorRun.trapped = false
	LokathmorRun.events = {}
end

local function watchEmptyRoom(token)
	if not LokathmorRunIsCurrent(token) then
		return
	end
	local zone = Zone("boss." .. toKey("lokathmor"))
	if zone and zone:countPlayers() == 0 then
		LokathmorRunTerminate(token, "normal_timeout", "room emptied before the encounter concluded")
		return
	end
	LokathmorRunTrackEvent(token, addEvent(watchEmptyRoom, 20 * 1000, token))
end

-- ================================================================
-- TRAP/PRISON PHASE (Secret Library repair v2, section 14)
-- ================================================================
-- CUSTOM_GLOBAL_LIKE_PENDING_EXACT_TIMING: the owner reference states Lokathmor "periodically" traps
-- players with no exact interval given anywhere. A stable functional interval is used instead - not
-- claimed Global-exact.
local TRAP_TRIGGER_INTERVAL = 90 * 1000

-- Force Field positions are derived at runtime relative to Lokathmor's own already-established boss
-- position (CENTER_POSITION, unchanged from the pre-existing config.boss.position) rather than a new
-- guessed map area - four cardinal offsets forming a cage around him. Exact tile-level correctness
-- cannot be proven against the configured OTBM this session (MAP_AUDIT_NOT_RUN), but this does not
-- gate quest progression on any single specific tile the way a puzzle trigger would - see the Manual
-- RME Manifest for the full disclosure.
local function forceFieldPositions()
	return {
		Position(CENTER_POSITION.x - 2, CENTER_POSITION.y, CENTER_POSITION.z),
		Position(CENTER_POSITION.x + 2, CENTER_POSITION.y, CENTER_POSITION.z),
		Position(CENTER_POSITION.x, CENTER_POSITION.y - 2, CENTER_POSITION.z),
		Position(CENTER_POSITION.x, CENTER_POSITION.y + 2, CENTER_POSITION.z),
	}
end

local DARK_KNOWLEDGE_POSITION = Position(CENTER_POSITION.x, CENTER_POSITION.y - 4, CENTER_POSITION.z)

local attemptTrapPhase
local scheduleNextTrapCheck

scheduleNextTrapCheck = function(token)
	LokathmorRunTrackEvent(token, addEvent(attemptTrapPhase, TRAP_TRIGGER_INTERVAL, token, 3))
end

-- CORRECTION (section 14/39): validate -> create full generation (4 Force Fields + 1 Dark Knowledge)
-- -> verify -> commit trapped state. Exhausting bounded retry technical-aborts the whole encounter
-- (a mandatory phase entity that cannot be verified must end the attempt, matching every other
-- boss's mandatory-entity precedent in this project), rather than silently skipping the phase.
attemptTrapPhase = function(token, retriesLeft)
	retriesLeft = retriesLeft or 3
	if not LokathmorRunIsCurrent(token) or LokathmorRun.trapped then
		return
	end
	local boss = Creature(LokathmorRun.bossId)
	if not boss or not LokathmorRunOwnsBoss(boss) or boss:getHealth() <= 0 then
		return
	end

	local generation = LokathmorRun.trapGeneration + 1
	local spawnedFields = {}
	local allOk = true
	for _, pos in pairs(forceFieldPositions()) do
		local field = Game.createMonster("Force Field", pos, false, true)
		if field then
			table.insert(spawnedFields, field)
		else
			allOk = false
		end
	end
	local darkKnowledge = nil
	if allOk then
		darkKnowledge = Game.createMonster("Dark Knowledge", DARK_KNOWLEDGE_POSITION, false, true)
		if not darkKnowledge then
			allOk = false
		end
	end

	if allOk then
		LokathmorRun.trapGeneration = generation
		LokathmorRun.forceFieldIds = {}
		LokathmorRun.darkKnowledgeIds = {}
		for _, field in pairs(spawnedFields) do
			LokathmorRun.forceFieldIds[field:getId()] = true
		end
		LokathmorRun.darkKnowledgeIds[darkKnowledge:getId()] = true
		darkKnowledge:setStorageValue(1, generation)

		boss:immune(true)
		boss:setSpeed(0)
		LokathmorRun.trapped = true
		boss:say("YOU CANNOT BREAK MY WILL!", TALKTYPE_MONSTER_SAY)
		return
	end

	for _, field in pairs(spawnedFields) do
		field:remove()
	end
	if darkKnowledge then
		darkKnowledge:remove()
	end
	logger.error("SecretLibrary/Lokathmor: trap phase mandatory entities failed to fully spawn (retries left: {})", retriesLeft)
	if retriesLeft > 0 then
		LokathmorRunTrackEvent(token, addEvent(attemptTrapPhase, 1000, token, retriesLeft - 1))
	else
		LokathmorRunTerminate(token, "technical_abort", "trap phase mandatory entities failed to spawn after bounded retries")
	end
end

-- CORRECTION (section 9/14 precedent): every accepted participant independently verified.
local function validateParticipant(creature)
	if not creature or not creature:isPlayer() then
		return true
	end
	if not creature:isPremium() then
		creature:sendTextMessage(MESSAGE_EVENT_ADVANCE, "You need a premium account to face Lokathmor.")
		return false
	end
	if creature:getStorageValue(Storage.Quest.U11_80.TheSecretLibrary.LibraryPermission) < 7 then
		creature:sendTextMessage(MESSAGE_EVENT_ADVANCE, "You have not yet been granted access to the Secret Library.")
		return false
	end
	return true
end

local lastInfoPositions = nil

local function createLokathmorEncounter()
	if LokathmorRun.active then
		logger.error("SecretLibrary/Lokathmor: a run is already active, refusing a second concurrent start")
		return false
	end

	local boss = Game.createMonster("Lokathmor", CENTER_POSITION, false, true)
	if not boss then
		logger.error("SecretLibrary/Lokathmor: technical abort - Lokathmor failed to spawn")
		return false
	end
	boss:registerEvent("BossLeverOnDeath")

	LokathmorRun.token = LokathmorRun.token + 1
	local token = LokathmorRun.token
	LokathmorRun.active = true
	LokathmorRun.bossId = boss:getId()
	LokathmorRun.participants = {}
	LokathmorRun.trapGeneration = 0
	LokathmorRun.forceFieldIds = {}
	LokathmorRun.darkKnowledgeIds = {}
	LokathmorRun.trapped = false
	LokathmorRun.events = {}

	if lastInfoPositions then
		for _, posInfo in pairs(lastInfoPositions) do
			local player = posInfo.creature
			if player and player:isPlayer() then
				LokathmorRun.participants[player:getId()] = true
			end
		end
	end

	-- CORRECTION (section 12): 17-minute encounter limit for each of the four inner bosses (no
	-- established different canonical timer was found for this project).
	LokathmorRunTrackEvent(
		token,
		addEvent(function()
			LokathmorRunTerminate(token, "normal_timeout", "encounter time limit exceeded")
		end, 17 * 60 * 1000)
	)
	LokathmorRunTrackEvent(token, addEvent(watchEmptyRoom, 20 * 1000, token))
	scheduleNextTrapCheck(token)

	return true
end

local config = {
	boss = {
		name = "Lokathmor",
		createFunction = createLokathmorEncounter,
	},
	requiredLevel = 250,
	timeToDefeat = 17 * 60,
	playerPositions = {
		{ pos = Position(32721, 32749, 10), teleport = Position(32751, 32685, 10), effect = CONST_ME_TELEPORT },
		{ pos = Position(32722, 32749, 10), teleport = Position(32751, 32685, 10), effect = CONST_ME_TELEPORT },
		{ pos = Position(32723, 32749, 10), teleport = Position(32751, 32685, 10), effect = CONST_ME_TELEPORT },
		{ pos = Position(32724, 32749, 10), teleport = Position(32751, 32685, 10), effect = CONST_ME_TELEPORT },
		{ pos = Position(32725, 32749, 10), teleport = Position(32751, 32685, 10), effect = CONST_ME_TELEPORT },
	},
	monsters = {
		{ name = "knowledge raider", pos = Position(32747, 32684, 10) },
		{ name = "knowledge raider", pos = Position(32755, 32684, 10) },
		{ name = "knowledge raider", pos = Position(32755, 32694, 10) },
		{ name = "knowledge raider", pos = Position(32747, 32694, 10) },
	},
	specPos = {
		from = Position(32742, 32681, 10),
		to = Position(32758, 32696, 10),
	},
	exit = EXIT_POSITION,
	onUseExtra = function(player, infoPositions)
		lastInfoPositions = infoPositions
		return validateParticipant(player)
	end,
}

local lever = BossLever(config)
lever:position(Position(32720, 32749, 10))
lever:register()
