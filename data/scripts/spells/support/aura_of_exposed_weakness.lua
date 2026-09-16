-- Aura of Exposed Weakness (15.25.3a4a52). Sorcerer crippling stance, level 175, 1500 mana. See
-- data/libs/systems/stance.lua.
--
-- The condition carries no effect of its own. What the stance does - every attack,
-- spell and rune the Sorcerer lands applies 8% more elemental damage taken to the enemy hit - lives in
-- data/scripts/eventcallbacks/creature/on_target_combat_stances.lua, which fires
-- once per target of every combat and looks for this subId on the attacker.
--
-- Replaces the targeted Expose Weakness spell of earlier versions; that script is left in
-- place untouched, since removing a spell players may have is a separate decision.
local function build()
	return Stance.condition(AttrSubId_StanceExposedWeakness, function(condition) end)
end

local spell = Spell("instant")

function spell.onCastSpell(creature, variant)
	return Stance.cast(creature, AttrSubId_StanceExposedWeakness, Stance.Family.Crippling, build, CONST_ME_MORTAREA)
end

spell:name("Aura of Exposed Weakness")
spell:words("exori moe tempo")
spell:group("support", "crippling")
spell:vocation("sorcerer;true", "master sorcerer;true")
-- Canary-internal spell id, NOT the official CipSoft id; see divine_defiance.lua.
spell:id(313)
spell:cooldown(2 * 1000)
spell:groupCooldown(2 * 1000, 2 * 1000)
spell:level(175)
spell:mana(1500)
spell:isSelfTarget(true)
spell:isAggressive(false)
spell:isPremium(true)

spell:register()
