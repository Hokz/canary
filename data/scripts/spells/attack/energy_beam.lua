local function formulaFunction(player, level, maglevel)
	local min = (level / 5) + (maglevel * 1.8) + 11
	local max = (level / 5) + (maglevel * 3) + 19
	return -min, -max
end

function onGetFormulaValues(player, level, maglevel)
	return formulaFunction(player, level, maglevel)
end

function onGetFormulaValuesWOD(player, level, maglevel)
	return formulaFunction(player, level, maglevel)
end

-- Beam Mastery's flank damage is a percentage of the beam's own damage. The
-- percentage lives in C++ (PlayerWheel::getBeamMasteryAdjacentDamagePercent) and is
-- read here per cast, so 25 / 40 / 70 is never written down a second time.
function onGetFormulaValuesBeamMasteryFlank(player, level, maglevel)
	local min, max = formulaFunction(player, level, maglevel)
	local factor = player:getBeamMasteryAdjacentDamage() / 100.0
	return min * factor, max * factor
end

local function createCombat(area, areaDiagonal, combatFunc, isFlank)
	local initCombat = Combat()
	initCombat:setCallback(CALLBACK_PARAM_LEVELMAGICVALUE, combatFunc)
	initCombat:setParameter(COMBAT_PARAM_TYPE, COMBAT_ENERGYDAMAGE)
	initCombat:setParameter(COMBAT_PARAM_EFFECT, CONST_ME_ENERGYHIT)
	initCombat:setArea(createCombatArea(area, areaDiagonal))
	if isFlank then
		-- Without this the flank's targets would be counted as central ones: they would
		-- feed the per-target cooldown reduction and take the central damage increase.
		initCombat:setParameter(COMBAT_PARAM_BEAM_MASTERY_FLANK, true)
	end
	return initCombat
end

local combat = createCombat(AREA_BEAM5, AREADIAGONAL_BEAM5, "onGetFormulaValues")
local combatWOD = createCombat(AREA_BEAM7, AREADIAGONAL_BEAM7, "onGetFormulaValuesWOD")

-- The flanks match the beam that actually executes with Beam Mastery active: BEAM7.
local flankArea, flankAreaDiagonal = buildBeamMasteryFlankAreas(7)
local combatFlank = createCombat(flankArea, flankAreaDiagonal, "onGetFormulaValuesBeamMasteryFlank", true)

local spell = Spell("instant")

function spell.onCastSpell(creature, var)
	local player = creature:getPlayer()
	if not creature or not player then
		return false
	end
	if not player:instantSkillWOD("Beam Mastery") then
		return combat:execute(creature, var)
	end

	-- The central beam first, so its own target accounting and cooldown reduction
	-- happen exactly as they did before the flanks existed.
	local result = combatWOD:execute(creature, var)
	if player:getBeamMasteryAdjacentDamage() > 0 then
		combatFlank:execute(creature, var)
	end
	return result
end

spell:group("attack")
spell:id(22)
spell:name("Energy Beam")
spell:words("exevo vis lux")
spell:castSound(SOUND_EFFECT_TYPE_SPELL_ENERGY_BEAM)
spell:level(23)
spell:mana(40)
spell:isPremium(false)
spell:needDirection(true)
spell:blockWalls(true)
spell:cooldown(4 * 1000)
spell:groupCooldown(2 * 1000)

spell:vocation("sorcerer;true", "master sorcerer;true")
spell:register()
