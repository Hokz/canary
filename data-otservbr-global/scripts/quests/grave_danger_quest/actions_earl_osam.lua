-- ================================================================
-- EARL OSAM RUN OWNERSHIP (correction pass section A/G/N/O)
-- ================================================================
-- Confirmed pre-existing gap: Earl Osam had no run/token object at all before this pass - every
-- sphere-movement/decrement callback in creaturescripts_earl_osam.lua trusted a bare `Creature("Earl
-- Osam")` name lookup and the boss's own storage(4) "generation" counter alone, with nothing verifying
-- those callbacks belonged to a still-current attempt, and no participant roster for grave_danger_
-- death to check against.
EarlOsamRun = {
	token = 0,
	active = false,
	bossId = nil, -- the one Earl Osam instance this run owns
	participants = {}, -- set: playerId -> true
	timerWritten = {}, -- set: playerId -> true (this attempt wrote Bosses.EarlOsam.Timer for them)
	monsters = {}, -- set: creatureId -> true (Magical Spheres owned by this attempt)
	events = {}, -- set: eventId -> true
}

function EarlOsamRunIsCurrent(token)
	return token ~= nil and token > 0 and EarlOsamRun.active and EarlOsamRun.token == token
end

function EarlOsamRunCurrentToken()
	if EarlOsamRun.active then
		return EarlOsamRun.token
	end
	return nil
end

function EarlOsamRunOwnsMonster(creature)
	return creature ~= nil and EarlOsamRun.active and EarlOsamRun.monsters[creature:getId()] == true
end

-- CORRECTION (section B): the exact boss identity check used by grave_danger_death to require actual
-- run ownership before crediting Earl Osam's grave/boss kill.
function EarlOsamRunOwnsBoss(creature)
	return creature ~= nil and EarlOsamRun.active and EarlOsamRun.bossId == creature:getId()
end

function EarlOsamRunIsParticipant(token, playerId)
	return EarlOsamRunIsCurrent(token) and EarlOsamRun.participants[playerId] == true
end

function EarlOsamRunTrackMonster(monster)
	if monster and EarlOsamRun.active then
		EarlOsamRun.monsters[monster:getId()] = true
	end
end

-- CORRECTION (lifecycle closure pass section D): called once a tracked Magical Sphere reaches Earl,
-- dies, or is otherwise resolved, so its id no longer lingers in the owned set.
function EarlOsamRunUntrackMonster(creatureId)
	EarlOsamRun.monsters[creatureId] = nil
end

function EarlOsamRunTrackEvent(token, eventId)
	if EarlOsamRunIsCurrent(token) and eventId then
		EarlOsamRun.events[eventId] = true
	end
end

-- CORRECTION (section O): records that THIS attempt wrote the legacy Bosses.EarlOsam.Timer lockout
-- for this player.
function EarlOsamRunMarkTimerWritten(token, playerId)
	if EarlOsamRunIsCurrent(token) then
		EarlOsamRun.timerWritten[playerId] = true
	end
end

local EXIT_POSITION = Position(33261, 31986, 8)

function EarlOsamRunTerminate(token, kind, reason)
	if not EarlOsamRunIsCurrent(token) then
		return
	end
	logger.info("GraveDanger/EarlOsam: run {} terminated ({}) - {}", token, kind, reason or "")
	EarlOsamRun.active = false

	for eventId in pairs(EarlOsamRun.events) do
		stopEvent(eventId)
	end

	if kind == "technical_abort" then
		for playerId in pairs(EarlOsamRun.participants) do
			local player = Player(playerId)
			if player then
				player:setBossCooldown("earl osam", 0)
				if EarlOsamRun.timerWritten[playerId] then
					player:setStorageValue(Storage.Quest.U12_20.GraveDanger.Bosses.EarlOsam.Timer, 0)
				end
			end
		end
	end

	-- CORRECTION (lifecycle closure pass section A): success cleanup belongs entirely to
	-- BossLeverOnDeath (registered on this boss's own monster.events) - see the matching comment in
	-- actions_count_vlarkorth_.lua for the full race-condition rationale.
	if kind ~= "success" then
		for monsterId in pairs(EarlOsamRun.monsters) do
			local monster = Creature(monsterId)
			if monster then
				monster:remove()
			end
		end
		-- The boss itself is only forced away on a technical abort; a legitimate kill needs no corpse
		-- cleanup, and a normal_timeout leaves him to the framework's own generic room reset.
		local boss = Creature(EarlOsamRun.bossId)
		if boss and kind == "technical_abort" then
			boss:remove()
		end

		-- CORRECTION (section N, refined by lifecycle closure pass section A): closes out BossLever's
		-- own internal state via a local reference. Order matches BossLever's own generic timeout
		-- callback exactly (refresh, then remove players, then clean) so a normal_timeout racing ahead
		-- of and cancelling BossLever's own timeoutEvent cannot leave players stranded in an
		-- already-cleaned room.
		local bossLever = BossLever["earl osam"]
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

	EarlOsamRun.bossId = nil
	EarlOsamRun.participants = {}
	EarlOsamRun.timerWritten = {}
	EarlOsamRun.monsters = {}
	EarlOsamRun.events = {}
end

-- CORRECTION (section G): mirrors the Count Vlarkorth/Lord Azaram fix - a timed-out or emptied
-- attempt previously left nothing to ever clear an equivalent run object (none existed at all), which
-- would have permanently blocked every future Earl Osam attempt the moment one was added. A flat
-- deadline at the shared BOSS_DEFAULT_TIME_TO_DEFEAT (no custom timeToDefeat is set below) plus a
-- 20-second empty-room poll.
local function watchEmptyRoom(token)
	if not EarlOsamRunIsCurrent(token) then
		return
	end
	local zone = Zone("boss." .. toKey("earl osam"))
	if zone and zone:countPlayers() == 0 then
		EarlOsamRunTerminate(token, "normal_timeout", "room emptied before the encounter concluded")
		return
	end
	EarlOsamRunTrackEvent(token, addEvent(watchEmptyRoom, 20 * 1000, token))
end

-- CORRECTION (section A): the lever now independently verifies Premium and that the Lich line has
-- actually been started for every occupied platform position.
local function validateParticipant(creature)
	if not creature or not creature:isPlayer() then
		return true
	end
	if not creature:isPremium() then
		creature:sendTextMessage(MESSAGE_EVENT_ADVANCE, "You need a premium account to face Earl Osam.")
		return false
	end
	if creature:getStorageValue(Storage.Quest.U12_20.GraveDanger.Questline) < 1 then
		creature:sendTextMessage(MESSAGE_EVENT_ADVANCE, "You have not yet started this quest.")
		return false
	end
	return true
end

-- Snapshot of the most recent onUseExtra call's infoPositions, consumed synchronously by
-- createEarlOsamEncounter() moments later in the same synchronous BossLever:onUse() call.
local lastInfoPositions = nil

-- CORRECTION (section G): converted from the generic unverified self.bossPosition path to
-- config.boss.createFunction, matching the pattern already applied to every other Lich boss in this
-- quest, so the mandatory boss creation is verified before the lever commits cooldown/teleport and so
-- this run's own token/participant/bossId state exists from the moment the fight starts.
local function createEarlOsamEncounter()
	if EarlOsamRun.active then
		logger.error("GraveDanger/EarlOsam: a run is already active, refusing a second concurrent start")
		return false
	end

	local boss = Game.createMonster("Earl Osam", Position(33488, 31441, 13), false, true)
	if not boss then
		logger.error("GraveDanger/EarlOsam: technical abort - Earl Osam failed to spawn")
		return false
	end

	EarlOsamRun.token = EarlOsamRun.token + 1
	local token = EarlOsamRun.token
	EarlOsamRun.active = true
	EarlOsamRun.bossId = boss:getId()
	EarlOsamRun.participants = {}
	EarlOsamRun.timerWritten = {}
	EarlOsamRun.monsters = {}
	EarlOsamRun.events = {}

	if lastInfoPositions then
		for _, posInfo in pairs(lastInfoPositions) do
			local player = posInfo.creature
			if player and player:isPlayer() then
				EarlOsamRun.participants[player:getId()] = true
			end
		end
	end

	EarlOsamRunTrackMonster(boss)
	EarlOsamRunTrackEvent(
		token,
		addEvent(function()
			EarlOsamRunTerminate(token, "normal_timeout", "encounter time limit exceeded")
		end, configManager.getNumber(configKeys.BOSS_DEFAULT_TIME_TO_DEFEAT) * 1000)
	)
	EarlOsamRunTrackEvent(token, addEvent(watchEmptyRoom, 20 * 1000, token))
	return true
end

local config = {
	boss = {
		name = "Earl Osam",
		-- No `position` field: created transactionally by createFunction above.
		createFunction = createEarlOsamEncounter,
	},
	requiredLevel = 250,
	playerPositions = {
		{ pos = Position(33516, 31444, 13), teleport = Position(33488, 31430, 13), effect = CONST_ME_TELEPORT },
		{ pos = Position(33517, 31444, 13), teleport = Position(33488, 31430, 13), effect = CONST_ME_TELEPORT },
		{ pos = Position(33518, 31444, 13), teleport = Position(33488, 31430, 13), effect = CONST_ME_TELEPORT },
		{ pos = Position(33519, 31444, 13), teleport = Position(33488, 31430, 13), effect = CONST_ME_TELEPORT },
		{ pos = Position(33520, 31444, 13), teleport = Position(33488, 31430, 13), effect = CONST_ME_TELEPORT },
	},
	specPos = {
		from = Position(33479, 31429, 13),
		to = Position(33497, 31446, 13),
	},
	exit = EXIT_POSITION,
	onUseExtra = function(creature, infoPositions)
		lastInfoPositions = infoPositions
		return validateParticipant(creature)
	end,
}

local lever = BossLever(config)
lever:position(Position(33515, 31444, 13))
lever:register()
