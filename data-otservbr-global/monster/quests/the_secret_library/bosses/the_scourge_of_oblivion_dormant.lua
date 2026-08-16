-- The Scourge of Oblivion - pre-fight placeholder form, spawned immediately by the existing
-- BossLever (actions_the_scourge_of_oblivion.lua) the moment the lever is pulled, representing "the
-- leader of the invasion" not yet having joined the fight - matches the reference exactly ("the
-- leader of the invasion finally joins the battle" only fires once all 4 wing bosses are cleared).
-- 100% immune to all damage types, same technique already used repeatedly this session (Dangerous
-- Depths' Dormant Morgathla, this quest's own Fire Empowered Duke-style forms) for "not yet a real
-- fight" placeholders. Swapped to the real "The Scourge of Oblivion" type (preserving current HP,
-- i.e. full HP since this form is never damaged) by InvasionCheckWingsCleared once all 4 wings die.
local mType = Game.createMonsterType("The Scourge of Oblivion (Dormant)")
local monster = {}

monster.description = "The Scourge Of Oblivion"
monster.experience = 0
monster.outfit = {
	lookType = 875,
	lookHead = 79,
	lookBody = 3,
	lookLegs = 4,
	lookFeet = 2,
	lookAddons = 3,
	lookMount = 0,
}

-- CORRECTION (final fidelity pass, section 6): maxHealth kept consistent with the base "The Scourge
-- of Oblivion" form (650000, PROVEN_REFERENCE) - setType transforms preserve raw current HP.
monster.health = 650000
monster.maxHealth = 650000
monster.race = "venom"
monster.corpse = 0
monster.speed = 0
monster.manaCost = 0

monster.changeTarget = {
	interval = 4000,
	chance = 0,
}

monster.strategiesTarget = {
	nearest = 100,
}

monster.flags = {
	summonable = false,
	attackable = true,
	hostile = false,
	convinceable = false,
	pushable = false,
	rewardBoss = false,
	illusionable = false,
	canPushItems = false,
	canPushCreatures = false,
	staticAttackChance = 0,
	targetDistance = 1,
	runHealth = 0,
	healthHidden = false,
	isBlockable = false,
	canWalkOnEnergy = true,
	canWalkOnFire = true,
	canWalkOnPoison = true,
}

monster.light = {
	level = 0,
	color = 0,
}

monster.voices = {
	interval = 5000,
	chance = 5,
	{ text = "You are not yet worthy of my attention.", yell = false },
}

monster.loot = {}

monster.attacks = {}

monster.defenses = {
	defense = 0,
	armor = 0,
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
