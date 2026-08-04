-- Ratmiral Blackwhiskers / upper deck, stage 3 - the pirate's permanently-respawning parrot,
-- attacking from above with ~500 life drain. The reference says it "isn't visible on the battle
-- list and cannot be killed in any way" - this engine has no way to hide a live creature from the
-- battle list, so this is implemented as unkillable (all damage blocked, matching "cannot be
-- killed") rather than fully invisible-to-UI; a disclosed, minor fidelity gap. See
-- creaturescripts_ratmiral_stages.lua for the periodic life-drain tick and respawn.
local mType = Game.createMonsterType("Ratmiral's Parrot")
local monster = {}

monster.description = "Ratmiral's parrot"
monster.experience = 0
monster.outfit = {
	lookType = 45,
	lookHead = 0,
	lookBody = 0,
	lookLegs = 0,
	lookFeet = 0,
	lookAddons = 0,
	lookMount = 0,
}

monster.health = 1
monster.maxHealth = 1
monster.race = "blood"
monster.corpse = 0
monster.speed = 260
monster.manaCost = 0

monster.changeTarget = {
	interval = 4000,
	chance = 0,
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
	healthHidden = true,
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
	interval = 4000,
	chance = 20,
	{ text = "Squawk!", yell = false },
}

monster.loot = {}
monster.attacks = {}
monster.defenses = {
	defense = 0,
	armor = 0,
}

monster.elements = {
	{ type = COMBAT_PHYSICALDAMAGE, percent = 0 },
	{ type = COMBAT_ENERGYDAMAGE, percent = 0 },
	{ type = COMBAT_EARTHDAMAGE, percent = 0 },
	{ type = COMBAT_FIREDAMAGE, percent = 0 },
	{ type = COMBAT_LIFEDRAIN, percent = 0 },
	{ type = COMBAT_MANADRAIN, percent = 0 },
	{ type = COMBAT_DROWNDAMAGE, percent = 0 },
	{ type = COMBAT_ICEDAMAGE, percent = 0 },
	{ type = COMBAT_HOLYDAMAGE, percent = 0 },
	{ type = COMBAT_DEATHDAMAGE, percent = 0 },
}

monster.immunities = {
	{ type = "paralyze", condition = true },
	{ type = "outfit", condition = false },
	{ type = "invisible", condition = true },
	{ type = "bleed", condition = false },
}

mType:register(monster)
