-- Ethereal Barrage (15.25.3a4a52). Paladin, level 60, 135 mana, 4s cooldown.
--
-- Physical damage on the target and the 21-square area around it, base power 40,
-- scaling with Distance Fighting and the equipped weapon in the datapack's base-power
-- form.
--
-- AIMING - supported subset: one of the update's three modes, "under the selected
-- target"; the crosshair and cursor-position modes need a client packet this server
-- does not have. See divine_barrage.lua.
-- FIDELITY_BLOCKER — TARGETING_PROTOCOL_EVIDENCE_REQUIRED.
local SPELL_BASE_POWER = 40

local area = createCombatArea({
	{ 0, 1, 1, 1, 0 },
	{ 1, 1, 1, 1, 1 },
	{ 1, 1, 3, 1, 1 },
	{ 1, 1, 1, 1, 1 },
	{ 0, 1, 1, 1, 0 },
})

local combat = Combat()
combat:setParameter(COMBAT_PARAM_TYPE, COMBAT_PHYSICALDAMAGE)
combat:setParameter(COMBAT_PARAM_EFFECT, CONST_ME_GROUNDSHAKER)
combat:setParameter(COMBAT_PARAM_DISTANCEEFFECT, CONST_ANI_ARROW)
combat:setParameter(COMBAT_PARAM_BLOCKARMOR, 1)
combat:setParameter(COMBAT_PARAM_USECHARGES, 1)
combat:setArea(area)

function onGetFormulaValues(player, skill, attack, factor)
	local damage = SPELL_BASE_POWER * (skill / 100) * (attack / 10) + player:calculateFlatDamageHealing()
	return -(damage - damage / 10), -(damage + damage / 10)
end

combat:setCallback(CALLBACK_PARAM_SKILLVALUE, "onGetFormulaValues")

local spell = Spell("instant")

function spell.onCastSpell(creature, var)
	return combat:execute(creature, var)
end

spell:group("attack")
spell:id(304)
spell:name("Ethereal Barrage")
spell:words("exori dir moe")
spell:level(60)
spell:mana(135)
spell:isPremium(true)
spell:range(7)
spell:needTarget(true)
spell:needWeapon(true)
spell:blockWalls(true)
spell:cooldown(4 * 1000)
spell:groupCooldown(2 * 1000)
spell:vocation("paladin;true", "royal paladin;true")
spell:register()
