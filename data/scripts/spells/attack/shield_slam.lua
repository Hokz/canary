-- Shield Slam (15.25.3a4a52). Knight, level 30, 110 mana, 6s cooldown.
--
-- Shield Bash's area sibling: hits every adjacent enemy, base power 52, damage from
-- the shield's defence, and the same next-auto-attack weakening on each target,
-- each creature carrying its own. See shield_bash.lua for how the shield is read.
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

-- The hit weakens the target's NEXT auto attack by 50% for up to 10 seconds. That
-- is a consumable, per-creature status in the engine (setNextAutoAttackDebuff):
-- the first melee, ranged or fist attack the creature makes is reduced and the
-- status is spent; spells and runes it casts are untouched; ten seconds with no
-- auto attack and it expires. Shield Slam's Augment II deepens the reduction to
-- 75% - read through the Wheel grade, which is NONE until the Wheel data carries
-- this spell.
local function weakenNextAutoAttack(creature, target)
	if not target or target:isPlayer() then
		return true
	end
	local percent = 50
	if creature:isPlayer() and creature:upgradeSpellsWOD("Shield Slam") == WHEEL_GRADE_UPGRADED then
		percent = 75
	end
	target:setNextAutoAttackDebuff(percent, 10 * 1000)
	return true
end

function onTargetCreature(creature, target)
	return weakenNextAutoAttack(creature, target)
end

local combat = Combat()
combat:setParameter(COMBAT_PARAM_TYPE, COMBAT_PHYSICALDAMAGE)
combat:setParameter(COMBAT_PARAM_EFFECT, CONST_ME_BLOW_WHITE)
combat:setParameter(COMBAT_PARAM_BLOCKARMOR, 1)
combat:setArea(createCombatArea(AREA_SQUARE1X1))
combat:setCallback(CALLBACK_PARAM_TARGETCREATURE, "onTargetCreature")

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
