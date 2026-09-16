-- Forked Thorns (15.25.3a4a52). Druid, level 80, 180 mana, 6s cooldown.
--
-- Earth damage on the target and up to 5 additional nearby targets: a chain of six.
-- Base power 105. See forked_glacier.lua.
local combat = Combat()
combat:setParameter(COMBAT_PARAM_TYPE, COMBAT_EARTHDAMAGE)
combat:setParameter(COMBAT_PARAM_EFFECT, CONST_ME_GREEN_RINGS)
combat:setParameter(COMBAT_PARAM_DISTANCEEFFECT, CONST_ANI_EARTH)
combat:setParameter(COMBAT_PARAM_CHAIN_EFFECT, CONST_ME_GREEN_RINGS)

function onGetFormulaValues(player, level, maglevel)
	local min = (level / 5) + (maglevel * 4.2)
	local max = (level / 5) + (maglevel * 6.9)
	return -min, -max
end

combat:setCallback(CALLBACK_PARAM_LEVELMAGICVALUE, "onGetFormulaValues")

function canChain(creature, target)
	if target:isNpc() or creature == target or target:getTile():hasFlag(TILESTATE_PROTECTIONZONE) then
		return false
	end
	return true
end

combat:setCallback(CALLBACK_PARAM_CHAINPICKER, "canChain")

function getChainValue(creature)
	local targets = 6
	local player = creature:getPlayer()
	if player then
		targets = targets + player:getWheelSpellAdditionalTarget("Forked Thorns")
	end
	return targets, 3, false
end

combat:setCallback(CALLBACK_PARAM_CHAINVALUE, "getChainValue")

local spell = Spell("instant")

function spell.onCastSpell(creature, var)
	return combat:execute(creature, var)
end

spell:group("attack")
spell:id(307)
spell:name("Forked Thorns")
spell:words("exevo fur tera")
spell:level(80)
spell:mana(180)
spell:isPremium(true)
spell:range(5)
spell:needTarget(true)
spell:blockWalls(true)
spell:cooldown(6 * 1000)
spell:groupCooldown(2 * 1000)
spell:vocation("druid;true", "elder druid;true")
spell:register()
