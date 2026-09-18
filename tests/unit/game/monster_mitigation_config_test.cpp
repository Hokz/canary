/**
 * Canary - A free and open-source MMORPG server emulator
 * Copyright (©) 2019–present OpenTibiaBR <opentibiabr@outlook.com>
 * Repository: https://github.com/opentibiabr/canary
 * License: https://github.com/opentibiabr/canary/blob/main/LICENSE
 * Contributors: https://github.com/opentibiabr/canary/graphs/contributors
 * Website: https://docs.opentibiabr.com/
 */

#include "pch.hpp"

#include <gtest/gtest.h>

#include "config/configmanager.hpp"
#include "creatures/monsters/monster.hpp"
#include "creatures/monsters/monsters.hpp"
#include "lib/logging/in_memory_logger.hpp"

namespace {

	// Monster mitigation is scaled and capped by configuration, not by constants in
	// the source. The 15.25 note says monster mitigation went up; it does not say by
	// how much or to what ceiling, so 1.5 and 45.0 are the project's accepted values
	// and both have to be changeable in config.lua without a recompile. These tests
	// drive the real config file, not a stubbed getter, because "changeable by config"
	// is the property being claimed.
	class MonsterMitigationConfigTest : public ::testing::Test {
	protected:
		static void SetUpTestSuite() {
			previousTestContainer = DI::getTestContainer();
			InMemoryLogger::install(injector);
			DI::setTestContainer(&injector);
		}

		static void TearDownTestSuite() {
			DI::setTestContainer(previousTestContainer);
		}

		void SetUp() override {
			std::error_code ec;
			const auto* testName = ::testing::UnitTest::GetInstance()->current_test_info()->name();
			root_ = std::filesystem::temp_directory_path(ec) / ("canary-monster-mitigation-" + std::string(testName));
			ASSERT_FALSE(ec) << "Could not resolve a temporary directory";
			std::filesystem::remove_all(root_, ec);
			ASSERT_TRUE(std::filesystem::create_directories(root_, ec)) << ec.message();

			previousConfigFile_ = g_configManager().getConfigFileLua();
		}

		void TearDown() override {
			(void)g_configManager().setConfigFileLua(previousConfigFile_);
			(void)g_configManager().reload();

			std::error_code ec;
			std::filesystem::remove_all(root_, ec);
		}

		// Writes a config.lua carrying only what this test needs and loads it. An
		// empty body means "the keys are absent", which is how an existing server's
		// config.lua looks the first time it meets this release.
		void loadConfig(const std::string &body) {
			const auto configPath = root_ / "config.lua";
			std::ofstream config(configPath);
			ASSERT_TRUE(config.is_open());
			config << body;
			config.close();

			(void)g_configManager().setConfigFileLua(configPath.generic_string());
			ASSERT_TRUE(g_configManager().reload());
		}

		// A monster whose type carries exactly the mitigation asked for, with a
		// neutral defence multiplier so the arithmetic is the config's alone.
		static std::shared_ptr<Monster> monsterWithMitigation(float mitigation) {
			auto monsterType = std::make_shared<MonsterType>("test monster");
			monsterType->info.mitigation = mitigation;
			monsterType->info.armor = 0;
			monsterType->info.defense = 0;
			auto monster = std::make_shared<Monster>(monsterType);
			return monster;
		}

		std::filesystem::path root_;
		std::string previousConfigFile_;

		inline static di::extension::injector<> injector {};
		inline static di::extension::injector<>* previousTestContainer = nullptr;
	};

	TEST_F(MonsterMitigationConfigTest, TheDefaultsAreOnePointFiveAndFortyFive) {
		// No keys in the file at all: the defaults are what an existing server gets
		// on upgrading, without editing anything.
		loadConfig("");
		EXPECT_FLOAT_EQ(1.5f, g_configManager().getFloat(MONSTER_MITIGATION_MULTIPLIER));
		EXPECT_FLOAT_EQ(45.0f, g_configManager().getFloat(MONSTER_MITIGATION_CAP));
	}

	TEST_F(MonsterMitigationConfigTest, RawTenBecomesFifteen) {
		loadConfig("");
		const auto monster = monsterWithMitigation(10.0f);
		EXPECT_FLOAT_EQ(15.0f, monster->getMitigation()) << "10 x 1.5";
	}

	TEST_F(MonsterMitigationConfigTest, AValueAboveTheCapStopsAtTheCap) {
		loadConfig("");
		// 40 x 1.5 = 60, over the ceiling.
		EXPECT_FLOAT_EQ(45.0f, monsterWithMitigation(40.0f)->getMitigation());
		// Exactly at the cap after scaling: 30 x 1.5 = 45.
		EXPECT_FLOAT_EQ(45.0f, monsterWithMitigation(30.0f)->getMitigation());
		// Just below: 29 x 1.5 = 43.5.
		EXPECT_FLOAT_EQ(43.5f, monsterWithMitigation(29.0f)->getMitigation());
	}

	TEST_F(MonsterMitigationConfigTest, TheMultiplierIsChangeableWithoutRecompiling) {
		loadConfig("monsterMitigationMultiplier = 2.0\n");
		EXPECT_FLOAT_EQ(2.0f, g_configManager().getFloat(MONSTER_MITIGATION_MULTIPLIER));
		EXPECT_FLOAT_EQ(20.0f, monsterWithMitigation(10.0f)->getMitigation());

		loadConfig("monsterMitigationMultiplier = 1.0\n");
		EXPECT_FLOAT_EQ(10.0f, monsterWithMitigation(10.0f)->getMitigation()) << "1.0 restores the pre-15.25 value";
	}

	TEST_F(MonsterMitigationConfigTest, TheCapIsChangeableWithoutRecompiling) {
		loadConfig("monsterMitigationCap = 30.0\n");
		EXPECT_FLOAT_EQ(30.0f, g_configManager().getFloat(MONSTER_MITIGATION_CAP));
		// 40 x 1.5 = 60, now held at the old 30 ceiling.
		EXPECT_FLOAT_EQ(30.0f, monsterWithMitigation(40.0f)->getMitigation());

		loadConfig("monsterMitigationCap = 80.0\n");
		EXPECT_FLOAT_EQ(60.0f, monsterWithMitigation(40.0f)->getMitigation()) << "a higher ceiling lets the scaled value through";
	}

	TEST_F(MonsterMitigationConfigTest, NoHardcodedOnePointFiveOrFortyFiveSurvives) {
		// If either number were still a literal in the source, setting both knobs to
		// something else would leave one of them showing through.
		loadConfig("monsterMitigationMultiplier = 3.0\nmonsterMitigationCap = 99.0\n");
		EXPECT_FLOAT_EQ(30.0f, monsterWithMitigation(10.0f)->getMitigation()) << "10 x 3.0, so the multiplier is not pinned at 1.5";
		EXPECT_FLOAT_EQ(99.0f, monsterWithMitigation(50.0f)->getMitigation()) << "50 x 3.0 held at 99, so the cap is not pinned at 45";
	}

	TEST_F(MonsterMitigationConfigTest, ZeroMitigationStaysZeroWhateverTheMultiplier) {
		loadConfig("monsterMitigationMultiplier = 3.0\n");
		EXPECT_FLOAT_EQ(0.0f, monsterWithMitigation(0.0f)->getMitigation());
	}

}
