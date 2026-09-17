-- Shared Conservation (15.25). Druid group-healing stance. See
-- data/libs/systems/stance.lua.
--
-- Two effects, and the condition itself carries no parameter: holding this subId is
-- the whole flag.
--
-- +10% self-healing lives in the engine, Player::applySharedConservationSelfHeal,
-- applied from Game::combatChangeHealth where healer and target are both known:
-- healing spells (instant or rune) the Druid casts on themselves. A heal from
-- someone else, a heal the Druid casts on someone else, and a potion get nothing.
--
-- The other - Heal Friend and Nature's Embrace also heal a second party member on
-- screen for 30% of the amount - lives in those two spells, which ask
-- Stance.sharedConservationTarget for whom to heal.
local function build()
	return Stance.condition(AttrSubId_StanceSharedConservation, function(condition) end)
end

local spell = Spell("instant")

function spell.onCastSpell(creature, variant)
	return Stance.cast(creature, AttrSubId_StanceSharedConservation, Stance.Family.General, build, CONST_ME_MAGIC_BLUE)
end

spell:name("Shared Conservation")
spell:words("utura sio")
spell:group("support", "focus")
spell:vocation("druid;true", "elder druid;true")
-- Canary-internal spell id, NOT the official CipSoft id; see divine_defiance.lua.
spell:id(300)
-- Cooldowns: 10s own, 2s Support, 10s on the stance family (secondary group Focus).
spell:cooldown(10 * 1000)
spell:groupCooldown(2 * 1000, 10 * 1000)
spell:level(20)
spell:mana(400)
spell:isSelfTarget(true)
spell:isAggressive(false)
spell:isPremium(true)

spell:register()
