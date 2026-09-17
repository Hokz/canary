-- Blood Rage is a stance as of 15.25: it stays on until recast or replaced by
-- Protector, and it survives logout and death. See data/libs/systems/stance.lua.
--
-- Numbers from the 15.25.3a4a52 spell table: +25% melee skill, +15% damage taken,
-- blocking disabled. The changelog section of the same update announced +30%; the
-- spell table is the shipped value and that is what is used here.
local function build()
	return Stance.condition(AttrSubId_StanceBloodRage, function(condition)
		-- MELEEPERCENT covers fist, axe, club and sword in one parameter, which is
		-- exactly the set the update names.
		condition:setParameter(CONDITION_PARAM_SKILL_MELEEPERCENT, 125)
		condition:setParameter(CONDITION_PARAM_BUFF_DAMAGERECEIVED, 115)
		condition:setParameter(CONDITION_PARAM_DISABLE_DEFENSE, true)
	end)
end

local spell = Spell("instant")

function spell.onCastSpell(creature, var)
	return Stance.cast(creature, AttrSubId_StanceBloodRage, Stance.Family.General, build)
end

spell:name("Blood Rage")
spell:words("utito tempo")
spell:group("support", "focus")
spell:vocation("knight;true", "elite knight;true")
spell:castSound(SOUND_EFFECT_TYPE_SPELL_BLOOD_RAGE)
spell:id(133)
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
