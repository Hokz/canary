-- Forked Glacier (15.25.3a4a52). Druid, level 90, 180 mana, 6s cooldown.
--
-- Ice damage on the target and up to 6 additional nearby targets: a chain of seven,
-- in the shape Chained Penance already uses. Base power 97 in the datapack's
-- level/magic-level form. The Wheel's "Forked Spells" augment II adds a target.
local combat = Combat()
combat:setParameter(COMBAT_PARAM_TYPE, COMBAT_ICEDAMAGE)
combat:setParameter(COMBAT_PARAM_EFFECT, CONST_ME_ICEATTACK)
combat:setParameter(COMBAT_PARAM_DISTANCEEFFECT, CONST_ANI_ICE)
combat:setParameter(COMBAT_PARAM_CHAIN_EFFECT, CONST_ME_ICEATTACK)

function onGetFormulaValues(player, level, maglevel)
	local min = (level / 5) + (maglevel * 3.9)
	local max = (level / 5) + (maglevel * 6.4)
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
	local targets = 7
	local player = creature:getPlayer()
	if player then
		targets = targets + player:getWheelSpellAdditionalTarget("Forked Glacier")
	end
	return targets, 3, false
end

combat:setCallback(CALLBACK_PARAM_CHAINVALUE, "getChainValue")

local spell = Spell("instant")

function spell.onCastSpell(creature, var)
	return combat:execute(creature, var)
end

spell:group("attack")
spell:id(306)
spell:name("Forked Glacier")
spell:words("exevo fur frigo")
spell:level(90)
spell:mana(180)
spell:isPremium(true)
spell:range(5)
spell:needTarget(true)
spell:blockWalls(true)
spell:cooldown(6 * 1000)
spell:groupCooldown(2 * 1000)
spell:vocation("druid;true", "elder druid;true")
spell:register()
