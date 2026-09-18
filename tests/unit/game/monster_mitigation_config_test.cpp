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

		// What the mitigation layer does to a hit, so a test can assert on damage rather
		// than only on the percentage. Mirrors Creature::mitigateDamage's arithmetic.
		static int32_t damageAfterMitigation(int32_t incoming, float mitigation) {
			int32_t damage = incoming;
			damage -= (damage * mitigation) / 100.;
			return damage <= 0 ? 0 : damage;
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

	// --- Negative configuration can never reach combat ---------------------------
	//
	// Both keys are user-editable, and a negative one would invert the percentage
	// layer: Creature::mitigateDamage computes damage -= damage * mitigation / 100, so
	// a negative mitigation ADDS damage instead of removing it. The correction happens
	// at the configuration boundary, so combat never sees an invalid value, and
	// Monster::getMitigation keeps one std::max because info.mitigation comes from a
	// monster's own XML, which nothing validates.

	TEST_F(MonsterMitigationConfigTest, ANegativeMultiplierNeverReachesCombat) {
		loadConfig("monsterMitigationMultiplier = -1.0\n");
		EXPECT_FLOAT_EQ(0.0f, g_configManager().getFloat(MONSTER_MITIGATION_MULTIPLIER)) << "corrected to zero at the boundary";
		EXPECT_GE(monsterWithMitigation(10.0f)->getMitigation(), 0.0f);
		EXPECT_FLOAT_EQ(0.0f, monsterWithMitigation(10.0f)->getMitigation());
	}

	TEST_F(MonsterMitigationConfigTest, ANegativeCapNeverReachesCombat) {
		loadConfig("monsterMitigationCap = -10.0\n");
		EXPECT_FLOAT_EQ(0.0f, g_configManager().getFloat(MONSTER_MITIGATION_CAP)) << "corrected to zero at the boundary";
		EXPECT_GE(monsterWithMitigation(10.0f)->getMitigation(), 0.0f);
		EXPECT_FLOAT_EQ(0.0f, monsterWithMitigation(10.0f)->getMitigation()) << "a zero ceiling holds mitigation at zero";
	}

	TEST_F(MonsterMitigationConfigTest, ANegativeMultiplierCannotIncreaseDamage) {
		// The failure this fix exists to prevent: a 1000-damage hit must never come out
		// of the mitigation layer larger than it went in.
		loadConfig("monsterMitigationMultiplier = -5.0\n");
		const float mitigation = monsterWithMitigation(20.0f)->getMitigation();
		ASSERT_GE(mitigation, 0.0f);
		EXPECT_LE(damageAfterMitigation(1000, mitigation), 1000) << "mitigation amplified the hit";
		EXPECT_EQ(1000, damageAfterMitigation(1000, mitigation)) << "with mitigation at zero the hit passes through unchanged";
	}

	TEST_F(MonsterMitigationConfigTest, ANegativeCapCannotProduceNegativeMitigation) {
		loadConfig("monsterMitigationCap = -45.0\nmonsterMitigationMultiplier = 2.0\n");
		for (const float raw : { 0.0f, 1.0f, 10.0f, 40.0f, 100.0f }) {
			const float mitigation = monsterWithMitigation(raw)->getMitigation();
			EXPECT_GE(mitigation, 0.0f) << "raw " << raw;
			EXPECT_LE(damageAfterMitigation(1000, mitigation), 1000) << "raw " << raw;
		}
	}

	TEST_F(MonsterMitigationConfigTest, BothNegativeAtOnceIsStillSafe) {
		loadConfig("monsterMitigationMultiplier = -2.0\nmonsterMitigationCap = -20.0\n");
		EXPECT_FLOAT_EQ(0.0f, g_configManager().getFloat(MONSTER_MITIGATION_MULTIPLIER));
		EXPECT_FLOAT_EQ(0.0f, g_configManager().getFloat(MONSTER_MITIGATION_CAP));
		EXPECT_FLOAT_EQ(0.0f, monsterWithMitigation(30.0f)->getMitigation());
		EXPECT_EQ(1000, damageAfterMitigation(1000, monsterWithMitigation(30.0f)->getMitigation()));
	}

	TEST_F(MonsterMitigationConfigTest, ANegativeMitigationInAMonstersOwnXmlIsAlsoClamped) {
		// The second input path: the configuration is validated, info.mitigation is not.
		loadConfig("");
		EXPECT_FLOAT_EQ(0.0f, monsterWithMitigation(-25.0f)->getMitigation());
		EXPECT_EQ(1000, damageAfterMitigation(1000, monsterWithMitigation(-25.0f)->getMitigation()));
	}

	TEST_F(MonsterMitigationConfigTest, ZeroIsAValidExplicitValueForBothKeys) {
		// Zero is a deliberate setting, not an error: it must be honoured silently.
		loadConfig("monsterMitigationMultiplier = 0.0\n");
		EXPECT_FLOAT_EQ(0.0f, g_configManager().getFloat(MONSTER_MITIGATION_MULTIPLIER));
		EXPECT_FLOAT_EQ(0.0f, monsterWithMitigation(30.0f)->getMitigation()) << "raw mitigation scaled to nothing";

		loadConfig("monsterMitigationCap = 0.0\n");
		EXPECT_FLOAT_EQ(0.0f, g_configManager().getFloat(MONSTER_MITIGATION_CAP));
		EXPECT_FLOAT_EQ(0.0f, monsterWithMitigation(30.0f)->getMitigation()) << "capped at nothing";
	}

	TEST_F(MonsterMitigationConfigTest, PositiveCustomValuesAreUntouchedByTheValidation) {
		// The guard must not disturb a valid configuration, including fractional and
		// large values.
		loadConfig("monsterMitigationMultiplier = 0.25\nmonsterMitigationCap = 12.5\n");
		EXPECT_FLOAT_EQ(0.25f, g_configManager().getFloat(MONSTER_MITIGATION_MULTIPLIER));
		EXPECT_FLOAT_EQ(12.5f, g_configManager().getFloat(MONSTER_MITIGATION_CAP));
		EXPECT_FLOAT_EQ(2.5f, monsterWithMitigation(10.0f)->getMitigation()) << "10 x 0.25";

		loadConfig("monsterMitigationMultiplier = 7.0\nmonsterMitigationCap = 900.0\n");
		EXPECT_FLOAT_EQ(7.0f, g_configManager().getFloat(MONSTER_MITIGATION_MULTIPLIER)) << "no hidden upper cap was added";
		EXPECT_FLOAT_EQ(900.0f, g_configManager().getFloat(MONSTER_MITIGATION_CAP));
		EXPECT_FLOAT_EQ(70.0f, monsterWithMitigation(10.0f)->getMitigation());
	}

	TEST_F(MonsterMitigationConfigTest, TheDefaultsSurviveTheValidation) {
		// 1.5 and 45.0 are both valid, so the guard must leave them exactly alone -
		// their confidence label does not change either: COMMUNITY_DERIVED_TUNABLE.
		loadConfig("");
		EXPECT_FLOAT_EQ(1.5f, g_configManager().getFloat(MONSTER_MITIGATION_MULTIPLIER));
		EXPECT_FLOAT_EQ(45.0f, g_configManager().getFloat(MONSTER_MITIGATION_CAP));
		EXPECT_FLOAT_EQ(15.0f, monsterWithMitigation(10.0f)->getMitigation());
		EXPECT_FLOAT_EQ(45.0f, monsterWithMitigation(40.0f)->getMitigation());
	}

}
