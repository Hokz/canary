-- Crippling stances (15.25.3a4a52): Aura of Sapped Strength and Aura of Exposed
-- Weakness. With one held, every attack, spell and rune the Sorcerer lands applies
-- its debuff to the enemy hit. This fires once per target of every combat, before
-- the hit resolves, which is the one place that sees each pair exactly once.
--
-- Approximations, stated: the engine's damage buffs are not split by damage type,
-- so "8% more elemental damage taken" is 8% more of all damage taken; and a hit that
-- is later blocked or dodged still applied the debuff, because this runs before the
-- roll. Durations follow the old targeted Sap Strength / Expose Weakness: 16s.
local DEBUFF_TICKS = 16 * 1000

local function debuff(param, value)
	local condition = Condition(CONDITION_ATTRIBUTES)
	condition:setParameter(CONDITION_PARAM_TICKS, DEBUFF_TICKS)
	condition:setParameter(param, value)
	return condition
end

local sappedStrength = debuff(CONDITION_PARAM_BUFF_DAMAGEDEALT, 90)
local exposedWeakness = debuff(CONDITION_PARAM_BUFF_DAMAGERECEIVED, 108)

local callback = EventCallback("CripplingStancesOnTargetCombat")

function callback.creatureOnTargetCombat(creature, target)
	if not creature or not target or not creature:isPlayer() or not target:isMonster() or target:getMaster() then
		return RETURNVALUE_NOERROR
	end

	if Stance.active(creature, AttrSubId_StanceSappedStrength) then
		target:addCondition(sappedStrength)
	end
	if Stance.active(creature, AttrSubId_StanceExposedWeakness) then
		target:addCondition(exposedWeakness)
	end
	return RETURNVALUE_NOERROR
end

callback:register()
