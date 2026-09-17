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

#include "creatures/combat/mana_shield_absorption.hpp"

namespace {

	// Energy Ring (15.25): 2 mana per hit point, and never a mana spent on a fraction
	// of a hit point. The hit points covered are decided first; the mana follows.
	TEST(ManaShieldAbsorptionTest, EnergyRingAtTwoToOneIsExact) {
		struct Case {
			int32_t mana;
			int32_t absorbed;
			int32_t spent;
		};
		for (const auto &[mana, absorbed, spent] : { Case { 0, 0, 0 }, Case { 1, 0, 0 }, Case { 2, 1, 2 }, Case { 3, 1, 2 }, Case { 5, 2, 4 } }) {
			const auto result = computeManaShieldAbsorption(mana, 10, 2);
			EXPECT_EQ(absorbed, result.healthAbsorbed) << "mana " << mana;
			EXPECT_EQ(spent, result.manaSpent) << "mana " << mana;
			EXPECT_EQ(mana - spent, mana - result.manaSpent) << "the odd mana stays";
		}
	}

	TEST(ManaShieldAbsorptionTest, EnoughManaCoversTheWholeHit) {
		const auto result = computeManaShieldAbsorption(100, 10, 2);
		EXPECT_EQ(10, result.healthAbsorbed);
		EXPECT_EQ(20, result.manaSpent);
	}

	TEST(ManaShieldAbsorptionTest, MagicShieldAtOneToOneIsUnchanged) {
		// The spell's shield: 3 mana covers 3 hit points and costs 3 mana, as before.
		const auto result = computeManaShieldAbsorption(3, 10, 1);
		EXPECT_EQ(3, result.healthAbsorbed);
		EXPECT_EQ(3, result.manaSpent);

		const auto whole = computeManaShieldAbsorption(50, 10, 1);
		EXPECT_EQ(10, whole.healthAbsorbed);
		EXPECT_EQ(10, whole.manaSpent);
	}

	TEST(ManaShieldAbsorptionTest, NothingToAbsorbOrPayWithIsNothing) {
		EXPECT_EQ(0, computeManaShieldAbsorption(10, 0, 2).manaSpent);
		EXPECT_EQ(0, computeManaShieldAbsorption(10, -5, 2).manaSpent);
		EXPECT_EQ(0, computeManaShieldAbsorption(-1, 10, 2).manaSpent);
		EXPECT_EQ(0, computeManaShieldAbsorption(10, 10, 0).healthAbsorbed);
	}

	TEST(ManaShieldAbsorptionTest, AbsorbedHealthComesOffPrimaryThenSecondaryAndNeverBelowZero) {
		CombatDamage damage;
		damage.primary.type = COMBAT_PHYSICALDAMAGE;
		damage.primary.value = 6;
		damage.secondary.type = COMBAT_FIREDAMAGE;
		damage.secondary.value = 5;

		takeAbsorbedHealthOff(damage, 4);
		EXPECT_EQ(2, damage.primary.value);
		EXPECT_EQ(5, damage.secondary.value);

		takeAbsorbedHealthOff(damage, 4);
		EXPECT_EQ(0, damage.primary.value);
		EXPECT_EQ(3, damage.secondary.value) << "2 from the primary, the other 2 from the secondary";

		takeAbsorbedHealthOff(damage, 100);
		EXPECT_EQ(0, damage.primary.value);
		EXPECT_EQ(0, damage.secondary.value);

		takeAbsorbedHealthOff(damage, 0);
		EXPECT_EQ(0, damage.secondary.value);
	}

	TEST(ManaShieldAbsorptionTest, AMixedHitUnderTheEnergyRingIsAccountedCoherently) {
		// 7 mana at 2:1 covers 3 hit points for 6 mana; a 6 + 5 hit becomes 3 + 5.
		CombatDamage damage;
		damage.primary.value = 6;
		damage.secondary.value = 5;
		const auto result = computeManaShieldAbsorption(7, damage.primary.value + damage.secondary.value, 2);
		EXPECT_EQ(3, result.healthAbsorbed);
		EXPECT_EQ(6, result.manaSpent);
		takeAbsorbedHealthOff(damage, result.manaSpent / 2);
		EXPECT_EQ(3, damage.primary.value);
		EXPECT_EQ(5, damage.secondary.value);
		EXPECT_EQ(11 - 3, damage.primary.value + damage.secondary.value);
	}

}
