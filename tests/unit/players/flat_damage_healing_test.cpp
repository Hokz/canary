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

	// The 15.25 level contribution to flat damage and healing.
	//
	// It is a tiered progression: levels 0..500 count at 1/5, the next 600 at 1/6, the
	// next 700 at 1/7, and so on - which means every completed tier is worth exactly
	// 100. That has a closed form, and it is what the engine computes now:
	//
	//   S = floor((sqrt(2L + 2025) + 5) / 10)
	//   B = floor((L + 1000) / S) + 50 * S - 450
	//
	// The loop that used to be here accumulated each tier's full threshold instead of
	// its width, so it agreed with the progression it documented only while no tier had
	// completed, and ran away above level 1100. These tests pin the closed form and
	// name that regression.
	class FlatDamageHealingTest : public ::testing::Test {
	protected:
		void SetUp() override {
			UPDATE_OTSYS_TIME();
		}

		static uint16_t at(uint32_t level) {
			auto player = std::make_shared<Player>();
			player->setLevel(level);
			return player->calculateFlatDamageHealing();
		}
	};

	TEST_F(FlatDamageHealingTest, TheClosedFormIsPinnedAcrossTheWholeRange) {
		// Every step transition is covered on both sides, which is where an off-by-one
		// in the floor semantics would show up.
		struct Case {
			uint32_t level;
			uint16_t expected;
		};
		static constexpr std::array<Case, 24> cases { {
			{ 1, 0 },
			{ 5, 1 },
			{ 8, 1 },
			{ 50, 10 },
			{ 100, 20 },
			{ 250, 50 },
			{ 499, 99 },
			{ 500, 100 },
			{ 501, 100 },
			{ 600, 116 },
			{ 1000, 183 },
			{ 1099, 199 },
			{ 1100, 200 },
			{ 1101, 200 },
			{ 1500, 257 },
			{ 1799, 299 },
			{ 1800, 300 },
			{ 1801, 300 },
			{ 2000, 325 },
			{ 2600, 400 },
			{ 2601, 400 },
			{ 3000, 444 },
			{ 5000, 645 },
			{ 8000, 892 },
		} };

		for (const auto &[level, expected] : cases) {
			EXPECT_EQ(expected, at(level)) << "level " << level;
		}
	}

	TEST_F(FlatDamageHealingTest, TheStepChangesExactlyAtTheTierBoundaries) {
		// S(L) = floor((sqrt(2L + 2025) + 5) / 10) steps up at 500, 1100, 1800 and 2600,
		// and each step is worth exactly 100 more. Asserted as the transition itself:
		// one level below the boundary is 99 short of it.
		static constexpr std::array<uint32_t, 4> boundaries { 500, 1100, 1800, 2600 };
		for (const uint32_t boundary : boundaries) {
			const uint16_t below = at(boundary - 1);
			const uint16_t on = at(boundary);
			const uint16_t above = at(boundary + 1);
			EXPECT_EQ(on - 1, below) << "boundary " << boundary << " must be reached by one";
			EXPECT_EQ(on, above) << "and the step must not jump past it";
		}
	}

	TEST_F(FlatDamageHealingTest, EveryCompletedTierIsWorthExactlyOneHundred) {
		// The property the progression is built on, and the cleanest way to catch a
		// coefficient drifting: the tier boundaries land on round hundreds.
		EXPECT_EQ(100, at(500));
		EXPECT_EQ(200, at(1100));
		EXPECT_EQ(300, at(1800));
		EXPECT_EQ(400, at(2600));
		EXPECT_EQ(500, at(3500));
	}

	TEST_F(FlatDamageHealingTest, TheHighLevelRunawayIsGone) {
		// The regression, named. The old loop returned 284 at level 1100, 566 at 2000
		// and 2873 at 8000 - inflating every high-level character's flat bonus, and with
		// it Shield Bash and Shield Slam, which read this value.
		EXPECT_EQ(200, at(1100)) << "was 284";
		EXPECT_EQ(325, at(2000)) << "was 566";
		EXPECT_EQ(892, at(8000)) << "was 2873";
	}

	TEST_F(FlatDamageHealingTest, ItNeverDecreasesAcrossTenThousandLevels) {
		// Every level, not a sample: an off-by-one at a step change is a single-level
		// regression and a stride would step over it.
		uint16_t previous = 0;
		for (uint32_t level = 1; level <= 10000; ++level) {
			const uint16_t value = at(level);
			ASSERT_GE(value, previous) << "level " << level << " went backwards";
			previous = value;
		}
		EXPECT_EQ(1033, at(10000));
	}

	TEST_F(FlatDamageHealingTest, TheFirstTierIsTheOldLevelTimesOneFifth) {
		// Every pre-15.25 healing formula in the datapack used level * 0.2. That is this
		// function's first tier, which is why the closed form is a generalisation of
		// those formulas rather than a replacement for them.
		for (const uint32_t level : { 5u, 50u, 100u, 250u, 400u, 500u }) {
			EXPECT_EQ(static_cast<uint16_t>(level / 5), at(level)) << "level " << level;
		}
	}

	TEST_F(FlatDamageHealingTest, ALevelOneCharacterGetsNothingAndNothingOverflows) {
		EXPECT_EQ(0, at(1));
		// The engine caps the result at a uint16_t; an absurd level must not wrap.
		EXPECT_GT(at(100000), 0);
		EXPECT_LE(at(100000), std::numeric_limits<uint16_t>::max());
	}
}
