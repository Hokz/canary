-- Master of Flames (15.25.3a4a52). Sorcerer elemental stance, level 20, 400 mana. See
-- data/libs/systems/stance.lua.
--
-- Two effects. "+4% base power on fire spells" is INCREASE_FIREPERCENT on the condition. That
-- parameter raises all fire damage the player deals, auto attacks with a fire
-- weapon included, not spells alone - the engine has nothing narrower.
--
-- The other lives in Combat::getCombatDamage: after a fire spell, the next spell
-- of another element is converted to fire. The engine reads that off the stance
-- condition itself - holding this subId is the whole flag - so nothing here has
-- to be set for it.
--
-- Elemental and Crippling are separate families, so a Sorcerer may hold one of
-- each; casting another Master of * replaces this one.
local function build()
	return Stance.condition(AttrSubId_StanceMasterOfFlames, function(condition)
		condition:setParameter(CONDITION_PARAM_INCREASE_FIREPERCENT, 4)
	end)
end

local spell = Spell("instant")

function spell.onCastSpell(creature, variant)
	return Stance.cast(creature, AttrSubId_StanceMasterOfFlames, Stance.Family.Elemental, build, CONST_ME_FIREAREA)
end

spell:name("Master of Flames")
spell:words("uteta flam")
spell:group("support", "focus")
spell:vocation("sorcerer;true", "master sorcerer;true")
-- Not the official client id; see divine_defiance.lua.
spell:id(309)
spell:cooldown(2 * 1000)
spell:groupCooldown(2 * 1000, 2 * 1000)
spell:level(20)
spell:mana(400)
spell:isSelfTarget(true)
spell:isAggressive(false)
spell:isPremium(true)

spell:register()
