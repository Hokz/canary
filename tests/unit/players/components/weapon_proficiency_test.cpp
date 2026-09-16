/**
 * Canary - A free and open-source MMORPG server emulator
 * Copyright (©) 2019–present OpenTibiaBR <opentibiabr@outlook.com>
 * Repository: https://github.com/opentibiabr/canary
 * License: https://github.com/opentibiabr/canary/blob/main/LICENSE
 * Contributors: https://github.com/opentibiabr/canary/graphs/contributors
 * Website: https://docs.opentibiabr.com/
 */

#include "pch.hpp"

#include <algorithm>
#include <filesystem>
#include <fstream>

#include <gtest/gtest.h>

#include "canary_server.hpp"
#include "config/configmanager.hpp"
#include "creatures/players/components/weapon_proficiency.hpp"
#include "creatures/players/player.hpp"
#include "enums/weapon_proficiency.hpp"
#include "lib/di/container.hpp"
#include "lib/logging/in_memory_logger.hpp"

namespace {

	// The proficiency data lives in one file per weapon category, hand-edited for
	// balancing. These tests build a throwaway core directory per test so the loader
	// can be pointed at files that are deliberately fine, deliberately broken, or
	// deliberately contradictory, without touching the shipped data.
	class WeaponProficiencyLoaderTest : public ::testing::Test {
	protected:
		static void SetUpTestSuite() {
			if (DI::getTestContainer() == nullptr) {
				InMemoryLogger::install(injector_);
				DI::setTestContainer(&injector_);
				ownsContainer_ = true;
			}
		}

		static void TearDownTestSuite() {
			if (ownsContainer_ && DI::getTestContainer() == &injector_) {
				DI::setTestContainer(nullptr);
			}
		}

		void SetUp() override {
			std::error_code ec;
			const auto* testName = ::testing::UnitTest::GetInstance()->current_test_info()->name();
			root_ = std::filesystem::temp_directory_path(ec) / ("canary-proficiency-" + std::string(testName));
			ASSERT_FALSE(ec) << "Could not resolve a temporary directory";

			std::filesystem::remove_all(root_, ec);
			ASSERT_TRUE(std::filesystem::create_directories(proficiencyFolder(), ec)) << ec.message();

			// generic_string keeps forward slashes, which Lua accepts on every platform;
			// a native Windows path would put backslashes inside the quoted string.
			const auto configPath = root_ / "config.lua";
			std::ofstream config(configPath);
			ASSERT_TRUE(config.is_open());
			config << "coreDirectory = \"" << (root_ / "core").generic_string() << "\"\n";
			config.close();

			previousConfigFile_ = g_configManager().getConfigFileLua();
			(void)g_configManager().setConfigFileLua(configPath.generic_string());
			ASSERT_TRUE(g_configManager().reload());
		}

		void TearDown() override {
			(void)g_configManager().setConfigFileLua(previousConfigFile_);
			(void)g_configManager().reload();

			std::error_code ec;
			std::filesystem::remove_all(root_, ec);
		}

		[[nodiscard]] std::filesystem::path proficiencyFolder() const {
			return root_ / "core" / "items" / "proficiencies";
		}

		[[nodiscard]] std::filesystem::path shapingFolder() const {
			return proficiencyFolder() / "shaping";
		}

		void writeShaping(const std::string &contents) const {
			std::error_code ec;
			std::filesystem::create_directories(shapingFolder(), ec);
			std::ofstream file(shapingFolder() / "shaping.json");
			ASSERT_TRUE(file.is_open()) << "Could not write shaping.json";
			file << contents;
		}

		// A complete, minimal set of shaping rules: one slot, one rollable option.
		[[nodiscard]] static std::string minimalShaping(double rank0Value = 0.01) {
			return R"({"RequiresProtectionZone":true,)"
				   R"("Slots":[{"Slot":0,"UnlockDustCost":250,"RequiredProficiencyLevel":3}],)"
				   R"("Refine":{"DustCostPerRank":[0,60]},)"
				   R"("Reshape":{"DustCost":150,"OptionCount":3},)"
				   R"("Clear":{"DustCost":0},)"
				   R"("Options":[{"Id":1,"Type":8,"Weight":100,"ValuePerRank":[)"
				+ std::to_string(rank0Value) + R"(,0.02]}]})";
		}

		void writeFile(const std::string &name, const std::string &contents) const {
			std::ofstream file(proficiencyFolder() / name);
			ASSERT_TRUE(file.is_open()) << "Could not write " << name;
			file << contents;
		}

		// One proficiency, one level, one perk, with a value the test can assert on.
		[[nodiscard]] static std::string singleProficiency(uint16_t id, double value, const std::string &category = "Sword") {
			return R"({"Category":")" + category + R"(","Proficiencies":[{"ProficiencyId":)" + std::to_string(id) + R"(,"Levels":[{"Perks":[{"Type":0,"Value":)" + std::to_string(value) + R"(}]}]}]})";
		}

		[[nodiscard]] static double firstPerkValue(uint16_t id) {
			const auto &proficiencies = WeaponProficiency::getProficiencies();
			const auto it = proficiencies.find(id);
			EXPECT_NE(proficiencies.end(), it) << "Proficiency " << id << " was not loaded";
			if (it == proficiencies.end() || it->second.level.empty() || it->second.level.front().perks.empty()) {
				return -1.0;
			}

			return it->second.level.front().perks.front().value;
		}

	private:
		std::filesystem::path root_ {};
		std::string previousConfigFile_ {};

		inline static di::extension::injector<> injector_ {};
		inline static bool ownsContainer_ = false;
	};

	TEST_F(WeaponProficiencyLoaderTest, LoadsEveryCategoryFileInTheFolder) {
		writeFile("sword.json", singleProficiency(1, 5, "Sword"));
		writeFile("axe.json", singleProficiency(2, 7, "Axe"));
		writeFile("_orphaned.json", singleProficiency(3, 9, "Orphaned"));

		ASSERT_TRUE(WeaponProficiency::loadFromJson());

		const auto &proficiencies = WeaponProficiency::getProficiencies();
		EXPECT_EQ(3U, proficiencies.size());
		EXPECT_DOUBLE_EQ(5.0, firstPerkValue(1));
		EXPECT_DOUBLE_EQ(7.0, firstPerkValue(2));
		// _orphaned.json is loaded like any other file: no item references those ids,
		// but an items.xml override can still name one.
		EXPECT_DOUBLE_EQ(9.0, firstPerkValue(3));
	}

	TEST_F(WeaponProficiencyLoaderTest, DerivesLevelFromArrayPositionNotFromTheLevelField) {
		// The "Level" key is documentation only; registerLevels counts array positions.
		// A file that numbers its levels wrongly must still load them in order.
		writeFile(
			"sword.json",
			R"({"Category":"Sword","Proficiencies":[{"ProficiencyId":1,"Levels":[)"
			R"({"Level":99,"Perks":[{"Type":0,"Value":1}]},)"
			R"({"Level":1,"Perks":[{"Type":0,"Value":2}]}]}]})"
		);

		ASSERT_TRUE(WeaponProficiency::loadFromJson());

		const auto &proficiency = WeaponProficiency::getProficiencies().at(1);
		ASSERT_EQ(2U, proficiency.level.size());
		EXPECT_EQ(2, proficiency.maxLevel);
		EXPECT_EQ(0, proficiency.level[0].perks.front().level);
		EXPECT_EQ(1, proficiency.level[1].perks.front().level);
	}

	TEST_F(WeaponProficiencyLoaderTest, SharedIdKeepsTheCopyFromTheFirstFileInSortedOrder) {
		// Ten real ids belong to weapons of two categories and are written in full into
		// both files. Files are read in sorted order, so "axe" wins over "sword".
		writeFile("axe.json", singleProficiency(54, 11, "Axe"));
		writeFile("sword.json", singleProficiency(54, 22, "Sword"));

		ASSERT_TRUE(WeaponProficiency::loadFromJson());

		EXPECT_EQ(1U, WeaponProficiency::getProficiencies().size());
		EXPECT_DOUBLE_EQ(11.0, firstPerkValue(54));
	}

	TEST_F(WeaponProficiencyLoaderTest, SkipsTheSchemaFile) {
		writeFile("sword.json", singleProficiency(1, 5));
		// The schema sits in the same folder and is not a proficiency file. Parsing it
		// as one would throw, so a passing load proves it is skipped by name.
		writeFile("proficiencies.schema.json", R"({"$schema":"http://json-schema.org/draft-07/schema#","type":"object"})");

		ASSERT_TRUE(WeaponProficiency::loadFromJson());
		EXPECT_EQ(1U, WeaponProficiency::getProficiencies().size());
	}

	TEST_F(WeaponProficiencyLoaderTest, ThrowsWhenTheFolderHasNoProficiencyFiles) {
		EXPECT_THROW((void)WeaponProficiency::loadFromJson(), FailedToInitializeCanary);
	}

	TEST_F(WeaponProficiencyLoaderTest, ThrowsWhenTheFolderIsMissing) {
		std::error_code ec;
		std::filesystem::remove_all(proficiencyFolder(), ec);

		EXPECT_THROW((void)WeaponProficiency::loadFromJson(), FailedToInitializeCanary);
	}

	TEST_F(WeaponProficiencyLoaderTest, ReloadPicksUpAnEditedValue) {
		writeFile("sword.json", singleProficiency(1, 5));
		ASSERT_TRUE(WeaponProficiency::loadFromJson());
		ASSERT_DOUBLE_EQ(5.0, firstPerkValue(1));

		// This is the whole point of splitting the data by category: edit one file,
		// reload, no restart.
		writeFile("sword.json", singleProficiency(1, 42));
		ASSERT_TRUE(WeaponProficiency::loadFromJson(true));

		EXPECT_DOUBLE_EQ(42.0, firstPerkValue(1));
	}

	TEST_F(WeaponProficiencyLoaderTest, ReloadDropsProficienciesRemovedFromTheFiles) {
		writeFile("sword.json", singleProficiency(1, 5));
		writeFile("axe.json", singleProficiency(2, 7, "Axe"));
		ASSERT_TRUE(WeaponProficiency::loadFromJson());
		ASSERT_EQ(2U, WeaponProficiency::getProficiencies().size());

		std::error_code ec;
		std::filesystem::remove(proficiencyFolder() / "axe.json", ec);
		ASSERT_TRUE(WeaponProficiency::loadFromJson(true));

		// A reload must not leave behind entries the files no longer define, or a
		// deleted proficiency would keep working until the next restart.
		EXPECT_EQ(1U, WeaponProficiency::getProficiencies().size());
		EXPECT_FALSE(WeaponProficiency::getProficiencies().contains(2));
	}

	TEST_F(WeaponProficiencyLoaderTest, FailedReloadKeepsThePreviouslyLoadedData) {
		writeFile("sword.json", singleProficiency(1, 5));
		writeFile("axe.json", singleProficiency(2, 7, "Axe"));
		ASSERT_TRUE(WeaponProficiency::loadFromJson());
		ASSERT_EQ(2U, WeaponProficiency::getProficiencies().size());

		// These files are edited by hand for balancing, so a typo is an expected
		// outcome of a reload. The new data is published only once every file has
		// parsed, so a failure must leave the running server on the data it had.
		writeFile("sword.json", R"({"Category":"Sword","Proficiencies":[{"ProficiencyId":1,)");
		EXPECT_THROW((void)WeaponProficiency::loadFromJson(true), FailedToInitializeCanary);

		EXPECT_EQ(2U, WeaponProficiency::getProficiencies().size());
		EXPECT_DOUBLE_EQ(5.0, firstPerkValue(1));
		EXPECT_DOUBLE_EQ(7.0, firstPerkValue(2));
	}

	TEST_F(WeaponProficiencyLoaderTest, FailedReloadOnAMissingKeyAlsoKeepsThePreviousData) {
		writeFile("sword.json", singleProficiency(1, 5));
		ASSERT_TRUE(WeaponProficiency::loadFromJson());

		// Valid JSON, wrong shape: the loader must fail on the missing "Proficiencies"
		// key rather than silently loading nothing.
		writeFile("sword.json", R"({"Category":"Sword"})");
		EXPECT_THROW((void)WeaponProficiency::loadFromJson(true), FailedToInitializeCanary);

		EXPECT_EQ(1U, WeaponProficiency::getProficiencies().size());
		EXPECT_DOUBLE_EQ(5.0, firstPerkValue(1));
	}

	TEST_F(WeaponProficiencyLoaderTest, StopsAtTheConfiguredMaximumNumberOfLevels) {
		const auto maxLevels = static_cast<size_t>(g_configManager().getNumber(WEAPON_PROFICIENCY_MAX_LEVELS));
		ASSERT_GT(maxLevels, 0U);

		std::string levels;
		for (size_t i = 0; i < maxLevels + 3; ++i) {
			levels += (i == 0 ? "" : ",");
			levels += R"({"Perks":[{"Type":0,"Value":1}]})";
		}
		writeFile("sword.json", R"({"Category":"Sword","Proficiencies":[{"ProficiencyId":1,"Levels":[)" + levels + R"(]}]})");

		ASSERT_TRUE(WeaponProficiency::loadFromJson());

		const auto &proficiency = WeaponProficiency::getProficiencies().at(1);
		EXPECT_EQ(maxLevels, proficiency.level.size());
		EXPECT_EQ(static_cast<uint8_t>(maxLevels), proficiency.maxLevel);
	}

	TEST_F(WeaponProficiencyLoaderTest, StopsAtTheConfiguredMaximumNumberOfPerksPerLevel) {
		const auto maxPerks = static_cast<size_t>(g_configManager().getNumber(WEAPON_PROFICIENCY_MAX_PERKS_PER_LEVEL));
		ASSERT_GT(maxPerks, 0U);

		std::string perks;
		for (size_t i = 0; i < maxPerks + 2; ++i) {
			perks += (i == 0 ? "" : ",");
			perks += R"({"Type":0,"Value":1})";
		}
		writeFile("sword.json", R"({"Category":"Sword","Proficiencies":[{"ProficiencyId":1,"Levels":[{"Perks":[)" + perks + R"(]}]}]})");

		ASSERT_TRUE(WeaponProficiency::loadFromJson());

		const auto &proficiency = WeaponProficiency::getProficiencies().at(1);
		ASSERT_EQ(1U, proficiency.level.size());
		EXPECT_EQ(maxPerks, proficiency.level.front().perks.size());
	}

	TEST_F(WeaponProficiencyLoaderTest, ShapingIsOptionalAndOffWhenTheFileIsAbsent) {
		writeFile("sword.json", singleProficiency(1, 5));

		ASSERT_TRUE(WeaponProficiency::loadFromJson());

		// A server that does not run perk shaping just has no file. It must still boot.
		EXPECT_TRUE(WeaponProficiency::getShapingRules().empty());
		EXPECT_EQ(1U, WeaponProficiency::getProficiencies().size());
	}

	TEST_F(WeaponProficiencyLoaderTest, LoadsShapingRules) {
		writeFile("sword.json", singleProficiency(1, 5));
		writeShaping(minimalShaping());

		ASSERT_TRUE(WeaponProficiency::loadFromJson());

		const auto &rules = WeaponProficiency::getShapingRules();
		ASSERT_FALSE(rules.empty());
		EXPECT_TRUE(rules.requiresProtectionZone);

		ASSERT_EQ(1U, rules.slots.size());
		EXPECT_EQ(250U, rules.slots.front().unlockDustCost);
		EXPECT_EQ(3, rules.slots.front().requiredProficiencyLevel);
		EXPECT_FALSE(rules.slots.front().requiresMastery);

		EXPECT_EQ(150U, rules.reshapeDustCost);
		EXPECT_EQ(3, rules.reshapeOptionCount);
		ASSERT_EQ(2U, rules.refineDustCostPerRank.size());
		EXPECT_EQ(60U, rules.refineDustCostPerRank[1]);

		ASSERT_EQ(1U, rules.options.size());
		const auto &option = rules.options.front();
		EXPECT_EQ(WeaponProficiencyBonus_t::CRITICAL_HIT_CHANCE, option.type);
		EXPECT_EQ(100U, option.weight);
		// maxRank is the last index, not the count: two values means ranks 0 and 1.
		EXPECT_EQ(1, option.maxRank());
	}

	TEST_F(WeaponProficiencyLoaderTest, ShapingRejectsAnUnknownPerkType) {
		writeFile("sword.json", singleProficiency(1, 5));
		writeShaping(R"({"Slots":[{"Slot":0}],"Options":[{"Id":1,"Type":250,"ValuePerRank":[1]}]})");

		EXPECT_THROW((void)WeaponProficiency::loadFromJson(), FailedToInitializeCanary);
	}

	TEST_F(WeaponProficiencyLoaderTest, ShapingRejectsAnOptionThatCouldNeverBeRolled) {
		writeFile("sword.json", singleProficiency(1, 5));
		writeShaping(R"({"Slots":[{"Slot":0}],"Options":[{"Id":1,"Type":8,"Weight":0,"ValuePerRank":[0.01]}]})");

		EXPECT_THROW((void)WeaponProficiency::loadFromJson(), FailedToInitializeCanary);
	}

	TEST_F(WeaponProficiencyLoaderTest, ShapingRejectsASkillAddressedTypeWithNoSkillId) {
		writeFile("sword.json", singleProficiency(1, 5));
		// Type 25 is SKILL_PERCENTAGE_AUTO_ATTACK. Its effect is filed under a skill,
		// so without a SkillId it lands on SKILL_NONE and the protocol never reads it:
		// the player rolls the option, pays for it, and receives nothing. Shipped that
		// way once already, which is why the loader now refuses it.
		writeShaping(R"({"Slots":[{"Slot":0}],"Options":[{"Id":1,"Type":25,"ValuePerRank":[0.01]}]})");

		EXPECT_THROW((void)WeaponProficiency::loadFromJson(), FailedToInitializeCanary);
	}

	TEST_F(WeaponProficiencyLoaderTest, ShapingAcceptsASkillAddressedTypeThatNamesItsSkill) {
		writeFile("sword.json", singleProficiency(1, 5));
		writeShaping(R"({"Slots":[{"Slot":0}],"Options":[{"Id":1,"Type":25,"SkillId":8,"ValuePerRank":[0.01]}]})");

		ASSERT_TRUE(WeaponProficiency::loadFromJson());
		ASSERT_NE(nullptr, WeaponProficiency::getShapingRules().findOption(1));
	}

	TEST_F(WeaponProficiencyLoaderTest, ShapingRejectsARankTableLongerThanRankCanCount) {
		writeFile("sword.json", singleProficiency(1, 5));
		// rank is a uint8_t and maxRank() is size - 1 cast down to it. Past 256 entries
		// that cast truncates, so the option would report a maximum far below its own
		// table and strand every rank above it.
		std::string values = "0.001";
		for (int i = 1; i < 300; ++i) {
			values += ",0.001";
		}
		writeShaping(R"({"Slots":[{"Slot":0}],"Options":[{"Id":1,"Type":8,"ValuePerRank":[)" + values + R"(]}]})");

		EXPECT_THROW((void)WeaponProficiency::loadFromJson(), FailedToInitializeCanary);
	}

	TEST_F(WeaponProficiencyLoaderTest, AReshapeOffersTheSameThreeOptionsEveryTimeItIsAsked) {
		writeFile("sword.json", singleProficiency(1, 5));
		writeShaping(
			R"({"Slots":[{"Slot":0}],"Reshape":{"DustCost":150,"OptionCount":3},"Options":[)"
			R"({"Id":10,"Type":8,"Weight":100,"ValuePerRank":[0.01]},)"
			R"({"Id":20,"Type":12,"Weight":100,"ValuePerRank":[0.02]},)"
			R"({"Id":30,"Type":16,"Weight":100,"ValuePerRank":[0.03]},)"
			R"({"Id":40,"Type":17,"Weight":100,"ValuePerRank":[0.04]},)"
			R"({"Id":50,"Type":30,"Weight":100,"ValuePerRank":[0.05]}]})"
		);
		ASSERT_TRUE(WeaponProficiency::loadFromJson());

		const auto &rules = WeaponProficiency::getShapingRules();
		const auto* option = rules.findOption(10);
		ASSERT_NE(nullptr, option);

		auto perk = WeaponProficiency::buildShapedPerk(*option, 0, 0, 0);
		perk.reshapeSeed = 123456;

		// Derived from the stored seed, not drawn fresh. Without this the three options
		// could not be enforced when the player answers: the server would have no way
		// to tell one it offered from one the client invented.
		const auto first = WeaponProficiency::reshapeOptionsFor(rules, perk);
		const auto second = WeaponProficiency::reshapeOptionsFor(rules, perk);
		EXPECT_EQ(first, second);
		EXPECT_EQ(3U, first.size());

		// Never the perk the player already has, and never the same one twice.
		EXPECT_EQ(first.end(), std::ranges::find(first, perk.shapingOptionId));
		auto sorted = first;
		std::ranges::sort(sorted);
		EXPECT_EQ(sorted.end(), std::ranges::unique(sorted).begin());
	}

	TEST_F(WeaponProficiencyLoaderTest, ADifferentSeedOffersADifferentReshape) {
		writeFile("sword.json", singleProficiency(1, 5));
		writeShaping(
			R"({"Slots":[{"Slot":0}],"Reshape":{"DustCost":150,"OptionCount":2},"Options":[)"
			R"({"Id":10,"Type":8,"Weight":100,"ValuePerRank":[0.01]},)"
			R"({"Id":20,"Type":12,"Weight":100,"ValuePerRank":[0.02]},)"
			R"({"Id":30,"Type":16,"Weight":100,"ValuePerRank":[0.03]},)"
			R"({"Id":40,"Type":17,"Weight":100,"ValuePerRank":[0.04]},)"
			R"({"Id":50,"Type":30,"Weight":100,"ValuePerRank":[0.05]}]})"
		);
		ASSERT_TRUE(WeaponProficiency::loadFromJson());

		const auto &rules = WeaponProficiency::getShapingRules();
		const auto* option = rules.findOption(10);
		ASSERT_NE(nullptr, option);

		// A reshape re-seeds the perk, so the next offer must not be the same three.
		// Scanning seeds proves the seed reaches the draw at all; a single pair could
		// collide by chance even with a working derivation.
		auto perk = WeaponProficiency::buildShapedPerk(*option, 0, 0, 0);
		perk.reshapeSeed = 1;
		const auto baseline = WeaponProficiency::reshapeOptionsFor(rules, perk);
		ASSERT_EQ(2U, baseline.size());

		bool sawADifferentOffer = false;
		for (uint32_t seed = 2; seed < 40 && !sawADifferentOffer; ++seed) {
			perk.reshapeSeed = seed;
			sawADifferentOffer = WeaponProficiency::reshapeOptionsFor(rules, perk) != baseline;
		}

		EXPECT_TRUE(sawADifferentOffer);
	}

	TEST_F(WeaponProficiencyLoaderTest, ShapingRejectsAnOptionWithNoValues) {
		writeFile("sword.json", singleProficiency(1, 5));
		writeShaping(R"({"Slots":[{"Slot":0}],"Options":[{"Id":1,"Type":8,"ValuePerRank":[]}]})");

		EXPECT_THROW((void)WeaponProficiency::loadFromJson(), FailedToInitializeCanary);
	}

	TEST_F(WeaponProficiencyLoaderTest, ShapingRejectsSlotsListedOutOfOrder) {
		writeFile("sword.json", singleProficiency(1, 5));
		// Slots are addressed by position, so a file numbering them 1,0 would price the
		// wrong slot rather than fail.
		writeShaping(R"({"Slots":[{"Slot":1},{"Slot":0}],"Options":[{"Id":1,"Type":8,"ValuePerRank":[0.01]}]})");

		EXPECT_THROW((void)WeaponProficiency::loadFromJson(), FailedToInitializeCanary);
	}

	TEST_F(WeaponProficiencyLoaderTest, FailedShapingReloadKeepsBothTheTreeAndTheRules) {
		writeFile("sword.json", singleProficiency(1, 5));
		writeShaping(minimalShaping(0.01));
		ASSERT_TRUE(WeaponProficiency::loadFromJson());
		ASSERT_EQ(1U, WeaponProficiency::getShapingRules().options.size());
		ASSERT_DOUBLE_EQ(0.01, WeaponProficiency::getShapingRules().options.front().valuePerRank.front());

		// The proficiency files are fine; only the shaping file is broken. Both must
		// survive, because both are published in the same step.
		writeShaping(R"({"Slots":[{"Slot":0}],"Options":[{"Id":1,"Type":250,"ValuePerRank":[1]}]})");
		EXPECT_THROW((void)WeaponProficiency::loadFromJson(true), FailedToInitializeCanary);

		EXPECT_EQ(1U, WeaponProficiency::getProficiencies().size());
		EXPECT_DOUBLE_EQ(5.0, firstPerkValue(1));
		ASSERT_EQ(1U, WeaponProficiency::getShapingRules().options.size());
		EXPECT_DOUBLE_EQ(0.01, WeaponProficiency::getShapingRules().options.front().valuePerRank.front());
	}

	TEST_F(WeaponProficiencyLoaderTest, ReloadPicksUpEditedShapingRules) {
		writeFile("sword.json", singleProficiency(1, 5));
		writeShaping(minimalShaping(0.01));
		ASSERT_TRUE(WeaponProficiency::loadFromJson());

		writeShaping(minimalShaping(0.03));
		ASSERT_TRUE(WeaponProficiency::loadFromJson(true));

		ASSERT_EQ(1U, WeaponProficiency::getShapingRules().options.size());
		EXPECT_DOUBLE_EQ(0.03, WeaponProficiency::getShapingRules().options.front().valuePerRank.front());
	}

	// ---------------------------------------------------------------------------
	// Reconciling a shaped perk against the rules as loaded right now.
	//
	// A shaped perk stores only its identity: which option was rolled, at what rank.
	// What it does is rebuilt through buildShapedPerk on every read, so an edit to
	// shaping.json reaches perks players already own. These pin that contract.
	// ---------------------------------------------------------------------------

	TEST_F(WeaponProficiencyLoaderTest, ShapingRejectsADuplicateOptionId) {
		writeFile("sword.json", singleProficiency(1, 5));
		// Two options sharing an Id would make a stored perk ambiguous.
		writeShaping(
			R"({"Slots":[{"Slot":0}],"Options":[)"
			R"({"Id":7,"Type":8,"ValuePerRank":[0.01]},)"
			R"({"Id":7,"Type":12,"ValuePerRank":[0.02]}]})"
		);

		EXPECT_THROW((void)WeaponProficiency::loadFromJson(), FailedToInitializeCanary);
	}

	TEST_F(WeaponProficiencyLoaderTest, ShapingRejectsOptionIdZero) {
		writeFile("sword.json", singleProficiency(1, 5));
		// 0 is how a perk says "not shaped", so no option may claim it.
		writeShaping(R"({"Slots":[{"Slot":0}],"Options":[{"Id":0,"Type":8,"ValuePerRank":[0.01]}]})");

		EXPECT_THROW((void)WeaponProficiency::loadFromJson(), FailedToInitializeCanary);
	}

	TEST_F(WeaponProficiencyLoaderTest, OptionsAreFoundByIdRegardlessOfFileOrder) {
		writeFile("sword.json", singleProficiency(1, 5));
		writeShaping(
			R"({"Slots":[{"Slot":0}],"Options":[)"
			R"({"Id":10,"Type":8,"ValuePerRank":[0.01]},)"
			R"({"Id":20,"Type":12,"ValuePerRank":[0.02]}]})"
		);
		ASSERT_TRUE(WeaponProficiency::loadFromJson());

		const auto* before = WeaponProficiency::getShapingRules().findOption(20);
		ASSERT_NE(nullptr, before);
		EXPECT_EQ(WeaponProficiencyBonus_t::CRITICAL_EXTRA_DAMAGE, before->type);

		// Same options, swapped in the file. Identity follows the Id, not the position,
		// or reordering the file would silently repoint players' perks.
		writeShaping(
			R"({"Slots":[{"Slot":0}],"Options":[)"
			R"({"Id":20,"Type":12,"ValuePerRank":[0.02]},)"
			R"({"Id":10,"Type":8,"ValuePerRank":[0.01]}]})"
		);
		ASSERT_TRUE(WeaponProficiency::loadFromJson(true));

		const auto* after = WeaponProficiency::getShapingRules().findOption(20);
		ASSERT_NE(nullptr, after);
		EXPECT_EQ(WeaponProficiencyBonus_t::CRITICAL_EXTRA_DAMAGE, after->type);
	}

	TEST_F(WeaponProficiencyLoaderTest, ARemovedOptionIsReportedMissingRatherThanGuessedAt) {
		writeFile("sword.json", singleProficiency(1, 5));
		writeShaping(
			R"({"Slots":[{"Slot":0}],"Options":[)"
			R"({"Id":10,"Type":8,"ValuePerRank":[0.01]},)"
			R"({"Id":20,"Type":12,"ValuePerRank":[0.02]}]})"
		);
		ASSERT_TRUE(WeaponProficiency::loadFromJson());
		ASSERT_NE(nullptr, WeaponProficiency::getShapingRules().findOption(20));

		writeShaping(R"({"Slots":[{"Slot":0}],"Options":[{"Id":10,"Type":8,"ValuePerRank":[0.01]}]})");
		ASSERT_TRUE(WeaponProficiency::loadFromJson(true));

		// The lookup fails cleanly, which is what makes a perk holding this id fall
		// back to the perk its proficiency file defines - the Clear outcome.
		EXPECT_EQ(nullptr, WeaponProficiency::getShapingRules().findOption(20));
		EXPECT_NE(nullptr, WeaponProficiency::getShapingRules().findOption(10));
		EXPECT_EQ(nullptr, WeaponProficiency::getShapingRules().findOption(0));
	}

	TEST_F(WeaponProficiencyLoaderTest, ShapedPerkTakesItsValueFromTheCurrentRules) {
		writeFile("sword.json", singleProficiency(1, 5));
		writeShaping(R"({"Slots":[{"Slot":0}],"Options":[{"Id":10,"Type":8,"ValuePerRank":[0.01,0.02,0.05]}]})");
		ASSERT_TRUE(WeaponProficiency::loadFromJson());

		const auto* option = WeaponProficiency::getShapingRules().findOption(10);
		ASSERT_NE(nullptr, option);

		const auto perk = WeaponProficiency::buildShapedPerk(*option, 2, 3, 1);
		EXPECT_TRUE(perk.shaped);
		EXPECT_EQ(10, perk.shapingOptionId);
		EXPECT_EQ(2, perk.rank);
		EXPECT_EQ(3, perk.level);
		EXPECT_EQ(1, perk.index);
		EXPECT_EQ(WeaponProficiencyBonus_t::CRITICAL_HIT_CHANCE, perk.type);
		EXPECT_DOUBLE_EQ(0.05, perk.value);
	}

	TEST_F(WeaponProficiencyLoaderTest, EditingValuePerRankReachesAPerkAlreadyOwned) {
		writeFile("sword.json", singleProficiency(1, 5));
		writeShaping(R"({"Slots":[{"Slot":0}],"Options":[{"Id":10,"Type":8,"ValuePerRank":[0.01,0.05]}]})");
		ASSERT_TRUE(WeaponProficiency::loadFromJson());

		const auto* before = WeaponProficiency::getShapingRules().findOption(10);
		ASSERT_NE(nullptr, before);
		ASSERT_DOUBLE_EQ(0.05, WeaponProficiency::buildShapedPerk(*before, 1, 0, 0).value);

		// Rank 1 was worth 0.05 and is nerfed to 0.04. A player sitting on rank 1 gets
		// 0.04 on the next read instead of keeping the old number.
		writeShaping(R"({"Slots":[{"Slot":0}],"Options":[{"Id":10,"Type":8,"ValuePerRank":[0.01,0.04]}]})");
		ASSERT_TRUE(WeaponProficiency::loadFromJson(true));

		const auto* after = WeaponProficiency::getShapingRules().findOption(10);
		ASSERT_NE(nullptr, after);
		EXPECT_DOUBLE_EQ(0.04, WeaponProficiency::buildShapedPerk(*after, 1, 0, 0).value);
	}

	TEST_F(WeaponProficiencyLoaderTest, ARankAboveTheNewMaximumIsClampedNotHonoured) {
		writeFile("sword.json", singleProficiency(1, 5));
		// Five ranks become two. A player at rank 4 must not keep a value the option no
		// longer offers.
		writeShaping(R"({"Slots":[{"Slot":0}],"Options":[{"Id":10,"Type":8,"ValuePerRank":[0.01,0.02]}]})");
		ASSERT_TRUE(WeaponProficiency::loadFromJson());

		const auto* option = WeaponProficiency::getShapingRules().findOption(10);
		ASSERT_NE(nullptr, option);
		ASSERT_EQ(1, option->maxRank());

		const auto perk = WeaponProficiency::buildShapedPerk(*option, 4, 0, 0);
		EXPECT_EQ(1, perk.rank);
		EXPECT_DOUBLE_EQ(0.02, perk.value);
	}

	TEST_F(WeaponProficiencyLoaderTest, ShapedPerkCarriesTheOptionSecondaryFields) {
		writeFile("sword.json", singleProficiency(1, 5));
		// Changing SkillId, SpellId, Range or AugmentType must reach owners too, so they
		// are rebuilt from the option like the value is. SkillId 8 is Cipbia "Sword";
		// the loader converts it to the server's skills_t.
		writeShaping(
			R"({"Slots":[{"Slot":0}],"Options":[{"Id":10,"Type":3,)"
			R"("SkillId":8,"SpellId":42,"Range":5,"AugmentType":6,"BestiaryName":"rat",)"
			R"("ValuePerRank":[1,2]}]})"
		);
		ASSERT_TRUE(WeaponProficiency::loadFromJson());

		const auto* option = WeaponProficiency::getShapingRules().findOption(10);
		ASSERT_NE(nullptr, option);

		const auto perk = WeaponProficiency::buildShapedPerk(*option, 1, 0, 0);
		EXPECT_EQ(option->skillId, perk.skillId);
		EXPECT_NE(SKILL_NONE, perk.skillId);
		EXPECT_EQ(42, perk.spellId);
		EXPECT_EQ(5, perk.range);
		EXPECT_EQ(6, perk.augmentType);
		EXPECT_EQ("rat", perk.bestiaryName);
		EXPECT_DOUBLE_EQ(2.0, perk.value);
	}

	TEST_F(WeaponProficiencyLoaderTest, ShapingRejectsAnInvalidSkillId) {
		writeFile("sword.json", singleProficiency(1, 5));
		// Caught at load, so a bad combination never reaches a player's perk.
		writeShaping(R"({"Slots":[{"Slot":0}],"Options":[{"Id":10,"Type":3,"SkillId":250,"ValuePerRank":[1]}]})");

		EXPECT_THROW((void)WeaponProficiency::loadFromJson(), FailedToInitializeCanary);
	}

	// ---------------------------------------------------------------------------
	// The shaping operations' guard ladder.
	//
	// These reach as far as a unit test can: a default-constructed Player has no
	// tile and Item::items is empty, so every path that needs a real weapon stops at
	// InvalidWeapon. What is proved here is that the guards short-circuit in the
	// right order and that an empty player never faults. Charging dust, slot costs
	// and rank progression need items loaded, which is integration territory.
	// ---------------------------------------------------------------------------

	TEST_F(WeaponProficiencyLoaderTest, ShapingRefusesWhenTheServerHasNoShapingFile) {
		writeFile("sword.json", singleProficiency(1, 5));
		ASSERT_TRUE(WeaponProficiency::loadFromJson());
		ASSERT_TRUE(WeaponProficiency::getShapingRules().empty());

		auto player = std::make_shared<Player>();
		auto &proficiency = player->weaponProficiency();

		// NotConfigured comes before every other check, so a server that does not run
		// shaping answers the same way whatever else is wrong with the request.
		EXPECT_EQ(ProficiencyShapingResult::NotConfigured, proficiency.shapePerk(0, 0, 0));
		EXPECT_EQ(ProficiencyShapingResult::NotConfigured, proficiency.refinePerk(0, 0));
		EXPECT_EQ(ProficiencyShapingResult::NotConfigured, proficiency.reshapePerk(0, 0, 1));
		EXPECT_EQ(ProficiencyShapingResult::NotConfigured, proficiency.clearShapedPerk(0, 0));
	}

	TEST_F(WeaponProficiencyLoaderTest, ShapingRefusesAnInvalidWeapon) {
		writeFile("sword.json", singleProficiency(1, 5));
		// Protection zone off, so nothing but the weapon check could refuse this.
		writeShaping(
			R"({"RequiresProtectionZone":false,"Slots":[{"Slot":0}],)"
			R"("Options":[{"Id":1,"Type":8,"ValuePerRank":[0.01]}]})"
		);
		ASSERT_TRUE(WeaponProficiency::loadFromJson());

		auto player = std::make_shared<Player>();
		auto &proficiency = player->weaponProficiency();

		EXPECT_EQ(ProficiencyShapingResult::InvalidWeapon, proficiency.shapePerk(0, 0, 0));
		EXPECT_EQ(ProficiencyShapingResult::InvalidWeapon, proficiency.refinePerk(0, 0));
		EXPECT_EQ(ProficiencyShapingResult::InvalidWeapon, proficiency.clearShapedPerk(0, 0));
	}

	TEST_F(WeaponProficiencyLoaderTest, TheWeaponCheckRunsBeforeTheProtectionZoneCheck) {
		writeFile("sword.json", singleProficiency(1, 5));
		writeShaping(minimalShaping());
		ASSERT_TRUE(WeaponProficiency::loadFromJson());
		ASSERT_TRUE(WeaponProficiency::getShapingRules().requiresProtectionZone);

		auto player = std::make_shared<Player>();

		// This player would fail the protection zone check too - it has no tile at all -
		// but the weapon check comes first, so that is what answers. The order matters
		// for the message the client shows: telling someone to walk to a temple when the
		// real problem is the weapon would send them on a pointless trip.
		//
		// The protection zone branch itself cannot be reached from a unit test:
		// isValidWeaponId needs weaponId < Item::items.size(), and Item::items is empty
		// until the item files are loaded, so no weapon id gets past the second guard.
		// Exercising that branch needs an integration test with items loaded.
		EXPECT_EQ(ProficiencyShapingResult::InvalidWeapon, player->weaponProficiency().shapePerk(0, 0, 0));
	}

	TEST_F(WeaponProficiencyLoaderTest, APlayerWithNoDataHasNothingShapedAndNothingToReshape) {
		writeFile("sword.json", singleProficiency(1, 5));
		writeShaping(minimalShaping());
		ASSERT_TRUE(WeaponProficiency::loadFromJson());

		auto player = std::make_shared<Player>();
		const auto &proficiency = player->weaponProficiency();

		EXPECT_EQ(0, proficiency.countShapedPerks(0));
		EXPECT_EQ(0, proficiency.countShapedPerks(1234));
		EXPECT_TRUE(proficiency.rollReshapeOptions(1234, 0).empty());
	}

} // namespace
