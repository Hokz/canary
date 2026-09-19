local combat = Combat()
combat:setParameter(COMBAT_PARAM_TYPE, COMBAT_HEALING)
combat:setParameter(COMBAT_PARAM_EFFECT, CONST_ME_MAGIC_BLUE)
combat:setParameter(COMBAT_PARAM_DISPEL, CONDITION_PARALYZE)
combat:setParameter(COMBAT_PARAM_AGGRESSIVE, false)

-- 15.25: Base Power, the level contribution, Shielding and Magic Level.
-- Every coefficient lives in KnightHealing.spells; see
-- data/libs/functions/knight_healing.lua for what each one is worth as evidence.
function onGetFormulaValues(player, _level, magicLevel)
	return KnightHealing.values("Intense Wound Cleansing", player, magicLevel)
end

combat:setCallback(CALLBACK_PARAM_LEVELMAGICVALUE, "onGetFormulaValues")

local spell = Spell("instant")

function spell.onCastSpell(creature, variant)
	return combat:execute(creature, variant)
end

spell:name("Intense Wound Cleansing")
spell:words("exura gran ico")
spell:group("healing")
spell:vocation("knight;true", "elite knight;true")
spell:castSound(SOUND_EFFECT_TYPE_SPELL_INTENSE_WOUND_CLEANSING)
spell:id(158)
spell:cooldown(600000) -- 600 sec
spell:groupCooldown(2 * 1000) -- GLOBAL 2026: Knight healing group cooldown raised to 2s
spell:level(80)
spell:mana(300) -- GLOBAL 2026
spell:isSelfTarget(true)
spell:isAggressive(false)
spell:isPremium(true)

spell:register()
