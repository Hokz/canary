-- ================================================================
-- GRAND MASTER OBERON RUN OWNERSHIP (Secret Library repair v2, section 9)
-- ================================================================
-- Confirmed pre-existing bug: createFunction chained :setStorageValue(...) directly onto
-- Game.createMonster(...)'s return value with no nil check - a failed spawn (blocked tile, etc.)
-- would error indexing nil. No run/token/attempt object existed at all; state was implicit (bare
-- Game.createMonster + the generic BossLever cooldown/zone machinery only). The lever's own config
-- also never set requiredLevel, so it silently defaulted to 0 (boss_lever.lua: `requiredLevel =
-- config.requiredLevel or 0`) - no meaningful level gate existed despite the quest's own 250/Premium
-- requirement.
OberonRun = {
	token = 0,
	active = false,
	bossId = nil, -- the one Grand Master Oberon instance this run owns
	participants = {}, -- set: playerId -> true
	events = {}, -- set: eventId -> true
}

function OberonRunIsCurrent(token)
	return token ~= nil and token > 0 and OberonRun.active and OberonRun.token == token
end

function OberonRunCurrentToken()
	if OberonRun.active then
		return OberonRun.token
	end
	return nil
end

function OberonRunOwnsBoss(creature)
	return creature ~= nil and OberonRun.active and OberonRun.bossId == creature:getId()
end

function OberonRunIsParticipant(token, playerId)
	return OberonRunIsCurrent(token) and OberonRun.participants[playerId] == true
end

function OberonRunTrackEvent(token, eventId)
	if OberonRunIsCurrent(token) and eventId then
		OberonRun.events[eventId] = true
	end
end

local EXIT_POSITION = Position(33297, 31285, 9)

-- Single terminal lifecycle path (mirrors the Grave Danger *RunTerminate precedent accepted in this
-- project). kind is one of "technical_abort", "normal_timeout", "success". Success cleanup is left
-- entirely to BossLeverOnDeath (registered directly on Oberon below, since custom createFunction
-- bosses never go through boss_lever.lua's generic monster:registerEvent("BossLeverOnDeath") path) -
-- this terminator must not race ahead of it and close BossLever's own bossAlive/timeoutEvent/
-- emptyRoomEvent/zone state on success, only on the two non-success paths.
function OberonRunTerminate(token, kind, reason)
	if not OberonRunIsCurrent(token) then
		return
	end
	logger.info("SecretLibrary/Oberon: run {} terminated ({}) - {}", token, kind, reason or "")

	OberonRun.active = false
	for eventId in pairs(OberonRun.events) do
		stopEvent(eventId)
	end

	if kind == "technical_abort" then
		for playerId in pairs(OberonRun.participants) do
			local player = Player(playerId)
			if player then
				player:setBossCooldown("grand master oberon", 0)
			end
		end
	end

	if kind ~= "success" then
		local boss = Creature(OberonRun.bossId)
		if boss then
			boss:remove()
		end

		local bossLever = BossLever["grand master oberon"]
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

	OberonRun.bossId = nil
	OberonRun.participants = {}
	OberonRun.events = {}
end

-- A timed-out or emptied attempt previously left no run object to get stuck at all (state was purely
-- implicit) - but a fresh createFunction guard (below) needs SOMETHING to know an attempt is already
-- in progress. This watchdog closes it out cleanly: a flat deadline at the shared
-- BOSS_DEFAULT_TIME_TO_DEFEAT (no custom timeToDefeat is set below) plus a 20-second empty-room poll,
-- matching the convention already established for every run-owned encounter in this project.
local function watchEmptyRoom(token)
	if not OberonRunIsCurrent(token) then
		return
	end
	local zone = Zone("boss." .. toKey("grand master oberon"))
	if zone and zone:countPlayers() == 0 then
		OberonRunTerminate(token, "normal_timeout", "room emptied before the encounter concluded")
		return
	end
	OberonRunTrackEvent(token, addEvent(watchEmptyRoom, 20 * 1000, token))
end

-- CORRECTION (section 9): every accepted participant must independently satisfy level 250, Premium,
-- and legitimate Falcon progression immediately prior to Oberon (KillingBosses >= 5, i.e. Dazed Leaf
-- Golem already defeated) - none of this was previously checked at the lever at all.
local function validateParticipant(creature)
	if not creature or not creature:isPlayer() then
		return true
	end
	if creature:getLevel() < 250 then
		creature:sendTextMessage(MESSAGE_EVENT_ADVANCE, "All players need to be level 250 or higher.")
		return false
	end
	if not creature:isPremium() then
		creature:sendTextMessage(MESSAGE_EVENT_ADVANCE, "You need a premium account to face Grand Master Oberon.")
		return false
	end
	if creature:getStorageValue(Storage.Quest.U11_80.TheSecretLibrary.FalconBastion.KillingBosses) < 5 then
		creature:sendTextMessage(MESSAGE_EVENT_ADVANCE, "You have not yet earned the right to challenge Grand Master Oberon.")
		return false
	end
	return true
end

-- Snapshot of the most recent onUseExtra call's infoPositions, consumed synchronously by
-- createOberonEncounter() moments later in the same synchronous BossLever:onUse() call.
local lastInfoPositions = nil

-- CORRECTION (section 9): validate -> create/verify Oberon -> commit run state, replacing the
-- previous bare Game.createMonster(...):setStorageValue(...) chain (a nil spawn would have errored
-- indexing nil). Registers BossLeverOnDeath directly (see the note on OberonRunTerminate above).
local function createOberonEncounter()
	if OberonRun.active then
		logger.error("SecretLibrary/Oberon: a run is already active, refusing a second concurrent start")
		return false
	end

	local boss = Game.createMonster("Grand Master Oberon", Position(33365, 31318, 9), true, true)
	if not boss then
		logger.error("SecretLibrary/Oberon: technical abort - Grand Master Oberon failed to spawn")
		return false
	end
	boss:setStorageValue(Storage.Quest.U11_80.TheSecretLibrary.FalconBastion.OberonHeal, 0)
	boss:registerEvent("BossLeverOnDeath")

	OberonRun.token = OberonRun.token + 1
	local token = OberonRun.token
	OberonRun.active = true
	OberonRun.bossId = boss:getId()
	OberonRun.participants = {}
	OberonRun.events = {}

	if lastInfoPositions then
		for _, posInfo in pairs(lastInfoPositions) do
			local player = posInfo.creature
			if player and player:isPlayer() then
				OberonRun.participants[player:getId()] = true
			end
		end
	end

	OberonRunTrackEvent(
		token,
		addEvent(function()
			OberonRunTerminate(token, "normal_timeout", "encounter time limit exceeded")
		end, configManager.getNumber(configKeys.BOSS_DEFAULT_TIME_TO_DEFEAT) * 1000)
	)
	OberonRunTrackEvent(token, addEvent(watchEmptyRoom, 20 * 1000, token))

	return true
end

local config = {
	boss = {
		name = "Grand Master Oberon",
		createFunction = createOberonEncounter,
	},
	requiredLevel = 250,
	timeToFightAgain = 20 * 60 * 60,
	playerPositions = {
		{ pos = Position(33364, 31344, 9), teleport = Position(33364, 31322, 9) },
		{ pos = Position(33362, 31344, 9), teleport = Position(33364, 31322, 9) },
		{ pos = Position(33363, 31344, 9), teleport = Position(33364, 31322, 9) },
		{ pos = Position(33365, 31344, 9), teleport = Position(33364, 31322, 9) },
		{ pos = Position(33366, 31344, 9), teleport = Position(33364, 31322, 9) },
	},
	specPos = {
		from = Position(33356, 31311, 9),
		to = Position(33376, 31328, 9),
	},
	exit = EXIT_POSITION,
	onUseExtra = function(player, infoPositions)
		lastInfoPositions = infoPositions
		return validateParticipant(player)
	end,
}

local leverOberon = BossLever(config)
leverOberon:aid(57605)
leverOberon:register()
