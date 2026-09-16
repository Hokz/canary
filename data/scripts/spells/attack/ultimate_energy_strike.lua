local combat = Combat()
combat:setParameter(COMBAT_PARAM_TYPE, COMBAT_ENERGYDAMAGE)
combat:setParameter(COMBAT_PARAM_EFFECT, CONST_ME_ENERGYAREA)
combat:setParameter(COMBAT_PARAM_DISTANCEEFFECT, CONST_ANI_ENERGY)

function onGetFormulaValues(player, level, maglevel)
	-- 15.25.3a4a52: base power 150 -> 210, expressed in the datapack's level/magic-level form by scaling the magic-level multipliers and constants by the same ratio.
	local min = (level / 5) + (maglevel * 6.3) + 49
	local max = (level / 5) + (maglevel * 10.2) + 77
	return -min, -max
end

combat:setCallback(CALLBACK_PARAM_LEVELMAGICVALUE, "onGetFormulaValues")

local spell = Spell("instant")

function spell.onCastSpell(creature, var)
	return combat:execute(creature, var)
end

spell:group("attack", "ultimatestrikes")
spell:id(155)
spell:name("Ultimate Energy Strike")
spell:words("exori max vis")
spell:castSound(SOUND_EFFECT_TYPE_SPELL_OR_RUNE)
spell:impactSound(SOUND_EFFECT_TYPE_SPELL_ULTIMATE_ENERGY_STRIKE)
spell:level(100)
spell:mana(100)
spell:isPremium(true)
spell:range(7)
spell:needCasterTargetOrDirection(true)
spell:blockWalls(true)
spell:cooldown(30 * 1000)
spell:groupCooldown(2 * 1000, 30 * 1000)

spell:vocation("sorcerer;true", "master sorcerer;true")
spell:register()
