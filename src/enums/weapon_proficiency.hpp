/**
 * Canary - A free and open-source MMORPG server emulator
 * Copyright (©) 2019–present OpenTibiaBR <opentibiabr@outlook.com>
 * Repository: https://github.com/opentibiabr/canary
 * License: https://github.com/opentibiabr/canary/blob/main/LICENSE
 * Contributors: https://github.com/opentibiabr/canary/graphs/contributors
 * Website: https://docs.opentibiabr.com/
 */

#pragma once

#ifndef USE_PRECOMPILED_HEADERS
	#include <cstdint>
#endif

#include "creatures/creatures_definitions.hpp"

enum class WeaponProficiencyBonus_t : uint8_t {
	ATTACK_DAMAGE = 0, // bonus to the attack damage of the weapon, which is added to the base damage - OK
	DEFENSE_BONUS = 1, // bonus to the defense of the weapon, which is added to the armor value - OK
	WEAPON_SHIELD_MODIFIER = 2, // bonus to the shield modifier of the weapon - OK
	SKILL_BONUS = 3, // bonus to the skill level of the weapon (distance, sword, axe, club, fist, magic, shield, fishing) - OK
	SPECIALIZED_MAGIC_LEVEL = 4, // bonus magic level for specialized spells - OK
	SPELL_AUGMENT = 5, // bonus damage against specific creatures based on spell augment - OK
	WEAPON_PROFICIENCY_BESTIARY = 6, // renamed from BESTIARY to avoid shadowing CyclopediaTitle_t::BESTIARY
	POWERFUL_FOE_BONUS = 7, // bonus damage against bosses, influenced and fiendish creatures - OK
	CRITICAL_HIT_CHANCE = 8, // chance to deal critical damage with the weapon - OK
	ELEMENTAL_HIT_CHANCE = 9, // chance to deal elemental damage with the weapon - OK
	RUNE_CRITICAL_HIT_CHANCE = 10, // chance to deal critical damage with runes - OK
	AUTO_ATTACK_CRITICAL_HIT_CHANCE = 11, // chance to deal critical damage with auto attacks - OK
	CRITICAL_EXTRA_DAMAGE = 12, // extra damage dealt when a critical hit occurs - OK
	ELEMENTAL_CRITICAL_EXTRA_DAMAGE = 13, // extra elemental damage dealt when a critical hit occurs - OK
	RUNE_CRITICAL_EXTRA_DAMAGE = 14, // extra damage dealt when a critical hit occurs with runes - OK
	AUTO_ATTACK_CRITICAL_EXTRA_DAMAGE = 15, // extra damage dealt when a critical hit occurs with auto attacks - OK
	MANA_LEECH = 16, // chance to leech mana from the target when hitting with the weapon - OK
	LIFE_LEECH = 17, // chance to leech life from the target when hitting with the weapon - OK
	MANA_GAIN_ON_HIT = 18, // chance to gain mana when hitting a creature with the weapon - OK
	LIFE_GAIN_ON_HIT = 19, // chance to gain life when hitting a creature with the weapon - OK
	MANA_GAIN_ON_KILL = 20, // chance to gain mana when killing a creature with the weapon - OK
	LIFE_GAIN_ON_KILL = 21, // chance to gain life when killing a creature with the weapon - OK
	PERFECT_SHOT_DAMAGE = 22, // bonus damage when hitting a target with a perfect shot - OK
	RANGED_HIT_CHANCE = 23, // chance to hit a target with ranged attacks - OK
	ATTACK_RANGE = 24, // the range of the weapon, how far it can hit a target (increases the current range of the weapon) - OK
	SKILL_PERCENTAGE_AUTO_ATTACK = 25, // a percentage of your current skill level as extra damage on auto attacks - OK
	SKILL_PERCENTAGE_SPELL_DAMAGE = 26, // a percentage of your current skill level as extra damage for spells - OK
	SKILL_PERCENTAGE_SPELL_HEALING = 27, // a percentage of your current skill level as extra healing for spells - OK
	ALPHA_STRIKE_EXTRA_DAMAGE = 28, // extra damage against creatures above the high-health threshold
	OMEGA_STRIKE_EXTRA_DAMAGE = 29, // extra damage against creatures below the low-health threshold
	ARMOR_PENETRATION = 30, // physical armor penetration percentage
	ELEMENTAL_PIERCE = 31, // elemental resistance penetration percentage
};

enum class SkillPercentage_t : uint8_t {
	AutoAttack,
	SpellDamage,
	SpellHealing,
};

enum class WeaponProficiencySpellBoost_t : uint8_t {
	MANA = 0,
	COOLDOWN = 1,
	GROUP_COOLDOWN = 2,
	SECONDARY_GROUP_COOLDOWN = 3,
	MANA_LEECH = 4,
	MANA_LEECH_CHANCE = 5,
	LIFE_LEECH = 6,
	LIFE_LEECH_CHANCE = 7,
	DAMAGE = 8,
	DAMAGE_REDUCTION = 9,
	HEAL = 10,
	CRITICAL_DAMAGE = 11,
	CRITICAL_CHANCE = 12,

	TOTAL_COUNT = 13
};

enum class WeaponProficiencyHealth_t : uint8_t {
	LIFE = 0,
	MANA = 1,
};

enum class WeaponProficiencyGain_t : uint8_t {
	HIT = 0,
	KILL = 1,
};

enum class WeaponProficiencyExperience_t : uint8_t {
	Easy = 1,
	Medium = 2,
	Hard = 3,
};

struct ProficiencyPerk {
	ProficiencyPerk() = default;

	uint8_t level = 0;
	uint8_t index = 0;

	// A shaped perk replaced the one the proficiency file defines at (level, index).
	// What is stored for it is its IDENTITY, not its effect: which shaping option was
	// rolled and at what rank. Everything else below - value, type, element, skill,
	// spell, range, augment - is rebuilt from the current shaping rules on every read,
	// exactly like a normal selection is rebuilt from the proficiency file. Storing
	// the computed effect instead would freeze it: a balance change to ValuePerRank
	// would never reach a player who already owns the perk.
	//
	// shapingOptionId is the option's stable Id from shaping.json, never its position
	// in the array, so reordering the file cannot silently repoint a player's perk.
	// 0 means the perk is not shaped.
	bool shaped = false;
	uint16_t shapingOptionId = 0;
	uint8_t rank = 0;

	double_t value = 0.0;

	uint16_t spellId = 0;
	uint8_t range = 0;
	uint16_t bestiaryId = 0;
	std::string bestiaryName = "";
	uint8_t augmentType = 0;
	skills_t skillId = SKILL_NONE;
	CombatType_t element = COMBAT_NONE;
	WeaponProficiencyBonus_t type = WeaponProficiencyBonus_t::ATTACK_DAMAGE;
};

// Everything the perk shaping systems (Shape, Refine, Reshape, Clear) need is data,
// not code: which effects may be rolled, what each is worth at every rank, what each
// operation costs, and what each slot requires. It lives in
// data/items/proficiencies/shaping.json so balancing never needs a rebuild.
struct ProficiencyShapingOption {
	// Stable identity, assigned by hand in shaping.json and never reused. A player's
	// shaped perk stores this, so an option keeps its meaning however the file is
	// reordered, and removing an option is detectable rather than silent.
	uint16_t id = 0;

	WeaponProficiencyBonus_t type = WeaponProficiencyBonus_t::ATTACK_DAMAGE;

	// Relative draw weight. A roll picks among the options whose requirements the
	// weapon meets, proportionally to this.
	uint32_t weight = 1;

	// Index 0 is rank 0, the value a freshly shaped slot rolls in at. The table's
	// size is that option's maximum rank, which may be lower than the global one.
	std::vector<double_t> valuePerRank = {};

	// Only meaningful for the perk types that carry them; left at the neutral value
	// otherwise, exactly as a perk read from a proficiency file would be.
	uint16_t spellId = 0;
	uint8_t range = 0;
	uint16_t bestiaryId = 0;
	std::string bestiaryName = "";
	uint8_t augmentType = 0;
	skills_t skillId = SKILL_NONE;
	CombatType_t element = COMBAT_NONE;

	[[nodiscard]] uint8_t maxRank() const {
		return valuePerRank.empty() ? 0 : static_cast<uint8_t>(valuePerRank.size() - 1);
	}
};

struct ProficiencyShapingSlot {
	uint8_t slot = 0;
	uint64_t unlockDustCost = 0;
	uint8_t requiredProficiencyLevel = 0;
	bool requiresMastery = false;
};

struct ProficiencyShapingRules {
	// Index is the rank being bought, so entry 0 is unused and entry 3 is what it
	// costs to go from rank 2 to rank 3. An empty table disables refining.
	std::vector<uint64_t> refineDustCostPerRank = {};

	uint64_t reshapeDustCost = 0;
	uint8_t reshapeOptionCount = 3;
	uint64_t clearDustCost = 0;

	// Instantly refines a perk to its maximum rank. 0 means no item is configured.
	uint16_t lunarAscensionOrbItemId = 0;

	// Shaping is only allowed inside a protection zone, as on the official servers.
	bool requiresProtectionZone = true;

	std::vector<ProficiencyShapingSlot> slots = {};
	std::vector<ProficiencyShapingOption> options = {};

	[[nodiscard]] bool empty() const {
		return options.empty() || slots.empty();
	}

	[[nodiscard]] const ProficiencyShapingOption* findOption(uint16_t optionId) const {
		if (optionId == 0) {
			return nullptr;
		}

		for (const auto &option : options) {
			if (option.id == optionId) {
				return &option;
			}
		}

		return nullptr;
	}
};

struct ProficiencyLevel {
	std::vector<ProficiencyPerk> perks = {};
};

struct Proficiency {
	Proficiency() = default;
	explicit Proficiency(uint16_t id) :
		id(id) { }

	uint16_t id = 0;
	std::vector<ProficiencyLevel> level = {};
	uint8_t maxLevel = 0;
};

struct WeaponProficiencyData {
	uint32_t experience = 0;
	std::vector<ProficiencyPerk> perks = {};
	bool mastered = false;
};

struct WeaponProficiencyBonusStat {
	CombatType_t element = COMBAT_NONE;
	uint32_t value = 0;
};

struct WeaponProficiencyPerfectShotBonus {
	uint8_t range = 0;
	double_t damage = 0;
};

struct SkillPercentage {
	skills_t skill = SKILL_NONE;

	double_t spellHealing = 0;
	double_t autoAttack = 0;
	double_t spellDamage = 0;

	void clear() {
		skill = SKILL_NONE;
		spellHealing = 0;
		autoAttack = 0;
		spellDamage = 0;
	}
};

struct WeaponProficiencyCriticalBonus {
	double_t chance = 0;
	double_t damage = 0;

	void clear() {
		chance = 0;
		damage = 0;
	}
};

namespace WeaponProficiencySpells {
	struct Increase {
		bool area = false;
		double_t damage = 0;
		double_t heal = 0;
		int32_t additionalTarget = 0;
		double_t damageReduction = 0;
		int32_t duration = 0;
		double_t criticalDamage = 0;
		double_t criticalChance = 0;
	};

	struct Decrease {
		int32_t cooldown = 0;
		int32_t manaCost = 0;
		int32_t secondaryGroupCooldown = 0;
	};

	struct Leech {
		double_t mana = 0;
		double_t life = 0;
	};

	struct Bonus {
		Leech leech;
		Increase increase;
		Decrease decrease;
	};
}
