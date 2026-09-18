-- Base power 170 -> 155 in the July balance pass (CipSoft, 7 July), the same
-- adjustment Great Death Beam received. This spell's own datapack coefficients are
-- 4 (min) and 7 (max) at base power 170; both scale by 155/170: 3.6471 and 6.3824,
-- to two decimals. See great_death_beam.lua.
local function formulaFunction(player, level, maglevel)
	local min = (level / 5) + (maglevel * 3.65)
	local max = (level / 5) + (maglevel * 6.38)
	return -min, -max
end

function onGetFormulaValues(player, level, maglevel)
	return formulaFunction(player, level, maglevel)
end

function onGetFormulaValuesWOD(player, level, maglevel)
	return formulaFunction(player, level, maglevel)
end

-- Beam Mastery's flank damage is a percentage of the beam's own damage, read from
-- C++ per cast so 25 / 40 / 70 lives in exactly one place.
function onGetFormulaValuesBeamMasteryFlank(player, level, maglevel)
	local min, max = formulaFunction(player, level, maglevel)
	local factor = player:getBeamMasteryAdjacentDamage() / 100.0
	return min * factor, max * factor
end

local function createCombat(area, combatFunc, isFlank)
	local initCombat = Combat()
	initCombat:setCallback(CALLBACK_PARAM_LEVELMAGICVALUE, combatFunc)
	initCombat:setParameter(COMBAT_PARAM_TYPE, COMBAT_ENERGYDAMAGE)
	initCombat:setParameter(COMBAT_PARAM_EFFECT, CONST_ME_ENERGYAREA)
	initCombat:setArea(createCombatArea(area))
	if isFlank then
		-- Keeps the flank out of the central beam's target accounting entirely.
		initCombat:setParameter(COMBAT_PARAM_BEAM_MASTERY_FLANK, true)
	end
	return initCombat
end

local combat = createCombat(AREA_BEAM8, "onGetFormulaValues")
local combatWOD = createCombat(AREA_BEAM10, "onGetFormulaValuesWOD")

-- Cardinal only, matching this spell's existing directions: it supplies no diagonal
-- area today and the flanks must not widen where it can be cast. The length matches
-- the beam that executes with Beam Mastery active: BEAM10.
local flankArea = buildBeamMasteryFlankAreas(10)
local combatFlank = createCombat(flankArea, "onGetFormulaValuesBeamMasteryFlank", true)

local spell = Spell("instant")

function spell.onCastSpell(creature, var)
	local player = creature:getPlayer()
	if not creature or not player then
		return false
	end
	if not player:instantSkillWOD("Beam Mastery") then
		return combat:execute(creature, var)
	end

	local result = combatWOD:execute(creature, var)
	if player:getBeamMasteryAdjacentDamage() > 0 then
		combatFlank:execute(creature, var)
	end
	return result
end

spell:group("attack", "greatbeams")
spell:id(23)
spell:name("Great Energy Beam")
spell:words("exevo gran vis lux")
spell:castSound(SOUND_EFFECT_TYPE_SPELL_GREAT_ENERGY_BEAM)
spell:level(29)
spell:mana(110)
spell:isPremium(false)
spell:needDirection(true)
spell:blockWalls(true)
spell:cooldown(6 * 1000)
spell:groupCooldown(2 * 1000, 6 * 1000)

spell:vocation("sorcerer;true", "master sorcerer;true")
spell:register()
