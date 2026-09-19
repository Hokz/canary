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
#include "creatures/players/grouping/groups.hpp"
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
		static constexpr uint16_t kShieldId = 64922;

		static constexpr int32_t kArmor = 100;
		static constexpr int16_t kFireAbsorbPercent = 70;
		static constexpr int32_t kIncomingDamage = 1000;

		// The resistance-assisted hit. 100 damage is small enough that the armor roll
		// alone - [50, 99] - can never finish it, and large enough that it survives the
		// absorb; 70% off leaves 30, which the same roll always finishes. So the two
		// facts this class rests on are both deterministic: armor could not stop this hit
		// before the reorder, and always stops it after.
		static constexpr int32_t kAssistedDamage = 100;
		// Small enough that armor alone stops it, so nothing about it is resistance-assisted.
		static constexpr int32_t kArmorBlockedDamage = 40;
		// 70% of 1 rounds to 1, so the absorb takes the whole hit by itself.
		static constexpr int32_t kFullyAbsorbedDamage = 1;

		static void SetUpTestSuite() {
			previousTestContainer = DI::getTestContainer();
			InMemoryLogger::install(injector);
			DI::setTestContainer(&injector);

			auto &items = Item::items.getItems();
			originalItemsSize = items.size();
			if (items.size() <= kShieldId) {
				items.resize(kShieldId + 1);
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

			// Only hasShield() needs to be satisfied, so this carries no armor, no
			// defense and no absorb. It sits in CONST_SLOT_LEFT, which Player::getArmor
			// does not read (its slot list is HEAD, NECKLACE, ARMOR, LEGS, FEET, RING,
			// AMMO), so it cannot disturb the ranges the ordering tests assert.
			auto &shield = items[kShieldId];
			shield = ItemType {};
			shield.id = kShieldId;
			shield.name = "test test shield";
			shield.weaponType = WEAPON_SHIELD;
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

			// blockHit's first branch is isImmune, which reaches Player::hasFlag, which
			// dereferences `group` unconditionally (player.cpp:7882). Player::group
			// defaults to nullptr, so a Player that has not been through IOLoginData
			// segfaults the moment anything asks it for a flag. Production always
			// assigns a group, so this is a fixture requirement rather than a missing
			// null check - a null group is an invariant violation, not a state to
			// tolerate. An empty Group is every flag false, which is what a plain
			// character has.
			player->setGroup(std::make_shared<Group>());
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

		// A defender whose Shielding advance can actually be watched. Three things have to
		// hold before onBlockHit() does anything observable, and none of them is true of a
		// freshly built Player:
		//
		//   - blockCount must be non-zero, or blockHit never sets hasDefense. It only ever
		//     accrues in Creature::onThink, so the test hook sets it directly;
		//   - the defender's own shieldBlockCount must be non-zero, which is what
		//     onAttackedCreatureBlockHit(BLOCK_NONE) arranges - it is how the engine itself
		//     opens the thirty-hit window;
		//   - hasShield() must hold, which needs a shield in a hand slot.
		//
		// Then a single advance moves Shielding from 0.00% to 1.00%, because a vocation's
		// shield base is 100 tries for level 11 and a new Player starts at level 10 with
		// zero tries. So a non-zero percent is exactly "onBlockHit() ran".
		static std::shared_ptr<Player> shieldedDefender(bool withAbsorb) {
			auto player = defender(withAbsorb);
			player->setTestInventoryItem(CONST_SLOT_LEFT, Item::CreateItem(kShieldId, 1));
			player->setTestBlockCount(1);
			player->onAttackedCreatureBlockHit(BLOCK_NONE);
			return player;
		}

		// A defender whose mitigation alone finishes any hit that reaches it.
		//
		// With nothing in either hand, PlayerWheel::calculateMitigation reduces to
		// ceil(effectiveShielding * skillFactor) / 100: there is no off-hand and no weapon,
		// so the equipment multiplier is 1.0, and fightFactor is 1.0 because a Player with
		// no client uses the modern combat model. A factor of 10000 / shielding would put
		// mitigation at exactly 100%; this uses twice that, because the test needs
		// mitigation to FINISH the hit and not to sit on a float knife edge at the boundary.
		//
		// The factor is derived from the Shielding the fixture actually has rather than
		// assumed to be the base 10, because getSkillLevel folds in loyalty and var
		// contributions - a lesson from the Battle Healing suite.
		static std::shared_ptr<Player> fullyMitigatedDefender() {
			auto player = defender(true);
			const auto shielding = player->getSkillLevel(SKILL_SHIELD);
			EXPECT_GT(shielding, 0) << "the factor below divides by this";
			player->getVocation()->mitigation.skillFactor = 20000.0f / static_cast<float>(shielding);
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

		// One hit of an explicit size against armor, which is the shape every
		// resistance-assisted assertion below needs.
		static BlockType_t hitFor(const std::shared_ptr<Player> &player, int32_t &damage, bool checkArmor = true) {
			return player->blockHit(nullptr, COMBAT_FIREDAMAGE, damage, false, checkArmor, false);
		}

		inline static di::extension::injector<> injector {};
		inline static di::extension::injector<>* previousTestContainer = nullptr;
		inline static size_t originalItemsSize = 0;
	};

	// --- The premises this test rests on -------------------------------------------

	TEST_F(DamageReductionOrderTest, AMinimalPlayerSurvivesTheWholeChain) {
		// The regression this file was written through. blockHit asks isImmune first,
		// isImmune asks hasFlag, and hasFlag dereferences the player's group. Six tests
		// here segfaulted on that until the fixture assigned one.
		//
		// Kept as its own test so the requirement is named: anything that drives
		// blockHit needs a Player complete enough to answer a flag.
		auto player = defender(true);
		ASSERT_NE(nullptr, player->getGroup()) << "blockHit needs a player that can answer a flag";
		EXPECT_FALSE(player->isImmune(COMBAT_FIREDAMAGE)) << "and an empty group is immune to nothing";

		int32_t damage = kIncomingDamage;
		EXPECT_NO_FATAL_FAILURE(player->blockHit(nullptr, COMBAT_FIREDAMAGE, damage, false, true, false));
		EXPECT_GT(damage, 0) << "a thousand damage does not vanish";
	}

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

	// --- Progression held where it was ----------------------------------------------

	// NOT COVERED, stated rather than faked: blockCount starts at zero on a Player that
	// has not been through IOLoginData, and Creature exposes no getter for it, so the
	// block-consumption path - decrement, hasDefense, onBlockHit, the Shielding advance -
	// is unreachable from this fixture. What the change guarantees is structural: the
	// decrement sits at the same point in blockHit it sat at before the resistances moved
	// ahead of it, and onBlockHit is gated on blockedByDefenceOrArmor so a resistance
	// swallowing the hit cannot trigger it. Proving it needs a Player with a real block
	// count, which is integration territory.

	TEST_F(DamageReductionOrderTest, AReducedHitThatStillLandsReportsNoBlock) {
		// The other side of the resistance-assisted class below. Same gear, same absorb,
		// but at 1000 damage: 70% off leaves 300, which an armor roll of [50, 99] cannot
		// finish. The resistance reduced the hit, armor did not stop it, so it is not a
		// block and nothing about progression changes.
		auto player = defender(true);
		BlockType_t blockType = BLOCK_NONE;
		const int32_t taken = takeFireHit(player, &blockType);

		EXPECT_GT(taken, 0);
		EXPECT_EQ(BLOCK_NONE, blockType) << "a reduced hit that still lands is not a block";
	}

	// --- Resistance-assisted blocks --------------------------------------------------
	//
	// The class this reorder creates: the resistance does NOT take the whole hit, but it
	// takes enough of it that defense or armor then does. Such a hit did not exist before
	// the reorder, because armor was handed the full damage and did not stop it.
	//
	// The contract, stated once here and asserted below:
	//
	//   damage            follows the new order
	//   caller blockType  follows the new order - zero damage means a block
	//   attacker          hears the same thing the caller does, with no special case
	//   Shielding         follows the new order: the layer that really stopped it
	//   item charges      preserved - they ask whether defense or armor would have stopped
	//                     the hit BEFORE the resistances, which is the hit they used to see
	//   blockCount        unchanged

	TEST_F(DamageReductionOrderTest, ArmorAloneCannotStopTheAssistedHit) {
		// The premise that makes the next test's block resistance-assisted rather than an
		// ordinary armor block. Without the absorb, 100 damage against an armor roll of
		// [50, 99] always leaves something standing.
		auto player = defender(false);
		int32_t damage = kAssistedDamage;
		const BlockType_t blockType = hitFor(player, damage);

		EXPECT_GE(damage, 1);
		EXPECT_LE(damage, 50);
		EXPECT_EQ(BLOCK_NONE, blockType) << "armor alone does not stop a hit of this size";
	}

	TEST_F(DamageReductionOrderTest, TheResistanceLetsArmorFinishTheAssistedHit) {
		// 100 -> 30 by the absorb, then an armor roll of at least 50. Deterministic.
		auto player = defender(true);
		int32_t damage = kAssistedDamage;
		const BlockType_t blockType = hitFor(player, damage);

		EXPECT_EQ(0, damage) << "the resistance brought it within armor's reach";
		EXPECT_EQ(BLOCK_ARMOR, blockType) << "and armor is what stopped it";
	}

	TEST_F(DamageReductionOrderTest, AnAssistedBlockIsReportedToTheAttackerAsABlock) {
		// The attacker's advance keys on drawing blood: BLOCK_NONE reopens the thirty-hit
		// window, a block spends one of it. This hit dealt zero damage, so no blood was
		// drawn, and the attacker hears a block.
		//
		// This is a deliberate change. Before the reorder the same hit landed for [1, 50]
		// and the attacker was told BLOCK_NONE. It landed only because armor was being
		// handed a number the defender was never going to take.
		auto attacker = std::make_shared<Player>();
		attacker->setGroup(std::make_shared<Group>());

		auto player = defender(true);
		int32_t damage = kAssistedDamage;
		const BlockType_t reported = player->blockHit(attacker, COMBAT_FIREDAMAGE, damage, false, true, false);

		EXPECT_EQ(0, damage);
		EXPECT_EQ(BLOCK_ARMOR, reported);
		EXPECT_EQ(BLOCK_ARMOR, attacker->getLastAttackBlockType()) << "no blood was drawn, so this is not a blood hit";
	}

	TEST_F(DamageReductionOrderTest, AnAssistedBlockAdvancesShielding) {
		// Armor really did stop this hit under the corrected order, so Shielding advances.
		// Observed, not inferred: a non-zero Shielding percent means onBlockHit() ran.
		auto player = shieldedDefender(true);
		ASSERT_DOUBLE_EQ(0.0, player->getSkillPercent(SKILL_SHIELD)) << "the fixture starts with no Shielding progress";

		int32_t damage = kAssistedDamage;
		ASSERT_EQ(BLOCK_ARMOR, hitFor(player, damage));

		EXPECT_GT(player->getSkillPercent(SKILL_SHIELD), 0.0) << "armor stopped it, so onBlockHit ran";
	}

	TEST_F(DamageReductionOrderTest, AnAssistedBlockStillSpendsTheResistanceCharge) {
		// The rule the reorder preserves, and the reason the charge condition reads the
		// pre-resistance hypothetical instead of what actually happened.
		//
		// Before the reorder this hit landed, so Player::blockHit ran its absorb loop and a
		// charge came out. Gating on "defense or armor stopped it" would silently stop
		// charging every hit of this shape - which is most melee against a defender with
		// physical absorb - and quietly make that gear cheaper to run.
		auto player = defender(true);
		int32_t damage = kAssistedDamage;
		ASSERT_EQ(BLOCK_ARMOR, hitFor(player, damage));

		EXPECT_TRUE(player->didTestSpendResistanceCharges()) << "armor would not have stopped the unreduced hit, so the charge is still owed";
	}

	// --- An ordinary armor block, with no resistance involved -------------------------

	TEST_F(DamageReductionOrderTest, AnOrdinaryArmorBlockIsUnchanged) {
		// 40 damage against an armor roll of [50, 99]: armor stops it on its own, before
		// and after the reorder alike. Shielding advances; there is no charge to spend.
		auto player = shieldedDefender(false);
		int32_t damage = kArmorBlockedDamage;
		const BlockType_t blockType = hitFor(player, damage);

		EXPECT_EQ(0, damage);
		EXPECT_EQ(BLOCK_ARMOR, blockType);
		EXPECT_GT(player->getSkillPercent(SKILL_SHIELD), 0.0) << "an ordinary armor block advances Shielding";
		EXPECT_FALSE(player->didTestSpendResistanceCharges()) << "no resistance applied, so nothing is charged";
	}

	// --- A resistance that takes the whole hit by itself ------------------------------

	TEST_F(DamageReductionOrderTest, AFullAbsorbReportsABlockToCallerAndAttacker) {
		// The absorb takes all of it, so the caller is told BLOCK_ARMOR - the value
		// Player::blockHit already returned for this case before the move - and the
		// attacker is told the same, because zero damage is not a blood hit.
		auto attacker = std::make_shared<Player>();
		attacker->setGroup(std::make_shared<Group>());

		auto player = defender(true);
		int32_t damage = kFullyAbsorbedDamage;
		const BlockType_t reported = player->blockHit(attacker, COMBAT_FIREDAMAGE, damage, false, true, false);

		EXPECT_EQ(0, damage);
		EXPECT_EQ(BLOCK_ARMOR, reported);
		EXPECT_EQ(BLOCK_ARMOR, attacker->getLastAttackBlockType());
	}

	TEST_F(DamageReductionOrderTest, AFullAbsorbDoesNotAdvanceShielding) {
		// The delta this reorder accepts on the defender's side, now observed rather than
		// asserted about. A hit the absorb swallows never reaches armor, so the shield and
		// the armour did not block it - the armour's elemental protection did, which is not
		// what Shielding measures. Before the reorder armor saw the hit at full strength,
		// stopped it, and Shielding advanced.
		auto player = shieldedDefender(true);
		int32_t damage = kFullyAbsorbedDamage;
		ASSERT_EQ(BLOCK_ARMOR, hitFor(player, damage));

		EXPECT_DOUBLE_EQ(0.0, player->getSkillPercent(SKILL_SHIELD)) << "the absorb stopped it, not the shield, so onBlockHit did not run";
	}

	TEST_F(DamageReductionOrderTest, AFullAbsorbArmorWouldHaveStoppedAnywaySpendsNoCharge) {
		// 1 damage against armor 100: armor would have finished this hit unaided, so before
		// the reorder Player::blockHit early-returned and the absorb loop never ran. No
		// charge then, no charge now.
		auto player = defender(true);
		int32_t damage = kFullyAbsorbedDamage;
		ASSERT_EQ(BLOCK_ARMOR, hitFor(player, damage));

		EXPECT_FALSE(player->didTestSpendResistanceCharges()) << "armor would have stopped this hit on its own";
	}

	TEST_F(DamageReductionOrderTest, AFullAbsorbArmorWouldNotHaveStoppedSpendsTheCharge) {
		// The same full absorb with armor out of the picture. Nothing else would have
		// stopped this hit, so before the reorder the loop ran and took a charge.
		auto player = defender(true);
		int32_t damage = kFullyAbsorbedDamage;
		ASSERT_EQ(BLOCK_ARMOR, hitFor(player, damage, false));

		EXPECT_EQ(0, damage);
		EXPECT_TRUE(player->didTestSpendResistanceCharges()) << "nothing else was going to stop it, so the charge is owed";
	}

	// --- Mitigation, the last reduction -----------------------------------------------

	TEST_F(DamageReductionOrderTest, AHitMitigationFinishesSpendsNoCharge) {
		// Mitigation ran before the absorb loop was reached and its early return skipped
		// it, so a hit mitigation finished never cost a charge. Unchanged here.
		auto player = fullyMitigatedDefender();
		int32_t damage = kIncomingDamage;
		hitFor(player, damage, false);

		ASSERT_EQ(0, damage) << "mitigation finished the hit";
		EXPECT_FALSE(player->didTestSpendResistanceCharges()) << "a hit mitigation finished never cost a charge";
	}

	TEST_F(DamageReductionOrderTest, AHitThatLandsSpendsTheCharge) {
		// The control for the test above: the same hit with mitigation out of the way lands
		// for 300 and does pay for the absorb.
		auto player = defender(true);
		int32_t damage = kIncomingDamage;
		hitFor(player, damage, false);

		ASSERT_EQ(300, damage) << "70% of 1000, with no armor and no mitigation in the way";
		EXPECT_TRUE(player->didTestSpendResistanceCharges());
	}

	// --- No regression on the plain paths ---------------------------------------------

	TEST_F(DamageReductionOrderTest, AnUnabsorbedTypeIsUntouchedByTheResistance) {
		// The absorb is fire only. An ice hit of the same size must look exactly like the
		// no-resistance control, and must not charge anything.
		auto player = defender(true);
		int32_t damage = kIncomingDamage;
		player->blockHit(nullptr, COMBAT_ICEDAMAGE, damage, false, true, false);

		EXPECT_GE(damage, 901);
		EXPECT_LE(damage, 950);
		EXPECT_FALSE(player->didTestSpendResistanceCharges()) << "the absorb does not cover ice, so it did no work";
	}
}
