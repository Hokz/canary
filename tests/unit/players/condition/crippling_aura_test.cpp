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
#include "creatures/combat/crippling_aura.hpp"
#include "creatures/players/player.hpp"
#include "utils/tools.hpp"

namespace {

	// Aura of Sapped Strength / Exposed Weakness land their debuff on the hit that
	// LANDS, from Game::combatChangeHealth after health was taken. CripplingAura::
	// qualifies is the gate; the debuffs refresh and never stack.
	class CripplingAuraTest : public ::testing::Test {
	protected:
		void SetUp() override {
			UPDATE_OTSYS_TIME();
		}

		static CombatDamage hit(CombatOrigin origin, const std::string &instant = "", const std::string &rune = "") {
			CombatDamage damage;
			damage.origin = origin;
			damage.primary.type = COMBAT_ENERGYDAMAGE;
			damage.primary.value = 100;
			damage.instantSpellName = instant;
			damage.runeSpellName = rune;
			return damage;
		}

		static std::shared_ptr<Player> sorcererWith(AttrSubId_t stance) {
			auto sorcerer = std::make_shared<Player>();
			auto condition = Condition::createCondition(CONDITIONID_COMBAT, CONDITION_ATTRIBUTES, -1, 0, false, magic_enum::enum_integer(stance), true);
			EXPECT_TRUE(sorcerer->addCondition(condition));
			return sorcerer;
		}
	};

	TEST_F(CripplingAuraTest, ALandedSpellRuneOrAutoAttackQualifies) {
		EXPECT_TRUE(CripplingAura::qualifies(hit(ORIGIN_SPELL, "Energy Strike"), 100));
		EXPECT_TRUE(CripplingAura::qualifies(hit(ORIGIN_SPELL, "", "Thunderstorm"), 100));
		EXPECT_TRUE(CripplingAura::qualifies(hit(ORIGIN_MELEE), 100));
		EXPECT_TRUE(CripplingAura::qualifies(hit(ORIGIN_RANGED), 100));
		EXPECT_TRUE(CripplingAura::qualifies(hit(ORIGIN_FIST), 100));
	}

	TEST_F(CripplingAuraTest, AHitThatTookNoHealthDoesNotQualify) {
		// Dodged, blocked, cancelled or immune: the hit resolved to nothing.
		EXPECT_FALSE(CripplingAura::qualifies(hit(ORIGIN_SPELL, "Energy Strike"), 0));
		EXPECT_FALSE(CripplingAura::qualifies(hit(ORIGIN_MELEE), 0));
	}

	TEST_F(CripplingAuraTest, ConditionTicksReflectionsAndUnnamedSpellDamageDoNotQualify) {
		EXPECT_FALSE(CripplingAura::qualifies(hit(ORIGIN_CONDITION), 100)) << "a DoT tick";
		EXPECT_FALSE(CripplingAura::qualifies(hit(ORIGIN_NONE), 100)) << "environment / script damage";

		auto reflected = hit(ORIGIN_MELEE);
		reflected.extension = true;
		EXPECT_FALSE(CripplingAura::qualifies(reflected, 100)) << "reflection, leech and charm damage are extensions";

		EXPECT_FALSE(CripplingAura::qualifies(hit(ORIGIN_SPELL), 100)) << "ORIGIN_SPELL with no spell behind it";
	}

	TEST_F(CripplingAuraTest, SappedStrengthIsMinusTenPercentDamageDealtAndRefreshesWithoutStacking) {
		auto target = std::make_shared<Player>();
		ASSERT_EQ(100, target->getBuff(BUFF_DAMAGEDEALT));

		ASSERT_TRUE(target->addCondition(CripplingAura::sappedStrength()));
		EXPECT_EQ(90, target->getBuff(BUFF_DAMAGEDEALT));

		const auto &held = target->getCondition(CONDITION_ATTRIBUTES, CONDITIONID_DEFAULT, magic_enum::enum_integer(AttrSubId_t::DebuffSappedStrength));
		ASSERT_NE(nullptr, held);
		held->setTicks(3000); // some of it has run out

		ASSERT_TRUE(target->addCondition(CripplingAura::sappedStrength()));
		EXPECT_EQ(90, target->getBuff(BUFF_DAMAGEDEALT)) << "a second landed hit refreshes, never stacks";
		EXPECT_EQ(CripplingAura::SAPPED_STRENGTH_DURATION_MS, held->getTicks()) << "and the duration starts over";

		target->removeCondition(held);
		EXPECT_EQ(100, target->getBuff(BUFF_DAMAGEDEALT));
	}

	TEST_F(CripplingAuraTest, ExposedWeaknessIsEightPercentPierceAndRefreshesWithoutStacking) {
		auto target = std::make_shared<Player>();
		ASSERT_TRUE(target->addCondition(CripplingAura::exposedWeakness()));
		EXPECT_EQ(8, target->getElementalPierceReceived());

		ASSERT_TRUE(target->addCondition(CripplingAura::exposedWeakness()));
		EXPECT_EQ(8, target->getElementalPierceReceived()) << "refreshed, not doubled";

		const auto &held = target->getCondition(CONDITION_ATTRIBUTES, CONDITIONID_DEFAULT, magic_enum::enum_integer(AttrSubId_t::DebuffExposedWeakness));
		ASSERT_NE(nullptr, held);
		EXPECT_EQ(CripplingAura::EXPOSED_WEAKNESS_DURATION_MS, held->getTicks());
		target->removeCondition(held);
		EXPECT_EQ(0, target->getElementalPierceReceived());
	}

	TEST_F(CripplingAuraTest, TheTwoDebuffsHaveTheirOwnSubIdsSoOneNeverEvictsTheOther) {
		auto target = std::make_shared<Player>();
		ASSERT_TRUE(target->addCondition(CripplingAura::sappedStrength()));
		ASSERT_TRUE(target->addCondition(CripplingAura::exposedWeakness()));
		EXPECT_EQ(90, target->getBuff(BUFF_DAMAGEDEALT));
		EXPECT_EQ(8, target->getElementalPierceReceived());
	}

	TEST_F(CripplingAuraTest, ApplyRefusesPlayersAndSummonsAndUnqualifiedHits) {
		// The debuff is for masterless monsters only. A player target, whatever the
		// hit, gets nothing - and neither does anything from a hit that did not land.
		auto sorcerer = sorcererWith(AttrSubId_t::StanceSappedStrength);
		auto otherPlayer = std::make_shared<Player>();
		EXPECT_FALSE(CripplingAura::apply(sorcerer, otherPlayer, hit(ORIGIN_SPELL, "Energy Strike"), 100));
		EXPECT_EQ(100, otherPlayer->getBuff(BUFF_DAMAGEDEALT));

		EXPECT_FALSE(CripplingAura::apply(sorcerer, otherPlayer, hit(ORIGIN_SPELL, "Energy Strike"), 0));
		EXPECT_FALSE(CripplingAura::apply(nullptr, otherPlayer, hit(ORIGIN_MELEE), 100));
		EXPECT_FALSE(CripplingAura::apply(sorcerer, nullptr, hit(ORIGIN_MELEE), 100));
	}

}
