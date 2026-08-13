-- ================================================================
-- LORD AZARAM RUN OWNERSHIP (executor contract, section 9)
-- ================================================================
AzaramRun = {
	token = 0,
	active = false,
	monsters = {}, -- set: creatureId -> true
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

function AzaramRunTrackMonster(monster)
	if monster and AzaramRun.active then
		AzaramRun.monsters[monster:getId()] = true
	end
end

function AzaramRunTerminate(token, kind, reason)
	if not AzaramRunIsCurrent(token) then
		return
	end
	logger.info("GraveDanger/LordAzaram: run {} terminated ({}) - {}", token, kind, reason or "")
	AzaramRun.active = false
	if kind == "technical_abort" then
		for monsterId in pairs(AzaramRun.monsters) do
			local monster = Creature(monsterId)
			if monster then
				monster:remove()
			end
		end
	end
	AzaramRun.monsters = {}
end

-- CORRECTION (executor contract, section 9): mirrors the Count Vlarkorth / King Zelos fix - created
-- via config.boss.createFunction (invoked after Zone:removeMonsters()) so the boss's own mandatory
-- creation is verified before the lever commits cooldown/teleport.
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

	AzaramRun.token = AzaramRun.token + 1
	AzaramRun.active = true
	AzaramRun.monsters = {}
	AzaramRunTrackMonster(boss)
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
	exit = Position(32192, 31819, 8),
}

local lever = BossLever(config)
lever:position(Position(33421, 31493, 13))
lever:register()
