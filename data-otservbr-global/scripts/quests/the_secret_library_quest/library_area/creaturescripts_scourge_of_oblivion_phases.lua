-- Secret Library final invasion - The Scourge of Oblivion's 3-phase cycle.
--
-- Yellow (vulnerable, the_scourge_of_oblivion.lua) <-> Red ("reflective shields",
-- the_scourge_of_oblivion_reflective.lua) <-> Blue ("prepares a devastating attack" then fires a
-- 4-directional beam, the_scourge_of_oblivion_immune.lua). No exact phase-duration timings are given
-- anywhere in the reference (only "after several turns changes form") - the intervals below are a
-- disclosed, reasonable judgment call, not sourced numbers.
local Invasion = Storage.Quest.U11_80.TheSecretLibrary.SecretLibraryInvasion

local YELLOW_DURATION = 25 * 1000
local RED_DURATION = 15 * 1000
local BLUE_PREPARE_DURATION = 5 * 1000
local BEAM_DAMAGE = { 8000, 12000 }

local PHASE_YELLOW, PHASE_RED, PHASE_BLUE = 1, 2, 3

local function fireBeam(monster)
	if not monster or monster:isRemoved() then
		return
	end
	local position = monster:getPosition()
	local directions = {
		{ x = 0, y = -1 }, -- north
		{ x = 0, y = 1 }, -- south
		{ x = -1, y = 0 }, -- west
		{ x = 1, y = 0 }, -- east
	}
	for _, dir in ipairs(directions) do
		for step = 1, 8 do
			local tilePos = Position(position.x + dir.x * step, position.y + dir.y * step, position.z)
			tilePos:sendMagicEffect(CONST_ME_ENERGYHIT)
			for _, spectator in ipairs(Game.getSpectators(tilePos, false, true, 0, 0, 0, 0)) do
				spectator:addHealth(-math.random(BEAM_DAMAGE[1], BEAM_DAMAGE[2]))
			end
		end
	end
end

local function swapScourge(monster, newName)
	local oldHealth = monster:getHealth()
	monster:setType(newName)
	monster:addHealth(-(monster:getHealth() - oldHealth))
	return monster
end

local scourgePhaseCycle = CreatureEvent("InvasionScourgePhaseCycle")
function scourgePhaseCycle.onThink(creature, interval)
	local name = creature:getName():lower()
	if not name:find("the scourge of oblivion") then
		return true
	end

	local phase = Game.getStorageValue(Invasion.ScourgePhase)
	local now = os.time()

	if phase < 1 then
		-- First tick after spawning in yellow form.
		Game.setStorageValue(Invasion.ScourgePhase, PHASE_YELLOW)
		creature:setStorageValue(2, now + math.floor(YELLOW_DURATION / 1000))
		return true
	end

	local phaseUntil = creature:getStorageValue(2)
	if phaseUntil > now then
		return true
	end

	if phase == PHASE_YELLOW then
		-- Yellow -> Red or Blue (2-in-3 chance red, matching red being the more frequent phase per
		-- the reference's description order).
		if math.random(1, 3) == 1 then
			swapScourge(creature, "The Scourge of Oblivion (Immune)")
			Game.setStorageValue(Invasion.ScourgePhase, PHASE_BLUE)
			creature:setStorageValue(2, now + math.floor(BLUE_PREPARE_DURATION / 1000) + 1)
			for _, spectator in ipairs(Game.getSpectators(creature:getPosition(), false, true, 10, 10, 10, 10)) do
				spectator:sendTextMessage(MESSAGE_EVENT_ADVANCE, "The Scourge of Oblivion prepares a devastating attack!")
			end
			addEvent(fireBeam, BLUE_PREPARE_DURATION, creature)
		else
			swapScourge(creature, "The Scourge of Oblivion (Reflective)")
			Game.setStorageValue(Invasion.ScourgePhase, PHASE_RED)
			creature:setStorageValue(2, now + math.floor(RED_DURATION / 1000))
			for _, spectator in ipairs(Game.getSpectators(creature:getPosition(), false, true, 10, 10, 10, 10)) do
				spectator:sendTextMessage(MESSAGE_EVENT_ADVANCE, "The Scourge of Oblivion activated its reflective shields!")
			end
		end
	elseif phase == PHASE_RED then
		swapScourge(creature, "The Scourge of Oblivion")
		Game.setStorageValue(Invasion.ScourgePhase, PHASE_YELLOW)
		creature:setStorageValue(2, now + math.floor(YELLOW_DURATION / 1000))
	elseif phase == PHASE_BLUE then
		swapScourge(creature, "The Scourge of Oblivion")
		Game.setStorageValue(Invasion.ScourgePhase, PHASE_YELLOW)
		creature:setStorageValue(2, now + math.floor(YELLOW_DURATION / 1000))
	end
	return true
end
scourgePhaseCycle:register()

local scourgeDeath = CreatureEvent("InvasionScourgeDeath")
function scourgeDeath.onDeath(creature, corpse, lasthitkiller, mostdamagekiller)
	Game.setStorageValue(Invasion.ScourgePhase, 0)
	onDeathForDamagingPlayers(creature, function(_creature, player)
		if not player:hasAchievement("Library Liberator") then
			player:addAchievement("Library Liberator")
		end
	end)
	return true
end
scourgeDeath:register()
