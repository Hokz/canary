-- ================================================================
-- COUNT VLARKORTH RUN OWNERSHIP (executor contract, section 8)
-- ================================================================
-- Bare global (no `local`), matching the King Zelos / HOD HODFinalRun precedent already accepted in
-- this engagement, so creaturescripts_count_vlarkorth.lua and actions_dark_remains.lua can read/
-- mutate it directly while every cross-file mutation goes through the token-checked helpers below.
VlarkorthRun = {
	token = 0,
	active = false,
	participants = {}, -- set: playerId -> true
	monsters = {}, -- set: creatureId -> true (dark summons owned by this attempt)
	events = {}, -- set: eventId -> true
}

function VlarkorthRunIsCurrent(token)
	return token ~= nil and token > 0 and VlarkorthRun.active and VlarkorthRun.token == token
end

function VlarkorthRunCurrentToken()
	if VlarkorthRun.active then
		return VlarkorthRun.token
	end
	return nil
end

function VlarkorthRunOwnsMonster(creature)
	return creature ~= nil and VlarkorthRun.active and VlarkorthRun.monsters[creature:getId()] == true
end

function VlarkorthRunTrackMonster(monster)
	if monster and VlarkorthRun.active then
		VlarkorthRun.monsters[monster:getId()] = true
	end
end

function VlarkorthRunTrackEvent(token, eventId)
	if VlarkorthRunIsCurrent(token) and eventId then
		VlarkorthRun.events[eventId] = true
	end
end

-- kind is one of "technical_abort" or "success" - Count Vlarkorth has no external phase timeout of
-- its own beyond BossLever's generic room timer, so "normal_timeout" is not a distinct path here.
function VlarkorthRunTerminate(token, kind, reason)
	if not VlarkorthRunIsCurrent(token) then
		return
	end
	logger.info("GraveDanger/CountVlarkorth: run {} terminated ({}) - {}", token, kind, reason or "")

	VlarkorthRun.active = false

	for eventId in pairs(VlarkorthRun.events) do
		stopEvent(eventId)
	end

	if kind == "technical_abort" then
		for playerId in pairs(VlarkorthRun.participants) do
			local player = Player(playerId)
			if player then
				player:setBossCooldown("count vlarkorth", 0)
			end
		end
		for monsterId in pairs(VlarkorthRun.monsters) do
			local monster = Creature(monsterId)
			if monster then
				monster:remove()
			end
		end
	end

	VlarkorthRun.participants = {}
	VlarkorthRun.monsters = {}
	VlarkorthRun.events = {}
end

-- Snapshot of the most recent onUseExtra call's infoPositions, consumed synchronously by
-- createVlarkorthEncounter() moments later in the same synchronous BossLever:onUse() call.
local lastInfoPositions = nil

-- CORRECTION (executor contract, section 8): mirrors the King Zelos fix - Count Vlarkorth is now
-- created via config.boss.createFunction (invoked by boss_lever.lua AFTER Zone:removeMonsters(),
-- unlike onUseExtra which runs during Lever:checkConditions() and would have its creation undone by
-- that same removeMonsters() call moments later) so the mandatory boss creation is verified before
-- Lever:teleportPlayers()/setCooldownAllPlayers() ever commit.
local function createVlarkorthEncounter()
	if VlarkorthRun.active then
		logger.error("GraveDanger/CountVlarkorth: a run is already active, refusing a second concurrent start")
		return false
	end

	local boss = Game.createMonster("Count Vlarkorth", Position(33456, 31434, 13), false, true)
	if not boss then
		logger.error("GraveDanger/CountVlarkorth: technical abort - Count Vlarkorth failed to spawn")
		return false
	end

	VlarkorthRun.token = VlarkorthRun.token + 1
	VlarkorthRun.active = true
	VlarkorthRun.participants = {}
	VlarkorthRun.monsters = {}
	VlarkorthRun.events = {}

	if lastInfoPositions then
		for _, posInfo in pairs(lastInfoPositions) do
			local player = posInfo.creature
			if player and player:isPlayer() then
				VlarkorthRun.participants[player:getId()] = true
			end
		end
	end

	VlarkorthRunTrackMonster(boss)
	return true
end

local config = {
	boss = {
		name = "Count Vlarkorth",
		-- No `position` field: created transactionally by createFunction above.
		createFunction = createVlarkorthEncounter,
	},
	requiredLevel = 250,
	playerPositions = {
		{ pos = Position(33455, 31413, 13), teleport = Position(33454, 31445, 13), effect = CONST_ME_TELEPORT },
		{ pos = Position(33456, 31413, 13), teleport = Position(33454, 31445, 13), effect = CONST_ME_TELEPORT },
		{ pos = Position(33457, 31413, 13), teleport = Position(33454, 31445, 13), effect = CONST_ME_TELEPORT },
		{ pos = Position(33458, 31413, 13), teleport = Position(33454, 31445, 13), effect = CONST_ME_TELEPORT },
		{ pos = Position(33459, 31413, 13), teleport = Position(33454, 31445, 13), effect = CONST_ME_TELEPORT },
	},
	specPos = {
		from = Position(33448, 31428, 13),
		to = Position(33464, 31446, 13),
	},
	exit = Position(33195, 31690, 8),
	onUseExtra = function(creature, infoPositions)
		lastInfoPositions = infoPositions
		return true
	end,
}

local lever = BossLever(config)
lever:position(Position(33454, 31413, 13))
lever:register()
