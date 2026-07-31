-- Gorga does not exist anywhere in the reference repo. Stats adapted from the comparable
-- candy-themed boss "Sugar Daddy" (same tier/bossRaceId range) since no owner-provided balance
-- figures exist for this boss - flagged as inferred/placeholder balance in the PR report.
local mType = Game.createMonsterType("Gorga")
local monster = {}

monster.description = "Gorga"
monster.experience = 15000
monster.outfit = {
	lookType = 1764,
	lookHead = 10,
	lookBody = 10,
	lookLegs = 10,
	lookFeet = 10,
	lookAddons = 2,
	lookMount = 0,
}

monster.events = {
	"SweetDreamsGorgaDeath",
}

monster.health = 9000
monster.maxHealth = 9000
monster.race = "blood"
monster.corpse = 48416
monster.speed = 240
monster.manaCost = 0

monster.changeTarget = {
	interval = 2000,
	chance = 20,
}

monster.strategiesTarget = {
	nearest = 70,
	health = 10,
	damage = 10,
	random = 10,
}

monster.flags = {
	summonable = false,
	attackable = true,
	hostile = true,
	convinceable = false,
	pushable = false,
	rewardBoss = true,
	illusionable = false,
	canPushItems = true,
	canPushCreatures = true,
	staticAttackChance = 98,
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
	chance = 10,
	{ text = "You'll never take my sweets!", yell = false },
	{ text = "GORGA HUNGRY!", yell = false },
}

monster.loot = {
	{ name = "gold coin", chance = 100000, maxCount = 90 },
	{ name = "platinum coin", chance = 100000, maxCount = 10 },
	{ name = "small enchanted sapphire", chance = 8900 },
	{ name = "white gem", chance = 5600, maxCount = 1 },
}

monster.attacks = {
	{ name = "melee", interval = 2000, chance = 20, minDamage = 0, maxDamage = -520 },
	{ name = "combat", interval = 2000, chance = 20, type = COMBAT_EARTHDAMAGE, minDamage = -280, maxDamage = -450, range = 6, effect = CONST_ME_HEARTS, target = true },
	{ name = "combat", interval = 2000, chance = 18, type = COMBAT_PHYSICALDAMAGE, minDamage = -200, maxDamage = -350, radius = 10, effect = CONST_ME_HITAREA, target = false },
}

monster.defenses = {
	defense = 60,
	armor = 50,
	{ name = "combat", interval = 3000, chance = 20, type = COMBAT_HEALING, minDamage = 350, maxDamage = 1200, effect = CONST_ME_MAGIC_BLUE, target = false },
}

monster.elements = {
	{ type = COMBAT_PHYSICALDAMAGE, percent = 0 },
	{ type = COMBAT_ENERGYDAMAGE, percent = 15 },
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
