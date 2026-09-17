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

#include "creatures/combat/effective_combat_values.hpp"

namespace {

	// The 15.25 global compensation as arithmetic: what each raw value becomes, what
	// each kind of off-hand item gets, and where the single rounding point lands.
	// Player::getEffective* is this table plus "which model is the player on";
	// combat_tactics_test covers that half.
	using namespace EffectiveCombatValues;

	ItemType itemOf(WeaponType_t weaponType, ItemTypes_t type, bool spellbook) {
		ItemType itemType {};
		itemType.weaponType = weaponType;
		itemType.type = type;
		itemType.spellbook = spellbook;
		return itemType;
	}

	TEST(EffectiveCombatValuesTest, WeaponAttackIsTwentyPercentHigher) {
		EXPECT_DOUBLE_EQ(120.0, weaponAttack(100));
		EXPECT_DOUBLE_EQ(60.0, weaponAttack(50));
		EXPECT_DOUBLE_EQ(1.2, weaponAttack(1));
	}

	TEST(EffectiveCombatValuesTest, ShieldDefenseIsThirtyPercentHigher) {
		EXPECT_DOUBLE_EQ(130.0, shieldDefense(100));
		EXPECT_DOUBLE_EQ(33.8, shieldDefense(26)); // a dwarven shield
	}

	TEST(EffectiveCombatValuesTest, SpellbookDefenseIsSixtyPercentHigher) {
		EXPECT_DOUBLE_EQ(160.0, spellbookDefense(100));
		EXPECT_DOUBLE_EQ(22.4, spellbookDefense(14)); // the plain spellbook
	}

	TEST(EffectiveCombatValuesTest, TheThreePercentagesAreDistinct) {
		// The whole point of three constants: the same raw value is worth three
		// different things depending on what the item is.
		EXPECT_NE(weaponAttack(100), shieldDefense(100));
		EXPECT_NE(shieldDefense(100), spellbookDefense(100));
		EXPECT_NE(weaponAttack(100), spellbookDefense(100));
	}

	TEST(EffectiveCombatValuesTest, FractionsAreKept) {
		// 33 x 1.3 is 42.9, not 42 and not 43: the fraction survives to whatever
		// formula consumes it, and only that formula's own rounding applies.
		EXPECT_DOUBLE_EQ(42.9, shieldDefense(33));
		EXPECT_DOUBLE_EQ(11.2, spellbookDefense(7));
		EXPECT_DOUBLE_EQ(40.8, weaponAttack(34));
	}

	TEST(EffectiveCombatValuesTest, NothingAtOrBelowZeroIsScaled) {
		EXPECT_DOUBLE_EQ(0.0, weaponAttack(0));
		EXPECT_DOUBLE_EQ(0.0, shieldDefense(0));
		EXPECT_DOUBLE_EQ(0.0, spellbookDefense(0));
		EXPECT_DOUBLE_EQ(-5.0, weaponAttack(-5)) << "a negative raw value is left exactly as it is";
	}

	TEST(EffectiveCombatValuesTest, AShieldIsAShieldAndASpellbookIsNot) {
		EXPECT_EQ(OffhandKind::Shield, classify(itemOf(WEAPON_SHIELD, ITEM_TYPE_SHIELD, false)));
		// Every spellbook in items.xml carries weaponType="spellbook", which the parser
		// maps to WEAPON_SHIELD and flags; the flag is what tells the two apart.
		EXPECT_EQ(OffhandKind::Spellbook, classify(itemOf(WEAPON_SHIELD, ITEM_TYPE_SHIELD, true)));
		EXPECT_EQ(OffhandKind::Other, classify(itemOf(WEAPON_SWORD, ITEM_TYPE_SWORD, false)));
		EXPECT_EQ(OffhandKind::Other, classify(itemOf(WEAPON_NONE, ITEM_TYPE_NONE, false))) << "a quiver or a bag is neither";
	}

	TEST(EffectiveCombatValuesTest, EachOffhandKindGetsItsOwnPercentageAndNoOther) {
		EXPECT_DOUBLE_EQ(130.0, offhandDefense(OffhandKind::Shield, 100));
		EXPECT_DOUBLE_EQ(160.0, offhandDefense(OffhandKind::Spellbook, 100));
		EXPECT_DOUBLE_EQ(100.0, offhandDefense(OffhandKind::Other, 100)) << "an ordinary off-hand item is untouched";
		EXPECT_DOUBLE_EQ(0.0, offhandDefense(OffhandKind::None, 100));
	}

	TEST(EffectiveCombatValuesTest, ApplyingTheCompensationTwiceIsVisiblyWrong) {
		// Pins the failure mode the central layer exists to prevent, so a second
		// multiplication anywhere downstream cannot look like the right answer.
		EXPECT_DOUBLE_EQ(130.0, shieldDefense(100));
		EXPECT_DOUBLE_EQ(169.0, shieldDefense(static_cast<int32_t>(shieldDefense(100))));
		EXPECT_NE(shieldDefense(100), shieldDefense(static_cast<int32_t>(shieldDefense(100))));
	}

	TEST(EffectiveCombatValuesTest, TheRoundingPointIsHalfAwayFromZero) {
		EXPECT_EQ(43, toInteger(42.9));
		EXPECT_EQ(42, toInteger(42.4));
		EXPECT_EQ(43, toInteger(42.5));
		EXPECT_EQ(0, toInteger(0.0));
		EXPECT_EQ(-43, toInteger(-42.5));
		EXPECT_EQ(34, toInteger(shieldDefense(26))); // 33.8
		EXPECT_EQ(22, toInteger(spellbookDefense(14))); // 22.4
	}

}
