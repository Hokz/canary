-- Master of Thunder (15.25.3a4a52). Sorcerer elemental stance, level 20, 400 mana. See
-- data/libs/systems/stance.lua.
--
-- Two effects. "+4% critical hit chance on energy spells" is an element critical bonus on the
-- condition, in basis points, applied next to the weapon proficiency's own element
-- critical when a spell's critical is rolled.
--
-- The other lives in Combat::getCombatDamage: after a energy spell, the next spell
-- of another element is converted to energy. The engine reads that off the stance
-- condition itself - holding this subId is the whole flag - so nothing here has
-- to be set for it.
--
-- Elemental and Crippling are separate families, so a Sorcerer may hold one of
-- each; casting another Master of * replaces this one.
local function build()
	return Stance.condition(AttrSubId_StanceMasterOfThunder, function(condition)
		condition:setParameter(CONDITION_PARAM_ELEMENT_CRITICAL_CHANCE_ENERGY, 400)
	end)
end

local spell = Spell("instant")

function spell.onCastSpell(creature, variant)
	return Stance.cast(creature, AttrSubId_StanceMasterOfThunder, Stance.Family.Elemental, build, CONST_ME_ENERGYAREA)
end

spell:name("Master of Thunder")
spell:words("uteta vis")
spell:group("support", "focus")
spell:vocation("sorcerer;true", "master sorcerer;true")
-- Not the official client id; see divine_defiance.lua.
spell:id(310)
spell:cooldown(2 * 1000)
spell:groupCooldown(2 * 1000, 2 * 1000)
spell:level(20)
spell:mana(400)
spell:isSelfTarget(true)
spell:isAggressive(false)
spell:isPremium(true)

spell:register()
