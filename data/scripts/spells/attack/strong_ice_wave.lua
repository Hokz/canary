local combat = Combat()
combat:setParameter(COMBAT_PARAM_TYPE, COMBAT_ICEDAMAGE)
combat:setParameter(COMBAT_PARAM_EFFECT, CONST_ME_ICEAREA)
combat:setArea(createCombatArea(AREA_SHORTWAVE3))

-- 15.25.3a4a52 plus the July balance pass: base damage 150 -> 140 (CipSoft,
-- 7 July). Every term of the datapack's formula scales by 140/150: 4.5 -> 4.2,
-- 20 -> 18.67, 7.6 -> 7.09, 48 -> 44.8.
function onGetFormulaValues(player, level, maglevel)
	local min = (level / 5) + (maglevel * 4.2) + 18.67
	local max = (level / 5) + (maglevel * 7.09) + 44.8
	return -min, -max
end

combat:setCallback(CALLBACK_PARAM_LEVELMAGICVALUE, "onGetFormulaValues")

local spell = Spell("instant")

function spell.onCastSpell(creature, var)
	return combat:execute(creature, var)
end

spell:group("attack")
spell:id(43)
spell:name("Strong Ice Wave")
spell:words("exevo gran frigo hur")
spell:castSound(SOUND_EFFECT_TYPE_SPELL_STRONG_ICE_WAVE)
spell:level(40)
spell:mana(170)
spell:needDirection(true)
-- 15.25.3a4a52: cooldown 8s -> 4s.
spell:cooldown(4 * 1000)
spell:groupCooldown(2 * 1000)

spell:vocation("druid;true", "elder druid;true")
spell:register()
