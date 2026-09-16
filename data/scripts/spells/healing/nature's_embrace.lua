local combat = Combat()
combat:setParameter(COMBAT_PARAM_TYPE, COMBAT_HEALING)
combat:setParameter(COMBAT_PARAM_EFFECT, CONST_ME_MAGIC_BLUE)
combat:setParameter(COMBAT_PARAM_AGGRESSIVE, 0)
combat:setParameter(COMBAT_PARAM_DISPEL, CONDITION_PARALYZE)

-- 15.25: base healing 650 -> 2000, and the heal is described as more consistent.
-- Kept as a level/magic-level formula in the datapack's own shape; the multiplier
-- was raised in the same proportion the update raised the base power, and the
-- spread between min and max narrowed to match "more consistent".
-- A local, so the companion formula reads THIS spell's numbers; see heal_friend.lua.
local function formula(level, maglevel)
	local min = (level / 2.5) + (maglevel * 62)
	local max = (level / 2.5) + (maglevel * 78)
	return min, max
end

function onGetFormulaValues(player, level, maglevel)
	return formula(level, maglevel)
end

combat:setCallback(CALLBACK_PARAM_LEVELMAGICVALUE, "onGetFormulaValues")

-- Shared Conservation (15.25): see heal_friend.lua.
local sharedCombat = Combat()
sharedCombat:setParameter(COMBAT_PARAM_TYPE, COMBAT_HEALING)
sharedCombat:setParameter(COMBAT_PARAM_EFFECT, CONST_ME_MAGIC_BLUE)
sharedCombat:setParameter(COMBAT_PARAM_AGGRESSIVE, 0)

function onGetSharedFormulaValues(player, level, maglevel)
	local min, max = formula(level, maglevel)
	return min * 0.3, max * 0.3
end

sharedCombat:setCallback(CALLBACK_PARAM_LEVELMAGICVALUE, "onGetSharedFormulaValues")

local spell = Spell("instant")

function spell.onCastSpell(creature, var)
	if creature:isPlayer() and var:getNumber() == creature:getId() then
		creature:sendCancelMessage("You can't cast this spell to yourself.")
		creature:getPosition():sendMagicEffect(CONST_ME_POFF)
		return false
	end

	if not combat:execute(creature, var) then
		return false
	end

	local target = Creature(var:getNumber())
	if target then
		Stance.castSharedConservation(sharedCombat, creature, Stance.sharedConservationTarget(creature, target))
	end
	return true
end

spell:group("healing")
spell:id(242)
spell:name("Nature's Embrace")
spell:words("exura gran sio")
spell:castSound(SOUND_EFFECT_TYPE_SPELL_NATURES_EMBRACE)
spell:level(300)
spell:mana(400)
spell:isPremium(true)
spell:needTarget(true)
spell:cooldown(60 * 1000)
spell:groupCooldown(1 * 1000)
spell:isAggressive(false)
spell:isBlockingWalls(true)
spell:hasParams(true)
spell:hasPlayerNameParam(true)
spell:vocation("druid;true", "elder druid;true")

spell:register()
