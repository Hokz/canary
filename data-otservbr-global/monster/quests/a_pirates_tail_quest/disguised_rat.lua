-- Rascacoon Trust Points / Supply Mission - a pirat disguised as a rat, raiding the cheese
-- cellar. Invulnerable to ordinary attacks (matches the reference: "won't fool anyone from close
-- up... but the disguise" only breaks under the shaman's staff) - see action_supply_mission.lua's
-- health-change hook, which reveals it into a killable "Smelly Cheese" only for a player who
-- currently holds the staff's effect.
local mType = Game.createMonsterType("Disguised Rat")
local monster = {}

monster.description = "a disguised rat"
monster.experience = 0
monster.outfit = {
	lookType = 21,
	lookHead = 0,
	lookBody = 0,
	lookLegs = 0,
	lookFeet = 0,
	lookAddons = 0,
	lookMount = 0,
}

monster.events = {
	"SupplyMissionRatRevealed",
}

monster.health = 1
monster.maxHealth = 1
monster.race = "blood"
monster.corpse = 0
monster.speed = 140
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
	pushable = true,
	rewardBoss = false,
	illusionable = false,
	canPushItems = false,
	canPushCreatures = false,
	staticAttackChance = 0,
	targetDistance = 1,
	runHealth = 0,
	healthHidden = true,
	isBlockable = true,
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
	chance = 15,
	{ text = "*squeak*", yell = false },
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
