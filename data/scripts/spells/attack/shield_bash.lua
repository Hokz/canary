-- Shield Bash (15.25.3a4a52). Knight, level 18, 30 mana, 4s cooldown.
--
-- Physical damage whose base is the equipped shield's defence rather than the
-- weapon's attack: base power 55, read through the Shielding skill and the shield's
-- defence value in the same shape the datapack's other base-power spells use. No
-- shield equipped means no damage, which is the spell refusing rather than falling
-- back to the weapon.
--
-- The hit also weakens the target: "the target's next auto attack within 10 seconds
-- deals 50% less". The engine has a damage-dealt debuff (BUFF_DAMAGEDEALT) but not a
-- "next auto attack only" one, so this is a 10-second -50% to everything the target
-- deals. Stated here because it is stronger than the official rule.
local SPELL_BASE_POWER = 55

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
-- Not the official client id; the 15.25 spell id table was not available.
spell:id(301)
spell:name("Shield Bash")
spell:words("exori ico scu")
spell:level(18)
spell:mana(30)
spell:isPremium(true)
spell:range(1)
spell:needTarget(true)
spell:blockWalls(true)
spell:cooldown(4 * 1000)
spell:groupCooldown(2 * 1000)
spell:vocation("knight;true", "elite knight;true")
spell:register()
