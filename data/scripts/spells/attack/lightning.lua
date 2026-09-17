local combat = Combat()
combat:setParameter(COMBAT_PARAM_TYPE, COMBAT_ENERGYDAMAGE)
combat:setParameter(COMBAT_PARAM_EFFECT, CONST_ME_ENERGYAREA)
combat:setParameter(COMBAT_PARAM_DISTANCEEFFECT, CONST_ANI_ENERGY)
-- 15.25.3a4a52: chains to two additional targets.
combat:setParameter(COMBAT_PARAM_CHAIN_EFFECT, CONST_ME_ENERGYAREA)

function onGetFormulaValues(player, level, maglevel)
	-- 15.25.3a4a52: base power 70 -> 110, expressed in the datapack's level/magic-level form by scaling the magic-level multipliers and constants by the same ratio.
	local min = (level / 5) + (maglevel * 3.5) + 19
	local max = (level / 5) + (maglevel * 5.3) + 33
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
	return 3, 3, false
end

combat:setCallback(CALLBACK_PARAM_CHAINVALUE, "getChainValue")

local spell = Spell("instant")

function spell.onCastSpell(creature, var)
	return combat:execute(creature, var)
end

spell:group("attack", "special")
spell:id(149)
spell:name("Lightning")
spell:words("exori amp vis")
spell:castSound(SOUND_EFFECT_TYPE_SPELL_LIGHTNING)
spell:level(55)
spell:mana(60)
spell:isPremium(true)
spell:range(7)
spell:needTarget(true)
spell:blockWalls(true)
spell:cooldown(8 * 1000)
spell:groupCooldown(2 * 1000, 8 * 1000)

spell:vocation("sorcerer;true", "master sorcerer;true")
spell:register()
