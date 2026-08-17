-- The Spellstealer - RED colored phase. Immune while colored; luring it onto the matching red
-- teleport (movements_invasion_start.lua) swaps it back to the base grey/vulnerable form, preserving
-- current HP - see creaturescripts_invasion_wings.lua's InvasionSpellstealerColorSwap.
local mType = Game.createMonsterType("The Spellstealer (red)")
local monster = {}

monster.description = "The Spellstealer"
-- CORRECTION (final P1 surgical correction, section 1): PROVEN_REFERENCE - "Summon Creature (4-5 Demon
-- Slave)" is a general ability of the boss (own monster page's ability list), not restricted to any one
-- color state - wired here too so the summon mechanic keeps working while colored/invulnerable.
monster.events = {
	"InvasionSpellstealerSummon",
}
monster.experience = 0
monster.outfit = {
	lookType = 12,
	lookHead = 81,
	lookBody = 100,
	lookLegs = 0,
	lookFeet = 0,
	lookAddons = 0,
	lookMount = 0,
}

-- CORRECTION (final fidelity pass, section 6): maxHealth kept consistent with the base "The
-- Spellstealer" form (280000) - setType-based transforms preserve raw current HP across a swap, so a
-- mismatched maxHealth here would clamp/distort HP on transform.
monster.health = 280000
monster.maxHealth = 280000
monster.race = "undead"
monster.corpse = 0
monster.speed = 175
monster.manaCost = 0

monster.changeTarget = {
	interval = 5000,
	chance = 8,
}

monster.strategiesTarget = {
	nearest = 100,
}

monster.flags = {
	summonable = false,
	attackable = true,
	hostile = true,
	convinceable = false,
	pushable = false,
	rewardBoss = false,
	illusionable = false,
	canPushItems = true,
	canPushCreatures = true,
	staticAttackChance = 90,
	targetDistance = 1,
	runHealth = 0,
	healthHidden = false,
	isBlockable = false,
	canWalkOnEnergy = true,
	canWalkOnFire = true,
	canWalkOnPoison = true,
}

monster.light = {
	level = 3,
	color = 132, -- red
}

monster.voices = {
	interval = 5000,
	chance = 10,
}

monster.loot = {}

monster.attacks = {
	{ name = "melee", interval = 2000, chance = 100, minDamage = 0, maxDamage = -200 },
}

monster.defenses = {
	defense = 33,
	armor = 28,
}

monster.elements = {
	{ type = COMBAT_PHYSICALDAMAGE, percent = 100 },
	{ type = COMBAT_ENERGYDAMAGE, percent = 100 },
	{ type = COMBAT_EARTHDAMAGE, percent = 100 },
	{ type = COMBAT_FIREDAMAGE, percent = 100 },
	{ type = COMBAT_LIFEDRAIN, percent = 100 },
	{ type = COMBAT_MANADRAIN, percent = 100 },
	{ type = COMBAT_DROWNDAMAGE, percent = 100 },
	{ type = COMBAT_ICEDAMAGE, percent = 100 },
	{ type = COMBAT_HOLYDAMAGE, percent = 100 },
	{ type = COMBAT_DEATHDAMAGE, percent = 100 },
}

monster.immunities = {
	{ type = "paralyze", condition = true },
	{ type = "outfit", condition = false },
	{ type = "invisible", condition = true },
	{ type = "bleed", condition = false },
}

mType:register(monster)
