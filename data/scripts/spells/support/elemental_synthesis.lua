-- Elemental Synthesis (15.25). Druid stance. See data/libs/systems/stance.lua.
--
-- 10% of the Druid's Magic Level as additional Magic Level for ice and earth
-- spells. Stored as the recipe (source skill + percentages) and recomputed from the
-- player's current Magic Level at startCondition, so it follows the skill.
local function build()
	return Stance.condition(AttrSubId_StanceElementalSynthesis, function(condition)
		condition:setParameter(CONDITION_PARAM_SPECIALIZED_MAGICLEVEL_SOURCE, SKILL_MAGLEVEL)
		condition:setParameter(CONDITION_PARAM_SPECIALIZED_MAGICLEVEL_ICEPERCENT, 10)
		condition:setParameter(CONDITION_PARAM_SPECIALIZED_MAGICLEVEL_EARTHPERCENT, 10)
	end)
end

local spell = Spell("instant")

function spell.onCastSpell(creature, variant)
	return Stance.cast(creature, AttrSubId_StanceElementalSynthesis, Stance.Family.General, build, CONST_ME_ICEATTACK)
end

spell:name("Elemental Synthesis")
spell:words("utito dru")
spell:group("support", "focus")
spell:vocation("druid;true", "elder druid;true")
-- Canary-internal spell id, NOT the official CipSoft id; see divine_defiance.lua.
spell:id(299)
-- Cooldowns: 10s own, 2s Support, 10s on the stance family, and premium - all four
-- confirmed by the official spell library, which names the secondary group "Stance".
-- The engine's Focus group carries it here because no protocol id for a "Stance"
-- group is evidenced in this server; see data/libs/systems/stance.lua.
spell:cooldown(10 * 1000)
spell:groupCooldown(2 * 1000, 10 * 1000)
spell:level(20)
spell:mana(400)
spell:isSelfTarget(true)
spell:isAggressive(false)
spell:isPremium(true)

spell:register()
