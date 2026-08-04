-- The Wreckoning / Tentugly's Head phase 2 - after the head vanishes, tentacles rise on both
-- floors of the ship and must all be destroyed before the head reappears for its final form. See
-- creaturescripts_tentugly_phases.lua. Stats are a reasonable new baseline scaled below the main
-- boss (no comparable "tentacle" monster exists elsewhere in this repo to adapt from).
local mType = Game.createMonsterType("Tentugly's Tentacle")
local monster = {}

monster.description = "a tentugly's tentacle"
monster.experience = 1800
monster.outfit = {
	lookTypeEx = 35105,
}

monster.events = {
	"TentuglyTentacleDeath",
}

monster.health = 6000
monster.maxHealth = 6000
monster.race = "blood"
monster.corpse = 35611 -- "tentacle of Tentugly"
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
	hostile = true,
	convinceable = false,
	pushable = false,
	rewardBoss = false,
	illusionable = false,
	canPushItems = false,
	canPushCreatures = false,
	staticAttackChance = 70,
	targetDistance = 1,
	runHealth = 0,
	healthHidden = false,
	isBlockable = false,
	canWalkOnEnergy = false,
	canWalkOnFire = false,
	canWalkOnPoison = false,
}

monster.light = {
	level = 0,
	color = 0,
}

monster.voices = {
	interval = 5000,
	chance = 10,
}

monster.loot = {}

monster.attacks = {
	{ name = "melee", interval = 2000, chance = 100, minDamage = 0, maxDamage = -300 },
	{ name = "combat", type = COMBAT_ENERGYDAMAGE, interval = 2000, chance = 30, minDamage = -80, maxDamage = -220, range = 4, target = true, effect = CONST_ME_ENERGYHIT },
}

monster.defenses = {
	defense = 40,
	armor = 60,
}

monster.elements = {
	{ type = COMBAT_PHYSICALDAMAGE, percent = 0 },
	{ type = COMBAT_ENERGYDAMAGE, percent = 30 },
	{ type = COMBAT_EARTHDAMAGE, percent = -30 },
	{ type = COMBAT_FIREDAMAGE, percent = -20 },
	{ type = COMBAT_LIFEDRAIN, percent = 0 },
	{ type = COMBAT_MANADRAIN, percent = 0 },
	{ type = COMBAT_DROWNDAMAGE, percent = 0 },
	{ type = COMBAT_ICEDAMAGE, percent = 0 },
	{ type = COMBAT_HOLYDAMAGE, percent = 0 },
	{ type = COMBAT_DEATHDAMAGE, percent = 0 },
}

monster.immunities = {
	{ type = "paralyze", condition = true },
	{ type = "outfit", condition = true },
	{ type = "invisible", condition = true },
	{ type = "bleed", condition = false },
}

mType:register(monster)
