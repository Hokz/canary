-- Crippling stances (15.25.3a4a52): Aura of Sapped Strength and Aura of Exposed
-- Weakness. With one held, every attack, spell and rune the Sorcerer lands applies
-- its debuff to the enemy hit. This fires once per target of every combat, before
-- the hit resolves, which is the one place that sees each pair exactly once.
--
-- Sapped Strength: the enemy deals 10% less. Exposed Weakness: +8% Elemental
-- Pierce against the enemy for 10 seconds - a pierce, not a damage multiplier. It
-- lowers the resistance elemental damage meets on that creature, inside the
-- engine's one resistance calculation, so physical damage gains nothing and an
-- immunity stays an immunity. One approximation remains and is stated: this fires
-- before the hit resolves, so a hit that is then blocked or dodged still applied
-- the debuff.
local SAPPED_STRENGTH_TICKS = 16 * 1000
local EXPOSED_WEAKNESS_TICKS = 10 * 1000

local function debuff(param, value, ticks)
	local condition = Condition(CONDITION_ATTRIBUTES)
	condition:setParameter(CONDITION_PARAM_TICKS, ticks)
	condition:setParameter(param, value)
	return condition
end

local sappedStrength = debuff(CONDITION_PARAM_BUFF_DAMAGEDEALT, 90, SAPPED_STRENGTH_TICKS)
local exposedWeakness = debuff(CONDITION_PARAM_ELEMENTAL_PIERCE_RECEIVED, 8, EXPOSED_WEAKNESS_TICKS)

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
