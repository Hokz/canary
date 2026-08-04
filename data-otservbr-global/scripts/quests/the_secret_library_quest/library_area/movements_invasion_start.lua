-- Secret Library final invasion ("Scourge of Oblivion") - wave/wing orchestration.
--
-- Previously this whole encounter was a single BossLever pull spawning "The Scourge of Oblivion"
-- directly with no wave sequence at all (actions_the_scourge_of_oblivion.lua, still the entry point -
-- see the small addition at the end of that file). This file implements the described 26:20, 4-wing
-- invasion: BossLever now spawns "The Scourge of Oblivion (Dormant)" (a 100%-immune placeholder,
-- the_scourge_of_oblivion_dormant.lua) at config.boss.position - the moment a player steps onto the
-- room's teleport-destination tile (the same real position players are always sent to,
-- 32726,32733,11), the wave sequence begins.
--
-- MAP SETUP REQUIRED: none of the 4 wing rooms have real coordinates anywhere in the source (only
-- directional/narrative description - "go northeast", "go southwest" - no map grid references) or
-- in the pre-existing repo (these 5 boss monsters had zero spawn wiring before this pass). All wing
-- positions below are nil pending owner map data - see the Map Setup Contract in the PR body. Until
-- filled in, the breach messages and central timer still fire (matching the reference's own
-- description, which frames them as message events, not visual reveals) but no wing boss/add ever
-- spawns, so a wing's defeated flag can never be set and the real Scourge of Oblivion can never
-- appear - fully inert/safe, same convention as every other position-dependent script this session.
local centralHall = Position(32726, 32733, 11) -- real - BossLever's own teleport destination
local Invasion = Storage.Quest.U11_80.TheSecretLibrary.SecretLibraryInvasion

local TOTAL_ENCOUNTER_SECONDS = 26 * 60 + 20
local WAVE_START_DELAY = 30 * 1000

local WINGS = {
	{
		key = "spellstealer",
		breachMessage = "THE NORTH EASTERN WING HAS BEEN BREACHED! RUSH TO CRUSH THE INTRUDERS!",
		monsters = { "The Spellstealer" },
		roomCenter = nil, -- Position, MAP SETUP REQUIRED (northeast wing)
		spawnPositions = {}, -- list of Position, MAP SETUP REQUIRED
		greenTeleport = nil, -- Position, MAP SETUP REQUIRED (northwest part of the wing room)
		redTeleport = nil, -- Position, MAP SETUP REQUIRED (southeast part of the wing room)
		defeatedStorage = Invasion.SpellstealerDefeated,
	},
	{
		key = "scionOfHavoc",
		breachMessage = "THE SOUTH EASTERN WING HAS BEEN BREACHED! RUSH TO CRUSH THE INTRUDERS!",
		monsters = { "The Scion of Havoc" },
		addMonsters = { "Spawn of Havoc" },
		roomCenter = nil, -- MAP SETUP REQUIRED (southeast wing)
		spawnPositions = {},
		addSpawnPositions = {},
		defeatedStorage = Invasion.ScionOfHavocDefeated,
	},
	{
		key = "brothers",
		breachMessage = "THE SOUTH WESTERN WING HAS BEEN BREACHED! RUSH TO CRUSH THE INTRUDERS!",
		monsters = { "Brother Chill", "Brother Freeze" },
		roomCenter = nil, -- MAP SETUP REQUIRED (southwest wing)
		spawnPositions = {},
		defeatedStorage = Invasion.BrothersDefeated,
	},
	{
		key = "devourer",
		breachMessage = "THE NORTH WESTERN WING HAS BEEN BREACHED! RUSH TO CRUSH THE INTRUDERS!",
		monsters = { "The Devourer of Secrets" },
		addMonsters = { "The Book of Secrets", "Stolen Tome of Portals" },
		roomCenter = nil, -- MAP SETUP REQUIRED (northwest wing)
		spawnPositions = {},
		addSpawnPositions = {},
		defeatedStorage = Invasion.DevourerDefeated,
	},
}

-- Global (not local): called from creaturescripts_invasion_wings.lua's per-wing onDeath handlers,
-- which live in a different file loaded independently - matching this repo's own convention for
-- cross-file quest helpers (e.g. clearBossRoom/roomIsOccupied in data/libs/functions/functions.lua).
function InvasionCheckWingsCleared()
	for _, wing in ipairs(WINGS) do
		if Game.getStorageValue(wing.defeatedStorage) < 1 then
			return
		end
	end

	local spectators = Game.getSpectators(centralHall, false, false, 15, 15, 15, 15)
	for _, spectator in ipairs(spectators) do
		if spectator:isMonster() and spectator:getName():lower() == "the scourge of oblivion (dormant)" then
			local oldHealth = spectator:getHealth()
			spectator:setType("The Scourge of Oblivion")
			spectator:addHealth(-(spectator:getHealth() - oldHealth))
			for _, player in ipairs(Game.getSpectators(centralHall, false, true, 15, 15, 15, 15)) do
				player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "The Leader of the invasion finally joins the battle! Beware, the scourge of oblivion enters the fray!")
			end
			break
		end
	end
end

local function spawnWing(wing)
	for _, position in ipairs(wing.spawnPositions or {}) do
		for _, name in ipairs(wing.monsters) do
			Game.createMonster(name, position, true, true)
		end
	end
	for _, position in ipairs(wing.addSpawnPositions or {}) do
		for _, name in ipairs(wing.addMonsters or {}) do
			Game.createMonster(name, position, true, true)
		end
	end
end

local function startWaves()
	for _, wing in ipairs(WINGS) do
		for _, spectator in ipairs(Game.getSpectators(centralHall, false, true, 15, 15, 15, 15)) do
			spectator:sendTextMessage(MESSAGE_EVENT_ADVANCE, wing.breachMessage)
		end
		spawnWing(wing)
	end
end

local function checkEncounterTimeout()
	local started = Game.getStorageValue(Invasion.Started)
	if started < 1 then
		return
	end
	if os.time() - started < TOTAL_ENCOUNTER_SECONDS then
		addEvent(checkEncounterTimeout, 10 * 1000)
		return
	end
	-- Time's up and the invasion wasn't cleared - matches BossLever's own timeToDefeat cleanup
	-- philosophy (see actions_the_scourge_of_oblivion.lua), but scoped to this file's own wave
	-- state so it resets correctly even if BossLever's own timeout fires first or second.
	Game.setStorageValue(Invasion.Started, 0)
end

local invasionStart = MoveEvent()

function invasionStart.onStepIn(creature, item, position, fromPosition)
	local player = creature:getPlayer()
	if not player then
		return true
	end
	if Game.getStorageValue(Invasion.Started) < 1 then
		Game.setStorageValue(Invasion.Started, os.time())
		Game.setStorageValue(Invasion.SpellstealerDefeated, 0)
		Game.setStorageValue(Invasion.ScionOfHavocDefeated, 0)
		Game.setStorageValue(Invasion.BrothersDefeated, 0)
		Game.setStorageValue(Invasion.BrothersDeathCount, 0)
		Game.setStorageValue(Invasion.DevourerDefeated, 0)
		Game.setStorageValue(Invasion.ScourgePhase, 0)
		addEvent(startWaves, WAVE_START_DELAY)
		addEvent(checkEncounterTimeout, 10 * 1000)
	end
	return true
end

invasionStart:position(centralHall)
invasionStart:register()

-- The Spellstealer's colored-phase teleports (see creaturescripts_invasion_wings.lua). Registered
-- unconditionally on nil positions currently has no effect - MoveEvent:position(nil) would error, so
-- these are guarded and simply skipped until the wing room (and therefore these two tiles) exist.
local spellstealerWing = WINGS[1]
if spellstealerWing.greenTeleport and spellstealerWing.redTeleport then
	local colorTeleports = MoveEvent()
	function colorTeleports.onStepIn(creature, item, position, fromPosition)
		local monster = creature:getMonster()
		if not monster then
			return true
		end
		local name = monster:getName():lower()
		local matches = (name == "the spellstealer (green)" and position == spellstealerWing.greenTeleport) or (name == "the spellstealer (red)" and position == spellstealerWing.redTeleport)
		if not matches then
			return true
		end
		local oldHealth = monster:getHealth()
		monster:setType("The Spellstealer")
		monster:addHealth(-(monster:getHealth() - oldHealth))
		position:sendMagicEffect(CONST_ME_MAGIC_BLUE)
		for _, spectator in ipairs(Game.getSpectators(position, false, true, 10, 10, 10, 10)) do
			spectator:sendTextMessage(MESSAGE_EVENT_ADVANCE, "The Spellstealer is drained of its stolen energy and becomes vulnerable again!")
		end
		return true
	end
	colorTeleports:position(spellstealerWing.greenTeleport)
	colorTeleports:position(spellstealerWing.redTeleport)
	colorTeleports:register()
end
