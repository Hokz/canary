-- Aura of Exposed Weakness (15.25.3a4a52). Sorcerer crippling stance, level 175, 1500 mana. See
-- data/libs/systems/stance.lua.
--
-- The condition carries no effect of its own. What the stance does - every attack,
-- spell and rune the Sorcerer LANDS applies Exposed Weakness (+8% Elemental Pierce
-- against it, for 10s) to the enemy hit - lives in the engine,
-- src/creatures/combat/crippling_aura.cpp, applied from Game::combatChangeHealth
-- after the hit has resolved and taken health. A dodged, blocked or cancelled hit
-- applies nothing; a landed hit refreshes the debuff and never stacks it.
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
-- Cooldowns: 30s own, 2s Support, 30s on the Crippling stance family; see aura_of_sapped_strength.lua.
spell:cooldown(30 * 1000)
spell:groupCooldown(2 * 1000, 30 * 1000)
spell:level(175)
spell:mana(1500)
spell:isSelfTarget(true)
spell:isAggressive(false)
spell:isPremium(true)

spell:register()
