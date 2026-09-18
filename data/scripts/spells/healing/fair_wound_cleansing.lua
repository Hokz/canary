local combat = Combat()
combat:setParameter(COMBAT_PARAM_TYPE, COMBAT_HEALING)
combat:setParameter(COMBAT_PARAM_EFFECT, CONST_ME_MAGIC_BLUE)
combat:setParameter(COMBAT_PARAM_AGGRESSIVE, false)
combat:setParameter(COMBAT_PARAM_DISPEL, CONDITION_PARALYZE)

-- 15.25: Base Power, the level contribution, Shielding and Magic Level.
-- Every coefficient lives in KnightHealing.spells; see
-- data/libs/functions/knight_healing.lua for what each one is worth as evidence.
function onGetFormulaValues(player, _level, magicLevel)
	return KnightHealing.values("Fair Wound Cleansing", player, magicLevel)
end

combat:setCallback(CALLBACK_PARAM_LEVELMAGICVALUE, "onGetFormulaValues")

local spell = Spell("instant")

function spell.onCastSpell(creature, variant)
	return combat:execute(creature, variant)
end

spell:group("healing")
spell:id(239)
spell:name("Fair Wound Cleansing")
spell:words("exura med ico")
spell:castSound(SOUND_EFFECT_TYPE_SPELL_FAIR_WOUND_CLEANSING)
spell:level(300)
spell:mana(135) -- GLOBAL 2026
spell:isPremium(true)
spell:isSelfTarget(true)
spell:cooldown(1000)
spell:groupCooldown(2 * 1000) -- GLOBAL 2026: Knight healing group cooldown raised to 2s
spell:isAggressive(false)
spell:vocation("knight;true", "elite knight;true")

spell:register()
