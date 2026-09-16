-- Shared Conservation (15.25). Druid group-healing stance. See
-- data/libs/systems/stance.lua.
--
-- Two effects. The +10% self-healing lives on the condition. The other - Heal Friend
-- and Nature's Embrace also heal a second party member on screen for 30% of the
-- amount - lives in those two spells, which ask Stance.sharedConservationTarget for
-- whom to heal. The stance itself only has to exist for that to switch on.
--
-- Approximation, stated: the engine has BUFF_HEALINGRECEIVED (everything that heals
-- this player) but nothing narrower for "healing you cast on yourself", so the +10%
-- also applies to heals the Druid receives from others.
local function build()
	return Stance.condition(AttrSubId_StanceSharedConservation, function(condition)
		condition:setParameter(CONDITION_PARAM_BUFF_HEALINGRECEIVED, 110)
	end)
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
spell:cooldown(2 * 1000)
spell:groupCooldown(2 * 1000, 2 * 1000)
spell:level(20)
spell:mana(400)
spell:isSelfTarget(true)
spell:isAggressive(false)
spell:isPremium(true)

spell:register()
