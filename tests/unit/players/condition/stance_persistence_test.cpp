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
#include "io/fileloader.hpp"
#include "utils/tools.hpp"

namespace {

	// The stances are persistent ConditionAttributes; this pins what that must mean
	// for the player's numbers: adding, replacing, removing and reloading a stance
	// moves its modifiers exactly once each way, and a bad blob fails safely.
	class StancePersistenceTest : public ::testing::Test {
	protected:
		void SetUp() override {
			UPDATE_OTSYS_TIME();
		}

		// Sharpshooter's recipe: +32% Distance Fighting, persistent.
		static std::shared_ptr<Condition> sharpshooter() {
			auto condition = Condition::createCondition(CONDITIONID_COMBAT, CONDITION_ATTRIBUTES, -1, 0, false, magic_enum::enum_integer(AttrSubId_t::StanceSharpshooter), true);
			EXPECT_NE(nullptr, condition);
			EXPECT_TRUE(condition->setParam(CONDITION_PARAM_SKILL_DISTANCEPERCENT, 132));
			return condition;
		}

		static std::shared_ptr<Condition> readBack(PropWriteStream &out) {
			size_t size = 0;
			const char* bytes = out.getStream(size);
			PropStream in;
			in.init(bytes, size);
			auto restored = Condition::createCondition(in);
			if (restored && !restored->unserialize(in)) {
				return nullptr;
			}
			return restored;
		}

		static int32_t expectedBonus(const std::shared_ptr<Player> &player) {
			return static_cast<int32_t>(player->getBaseSkill(SKILL_DISTANCE) * 0.32f);
		}
	};

	TEST_F(StancePersistenceTest, AddingTheSameStanceTwiceAppliesItsModifierOnce) {
		auto player = std::make_shared<Player>();
		const auto base = player->getBaseSkill(SKILL_DISTANCE);
		ASSERT_TRUE(player->addCondition(sharpshooter()));
		EXPECT_EQ(base + expectedBonus(player), player->getSkillLevel(SKILL_DISTANCE));

		ASSERT_TRUE(player->addCondition(sharpshooter()));
		EXPECT_EQ(base + expectedBonus(player), player->getSkillLevel(SKILL_DISTANCE)) << "a merge replaces, it does not stack";
	}

	TEST_F(StancePersistenceTest, RemovingTheStanceTakesTheWholeModifierOff) {
		auto player = std::make_shared<Player>();
		const auto base = player->getBaseSkill(SKILL_DISTANCE);
		auto stance = sharpshooter();
		ASSERT_TRUE(player->addCondition(stance));
		ASSERT_NE(base, player->getSkillLevel(SKILL_DISTANCE));

		player->removeCondition(stance);
		EXPECT_EQ(base, player->getSkillLevel(SKILL_DISTANCE));
		EXPECT_FALSE(player->hasStance(AttrSubId_t::StanceSharpshooter));
	}

	TEST_F(StancePersistenceTest, ReplacingAStanceInItsFamilyLeavesOnlyTheNewOne) {
		// What Stance.cast does for a family change: remove the held one, add the new.
		auto player = std::make_shared<Player>();
		const auto base = player->getBaseSkill(SKILL_DISTANCE);
		auto held = sharpshooter();
		ASSERT_TRUE(player->addCondition(held));
		player->removeCondition(held);

		auto defiance = Condition::createCondition(CONDITIONID_COMBAT, CONDITION_ATTRIBUTES, -1, 0, false, magic_enum::enum_integer(AttrSubId_t::StanceDivineDefiance), true);
		ASSERT_TRUE(defiance->setParam(CONDITION_PARAM_DODGE_RANGED, 1200));
		ASSERT_TRUE(player->addCondition(defiance));

		EXPECT_EQ(base, player->getSkillLevel(SKILL_DISTANCE)) << "Sharpshooter's bonus is gone";
		EXPECT_EQ(1200, player->getRangedDodgeChance());
		EXPECT_FALSE(player->hasStance(AttrSubId_t::StanceSharpshooter));
		EXPECT_TRUE(player->hasStance(AttrSubId_t::StanceDivineDefiance));
	}

	TEST_F(StancePersistenceTest, ARelogRestoresThePermanentStanceExactlyOnce) {
		// The flag has to survive the factory first: Condition::createCondition's
		// CONDITION_ATTRIBUTES case once dropped it, and a stance that answers
		// "not persistent" is never written to the conditions blob at logout.
		EXPECT_TRUE(sharpshooter()->isPersistent()) << "a stance built with the flag must report it";
		EXPECT_FALSE(sharpshooter()->isRemovableOnDeath());

		PropWriteStream out;
		sharpshooter()->serialize(out);
		out.write<uint8_t>(CONDITIONATTR_END);

		auto restored = readBack(out);
		ASSERT_NE(nullptr, restored);
		EXPECT_TRUE(restored->isPersistent());
		EXPECT_EQ(-1, restored->getTicks());

		// Login: the stored condition list is added to the fresh Player.
		auto player = std::make_shared<Player>();
		const auto base = player->getBaseSkill(SKILL_DISTANCE);
		ASSERT_TRUE(player->addCondition(restored));
		EXPECT_EQ(base + expectedBonus(player), player->getSkillLevel(SKILL_DISTANCE));
		EXPECT_TRUE(player->hasStance(AttrSubId_t::StanceSharpshooter));
	}

	TEST_F(StancePersistenceTest, ACorruptSkillIndexFailsSafelyInsteadOfWritingPastTheArray) {
		PropWriteStream out;
		sharpshooter()->serialize(out); // writes exactly SKILL_LAST + 1 CONDITIONATTR_SKILLS entries
		out.write<uint8_t>(CONDITIONATTR_SKILLS); // one more than the array holds
		out.write<int32_t>(7);
		out.write<uint8_t>(CONDITIONATTR_END);

		EXPECT_EQ(nullptr, readBack(out)) << "unserialize must refuse the out-of-range index";
	}

	TEST_F(StancePersistenceTest, AConditionWithoutAnyNewFieldStillLoadsAndBehaves) {
		// A blob written before the 15.25 fields existed: an old timed attribute
		// buff with a flat skill and nothing else.
		auto old = Condition::createCondition(CONDITIONID_COMBAT, CONDITION_ATTRIBUTES, 5000, 0, false, 3);
		ASSERT_TRUE(old->setParam(CONDITION_PARAM_SKILL_SWORD, 5));
		PropWriteStream out;
		old->serialize(out);
		out.write<uint8_t>(CONDITIONATTR_END);

		auto restored = readBack(out);
		ASSERT_NE(nullptr, restored);
		auto player = std::make_shared<Player>();
		const auto base = player->getBaseSkill(SKILL_SWORD);
		ASSERT_TRUE(player->addCondition(restored));
		EXPECT_EQ(base + 5, player->getSkillLevel(SKILL_SWORD));
		EXPECT_EQ(COMBAT_NONE, player->getPendingElementalConversion());
		EXPECT_EQ(0, player->getRangedDodgeChance());
		EXPECT_EQ(0, player->getElementalPierceReceived());
	}

}
