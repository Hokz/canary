-- Death Echo (15.25.3a4a52). Sorcerer, level 120, 150 mana, 6s cooldown.
--
-- Death damage in a 5x5 around the caster, then, after a short interval, a second
-- impact in a larger area. Base power 85 for the first hit, in the datapack's
-- level/magic-level form. The update does not state the second impact's power, only
-- that it is "additional damage" over a larger area: half of the first, one second
-- later, in the 7x7. Stated here because the half is a choice, not a sourced number.
function onGetFormulaValues(player, level, maglevel)
	local min = (level / 5) + (maglevel * 3.4)
	local max = (level / 5) + (maglevel * 5.6)
	return -min, -max
end

function onGetEchoFormulaValues(player, level, maglevel)
	local min, max = onGetFormulaValues(player, level, maglevel)
	return min * 0.5, max * 0.5
end

local combat = Combat()
combat:setParameter(COMBAT_PARAM_TYPE, COMBAT_DEATHDAMAGE)
combat:setParameter(COMBAT_PARAM_EFFECT, CONST_ME_MORTAREA)
combat:setArea(createCombatArea(AREA_CIRCLE2X2))
combat:setCallback(CALLBACK_PARAM_LEVELMAGICVALUE, "onGetFormulaValues")

local echo = Combat()
echo:setParameter(COMBAT_PARAM_TYPE, COMBAT_DEATHDAMAGE)
echo:setParameter(COMBAT_PARAM_EFFECT, CONST_ME_MORTAREA)
echo:setArea(createCombatArea(AREA_CIRCLE3X3))
echo:setCallback(CALLBACK_PARAM_LEVELMAGICVALUE, "onGetEchoFormulaValues")

local function secondImpact(playerId, position)
	local player = Player(playerId)
	if not player then
		return
	end
	echo:execute(player, Variant(position))
end

local spell = Spell("instant")

function spell.onCastSpell(creature, var)
	if not combat:execute(creature, var) then
		return false
	end
	-- The echo lands where the caster stood, not where they are a second later.
	addEvent(secondImpact, 1000, creature:getId(), creature:getPosition())
	return true
end

spell:group("attack")
spell:id(305)
spell:name("Death Echo")
spell:words("exevo mort ora")
spell:level(120)
spell:mana(150)
spell:isPremium(true)
spell:isSelfTarget(true)
spell:cooldown(6 * 1000)
spell:groupCooldown(2 * 1000)
spell:vocation("sorcerer;true", "master sorcerer;true")
spell:register()
