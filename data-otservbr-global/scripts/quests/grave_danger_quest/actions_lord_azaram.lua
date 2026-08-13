-- ================================================================
-- LORD AZARAM RUN OWNERSHIP (executor contract, section 9; correction pass section A/F/N/O)
-- ================================================================
AzaramRun = {
	token = 0,
	active = false,
	bossId = nil, -- the one Lord Azaram instance this run owns
	soulId = nil, -- the one Azaram's Soul instance this run owns
	participants = {}, -- set: playerId -> true
	timerWritten = {}, -- set: playerId -> true (this attempt wrote Bosses.LordAzaram.Timer for them)
	monsters = {}, -- set: creatureId -> true (splinters/Condensed Sin adds owned by this attempt)
	events = {}, -- set: eventId -> true
}

function AzaramRunIsCurrent(token)
	return token ~= nil and token > 0 and AzaramRun.active and AzaramRun.token == token
end

function AzaramRunCurrentToken()
	if AzaramRun.active then
		return AzaramRun.token
	end
	return nil
end

function AzaramRunOwnsMonster(creature)
	return creature ~= nil and AzaramRun.active and AzaramRun.monsters[creature:getId()] == true
end

-- CORRECTION (section B): the exact boss identity check used by grave_danger_death to require actual
-- run ownership before crediting Lord Azaram's grave/boss kill.
function AzaramRunOwnsBoss(creature)
	return creature ~= nil and AzaramRun.active and AzaramRun.bossId == creature:getId()
end

function AzaramRunOwnsSoul(creature)
	return creature ~= nil and AzaramRun.active and AzaramRun.soulId == creature:getId()
end

function AzaramRunIsParticipant(token, playerId)
	return AzaramRunIsCurrent(token) and AzaramRun.participants[playerId] == true
end

function AzaramRunTrackMonster(monster)
	if monster and AzaramRun.active then
		AzaramRun.monsters[monster:getId()] = true
	end
end

function AzaramRunTrackEvent(token, eventId)
	if AzaramRunIsCurrent(token) and eventId then
		AzaramRun.events[eventId] = true
	end
end

-- CORRECTION (section O): records that THIS attempt wrote the legacy Bosses.LordAzaram.Timer lockout
-- for this player.
function AzaramRunMarkTimerWritten(token, playerId)
	if AzaramRunIsCurrent(token) then
		AzaramRun.timerWritten[playerId] = true
	end
end

local EXIT_POSITION = Position(32192, 31819, 8)

function AzaramRunTerminate(token, kind, reason)
	if not AzaramRunIsCurrent(token) then
		return
	end
	logger.info("GraveDanger/LordAzaram: run {} terminated ({}) - {}", token, kind, reason or "")
	AzaramRun.active = false

	for eventId in pairs(AzaramRun.events) do
		stopEvent(eventId)
	end

	if kind == "technical_abort" then
		for playerId in pairs(AzaramRun.participants) do
			local player = Player(playerId)
			if player then
				player:setBossCooldown("lord azaram", 0)
				if AzaramRun.timerWritten[playerId] then
					player:setStorageValue(Storage.Quest.U12_20.GraveDanger.Bosses.LordAzaram.Timer, 0)
				end
			end
		end
	end

	-- CORRECTION (lifecycle closure pass section A): success cleanup belongs entirely to
	-- BossLeverOnDeath (registered on this boss's own monster.events) - see the matching comment in
	-- actions_count_vlarkorth_.lua for the full race-condition rationale. Only technical_abort/
	-- normal_timeout close BossLever's own internal state here.
	if kind ~= "success" then
		for monsterId in pairs(AzaramRun.monsters) do
			local monster = Creature(monsterId)
			if monster then
				monster:remove()
			end
		end

		-- CORRECTION (section N, refined by lifecycle closure pass section A): closes out BossLever's
		-- own internal state via a local reference. Order matches BossLever's own generic timeout
		-- callback exactly (refresh, then remove players, then clean) so a normal_timeout racing ahead
		-- of and cancelling BossLever's own timeoutEvent cannot leave players stranded in an
		-- already-cleaned room.
		local bossLever = BossLever["lord azaram"]
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

	AzaramRun.bossId = nil
	AzaramRun.soulId = nil
	AzaramRun.participants = {}
	AzaramRun.timerWritten = {}
	AzaramRun.monsters = {}
	AzaramRun.events = {}
end

-- CORRECTION (section F): Lord Azaram previously had no phase timeout of its own, so a timed-out or
-- emptied attempt left AzaramRun.active stuck true forever, permanently blocking every future Lord
-- Azaram attempt. Mirrors the Count Vlarkorth fix: a flat deadline at the shared BOSS_DEFAULT_TIME_TO_
-- DEFEAT (no custom timeToDefeat is set below) plus a 20-second empty-room poll.
local function watchEmptyRoom(token)
	if not AzaramRunIsCurrent(token) then
		return
	end
	local zone = Zone("boss." .. toKey("lord azaram"))
	if zone and zone:countPlayers() == 0 then
		AzaramRunTerminate(token, "normal_timeout", "room emptied before the encounter concluded")
		return
	end
	AzaramRunTrackEvent(token, addEvent(watchEmptyRoom, 20 * 1000, token))
end

-- CORRECTION (section A): the lever now independently verifies Premium and that the Lich line has
-- actually been started for every occupied platform position.
local function validateParticipant(creature)
	if not creature or not creature:isPlayer() then
		return true
	end
	if not creature:isPremium() then
		creature:sendTextMessage(MESSAGE_EVENT_ADVANCE, "You need a premium account to face Lord Azaram.")
		return false
	end
	if creature:getStorageValue(Storage.Quest.U12_20.GraveDanger.Questline) < 1 then
		creature:sendTextMessage(MESSAGE_EVENT_ADVANCE, "You have not yet started this quest.")
		return false
	end
	return true
end

-- Snapshot of the most recent onUseExtra call's infoPositions, consumed synchronously by
-- createAzaramEncounter() moments later in the same synchronous BossLever:onUse() call.
local lastInfoPositions = nil

-- Proven position already used elsewhere in this quest for Azaram's Soul (creaturescripts_lord_
-- azaram.lua's config.soulPos - the position the Soul is teleported to mid-fight; also its correct
-- spawn point, since it sits inside the boss room and is not itself part of the fight until then).
local SOUL_POSITION = Position(33426, 31471, 13)

-- CORRECTION (executor contract, section 9; correction pass section F): mirrors the Count Vlarkorth
-- fix - created via config.boss.createFunction (invoked after Zone:removeMonsters()) so the boss's own
-- mandatory creation is verified before the lever commits cooldown/teleport. Azaram's Soul is now ALSO
-- created here (not assumed to be a surviving static placement - BossLever's own zone:removeMonsters()
-- runs immediately before this function and would have removed any pre-placed Soul) and is a mandatory
-- phase entity: if it cannot be verified, the whole encounter fails to start.
local function createAzaramEncounter()
	if AzaramRun.active then
		logger.error("GraveDanger/LordAzaram: a run is already active, refusing a second concurrent start")
		return false
	end

	local boss = Game.createMonster("Lord Azaram", Position(33424, 31473, 13), false, true)
	if not boss then
		logger.error("GraveDanger/LordAzaram: technical abort - Lord Azaram failed to spawn")
		return false
	end

	local soul = Game.createMonster("Azaram's Soul", SOUL_POSITION, false, true)
	if not soul then
		logger.error("GraveDanger/LordAzaram: technical abort - Azaram's Soul failed to spawn")
		boss:remove()
		return false
	end

	AzaramRun.token = AzaramRun.token + 1
	local token = AzaramRun.token
	AzaramRun.active = true
	AzaramRun.bossId = boss:getId()
	AzaramRun.soulId = soul:getId()
	AzaramRun.participants = {}
	AzaramRun.timerWritten = {}
	AzaramRun.monsters = {}
	AzaramRun.events = {}

	if lastInfoPositions then
		for _, posInfo in pairs(lastInfoPositions) do
			local player = posInfo.creature
			if player and player:isPlayer() then
				AzaramRun.participants[player:getId()] = true
			end
		end
	end

	AzaramRunTrackMonster(boss)
	AzaramRunTrackMonster(soul)
	AzaramRunTrackEvent(
		token,
		addEvent(function()
			AzaramRunTerminate(token, "normal_timeout", "encounter time limit exceeded")
		end, configManager.getNumber(configKeys.BOSS_DEFAULT_TIME_TO_DEFEAT) * 1000)
	)
	AzaramRunTrackEvent(token, addEvent(watchEmptyRoom, 20 * 1000, token))
	return true
end

local config = {
	boss = {
		name = "Lord Azaram",
		createFunction = createAzaramEncounter,
	},
	requiredLevel = 250,
	playerPositions = {
		{ pos = Position(33422, 31493, 13), teleport = Position(33423, 31465, 13), effect = CONST_ME_TELEPORT },
		{ pos = Position(33423, 31493, 13), teleport = Position(33423, 31465, 13), effect = CONST_ME_TELEPORT },
		{ pos = Position(33424, 31493, 13), teleport = Position(33423, 31465, 13), effect = CONST_ME_TELEPORT },
		{ pos = Position(33425, 31493, 13), teleport = Position(33423, 31465, 13), effect = CONST_ME_TELEPORT },
		{ pos = Position(33426, 31493, 13), teleport = Position(33423, 31465, 13), effect = CONST_ME_TELEPORT },
	},
	specPos = {
		from = Position(33416, 31463, 13),
		to = Position(33432, 31481, 13),
	},
	exit = EXIT_POSITION,
	onUseExtra = function(creature, infoPositions)
		lastInfoPositions = infoPositions
		return validateParticipant(creature)
	end,
}

local lever = BossLever(config)
lever:position(Position(33421, 31493, 13))
lever:register()
