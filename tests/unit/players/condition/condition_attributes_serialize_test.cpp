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
#include "io/fileloader.hpp"

namespace {

	// The 15.25 stances persist across logout, so what a ConditionAttributes writes
	// to the player's conditions blob has to come back whole. These tests go through
	// the real path - serialize into a PropWriteStream, createCondition + unserialize
	// out of a PropStream - and then observe the effect on a fresh Player, because
	// the fields themselves are private and the effect is what matters.
	class ConditionAttributesSerializeTest : public ::testing::Test {
	protected:
		void SetUp() override {
			UPDATE_OTSYS_TIME();
		}

		static std::shared_ptr<Condition> roundTrip(const std::shared_ptr<Condition> &condition) {
			PropWriteStream out;
			condition->serialize(out);
			out.write<uint8_t>(CONDITIONATTR_END);

			size_t size = 0;
			const char* bytes = out.getStream(size);
			PropStream in;
			in.init(bytes, size);

			auto restored = Condition::createCondition(in);
			EXPECT_NE(nullptr, restored) << "createCondition could not read the header back";
			if (restored) {
				EXPECT_TRUE(restored->unserialize(in)) << "unserialize refused what serialize wrote";
			}
			return restored;
		}

		static std::shared_ptr<Condition> persistentAttributes(uint32_t subId) {
			auto condition = Condition::createCondition(CONDITIONID_COMBAT, CONDITION_ATTRIBUTES, -1, 0, false, subId, true);
			EXPECT_NE(nullptr, condition);
			return condition;
		}
	};

	TEST_F(ConditionAttributesSerializeTest, RangedDodgeSurvivesTheBlob) {
		auto condition = persistentAttributes(1);
		ASSERT_TRUE(condition->setParam(CONDITION_PARAM_DODGE_RANGED, 1200));

		auto restored = roundTrip(condition);
		ASSERT_NE(nullptr, restored);

		auto player = std::make_shared<Player>();
		EXPECT_EQ(0, player->getRangedDodgeChance());
		ASSERT_TRUE(player->addCondition(restored));
		EXPECT_EQ(1200, player->getRangedDodgeChance());

		player->removeCondition(restored);
		EXPECT_EQ(0, player->getRangedDodgeChance()) << "endCondition must give back exactly what startCondition gave";
	}

	TEST_F(ConditionAttributesSerializeTest, SpecializedMagicLevelRecipeSurvivesAndRecomputes) {
		// 100% of Distance Fighting as Holy Magic Level. A fresh Player's base skill is
		// 10, so the flat value the recipe produces is observable without items loaded.
		auto condition = persistentAttributes(2);
		ASSERT_TRUE(condition->setParam(CONDITION_PARAM_SPECIALIZED_MAGICLEVEL_SOURCE, SKILL_DISTANCE));
		ASSERT_TRUE(condition->setParam(CONDITION_PARAM_SPECIALIZED_MAGICLEVEL_HOLYPERCENT, 100));

		auto restored = roundTrip(condition);
		ASSERT_NE(nullptr, restored);

		auto player = std::make_shared<Player>();
		const auto distance = player->getSkillLevel(SKILL_DISTANCE);
		ASSERT_GT(distance, 0);
		EXPECT_EQ(0, player->getSpecializedMagicLevel(COMBAT_HOLYDAMAGE));
		ASSERT_TRUE(player->addCondition(restored));
		EXPECT_EQ(distance, player->getSpecializedMagicLevel(COMBAT_HOLYDAMAGE));

		player->removeCondition(restored);
		EXPECT_EQ(0, player->getSpecializedMagicLevel(COMBAT_HOLYDAMAGE));
	}

	TEST_F(ConditionAttributesSerializeTest, MagicLevelIsAnAcceptedSourceAndSurvivesTheBlob) {
		// SKILL_MAGLEVEL sits outside [SKILL_FIRST, SKILL_LAST] on purpose, and the
		// first version of this code refused it. Elemental Synthesis reads from it.
		auto condition = persistentAttributes(3);
		ASSERT_TRUE(condition->setParam(CONDITION_PARAM_SPECIALIZED_MAGICLEVEL_SOURCE, SKILL_MAGLEVEL));
		ASSERT_TRUE(condition->setParam(CONDITION_PARAM_SPECIALIZED_MAGICLEVEL_ICEPERCENT, 10));

		auto restored = roundTrip(condition);
		ASSERT_NE(nullptr, restored);
	}

	TEST_F(ConditionAttributesSerializeTest, AConditionWithNoRecipeStillLoads) {
		// Every ConditionAttributes without a recipe carries SKILL_NONE, which is -1.
		// Written as an unsigned byte that became 255 and the reader refused it,
		// which would have stopped every saved attribute condition on the server from
		// loading. This is the regression test for that.
		auto condition = persistentAttributes(4);
		ASSERT_TRUE(condition->setParam(CONDITION_PARAM_SKILL_SHIELDPERCENT, 130));

		auto restored = roundTrip(condition);
		ASSERT_NE(nullptr, restored);
	}

	TEST_F(ConditionAttributesSerializeTest, ElementCriticalSurvivesTheBlob) {
		auto condition = persistentAttributes(5);
		ASSERT_TRUE(condition->setParam(CONDITION_PARAM_ELEMENT_CRITICAL_CHANCE_ENERGY, 400));
		ASSERT_TRUE(condition->setParam(CONDITION_PARAM_ELEMENT_CRITICAL_DAMAGE_DEATH, 3000));

		auto restored = roundTrip(condition);
		ASSERT_NE(nullptr, restored);

		auto player = std::make_shared<Player>();
		ASSERT_TRUE(player->addCondition(restored));

		CombatDamage energy;
		energy.primary.type = COMBAT_ENERGYDAMAGE;
		player->applyConditionElementCritical(energy);
		EXPECT_EQ(400, energy.criticalChance);
		EXPECT_EQ(0, energy.criticalDamage);

		CombatDamage death;
		death.primary.type = COMBAT_DEATHDAMAGE;
		player->applyConditionElementCritical(death);
		EXPECT_EQ(0, death.criticalChance);
		EXPECT_EQ(3000, death.criticalDamage);

		player->removeCondition(restored);
		CombatDamage after;
		after.primary.type = COMBAT_ENERGYDAMAGE;
		player->applyConditionElementCritical(after);
		EXPECT_EQ(0, after.criticalChance);
	}

	TEST_F(ConditionAttributesSerializeTest, ElementalPierceReceivedSurvivesTheBlobAndComesOff) {
		// Aura of Exposed Weakness lands this on the monster hit. It is what
		// Creature::applyAbsorbDamageModifications subtracts from the resistance.
		auto condition = persistentAttributes(7);
		ASSERT_TRUE(condition->setParam(CONDITION_PARAM_ELEMENTAL_PIERCE_RECEIVED, 8));

		auto restored = roundTrip(condition);
		ASSERT_NE(nullptr, restored);

		auto creature = std::make_shared<Player>();
		EXPECT_EQ(0, creature->getElementalPierceReceived());
		ASSERT_TRUE(creature->addCondition(restored));
		EXPECT_EQ(8, creature->getElementalPierceReceived());

		creature->removeCondition(restored);
		EXPECT_EQ(0, creature->getElementalPierceReceived());
	}

	TEST_F(ConditionAttributesSerializeTest, PercentSkillsSurviveTheBlobAndRecompute) {
		// The recipe, not the result: skillsPercent is what has to come back, so the
		// bonus is recomputed against the player's current skill on login rather than
		// replayed as the flat value it was when first cast.
		auto condition = persistentAttributes(6);
		ASSERT_TRUE(condition->setParam(CONDITION_PARAM_SKILL_DISTANCEPERCENT, 200));

		auto restored = roundTrip(condition);
		ASSERT_NE(nullptr, restored);

		auto player = std::make_shared<Player>();
		const auto base = player->getBaseSkill(SKILL_DISTANCE);
		ASSERT_GT(base, 0);
		ASSERT_TRUE(player->addCondition(restored));
		EXPECT_EQ(base * 2, player->getSkillLevel(SKILL_DISTANCE));
	}

}
