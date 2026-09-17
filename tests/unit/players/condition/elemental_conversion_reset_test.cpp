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

	// A pending elemental conversion belongs to the Elemental stance that armed it.
	// The stance coming off - replaced or toggled off - disarms it, in
	// ConditionAttributes::endCondition; a Crippling or General stance changing does
	// not. This mirrors what data/libs/systems/stance.lua does on a cast: remove the
	// held stance of the family (endCondition), then add the new one.
	class ElementalConversionResetTest : public ::testing::Test {
	protected:
		void SetUp() override {
			UPDATE_OTSYS_TIME();
		}

		static std::shared_ptr<Condition> stance(AttrSubId_t subId) {
			auto condition = Condition::createCondition(CONDITIONID_COMBAT, CONDITION_ATTRIBUTES, -1, 0, false, magic_enum::enum_integer(subId), true);
			EXPECT_NE(nullptr, condition);
			return condition;
		}

		static void toggleOff(const std::shared_ptr<Player> &player, AttrSubId_t subId) {
			const auto &held = player->getCondition(CONDITION_ATTRIBUTES, CONDITIONID_COMBAT, magic_enum::enum_integer(subId));
			ASSERT_NE(nullptr, held);
			player->removeCondition(held);
		}
	};

	TEST_F(ElementalConversionResetTest, SwitchingFlamesToThunderDisarmsTheFireConversion) {
		auto player = std::make_shared<Player>();
		ASSERT_TRUE(player->addCondition(stance(AttrSubId_t::StanceMasterOfFlames)));
		player->setPendingElementalConversion(COMBAT_FIREDAMAGE); // a fire spell armed it

		// Stance.cast: clear the Elemental family, then add the new stance.
		toggleOff(player, AttrSubId_t::StanceMasterOfFlames);
		ASSERT_TRUE(player->addCondition(stance(AttrSubId_t::StanceMasterOfThunder)));

		EXPECT_EQ(COMBAT_NONE, player->getPendingElementalConversion());
		EXPECT_TRUE(player->hasStance(AttrSubId_t::StanceMasterOfThunder));
		EXPECT_FALSE(player->hasStance(AttrSubId_t::StanceMasterOfFlames));
	}

	TEST_F(ElementalConversionResetTest, TogglingFlamesOffDisarmsTheFireConversion) {
		auto player = std::make_shared<Player>();
		ASSERT_TRUE(player->addCondition(stance(AttrSubId_t::StanceMasterOfFlames)));
		player->setPendingElementalConversion(COMBAT_FIREDAMAGE);

		toggleOff(player, AttrSubId_t::StanceMasterOfFlames);

		EXPECT_EQ(COMBAT_NONE, player->getPendingElementalConversion());
		EXPECT_FALSE(player->hasStance(AttrSubId_t::StanceMasterOfFlames));
	}

	TEST_F(ElementalConversionResetTest, ChangingTheCripplingStanceLeavesTheConversionArmed) {
		auto player = std::make_shared<Player>();
		ASSERT_TRUE(player->addCondition(stance(AttrSubId_t::StanceMasterOfFlames)));
		ASSERT_TRUE(player->addCondition(stance(AttrSubId_t::StanceExposedWeakness)));
		player->setPendingElementalConversion(COMBAT_FIREDAMAGE);

		// Exposed -> Sapped: the Crippling family changes, the Elemental one does not.
		toggleOff(player, AttrSubId_t::StanceExposedWeakness);
		ASSERT_TRUE(player->addCondition(stance(AttrSubId_t::StanceSappedStrength)));

		EXPECT_EQ(COMBAT_FIREDAMAGE, player->getPendingElementalConversion());
		EXPECT_TRUE(player->hasStance(AttrSubId_t::StanceMasterOfFlames));
		EXPECT_TRUE(player->hasStance(AttrSubId_t::StanceSappedStrength));
	}

	TEST_F(ElementalConversionResetTest, AnUnrelatedAttributeConditionEndingLeavesItArmed) {
		auto player = std::make_shared<Player>();
		ASSERT_TRUE(player->addCondition(stance(AttrSubId_t::StanceMasterOfDecay)));
		player->setPendingElementalConversion(COMBAT_DEATHDAMAGE);

		auto unrelated = Condition::createCondition(CONDITIONID_COMBAT, CONDITION_ATTRIBUTES, 5000, 0, false, 99);
		ASSERT_NE(nullptr, unrelated);
		ASSERT_TRUE(player->addCondition(unrelated));
		player->removeCondition(unrelated);

		EXPECT_EQ(COMBAT_DEATHDAMAGE, player->getPendingElementalConversion());
	}

}
