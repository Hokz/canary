-- ================================================================
-- GORZINDEL RUN OWNERSHIP (Secret Library repair v2, section 15)
-- ================================================================
GorzindelRun = {
	token = 0,
	active = false,
	bossId = nil, -- the one Gorzindel instance this run owns
	tomeId = nil, -- the current Stolen Tome of Portals instance this run owns
	knowledgeIds = {}, -- set: creatureId -> true, the exact 5 Stolen Knowledge this run owns
	knowledgeRemaining = 0,
	participants = {}, -- set: playerId -> true
	events = {}, -- set: eventId -> true
}

function GorzindelRunIsCurrent(token)
	return token ~= nil and token > 0 and GorzindelRun.active and GorzindelRun.token == token
end

function GorzindelRunCurrentToken()
	if GorzindelRun.active then
		return GorzindelRun.token
	end
	return nil
end

function GorzindelRunOwnsBoss(creature)
	return creature ~= nil and GorzindelRun.active and GorzindelRun.bossId == creature:getId()
end

function GorzindelRunOwnsTome(creature)
	return creature ~= nil and GorzindelRun.active and GorzindelRun.tomeId == creature:getId()
end

function GorzindelRunOwnsKnowledge(creature)
	return creature ~= nil and GorzindelRun.active and GorzindelRun.knowledgeIds[creature:getId()] == true
end

function GorzindelRunIsParticipant(token, playerId)
	return GorzindelRunIsCurrent(token) and GorzindelRun.participants[playerId] == true
end

function GorzindelRunTrackEvent(token, eventId)
	if GorzindelRunIsCurrent(token) and eventId then
		GorzindelRun.events[eventId] = true
	end
end

-- CORRECTION (section 15): exact-count decrement replacing the previous redundant 1-second-delayed
-- Game.getSpectators re-scan (which ran once per knowledge death, independently, with no single
-- completion flag guarding it from firing more than once).
function GorzindelRunKnowledgeDied(creatureId)
	if not GorzindelRun.active or not GorzindelRun.knowledgeIds[creatureId] then
		return false
	end
	GorzindelRun.knowledgeIds[creatureId] = nil
	GorzindelRun.knowledgeRemaining = math.max(0, GorzindelRun.knowledgeRemaining - 1)
	return GorzindelRun.knowledgeRemaining <= 0
end

function GorzindelRunSetTome(token, monster)
	if GorzindelRunIsCurrent(token) then
		GorzindelRun.tomeId = monster and monster:getId() or nil
	end
end

local EXIT_POSITION = Position(32660, 32734, 12)
local CENTER_POSITION = Position(32687, 32715, 10)

function GorzindelRunTerminate(token, kind, reason)
	if not GorzindelRunIsCurrent(token) then
		return
	end
	logger.info("SecretLibrary/Gorzindel: run {} terminated ({}) - {}", token, kind, reason or "")

	GorzindelRun.active = false
	for eventId in pairs(GorzindelRun.events) do
		stopEvent(eventId)
	end

	if kind == "technical_abort" then
		for playerId in pairs(GorzindelRun.participants) do
			local player = Player(playerId)
			if player then
				player:setBossCooldown("gorzindel", 0)
			end
		end
	end

	if kind ~= "success" then
		for creatureId in pairs(GorzindelRun.knowledgeIds) do
			local monster = Creature(creatureId)
			if monster then
				monster:remove()
			end
		end
		local tome = Creature(GorzindelRun.tomeId)
		if tome then
			tome:remove()
		end
		local boss = Creature(GorzindelRun.bossId)
		if boss then
			boss:remove()
		end

		local bossLever = BossLever["gorzindel"]
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

	GorzindelRun.bossId = nil
	GorzindelRun.tomeId = nil
	GorzindelRun.knowledgeIds = {}
	GorzindelRun.knowledgeRemaining = 0
	GorzindelRun.participants = {}
	GorzindelRun.events = {}
end

local function watchEmptyRoom(token)
	if not GorzindelRunIsCurrent(token) then
		return
	end
	local zone = Zone("boss." .. toKey("gorzindel"))
	if zone and zone:countPlayers() == 0 then
		GorzindelRunTerminate(token, "normal_timeout", "room emptied before the encounter concluded")
		return
	end
	GorzindelRunTrackEvent(token, addEvent(watchEmptyRoom, 20 * 1000, token))
end

local function validateParticipant(creature)
	if not creature or not creature:isPlayer() then
		return true
	end
	if not creature:isPremium() then
		creature:sendTextMessage(MESSAGE_EVENT_ADVANCE, "You need a premium account to face Gorzindel.")
		return false
	end
	if creature:getStorageValue(Storage.Quest.U11_80.TheSecretLibrary.LibraryPermission) < 7 then
		creature:sendTextMessage(MESSAGE_EVENT_ADVANCE, "You have not yet been granted access to the Secret Library.")
		return false
	end
	return true
end

local lastInfoPositions = nil

-- CORRECTION (section 15/39): mandatory Gorzindel + 5 Stolen Knowledge + Stolen Tome of Portals are
-- all verified before commit. The 7 "minion" adds remain ambient/non-mandatory (bounded light retry,
-- a miss does not abort the fight), matching this project's established mandatory-vs-ambient
-- distinction.
local function createGorzindelEncounter()
	if GorzindelRun.active then
		logger.error("SecretLibrary/Gorzindel: a run is already active, refusing a second concurrent start")
		return false
	end

	local boss = Game.createMonster("Gorzindel", CENTER_POSITION, false, true)
	if not boss then
		logger.error("SecretLibrary/Gorzindel: technical abort - Gorzindel failed to spawn")
		return false
	end

	local knowledgeSpots = {
		{ name = "stolen knowledge of armor", pos = Position(32687, 32707, 10) },
		{ name = "stolen knowledge of summoning", pos = Position(32698, 32715, 10) },
		{ name = "stolen knowledge of lifesteal", pos = Position(32693, 32729, 10) },
		{ name = "stolen knowledge of spells", pos = Position(32681, 32729, 10) },
		{ name = "stolen knowledge of healing", pos = Position(32676, 32715, 10) },
	}
	local knowledgeMonsters = {}
	for _, spot in pairs(knowledgeSpots) do
		local monster = Game.createMonster(spot.name, spot.pos, false, true)
		if not monster then
			logger.error("SecretLibrary/Gorzindel: technical abort - {} failed to spawn", spot.name)
			boss:remove()
			for _, spawned in pairs(knowledgeMonsters) do
				spawned:remove()
			end
			return false
		end
		table.insert(knowledgeMonsters, monster)
	end

	local tome = Game.createMonster("stolen tome of portals", Position(32688, 32715, 10), false, true)
	if not tome then
		logger.error("SecretLibrary/Gorzindel: technical abort - Stolen Tome of Portals failed to spawn")
		boss:remove()
		for _, spawned in pairs(knowledgeMonsters) do
			spawned:remove()
		end
		return false
	end

	GorzindelRun.token = GorzindelRun.token + 1
	local token = GorzindelRun.token
	GorzindelRun.active = true
	GorzindelRun.bossId = boss:getId()
	GorzindelRun.tomeId = tome:getId()
	GorzindelRun.knowledgeIds = {}
	for _, monster in pairs(knowledgeMonsters) do
		GorzindelRun.knowledgeIds[monster:getId()] = true
	end
	GorzindelRun.knowledgeRemaining = #knowledgeMonsters
	GorzindelRun.participants = {}
	GorzindelRun.events = {}

	if lastInfoPositions then
		for _, posInfo in pairs(lastInfoPositions) do
			local player = posInfo.creature
			if player and player:isPlayer() then
				GorzindelRun.participants[player:getId()] = true
			end
		end
	end

	-- Ambient minions - ownership not tracked, they are flavour adds cleaned up generically by
	-- BossLever's own zone:removeMonsters() on any terminal path.
	local minionSpots = {
		{ name = "mean minion", pos = Position(32687, 32717, 10) },
		{ name = "malicious minion", pos = Position(32687, 32720, 10) },
		{ name = "malicious minion", pos = Position(32687, 32708, 10) },
		{ name = "malicious minion", pos = Position(32698, 32716, 10) },
		{ name = "malicious minion", pos = Position(32693, 32730, 10) },
		{ name = "malicious minion", pos = Position(32681, 32730, 10) },
		{ name = "malicious minion", pos = Position(32676, 32716, 10) },
	}
	for _, spot in pairs(minionSpots) do
		Game.createMonster(spot.name, spot.pos, false, true)
	end

	GorzindelRunTrackEvent(
		token,
		addEvent(function()
			GorzindelRunTerminate(token, "normal_timeout", "encounter time limit exceeded")
		end, 17 * 60 * 1000)
	)
	GorzindelRunTrackEvent(token, addEvent(watchEmptyRoom, 20 * 1000, token))

	return true
end

local config = {
	boss = {
		name = "Gorzindel",
		createFunction = createGorzindelEncounter,
	},
	requiredLevel = 250,
	timeToDefeat = 17 * 60,
	playerPositions = {
		{ pos = Position(32747, 32749, 10), teleport = Position(32686, 32721, 10), effect = CONST_ME_TELEPORT },
		{ pos = Position(32748, 32749, 10), teleport = Position(32686, 32721, 10), effect = CONST_ME_TELEPORT },
		{ pos = Position(32749, 32749, 10), teleport = Position(32686, 32721, 10), effect = CONST_ME_TELEPORT },
		{ pos = Position(32750, 32749, 10), teleport = Position(32686, 32721, 10), effect = CONST_ME_TELEPORT },
		{ pos = Position(32751, 32749, 10), teleport = Position(32686, 32721, 10), effect = CONST_ME_TELEPORT },
	},
	specPos = {
		from = Position(32680, 32711, 10),
		to = Position(32695, 32726, 10),
	},
	exit = EXIT_POSITION,
	onUseExtra = function(player, infoPositions)
		lastInfoPositions = infoPositions
		return validateParticipant(player)
	end,
}

local lever = BossLever(config)
lever:position(Position(32746, 32749, 10))
lever:register()
