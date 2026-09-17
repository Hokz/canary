-- Thousand Fist Blows (15.25.3a4a52). Monk, level 120, 145 mana, 12s cooldown.
--
-- A Builder: raises harmony when cast. Physical damage on the target and the area
-- around it, base power 62 in the datapack's base-power form.
--
-- AIMING - supported subset: one of the update's three modes, "under the selected
-- target"; the crosshair and cursor-position modes need a client packet this server
-- does not have. See divine_barrage.lua.
-- FIDELITY_BLOCKER — TARGETING_PROTOCOL_EVIDENCE_REQUIRED.
local SPELL_BASE_POWER = 62

local combat = Combat()
combat:setParameter(COMBAT_PARAM_TYPE, COMBAT_PHYSICALDAMAGE)
combat:setParameter(COMBAT_PARAM_EFFECT, CONST_ME_BLOW_WHITE)
combat:setParameter(COMBAT_PARAM_BLOCKARMOR, 1)
combat:setArea(createCombatArea(AREA_CIRCLE2X2))

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
spell:id(308)
spell:name("Thousand Fist Blows")
spell:words("exori mas amp pug")
spell:level(120)
spell:mana(145)
spell:isPremium(true)
spell:range(5)
spell:needTarget(true)
spell:blockWalls(true)
spell:cooldown(12 * 1000)
spell:groupCooldown(2 * 1000)
spell:monkSpellType(MonkSpell_Builder)
spell:vocation("monk;true", "exalted monk;true")
spell:register()
