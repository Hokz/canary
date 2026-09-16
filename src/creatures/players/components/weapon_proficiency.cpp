/**
 * Canary - A free and open-source MMORPG server emulator
 * Copyright (©) 2019-2024 OpenTibiaBR <opentibiabr@outlook.com>
 * Repository: https://github.com/opentibiabr/canary
 * License: https://github.com/opentibiabr/canary/blob/main/LICENSE
 * Contributors: https://github.com/opentibiabr/canary/graphs/contributors
 * Website: https://docs.opentibiabr.com/
 */

#include <algorithm>
#include <cmath>
#include <filesystem>
#include <limits>
#include <numeric>

// Player.hpp already includes the weapon
#include "creatures/players/player.hpp"
#include "creatures/monsters/monster.hpp"
#include "items/tile.hpp"
#include "items/weapons/weapons.hpp"
#include "creatures/monsters/monsters.hpp"
#include "canary_server.hpp"

#include "config/configmanager.hpp"
#include "io/fileloader.hpp"
#include "io/io_bosstiary.hpp"
#include "utils/tools.hpp"
#include "utils/hash.hpp"
#include "utils/transparent_string_hash.hpp"
#include "kv/value_wrapper.hpp"

#include "kv/kv.hpp"

namespace AugmentType {
	constexpr uint8_t DAMAGE = 2;
	constexpr uint8_t HEAL = 3;
	constexpr uint8_t COOLDOWN = 6;
	constexpr uint8_t LIFE_LEECH = 14;
	constexpr uint8_t MANA_LEECH = 15;
	constexpr uint8_t CRITICAL_DAMAGE = 16;
	constexpr uint8_t CRITICAL_CHANCE = 17;
}

namespace {
	constexpr int32_t MIN_TRACKED_SKILL = static_cast<int32_t>(SKILL_FIRST);
	constexpr int32_t MAX_TRACKED_SKILL = static_cast<int32_t>(SKILL_MAGLEVEL);
	constexpr size_t MASTERY_EXPERIENCE_OFFSET = 2;

	[[nodiscard]] bool isTrackedWeaponProficiencySkill(skills_t skill) {
		const auto enumValue = static_cast<int32_t>(skill);
		return enumValue >= MIN_TRACKED_SKILL && enumValue <= MAX_TRACKED_SKILL;
	}

	uint32_t scaleWeaponProficiencyExperienceGain(uint32_t experience) {
		auto multiplier = g_configManager().getFloat(WEAPON_PROFICIENCY_GAIN_MULTIPLIER);
		if (multiplier < 0.0f) {
			multiplier = 0.0f;
		}

		const auto scaledExperience = static_cast<uint64_t>(std::llround(static_cast<double>(experience) * multiplier));
		return static_cast<uint32_t>(std::min<uint64_t>(scaledExperience, std::numeric_limits<uint32_t>::max()));
	}

	bool usesKnightProficiencyTable(const ItemType &itemType) {
		if (itemType.weaponType != WEAPON_SWORD && itemType.weaponType != WEAPON_AXE && itemType.weaponType != WEAPON_CLUB) {
			return false;
		}

		return asLowerCaseString(itemType.vocationString).find("knight") != std::string::npos;
	}

	size_t getMasteryExperienceTierCount(const Proficiency &proficiencyInfo, const std::vector<uint32_t> &experienceArray) {
		if (proficiencyInfo.maxLevel == 0 || experienceArray.empty()) {
			return 0;
		}

		const auto masteryLevels = static_cast<size_t>(proficiencyInfo.maxLevel) + MASTERY_EXPERIENCE_OFFSET;
		return std::min(experienceArray.size(), masteryLevels);
	}
}

std::unordered_map<uint16_t, Proficiency> WeaponProficiency::proficiencies;
ProficiencyShapingRules WeaponProficiency::shapingRules;

std::vector<uint32_t> WeaponProficiency::crossbowExperience = {
	600,
	8000,
	30000,
	150000,
	650000,
	2500000,
	10000000,
	20000000,
	30000000
};

std::vector<uint32_t> WeaponProficiency::knightExperience = {
	1250,
	20000,
	80000,
	300000,
	1500000,
	6000000,
	20000000,
	40000000,
	60000000
};

std::vector<uint32_t> WeaponProficiency::standardExperience = {
	1750,
	25000,
	100000,
	400000,
	2000000,
	8000000,
	30000000,
	60000000,
	90000000
};

WeaponProficiency::WeaponProficiency(Player &player) :
	m_player(player) { }

bool WeaponProficiency::isValidWeaponId(uint16_t weaponId) const {
	return weaponId > 0 && weaponId < Item::items.size();
}

static void registerPerks(const nlohmann::json &perksJson, ProficiencyLevel &proficiencyLevel) {
	using enum WeaponProficiencyBonus_t;

	uint8_t perkIndex = 0;
	const uint8_t maxPerks = g_configManager().getNumber(WEAPON_PROFICIENCY_MAX_PERKS_PER_LEVEL);
	for (const auto &perkJson : perksJson) {
		if (perkIndex >= maxPerks) {
			g_logger().error("{} - Proficiency level exceeded the maximum perks, skipping perk index above {}", __FUNCTION__, perkIndex + 1);
			break;
		}

		ProficiencyPerk proficiencyPerk;
		proficiencyPerk.type = perkJson["Type"].get<WeaponProficiencyBonus_t>();
		proficiencyPerk.value = perkJson["Value"].get<double_t>();

		uint64_t shiftedValue = 0;
		if (proficiencyPerk.type == SPECIALIZED_MAGIC_LEVEL) {
			shiftedValue = perkJson["DamageType"].get<uint64_t>();
		} else if (proficiencyPerk.type == ELEMENTAL_HIT_CHANCE || proficiencyPerk.type == ELEMENTAL_CRITICAL_EXTRA_DAMAGE || proficiencyPerk.type == ELEMENTAL_PIERCE) {
			shiftedValue = perkJson["ElementId"].get<uint64_t>();
		}

		if (shiftedValue > 0) {
			const auto unshiftedValue = undoShift(shiftedValue);
			proficiencyPerk.element = getCombatFromCipbiaElement(static_cast<Cipbia_Elementals_t>(unshiftedValue));
		}

		if (perkJson.contains("Range")) {
			proficiencyPerk.range = perkJson["Range"].get<uint8_t>();
		}
		if (perkJson.contains("AugmentType")) {
			proficiencyPerk.augmentType = perkJson["AugmentType"].get<uint8_t>();
		}
		if (perkJson.contains("SpellId")) {
			proficiencyPerk.spellId = perkJson["SpellId"].get<uint16_t>();
		}
		if (perkJson.contains("SkillId")) {
			const auto skill = perkJson["SkillId"].get<uint8_t>();

			const auto skillOpt = magic_enum::enum_cast<CipbiaSkills_t>(skill);
			if (skillOpt.has_value()) {
				proficiencyPerk.skillId = getSkillsFromCipbiaSkill(skillOpt.value());
			} else {
				g_logger().error("{} - Invalid skill id {}, skipping skill register", __FUNCTION__, skill);
			}
		}
		if (perkJson.contains("BestiaryId")) {
			proficiencyPerk.bestiaryId = perkJson["BestiaryId"].get<uint16_t>();
		}
		if (perkJson.contains("BestiaryName")) {
			proficiencyPerk.bestiaryName = perkJson["BestiaryName"].get<std::string>();
		}

		proficiencyPerk.index = perkIndex;

		proficiencyLevel.perks.push_back(std::move(proficiencyPerk));
		perkIndex++;
	}
}

static void registerLevels(const nlohmann::json &levelsJson, Proficiency &proficiency) {
	uint8_t levelIndex = 0;
	const uint8_t maxLevels = g_configManager().getNumber(WEAPON_PROFICIENCY_MAX_LEVELS);
	for (const auto &levelJson : levelsJson) {
		if (levelIndex >= maxLevels) {
			g_logger().error("{} - Proficiency '{}' exceeded the maximum level, skipping levels above {}", __FUNCTION__, proficiency.id, levelIndex + 1);
			break;
		}

		ProficiencyLevel proficiencyLevel;
		registerPerks(levelJson["Perks"], proficiencyLevel);

		for (auto &perk : proficiencyLevel.perks) {
			perk.level = levelIndex;
		}

		proficiency.level.push_back(std::move(proficiencyLevel));
		levelIndex++;
	}

	proficiency.maxLevel = levelIndex;
}

[[nodiscard]] std::unordered_map<uint16_t, Proficiency> &WeaponProficiency::getProficiencies() {
	return proficiencies;
}

[[nodiscard]] const ProficiencyShapingRules &WeaponProficiency::getShapingRules() {
	return shapingRules;
}

// Rebuilds a shaped perk from the shaping rules as they are loaded right now. This
// is the whole point of storing only (optionId, rank): a balance change to
// ValuePerRank, SkillId, ElementId or anything else reaches players who already own
// the perk, on their next read, with no migration.
ProficiencyPerk WeaponProficiency::buildShapedPerk(const ProficiencyShapingOption &option, uint8_t rank, uint8_t level, uint8_t index) {
	ProficiencyPerk perk;
	perk.shaped = true;
	perk.shapingOptionId = option.id;

	// A rank the option no longer offers is clamped down, never kept. Shrinking a
	// ValuePerRank table must not leave anyone holding a value that no longer exists.
	perk.rank = std::min(rank, option.maxRank());

	perk.level = level;
	perk.index = index;

	perk.type = option.type;
	perk.value = option.valuePerRank[perk.rank];
	perk.spellId = option.spellId;
	perk.range = option.range;
	perk.bestiaryId = option.bestiaryId;
	perk.bestiaryName = option.bestiaryName;
	perk.augmentType = option.augmentType;
	perk.skillId = option.skillId;
	perk.element = option.element;

	return perk;
}

static void registerShapingOption(const nlohmann::json &optionJson, ProficiencyShapingRules &rules) {
	const auto rawType = optionJson.at("Type").get<uint8_t>();
	const auto typeOpt = magic_enum::enum_cast<WeaponProficiencyBonus_t>(rawType);
	if (!typeOpt.has_value()) {
		throw FailedToInitializeCanary(fmt::format("{} - Unknown perk Type '{}' in shaping options", __FUNCTION__, rawType));
	}

	ProficiencyShapingOption option;
	option.type = typeOpt.value();

	// The Id is what a player's shaped perk stores. Without it the only handle on an
	// option would be its position in the array, and reordering the file would
	// silently repoint every perk rolled from it.
	option.id = optionJson.at("Id").get<uint16_t>();
	if (option.id == 0) {
		throw FailedToInitializeCanary(fmt::format("{} - Shaping option Id must not be 0 (perk Type '{}')", __FUNCTION__, rawType));
	}
	if (rules.findOption(option.id) != nullptr) {
		throw FailedToInitializeCanary(fmt::format("{} - Duplicate shaping option Id '{}'", __FUNCTION__, option.id));
	}

	for (const auto &valueJson : optionJson.at("ValuePerRank")) {
		option.valuePerRank.push_back(valueJson.get<double_t>());
	}
	if (option.valuePerRank.empty()) {
		throw FailedToInitializeCanary(fmt::format("{} - Perk Type '{}' has an empty ValuePerRank", __FUNCTION__, rawType));
	}

	// A zero weight can never be drawn, which is a silent way to lose an option; say
	// so instead of shipping a table with a dead entry in it.
	option.weight = optionJson.value("Weight", 1U);
	if (option.weight == 0) {
		throw FailedToInitializeCanary(fmt::format("{} - Perk Type '{}' has Weight 0 and could never be rolled", __FUNCTION__, rawType));
	}

	// Optional fields, read the same way registerPerks reads them for a perk that
	// comes from a proficiency file, so a shaped perk is indistinguishable from a
	// file-defined one once it is built.
	option.range = optionJson.value("Range", uint8_t { 0 });
	option.augmentType = optionJson.value("AugmentType", uint8_t { 0 });
	option.spellId = optionJson.value("SpellId", uint16_t { 0 });
	option.bestiaryId = optionJson.value("BestiaryId", uint16_t { 0 });
	option.bestiaryName = optionJson.value("BestiaryName", std::string {});

	if (optionJson.contains("SkillId")) {
		const auto skill = optionJson.at("SkillId").get<uint8_t>();
		const auto skillOpt = magic_enum::enum_cast<CipbiaSkills_t>(skill);
		if (!skillOpt.has_value()) {
			throw FailedToInitializeCanary(fmt::format("{} - Invalid SkillId '{}' for perk Type '{}'", __FUNCTION__, skill, rawType));
		}
		option.skillId = getSkillsFromCipbiaSkill(skillOpt.value());
	}

	if (optionJson.contains("ElementId")) {
		const auto element = optionJson.at("ElementId").get<uint64_t>();
		const auto unshifted = undoShift(element);
		option.element = getCombatFromCipbiaElement(static_cast<Cipbia_Elementals_t>(unshifted));
		if (option.element == COMBAT_NONE) {
			throw FailedToInitializeCanary(fmt::format("{} - Invalid ElementId '{}' for perk Type '{}'", __FUNCTION__, element, rawType));
		}
	}

	rules.options.push_back(std::move(option));
}

static ProficiencyShapingRules loadShapingRules(const std::string &folder) {
	ProficiencyShapingRules rules;

	const auto fileName = fmt::format("{}/shaping/shaping.json", folder);
	if (!std::filesystem::is_regular_file(fileName)) {
		// Optional: a server that does not run perk shaping simply has no file, and
		// every shaping operation reports the feature as unavailable.
		g_logger().info("Weapon proficiency shaping is not configured ('{}' not found)", fileName);
		return rules;
	}

	std::ifstream file(fileName);
	if (!file.is_open()) {
		throw FailedToInitializeCanary(fmt::format("{} - Unable to open file '{}'", __FUNCTION__, fileName));
	}

	nlohmann::json shapingJson;
	try {
		file >> shapingJson;
	} catch (const nlohmann::json::parse_error &e) {
		throw FailedToInitializeCanary(fmt::format("{} - JSON parsing error in file '{}': {}", __FUNCTION__, fileName, e.what()));
	}

	try {
		rules.requiresProtectionZone = shapingJson.value("RequiresProtectionZone", true);

		for (const auto &slotJson : shapingJson.at("Slots")) {
			ProficiencyShapingSlot slot;
			slot.slot = slotJson.at("Slot").get<uint8_t>();
			slot.unlockDustCost = slotJson.value("UnlockDustCost", uint64_t { 0 });
			slot.requiredProficiencyLevel = slotJson.value("RequiredProficiencyLevel", uint8_t { 0 });
			slot.requiresMastery = slotJson.value("RequiresMastery", false);
			rules.slots.push_back(slot);
		}

		if (shapingJson.contains("Refine")) {
			for (const auto &costJson : shapingJson.at("Refine").at("DustCostPerRank")) {
				rules.refineDustCostPerRank.push_back(costJson.get<uint64_t>());
			}
		}

		if (shapingJson.contains("Reshape")) {
			const auto &reshapeJson = shapingJson.at("Reshape");
			rules.reshapeDustCost = reshapeJson.value("DustCost", uint64_t { 0 });
			rules.reshapeOptionCount = reshapeJson.value("OptionCount", uint8_t { 3 });
		}

		if (shapingJson.contains("Clear")) {
			rules.clearDustCost = shapingJson.at("Clear").value("DustCost", uint64_t { 0 });
		}

		if (shapingJson.contains("LunarAscensionOrb")) {
			rules.lunarAscensionOrbItemId = shapingJson.at("LunarAscensionOrb").value("ItemId", uint16_t { 0 });
		}

		for (const auto &optionJson : shapingJson.at("Options")) {
			registerShapingOption(optionJson, rules);
		}
	} catch (const nlohmann::json::exception &e) {
		throw FailedToInitializeCanary(fmt::format("{} - JSON exception in file '{}': {}", __FUNCTION__, fileName, e.what()));
	}

	// Slots are addressed by their position in this vector everywhere else, so a file
	// that numbers them out of order or repeats one would silently mis-price a slot.
	for (size_t i = 0; i < rules.slots.size(); ++i) {
		if (rules.slots[i].slot != static_cast<uint8_t>(i)) {
			throw FailedToInitializeCanary(fmt::format("{} - Slot at position {} declares Slot {}; slots must be listed in order starting at 0", __FUNCTION__, i, rules.slots[i].slot));
		}
	}

	return rules;
}

bool WeaponProficiency::loadFromJson(bool reload /* = false */) {
	g_logger().info("{}oading weapon proficiencies...", reload ? "Rel" : "L");

	auto coreFolder = g_configManager().getString(CORE_DIRECTORY);
	auto folder = fmt::format("{}/items/proficiencies", coreFolder);
	if (!std::filesystem::is_directory(folder)) {
		throw FailedToInitializeCanary(fmt::format("{} - Unable to open folder '{}'", __FUNCTION__, folder));
	}

	// One file per weapon category, so a balance change only touches the weapons
	// it is about.
	// _orphaned.json is loaded like any other file: no item references those ids,
	// but keeping them in the map preserves the behaviour of the single file this
	// replaced, where an items.xml override could still name one of them.
	std::vector<std::filesystem::path> files;
	for (const auto &entry : std::filesystem::directory_iterator(folder)) {
		const auto &path = entry.path();
		if (entry.is_regular_file() && path.extension() == ".json" && path.filename() != "proficiencies.schema.json") {
			files.emplace_back(path);
		}
	}
	// directory_iterator has no defined order; sort so any load-order-dependent
	// behaviour is at least reproducible across machines.
	std::ranges::sort(files);

	if (files.empty()) {
		throw FailedToInitializeCanary(fmt::format("{} - No proficiency files found in '{}'", __FUNCTION__, folder));
	}

	// Parsed into a local map and published only once every file has been read, so
	// a reload that hits a bad file leaves the running server on the data it already
	// had instead of on a half-loaded map.
	std::unordered_map<uint16_t, Proficiency> loaded;
	for (const auto &path : files) {
		const auto fileName = path.string();
		std::ifstream file(fileName);
		if (!file.is_open()) {
			throw FailedToInitializeCanary(fmt::format("{} - Unable to open file '{}'", __FUNCTION__, fileName));
		}

		nlohmann::json categoryJson;
		try {
			file >> categoryJson;
		} catch (const nlohmann::json::parse_error &e) {
			throw FailedToInitializeCanary(fmt::format("{} - JSON parsing error in file '{}': {}", __FUNCTION__, fileName, e.what()));
		}

		try {
			for (const auto &proficiencyJson : categoryJson.at("Proficiencies")) {
				const auto id = proficiencyJson["ProficiencyId"].get<uint16_t>();

				// Ten ids belong to weapons in two categories and are written in full into
				// both files, so each file stands alone for balancing. The copies are kept
				// identical by `python -m tools.proficiency_split validate`, which the
				// Repository Audit job runs on every change to the data or the tool. The
				// first copy read therefore wins and the rest are skipped without parsing
				// their levels.
				if (loaded.contains(id)) {
					continue;
				}

				Proficiency proficiency;
				proficiency.id = id;
				registerLevels(proficiencyJson["Levels"], proficiency);
				loaded[id] = std::move(proficiency);
			}
		} catch (const nlohmann::json::exception &e) {
			throw FailedToInitializeCanary(fmt::format("{} - JSON exception in file '{}': {}", __FUNCTION__, fileName, e.what()));
		}
	}

	// Same atomicity: parsed before anything is published, so a broken shaping file
	// leaves both the tree and the rules as they were.
	auto loadedShaping = loadShapingRules(folder);

	proficiencies = std::move(loaded);
	shapingRules = std::move(loadedShaping);

	g_logger().info("Weapon proficiencies {}! ({} proficiencies from {} files, {} shaping options)", reload ? "reloaded" : "loaded", proficiencies.size(), files.size(), shapingRules.options.size());

	return true;
}

void WeaponProficiency::load() {
	proficiency.clear();

	auto wp_kv = m_player.kv()->scoped("weapon-proficiency");
	for (const auto &key : wp_kv->keys()) {
		int parsedId = 0;
		const auto* begin = key.data();
		const auto* end = key.data() + key.size();
		const auto [ptr, ec] = std::from_chars(begin, end, parsedId);
		if (ec == std::errc::result_out_of_range) {
			g_logger().error("{} - Out of range key '{}' in weapon-proficiency KV: parse overflow (player: {})", __FUNCTION__, key, m_player.getName());
			continue;
		}
		if (ec == std::errc::invalid_argument || ptr != end) {
			g_logger().error("{} - Invalid key '{}' in weapon-proficiency KV: parse failure (player: {})", __FUNCTION__, key, m_player.getName());
			continue;
		}
		if (parsedId <= 0 || parsedId > std::numeric_limits<uint16_t>::max()) {
			g_logger().warn("{} - Skipping out of range weapon proficiency key '{}' (player: {})", __FUNCTION__, key, m_player.getName());
			continue;
		}

		const auto weaponId = static_cast<uint16_t>(parsedId);
		if (!isValidWeaponId(weaponId) || Item::items[weaponId].proficiencyId == 0) {
			g_logger().warn("{} - Skipping invalid weapon proficiency data for weapon ID '{}' (player: {})", __FUNCTION__, parsedId, m_player.getName());
			continue;
		}

		auto kv_it = wp_kv->get(key);
		if (!kv_it.has_value()) {
			continue;
		}

		proficiency[weaponId] = deserialize(kv_it.value());
		normalizeStoredState(weaponId);
	}
}

void WeaponProficiency::save(uint16_t weaponId) const {
	if (auto it = proficiency.find(weaponId); it != proficiency.end()) {
		m_player.kv()->scoped("weapon-proficiency")->set(std::to_string(weaponId), serialize(it->second));
	}
}

bool WeaponProficiency::saveAll() const {
	auto wp_kv = m_player.kv()->scoped("weapon-proficiency");

	for (const auto &storedKey : wp_kv->keys()) {
		int parsedId = 0;
		const auto* begin = storedKey.data();
		const auto* end = storedKey.data() + storedKey.size();
		const auto [ptr, ec] = std::from_chars(begin, end, parsedId);
		if (ec == std::errc::invalid_argument || ec == std::errc::result_out_of_range || ptr != end || parsedId <= 0 || parsedId > std::numeric_limits<uint16_t>::max()) {
			wp_kv->remove(storedKey);
			continue;
		}

		const auto weaponId = static_cast<uint16_t>(parsedId);
		if (!proficiency.contains(weaponId)) {
			wp_kv->remove(storedKey);
		}
	}

	for (const auto &[weaponId, weaponData] : proficiency) {
		wp_kv->set(std::to_string(weaponId), serialize(weaponData));
	}

	return true;
}

std::vector<uint16_t> WeaponProficiency::getTrackedWeaponIds() const {
	std::vector<uint16_t> weaponIds;
	weaponIds.reserve(proficiency.size());

	for (const auto &[weaponId, _] : proficiency) {
		weaponIds.push_back(weaponId);
	}

	(void)std::ranges::sort(weaponIds);
	return weaponIds;
}

WeaponProficiencyData WeaponProficiency::deserialize(const ValueWrapper &val) {
	auto map = val.get<MapType>();
	if (map.empty()) {
		return {};
	}

	WeaponProficiencyData weaponData;
	if (auto expIt = map.find("experience"); expIt != map.end()) {
		const auto storedExperience = expIt->second->get<IntType>();
		if (storedExperience <= 0) {
			weaponData.experience = 0;
		} else if (storedExperience > std::numeric_limits<uint32_t>::max()) {
			weaponData.experience = std::numeric_limits<uint32_t>::max();
		} else {
			weaponData.experience = static_cast<uint32_t>(storedExperience);
		}
	}
	if (auto masteredIt = map.find("mastered"); masteredIt != map.end()) {
		weaponData.mastered = masteredIt->second->get<BooleanType>();
	}
	if (auto perksIt = map.find("perks"); perksIt != map.end()) {
		weaponData.perks = deserializePerks(perksIt->second->getVariant());
	}

	return weaponData;
}

std::vector<ProficiencyPerk> WeaponProficiency::deserializePerks(const ValueWrapper &val) {
	auto array = val.get<ArrayType>();
	if (array.empty()) {
		return {};
	}

	std::vector<ProficiencyPerk> perks;

	for (const auto &item : array) {
		(void)perks.emplace_back(deserializePerk(item));
	}

	return perks;
}

ProficiencyPerk WeaponProficiency::deserializePerk(const ValueWrapper &val) {
	auto map = val.get<MapType>();
	if (map.empty()) {
		return {};
	}

	ProficiencyPerk perk;

	auto getInt = [&](const std::string &key) -> int64_t {
		if (auto it = map.find(key); it != map.end()) {
			return it->second->get<IntType>();
		}
		return 0;
	};

	perk.index = static_cast<uint8_t>(getInt("index"));
	perk.type = static_cast<WeaponProficiencyBonus_t>(getInt("type"));
	if (auto it = map.find("value"); it != map.end()) {
		perk.value = it->second->get<DoubleType>();
	}
	perk.level = static_cast<uint8_t>(getInt("level"));
	perk.augmentType = static_cast<uint8_t>(getInt("augmentType"));
	perk.bestiaryId = static_cast<uint16_t>(getInt("bestiaryId"));
	if (auto it = map.find("bestiaryName"); it != map.end()) {
		perk.bestiaryName = it->second->get<StringType>();
	}
	perk.element = static_cast<CombatType_t>(getInt("element"));
	perk.range = static_cast<uint8_t>(getInt("range"));
	perk.skillId = static_cast<skills_t>(getInt("skillId"));
	perk.spellId = static_cast<uint16_t>(getInt("spellId"));

	perk.rank = static_cast<uint8_t>(getInt("rank"));
	perk.shapingOptionId = static_cast<uint16_t>(getInt("shapingOptionId"));
	if (auto it = map.find("shaped"); it != map.end()) {
		perk.shaped = it->second->get<BooleanType>();
	}

	// Everything read above except (level, index, shaped, shapingOptionId, rank) is
	// carried for diagnostics only. collectValidSelectedPerks rebuilds every perk it
	// returns - a shaped one from its shaping option, any other from the proficiency
	// file - so nothing stored here is ever applied as-is, and a stale or tampered
	// effect cannot reach the player.
	//
	// A shaped perk with no option id is the one thing that cannot be rebuilt, so it
	// is demoted: the slot falls back to whatever the proficiency file defines.
	if (perk.shaped && perk.shapingOptionId == 0) {
		g_logger().error("{} - Demoting a shaped perk with no shaping option id (level {}, index {})", __FUNCTION__, perk.level, perk.index);
		perk.shaped = false;
		perk.rank = 0;
	}

	return perk;
}

ValueWrapper WeaponProficiency::serialize(const WeaponProficiencyData &weaponData) const {
	return {
		std::pair<const std::string, ValueWrapper> { "experience", ValueWrapper(static_cast<IntType>(weaponData.experience)) },
		std::pair<const std::string, ValueWrapper> { "mastered", ValueWrapper(weaponData.mastered) },
		std::pair<const std::string, ValueWrapper> { "perks", serializePerks(weaponData.perks) },
	};
}

ValueWrapper WeaponProficiency::serializePerk(const ProficiencyPerk &perk) const {
	return {
		{ "index", static_cast<IntType>(perk.index) },
		{ "shaped", perk.shaped },
		{ "shapingOptionId", static_cast<IntType>(perk.shapingOptionId) },
		{ "rank", static_cast<IntType>(perk.rank) },
		{ "type", static_cast<IntType>(perk.type) },
		{ "value", perk.value },
		{ "level", static_cast<IntType>(perk.level) },
		{ "augmentType", static_cast<IntType>(perk.augmentType) },
		{ "bestiaryId", static_cast<IntType>(perk.bestiaryId) },
		{ "bestiaryName", static_cast<StringType>(perk.bestiaryName) },
		{ "element", static_cast<IntType>(perk.element) },
		{ "range", static_cast<IntType>(perk.range) },
		{ "skillId", static_cast<IntType>(perk.skillId) },
		{ "spellId", static_cast<IntType>(perk.spellId) },
	};
}

std::vector<ValueWrapper> WeaponProficiency::serializePerks(const std::vector<ProficiencyPerk> &perks) const {
	std::vector<ValueWrapper> arrayWrapper;
	for (const auto &perk : perks) {
		(void)arrayWrapper.emplace_back(serializePerk(perk));
	}

	return arrayWrapper;
}

void WeaponProficiency::applyPerks(uint16_t weaponId, bool sendSkillUpdate /* = true */) {
	using enum WeaponProficiencyBonus_t;

	const auto &perks = getSelectedPerks(weaponId);
	for (const auto &selectedPerk : perks) {
		switch (selectedPerk.type) {
			case SPELL_AUGMENT: {
				WeaponProficiencySpells::Bonus augmentBonus;
				switch (selectedPerk.augmentType) {
					case AugmentType::DAMAGE:
						augmentBonus.increase.damage = selectedPerk.value;
						break;
					case AugmentType::HEAL:
						augmentBonus.increase.heal = selectedPerk.value;
						break;
					case AugmentType::COOLDOWN:
						augmentBonus.decrease.cooldown = static_cast<int32_t>(std::lround(std::abs(selectedPerk.value) * 1000.0));
						break;
					case AugmentType::LIFE_LEECH:
						augmentBonus.leech.life = selectedPerk.value;
						break;
					case AugmentType::MANA_LEECH:
						augmentBonus.leech.mana = selectedPerk.value;
						break;
					case AugmentType::CRITICAL_DAMAGE:
						augmentBonus.increase.criticalDamage = selectedPerk.value;
						break;
					case AugmentType::CRITICAL_CHANCE:
						augmentBonus.increase.criticalChance = selectedPerk.value;
						break;
					default:
						g_logger().error("[{}] - Unknown augment type {}", __FUNCTION__, selectedPerk.augmentType);
						continue;
				}
				addSpellBonus(selectedPerk.spellId, augmentBonus);
				break;
			}
			case SPECIALIZED_MAGIC_LEVEL:
				addSpecializedMagic(selectedPerk.element, selectedPerk.value);
				break;
			case AUTO_ATTACK_CRITICAL_EXTRA_DAMAGE:
			case AUTO_ATTACK_CRITICAL_HIT_CHANCE:
			case ELEMENTAL_HIT_CHANCE:
			case ELEMENTAL_CRITICAL_EXTRA_DAMAGE:
			case RUNE_CRITICAL_HIT_CHANCE:
			case RUNE_CRITICAL_EXTRA_DAMAGE:
			case CRITICAL_HIT_CHANCE:
			case CRITICAL_EXTRA_DAMAGE:
				applyCriticalBonus(selectedPerk);
				break;
			case WEAPON_PROFICIENCY_BESTIARY:
				addBestiaryDamage(selectedPerk.bestiaryId, selectedPerk.value);
				break;
			case POWERFUL_FOE_BONUS:
				addPowerfulFoeDamage(selectedPerk.value);
				break;
			case SKILL_BONUS:
				addSkillBonus(selectedPerk.skillId, selectedPerk.value);
				break;
			case LIFE_LEECH:
			case MANA_LEECH:
				addSkillBonus(selectedPerk.type == LIFE_LEECH ? SKILL_LIFE_LEECH_AMOUNT : SKILL_MANA_LEECH_AMOUNT, selectedPerk.value * 10000);
				break;
			case PERFECT_SHOT_DAMAGE:
				setPerfectShotBonus(selectedPerk.range, selectedPerk.value);
				break;
			case SKILL_PERCENTAGE_AUTO_ATTACK:
			case SKILL_PERCENTAGE_SPELL_DAMAGE:
			case SKILL_PERCENTAGE_SPELL_HEALING:
				applySkillPercentageBonus(selectedPerk);
				break;
			default:
				addStat(selectedPerk.type, selectedPerk.value);
				break;
		}
	}

	if (sendSkillUpdate) {
		m_player.sendSkills();
	}
}

void WeaponProficiency::applyCriticalBonus(const ProficiencyPerk &perk) {
	using enum WeaponProficiencyBonus_t;
	WeaponProficiencyCriticalBonus criticalBonus;
	criticalBonus.chance = (perk.type == AUTO_ATTACK_CRITICAL_HIT_CHANCE || perk.type == ELEMENTAL_HIT_CHANCE || perk.type == RUNE_CRITICAL_HIT_CHANCE || perk.type == CRITICAL_HIT_CHANCE) ? perk.value : 0;
	criticalBonus.damage = (perk.type == AUTO_ATTACK_CRITICAL_EXTRA_DAMAGE || perk.type == ELEMENTAL_CRITICAL_EXTRA_DAMAGE || perk.type == RUNE_CRITICAL_EXTRA_DAMAGE || perk.type == CRITICAL_EXTRA_DAMAGE) ? perk.value : 0;

	switch (perk.type) {
		case AUTO_ATTACK_CRITICAL_EXTRA_DAMAGE:
		case AUTO_ATTACK_CRITICAL_HIT_CHANCE:
			addAutoAttackCritical(criticalBonus);
			break;
		case ELEMENTAL_HIT_CHANCE:
		case ELEMENTAL_CRITICAL_EXTRA_DAMAGE:
			addElementCritical(perk.element, criticalBonus);
			break;
		case RUNE_CRITICAL_HIT_CHANCE:
		case RUNE_CRITICAL_EXTRA_DAMAGE:
			addRunesCritical(criticalBonus);
			break;
		case CRITICAL_HIT_CHANCE:
		case CRITICAL_EXTRA_DAMAGE:
			addGeneralCritical(criticalBonus);
			break;
		default:
			break;
	}
}

void WeaponProficiency::applySkillPercentageBonus(const ProficiencyPerk &perk) {
	using enum WeaponProficiencyBonus_t;
	using enum SkillPercentage_t;
	SkillPercentage_t type;
	switch (perk.type) {
		case SKILL_PERCENTAGE_AUTO_ATTACK:
			type = AutoAttack;
			break;
		case SKILL_PERCENTAGE_SPELL_DAMAGE:
			type = SpellDamage;
			break;
		case SKILL_PERCENTAGE_SPELL_HEALING:
			type = SpellHealing;
			break;
		default:
			return;
	}
	addSkillPercentage(perk.skillId, type, perk.value);
}

std::vector<ProficiencyPerk> WeaponProficiency::getSelectedPerks(uint16_t weaponId) const {
	return collectValidSelectedPerks(weaponId);
}

void WeaponProficiency::clearSelectedPerks(uint16_t weaponId) {
	if (weaponId == 0) {
		return;
	}

	if (auto it = proficiency.find(weaponId); it != proficiency.end()) {
		it->second.perks.clear();
	}
}

void WeaponProficiency::setSelectedPerk(uint8_t level, uint8_t perkIndex, uint16_t weaponId /* = 0 */) {
	if (weaponId == 0) {
		weaponId = m_player.getWeaponId(true);
	}

	if (weaponId == 0) {
		g_logger().error("{} - Invalid weapon ID: {}", __FUNCTION__, weaponId);
		return;
	}

	if (!isValidWeaponId(weaponId)) {
		g_logger().error("{} - Weapon ID out of range: {}", __FUNCTION__, weaponId);
		return;
	}

	auto playerProficiencyIt = proficiency.find(weaponId);
	if (playerProficiencyIt == proficiency.end()) {
		g_logger().error("{} - No stored proficiency data for weapon ID: {}", __FUNCTION__, weaponId);
		return;
	}

	auto proficiencyId = Item::items[weaponId].proficiencyId;
	if (!proficiencies.contains(proficiencyId)) {
		g_logger().error("{} - Proficiency not found for weapon ID: {}", __FUNCTION__, weaponId);
		return;
	}

	const auto unlockedLevelCount = getUnlockedLevelCount(weaponId);
	if (level >= unlockedLevelCount) {
		g_logger().warn("{} - Attempt to select locked proficiency level {} for weapon ID: {}", __FUNCTION__, level, weaponId);
		return;
	}

	const auto &info = proficiencies.at(proficiencyId);
	if (level >= info.level.size()) {
		g_logger().error("{} - Proficiency level exceeds maximum size for weapon ID: {}", __FUNCTION__, weaponId);
		return;
	}
	const auto &selectedLevel = info.level.at(level);

	if (perkIndex >= selectedLevel.perks.size()) {
		g_logger().error("{} - Proficiency level {} exceeds maximum perks size for weapon ID: {}", __FUNCTION__, level, weaponId);
		return;
	}
	const auto &selectedPerk = selectedLevel.perks.at(perkIndex);

	const auto hasLevelSelected = std::ranges::any_of(playerProficiencyIt->second.perks, [level](const auto &perk) {
		return perk.level == level;
	});
	if (hasLevelSelected) {
		g_logger().warn("{} - Duplicate proficiency level {} selection ignored for weapon ID: {}", __FUNCTION__, level, weaponId);
		return;
	}

	playerProficiencyIt->second.perks.push_back(selectedPerk);
}

ProficiencyPerk* WeaponProficiency::findStoredPerk(uint16_t weaponId, uint8_t level) {
	const auto it = proficiency.find(weaponId);
	if (it == proficiency.end()) {
		return nullptr;
	}

	const auto perkIt = std::ranges::find(it->second.perks, level, &ProficiencyPerk::level);
	return perkIt == it->second.perks.end() ? nullptr : &*perkIt;
}

const ProficiencyPerk* WeaponProficiency::findStoredPerk(uint16_t weaponId, uint8_t level) const {
	return const_cast<WeaponProficiency*>(this)->findStoredPerk(weaponId, level);
}

uint8_t WeaponProficiency::countShapedPerks(uint16_t weaponId) const {
	const auto it = proficiency.find(weaponId);
	if (it == proficiency.end()) {
		return 0;
	}

	return static_cast<uint8_t>(std::ranges::count(it->second.perks, true, &ProficiencyPerk::shaped));
}

// The checks every operation shares: the feature is configured, the weapon is real
// and known to this player, the tree level is unlocked, and the player is where the
// rules allow shaping.
ProficiencyShapingResult WeaponProficiency::checkShapingPreconditions(uint16_t weaponId, uint8_t level) const {
	using enum ProficiencyShapingResult;

	if (shapingRules.empty()) {
		return NotConfigured;
	}

	if (!isValidWeaponId(weaponId)) {
		return InvalidWeapon;
	}

	if (!proficiency.contains(weaponId) || !proficiencies.contains(Item::items[weaponId].proficiencyId)) {
		return NoProficiencyData;
	}

	if (level >= getUnlockedLevelCount(weaponId)) {
		return LevelLocked;
	}

	if (shapingRules.requiresProtectionZone) {
		const auto &tile = m_player.getTile();
		if (!tile || !tile->hasFlag(TILESTATE_PROTECTIONZONE)) {
			return NotInProtectionZone;
		}
	}

	return Success;
}

// Bring the stored state back in line, persist it, and make the change visible at
// once if the weapon is the one in hand. Every operation ends here, so none of them
// can forget a step.
void WeaponProficiency::commitShapingChange(uint16_t weaponId) {
	normalizeStoredState(weaponId);
	save(weaponId);

	if (m_player.getWeaponId(true) == weaponId) {
		clearAllStats();
		applyPerks(weaponId, false);
		m_player.sendStats();
		m_player.sendSkills();
	}

	m_player.sendWeaponProficiency(weaponId);
}

namespace {
	// Weighted draw over the options a roll may pick from. `excluded` keeps a reshape
	// from offering the perk the player already has.
	const ProficiencyShapingOption* rollOption(const ProficiencyShapingRules &rules, const std::vector<uint16_t> &excluded) {
		const auto total = std::accumulate(
			rules.options.begin(), rules.options.end(), uint64_t { 0 },
			[&excluded](uint64_t sum, const ProficiencyShapingOption &option) {
				return std::ranges::find(excluded, option.id) == excluded.end() ? sum + option.weight : sum;
			}
		);

		if (total == 0) {
			return nullptr;
		}

		auto roll = static_cast<uint64_t>(uniform_random(1, static_cast<int32_t>(std::min<uint64_t>(total, std::numeric_limits<int32_t>::max()))));
		for (const auto &option : rules.options) {
			if (std::ranges::find(excluded, option.id) != excluded.end()) {
				continue;
			}

			if (roll <= option.weight) {
				return &option;
			}

			roll -= option.weight;
		}

		return nullptr;
	}
}

ProficiencyShapingResult WeaponProficiency::shapePerk(uint16_t weaponId, uint8_t level, uint8_t perkIndex) {
	using enum ProficiencyShapingResult;

	if (const auto precondition = checkShapingPreconditions(weaponId, level); precondition != Success) {
		return precondition;
	}

	const auto &proficiencyInfo = proficiencies.at(Item::items[weaponId].proficiencyId);
	if (level >= proficiencyInfo.level.size() || perkIndex >= proficiencyInfo.level[level].perks.size()) {
		return InvalidPerkIndex;
	}

	if (const auto* existing = findStoredPerk(weaponId, level); existing != nullptr && existing->shaped) {
		return AlreadyShaped;
	}

	// Which shaping slot is being bought follows from how many are already in use, so
	// the first shaping on a weapon costs what Slots[0] says and the second Slots[1].
	const auto shapedCount = countShapedPerks(weaponId);
	if (shapedCount >= shapingRules.slots.size()) {
		return NoSlotsLeft;
	}

	const auto &slot = shapingRules.slots[shapedCount];
	if (getUnlockedLevelCount(weaponId) < slot.requiredProficiencyLevel) {
		return ProficiencyTooLow;
	}

	if (slot.requiresMastery && !proficiency.at(weaponId).mastered) {
		return NotMastered;
	}

	if (m_player.getForgeDusts() < slot.unlockDustCost) {
		return NotEnoughDust;
	}

	// A freshly shaped slot always rolls in at rank 0, its lowest value.
	const auto* option = rollOption(shapingRules, {});
	if (option == nullptr) {
		return UnknownOption;
	}

	m_player.removeForgeDusts(slot.unlockDustCost);

	auto &perks = proficiency.at(weaponId).perks;
	std::erase_if(perks, [level](const auto &perk) { return perk.level == level; });
	perks.push_back(buildShapedPerk(*option, 0, level, perkIndex));

	commitShapingChange(weaponId);
	return Success;
}

ProficiencyShapingResult WeaponProficiency::refinePerk(uint16_t weaponId, uint8_t level) {
	using enum ProficiencyShapingResult;

	if (const auto precondition = checkShapingPreconditions(weaponId, level); precondition != Success) {
		return precondition;
	}

	auto* stored = findStoredPerk(weaponId, level);
	if (stored == nullptr || !stored->shaped) {
		return NotShaped;
	}

	const auto* option = shapingRules.findOption(stored->shapingOptionId);
	if (option == nullptr) {
		return UnknownOption;
	}

	const uint8_t nextRank = stored->rank + 1;
	if (nextRank > option->maxRank()) {
		return AtMaximumRank;
	}

	if (nextRank >= shapingRules.refineDustCostPerRank.size()) {
		return RefineDisabled;
	}

	const auto cost = shapingRules.refineDustCostPerRank[nextRank];
	if (m_player.getForgeDusts() < cost) {
		return NotEnoughDust;
	}

	m_player.removeForgeDusts(cost);
	stored->rank = nextRank;

	commitShapingChange(weaponId);
	return Success;
}

std::vector<uint16_t> WeaponProficiency::rollReshapeOptions(uint16_t weaponId, uint8_t level) const {
	std::vector<uint16_t> offered;

	const auto* stored = findStoredPerk(weaponId, level);
	if (stored == nullptr || !stored->shaped || shapingRules.empty()) {
		return offered;
	}

	// The perk the player already has is never offered back to them, and neither is
	// an option already drawn for this reshape.
	std::vector<uint16_t> excluded { stored->shapingOptionId };
	for (uint8_t i = 0; i < shapingRules.reshapeOptionCount; ++i) {
		const auto* option = rollOption(shapingRules, excluded);
		if (option == nullptr) {
			break;
		}

		offered.push_back(option->id);
		excluded.push_back(option->id);
	}

	return offered;
}

ProficiencyShapingResult WeaponProficiency::reshapePerk(uint16_t weaponId, uint8_t level, uint16_t optionId) {
	using enum ProficiencyShapingResult;

	if (const auto precondition = checkShapingPreconditions(weaponId, level); precondition != Success) {
		return precondition;
	}

	auto* stored = findStoredPerk(weaponId, level);
	if (stored == nullptr || !stored->shaped) {
		return NotShaped;
	}

	const auto* option = shapingRules.findOption(optionId);
	if (option == nullptr) {
		return UnknownOption;
	}

	if (m_player.getForgeDusts() < shapingRules.reshapeDustCost) {
		return NotEnoughDust;
	}

	m_player.removeForgeDusts(shapingRules.reshapeDustCost);

	// Reshaping keeps the rank: the player swaps the effect, not the progress paid
	// for. A rank the new option cannot reach is clamped by buildShapedPerk.
	const auto perkIndex = stored->index;
	const auto rank = stored->rank;
	*stored = buildShapedPerk(*option, rank, level, perkIndex);

	commitShapingChange(weaponId);
	return Success;
}

ProficiencyShapingResult WeaponProficiency::clearShapedPerk(uint16_t weaponId, uint8_t level) {
	using enum ProficiencyShapingResult;

	if (const auto precondition = checkShapingPreconditions(weaponId, level); precondition != Success) {
		return precondition;
	}

	auto* stored = findStoredPerk(weaponId, level);
	if (stored == nullptr || !stored->shaped) {
		return NotShaped;
	}

	if (m_player.getForgeDusts() < shapingRules.clearDustCost) {
		return NotEnoughDust;
	}

	m_player.removeForgeDusts(shapingRules.clearDustCost);

	// Clearing restores the slot to the perk the proficiency file defines there: the
	// selection stays, it simply stops being shaped. The dust spent on the shaping is
	// not refunded.
	stored->shaped = false;
	stored->shapingOptionId = 0;
	stored->rank = 0;

	commitShapingChange(weaponId);
	return Success;
}

void WeaponProficiency::onDataReloaded() {
	// The proficiency files were reloaded under this player's stored state. Bring
	// that state in line with the new data exactly as a login would: clamp the
	// experience to the new maximum, recompute `mastered`, and drop a selection
	// whose level or perk index the edit removed. Reads already filter those out,
	// but without this the stale entries would be written back by the next save.
	for (const auto weaponId : getTrackedWeaponIds()) {
		normalizeStoredState(weaponId);
	}

	// Bonuses currently applied came from the old data, so drop them and re-apply
	// from what is loaded now. The caller sends the updated stats and skills.
	clearAllStats();
	if (const auto weaponId = m_player.getWeaponId(true); weaponId != 0) {
		applyPerks(weaponId, false);
	}
}

std::unordered_map<std::pair<uint16_t, uint8_t>, double, PairHash, PairEqual> WeaponProficiency::getActiveAugments(uint16_t weaponId) {
	std::unordered_map<std::pair<uint16_t, uint8_t>, double, PairHash, PairEqual> augments;

	weaponId = weaponId == 0 ? m_player.getWeaponId(true) : weaponId;

	if (weaponId == 0) {
		g_logger().error("{} - Invalid weapon ID: {}", __FUNCTION__, weaponId);
		return augments;
	}

	const auto &perks = getSelectedPerks(weaponId);

	for (const auto &perk : perks) {
		if (perk.spellId && perk.augmentType) {
			const auto key = std::make_pair(perk.spellId, perk.augmentType);
			augments[key] += perk.value;
		}
	}

	return augments;
}

const std::vector<uint32_t> &WeaponProficiency::getExperienceArray(uint16_t weaponId) const {
	if (!isValidWeaponId(weaponId)) {
		g_logger().error("{} - Invalid weapon ID: {}", __FUNCTION__, weaponId);
		return standardExperience;
	}

	const auto &itemType = Item::items[weaponId];
	if (itemType.ammoType == AMMO_BOLT) {
		return crossbowExperience;
	}

	if (usesKnightProficiencyTable(itemType)) {
		return knightExperience;
	}

	return standardExperience;
}

uint32_t WeaponProficiency::nextLevelExperience(uint16_t weaponId) {
	if (!isValidWeaponId(weaponId)) {
		g_logger().error("{} - Invalid weapon ID: {}", __FUNCTION__, weaponId);
		return 0;
	}

	const auto &experienceArray = getExperienceArray(weaponId);
	if (experienceArray.empty()) {
		return 0;
	}

	auto prof_it = proficiencies.find(Item::items[weaponId].proficiencyId);
	if (prof_it == proficiencies.end()) {
		g_logger().error("{} - Proficiency not found for weapon ID: {}", __FUNCTION__, weaponId);
		return 0;
	}

	const auto &proficiencyInfo = prof_it->second;
	if (!proficiency.contains(weaponId)) {
		return experienceArray[0];
	}

	const auto &playerProficiency = proficiency.at(weaponId);
	const auto maxExpLevels = getMasteryExperienceTierCount(proficiencyInfo, experienceArray);
	for (size_t i = 0; i < maxExpLevels; ++i) {
		if (playerProficiency.experience >= experienceArray[i]) {
			continue;
		}

		return experienceArray[i] - playerProficiency.experience;
	}

	return 0;
}

uint32_t WeaponProficiency::getMaxExperience(uint16_t weaponId) const {
	if (!isValidWeaponId(weaponId)) {
		g_logger().error("{} - Invalid weapon ID: {}", __FUNCTION__, weaponId);
		return 0;
	}

	const auto &experienceArray = getExperienceArray(weaponId);
	auto prof_it = proficiencies.find(Item::items[weaponId].proficiencyId);
	if (prof_it == proficiencies.end()) {
		g_logger().error("{} - Proficiency not found for weapon ID: {}", __FUNCTION__, weaponId);
		return 0;
	}

	const auto &proficiencyInfo = prof_it->second;
	const auto masteryTierCount = getMasteryExperienceTierCount(proficiencyInfo, experienceArray);
	if (masteryTierCount > 0) {
		return experienceArray[masteryTierCount - 1];
	}
	return 0;
}

void WeaponProficiency::addExperience(uint32_t experience, uint16_t weaponId /* = 0 */) {
	weaponId = weaponId > 0 ? weaponId : m_player.getWeaponId(true);

	if (weaponId == 0) {
		return;
	}

	experience = scaleWeaponProficiencyExperienceGain(experience);
	if (experience == 0) {
		return;
	}

	// Validate that the item has a valid proficiency
	if (!isValidWeaponId(weaponId) || Item::items[weaponId].proficiencyId == 0) {
		g_logger().debug("{} - Weapon ID '{}' has no proficiency assigned", __FUNCTION__, weaponId);
		return;
	}

	if (nextLevelExperience(weaponId) <= 0) {
		return;
	}

	uint32_t maxExperience = getMaxExperience(weaponId);

	if (!proficiency.contains(weaponId)) {
		const auto [_, inserted] = proficiency.try_emplace(weaponId, std::min(experience, maxExperience));
		if (!inserted) {
			g_logger().warn("{} - Failed to create proficiency state for weapon ID '{}'", __FUNCTION__, weaponId);
			return;
		}
		m_player.sendWeaponProficiency(weaponId);

		return;
	}

	const uint64_t newExperience = static_cast<uint64_t>(proficiency[weaponId].experience) + experience;

	if (newExperience >= maxExperience) {
		proficiency[weaponId].mastered = true;
		proficiency[weaponId].experience = maxExperience;
		m_player.sendWeaponProficiency(weaponId);

		return;
	}

	proficiency[weaponId].experience = static_cast<uint32_t>(newExperience);

	m_player.sendWeaponProficiency(weaponId);
}

uint32_t WeaponProficiency::getBosstiaryExperience(BosstiaryRarity_t rarity) const {
	using enum BosstiaryRarity_t;
	switch (rarity) {
		case RARITY_BANE:
			return 500;
		case RARITY_ARCHFOE:
			return 5000;
		case RARITY_NEMESIS:
			return 15000;
		default:
			return 0;
	}
}

uint32_t WeaponProficiency::getBestiaryExperience(uint8_t monsterStar) const {
	if (monsterStar > 5) { // Assuming 5 is max star
		monsterStar = 5;
	}
	double poly = -1.133 * std::pow(monsterStar, 5) + 14.083 * std::pow(monsterStar, 4) + -59.666 * std::pow(monsterStar, 3) + 102.916 * std::pow(monsterStar, 2) + -27.2 * monsterStar + 1.0;
	return static_cast<uint32_t>(std::max(0.0, poly));
}

uint32_t WeaponProficiency::getExperience(uint16_t weaponId /* = 0 */) const {
	weaponId = weaponId > 0 ? weaponId : m_player.getWeaponId(true);
	if (weaponId == 0) {
		return 0;
	}

	if (!proficiency.contains(weaponId)) {
		return 0;
	}

	return proficiency.at(weaponId).experience;
}

bool WeaponProficiency::isUpgradeAvailable(uint16_t weaponId /* = 0 */) const {
	weaponId = weaponId > 0 ? weaponId : m_player.getWeaponId(true);

	if (weaponId == 0) {
		g_logger().error("{} - Invalid weapon ID: {}", __FUNCTION__, weaponId);
		return false;
	}

	if (!isValidWeaponId(weaponId)) {
		g_logger().error("{} - Weapon ID out of range: {}", __FUNCTION__, weaponId);
		return false;
	}

	const auto &experienceArray = getExperienceArray(weaponId);

	auto proficiencyId = Item::items[weaponId].proficiencyId;

	if (!proficiency.contains(weaponId)) {
		return false;
	}

	if (!proficiencies.contains(proficiencyId)) {
		return false;
	}

	const auto &proficiencyInfo = proficiencies.at(proficiencyId);

	const auto &selectedPerks = getSelectedPerks(weaponId);
	const auto &playerProficiency = proficiency.at(weaponId);

	size_t limit = std::min(experienceArray.size(), static_cast<size_t>(proficiencyInfo.maxLevel));
	for (size_t i = 0; i < limit; ++i) {
		if (playerProficiency.experience < experienceArray[i]) {
			break;
		}

		if (selectedPerks.size() < i + 1) {
			return true;
		}
	}

	return false;
}

size_t WeaponProficiency::getUnlockedLevelCount(uint16_t weaponId) const {
	if (!isValidWeaponId(weaponId)) {
		return 0;
	}

	const auto playerProficiencyIt = proficiency.find(weaponId);
	if (playerProficiencyIt == proficiency.end()) {
		return 0;
	}

	const auto profIt = proficiencies.find(Item::items[weaponId].proficiencyId);
	if (profIt == proficiencies.end()) {
		return 0;
	}

	const auto &experienceArray = getExperienceArray(weaponId);
	const auto &proficiencyInfo = profIt->second;
	if (proficiencyInfo.maxLevel == 0) {
		return 0;
	}

	const size_t limit = std::min(experienceArray.size(), static_cast<size_t>(proficiencyInfo.maxLevel));
	size_t unlockedLevels = 0;
	for (size_t i = 0; i < limit; ++i) {
		if (playerProficiencyIt->second.experience < experienceArray[i]) {
			break;
		}

		++unlockedLevels;
	}

	return unlockedLevels;
}

std::vector<ProficiencyPerk> WeaponProficiency::collectValidSelectedPerks(uint16_t weaponId) const {
	if (!isValidWeaponId(weaponId)) {
		return {};
	}

	const auto playerProficiencyIt = proficiency.find(weaponId);
	if (playerProficiencyIt == proficiency.end()) {
		return {};
	}

	const auto profIt = proficiencies.find(Item::items[weaponId].proficiencyId);
	if (profIt == proficiencies.end()) {
		return {};
	}

	const auto unlockedLevelCount = getUnlockedLevelCount(weaponId);
	if (unlockedLevelCount == 0) {
		return {};
	}

	const auto &storedPerks = playerProficiencyIt->second.perks;
	const auto &proficiencyInfo = profIt->second;
	std::vector<ProficiencyPerk> validPerks;
	validPerks.reserve(std::min(storedPerks.size(), unlockedLevelCount));
	std::vector<bool> usedLevels(proficiencyInfo.level.size(), false);

	for (const auto &storedPerk : storedPerks) {
		const auto level = static_cast<size_t>(storedPerk.level);
		const auto index = static_cast<size_t>(storedPerk.index);

		if (level >= unlockedLevelCount || level >= proficiencyInfo.level.size() || usedLevels[level]) {
			continue;
		}

		const auto &levelPerks = proficiencyInfo.level[level].perks;
		if (index >= levelPerks.size()) {
			continue;
		}

		// Every perk returned from here is rebuilt, never replayed from storage. A
		// normal selection comes from the proficiency file; a shaped one is rebuilt
		// from its shaping option at its stored rank. That is what keeps the data
		// authoritative: edit shaping.json and the next read of an existing perk
		// already reflects it.
		if (storedPerk.shaped) {
			const auto* option = shapingRules.findOption(storedPerk.shapingOptionId);
			if (option == nullptr) {
				// The option was removed from shaping.json. The slot falls back to the
				// perk the proficiency file defines there, which is exactly what Clear
				// produces. The dust spent on the shaping is not refunded.
				g_logger().debug("{} - Shaping option {} no longer exists; slot (level {}, index {}) falls back to the proficiency file", __FUNCTION__, storedPerk.shapingOptionId, level, index);
				validPerks.push_back(levelPerks[index]);
			} else {
				validPerks.push_back(buildShapedPerk(*option, storedPerk.rank, storedPerk.level, storedPerk.index));
			}
		} else {
			validPerks.push_back(levelPerks[index]);
		}

		usedLevels[level] = true;
	}

	(void)std::ranges::sort(validPerks, [](const auto &lhs, const auto &rhs) {
		if (lhs.level != rhs.level) {
			return lhs.level < rhs.level;
		}

		return lhs.index < rhs.index;
	});

	return validPerks;
}

void WeaponProficiency::normalizeStoredState(uint16_t weaponId) {
	if (!isValidWeaponId(weaponId)) {
		return;
	}

	const auto playerProficiencyIt = proficiency.find(weaponId);
	if (playerProficiencyIt == proficiency.end()) {
		return;
	}

	const auto maxExperience = getMaxExperience(weaponId);
	if (maxExperience > 0 && playerProficiencyIt->second.experience > maxExperience) {
		playerProficiencyIt->second.experience = maxExperience;
	}

	if (maxExperience > 0) {
		playerProficiencyIt->second.mastered = playerProficiencyIt->second.experience >= maxExperience;
	}

	playerProficiencyIt->second.perks = collectValidSelectedPerks(weaponId);
}

void WeaponProficiency::addStat(WeaponProficiencyBonus_t type, double_t value) {
	auto enumValue = static_cast<uint8_t>(type);
	if (enumValue >= magic_enum::enum_count<WeaponProficiencyBonus_t>()) {
		g_logger().error("[{}]. Type {} is out of range, value {}. Error message: {}", __FUNCTION__, enumValue, value, "Enum value is out of range");
		return;
	}
	m_stats[enumValue] += value;
}

double_t WeaponProficiency::getStat(WeaponProficiencyBonus_t type) const {
	auto enumValue = static_cast<uint8_t>(type);
	try {
		return m_stats.at(enumValue);
	} catch (const std::out_of_range &e) {
		g_logger().error("[{}]. Instant type {}. Error message: {}", __FUNCTION__, enumValue, e.what());
	}
	return 0;
}

void WeaponProficiency::resetStats() {
	m_stats.fill(0);
}

void WeaponProficiency::addSkillPercentage(skills_t skill, SkillPercentage_t type, double_t value) {
	using enum SkillPercentage_t;
	auto &skillPercentage = m_skillPercentages[skill];
	skillPercentage.skill = skill;

	switch (type) {
		case AutoAttack:
			skillPercentage.autoAttack += value;
			break;
		case SpellDamage:
			skillPercentage.spellDamage += value;
			break;
		case SpellHealing:
			skillPercentage.spellHealing += value;
			break;
		default:
			break;
	}
}

const SkillPercentage &WeaponProficiency::getSkillPercentage(skills_t skill) const {
	static const SkillPercentage defaultSkillPercentage;
	if (auto it = m_skillPercentages.find(skill); it != m_skillPercentages.end()) {
		return it->second;
	}
	return defaultSkillPercentage;
}

void WeaponProficiency::addSpecializedMagic(CombatType_t type, uint16_t value) {
	auto enumValue = static_cast<uint8_t>(type);
	try {
		m_specializedMagic.at(enumValue) += value;
	} catch (const std::out_of_range &e) {
		g_logger().error("[{}]. Type {} is out of range, value {}. Error message: {}", __FUNCTION__, enumValue, value, e.what());
	}
}

uint16_t WeaponProficiency::getSpecializedMagic(CombatType_t type) const {
	auto enumValue = static_cast<uint8_t>(type);
	try {
		return m_specializedMagic.at(enumValue);
	} catch (const std::out_of_range &e) {
		g_logger().error("[{}]. Instant type {}. Error message: {}", __FUNCTION__, enumValue, e.what());
	}
	return 0;
}

void WeaponProficiency::resetSpecializedMagic() {
	m_specializedMagic.fill(0);
}

uint32_t WeaponProficiency::getSkillBonus(skills_t type) const {
	const auto enumValue = static_cast<int32_t>(type);
	if (!isTrackedWeaponProficiencySkill(type)) {
		g_logger().error("[{}]. Skill type {} is out of range.", __FUNCTION__, enumValue);
		return 0;
	}

	return m_skills[static_cast<size_t>(enumValue)];
}

void WeaponProficiency::addSkillBonus(skills_t type, uint32_t value) {
	const auto enumValue = static_cast<int32_t>(type);
	if (!isTrackedWeaponProficiencySkill(type)) {
		g_logger().error("[{}]. Type {} is out of range, value {}.", __FUNCTION__, enumValue, value);
		return;
	}

	m_skills[static_cast<size_t>(enumValue)] += value;
}

void WeaponProficiency::resetSkillBonuses() {
	m_skills.fill(0);
}

double_t WeaponProficiency::getPowerfulFoeDamage() const {
	return m_powerfulFoeDamage;
}

void WeaponProficiency::addPowerfulFoeDamage(double_t percent) {
	m_powerfulFoeDamage += percent;
}

void WeaponProficiency::resetPowerfulFoeDamage() {
	m_powerfulFoeDamage = 0;
}

const WeaponProficiencyCriticalBonus &WeaponProficiency::getAutoAttackCritical() const {
	return m_autoAttackCritical;
}

void WeaponProficiency::addAutoAttackCritical(const WeaponProficiencyCriticalBonus &bonus) {
	m_autoAttackCritical.chance += bonus.chance;
	m_autoAttackCritical.damage += bonus.damage;
}

const WeaponProficiencyCriticalBonus &WeaponProficiency::getRunesCritical() const {
	return m_runesCritical;
}

void WeaponProficiency::addRunesCritical(const WeaponProficiencyCriticalBonus &bonus) {
	m_runesCritical.chance += bonus.chance;
	m_runesCritical.damage += bonus.damage;
}

const WeaponProficiencyCriticalBonus &WeaponProficiency::getGeneralCritical() const {
	return m_generalCritical;
}

void WeaponProficiency::addGeneralCritical(const WeaponProficiencyCriticalBonus &bonus) {
	m_generalCritical.chance += bonus.chance;
	m_generalCritical.damage += bonus.damage;
}

WeaponProficiencyCriticalBonus WeaponProficiency::getElementCritical(CombatType_t type) const {
	if (type == COMBAT_NONE) {
		return {};
	}
	const auto enumValue = static_cast<uint8_t>(type);
	if (enumValue < m_elementCritical.size()) {
		return m_elementCritical[enumValue];
	}
	g_logger().error("[{}]. Element type {} is out of range.", __FUNCTION__, enumValue);
	return {};
}

void WeaponProficiency::addElementCritical(CombatType_t type, const WeaponProficiencyCriticalBonus &bonus) {
	if (type == COMBAT_NONE) {
		return;
	}

	const auto enumValue = static_cast<uint8_t>(type);
	if (enumValue >= m_elementCritical.size()) {
		g_logger().error("[{}]. Type {} is out of range.", __FUNCTION__, enumValue);
		return;
	}

	m_elementCritical[enumValue].chance += bonus.chance;
	m_elementCritical[enumValue].damage += bonus.damage;
}

uint32_t WeaponProficiency::getSpellBonus(uint16_t spellId, WeaponProficiencySpellBoost_t boost) const {
	using enum WeaponProficiencySpellBoost_t;

	auto it = m_spellsBonuses.find(spellId);
	if (it == m_spellsBonuses.end()) {
		return 0;
	}

	const auto &[leech, increase, decrease] = it->second;
	switch (boost) {
		case COOLDOWN:
			return decrease.cooldown;
		case MANA:
			return decrease.manaCost;
		case SECONDARY_GROUP_COOLDOWN:
			return decrease.secondaryGroupCooldown;
		case CRITICAL_CHANCE:
			return increase.criticalChance;
		case CRITICAL_DAMAGE:
			return increase.criticalDamage;
		case DAMAGE:
			return increase.damage;
		case DAMAGE_REDUCTION:
			return increase.damageReduction;
		case HEAL:
			return increase.heal;
		case LIFE_LEECH:
			return leech.life;
		case MANA_LEECH:
			return leech.mana;
		default:
			return 0;
	}
}

void WeaponProficiency::addSpellBonus(uint16_t spellId, const WeaponProficiencySpells::Bonus &bonus) {
	if (auto it = m_spellsBonuses.find(spellId); it != m_spellsBonuses.end()) {
		it->second.decrease.cooldown += bonus.decrease.cooldown;
		it->second.decrease.manaCost += bonus.decrease.manaCost;
		it->second.decrease.secondaryGroupCooldown += bonus.decrease.secondaryGroupCooldown;
		it->second.increase.additionalTarget += bonus.increase.additionalTarget;
		it->second.increase.area = it->second.increase.area || bonus.increase.area;
		it->second.increase.criticalChance += bonus.increase.criticalChance;
		it->second.increase.criticalDamage += bonus.increase.criticalDamage;
		it->second.increase.damage += bonus.increase.damage;
		it->second.increase.damageReduction += bonus.increase.damageReduction;
		it->second.increase.duration += bonus.increase.duration;
		it->second.increase.heal += bonus.increase.heal;
		it->second.leech.life += bonus.leech.life;
		it->second.leech.mana += bonus.leech.mana;
		return;
	}
	m_spellsBonuses[spellId] = bonus;
}

void WeaponProficiency::setPerfectShotBonus(uint8_t range, double_t damage) {
	m_perfectShot.range = range;
	m_perfectShot.damage += damage;
}

const WeaponProficiencyPerfectShotBonus &WeaponProficiency::getPerfectShotBonus() const {
	return m_perfectShot;
}

void WeaponProficiency::resetPerfectShotBonus() {
	m_perfectShot = {};
}

double_t WeaponProficiency::getBestiaryDamage(uint8_t race) const {
	if (auto it = m_bestiaryDamage.find(race); it != m_bestiaryDamage.end()) {
		return it->second;
	}

	return 0;
}

void WeaponProficiency::addBestiaryDamage(uint8_t race, double_t bonus) {
	if (auto it = m_bestiaryDamage.find(race); it != m_bestiaryDamage.end()) {
		it->second += bonus;
		return;
	}
	m_bestiaryDamage[race] = bonus;
}

void WeaponProficiency::resetBestiaryDamage() {
	m_bestiaryDamage.clear();
}

uint16_t WeaponProficiency::getSkillValueFromWeapon() const {
	const auto &weapon = m_player.getWeapon(true);
	if (!weapon) {
		return 0;
	}

	const auto weaponId = weapon->getID();
	if (!isValidWeaponId(weaponId)) {
		g_logger().error("{} - Invalid weapon ID: {}", __FUNCTION__, weaponId);
		return 0;
	}

	switch (Item::items[weaponId].type) {
		case ITEM_TYPE_SWORD:
			return m_player.getSkillLevel(SKILL_SWORD);
		case ITEM_TYPE_AXE:
			return m_player.getSkillLevel(SKILL_AXE);
		case ITEM_TYPE_CLUB:
			return m_player.getSkillLevel(SKILL_CLUB);
		case ITEM_TYPE_WAND:
			return m_player.getMagicLevel();
		case ITEM_TYPE_DISTANCE:
			return m_player.getSkillLevel(SKILL_DISTANCE);
		default:
			return 0;
	}
}

void WeaponProficiency::applyAutoAttackCritical(CombatDamage &damage) const {
	if (damage.origin == ORIGIN_FIST || damage.origin == ORIGIN_MELEE || damage.origin == ORIGIN_RANGED) {
		const auto &autoAttackCritical = getAutoAttackCritical();
		damage.criticalChance += autoAttackCritical.chance * 10000;
		damage.criticalDamage += autoAttackCritical.damage * 10000;
	}
}

void WeaponProficiency::applyRunesCritical(CombatDamage &damage, bool aggressive) const {
	if (!damage.runeSpellName.empty() && aggressive) {
		const auto &runesCritical = getRunesCritical();
		damage.criticalChance += runesCritical.chance * 10000;
		damage.criticalDamage += runesCritical.damage * 10000;
	}
}

void WeaponProficiency::applyElementCritical(CombatDamage &damage) const {
	if (damage.primary.type == COMBAT_NONE || damage.primary.type >= COMBAT_COUNT) {
		return;
	}

	const auto elementCritical = getElementCritical(damage.primary.type);
	if (elementCritical.chance > 0 || elementCritical.damage > 0) {
		damage.criticalChance += elementCritical.chance * 10000;
		damage.criticalDamage += elementCritical.damage * 10000;
	}
}

void WeaponProficiency::applyBestiaryDamage(CombatDamage &damage, const std::shared_ptr<Monster> &monster) const {
	if (!monster) {
		return;
	}
	const auto &monsterType = monster->getMonsterType();
	if (!monsterType) {
		return;
	}

	const auto race = magic_enum::enum_integer(monsterType->info.bestiaryRace);
	if (race > 0) {
		const auto bestiaryDamage = getBestiaryDamage(race);
		damage.primary.value *= 1 + bestiaryDamage;
		damage.secondary.value *= 1 + bestiaryDamage;
	}
}

void WeaponProficiency::applyPowerfulFoeDamage(CombatDamage &damage, const std::shared_ptr<Monster> &monster) const {
	using enum WeaponProficiencyBonus_t;
	if (!monster) {
		return;
	}

	const auto forgeStack = monster->getForgeStack();
	const auto mt = monster->getMonsterType();
	if (forgeStack > 0 || (mt && mt->isBoss())) {
		const auto bonusDamage = getPowerfulFoeDamage();
		damage.primary.value *= 1 + bonusDamage;
		damage.secondary.value *= 1 + bonusDamage;
	}
}

void WeaponProficiency::applySkillAutoAttackPercentage(CombatDamage &damage) const {
	using enum WeaponProficiencyBonus_t;

	if (damage.origin != ORIGIN_FIST && damage.origin != ORIGIN_MELEE && damage.origin != ORIGIN_RANGED) {
		return;
	}

	const auto &weapon = m_player.getWeapon(true);
	if (!weapon) {
		return;
	}

	for (const auto &[skill, skillPercentage] : m_skillPercentages) {
		if (skillPercentage.autoAttack <= 0) {
			continue;
		}

		const auto bonusDamage = m_player.getSkillLevel(skill) * skillPercentage.autoAttack;

		if (damage.primary.type != COMBAT_NONE) {
			damage.primary.value -= std::ceil(bonusDamage);
		}
		if (damage.secondary.type != COMBAT_NONE) {
			damage.secondary.value -= std::ceil(bonusDamage);
		}
	}
}

void WeaponProficiency::applySkillSpellPercentage(CombatDamage &damage, bool healing) const {
	using enum WeaponProficiencyBonus_t;

	if (damage.instantSpellName.empty()) {
		return;
	}

	if (healing && damage.primary.type != COMBAT_HEALING) {
		return;
	}

	const auto &weapon = m_player.getWeapon(true);
	if (!weapon) {
		return;
	}

	for (const auto &[skill, skillPercentage] : m_skillPercentages) {
		const auto skillPercentageValue = healing ? skillPercentage.spellHealing : skillPercentage.spellDamage;
		if (skillPercentageValue <= 0) {
			continue;
		}

		const auto bonusDamage = std::ceil(m_player.getSkillLevel(skill) * skillPercentageValue);

		if (damage.primary.type != COMBAT_NONE) {
			damage.primary.value += (damage.primary.value < 0 ? -bonusDamage : bonusDamage);
		}
		if (damage.secondary.type != COMBAT_NONE) {
			damage.secondary.value += (damage.secondary.value < 0 ? -bonusDamage : bonusDamage);
		}
	}
}

void WeaponProficiency::applyOn(WeaponProficiencyHealth_t healthType, WeaponProficiencyGain_t gainType) const {
	using enum WeaponProficiencyBonus_t;

	WeaponProficiencyBonus_t statsType;
	if (healthType == WeaponProficiencyHealth_t::LIFE) {
		statsType = gainType == WeaponProficiencyGain_t::KILL ? LIFE_GAIN_ON_KILL : LIFE_GAIN_ON_HIT;
	} else {
		statsType = gainType == WeaponProficiencyGain_t::KILL ? MANA_GAIN_ON_KILL : MANA_GAIN_ON_HIT;
	}

	CombatParams params;
	params.combatType = COMBAT_HEALING;
	params.soundImpactEffect = SoundEffect_t::SPELL_LIGHT_HEALING;

	CombatDamage damage;

	damage.origin = ORIGIN_WEAPON_PROFICIENCY;

	damage.primary.type = params.combatType;
	damage.primary.value = getStat(statsType);

	const auto &playerCreature = m_player.getCreature();
	if (healthType == WeaponProficiencyHealth_t::LIFE) {
		Combat::doCombatHealth(nullptr, playerCreature, damage, params);
	} else {
		Combat::doCombatMana(nullptr, playerCreature, damage, params);
	}
}

void WeaponProficiency::applySpellAugment(CombatDamage &damage, uint16_t spellId) const {
	if (auto it = m_spellsBonuses.find(spellId); it != m_spellsBonuses.end()) {
		damage.damageMultiplier += static_cast<int32_t>(std::lround(it->second.increase.damage * 100));
		damage.healingMultiplier += static_cast<int32_t>(std::lround(it->second.increase.heal * 100));
		damage.criticalChance += it->second.increase.criticalChance * 10000;
		damage.criticalDamage += it->second.increase.criticalDamage * 10000;
		damage.lifeLeech += it->second.leech.life * 10000;
		damage.manaLeech += it->second.leech.mana * 10000;
	}
}

std::vector<std::pair<std::string, double>> WeaponProficiency::getActiveBestiariesDamage() const {
	using enum WeaponProficiencyBonus_t;
	std::unordered_map<std::string, double, TransparentStringHasher, std::equal_to<>> aggregatedBestiaries;

	const auto weaponId = m_player.getWeaponId(true);

	const auto &perks = getSelectedPerks(weaponId);
	for (const auto &perk : perks) {
		if (perk.type == WEAPON_PROFICIENCY_BESTIARY && !perk.bestiaryName.empty()) {
			aggregatedBestiaries[perk.bestiaryName] += perk.value;
		}
	}

	std::vector<std::pair<std::string, double>> bestiariesDamage;
	bestiariesDamage.reserve(aggregatedBestiaries.size());
	for (const auto &[name, value] : aggregatedBestiaries) {
		(void)bestiariesDamage.emplace_back(name, value);
	}

	(void)std::ranges::sort(bestiariesDamage, [](const auto &lhs, const auto &rhs) {
		return lhs.first < rhs.first;
	});

	return bestiariesDamage;
}

std::optional<std::pair<uint8_t, double>> WeaponProficiency::getActiveElementalCriticalType(WeaponProficiencyBonus_t criticalType) const {
	using enum WeaponProficiencyBonus_t;

	if (criticalType != ELEMENTAL_HIT_CHANCE && criticalType != ELEMENTAL_CRITICAL_EXTRA_DAMAGE) {
		return std::nullopt;
	}

	const auto weaponId = m_player.getWeaponId(true);

	const auto &perks = getSelectedPerks(weaponId);
	std::unordered_map<uint8_t, double> aggregatedByElement;
	std::vector<uint8_t> displayOrder;
	for (const auto &perk : perks) {
		if (perk.type != criticalType || perk.element == COMBAT_NONE) {
			continue;
		}

		const auto elementId = getCipbiaElement(perk.element);
		if (!aggregatedByElement.contains(elementId)) {
			displayOrder.push_back(elementId);
		}
		aggregatedByElement[elementId] += perk.value;
	}

	if (!displayOrder.empty()) {
		auto bestElementId = displayOrder.front();
		auto bestValue = aggregatedByElement[bestElementId];
		for (const auto elementId : displayOrder) {
			const auto value = aggregatedByElement[elementId];
			if (value > bestValue) {
				bestElementId = elementId;
				bestValue = value;
			}
		}
		return std::make_pair(bestElementId, bestValue);
	}

	return std::nullopt;
}

void WeaponProficiency::clearAllStats() {
	resetStats();
	resetSpecializedMagic();
	resetSkillBonuses();
	resetPowerfulFoeDamage();
	resetBestiaryDamage();

	m_skillPercentages.clear();
	m_autoAttackCritical.clear();
	m_runesCritical.clear();
	m_generalCritical.clear();
	m_elementCritical.fill({});
	m_spellsBonuses.clear();
	resetPerfectShotBonus();
}
