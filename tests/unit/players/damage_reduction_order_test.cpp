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

	// FIDELITY_BLOCKER - DAMAGE_REDUCTION_PIPELINE_ORDER.
	//
	// Every resistance belongs before armor and mitigation. An item's absorb percentage,
	// its imbuements and the Wheel's resistance used to run dead last, in
	// Player::blockHit, after armor had already subtracted and mitigation had already
	// scaled.
	//
	// A percentage before a flat subtraction is worth more than the same percentage
	// after it, so the two orders give different numbers. The armor roll is random
	// (uniform_random(armor/2, armor - (armor%2 + 1))), which would normally make this
	// untestable - but with 1000 damage, 100 armor and a 70% absorb the two orders land
	// in disjoint ranges:
	//
	//   resistance then armor (correct):  1000 -> 300, minus [50, 99]  =>  [201, 250]
	//   armor then resistance (old):      1000 - [50, 99] -> 70% off   =>  [270, 285]
	//
	// So an upper bound of 250 is a deterministic assertion that the resistance ran
	// first, whatever the roll.
	class DamageReductionOrderTest : public ::testing::Test {
	protected:
		static constexpr uint16_t kArmorId = 64920;
		static constexpr uint16_t kAbsorbId = 64921;

		static constexpr int32_t kArmor = 100;
		static constexpr int16_t kFireAbsorbPercent = 70;
		static constexpr int32_t kIncomingDamage = 1000;

		static void SetUpTestSuite() {
			previousTestContainer = DI::getTestContainer();
			InMemoryLogger::install(injector);
			DI::setTestContainer(&injector);

			auto &items = Item::items.getItems();
			originalItemsSize = items.size();
			if (items.size() <= kAbsorbId) {
				items.resize(kAbsorbId + 1);
			}

			auto &armor = items[kArmorId];
			armor = ItemType {};
			armor.id = kArmorId;
			armor.name = "test plate";
			armor.armor = kArmor;

			// Carried in the backpack slot on purpose: it must contribute a resistance
			// and nothing else. A weapon or shield slot would also feed getDefense, and
			// an armour slot would feed getArmor, either of which would blur the two
			// layers this test is trying to separate.
			auto &absorb = items[kAbsorbId];
			absorb = ItemType {};
			absorb.id = kAbsorbId;
			absorb.name = "test warding charm";
			absorb.getAbilities().absorbPercent[combatTypeToIndex(COMBAT_FIREDAMAGE)] = kFireAbsorbPercent;
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

		static std::shared_ptr<Player> defender(bool withAbsorb) {
			auto player = std::make_shared<Player>();
			auto vocation = std::make_shared<Vocation>(0);
			vocation->armorMultiplier = 1.0f;
			// Mitigation is the layer after armor; zero it so it cannot perturb the two
			// layers under test. Its own ordering is covered by the mitigation suite.
			//
			// It is the PROFILE that has to be zeroed, not the three legacy floats:
			// PlayerWheel::calculateMitigation reads vocation->mitigation, which is its
			// own member and is not derived from them. With the profile left alone a
			// bare player still has a base Shielding, so mitigation came out at about
			// 0.1% - too small to move the ranges below, but not zero.
			vocation->mitigation.skillFactor = 0.0f;
			player->setTestVocation(vocation);

			player->setTestInventoryItem(CONST_SLOT_ARMOR, Item::CreateItem(kArmorId, 1));
			player->setItemAbility(CONST_SLOT_ARMOR, true);

			if (withAbsorb) {
				player->setTestInventoryItem(CONST_SLOT_BACKPACK, Item::CreateItem(kAbsorbId, 1));
				player->setItemAbility(CONST_SLOT_BACKPACK, true);
			}

			return player;
		}

		static int32_t takeFireHit(const std::shared_ptr<Player> &player, BlockType_t* blockTypeOut = nullptr) {
			int32_t damage = kIncomingDamage;
			const BlockType_t blockType = player->blockHit(nullptr, COMBAT_FIREDAMAGE, damage, false, true, false);
			if (blockTypeOut != nullptr) {
				*blockTypeOut = blockType;
			}
			return damage;
		}

		inline static di::extension::injector<> injector {};
		inline static di::extension::injector<>* previousTestContainer = nullptr;
		inline static size_t originalItemsSize = 0;
	};

	// --- The premises this test rests on -------------------------------------------

	TEST_F(DamageReductionOrderTest, TheFixtureGivesTheArmorAndNothingElse) {
		auto player = defender(false);
		ASSERT_EQ(kArmor, player->getArmor()) << "the armour slot must be the only armour";
		ASSERT_FLOAT_EQ(0.0f, player->getMitigation()) << "mitigation must not perturb the two layers under test";
	}

	TEST_F(DamageReductionOrderTest, WithoutAResistanceOnlyTheArmorRollApplies) {
		// The control: 1000 damage less a roll of [50, 99].
		auto player = defender(false);
		const int32_t taken = takeFireHit(player);
		EXPECT_GE(taken, 901);
		EXPECT_LE(taken, 950);
	}

	// --- The order ------------------------------------------------------------------

	TEST_F(DamageReductionOrderTest, TheResistanceAppliesBeforeTheArmor) {
		auto player = defender(true);
		const int32_t taken = takeFireHit(player);

		EXPECT_GE(taken, 201) << "the resistance cannot take more than 70%";
		EXPECT_LE(taken, 250) << "the old order could never land below 270";
	}

	TEST_F(DamageReductionOrderTest, TheOldOrdersRangeIsNeverReached) {
		// Stated as its own assertion so the regression is named rather than implied:
		// armor-then-resistance bottoms out at 270, and nothing may land there.
		for (int attempt = 0; attempt < 64; ++attempt) {
			auto player = defender(true);
			const int32_t taken = takeFireHit(player);
			ASSERT_LT(taken, 270) << "attempt " << attempt << " landed in the old order's range";
		}
	}

	TEST_F(DamageReductionOrderTest, TheResistanceIsWorthMoreThanItUsedToBe) {
		// The point of the fix, as a comparison rather than a constant: the same
		// resistance against the same armour now removes more damage than the old order
		// could, because it acts on the full hit.
		int32_t bestWithResistance = kIncomingDamage;
		int32_t worstWithoutResistance = 0;
		for (int attempt = 0; attempt < 32; ++attempt) {
			bestWithResistance = std::min(bestWithResistance, takeFireHit(defender(true)));
			worstWithoutResistance = std::max(worstWithoutResistance, takeFireHit(defender(false)));
		}

		EXPECT_LT(bestWithResistance, worstWithoutResistance);
		EXPECT_LE(bestWithResistance, 250);
	}

	// --- What the attacker is told ---------------------------------------------------

	TEST_F(DamageReductionOrderTest, AFullyAbsorbedHitReportsABlock) {
		// A resistance that takes the whole hit reports BLOCK_ARMOR, which is the value
		// Player::blockHit already returned for this case before the move. The
		// difference is that the attacker's onAttackedCreatureBlockHit now sees it too;
		// it used to be told BLOCK_NONE while the caller was told BLOCK_ARMOR.
		auto player = defender(true);
		int32_t damage = 1; // 70% of 1 rounds to 1, so the absorb takes all of it
		const BlockType_t blockType = player->blockHit(nullptr, COMBAT_FIREDAMAGE, damage, false, true, false);

		EXPECT_EQ(0, damage);
		EXPECT_EQ(BLOCK_ARMOR, blockType);
	}

	TEST_F(DamageReductionOrderTest, AnUnabsorbedTypeIsUntouchedByTheResistance) {
		// The absorb is fire only. An ice hit of the same size must look exactly like
		// the no-resistance control.
		auto player = defender(true);
		int32_t damage = kIncomingDamage;
		player->blockHit(nullptr, COMBAT_ICEDAMAGE, damage, false, true, false);

		EXPECT_GE(damage, 901);
		EXPECT_LE(damage, 950);
	}
}
