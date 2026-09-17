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

#include "creatures/combat/condition.hpp"
#include "creatures/players/player.hpp"
#include "utils/tools.hpp"

namespace {

	// The stance families' cooldowns ride the engine's secondary spell groups: the
	// Elemental family (and the General one, no vocation holds both) on Focus, the
	// Crippling family on Crippling. Spell::playerSpellCheck refuses a cast while
	// player->hasCondition(CONDITION_SPELLGROUPCOOLDOWN, group) holds for the spell's
	// primary or secondary group; this pins that the two families' locks are
	// independent, which is what makes a Sorcerer's Elemental + Crippling pair work.
	class StanceFamilyCooldownTest : public ::testing::Test {
	protected:
		void SetUp() override {
			UPDATE_OTSYS_TIME();
		}

		static std::shared_ptr<Condition> groupLock(SpellGroup_t group, int32_t ms) {
			auto condition = Condition::createCondition(CONDITIONID_DEFAULT, CONDITION_SPELLGROUPCOOLDOWN, ms, 0, false, group);
			EXPECT_NE(nullptr, condition);
			return condition;
		}

		static bool locked(const std::shared_ptr<Player> &player, SpellGroup_t group) {
			return player->hasCondition(CONDITION_SPELLGROUPCOOLDOWN, group);
		}
	};

	TEST_F(StanceFamilyCooldownTest, AnElementalStanceLocksItsFamilyForItsDurationAndNotTheCripplingOne) {
		auto sorcerer = std::make_shared<Player>();
		// Master of Flames: 2s Support, 30s Focus (the Elemental family).
		ASSERT_TRUE(sorcerer->addCondition(groupLock(SPELLGROUP_SUPPORT, 2000)));
		ASSERT_TRUE(sorcerer->addCondition(groupLock(SPELLGROUP_FOCUS, 30000)));

		EXPECT_TRUE(locked(sorcerer, SPELLGROUP_FOCUS)) << "Master of Thunder is locked";
		EXPECT_FALSE(locked(sorcerer, SPELLGROUP_CRIPPLING)) << "Aura of Exposed Weakness is not";
		EXPECT_EQ(30000, sorcerer->getCondition(CONDITION_SPELLGROUPCOOLDOWN, CONDITIONID_DEFAULT, SPELLGROUP_FOCUS)->getTicks());
	}

	TEST_F(StanceFamilyCooldownTest, ACripplingStanceLocksItsFamilyAndNotTheElementalOne) {
		auto sorcerer = std::make_shared<Player>();
		ASSERT_TRUE(sorcerer->addCondition(groupLock(SPELLGROUP_SUPPORT, 2000)));
		ASSERT_TRUE(sorcerer->addCondition(groupLock(SPELLGROUP_CRIPPLING, 30000)));

		EXPECT_TRUE(locked(sorcerer, SPELLGROUP_CRIPPLING)) << "Aura of Sapped Strength is locked";
		EXPECT_FALSE(locked(sorcerer, SPELLGROUP_FOCUS)) << "Master of Thunder is not";
	}

	TEST_F(StanceFamilyCooldownTest, BothFamiliesLockedAtOnceStayIndependent) {
		auto sorcerer = std::make_shared<Player>();
		ASSERT_TRUE(sorcerer->addCondition(groupLock(SPELLGROUP_FOCUS, 30000)));
		ASSERT_TRUE(sorcerer->addCondition(groupLock(SPELLGROUP_CRIPPLING, 30000)));
		EXPECT_TRUE(locked(sorcerer, SPELLGROUP_FOCUS));
		EXPECT_TRUE(locked(sorcerer, SPELLGROUP_CRIPPLING));

		sorcerer->removeCondition(sorcerer->getCondition(CONDITION_SPELLGROUPCOOLDOWN, CONDITIONID_DEFAULT, SPELLGROUP_FOCUS));
		EXPECT_FALSE(locked(sorcerer, SPELLGROUP_FOCUS));
		EXPECT_TRUE(locked(sorcerer, SPELLGROUP_CRIPPLING)) << "the Crippling lock outlives the Elemental one";
	}

	TEST_F(StanceFamilyCooldownTest, AGeneralStanceLockIsTheFocusFamilyAndTouchesNoOtherGroup) {
		auto paladin = std::make_shared<Player>();
		// Divine Defiance: 2s Support, 10s Focus.
		ASSERT_TRUE(paladin->addCondition(groupLock(SPELLGROUP_SUPPORT, 2000)));
		ASSERT_TRUE(paladin->addCondition(groupLock(SPELLGROUP_FOCUS, 10000)));
		EXPECT_TRUE(locked(paladin, SPELLGROUP_FOCUS)) << "Sharpshooter is locked";
		EXPECT_FALSE(locked(paladin, SPELLGROUP_ATTACK));
		EXPECT_FALSE(locked(paladin, SPELLGROUP_HEALING)) << "no healing lockout any more";
		EXPECT_EQ(10000, paladin->getCondition(CONDITION_SPELLGROUPCOOLDOWN, CONDITIONID_DEFAULT, SPELLGROUP_FOCUS)->getTicks());
	}

}
