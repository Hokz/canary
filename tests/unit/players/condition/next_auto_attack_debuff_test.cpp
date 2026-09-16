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

	// Shield Bash / Shield Slam: the target's NEXT auto attack deals less, once.
	// Player is the concrete Creature used here; the mechanic lives on Creature, so
	// monsters carry it the same way.
	class NextAutoAttackDebuffTest : public ::testing::Test {
	protected:
		void SetUp() override {
			UPDATE_OTSYS_TIME();
		}

		static CombatDamage swing(CombatOrigin origin, int32_t primary = 100, int32_t secondary = 40) {
			CombatDamage damage;
			damage.origin = origin;
			damage.primary.type = COMBAT_PHYSICALDAMAGE;
			damage.primary.value = primary;
			damage.secondary.type = COMBAT_FIREDAMAGE;
			damage.secondary.value = secondary;
			return damage;
		}
	};

	TEST_F(NextAutoAttackDebuffTest, ReducesTheNextAutoAttackAndIsConsumed) {
		auto creature = std::make_shared<Player>();
		creature->setNextAutoAttackDebuff(50, 10000);
		ASSERT_TRUE(creature->hasNextAutoAttackDebuff());

		auto first = swing(ORIGIN_MELEE);
		EXPECT_TRUE(creature->consumeNextAutoAttackDebuff(first));
		EXPECT_EQ(50, first.primary.value);
		EXPECT_EQ(20, first.secondary.value);
		EXPECT_FALSE(creature->hasNextAutoAttackDebuff()) << "one swing spends it";

		auto second = swing(ORIGIN_MELEE);
		EXPECT_FALSE(creature->consumeNextAutoAttackDebuff(second));
		EXPECT_EQ(100, second.primary.value) << "the swing after the consumed one is normal";
	}

	TEST_F(NextAutoAttackDebuffTest, SpellsAndRunesAreNotReducedAndDoNotSpendIt) {
		auto creature = std::make_shared<Player>();
		creature->setNextAutoAttackDebuff(50, 10000);

		for (const auto origin : { ORIGIN_SPELL, ORIGIN_CONDITION, ORIGIN_NONE }) {
			auto cast = swing(origin);
			EXPECT_FALSE(creature->consumeNextAutoAttackDebuff(cast));
			EXPECT_EQ(100, cast.primary.value);
			EXPECT_TRUE(creature->hasNextAutoAttackDebuff()) << "a spell must not consume the auto-attack debuff";
		}

		auto melee = swing(ORIGIN_MELEE);
		EXPECT_TRUE(creature->consumeNextAutoAttackDebuff(melee));
		EXPECT_EQ(50, melee.primary.value);
	}

	TEST_F(NextAutoAttackDebuffTest, RangedAndFistCountAsAutoAttacks) {
		for (const auto origin : { ORIGIN_RANGED, ORIGIN_FIST }) {
			auto creature = std::make_shared<Player>();
			creature->setNextAutoAttackDebuff(50, 10000);
			auto attack = swing(origin);
			EXPECT_TRUE(creature->consumeNextAutoAttackDebuff(attack));
			EXPECT_EQ(50, attack.primary.value);
		}
	}

	TEST_F(NextAutoAttackDebuffTest, ExpiresWithoutASwing) {
		auto creature = std::make_shared<Player>();
		// A zero duration is already expired: OTSYS_TIME() is not in the future.
		creature->setNextAutoAttackDebuff(50, 0);
		EXPECT_FALSE(creature->hasNextAutoAttackDebuff());

		auto melee = swing(ORIGIN_MELEE);
		EXPECT_FALSE(creature->consumeNextAutoAttackDebuff(melee));
		EXPECT_EQ(100, melee.primary.value);
	}

	TEST_F(NextAutoAttackDebuffTest, ReapplyingRefreshesPercentAndEachCreatureOwnsItsOwn) {
		auto a = std::make_shared<Player>();
		auto b = std::make_shared<Player>();
		a->setNextAutoAttackDebuff(50, 10000);
		a->setNextAutoAttackDebuff(75, 10000); // Shield Slam Augment II
		b->setNextAutoAttackDebuff(50, 10000);

		auto swingA = swing(ORIGIN_MELEE);
		EXPECT_TRUE(a->consumeNextAutoAttackDebuff(swingA));
		EXPECT_EQ(25, swingA.primary.value);
		EXPECT_TRUE(b->hasNextAutoAttackDebuff()) << "consuming a's must not touch b's";

		auto swingB = swing(ORIGIN_MELEE);
		EXPECT_TRUE(b->consumeNextAutoAttackDebuff(swingB));
		EXPECT_EQ(50, swingB.primary.value);
	}

}
