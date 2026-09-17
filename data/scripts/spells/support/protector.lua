-- Protector is a stance as of 15.25: it stays on until recast or replaced by Blood
-- Rage, and it survives logout and death. See data/libs/systems/stance.lua.
--
-- Numbers from the 15.25.3a4a52 spell table: +30% shielding, -15% damage received,
-- -15% damage dealt. The pre-15.25 values were far larger (+120% shielding, -35%
-- damage dealt) because the spell was a short timed burst; as a permanent stance it
-- is the update's smaller, flatter numbers.
local function build()
	return Stance.condition(AttrSubId_StanceProtector, function(condition)
		condition:setParameter(CONDITION_PARAM_SKILL_SHIELDPERCENT, 130)
		condition:setParameter(CONDITION_PARAM_BUFF_DAMAGEDEALT, 85)
		condition:setParameter(CONDITION_PARAM_BUFF_DAMAGERECEIVED, 85)
	end)
end

local spell = Spell("instant")

function spell.onCastSpell(creature, variant)
	return Stance.cast(creature, AttrSubId_StanceProtector, Stance.Family.General, build)
end

spell:name("Protector")
spell:words("utamo tempo")
spell:group("support", "focus")
spell:vocation("knight;true", "elite knight;true")
spell:castSound(SOUND_EFFECT_TYPE_SPELL_PROTECTOR)
spell:id(132)
-- Cooldowns: 2s own, 2s Support, 2s Focus - the contract the pre-15.25 datapack
-- already had for this spell, kept as its own rather than a blanket stance value.
spell:cooldown(2 * 1000)
spell:groupCooldown(2 * 1000, 2 * 1000)
spell:level(20)
spell:mana(20)
spell:isSelfTarget(true)
spell:isAggressive(false)
spell:isPremium(true)

spell:register()
