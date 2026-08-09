local config = {
	positions = {
		{ x = 33258, y = 31080, z = 8 },
		{ x = 33266, y = 31084, z = 8 },
		{ x = 33259, y = 31089, z = 8 },
		{ x = 33263, y = 31093, z = 8 },
	},
	stairPosition = Position(33265, 31116, 8),
	areaCenter = Position(33268, 31119, 7),
	zalamonPosition = Position(33353, 31410, 8),

	summonArea = {
		from = Position(33252, 31105, 7),
		to = Position(33288, 31134, 7),
	},
	-- PROVEN (owner PDF main spoiler + TibiaWiki, corroborated by the PDF's own reader comment
	-- noting a "Lizard Gate Guardian" encounter during this mission): 10-minute survival, waves
	-- every minute, early waves are eternal guardians, later waves are lizard chosen, and the
	-- boss (Lizard Gate Guardian) spawns additionally around minute 8.
	-- NOT_PROVEN: the exact monster COUNT per wave. No source (owner PDF, TibiaWiki, or bounded
	-- external research) documents an exact number. 20 is carried over from this file's own
	-- pre-existing (pre-this-PR) wave-1-4 configuration for consistency, not asserted as a
	-- confirmed Global value - it does not affect completability either way, since surviving
	-- (not killing) is the actual objective. 9 waves (not 10): a wave scheduled at exactly the
	-- 10-minute mark would fire at the same tick as the area clear and be removed instantly by
	-- doClearMissionArea, which is pointless and unproven as intended Global behavior - dropped.
	waves = {
		{ monster = "eternal guardian", size = 20 },
		{ monster = "eternal guardian", size = 20 },
		{ monster = "eternal guardian", size = 20 },
		{ monster = "eternal guardian", size = 20 },
		{ monster = "lizard chosen", size = 20 },
		{ monster = "lizard chosen", size = 20 },
		{ monster = "lizard chosen", size = 20 },
		{ monster = "lizard chosen", size = 20 },
		{ monster = "lizard chosen", size = 20 },
	},
	bossWaveIndex = 8,
	boss = "lizard gate guardian",
	-- CONFIRMED (bounded external research, cross-checked read-only against the exact configured
	-- OTBM): a fixed spawn tile near the great gate. The tile sits exactly on the edge of this
	-- file's own summonArea (y = 31105 = summonArea.from.y) and is confirmed walkable outdoor
	-- terrain (rock ground + jungle grass, no blocking object) - not guessed.
	bossPosition = Position(33261, 31105, 7),
	survivalDuration = 10 * 60 * 1000,
}

local Mission05 = Storage.Quest.U8_54.ChildrenOfTheRevolution.Mission05

-- Session-safe: this arena is shared physical map state, not a per-player instance. Each
-- formation start gets a unique, monotonically increasing run token (module-level counter,
-- zero collision risk) so a stale callback from an earlier, already-finished or abandoned
-- attempt can never affect a later attempt sharing this same room - the same pattern used for
-- The New Frontier's Mortal Combat arena.
local currentRunToken = 0

local function isCurrentRun(runToken)
	return runToken > 0 and Game.getStorageValue(Mission05) == runToken
end

-- CONFIRMED BUG (found in review): only the STEPPING player was checked for Questline == 19;
-- the other three formation tiles were accepted from any isPlayer() occupant at all, letting one
-- eligible player plus three arbitrary bystanders start the encounter. Every one of the four
-- formation occupants must independently satisfy this predicate. Kept as its own function (not
-- inlined) so a future task-family PR can extend it - e.g. "== 19 OR active Zze Art of War
-- participant" - without touching the formation/wave logic at all.
local function isEligibleForMission05Formation(player)
	return player:getStorageValue(Storage.Quest.U8_54.ChildrenOfTheRevolution.Questline) == 19
end

local function doClearMissionArea(runToken)
	if not isCurrentRun(runToken) then
		return
	end

	Game.setStorageValue(Mission05, -1)

	local spectators = Game.getSpectators(config.areaCenter, false, true, 26, 26, 20, 20)
	for i = 1, #spectators do
		local spectator = spectators[i]
		if spectator:isPlayer() then
			spectator:teleportTo(config.zalamonPosition)
			spectator:getPosition():sendMagicEffect(CONST_ME_TELEPORT)
			if spectator:getStorageValue(Storage.Quest.U8_54.ChildrenOfTheRevolution.Questline) == 19 then
				spectator:setStorageValue(Storage.Quest.U8_54.ChildrenOfTheRevolution.Questline, 20)
			end
		else
			spectator:remove()
		end
	end
	return true
end

local function removeStairs(runToken)
	if not isCurrentRun(runToken) then
		return
	end

	local stair = Tile(config.stairPosition):getItemById(1977)
	if stair then
		stair:transform(1897)
	end
end

local function summonWave(runToken, i)
	if not isCurrentRun(runToken) then
		return
	end

	local wave = config.waves[i]
	if wave then
		for _ = 1, wave.size do
			local summonPosition = Position(math.random(config.summonArea.from.x, config.summonArea.to.x), math.random(config.summonArea.from.y, config.summonArea.to.y), 7)
			Game.createMonster(wave.monster, summonPosition)
			summonPosition:sendMagicEffect(CONST_ME_TELEPORT)
		end
	end

	if i == config.bossWaveIndex then
		-- Unlike the regular waves (where a handful of failed spawns out of 20 is
		-- inconsequential), the boss is a named, singular monster, so its creation is checked
		-- rather than fired-and-forgotten. extended=true lets the engine place it on a nearby
		-- free tile if the exact spot is temporarily occupied. Mission 5 completion is a survival
		-- objective, not a kill requirement, so a failed spawn must not soft-lock the quest - but
		-- it must not be silent either.
		local boss = Game.createMonster(config.boss, config.bossPosition, true)
		if boss then
			-- extended=true may place the boss on a nearby free tile if the exact spot is
			-- occupied - send the effect at where it actually ended up, not the requested tile.
			boss:getPosition():sendMagicEffect(CONST_ME_TELEPORT)
		else
			logger.warn("[children_of_the_revolution.movements_click] Failed to spawn {} at {} for run {}", config.boss, config.bossPosition:toString(), runToken)
		end
	end
end

local click = MoveEvent()

function click.onStepIn(creature, item, position, fromPosition)
	local player = creature:getPlayer()
	if not player then
		return true
	end

	if not isEligibleForMission05Formation(player) or Game.getStorageValue(Mission05) > 0 then
		return true
	end

	local players = {}
	for i = 1, #config.positions do
		local occupant = Tile(Position(config.positions[i])):getTopCreature()
		if occupant and occupant:isPlayer() and isEligibleForMission05Formation(occupant) then
			players[#players + 1] = occupant
		end
	end

	for i = 1, #players do
		players[i]:say("A clicking sound tatters the silence.", TALKTYPE_MONSTER_SAY)
	end

	if #players ~= #config.positions then
		return true
	end

	player:say("The army is complete again. You hear a hatch opening elsewhere, followed by a grinding sound.", TALKTYPE_MONSTER_SAY, false, 0, Position(33261, 31081, 8))

	local stair = Tile(config.stairPosition):getItemById(1897)
	if stair then
		stair:transform(1977)
	end

	currentRunToken = currentRunToken + 1
	local runToken = currentRunToken
	Game.setStorageValue(Mission05, runToken)

	for wave = 1, #config.waves do
		addEvent(summonWave, wave * 60 * 1000, runToken, wave)
	end
	addEvent(removeStairs, 30 * 1000, runToken)
	addEvent(doClearMissionArea, config.survivalDuration, runToken)
	return true
end

click:type("stepin")
for index, value in pairs(config.positions) do
	click:position(value)
end
click:register()
