local combat = Combat()
combat:setParameter(COMBAT_PARAM_TYPE, COMBAT_HEALING)
combat:setParameter(COMBAT_PARAM_EFFECT, CONST_ME_MAGIC_GREEN)
combat:setParameter(COMBAT_PARAM_DISPEL, CONDITION_PARALYZE)
combat:setParameter(COMBAT_PARAM_AGGRESSIVE, false)

-- A local, so the 30% companion formula below reads THIS spell's numbers. Every
-- healing spell defines a global onGetFormulaValues; at call time that name resolves
-- to whichever file loaded last, so it cannot be called by name from here.
local function formula(level, magicLevel)
	local min = (level * 0.2 + magicLevel * 10) + 3
	local max = (level * 0.2 + magicLevel * 14) + 5
	return min, max
end

function onGetFormulaValues(player, level, magicLevel)
	return formula(level, magicLevel)
end

combat:setCallback(CALLBACK_PARAM_LEVELMAGICVALUE, "onGetFormulaValues")

-- Shared Conservation (15.25): with the stance on, a second party member on screen
-- is also healed, for 30% of the amount. Same formula at 30%, in its own Combat, so
-- the companion heal runs through the same healing pipeline as the main one.
local sharedCombat = Combat()
sharedCombat:setParameter(COMBAT_PARAM_TYPE, COMBAT_HEALING)
sharedCombat:setParameter(COMBAT_PARAM_EFFECT, CONST_ME_MAGIC_GREEN)
sharedCombat:setParameter(COMBAT_PARAM_AGGRESSIVE, false)

function onGetSharedFormulaValues(player, level, magicLevel)
	local min, max = formula(level, magicLevel)
	return min * 0.3, max * 0.3
end

sharedCombat:setCallback(CALLBACK_PARAM_LEVELMAGICVALUE, "onGetSharedFormulaValues")

local spell = Spell("instant")

function spell.onCastSpell(creature, variant)
	creature:getPosition():sendMagicEffect(CONST_ME_MAGIC_BLUE)
	if not combat:execute(creature, variant) then
		return false
	end

	local target = Creature(variant:getNumber())
	if target then
		Stance.castSharedConservation(sharedCombat, creature, Stance.sharedConservationTarget(creature, target))
	end
	return true
end

spell:name("Heal Friend")
spell:words("exura sio")
spell:group("healing")
spell:vocation("druid;true", "elder druid;true")
spell:castSound(SOUND_EFFECT_TYPE_SPELL_HEAL_FRIEND)
spell:id(84)
spell:cooldown(1000)
spell:groupCooldown(1000)
spell:level(18)
spell:mana(120)
spell:needTarget(true)
spell:hasParams(true)
spell:hasPlayerNameParam(true)
spell:allowOnSelf(false)
spell:isAggressive(false)
spell:isPremium(true)
spell:register()
