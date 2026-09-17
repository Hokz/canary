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
#include "creatures/players/player.hpp"
#include "creatures/players/vocations/vocation.hpp"
#include "items/item.hpp"
#include "lib/logging/in_memory_logger.hpp"

namespace {

	// Two rules of the 15.25 combat model, together because they are the same
	// player's numbers:
	//
	//   - Attack / Balanced / Defense carry no mathematical weight any more. The same
	//     player with the same equipment produces the same attack factor, defence,
	//     mitigation and attack total in all three. A client whose protocol profile
	//     still sends a fight mode keeps the old weighting, and these tests pin that
	//     too, so the compatibility path cannot rot unnoticed.
	//   - A weapon's Attack counts 20% higher, a shield's Defence 30% and a
	//     spellbook's 60%, each exactly once and only on its own kind of item.
	class CombatTacticsTest : public ::testing::Test {
	protected:
		static constexpr uint16_t kSwordId = 64900;
		static constexpr uint16_t kShieldId = 64901;
		static constexpr uint16_t kSpellbookId = 64902;
		static constexpr uint16_t kQuiverId = 64903;

		static constexpr int32_t kSwordAttack = 100;
		static constexpr int32_t kShieldDefense = 100;
		static constexpr int32_t kSpellbookDefense = 100;
		static constexpr int32_t kQuiverDefense = 100;

		static void SetUpTestSuite() {
			previousTestContainer = DI::getTestContainer();
			InMemoryLogger::install(injector);
			DI::setTestContainer(&injector);

			auto &items = Item::items.getItems();
			originalItemsSize = items.size();
			if (items.size() <= kQuiverId) {
				items.resize(kQuiverId + 1);
			}

			auto &sword = items[kSwordId];
			sword = ItemType {};
			sword.id = kSwordId;
			sword.name = "test sword";
			sword.weaponType = WEAPON_SWORD;
			sword.type = ITEM_TYPE_SWORD;
			sword.attack = kSwordAttack;

			auto &shield = items[kShieldId];
			shield = ItemType {};
			shield.id = kShieldId;
			shield.name = "test shield";
			shield.weaponType = WEAPON_SHIELD;
			shield.type = ITEM_TYPE_SHIELD;
			shield.defense = kShieldDefense;

			// items.xml gives a spellbook weaponType="spellbook", which the parser maps
			// to WEAPON_SHIELD and flags; the flag is the only thing separating the two.
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
		}

		static void TearDownTestSuite() {
			auto &items = Item::items.getItems();
			if (items.size() > originalItemsSize) {
				items.resize(originalItemsSize);
			}
			DI::setTestContainer(previousTestContainer);
		}

		static std::shared_ptr<Player> makePlayer() {
			auto player = std::make_shared<Player>();
			auto vocation = std::make_shared<Vocation>(0);
			vocation->defenseMultiplier = 1.0f;
			vocation->mitigationFactor = 1.0f;
			vocation->mitigationPrimaryShield = 1.0f;
			vocation->mitigationSecondaryShield = 1.0f;
			player->setTestVocation(vocation);
			return player;
		}

		static void equip(const std::shared_ptr<Player> &player, Slots_t slot, uint16_t itemId) {
			const auto item = Item::CreateItem(itemId, 1);
			EXPECT_NE(nullptr, item);
			player->setTestInventoryItem(slot, item);
		}

		// Reads one value in each of the three legacy fight modes.
		template <typename Fn>
		static std::array<double, 3> inEveryFightMode(const std::shared_ptr<Player> &player, Fn &&read) {
			std::array<double, 3> values {};
			const std::array<FightMode_t, 3> modes { FIGHTMODE_ATTACK, FIGHTMODE_BALANCED, FIGHTMODE_DEFENSE };
			for (size_t i = 0; i < modes.size(); ++i) {
				player->setFightMode(modes[i]);
				values[i] = static_cast<double>(read(player));
			}
			return values;
		}

		inline static di::extension::injector<> injector {};
		inline static di::extension::injector<>* previousTestContainer = nullptr;
		inline static size_t originalItemsSize = 0;
	};

	TEST_F(CombatTacticsTest, TheAttackFactorIsTheSameInEveryFightMode) {
		auto player = makePlayer();
		const auto factors = inEveryFightMode(player, [](const auto &p) { return p->getAttackFactor(); });
		EXPECT_DOUBLE_EQ(1.0, factors[0]);
		EXPECT_DOUBLE_EQ(1.0, factors[1]);
		EXPECT_DOUBLE_EQ(1.0, factors[2]);
	}

	TEST_F(CombatTacticsTest, TheDefenseFactorIsTheSameInEveryFightMode) {
		auto player = makePlayer();
		const auto factors = inEveryFightMode(player, [](const auto &p) { return p->getDefenseFactor(false); });
		EXPECT_DOUBLE_EQ(1.0, factors[0]);
		EXPECT_DOUBLE_EQ(1.0, factors[1]);
		EXPECT_DOUBLE_EQ(1.0, factors[2]);
	}

	TEST_F(CombatTacticsTest, DefenceMitigationAndAttackTotalAreTheSameInEveryFightMode) {
		auto player = makePlayer();
		equip(player, CONST_SLOT_LEFT, kSwordId);
		equip(player, CONST_SLOT_RIGHT, kShieldId);

		const auto defence = inEveryFightMode(player, [](const auto &p) { return p->getDefense(); });
		EXPECT_EQ(defence[0], defence[1]);
		EXPECT_EQ(defence[1], defence[2]);
		EXPECT_GT(defence[0], 0);

		const auto mitigation = inEveryFightMode(player, [](const auto &p) { return p->getMitigation(); });
		EXPECT_DOUBLE_EQ(mitigation[0], mitigation[1]);
		EXPECT_DOUBLE_EQ(mitigation[1], mitigation[2]);

		const auto attack = inEveryFightMode(player, [](const auto &p) { return p->attackTotal(0, 120, 100); });
		EXPECT_EQ(attack[0], attack[1]);
		EXPECT_EQ(attack[1], attack[2]);

		const auto equipment = inEveryFightMode(player, [](const auto &p) { return p->getDefenseEquipment(); });
		EXPECT_EQ(equipment[0], equipment[1]);
		EXPECT_EQ(equipment[1], equipment[2]);
	}

	TEST_F(CombatTacticsTest, ALegacyClientKeepsTheOldFightModeWeighting) {
		// The compatibility half: the pre-15.25 numbers are still reachable, and they
		// really are different from each other, so "all three equal" above is a
		// property of the modern model and not of the test setup.
		auto player = makePlayer();
		player->setTestLegacyCombatModel(true);
		equip(player, CONST_SLOT_LEFT, kSwordId);
		equip(player, CONST_SLOT_RIGHT, kShieldId);

		const auto factors = inEveryFightMode(player, [](const auto &p) { return p->getAttackFactor(); });
		EXPECT_DOUBLE_EQ(1.0, factors[0]);
		EXPECT_DOUBLE_EQ(0.75, factors[1]);
		EXPECT_DOUBLE_EQ(0.5, factors[2]);

		const auto defenceFactors = inEveryFightMode(player, [](const auto &p) { return p->getDefenseFactor(true); });
		EXPECT_DOUBLE_EQ(0.5, defenceFactors[0]);
		EXPECT_DOUBLE_EQ(0.75, defenceFactors[1]);
		EXPECT_DOUBLE_EQ(1.0, defenceFactors[2]);

		const auto mitigation = inEveryFightMode(player, [](const auto &p) { return p->getMitigation(); });
		EXPECT_LT(mitigation[0], mitigation[1]) << "attack weighted mitigation down";
		EXPECT_LT(mitigation[1], mitigation[2]) << "and defense weighted it up";

		const auto attack = inEveryFightMode(player, [](const auto &p) { return p->attackTotal(0, 120, 100); });
		EXPECT_GT(attack[0], attack[1]);
		EXPECT_GT(attack[1], attack[2]);
	}

	TEST_F(CombatTacticsTest, AWeaponsAttackCountsTwentyPercentHigherOnTheModernModelOnly) {
		auto player = makePlayer();
		EXPECT_DOUBLE_EQ(120.0, player->getEffectiveWeaponAttackValue(kSwordAttack));

		player->setTestLegacyCombatModel(true);
		EXPECT_DOUBLE_EQ(100.0, player->getEffectiveWeaponAttackValue(kSwordAttack)) << "a legacy client sees the raw item data";
	}

	TEST_F(CombatTacticsTest, AShieldGetsThirtyPercentAndASpellbookSixty) {
		auto withShield = makePlayer();
		equip(withShield, CONST_SLOT_RIGHT, kShieldId);
		EXPECT_DOUBLE_EQ(130.0, withShield->getEffectiveOffhandDefense(withShield->getInventoryItem(CONST_SLOT_RIGHT)));
		EXPECT_EQ(130, withShield->getDefenseEquipment());

		auto withSpellbook = makePlayer();
		equip(withSpellbook, CONST_SLOT_RIGHT, kSpellbookId);
		EXPECT_DOUBLE_EQ(160.0, withSpellbook->getEffectiveOffhandDefense(withSpellbook->getInventoryItem(CONST_SLOT_RIGHT)));
		EXPECT_EQ(160, withSpellbook->getDefenseEquipment());
	}

	TEST_F(CombatTacticsTest, AnOrdinaryOffhandItemGetsNeitherPercentage) {
		auto player = makePlayer();
		equip(player, CONST_SLOT_RIGHT, kQuiverId);
		EXPECT_DOUBLE_EQ(static_cast<double>(kQuiverDefense), player->getEffectiveOffhandDefense(player->getInventoryItem(CONST_SLOT_RIGHT)));
	}

	TEST_F(CombatTacticsTest, RawItemDataIsUntouched) {
		// The compensation lives in the Player, never in the item: the market, the
		// item description and serialisation all keep reading the canonical numbers.
		auto player = makePlayer();
		equip(player, CONST_SLOT_LEFT, kSwordId);
		equip(player, CONST_SLOT_RIGHT, kShieldId);

		EXPECT_EQ(kSwordAttack, player->getInventoryItem(CONST_SLOT_LEFT)->getAttack());
		EXPECT_EQ(kShieldDefense, player->getInventoryItem(CONST_SLOT_RIGHT)->getDefense());
		EXPECT_EQ(kShieldDefense, Item::items[kShieldId].defense);
		EXPECT_EQ(kSwordAttack, Item::items[kSwordId].attack);
	}

	TEST_F(CombatTacticsTest, ShieldBashReadsTheSameCompensatedShieldDefence) {
		// Player::getEffectiveShieldDefense is what the Lua helper behind Shield Bash
		// and Shield Slam returns, so the spell cannot drift from normal shield
		// combat and must not apply the 30% a second time.
		auto player = makePlayer();
		equip(player, CONST_SLOT_RIGHT, kShieldId);
		EXPECT_EQ(130, player->getEffectiveShieldDefense());
		EXPECT_EQ(EffectiveCombatValues::toInteger(player->getEffectiveOffhandDefense(player->getInventoryItem(CONST_SLOT_RIGHT))), player->getEffectiveShieldDefense());

		auto withSpellbook = makePlayer();
		equip(withSpellbook, CONST_SLOT_RIGHT, kSpellbookId);
		EXPECT_EQ(0, withSpellbook->getEffectiveShieldDefense()) << "a spellbook is not a shield to bash with";

		auto barehanded = makePlayer();
		EXPECT_EQ(0, barehanded->getEffectiveShieldDefense());
	}

	TEST_F(CombatTacticsTest, NoPercentageIsAppliedTwiceAlongTheDefenceChain) {
		auto player = makePlayer();
		equip(player, CONST_SLOT_RIGHT, kShieldId);

		// 100 raw -> 130 effective. 169 would be the compensation landing twice.
		EXPECT_EQ(130, player->getDefenseEquipment());
		EXPECT_NE(169, player->getDefenseEquipment());

		// And mitigation consumes that same 130 once: with every vocation factor at
		// 1.0 and shielding at its untrained 10, it is (10 + 130) / 100. Raw would be
		// 1.10 and a doubled compensation 1.79, so the tolerance still separates them.
		EXPECT_NEAR(1.4, player->getMitigation(), 0.011);
	}

}
