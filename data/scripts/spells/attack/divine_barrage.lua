-- Divine Barrage (15.25.3a4a52). Paladin, level 70, 175 mana, 4s cooldown.
--
-- Holy damage on the target and the area around it - "the same size as Diamond
-- Arrows", so the diamond arrow's 21-square shape. Base power 140 at release,
-- adjusted to 130 in the July balance pass; 130 is the value here, scaling with
-- Magic Level in the level/magic-level form the datapack uses for Divine Caldera:
-- k = 4/140 (min) and 6/140 (max) per point of base power, so 130 -> 3.71 / 5.57,
-- rounded to one decimal.
--
-- AIMING - supported subset, stated exactly: the update gives this spell three
-- modes (crosshair / use-with, the cursor position, under the selected target or
-- under the character without one). This server implements ONE: under the selected
-- target - the spell needs a target and the area is centred on it. The other two
-- need the client to send a position with an instant spell, and this server's
-- protocol has no such packet; none is invented here.
-- FIDELITY_BLOCKER — TARGETING_PROTOCOL_EVIDENCE_REQUIRED.
local area = createCombatArea({
	{ 0, 1, 1, 1, 0 },
	{ 1, 1, 1, 1, 1 },
	{ 1, 1, 3, 1, 1 },
	{ 1, 1, 1, 1, 1 },
	{ 0, 1, 1, 1, 0 },
})

local combat = Combat()
combat:setParameter(COMBAT_PARAM_TYPE, COMBAT_HOLYDAMAGE)
combat:setParameter(COMBAT_PARAM_EFFECT, CONST_ME_HOLYAREA)
combat:setParameter(COMBAT_PARAM_DISTANCEEFFECT, CONST_ANI_HOLY)
combat:setArea(area)

function onGetFormulaValues(player, level, maglevel)
	local min = (level / 5) + (maglevel * 3.7)
	local max = (level / 5) + (maglevel * 5.6)
	return -min, -max
end

combat:setCallback(CALLBACK_PARAM_LEVELMAGICVALUE, "onGetFormulaValues")

local spell = Spell("instant")

function spell.onCastSpell(creature, var)
	return combat:execute(creature, var)
end

spell:group("attack")
spell:id(303)
spell:name("Divine Barrage")
spell:words("exori dir san")
spell:level(70)
spell:mana(175)
spell:isPremium(true)
spell:range(7)
spell:needTarget(true)
spell:blockWalls(true)
spell:cooldown(4 * 1000)
spell:groupCooldown(2 * 1000)
spell:vocation("paladin;true", "royal paladin;true")
spell:register()
