-- Master of Decay (15.25.3a4a52). Sorcerer elemental stance, level 20, 400 mana. See
-- data/libs/systems/stance.lua.
--
-- Two effects. "+30% critical extra damage on death spells" is an element critical bonus on the
-- condition, in basis points, applied next to the weapon proficiency's own element
-- critical when a spell's critical is rolled - for instant spells whose NATURAL
-- element is death only (Player::applyConditionElementCritical). A death rune, a
-- wand hit, and a spell of another element converted to death get nothing.
--
-- The other lives in Combat::getCombatDamage: after a death spell, the next spell
-- of another element is converted to death. The engine reads that off the stance
-- condition itself - holding this subId is the whole flag - so nothing here has
-- to be set for it.
--
-- Elemental and Crippling are separate families, so a Sorcerer may hold one of
-- each; casting another Master of * replaces this one. A conversion this stance
-- armed is disarmed the moment the stance comes off - toggled off or replaced -
-- in ConditionAttributes::endCondition; a Crippling or General stance changing
-- leaves it armed.
local function build()
	return Stance.condition(AttrSubId_StanceMasterOfDecay, function(condition)
		condition:setParameter(CONDITION_PARAM_ELEMENT_CRITICAL_DAMAGE_DEATH, 3000)
	end)
end

local spell = Spell("instant")

function spell.onCastSpell(creature, variant)
	return Stance.cast(creature, AttrSubId_StanceMasterOfDecay, Stance.Family.Elemental, build, CONST_ME_MORTAREA)
end

spell:name("Master of Decay")
spell:words("uteta mort")
spell:group("support", "focus")
spell:vocation("sorcerer;true", "master sorcerer;true")
-- Canary-internal spell id, NOT the official CipSoft id; see divine_defiance.lua.
spell:id(311)
-- Cooldowns: 30s own, 2s Support, 30s on the Elemental stance family; see master_of_flames.lua.
spell:cooldown(30 * 1000)
spell:groupCooldown(2 * 1000, 30 * 1000)
spell:level(20)
spell:mana(400)
spell:isSelfTarget(true)
spell:isAggressive(false)
spell:isPremium(true)

spell:register()
