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
#include "creatures/players/components/weapon_proficiency.hpp"
#include "creatures/players/player.hpp"
#include "enums/weapon_proficiency.hpp"
#include "utils/tools.hpp"

namespace {

	// Elemental Pierce has one home, Creature::applyAbsorbDamageModifications, and
	// two sources: the attacker's weapon proficiency stat and the Exposed Weakness
	// debuff on the target. These tests walk the resistance boundaries.
	class ElementalPierceTest : public ::testing::Test {
	protected:
		void SetUp() override {
			UPDATE_OTSYS_TIME();
		}

		static int32_t hitFor(const std::shared_ptr<Creature> &target, const std::shared_ptr<Creature> &attacker, CombatType_t type, int32_t damage = 100) {
			target->applyAbsorbDamageModifications(attacker, damage, type);
			return damage;
		}

		static std::shared_ptr<Player> attackerWithPierce(double fraction) {
			auto attacker = std::make_shared<Player>();
			attacker->weaponProficiency().addStat(WeaponProficiencyBonus_t::ELEMENTAL_PIERCE, fraction);
			return attacker;
		}

		static std::shared_ptr<Player> targetAbsorbing(CombatType_t type, int32_t percent) {
			auto target = std::make_shared<Player>();
			target->setAbsorbPercent(type, percent);
			return target;
		}
	};

	TEST_F(ElementalPierceTest, A_NeutralResistanceIsUntouched) {
		auto target = std::make_shared<Player>();
		ASSERT_TRUE(target->addCondition(CripplingAura::exposedWeakness()));
		EXPECT_EQ(100, hitFor(target, attackerWithPierce(0.05), COMBAT_FIREDAMAGE)) << "nothing to pierce";
	}

	TEST_F(ElementalPierceTest, B_NormalResistanceIsLoweredByThePierce) {
		auto target = targetAbsorbing(COMBAT_FIREDAMAGE, 30);
		EXPECT_EQ(70, hitFor(target, nullptr, COMBAT_FIREDAMAGE)) << "30% absorbed";
		ASSERT_TRUE(target->addCondition(CripplingAura::exposedWeakness()));
		EXPECT_EQ(78, hitFor(target, nullptr, COMBAT_FIREDAMAGE)) << "30 - 8 = 22% absorbed";
	}

	TEST_F(ElementalPierceTest, C_NearImmunityStillYields) {
		auto target = targetAbsorbing(COMBAT_FIREDAMAGE, 95);
		ASSERT_TRUE(target->addCondition(CripplingAura::exposedWeakness()));
		EXPECT_EQ(13, hitFor(target, nullptr, COMBAT_FIREDAMAGE)) << "95 - 8 = 87% absorbed";
	}

	TEST_F(ElementalPierceTest, D_CompleteImmunityIsNeverTurnedIntoDamage) {
		auto target = targetAbsorbing(COMBAT_FIREDAMAGE, 100);
		ASSERT_TRUE(target->addCondition(CripplingAura::exposedWeakness()));
		EXPECT_EQ(0, hitFor(target, attackerWithPierce(0.5), COMBAT_FIREDAMAGE));
	}

	TEST_F(ElementalPierceTest, E_AVulnerabilityIsNotMadeWorse) {
		// Negative absorb is a weakness (takes more). Pierce lowers resistances only.
		auto target = targetAbsorbing(COMBAT_FIREDAMAGE, -20);
		EXPECT_EQ(120, hitFor(target, nullptr, COMBAT_FIREDAMAGE));
		ASSERT_TRUE(target->addCondition(CripplingAura::exposedWeakness()));
		EXPECT_EQ(120, hitFor(target, attackerWithPierce(0.05), COMBAT_FIREDAMAGE));
	}

	TEST_F(ElementalPierceTest, F_WeaponProficiencyPierceAlone) {
		auto target = targetAbsorbing(COMBAT_ICEDAMAGE, 30);
		EXPECT_EQ(75, hitFor(target, attackerWithPierce(0.05), COMBAT_ICEDAMAGE)) << "30 - 5 = 25% absorbed";
	}

	TEST_F(ElementalPierceTest, G_ExposedWeaknessAlone) {
		auto target = targetAbsorbing(COMBAT_ICEDAMAGE, 30);
		ASSERT_TRUE(target->addCondition(CripplingAura::exposedWeakness()));
		EXPECT_EQ(78, hitFor(target, std::make_shared<Player>(), COMBAT_ICEDAMAGE));
	}

	TEST_F(ElementalPierceTest, H_BothSourcesAddUp) {
		auto target = targetAbsorbing(COMBAT_ICEDAMAGE, 30);
		ASSERT_TRUE(target->addCondition(CripplingAura::exposedWeakness()));
		EXPECT_EQ(83, hitFor(target, attackerWithPierce(0.05), COMBAT_ICEDAMAGE)) << "30 - 8 - 5 = 17% absorbed";
	}

	TEST_F(ElementalPierceTest, I_TheDebuffComingOffRestoresTheResistance) {
		auto target = targetAbsorbing(COMBAT_ICEDAMAGE, 30);
		auto debuff = CripplingAura::exposedWeakness();
		ASSERT_TRUE(target->addCondition(debuff));
		EXPECT_EQ(78, hitFor(target, nullptr, COMBAT_ICEDAMAGE));
		target->removeCondition(debuff);
		EXPECT_EQ(70, hitFor(target, nullptr, COMBAT_ICEDAMAGE));
	}

	TEST_F(ElementalPierceTest, J_PhysicalDamageGetsNoGenericEightPercent) {
		auto target = targetAbsorbing(COMBAT_PHYSICALDAMAGE, 30);
		ASSERT_TRUE(target->addCondition(CripplingAura::exposedWeakness()));
		EXPECT_EQ(70, hitFor(target, attackerWithPierce(0.05), COMBAT_PHYSICALDAMAGE));
	}

	TEST_F(ElementalPierceTest, K_PierceOnlyMeetsTheResistanceOfTheElementHit) {
		// Fire resistance and an ice hit: there is no fire resistance in the way of
		// ice damage, so the pierce has nothing to lower and the hit is whole.
		auto target = targetAbsorbing(COMBAT_FIREDAMAGE, 30);
		ASSERT_TRUE(target->addCondition(CripplingAura::exposedWeakness()));
		EXPECT_EQ(100, hitFor(target, attackerWithPierce(0.05), COMBAT_ICEDAMAGE));
		EXPECT_EQ(83, hitFor(target, attackerWithPierce(0.05), COMBAT_FIREDAMAGE));
	}

	TEST_F(ElementalPierceTest, HealingAndTheDrainsAreNeverPierced) {
		auto target = std::make_shared<Player>();
		ASSERT_TRUE(target->addCondition(CripplingAura::exposedWeakness()));
		EXPECT_EQ(100, hitFor(target, attackerWithPierce(0.5), COMBAT_HEALING));
	}

}
