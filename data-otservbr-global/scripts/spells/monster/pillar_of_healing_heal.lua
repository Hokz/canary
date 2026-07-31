-- Mezlon the Defiler's signature ability - heals the other Pillars in the Essence of Malice
-- fight (data-otservbr-global/monster/quests/cults_of_tibia/bosses/mezlon_the_defiler.lua and
-- _stop.lua reference this spell by name; it did not exist anywhere in the repo before this fix).
local combat = Combat()
combat:setParameter(COMBAT_PARAM_EFFECT, CONST_ME_MAGIC_RED)
combat:setParameter(COMBAT_PARAM_AGGRESSIVE, 0)
combat:setArea(createCombatArea(AREA_CIRCLE3X3))

function onTargetCreature(creature, target)
	if not target:isMonster() then
		return true
	end
	local name = target:getName():lower()
	if not name:find("^pillar of ") or target:getId() == creature:getId() then
		return true
	end
	doTargetCombatHealth(0, target, COMBAT_HEALING, 1500, 2500, CONST_ME_MAGIC_RED)
	return true
end

combat:setCallback(CALLBACK_PARAM_TARGETCREATURE, "onTargetCreature")

local spell = Spell("instant")

function spell.onCastSpell(creature, var)
	return combat:execute(creature, var)
end

spell:name("heal monster 9x9")
spell:words("###cultsheal")
spell:isAggressive(false)
spell:blockWalls(false)
spell:needLearn(true)
spell:register()
