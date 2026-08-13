-- ================================================================
-- MAZZINOR RUN OWNERSHIP (Secret Library repair v2, section 16)
-- ================================================================
-- Confirmed pre-existing bug: "mazzinorHealth" (creaturescripts_mazzinor.lua) unconditionally zeroed
-- ALL incoming damage with no phase check at all - Mazzinor could never be damaged in any state. The
-- separate "Supercharged Mazzinor" monster type existed but was never referenced by any script - no
-- transform, no timing, no explosion damage existed anywhere for it.
MazzinorRun = {
	token = 0,
	active = false,
	bossId = nil, -- the one Mazzinor instance this run owns (its id is unchanged across the in-place
	-- setType transform to/from "Supercharged Mazzinor")
	participants = {}, -- set: playerId -> true
	phase = "normal", -- "normal" | "supercharged"
	chargeGeneration = 0,
	events = {}, -- set: eventId -> true
}

function MazzinorRunIsCurrent(token)
	return token ~= nil and token > 0 and MazzinorRun.active and MazzinorRun.token == token
end

function MazzinorRunCurrentToken()
	if MazzinorRun.active then
		return MazzinorRun.token
	end
	return nil
end

function MazzinorRunOwnsBoss(creature)
	return creature ~= nil and MazzinorRun.active and MazzinorRun.bossId == creature:getId()
end

function MazzinorRunIsParticipant(token, playerId)
	return MazzinorRunIsCurrent(token) and MazzinorRun.participants[playerId] == true
end

function MazzinorRunTrackEvent(token, eventId)
	if MazzinorRunIsCurrent(token) and eventId then
		MazzinorRun.events[eventId] = true
	end
end

local EXIT_POSITION = Position(32616, 32531, 13)
local CENTER_POSITION = Position(32725, 32719, 10)

function MazzinorRunTerminate(token, kind, reason)
	if not MazzinorRunIsCurrent(token) then
		return
	end
	logger.info("SecretLibrary/Mazzinor: run {} terminated ({}) - {}", token, kind, reason or "")

	MazzinorRun.active = false
	for eventId in pairs(MazzinorRun.events) do
		stopEvent(eventId)
	end

	if kind == "technical_abort" then
		for playerId in pairs(MazzinorRun.participants) do
			local player = Player(playerId)
			if player then
				player:setBossCooldown("mazzinor", 0)
			end
		end
	end

	if kind ~= "success" then
		local boss = Creature(MazzinorRun.bossId)
		if boss then
			boss:remove()
		end

		local bossLever = BossLever["mazzinor"]
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

	MazzinorRun.bossId = nil
	MazzinorRun.participants = {}
	MazzinorRun.phase = "normal"
	MazzinorRun.chargeGeneration = 0
	MazzinorRun.events = {}
end

local function watchEmptyRoom(token)
	if not MazzinorRunIsCurrent(token) then
		return
	end
	local zone = Zone("boss." .. toKey("mazzinor"))
	if zone and zone:countPlayers() == 0 then
		MazzinorRunTerminate(token, "normal_timeout", "room emptied before the encounter concluded")
		return
	end
	MazzinorRunTrackEvent(token, addEvent(watchEmptyRoom, 20 * 1000, token))
end

-- ================================================================
-- SUPERCHARGE CYCLE (Secret Library repair v2, section 16/16.1)
-- ================================================================
-- CUSTOM_GLOBAL_LIKE_PENDING_EXACT_TIMING: the owner reference gives the Supercharged duration itself
-- as exactly 8 seconds (used below, not marked as a guess), but does not give the interval BETWEEN
-- charge cycles - a stable functional interval is used for that instead.
local CHARGE_CYCLE_INTERVAL = 45 * 1000
local SUPERCHARGE_DURATION = 8 * 1000
local EXPLOSION_MIN, EXPLOSION_MAX = 5000, 8000
local KNOWLEDGE_ELEMENTAL_LOOKTYPE = 1065

local attemptSuperchargePhase
local scheduleChargeCheck

scheduleChargeCheck = function(token)
	MazzinorRunTrackEvent(token, addEvent(attemptSuperchargePhase, CHARGE_CYCLE_INTERVAL, token))
end

local function resolveSupercharge(token, generation)
	if not MazzinorRunIsCurrent(token) or MazzinorRun.chargeGeneration ~= generation then
		return
	end
	local boss = Creature(MazzinorRun.bossId)
	if boss and MazzinorRunOwnsBoss(boss) then
		local position = boss:getPosition()
		local spectators = Game.getSpectators(position, false, true, 8, 8, 8, 8)
		for _, player in pairs(spectators) do
			-- CORRECTION (section 16): a player currently under the Knowledge Elemental protection
			-- (matched by its exact lookType, set by movements_mazzinor.lua below) survives the
			-- explosion - this is the whole point of the vortex/transform mechanic. Everyone else
			-- takes the full owner-contract 5000-8000 room-wide hit.
			local outfit = player:getOutfit()
			if outfit.lookType ~= KNOWLEDGE_ELEMENTAL_LOOKTYPE then
				doTargetCombatHealth(0, player, COMBAT_ENERGYDAMAGE, -EXPLOSION_MIN, -EXPLOSION_MAX, CONST_ME_ENERGYAREA)
			end
		end
		boss:setType("Mazzinor")
		boss:immune(false)
	end
	MazzinorRun.phase = "normal"
	scheduleChargeCheck(token)
end

-- CORRECTION (section 16/39): validate -> commit supercharge phase -> schedule the exact-8-second
-- resolution, capturing token + this exact charge generation so a stale resolve callback from an
-- already-terminated run/superseded cycle can never fire against a newer one.
attemptSuperchargePhase = function(token)
	if not MazzinorRunIsCurrent(token) or MazzinorRun.phase ~= "normal" then
		return
	end
	local boss = Creature(MazzinorRun.bossId)
	if not boss or not MazzinorRunOwnsBoss(boss) or boss:getHealth() <= 0 then
		return
	end

	MazzinorRun.chargeGeneration = MazzinorRun.chargeGeneration + 1
	local generation = MazzinorRun.chargeGeneration
	MazzinorRun.phase = "supercharged"

	boss:setType("Supercharged Mazzinor")
	boss:immune(true)
	boss:say("MY POWER GROWS BEYOND MEASURE!", TALKTYPE_MONSTER_SAY)
	for _, spectator in pairs(Game.getSpectators(boss:getPosition(), false, true, 8, 8, 8, 8)) do
		spectator:sendTextMessage(MESSAGE_EVENT_ADVANCE, "Mazzinor is charging a devastating explosion - find protection!")
	end

	MazzinorRunTrackEvent(
		token,
		addEvent(function()
			resolveSupercharge(token, generation)
		end, SUPERCHARGE_DURATION)
	)
end

local function validateParticipant(creature)
	if not creature or not creature:isPlayer() then
		return true
	end
	if not creature:isPremium() then
		creature:sendTextMessage(MESSAGE_EVENT_ADVANCE, "You need a premium account to face Mazzinor.")
		return false
	end
	if creature:getStorageValue(Storage.Quest.U11_80.TheSecretLibrary.LibraryPermission) < 7 then
		creature:sendTextMessage(MESSAGE_EVENT_ADVANCE, "You have not yet been granted access to the Secret Library.")
		return false
	end
	return true
end

local lastInfoPositions = nil

local function createMazzinorEncounter()
	if MazzinorRun.active then
		logger.error("SecretLibrary/Mazzinor: a run is already active, refusing a second concurrent start")
		return false
	end

	local boss = Game.createMonster("Mazzinor", CENTER_POSITION, false, true)
	if not boss then
		logger.error("SecretLibrary/Mazzinor: technical abort - Mazzinor failed to spawn")
		return false
	end
	boss:registerEvent("BossLeverOnDeath")

	local wildKnowledgeSpots = {
		Position(32719, 32718, 10),
		Position(32723, 32719, 10),
		Position(32728, 32718, 10),
		Position(32724, 32724, 10),
	}
	for _, pos in pairs(wildKnowledgeSpots) do
		Game.createMonster("wild knowledge", pos, false, true)
	end

	MazzinorRun.token = MazzinorRun.token + 1
	local token = MazzinorRun.token
	MazzinorRun.active = true
	MazzinorRun.bossId = boss:getId()
	MazzinorRun.participants = {}
	MazzinorRun.phase = "normal"
	MazzinorRun.chargeGeneration = 0
	MazzinorRun.events = {}

	if lastInfoPositions then
		for _, posInfo in pairs(lastInfoPositions) do
			local player = posInfo.creature
			if player and player:isPlayer() then
				MazzinorRun.participants[player:getId()] = true
			end
		end
	end

	MazzinorRunTrackEvent(
		token,
		addEvent(function()
			MazzinorRunTerminate(token, "normal_timeout", "encounter time limit exceeded")
		end, 17 * 60 * 1000)
	)
	MazzinorRunTrackEvent(token, addEvent(watchEmptyRoom, 20 * 1000, token))
	scheduleChargeCheck(token)

	return true
end

local config = {
	boss = {
		name = "Mazzinor",
		createFunction = createMazzinorEncounter,
	},
	requiredLevel = 250,
	timeToDefeat = 17 * 60,
	playerPositions = {
		{ pos = Position(32721, 32773, 10), teleport = Position(32726, 32726, 10), effect = CONST_ME_TELEPORT },
		{ pos = Position(32722, 32773, 10), teleport = Position(32726, 32726, 10), effect = CONST_ME_TELEPORT },
		{ pos = Position(32723, 32773, 10), teleport = Position(32726, 32726, 10), effect = CONST_ME_TELEPORT },
		{ pos = Position(32724, 32773, 10), teleport = Position(32726, 32726, 10), effect = CONST_ME_TELEPORT },
		{ pos = Position(32725, 32773, 10), teleport = Position(32726, 32726, 10), effect = CONST_ME_TELEPORT },
	},
	specPos = {
		from = Position(32716, 32713, 10),
		to = Position(32732, 32728, 10),
	},
	exit = EXIT_POSITION,
	onUseExtra = function(player, infoPositions)
		lastInfoPositions = infoPositions
		return validateParticipant(player)
	end,
}

local lever = BossLever(config)
lever:position(Position(32720, 32773, 10))
lever:register()
