local combat = Combat()
combat:setParameter(COMBAT_PARAM_TYPE, COMBAT_HOLYDAMAGE)
combat:setParameter(COMBAT_PARAM_EFFECT, CONST_ME_HOLYAREA)
combat:setArea(createCombatArea(AREA_CIRCLE3X3))

function onGetFormulaValues(player, level, maglevel)
	-- 15.25.3a4a52: base power 140 -> 160 at release, adjusted to 150 in the July
	-- balance pass; 150 is the value here. The datapack's shape for this spell is
	-- level/5 + magicLevel x k, with k = 4 (min) and 6 (max) at base power 140, so
	-- k scales as 4/140 and 6/140 per point of base power: 150 -> 4.29 / 6.43,
	-- rounded to one decimal.
	local min = (level / 5) + (maglevel * 4.3)
	local max = (level / 5) + (maglevel * 6.4)
	return -min, -max
end

combat:setCallback(CALLBACK_PARAM_LEVELMAGICVALUE, "onGetFormulaValues")

local spell = Spell("instant")

function spell.onCastSpell(creature, var)
	return combat:execute(creature, var)
end

spell:group("attack")
spell:id(124)
spell:name("Divine Caldera")
spell:words("exevo mas san")
spell:castSound(SOUND_EFFECT_TYPE_SPELL_DIVINE_CALDERA)
spell:level(50)
spell:mana(160)
spell:isPremium(true)
spell:isSelfTarget(true)
spell:cooldown(4 * 1000)
spell:groupCooldown(2 * 1000)

spell:vocation("paladin;true", "royal paladin;true")
spell:register()
