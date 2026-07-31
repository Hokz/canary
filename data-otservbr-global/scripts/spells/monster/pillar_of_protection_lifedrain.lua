-- Eliz the Unyielding's signature ability - Life Drain damage in an area, per the Pillar of
-- Protection's documented mechanic (data-otservbr-global/monster/quests/cults_of_tibia/bosses/
-- eliz_the_unyielding.lua and _stop.lua reference this spell by name; it did not exist anywhere
-- in the repo before this fix).
local combat = Combat()
combat:setParameter(COMBAT_PARAM_TYPE, COMBAT_LIFEDRAIN)
combat:setParameter(COMBAT_PARAM_EFFECT, CONST_ME_MAGIC_GREEN)
combat:setArea(createCombatArea(AREA_CIRCLE3X3))

function onGetFormulaValues(creature, level, magicLevel)
	local min = -350
	local max = -550
	return min, max
end

combat:setCallback(CALLBACK_PARAM_LEVELMAGICVALUE, "onGetFormulaValues")

local spell = Spell("instant")

function spell.onCastSpell(creature, var)
	return combat:execute(creature, var)
end

spell:name("cults of tibia armor buff")
spell:words("###cultslifedrain")
spell:isAggressive(true)
spell:blockWalls(true)
spell:needLearn(true)
spell:register()
