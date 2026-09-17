-- Divine Defiance (15.25). Paladin defensive stance. See data/libs/systems/stance.lua.
--
-- Numbers from the 15.25.3a4a52 spell table, which is the shipped value: 6% of
-- Distance Fighting as Holy Magic Level, 6% as Healing Magic Level, and 12% dodge
-- against attackers that are not adjacent. The changelog section of the same
-- update announced 7.5% / 7.5% / 15%; those were the test-server numbers.
--
-- The magic level halves are a recipe, not a flat value: the condition stores the
-- source skill and the percentages, and the engine recomputes the flat bonus from
-- the player's current Distance Fighting at startCondition - so the bonus follows
-- the skill across logins. The dodge is applied in Game::combatBlockHit, where the
-- attacker's position is known.
local function build()
	return Stance.condition(AttrSubId_StanceDivineDefiance, function(condition)
		condition:setParameter(CONDITION_PARAM_SPECIALIZED_MAGICLEVEL_SOURCE, SKILL_DISTANCE)
		condition:setParameter(CONDITION_PARAM_SPECIALIZED_MAGICLEVEL_HOLYPERCENT, 6)
		condition:setParameter(CONDITION_PARAM_SPECIALIZED_MAGICLEVEL_HEALINGPERCENT, 6)
		-- basis points: 1200 is 12%
		condition:setParameter(CONDITION_PARAM_DODGE_RANGED, 1200)
	end)
end

local spell = Spell("instant")

function spell.onCastSpell(creature, variant)
	return Stance.cast(creature, AttrSubId_StanceDivineDefiance, Stance.Family.General, build, CONST_ME_HOLYAREA)
end

spell:name("Divine Defiance")
spell:words("utori hur")
spell:group("support", "focus")
spell:vocation("paladin;true", "royal paladin;true")
-- Canary-internal spell id, NOT the official CipSoft id: the 15.25 spell id table was
-- not available. The next free id in this datapack; replace when the official one is proven.
spell:id(298)
-- Cooldowns: 10s own, 2s Support, 10s on the stance family (secondary group Focus).
spell:cooldown(10 * 1000)
spell:groupCooldown(2 * 1000, 10 * 1000)
spell:level(20)
spell:mana(250)
spell:isSelfTarget(true)
spell:isAggressive(false)
spell:isPremium(true)

spell:register()
