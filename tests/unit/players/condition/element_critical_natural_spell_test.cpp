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

	// Master of Thunder (+4% critical chance on energy spells) and Master of Decay
	// (+30% critical extra damage on death spells) grant their bonus to SPELLS whose
	// NATURAL element is the stance's. The rule is Player::applyConditionElementCritical;
	// these tests pin every source it must refuse.
	class ElementCriticalNaturalSpellTest : public ::testing::Test {
	protected:
		void SetUp() override {
			UPDATE_OTSYS_TIME();
		}

		static std::shared_ptr<Player> thunderAndDecay() {
			auto player = std::make_shared<Player>();
			player->setVarElementCritical(COMBAT_ENERGYDAMAGE, 400, 0);
			player->setVarElementCritical(COMBAT_DEATHDAMAGE, 0, 3000);
			return player;
		}

		// A damage packet as Combat::getCombatDamage builds it: naturalPrimaryType is
		// the element before conversion, primary.type the element after.
		static CombatDamage packet(CombatType_t natural, CombatType_t final, const std::string &instant = "", const std::string &rune = "") {
			CombatDamage damage;
			damage.origin = ORIGIN_SPELL;
			damage.naturalPrimaryType = natural;
			damage.primary.type = final;
			damage.primary.value = 100;
			damage.instantSpellName = instant;
			damage.runeSpellName = rune;
			return damage;
		}
	};

	TEST_F(ElementCriticalNaturalSpellTest, NaturalEnergySpellUnderThunderGetsTheChance) {
		auto damage = packet(COMBAT_ENERGYDAMAGE, COMBAT_ENERGYDAMAGE, "Energy Strike");
		thunderAndDecay()->applyConditionElementCritical(damage);
		EXPECT_EQ(400, damage.criticalChance);
		EXPECT_EQ(0, damage.criticalDamage);
	}

	TEST_F(ElementCriticalNaturalSpellTest, EnergyRuneUnderThunderGetsNothing) {
		auto damage = packet(COMBAT_ENERGYDAMAGE, COMBAT_ENERGYDAMAGE, "", "Thunderstorm");
		thunderAndDecay()->applyConditionElementCritical(damage);
		EXPECT_EQ(0, damage.criticalChance) << "a rune is not a spell of the stance";
	}

	TEST_F(ElementCriticalNaturalSpellTest, EnergyAutoAttackOrWandGetsNothing) {
		// A wand hit or an auto attack is built outside getCombatDamage: no spell name
		// and no natural type recorded.
		CombatDamage damage;
		damage.origin = ORIGIN_RANGED;
		damage.primary.type = COMBAT_ENERGYDAMAGE;
		damage.primary.value = 100;
		thunderAndDecay()->applyConditionElementCritical(damage);
		EXPECT_EQ(0, damage.criticalChance);

		// Even with a natural type recorded, no instant spell name means no bonus.
		auto named = packet(COMBAT_ENERGYDAMAGE, COMBAT_ENERGYDAMAGE);
		thunderAndDecay()->applyConditionElementCritical(named);
		EXPECT_EQ(0, named.criticalChance);
	}

	TEST_F(ElementCriticalNaturalSpellTest, FireSpellConvertedToEnergyGetsNoEnergyBonus) {
		// Master of Thunder's own conversion turned a fire spell into energy damage.
		// Its natural element is still fire, so the natural-energy bonus is refused.
		auto damage = packet(COMBAT_FIREDAMAGE, COMBAT_ENERGYDAMAGE, "Flame Strike");
		thunderAndDecay()->applyConditionElementCritical(damage);
		EXPECT_EQ(0, damage.criticalChance);
	}

	TEST_F(ElementCriticalNaturalSpellTest, NaturalEnergySpellConvertedElsewhereStillCountsAsEnergy) {
		// The judgement is on the natural element, not the final one.
		auto damage = packet(COMBAT_ENERGYDAMAGE, COMBAT_DEATHDAMAGE, "Energy Strike");
		thunderAndDecay()->applyConditionElementCritical(damage);
		EXPECT_EQ(400, damage.criticalChance);
		EXPECT_EQ(0, damage.criticalDamage) << "and it is not a natural death spell";
	}

	TEST_F(ElementCriticalNaturalSpellTest, NaturalDeathSpellUnderDecayGetsTheExtraDamage) {
		auto damage = packet(COMBAT_DEATHDAMAGE, COMBAT_DEATHDAMAGE, "Death Strike");
		thunderAndDecay()->applyConditionElementCritical(damage);
		EXPECT_EQ(3000, damage.criticalDamage);
		EXPECT_EQ(0, damage.criticalChance);
	}

	TEST_F(ElementCriticalNaturalSpellTest, DeathRuneUnderDecayGetsNothing) {
		auto damage = packet(COMBAT_DEATHDAMAGE, COMBAT_DEATHDAMAGE, "", "Sudden Death");
		thunderAndDecay()->applyConditionElementCritical(damage);
		EXPECT_EQ(0, damage.criticalDamage);
	}

	TEST_F(ElementCriticalNaturalSpellTest, EnergySpellConvertedToDeathGetsNoDeathBonus) {
		auto damage = packet(COMBAT_ENERGYDAMAGE, COMBAT_DEATHDAMAGE, "Energy Strike");
		thunderAndDecay()->applyConditionElementCritical(damage);
		EXPECT_EQ(0, damage.criticalDamage);
	}

	TEST_F(ElementCriticalNaturalSpellTest, TheStanceConditionFeedsTheSameRule) {
		// End to end through the condition: Master of Thunder's parameter lands on the
		// player, and only a natural energy instant spell reads it.
		auto condition = Condition::createCondition(CONDITIONID_COMBAT, CONDITION_ATTRIBUTES, -1, 0, false, magic_enum::enum_integer(AttrSubId_t::StanceMasterOfThunder), true);
		ASSERT_NE(nullptr, condition);
		ASSERT_TRUE(condition->setParam(CONDITION_PARAM_ELEMENT_CRITICAL_CHANCE_ENERGY, 400));

		auto player = std::make_shared<Player>();
		ASSERT_TRUE(player->addCondition(condition));

		auto spell = packet(COMBAT_ENERGYDAMAGE, COMBAT_ENERGYDAMAGE, "Energy Strike");
		player->applyConditionElementCritical(spell);
		EXPECT_EQ(400, spell.criticalChance);

		auto rune = packet(COMBAT_ENERGYDAMAGE, COMBAT_ENERGYDAMAGE, "", "Thunderstorm");
		player->applyConditionElementCritical(rune);
		EXPECT_EQ(0, rune.criticalChance);

		player->removeCondition(condition);
		auto after = packet(COMBAT_ENERGYDAMAGE, COMBAT_ENERGYDAMAGE, "Energy Strike");
		player->applyConditionElementCritical(after);
		EXPECT_EQ(0, after.criticalChance) << "the stance coming off takes its bonus with it";
	}

}
