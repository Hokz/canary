-- Divine Barrage (15.25.3a4a52). Paladin, level 70, 175 mana, 4s cooldown.
--
-- Holy damage on the target and the area around it - "the same size as Diamond
-- Arrows", so the diamond arrow's 21-square shape. Base power 140, scaling with
-- Magic Level, expressed here in the level/magic-level form the datapack uses for
-- Divine Caldera, scaled to 140/160 of Caldera's post-update numbers.
--
-- The update gives it three aiming modes (crosshair, cursor position, under the
-- target). This implements the third: the spell needs a target and the area is
-- centred on it. The other two need a position sent by the client, which is the
-- protocol layer's concern.
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
	local min = (level / 5) + (maglevel * 4.0)
	local max = (level / 5) + (maglevel * 6.0)
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
