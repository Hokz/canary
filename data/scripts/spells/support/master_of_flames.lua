-- Master of Flames (15.25.3a4a52). Sorcerer elemental stance, level 20, 400 mana. See
-- data/libs/systems/stance.lua.
--
-- Two effects, both in the engine and both keyed on this stance's subId. +4% base
-- power on fire SPELLS - Combat::getCombatDamage applies it on the spell's natural
-- element and only to instant spells, so fire runes, wand hits and converted spells
-- get nothing. The condition itself carries no parameter.
--
-- The other lives in Combat::getCombatDamage: after a fire spell, the next spell
-- of another element is converted to fire. The engine reads that off the stance
-- condition itself - holding this subId is the whole flag - so nothing here has
-- to be set for it.
--
-- Elemental and Crippling are separate families, so a Sorcerer may hold one of
-- each; casting another Master of * replaces this one. A conversion this stance
-- armed is disarmed the moment the stance comes off - toggled off or replaced -
-- in ConditionAttributes::endCondition; a Crippling or General stance changing
-- leaves it armed.
local function build()
	return Stance.condition(AttrSubId_StanceMasterOfFlames, function(condition) end)
end

local spell = Spell("instant")

function spell.onCastSpell(creature, variant)
	return Stance.cast(creature, AttrSubId_StanceMasterOfFlames, Stance.Family.Elemental, build, CONST_ME_FIREAREA)
end

spell:name("Master of Flames")
spell:words("uteta flam")
spell:group("support", "focus")
spell:vocation("sorcerer;true", "master sorcerer;true")
-- Canary-internal spell id, NOT the official CipSoft id; see divine_defiance.lua.
spell:id(309)
-- Cooldowns: 30s own, 2s Support, 30s on the Elemental stance family (secondary
-- group). The engine's Focus group is that family here - see stance.lua.
spell:cooldown(30 * 1000)
spell:groupCooldown(2 * 1000, 30 * 1000)
spell:level(20)
spell:mana(400)
spell:isSelfTarget(true)
spell:isAggressive(false)
spell:isPremium(true)

spell:register()
