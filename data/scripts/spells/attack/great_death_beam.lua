-- Base power 170 -> 155 in the July balance pass (CipSoft, 7 July; the same note
-- moves Great Energy Beam by the same amounts). The datapack expresses this spell
-- as level/5 + magicLevel x k with k = 5.5 (min) and 9 (max) at base power 170, so
-- both scale by 155/170: 5.0147 and 8.2059, to two decimals.
local function formulaFunction(player, level, maglevel)
	local min = (level / 5) + (maglevel * 5.01)
	local max = (level / 5) + (maglevel * 8.21)
	return -min, -max
end

-- Beam Mastery's flank damage is a percentage of the beam's own damage, read from C++
-- per cast so 25 / 40 / 70 lives in exactly one place.
local function flankFormula(player, level, maglevel)
	local min, max = formulaFunction(player, level, maglevel)
	local factor = player:getBeamMasteryAdjacentDamage() / 100.0
	return min * factor, max * factor
end

-- One global per Combat, not one per formula. LuaScriptInterface::getEvent takes the
-- global and then sets it to nil, so a callback name can be consumed exactly once: two
-- Combats naming the same function would leave the second with no formula at all. The
-- six names below are identical in body and deliberately distinct in name.
function onGetFormulaValues(player, level, maglevel)
	return formulaFunction(player, level, maglevel)
end

function onGetFormulaValuesGradeTwo(player, level, maglevel)
	return formulaFunction(player, level, maglevel)
end

function onGetFormulaValuesGradeThree(player, level, maglevel)
	return formulaFunction(player, level, maglevel)
end

function onGetFormulaValuesFlankGradeOne(player, level, maglevel)
	return flankFormula(player, level, maglevel)
end

function onGetFormulaValuesFlankGradeTwo(player, level, maglevel)
	return flankFormula(player, level, maglevel)
end

function onGetFormulaValuesFlankGradeThree(player, level, maglevel)
	return flankFormula(player, level, maglevel)
end

-- One Combat per grade. This used to pass a single shared Combat through
-- createCombat three times, so every call overwrote the previous area and all three
-- grades ended up executing the last one - the beam was always BEAM8 whatever the
-- grade. Each grade now owns its object, which is also what lets a flank match the
-- length that actually executed.
local function createCombat(area, combatFunc, isFlank)
	local combat = Combat()
	combat:setCallback(CALLBACK_PARAM_LEVELMAGICVALUE, combatFunc)
	combat:setParameter(COMBAT_PARAM_TYPE, COMBAT_DEATHDAMAGE)
	combat:setParameter(COMBAT_PARAM_EFFECT, CONST_ME_MORTAREA)
	combat:setArea(createCombatArea(area))
	if isFlank then
		-- Keeps the flank out of the central beam's target accounting entirely.
		combat:setParameter(COMBAT_PARAM_BEAM_MASTERY_FLANK, true)
	end
	return combat
end

local combat = {
	createCombat(AREA_BEAM6, "onGetFormulaValues"),
	createCombat(AREA_BEAM7, "onGetFormulaValuesGradeTwo"),
	createCombat(AREA_BEAM8, "onGetFormulaValuesGradeThree"),
}

-- Cardinal only, matching this spell's existing directions. One flank per grade, each
-- the same length as the central beam of that grade.
local combatFlank = {
	createCombat(buildBeamMasteryFlankAreas(6), "onGetFormulaValuesFlankGradeOne", true),
	createCombat(buildBeamMasteryFlankAreas(7), "onGetFormulaValuesFlankGradeTwo", true),
	createCombat(buildBeamMasteryFlankAreas(8), "onGetFormulaValuesFlankGradeThree", true),
}

local spell = Spell("instant")

local exhaust = {}
function spell.onCastSpell(creature, var)
	local player = creature and creature:getPlayer()
	if not player then
		return false
	end

	-- 15.25.3a4a52: a common spell learned at level 66. The Wheel grades still
	-- lengthen the beam; without one it is the base beam, not a refusal.
	local grade = player:upgradeSpellsWOD("Great Death Beam")
	if grade == WHEEL_GRADE_NONE then
		grade = 1
	end

	local result = combat[grade]:execute(creature, var)
	-- The flank follows the grade that executed, so its length always matches.
	if player:instantSkillWOD("Beam Mastery") and player:getBeamMasteryAdjacentDamage() > 0 then
		combatFlank[grade]:execute(creature, var)
	end
	return result
end

spell:group("attack", "greatbeams")
spell:id(260)
spell:name("Great Death Beam")
spell:words("exevo max mort")
spell:level(66)
spell:mana(140)
spell:isPremium(false)
spell:needDirection(true)
spell:blockWalls(true)
spell:cooldown(10 * 1000)
spell:groupCooldown(2 * 1000, 6 * 1000)
spell:vocation("sorcerer;true", "master sorcerer;true")
spell:register()
