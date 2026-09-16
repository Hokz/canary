-- Shield Slam (15.25.3a4a52). Knight, level 30, 110 mana, 6s cooldown.
--
-- Shield Bash's area sibling: hits every adjacent enemy, base power 52, damage from
-- the shield's defence, and the same 10-second weakening on each target. See
-- shield_bash.lua for how the shield is read and why the debuff is broader than the
-- official "next auto attack".
local SPELL_BASE_POWER = 52

local function shieldDefense(player)
	for _, slot in ipairs({ CONST_SLOT_LEFT, CONST_SLOT_RIGHT }) do
		local item = player:getSlotItem(slot)
		if item and item:getType():getWeaponType() == WEAPON_SHIELD then
			return item:getType():getDefense()
		end
	end
	return 0
end

local weaken = Condition(CONDITION_ATTRIBUTES)
weaken:setParameter(CONDITION_PARAM_TICKS, 10 * 1000)
weaken:setParameter(CONDITION_PARAM_BUFF_DAMAGEDEALT, 50)

local combat = Combat()
combat:setParameter(COMBAT_PARAM_TYPE, COMBAT_PHYSICALDAMAGE)
combat:setParameter(COMBAT_PARAM_EFFECT, CONST_ME_BLOW_WHITE)
combat:setParameter(COMBAT_PARAM_BLOCKARMOR, 1)
combat:setArea(createCombatArea(AREA_SQUARE1X1))
combat:addCondition(weaken)

function onGetFormulaValues(player, skill, attack, factor)
	local defense = shieldDefense(player)
	local shielding = player:getEffectiveSkillLevel(SKILL_SHIELD)
	local damage = SPELL_BASE_POWER * (shielding / 100) * (defense / 10) + player:calculateFlatDamageHealing()
	return -(damage - damage / 10), -(damage + damage / 10)
end

combat:setCallback(CALLBACK_PARAM_SKILLVALUE, "onGetFormulaValues")

local spell = Spell("instant")

function spell.onCastSpell(creature, var)
	if shieldDefense(creature) == 0 then
		creature:sendCancelMessage("You need a shield equipped to cast this spell.")
		creature:getPosition():sendMagicEffect(CONST_ME_POFF)
		return false
	end
	return combat:execute(creature, var)
end

spell:group("attack")
spell:id(302)
spell:name("Shield Slam")
spell:words("exori scu")
spell:level(30)
spell:mana(110)
spell:isPremium(true)
spell:isSelfTarget(true)
spell:cooldown(6 * 1000)
spell:groupCooldown(2 * 1000)
spell:vocation("knight;true", "elite knight;true")
spell:register()
