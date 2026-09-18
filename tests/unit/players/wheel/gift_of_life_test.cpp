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

#include "creatures/players/player.hpp"
#include "utils/tools.hpp"

namespace {

	// 15.25: Gift of Life gives back mana as well as health, the same percentage of
	// each maximum - 20 / 25 / 30 by stage. Before this it restored health only.
	//
	// checkGiftOfLife itself needs a near-death and a running game to reach, so the two
	// amounts it sends are accessors and those are what is asserted here.
	class GiftOfLifeTest : public ::testing::Test {
	protected:
		void SetUp() override {
			UPDATE_OTSYS_TIME();
		}

		// Maximum health and mana come from vocation and level, which a bare test
		// player has none of. The Wheel's own stats feed the same two getters and need
		// no game running, so they are what gives this player known maximums.
		static std::shared_ptr<Player> playerWith(int32_t maxHealth, int32_t maxMana, uint8_t giftStage) {
			auto player = std::make_shared<Player>();
			player->wheel().addStat(WheelStat_t::HEALTH, maxHealth - player->getMaxHealth());
			player->wheel().addStat(WheelStat_t::MANA, maxMana - static_cast<int32_t>(player->getMaxMana()));
			player->wheel().setStage(WheelStage_t::GIFT_OF_LIFE, giftStage);
			return player;
		}
	};

	TEST_F(GiftOfLifeTest, TheStagePercentagesAreTwentyTwentyFiveThirty) {
		auto player = std::make_shared<Player>();
		EXPECT_EQ(0, player->wheel().getGiftOfLifeValue()) << "no stage, no Gift of Life";

		player->wheel().setStage(WheelStage_t::GIFT_OF_LIFE, 1);
		EXPECT_EQ(20, player->wheel().getGiftOfLifeValue());
		player->wheel().setStage(WheelStage_t::GIFT_OF_LIFE, 2);
		EXPECT_EQ(25, player->wheel().getGiftOfLifeValue());
		player->wheel().setStage(WheelStage_t::GIFT_OF_LIFE, 3);
		EXPECT_EQ(30, player->wheel().getGiftOfLifeValue());
	}

	TEST_F(GiftOfLifeTest, ManaComesBackAtEveryStage) {
		struct Case {
			uint8_t stage;
			int32_t expected;
		};
		for (const auto &[stage, expected] : { Case { 1, 400 }, Case { 2, 500 }, Case { 3, 600 } }) {
			auto player = playerWith(5000, 2000, stage);
			ASSERT_EQ(2000u, player->getMaxMana()) << "stage " << static_cast<int>(stage);
			EXPECT_EQ(expected, player->wheel().getGiftOfLifeManaAmount()) << "stage " << static_cast<int>(stage);
		}
	}

	TEST_F(GiftOfLifeTest, HealthStillComesBackUnchanged) {
		struct Case {
			uint8_t stage;
			int32_t expected;
		};
		for (const auto &[stage, expected] : { Case { 1, 1000 }, Case { 2, 1250 }, Case { 3, 1500 } }) {
			auto player = playerWith(5000, 2000, stage);
			ASSERT_EQ(5000, player->getMaxHealth()) << "stage " << static_cast<int>(stage);
			EXPECT_EQ(expected, player->wheel().getGiftOfLifeHealthAmount()) << "stage " << static_cast<int>(stage);
		}
	}

	TEST_F(GiftOfLifeTest, BothHalvesReadTheOnepercentage) {
		// Health and mana are separate pipelines but a single percentage. If a later
		// edit moved one of them, these two ratios would stop matching.
		auto player = playerWith(4000, 4000, 2);
		EXPECT_EQ(player->wheel().getGiftOfLifeHealthAmount(), player->wheel().getGiftOfLifeManaAmount())
			<< "equal maximums must give equal amounts";
		EXPECT_EQ(1000, player->wheel().getGiftOfLifeManaAmount());
	}

	TEST_F(GiftOfLifeTest, WithoutTheStageNothingComesBack) {
		auto player = playerWith(5000, 2000, 0);
		EXPECT_EQ(0, player->wheel().getGiftOfLifeHealthAmount());
		EXPECT_EQ(0, player->wheel().getGiftOfLifeManaAmount());
	}

	TEST_F(GiftOfLifeTest, AManalessCharacterGetsNoManaAndStillGetsHealth) {
		// A Knight's maximum mana can be very low; the mana half must not turn into a
		// negative or throw the health half off.
		auto player = playerWith(10000, 0, 3);
		ASSERT_EQ(0u, player->getMaxMana());
		EXPECT_EQ(0, player->wheel().getGiftOfLifeManaAmount());
		EXPECT_EQ(3000, player->wheel().getGiftOfLifeHealthAmount());
	}

	TEST_F(GiftOfLifeTest, TheAmountsTruncateRatherThanRound) {
		// Integer division, as everywhere else in this engine's percentage maths.
		auto player = playerWith(101, 101, 1);
		EXPECT_EQ(20, player->wheel().getGiftOfLifeHealthAmount()) << "20% of 101 is 20.2";
		EXPECT_EQ(20, player->wheel().getGiftOfLifeManaAmount());
	}
}
