-- LIZARD_GATE_GUARDIAN_REFERENCE_MATRIX (see PR body for the full field-by-field table).
-- HP/EXP/summon ability/Bosstiary tier: CURRENT_SOURCE_PROVEN (current-Global values supplied
-- during review). Outfit/corpse/speed/defense/armor/mitigation/immunities/push/summon
-- chance-interval: DERIVED_FROM_PROVEN_FAMILY or CUSTOM_GLOBAL_LIKE_PENDING_EXACT_REFERENCE -
-- no current source documents these, so the closest known project family (Lizard Chosen for
-- appearance/corpse, Demodras for summon cadence) was used instead of inventing a number.
local mType = Game.createMonsterType("Lizard Gate Guardian")
local monster = {}

monster.description = "a lizard gate guardian"
monster.experience = 2500
monster.outfit = {
	lookType = 344,
	lookHead = 0,
	lookBody = 0,
	lookLegs = 0,
	lookFeet = 0,
	lookAddons = 0,
	lookMount = 0,
}

monster.health = 5000
monster.maxHealth = 5000
monster.race = "blood"
monster.corpse = 10371
monster.speed = 130
monster.manaCost = 0

monster.changeTarget = {
	interval = 4000,
	chance = 10,
}

-- Project-native Bosstiary integration (RARITY_NEMESIS confirmed current-source). bossRaceId is
-- this project's own internal sequential index (highest existing value found was 2594), not a
-- CipSoft-canonical number - there is no such thing for an OT project, every boss in this
-- codebase is assigned one the same way.
monster.bosstiary = {
	bossRaceId = 2595,
	bossRace = RARITY_NEMESIS,
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
	canPushCreatures = false,
	staticAttackChance = 90,
	targetDistance = 1,
	runHealth = 0,
	healthHidden = false,
	isBlockable = false,
	canWalkOnEnergy = false,
	canWalkOnFire = false,
	canWalkOnPoison = true,
}

monster.light = {
	level = 0,
	color = 0,
}

-- No voice lines: a source explicitly documents none for this monster, and no source confirmed
-- any specific line - not inventing one.
monster.voices = {}

-- ITEM PRESENCE: EXTERNAL_REFERENCE_PROVEN (all 10 items confirmed to exist by exact name in
-- items.xml). DROP CHANCE / maxCount: the source itself states these are estimated from a small
-- sample (32 kills), not authoritative CipSoft configuration data - kept as conservative,
-- clearly-labeled estimates (CUSTOM_GLOBAL_LIKE_PENDING_EXACT_DROP_RATE), not asserted exact.
monster.loot = {
	{ name = "gold coin", chance = 100000, maxCount = 48 }, -- CUSTOM_GLOBAL_LIKE_PENDING_EXACT_DROP_RATE
	{ name = "platinum coin", chance = 30000, maxCount = 3 }, -- CUSTOM_GLOBAL_LIKE_PENDING_EXACT_DROP_RATE
	{ name = "ultimate health potion", chance = 100000 }, -- CUSTOM_GLOBAL_LIKE_PENDING_EXACT_DROP_RATE
	{ name = "lizard leather", chance = 20000 }, -- CUSTOM_GLOBAL_LIKE_PENDING_EXACT_DROP_RATE
	{ name = "lizard scale", chance = 40000, maxCount = 2 }, -- CUSTOM_GLOBAL_LIKE_PENDING_EXACT_DROP_RATE
	{ name = "zaoan armor", chance = 2000 }, -- CUSTOM_GLOBAL_LIKE_PENDING_EXACT_DROP_RATE
	{ name = "zaoan legs", chance = 2000 }, -- CUSTOM_GLOBAL_LIKE_PENDING_EXACT_DROP_RATE
	{ name = "zaoan shoes", chance = 2000 }, -- CUSTOM_GLOBAL_LIKE_PENDING_EXACT_DROP_RATE
	{ name = "zaoan helmet", chance = 500 }, -- CUSTOM_GLOBAL_LIKE_PENDING_EXACT_DROP_RATE
	{ name = "zaoan sword", chance = 500 }, -- CUSTOM_GLOBAL_LIKE_PENDING_EXACT_DROP_RATE
}

monster.attacks = {
	{ name = "melee", interval = 2000, chance = 100, minDamage = 0, maxDamage = -350 },
}

-- CURRENT_SOURCE_PROVEN: summons 2 Lizard Chosen. Frequency (chance/interval) is NOT_PROVEN from
-- any source - modeled on Demodras's closest comparable "summons 2 of a named creature" pattern
-- (killing_in_the_name_of/demodras.lua) rather than an invented number.
monster.summon = {
	maxSummons = 2,
	summons = {
		{ name = "Lizard Chosen", chance = 17, interval = 1000, count = 2 },
	},
}

monster.defenses = {
	defense = 45,
	armor = 30,
	mitigation = 0.94,
}

-- ELEMENT SEMANTICS PROVEN from engine source (Monster::blockHit, monster.cpp):
--   damage = damage * (100 - percent) / 100
-- so `percent` is RESISTANCE, not damage taken - percent = 100 - (damage-taken %).
-- CURRENT_SOURCE_PROVEN damage-taken figures translated below (unlisted types - life/mana drain -
-- are not documented by any source and are left at the neutral default, percent = 0):
--   physical 100% -> 0   | death 100% -> 0   | holy 100% -> 0   | ice 100% -> 0
--   drown    100% -> 0   | fire   90% -> 10  | energy 80% -> 20 | earth    0% -> 100 (immune)
-- Earth immunity also matches Lizard Chosen (this creature's closest family member), which
-- carries the identical { type = COMBAT_EARTHDAMAGE, percent = 100 } entry.
monster.elements = {
	{ type = COMBAT_PHYSICALDAMAGE, percent = 0 },
	{ type = COMBAT_ENERGYDAMAGE, percent = 20 },
	{ type = COMBAT_EARTHDAMAGE, percent = 100 },
	{ type = COMBAT_FIREDAMAGE, percent = 10 },
	{ type = COMBAT_LIFEDRAIN, percent = 0 },
	{ type = COMBAT_MANADRAIN, percent = 0 },
	{ type = COMBAT_DROWNDAMAGE, percent = 0 },
	{ type = COMBAT_ICEDAMAGE, percent = 0 },
	{ type = COMBAT_HOLYDAMAGE, percent = 0 },
	{ type = COMBAT_DEATHDAMAGE, percent = 0 },
}

monster.immunities = {
	{ type = "paralyze", condition = false },
	{ type = "outfit", condition = false },
	{ type = "invisible", condition = true },
	{ type = "bleed", condition = false },
}

mType:register(monster)
