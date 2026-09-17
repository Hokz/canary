-- Shatterstorm arrow (15.25.3a4a52). A 13-square area arrow, physical, the entry-level one at level 50.
-- Same shape as the diamond arrow script, with the 13-square diamond the update
-- describes instead of the diamond arrow's 21.
local area = createCombatArea({
	{ 0, 0, 1, 0, 0 },
	{ 0, 1, 1, 1, 0 },
	{ 1, 1, 3, 1, 1 },
	{ 0, 1, 1, 1, 0 },
	{ 0, 0, 1, 0, 0 },
})

local combat = Combat()
combat:setParameter(COMBAT_PARAM_TYPE, COMBAT_PHYSICALDAMAGE)
combat:setParameter(COMBAT_PARAM_EFFECT, CONST_ME_GROUNDSHAKER)
combat:setParameter(COMBAT_PARAM_DISTANCEEFFECT, CONST_ANI_DIAMONDARROW)
combat:setParameter(COMBAT_PARAM_CASTSOUND, SOUND_EFFECT_TYPE_DIST_ATK_BOW)
combat:setParameter(COMBAT_PARAM_BLOCKARMOR, true)

function onGetFormulaValues(player, skill, attack, factor)
	local distanceSkill = player:getEffectiveSkillLevel(SKILL_DISTANCE)
	local min = (player:getLevel() / 5)
	local max = (0.09 * factor) * distanceSkill * attack + (player:getLevel() / 5)
	return -min, -max
end

combat:setCallback(CALLBACK_PARAM_SKILLVALUE, "onGetFormulaValues")
combat:setArea(area)

local arrow = Weapon(WEAPON_AMMO)

function arrow.onUseWeapon(player, variant)
	return combat:execute(player, variant)
end

arrow:id(53168)
arrow:level(50)
arrow:attack(27)
arrow:action("removecount")
arrow:ammoType("arrow")
arrow:shootType(CONST_ANI_DIAMONDARROW)
arrow:maxHitChance(100)
arrow:wieldUnproperly(true)
arrow:register()
