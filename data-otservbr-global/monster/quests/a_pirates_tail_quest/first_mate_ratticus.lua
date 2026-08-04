-- Ratmiral Blackwhiskers / upper deck, stage 3 - the second boss form Ratmiral swaps places
-- with, per the reference ("boss zamieni się miejscem z [pirat], który dotychczas spacerował
-- piętro wyżej"). Named per the reference's own monster list ("1st Mate Ratticus"). Stats are a
-- reduced-tier adaptation of Ratmiral Blackwhiskers' own stats (no separate reference numbers
-- exist for this form).
local mType = Game.createMonsterType("1st Mate Ratticus")
local monster = {}

monster.description = "1st Mate Ratticus"
monster.experience = 22000
monster.outfit = {
	lookType = 1377,
	lookHead = 10,
	lookBody = 10,
	lookLegs = 10,
	lookFeet = 10,
	lookAddons = 0,
	lookMount = 0,
}

monster.events = {
	"RatmiralUpperDeckDeath",
}

monster.health = 90000
monster.maxHealth = 90000
monster.race = "blood"
monster.corpse = 0
monster.speed = 115
monster.manaCost = 0

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
	staticAttackChance = 70,
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
}

monster.loot = {
	{ name = "gold coin", chance = 100000, maxCount = 80 },
	{ name = "platinum coin", chance = 55000, maxCount = 20 },
}

monster.attacks = {
	{ name = "melee", interval = 2000, chance = 100, minDamage = -200, maxDamage = -400 },
	{ name = "combat", interval = 2000, chance = 30, type = COMBAT_FIREDAMAGE, minDamage = -250, maxDamage = -450, range = 6, target = true, effect = CONST_ME_FIREATTACK },
}

monster.defenses = {
	defense = 50,
	armor = 65,
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
