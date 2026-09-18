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

#include "creatures/creature.hpp"
#include "creatures/players/player.hpp"
#include "creatures/players/vocations/mitigation_profile.hpp"
#include "creatures/players/vocations/vocation.hpp"
#include "items/item.hpp"
#include "lib/logging/in_memory_logger.hpp"

namespace {

	// The modern mitigation profile: which Defence a category contributes, which
	// multiplier weights the result, and that each of the thirteen knobs moves exactly
	// one thing. The legacy <mitigation multiplier primaryShield secondaryShield />
	// still feeds all of them, so a vocations.xml that was never updated keeps its
	// numbers - that fallback is pinned here too.
	//
	// The vocation used is deliberately synthetic with distinct, easily recognisable
	// factors, so a number landing in the wrong position is visible rather than
	// coincidentally right.
	class MitigationProfileTest : public ::testing::Test {
	protected:
		static constexpr uint16_t kSwordId = 64910; // one-handed, has its own Defence
		static constexpr uint16_t kTwoHanderId = 64911;
		static constexpr uint16_t kShieldId = 64912;
		static constexpr uint16_t kSpellbookId = 64913;
		static constexpr uint16_t kQuiverId = 64914;
		static constexpr uint16_t kBowId = 64915;
		static constexpr uint16_t kCrossbowId = 64916;
		static constexpr uint16_t kBondFistId = 64917;
		static constexpr uint16_t kLastId = kBondFistId;

		static constexpr int32_t kSwordDefense = 30;
		static constexpr int32_t kSwordExtraDefense = 5;
		static constexpr int32_t kTwoHanderDefense = 40;
		static constexpr int32_t kShieldDefense = 100; // effective 130
		static constexpr int32_t kSpellbookDefense = 100; // effective 160
		static constexpr int32_t kQuiverDefense = 10;

		static void SetUpTestSuite() {
			previousTestContainer = DI::getTestContainer();
			InMemoryLogger::install(injector);
			DI::setTestContainer(&injector);

			auto &items = Item::items.getItems();
			originalItemsSize = items.size();
			if (items.size() <= kLastId) {
				items.resize(kLastId + 1);
			}

			auto &sword = items[kSwordId];
			sword = ItemType {};
			sword.id = kSwordId;
			sword.name = "test sword";
			sword.weaponType = WEAPON_SWORD;
			sword.type = ITEM_TYPE_SWORD;
			sword.attack = 100;
			sword.defense = kSwordDefense;
			sword.extraDefense = kSwordExtraDefense;

			auto &twoHander = items[kTwoHanderId];
			twoHander = ItemType {};
			twoHander.id = kTwoHanderId;
			twoHander.name = "test two-hander";
			twoHander.weaponType = WEAPON_AXE;
			twoHander.type = ITEM_TYPE_AXE;
			twoHander.attack = 120;
			twoHander.defense = kTwoHanderDefense;
			twoHander.slotPosition = SLOTP_TWO_HAND;

			auto &shield = items[kShieldId];
			shield = ItemType {};
			shield.id = kShieldId;
			shield.name = "test shield";
			shield.weaponType = WEAPON_SHIELD;
			shield.type = ITEM_TYPE_SHIELD;
			shield.defense = kShieldDefense;

			auto &spellbook = items[kSpellbookId];
			spellbook = ItemType {};
			spellbook.id = kSpellbookId;
			spellbook.name = "test spellbook";
			spellbook.weaponType = WEAPON_SHIELD;
			spellbook.type = ITEM_TYPE_SHIELD;
			spellbook.spellbook = true;
			spellbook.defense = kSpellbookDefense;

			auto &quiver = items[kQuiverId];
			quiver = ItemType {};
			quiver.id = kQuiverId;
			quiver.name = "test quiver";
			quiver.weaponType = WEAPON_NONE;
			quiver.type = ITEM_TYPE_QUIVER;
			quiver.defense = kQuiverDefense;

			auto &bow = items[kBowId];
			bow = ItemType {};
			bow.id = kBowId;
			bow.name = "test bow";
			bow.weaponType = WEAPON_DISTANCE;
			bow.type = ITEM_TYPE_NONE;
			bow.ammoType = AMMO_ARROW;
			bow.slotPosition = SLOTP_TWO_HAND;

			auto &crossbow = items[kCrossbowId];
			crossbow = ItemType {};
			crossbow.id = kCrossbowId;
			crossbow.name = "test crossbow";
			crossbow.weaponType = WEAPON_DISTANCE;
			crossbow.type = ITEM_TYPE_NONE;
			crossbow.ammoType = AMMO_BOLT;
			crossbow.slotPosition = SLOTP_TWO_HAND;

			// A Monk fist weapon carrying an Elemental Bond.
			auto &bondFist = items[kBondFistId];
			bondFist = ItemType {};
			bondFist.id = kBondFistId;
			bondFist.name = "test bonded fist";
			bondFist.weaponType = WEAPON_FIST;
			bondFist.type = ITEM_TYPE_NONE;
			bondFist.attack = 50;
			bondFist.defense = 20;
			bondFist.elementalBond = COMBAT_FIREDAMAGE;
		}

		static void TearDownTestSuite() {
			auto &items = Item::items.getItems();
			if (items.size() > originalItemsSize) {
				items.resize(originalItemsSize);
			}
			DI::setTestContainer(previousTestContainer);
		}

		// Distinct values so a factor used in the wrong position is obvious.
		static std::shared_ptr<Vocation> profiledVocation() {
			auto vocation = std::make_shared<Vocation>(0);
			auto &profile = vocation->mitigation;
			profile.skillFactor = 2.0f;
			profile.shieldDefenseFactor = 3.0f;
			profile.spellbookDefenseFactor = 5.0f;
			profile.oneHandedDefenseFactor = 7.0f;
			profile.twoHandedDefenseFactor = 11.0f;
			profile.shieldEquipmentMultiplier = 1.0f;
			profile.spellbookEquipmentMultiplier = 13.0f;
			profile.oneHandedEquipmentMultiplier = 17.0f;
			profile.twoHandedEquipmentMultiplier = 19.0f;
			profile.bowEquipmentMultiplier = 23.0f;
			profile.crossbowEquipmentMultiplier = 29.0f;
			profile.quiverEquipmentMultiplier = 31.0f;
			profile.elementalBondEquipmentMultiplier = 1.0f;
			return vocation;
		}

		static std::shared_ptr<Player> makePlayer(const std::shared_ptr<Vocation> &vocation) {
			auto player = std::make_shared<Player>();
			player->setTestVocation(vocation);
			return player;
		}

		static void equip(const std::shared_ptr<Player> &player, Slots_t slot, uint16_t itemId) {
			const auto item = Item::CreateItem(itemId, 1);
			ASSERT_NE(nullptr, item);
			player->setTestInventoryItem(slot, item);
		}

		// The formula, written out, so an expectation states the intended arithmetic
		// rather than repeating whatever the implementation happens to do.
		static float expected(const std::shared_ptr<Player> &player, double defenceContribution, float equipmentMultiplier) {
			const double skill = player->getSkillLevel(SKILL_SHIELD) * player->getVocation()->mitigation.skillFactor;
			return std::ceil(((skill + defenceContribution) / 100.0) * equipmentMultiplier * 100.0f) / 100.0f;
		}

		inline static di::extension::injector<> injector {};
		inline static di::extension::injector<>* previousTestContainer = nullptr;
		inline static size_t originalItemsSize = 0;
	};

	// --- A: nothing equipped ----------------------------------------------------

	TEST_F(MitigationProfileTest, WithNoEquipmentOnlyTheSkillContributes) {
		auto player = makePlayer(profiledVocation());
		EXPECT_FLOAT_EQ(expected(player, 0.0, 1.0f), player->getMitigation());
	}

	// --- B / C: the off-hand compensation, applied exactly once -----------------

	TEST_F(MitigationProfileTest, AShieldContributesItsEffectiveDefenceOnce) {
		auto player = makePlayer(profiledVocation());
		equip(player, CONST_SLOT_RIGHT, kShieldId);
		// 100 raw -> 130 effective (+30%), weighted by shieldDefenseFactor.
		EXPECT_FLOAT_EQ(expected(player, 130.0 * 3.0, 1.0f), player->getMitigation());
	}

	TEST_F(MitigationProfileTest, ASpellbookContributesItsEffectiveDefenceOnce) {
		auto player = makePlayer(profiledVocation());
		equip(player, CONST_SLOT_RIGHT, kSpellbookId);
		// 100 raw -> 160 effective (+60%), its own factor, its own multiplier.
		EXPECT_FLOAT_EQ(expected(player, 160.0 * 5.0, 13.0f), player->getMitigation());
	}

	TEST_F(MitigationProfileTest, AShieldAndASpellbookAreNeverTheSameNumber) {
		// Same raw Defence, three different percentages and three different knobs:
		// if the spellbook were still misread as a shield these would collide.
		auto withShield = makePlayer(profiledVocation());
		equip(withShield, CONST_SLOT_RIGHT, kShieldId);
		auto withSpellbook = makePlayer(profiledVocation());
		equip(withSpellbook, CONST_SLOT_RIGHT, kSpellbookId);
		EXPECT_NE(withShield->getMitigation(), withSpellbook->getMitigation());
	}

	// --- D / E: the one-handed weapon's full Defence -----------------------------

	TEST_F(MitigationProfileTest, AOneHandedWeaponContributesItsFullDefence) {
		// The approved change this round: the whole Defence, not only extraDefense.
		auto player = makePlayer(profiledVocation());
		equip(player, CONST_SLOT_LEFT, kSwordId);
		const double weapon = (kSwordDefense + kSwordExtraDefense) * 7.0;
		EXPECT_FLOAT_EQ(expected(player, weapon, 17.0f), player->getMitigation());

		// And it really is more than the old extraDefense-only rule gave.
		const float extraDefenseOnly = expected(player, kSwordExtraDefense * 7.0, 17.0f);
		EXPECT_GT(player->getMitigation(), extraDefenseOnly);
	}

	TEST_F(MitigationProfileTest, AOneHandedWeaponAndAShieldEachContributeOnce) {
		auto player = makePlayer(profiledVocation());
		equip(player, CONST_SLOT_LEFT, kSwordId);
		equip(player, CONST_SLOT_RIGHT, kShieldId);

		const double shield = 130.0 * 3.0;
		const double weapon = (kSwordDefense + kSwordExtraDefense) * 7.0;
		// The shield's category wins: the weapon does not define the stance.
		EXPECT_FLOAT_EQ(expected(player, shield + weapon, 1.0f), player->getMitigation());

		// No double count: the pair is exactly the sum of what each contributes on
		// its own defence half, not either one counted twice.
		auto shieldOnly = makePlayer(profiledVocation());
		equip(shieldOnly, CONST_SLOT_RIGHT, kShieldId);
		EXPECT_FLOAT_EQ(expected(shieldOnly, shield, 1.0f), shieldOnly->getMitigation());
		EXPECT_NE(player->getMitigation(), expected(player, shield + shield, 1.0f));
	}

	// --- F: two-handed ----------------------------------------------------------

	TEST_F(MitigationProfileTest, ATwoHandedWeaponUsesItsOwnCategory) {
		auto player = makePlayer(profiledVocation());
		equip(player, CONST_SLOT_LEFT, kTwoHanderId);
		EXPECT_FLOAT_EQ(expected(player, kTwoHanderDefense * 11.0, 19.0f), player->getMitigation());
	}

	// --- G / H / I: bow, crossbow, quiver ---------------------------------------

	TEST_F(MitigationProfileTest, ABowAndACrossbowHaveSeparateKnobs) {
		auto withBow = makePlayer(profiledVocation());
		equip(withBow, CONST_SLOT_LEFT, kBowId);
		EXPECT_FLOAT_EQ(expected(withBow, 0.0, 23.0f), withBow->getMitigation());

		auto withCrossbow = makePlayer(profiledVocation());
		equip(withCrossbow, CONST_SLOT_LEFT, kCrossbowId);
		EXPECT_FLOAT_EQ(expected(withCrossbow, 0.0, 29.0f), withCrossbow->getMitigation());

		// The whole point of splitting them: they can differ.
		EXPECT_NE(withBow->getMitigation(), withCrossbow->getMitigation());
	}

	TEST_F(MitigationProfileTest, AQuiverIsItsOwnCategoryAndTakesNeitherCompensation) {
		auto player = makePlayer(profiledVocation());
		equip(player, CONST_SLOT_RIGHT, kQuiverId);
		// Raw Defence: a quiver is neither a shield nor a spellbook, so no +30 and no
		// +60, and its contribution is unweighted.
		EXPECT_FLOAT_EQ(expected(player, static_cast<double>(kQuiverDefense), 31.0f), player->getMitigation());
	}

	TEST_F(MitigationProfileTest, TheWeaponsCategoryWinsOverTheOffhandsForABow) {
		auto player = makePlayer(profiledVocation());
		equip(player, CONST_SLOT_RIGHT, kQuiverId);
		equip(player, CONST_SLOT_LEFT, kBowId);
		// The quiver still contributes its Defence; the bow decides the multiplier.
		EXPECT_FLOAT_EQ(expected(player, static_cast<double>(kQuiverDefense), 23.0f), player->getMitigation());
	}

	// --- J: Elemental Bond ------------------------------------------------------

	TEST_F(MitigationProfileTest, ElementalBondIsANeutralKnobUntilThereIsEvidence) {
		auto vocation = profiledVocation();
		auto player = makePlayer(vocation);
		equip(player, CONST_SLOT_LEFT, kBondFistId);
		const float neutral = player->getMitigation();

		// Neutral by default: the bonded weapon behaves as its own weapon category.
		EXPECT_FLOAT_EQ(expected(player, 20.0 * 7.0, 17.0f), neutral);

		// But it is a real knob, so a future evidenced value can be dialled in.
		vocation->mitigation.elementalBondEquipmentMultiplier = 2.0f;
		EXPECT_FLOAT_EQ(expected(player, 20.0 * 7.0, 17.0f * 2.0f), player->getMitigation());
		EXPECT_NE(neutral, player->getMitigation());
	}

	// --- K: no fight mode on the modern model -----------------------------------

	TEST_F(MitigationProfileTest, EveryFightModeGivesTheSameMitigation) {
		auto player = makePlayer(profiledVocation());
		equip(player, CONST_SLOT_LEFT, kSwordId);
		equip(player, CONST_SLOT_RIGHT, kShieldId);

		player->setFightMode(FIGHTMODE_ATTACK);
		const float attack = player->getMitigation();
		player->setFightMode(FIGHTMODE_BALANCED);
		const float balanced = player->getMitigation();
		player->setFightMode(FIGHTMODE_DEFENSE);
		const float defense = player->getMitigation();

		EXPECT_FLOAT_EQ(attack, balanced);
		EXPECT_FLOAT_EQ(balanced, defense);
		EXPECT_GT(attack, 0.0f);
	}

	TEST_F(MitigationProfileTest, ALegacyClientStillGetsTheOldFightModeWeighting) {
		// The compatibility path round 1 established, unchanged by the refactor.
		auto player = makePlayer(profiledVocation());
		equip(player, CONST_SLOT_RIGHT, kShieldId);
		player->setTestLegacyCombatModel(true);

		player->setFightMode(FIGHTMODE_ATTACK);
		const float attack = player->getMitigation();
		player->setFightMode(FIGHTMODE_DEFENSE);
		const float defense = player->getMitigation();
		EXPECT_LT(attack, defense) << "0.8 and 1.2 must still differ on a legacy client";
	}

	// --- L / M: the Wheel multiplier is multiplicative ---------------------------

	TEST_F(MitigationProfileTest, TheWheelMultiplierMultipliesAndNeverAdds) {
		auto player = makePlayer(profiledVocation());
		equip(player, CONST_SLOT_RIGHT, kShieldId);
		const float base = player->getMitigation();
		ASSERT_GT(base, 0.0f);

		// The stat is stored in hundredths: 2000 is the +20% one Lesser Gem grants.
		player->wheel().addStat(WheelStat_t::MITIGATION, 2000);
		ASSERT_DOUBLE_EQ(20.0, player->wheel().getMitigationMultiplier());

		const float boosted = player->getMitigation();
		EXPECT_FLOAT_EQ(base * 1.20f, boosted) << "a +20% Wheel bonus is x1.20";
		EXPECT_NE(base + 20.0f, boosted) << "it is not twenty percentage points";
	}

	TEST_F(MitigationProfileTest, WheelSourcesAccumulateBeforeTheyMultiply) {
		auto player = makePlayer(profiledVocation());
		equip(player, CONST_SLOT_RIGHT, kShieldId);
		const float base = player->getMitigation();

		// Two sources of +20% and +10% accumulate into one +30% multiplier and are
		// applied once - not 1.20 x 1.10 compounded.
		player->wheel().addStat(WheelStat_t::MITIGATION, 2000);
		player->wheel().addStat(WheelStat_t::MITIGATION, 1000);
		ASSERT_DOUBLE_EQ(30.0, player->wheel().getMitigationMultiplier());
		EXPECT_FLOAT_EQ(base * 1.30f, player->getMitigation());
		EXPECT_NE(base * 1.20f * 1.10f, player->getMitigation());
	}

	// --- N: the per-vocation profile --------------------------------------------

	TEST_F(MitigationProfileTest, TheLegacyThreeStillFillEveryModernKnob) {
		// A vocations.xml that carries only multiplier/primaryShield/secondaryShield
		// keeps exactly the numbers it had. Knight values.
		VocationMitigationProfile profile;
		profile.deriveFromLegacy(1.30f, 2.05f, 1.25f);

		EXPECT_FLOAT_EQ(1.30f, profile.skillFactor);
		// primaryShield weighted a shield's and a one-handed weapon's Defence...
		EXPECT_FLOAT_EQ(2.05f, profile.shieldDefenseFactor);
		EXPECT_FLOAT_EQ(2.05f, profile.oneHandedDefenseFactor);
		// ...secondaryShield weighted a two-hander's Defence...
		EXPECT_FLOAT_EQ(1.25f, profile.twoHandedDefenseFactor);
		// ...and multiplied the whole result for a spellbook, quiver, bow or crossbow.
		EXPECT_FLOAT_EQ(1.25f, profile.spellbookEquipmentMultiplier);
		EXPECT_FLOAT_EQ(1.25f, profile.quiverEquipmentMultiplier);
		EXPECT_FLOAT_EQ(1.25f, profile.bowEquipmentMultiplier);
		EXPECT_FLOAT_EQ(1.25f, profile.crossbowEquipmentMultiplier);
		// A spellbook's Defence itself was never weighted.
		EXPECT_FLOAT_EQ(1.0f, profile.spellbookDefenseFactor);
		EXPECT_FLOAT_EQ(1.0f, profile.shieldEquipmentMultiplier);
		EXPECT_FLOAT_EQ(1.0f, profile.oneHandedEquipmentMultiplier);
		EXPECT_FLOAT_EQ(1.0f, profile.twoHandedEquipmentMultiplier);
		// Never modelled, no evidence: neutral.
		EXPECT_FLOAT_EQ(1.0f, profile.elementalBondEquipmentMultiplier);
	}

	TEST_F(MitigationProfileTest, EachVocationFamilyKeepsItsOwnAuditedNumbers) {
		struct Family {
			const char* name;
			float multiplier;
			float primary;
			float secondary;
		};
		// data/XML/vocations.xml, as audited.
		const std::array<Family, 4> families { {
			{ "Sorcerer/Druid", 1.26f, 2.00f, 1.20f },
			{ "Paladin", 1.28f, 2.08f, 1.20f },
			{ "Knight", 1.30f, 2.05f, 1.25f },
			{ "Monk", 1.28f, 2.08f, 1.20f },
		} };

		for (const auto &family : families) {
			VocationMitigationProfile profile;
			profile.deriveFromLegacy(family.multiplier, family.primary, family.secondary);
			EXPECT_FLOAT_EQ(family.multiplier, profile.skillFactor) << family.name;
			EXPECT_FLOAT_EQ(family.primary, profile.shieldDefenseFactor) << family.name;
			EXPECT_FLOAT_EQ(family.secondary, profile.twoHandedDefenseFactor) << family.name;
		}

		// The Knight really is tuned apart from the mage: the refactor must not have
		// flattened the families into one.
		VocationMitigationProfile knight;
		knight.deriveFromLegacy(1.30f, 2.05f, 1.25f);
		VocationMitigationProfile mage;
		mage.deriveFromLegacy(1.26f, 2.00f, 1.20f);
		EXPECT_NE(knight.skillFactor, mage.skillFactor);
		EXPECT_NE(knight.shieldDefenseFactor, mage.shieldDefenseFactor);
	}

	TEST_F(MitigationProfileTest, EveryKnobMovesExactlyOneThing) {
		// Thirteen knobs, thirteen independent effects. A knob that changed a case it
		// has no business in would show up here.
		auto player = makePlayer(profiledVocation());
		equip(player, CONST_SLOT_RIGHT, kShieldId);
		const float withShield = player->getMitigation();

		auto other = makePlayer(profiledVocation());
		other->getVocation()->mitigation.spellbookDefenseFactor = 99.0f;
		other->getVocation()->mitigation.twoHandedDefenseFactor = 99.0f;
		other->getVocation()->mitigation.bowEquipmentMultiplier = 99.0f;
		other->getVocation()->mitigation.crossbowEquipmentMultiplier = 99.0f;
		other->getVocation()->mitigation.quiverEquipmentMultiplier = 99.0f;
		equip(other, CONST_SLOT_RIGHT, kShieldId);
		EXPECT_FLOAT_EQ(withShield, other->getMitigation()) << "a shield read a knob that is not its own";
	}

	// --- O: the damage-type whitelist -------------------------------------------

	TEST_F(MitigationProfileTest, OnlyTheSevenCommonDamageTypesAreMitigated) {
		for (const auto type : { COMBAT_PHYSICALDAMAGE, COMBAT_EARTHDAMAGE, COMBAT_ICEDAMAGE, COMBAT_FIREDAMAGE, COMBAT_ENERGYDAMAGE, COMBAT_HOLYDAMAGE, COMBAT_DEATHDAMAGE }) {
			EXPECT_TRUE(Creature::isMitigatableCombatType(type)) << "common type " << static_cast<int>(type) << " is not mitigated";
		}
	}

	TEST_F(MitigationProfileTest, HealingDrainsAgonyAndDrowningAreNotMitigated) {
		for (const auto type : { COMBAT_HEALING, COMBAT_LIFEDRAIN, COMBAT_MANADRAIN, COMBAT_AGONYDAMAGE, COMBAT_DROWNDAMAGE, COMBAT_NEUTRALDAMAGE, COMBAT_UNDEFINEDDAMAGE, COMBAT_NONE }) {
			EXPECT_FALSE(Creature::isMitigatableCombatType(type)) << "type " << static_cast<int>(type) << " must not be mitigated";
		}
	}

	TEST_F(MitigationProfileTest, DrowningIsTheOneTheOldExceptionListLetThrough) {
		// The old code excluded only the two drains and agony, so drowning, neutral
		// and undefined damage were all mitigated by accident. Pinned so the
		// whitelist cannot quietly widen back out.
		EXPECT_FALSE(Creature::isMitigatableCombatType(COMBAT_DROWNDAMAGE));
		EXPECT_FALSE(Creature::isMitigatableCombatType(COMBAT_NEUTRALDAMAGE));
		EXPECT_FALSE(Creature::isMitigatableCombatType(COMBAT_UNDEFINEDDAMAGE));
	}

	// --- Rounding ---------------------------------------------------------------

	TEST_F(MitigationProfileTest, MitigationKeepsTwoDecimalsRoundedUp) {
		// Characterised, not changed: the engine rounds the equipment-adjusted value
		// up to two decimals, and the Wheel multiplier applies after that.
		auto vocation = profiledVocation();
		vocation->mitigation.skillFactor = 1.0f;
		auto player = makePlayer(vocation);

		// Skill 10 x 1.0 / 100 = 0.10 exactly.
		EXPECT_FLOAT_EQ(0.10f, player->getMitigation());

		vocation->mitigation.skillFactor = 1.26f; // 12.6 / 100 = 0.126 -> 0.13
		EXPECT_FLOAT_EQ(0.13f, player->getMitigation());

		vocation->mitigation.skillFactor = 1.21f; // 12.1 / 100 = 0.121 -> 0.13
		EXPECT_FLOAT_EQ(0.13f, player->getMitigation());
	}

	TEST_F(MitigationProfileTest, ZeroMitigationStaysZeroThroughTheWheelMultiplier) {
		auto vocation = profiledVocation();
		vocation->mitigation.skillFactor = 0.0f;
		auto player = makePlayer(vocation);
		ASSERT_FLOAT_EQ(0.0f, player->getMitigation());

		player->wheel().addStat(WheelStat_t::MITIGATION, 2000);
		EXPECT_FLOAT_EQ(0.0f, player->getMitigation()) << "a multiplier on nothing is still nothing";
	}

}
