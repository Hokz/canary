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

#include "creatures/players/player.hpp"
#include "creatures/players/vocations/vocation.hpp"
#include "items/item.hpp"
#include "lib/logging/in_memory_logger.hpp"
#include "utils/tools.hpp"

namespace {

	// The two post-July Knight Wheel reworks.
	//
	// Battle Healing's Shielding multiplier is 2, up from 0.2 - at any realistic
	// Shielding the old value was worth a handful of hit points a tick. The two
	// low-health tiers are unchanged.
	//
	// Combat Mastery's two-handed critical damage is 10 / 12 / 14 percent by stage,
	// replacing 4 / 8 / 12, so stage 1 gains the most and the stages sit closer
	// together. The one-handed Defence branch is untouched.
	class KnightWheelReworkTest : public ::testing::Test {
	protected:
		static constexpr uint16_t kTwoHanderId = 64910;
		static constexpr uint16_t kOneHanderId = 64911;

		static void SetUpTestSuite() {
			previousTestContainer = DI::getTestContainer();
			InMemoryLogger::install(injector);
			DI::setTestContainer(&injector);

			auto &items = Item::items.getItems();
			originalItemsSize = items.size();
			if (items.size() <= kOneHanderId) {
				items.resize(kOneHanderId + 1);
			}

			auto &twoHander = items[kTwoHanderId];
			twoHander = ItemType {};
			twoHander.id = kTwoHanderId;
			twoHander.name = "test two-hander";
			twoHander.weaponType = WEAPON_SWORD;
			twoHander.type = ITEM_TYPE_SWORD;
			twoHander.attack = 100;
			twoHander.slotPosition = SLOTP_TWO_HAND;

			auto &oneHander = items[kOneHanderId];
			oneHander = ItemType {};
			oneHander.id = kOneHanderId;
			oneHander.name = "test one-hander";
			oneHander.weaponType = WEAPON_SWORD;
			oneHander.type = ITEM_TYPE_SWORD;
			oneHander.attack = 100;
			oneHander.slotPosition = SLOTP_LEFT;
		}

		static void TearDownTestSuite() {
			auto &items = Item::items.getItems();
			if (items.size() > originalItemsSize) {
				items.resize(originalItemsSize);
			}
			DI::setTestContainer(previousTestContainer);
		}

		void SetUp() override {
			UPDATE_OTSYS_TIME();
		}

		static std::shared_ptr<Player> knight() {
			auto player = std::make_shared<Player>();
			auto vocation = std::make_shared<Vocation>(0);
			player->setTestVocation(vocation);
			return player;
		}

		static void equip(const std::shared_ptr<Player> &player, uint16_t itemId) {
			const auto item = Item::CreateItem(itemId, 1);
			EXPECT_NE(nullptr, item);
			player->setTestInventoryItem(CONST_SLOT_LEFT, item);
		}

		// A player's current health stays where it is while maximum health is raised
		// through the Wheel, which is how a given health percentage is reached here
		// without a game running to take damage through.
		static void setHealthPercent(const std::shared_ptr<Player> &player, int32_t percent) {
			const int32_t current = player->getHealth();
			const int32_t wanted = (current * 100) / percent;
			player->wheel().addStat(WheelStat_t::HEALTH, wanted - player->getMaxHealth());
		}

		inline static di::extension::injector<> injector {};
		inline static di::extension::injector<>* previousTestContainer = nullptr;
		inline static size_t originalItemsSize = 0;
	};

	// --- Battle Healing -----------------------------------------------------------

	// The assertions below read the Shielding the player actually has rather than
	// assuming it. Player::getLoyaltySkill takes a different branch depending on
	// whether a vocation is set (player.cpp:1218), so a fixture's baseline skill is not
	// something to hard-code. What matters is the coefficient, and that is what these
	// pin: the amount is twice the Shielding, whatever the Shielding is.

	TEST_F(KnightWheelReworkTest, BattleHealingMultipliesShieldingByTwo) {
		auto player = knight();
		player->setVarSkill(SKILL_SHIELD, 100);
		const int32_t shielding = player->getSkillLevel(SKILL_SHIELD);
		ASSERT_GT(shielding, 0) << "the fixture must give the player some Shielding";
		ASSERT_EQ(100, (player->getHealth() * 100) / player->getMaxHealth()) << "at full health, no tier applies";

		EXPECT_EQ(shielding * 2, player->wheel().checkBattleHealingAmount());
	}

	TEST_F(KnightWheelReworkTest, TheCoefficientIsTwoAndNotTwoTenths) {
		// The rework in one assertion: the old multiplier was 0.2, and at any Shielding
		// worth having the two answers are an order of magnitude apart.
		auto player = knight();
		player->setVarSkill(SKILL_SHIELD, 100);
		const int32_t shielding = player->getSkillLevel(SKILL_SHIELD);
		const int32_t amount = player->wheel().checkBattleHealingAmount();

		EXPECT_EQ(shielding * 2, amount);
		EXPECT_NE(static_cast<int32_t>(shielding * 0.2), amount) << "the old coefficient must be gone";
	}

	TEST_F(KnightWheelReworkTest, BattleHealingScalesLinearlyWithShielding) {
		int32_t previous = -1;
		for (const int32_t bonus : { 0, 1, 50, 137 }) {
			auto player = knight();
			player->setVarSkill(SKILL_SHIELD, bonus);
			const int32_t shielding = player->getSkillLevel(SKILL_SHIELD);
			const int32_t amount = player->wheel().checkBattleHealingAmount();

			EXPECT_EQ(shielding * 2, amount) << "bonus " << bonus;
			EXPECT_GT(amount, previous) << "more Shielding must heal more; bonus " << bonus;
			previous = amount;
		}
	}

	TEST_F(KnightWheelReworkTest, TheLowHealthTiersAreUnchanged) {
		// 60% and below doubles, 30% and below triples, both composing on top of the
		// new multiplier rather than replacing it.
		auto full = knight();
		full->setVarSkill(SKILL_SHIELD, 100);
		const int32_t base = full->wheel().checkBattleHealingAmount();
		ASSERT_GT(base, 0);

		auto half = knight();
		half->setVarSkill(SKILL_SHIELD, 100);
		setHealthPercent(half, 50);
		ASSERT_EQ(50, (half->getHealth() * 100) / half->getMaxHealth());
		EXPECT_EQ(base * 2, half->wheel().checkBattleHealingAmount()) << "doubled below 60%";

		auto quarter = knight();
		quarter->setVarSkill(SKILL_SHIELD, 100);
		setHealthPercent(quarter, 25);
		ASSERT_EQ(25, (quarter->getHealth() * 100) / quarter->getMaxHealth());
		EXPECT_EQ(base * 3, quarter->wheel().checkBattleHealingAmount()) << "tripled below 30%";
	}

	TEST_F(KnightWheelReworkTest, TheTierBoundariesAreInclusive) {
		auto full = knight();
		full->setVarSkill(SKILL_SHIELD, 100);
		const int32_t base = full->wheel().checkBattleHealingAmount();

		auto atSixty = knight();
		atSixty->setVarSkill(SKILL_SHIELD, 100);
		setHealthPercent(atSixty, 60);
		EXPECT_EQ(base * 2, atSixty->wheel().checkBattleHealingAmount()) << "exactly 60% already doubles";

		auto atThirty = knight();
		atThirty->setVarSkill(SKILL_SHIELD, 100);
		setHealthPercent(atThirty, 30);
		EXPECT_EQ(base * 3, atThirty->wheel().checkBattleHealingAmount()) << "exactly 30% already triples";
	}

	// --- Combat Mastery -----------------------------------------------------------

	TEST_F(KnightWheelReworkTest, CombatMasteryTwoHandedCriticalIsTenTwelveFourteen) {
		struct Case {
			uint8_t stage;
			int32_t expected;
		};
		for (const auto &[stage, expected] : { Case { 1, 1000 }, Case { 2, 1200 }, Case { 3, 1400 } }) {
			auto player = knight();
			equip(player, kTwoHanderId);
			player->wheel().setStage(WheelStage_t::COMBAT_MASTERY, stage);

			player->wheel().checkCombatMastery();
			EXPECT_EQ(expected, player->wheel().getMajorStat(WheelMajor_t::CRITICAL_DMG_2))
				<< "stage " << static_cast<int>(stage) << " in basis points";
		}
	}

	TEST_F(KnightWheelReworkTest, WithoutTheStageThereIsNoCriticalBonus) {
		auto player = knight();
		equip(player, kTwoHanderId);
		player->wheel().checkCombatMastery();
		EXPECT_EQ(0, player->wheel().getMajorStat(WheelMajor_t::CRITICAL_DMG_2));
	}

	TEST_F(KnightWheelReworkTest, TheStagesAreTwoPercentApartAndAscending) {
		// 4 / 8 / 12 stepped by 4; the rework steps by 2 and starts higher. Asserted as
		// a shape so a half-applied edit is caught even if every value changes.
		std::array<int32_t, 3> values {};
		for (uint8_t stage = 1; stage <= 3; ++stage) {
			auto player = knight();
			equip(player, kTwoHanderId);
			player->wheel().setStage(WheelStage_t::COMBAT_MASTERY, stage);
			player->wheel().checkCombatMastery();
			values[stage - 1] = player->wheel().getMajorStat(WheelMajor_t::CRITICAL_DMG_2);
		}

		EXPECT_LT(values[0], values[1]);
		EXPECT_LT(values[1], values[2]);
		EXPECT_EQ(200, values[1] - values[0]) << "two percent per stage";
		EXPECT_EQ(200, values[2] - values[1]);
		EXPECT_GT(values[0], 400) << "stage 1 is above the old stage 1";
	}

	TEST_F(KnightWheelReworkTest, AOneHandedWeaponTakesTheDefenceBranchInstead) {
		// The rework is the two-handed critical only. A one-hander still gets the
		// Defence grant and no critical damage at all.
		auto player = knight();
		equip(player, kOneHanderId);
		player->wheel().setStage(WheelStage_t::COMBAT_MASTERY, 3);

		player->wheel().checkCombatMastery();
		EXPECT_EQ(0, player->wheel().getMajorStat(WheelMajor_t::CRITICAL_DMG_2)) << "no critical without two hands";
		EXPECT_EQ(30, player->wheel().getMajorStat(WheelMajor_t::DEFENSE)) << "the Defence branch is unchanged";
	}
}
