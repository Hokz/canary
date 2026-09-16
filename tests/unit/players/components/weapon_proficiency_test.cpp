/**
 * Canary - A free and open-source MMORPG server emulator
 * Copyright (©) 2019–present OpenTibiaBR <opentibiabr@outlook.com>
 * Repository: https://github.com/opentibiabr/canary
 * License: https://github.com/opentibiabr/canary/blob/main/LICENSE
 * Contributors: https://github.com/opentibiabr/canary/graphs/contributors
 * Website: https://docs.opentibiabr.com/
 */

#include "pch.hpp"

#include <filesystem>
#include <fstream>

#include <gtest/gtest.h>

#include "canary_server.hpp"
#include "config/configmanager.hpp"
#include "creatures/players/components/weapon_proficiency.hpp"
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

} // namespace
