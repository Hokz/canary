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

	// Shared Conservation's +10% is on healing SPELLS the holder casts on themselves,
	// decided in Player::applySharedConservationSelfHeal where healer and target are
	// both known. Not a generic "healing received" buff any more: a heal from someone
	// else, a heal the holder casts on someone else, and a potion get nothing.
	class SharedConservationSelfHealTest : public ::testing::Test {
	protected:
		void SetUp() override {
			UPDATE_OTSYS_TIME();
		}

		static std::shared_ptr<Player> druidWithStance() {
			auto druid = std::make_shared<Player>();
			auto stance = Condition::createCondition(CONDITIONID_COMBAT, CONDITION_ATTRIBUTES, -1, 0, false, magic_enum::enum_integer(AttrSubId_t::StanceSharedConservation), true);
			EXPECT_TRUE(druid->addCondition(stance));
			return druid;
		}

		static CombatDamage heal(int32_t value, CombatOrigin origin = ORIGIN_SPELL, const std::string &instant = "Light Healing", const std::string &rune = "") {
			CombatDamage damage;
			damage.origin = origin;
			damage.primary.type = COMBAT_HEALING;
			damage.primary.value = value;
			damage.instantSpellName = instant;
			damage.runeSpellName = rune;
			return damage;
		}
	};

	TEST_F(SharedConservationSelfHealTest, DruidHealingThemselvesGetsTenPercentMore) {
		auto druid = druidWithStance();
		auto damage = heal(200);
		EXPECT_TRUE(druid->applySharedConservationSelfHeal(druid, damage));
		EXPECT_EQ(220, damage.primary.value);
	}

	TEST_F(SharedConservationSelfHealTest, AHealingRuneOnThemselvesCountsToo) {
		auto druid = druidWithStance();
		auto damage = heal(200, ORIGIN_SPELL, "", "Ultimate Healing Rune");
		EXPECT_TRUE(druid->applySharedConservationSelfHeal(druid, damage));
		EXPECT_EQ(220, damage.primary.value);
	}

	TEST_F(SharedConservationSelfHealTest, AnotherPlayerHealingTheDruidGetsNoStanceBonus) {
		auto druid = druidWithStance();
		auto healer = std::make_shared<Player>();
		auto damage = heal(200, ORIGIN_SPELL, "Heal Friend");
		// The healer is the one asked; the target holds the stance, which is not enough.
		EXPECT_FALSE(healer->applySharedConservationSelfHeal(druid, damage));
		EXPECT_EQ(200, damage.primary.value);
	}

	TEST_F(SharedConservationSelfHealTest, DruidHealingAPartyMemberGetsNoSelfHealBonus) {
		auto druid = druidWithStance();
		auto knight = std::make_shared<Player>();
		auto damage = heal(200, ORIGIN_SPELL, "Heal Friend");
		EXPECT_FALSE(druid->applySharedConservationSelfHeal(knight, damage));
		EXPECT_EQ(200, damage.primary.value);
	}

	TEST_F(SharedConservationSelfHealTest, APotionIsNotASpell) {
		// doTargetCombatHealth from potions.lua: ORIGIN_SPELL by default, no spell name.
		auto druid = druidWithStance();
		auto damage = heal(200, ORIGIN_SPELL, "", "");
		EXPECT_FALSE(druid->applySharedConservationSelfHeal(druid, damage));
		EXPECT_EQ(200, damage.primary.value);

		auto regen = heal(200, ORIGIN_CONDITION, "", "");
		EXPECT_FALSE(druid->applySharedConservationSelfHeal(druid, regen));
		EXPECT_EQ(200, regen.primary.value);
	}

	TEST_F(SharedConservationSelfHealTest, WithoutTheStanceNothingChanges) {
		auto druid = std::make_shared<Player>();
		auto damage = heal(200);
		EXPECT_FALSE(druid->applySharedConservationSelfHeal(druid, damage));
		EXPECT_EQ(200, damage.primary.value);
	}

	TEST_F(SharedConservationSelfHealTest, TheGenericHealingReceivedBuffIsUntouchedAndIndependent) {
		// The engine's BUFF_HEALINGRECEIVED still exists for whatever else uses it, and
		// the stance no longer sets it: a Druid holding the stance has the default 100.
		auto druid = druidWithStance();
		EXPECT_EQ(100, druid->getBuff(BUFF_HEALINGRECEIVED));

		auto buff = Condition::createCondition(CONDITIONID_COMBAT, CONDITION_ATTRIBUTES, 5000, 0, false, 77);
		ASSERT_TRUE(buff->setParam(CONDITION_PARAM_BUFF_HEALINGRECEIVED, 120));
		ASSERT_TRUE(druid->addCondition(buff));
		EXPECT_EQ(120, druid->getBuff(BUFF_HEALINGRECEIVED));

		// And the stance applies once, on top, whatever other modifiers coexist.
		auto damage = heal(200);
		EXPECT_TRUE(druid->applySharedConservationSelfHeal(druid, damage));
		EXPECT_EQ(220, damage.primary.value);
	}

}
