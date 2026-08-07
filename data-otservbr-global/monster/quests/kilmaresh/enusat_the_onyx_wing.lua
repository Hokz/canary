-- "Aspiring Oracle" (added 12.70) final target - a black Manticore. Did not exist before this pass;
-- based on the existing "Manticore" template (magicals/manticore.lua) with boosted stats befitting a
-- named quest boss, since the source describes no special combat mechanic beyond "find and kill him."
local mType = Game.createMonsterType("Enusat the Onyx Wing")
local monster = {}

monster.description = "Enusat the Onyx Wing"
monster.experience = 12000
monster.outfit = {
	lookType = 1189,
	lookHead = 96,
	lookBody = 96,
	lookLegs = 96,
	lookFeet = 96,
	lookAddons = 0,
	lookMount = 0,
}

monster.health = 25000
monster.maxHealth = 25000
monster.race = "blood"
monster.corpse = 31390
monster.speed = 165
monster.manaCost = 0

monster.events = {
	"AspiringOracleEnusatDeath",
}

monster.changeTarget = {
	interval = 4000,
	chance = 10,
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
	targetDistance = 4,
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
	chance = 10,
	{ text = "The onyx wing casts a shadow of dread.", yell = false },
}

monster.loot = {
	{ name = "platinum coin", chance = 100000, maxCount = 5 },
	{ name = "manticore tail", chance = 15000 },
	{ name = "manticore ear", chance = 12000 },
	{ name = "black pearl", chance = 8000 },
	{ name = "violet gem", chance = 6000 },
	{ name = "royal star", chance = 3000, maxCount = 3 },
}

monster.attacks = {
	{ name = "melee", interval = 2000, chance = 100, minDamage = -200, maxDamage = -900 },
	{ name = "combat", interval = 2000, chance = 15, type = COMBAT_DEATHDAMAGE, minDamage = -400, maxDamage = -650, length = 8, spread = 3, effect = CONST_ME_MORTAREA, target = false },
	{ name = "combat", interval = 4000, chance = 18, type = COMBAT_EARTHDAMAGE, minDamage = -400, maxDamage = -550, radius = 3, shootEffect = CONST_ANI_ENVENOMEDARROW, effect = CONST_ME_GREEN_RINGS, target = true },
	{ name = "combat", interval = 2000, chance = 22, type = COMBAT_PHYSICALDAMAGE, minDamage = -550, maxDamage = -700, range = 4, shootEffect = CONST_ANI_BURSTARROW, target = true },
}

monster.defenses = {
	defense = 90,
	armor = 90,
	mitigation = 2.5,
}

monster.elements = {
	{ type = COMBAT_PHYSICALDAMAGE, percent = 0 },
	{ type = COMBAT_ENERGYDAMAGE, percent = 0 },
	{ type = COMBAT_EARTHDAMAGE, percent = 0 },
	{ type = COMBAT_FIREDAMAGE, percent = 10 },
	{ type = COMBAT_LIFEDRAIN, percent = 0 },
	{ type = COMBAT_MANADRAIN, percent = 0 },
	{ type = COMBAT_DROWNDAMAGE, percent = 0 },
	{ type = COMBAT_ICEDAMAGE, percent = -10 },
	{ type = COMBAT_HOLYDAMAGE, percent = 0 },
	{ type = COMBAT_DEATHDAMAGE, percent = 20 },
}

monster.immunities = {
	{ type = "paralyze", condition = true },
	{ type = "outfit", condition = false },
	{ type = "invisible", condition = true },
	{ type = "bleed", condition = false },
}

mType:register(monster)
