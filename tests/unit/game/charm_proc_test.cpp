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

#include "creatures/combat/charm_proc.hpp"
#include "creatures/players/player.hpp"
#include "utils/tools.hpp"

namespace {

	// 15.25: an auto attack rolls its charms on the attacked creature and on nothing
	// else. The area ammunition the update adds is one auto attack over thirteen
	// squares, so without this rule one shot rolled the offensive charm once per
	// creature it caught.
	//
	// Spells and runes are areas on purpose and keep rolling on everything they hit.
	class CharmProcTest : public ::testing::Test {
	protected:
		void SetUp() override {
			UPDATE_OTSYS_TIME();
		}

		static constexpr CharmProc::Hit spellHit() {
			return {};
		}
	};

	// --- The decision -------------------------------------------------------------

	TEST_F(CharmProcTest, AnOrdinarySpellHitRolls) {
		EXPECT_TRUE(CharmProc::allows(spellHit()));
	}

	TEST_F(CharmProcTest, AnAreaSpellRollsOnEveryCreatureItHits) {
		// Not an auto attack, so "main target" never enters into it: a rune that hits
		// nine squares still rolls nine times, exactly as before.
		CharmProc::Hit hit = spellHit();
		hit.autoAttack = false;
		hit.mainTarget = false;
		EXPECT_TRUE(CharmProc::allows(hit));
	}

	TEST_F(CharmProcTest, AnAutoAttackRollsOnItsMainTarget) {
		CharmProc::Hit hit = spellHit();
		hit.autoAttack = true;
		hit.mainTarget = true;
		EXPECT_TRUE(CharmProc::allows(hit));
	}

	TEST_F(CharmProcTest, AnAutoAttackNeverRollsOnTheSplash) {
		// The thirteen-square storm arrow: twelve of the thirteen are this case.
		CharmProc::Hit hit = spellHit();
		hit.autoAttack = true;
		hit.mainTarget = false;
		EXPECT_FALSE(CharmProc::allows(hit));
	}

	TEST_F(CharmProcTest, NoCharmDamageNeverRolls) {
		for (const bool autoAttack : { false, true }) {
			for (const bool mainTarget : { false, true }) {
				CharmProc::Hit hit = spellHit();
				hit.noCharm = true;
				hit.autoAttack = autoAttack;
				hit.mainTarget = mainTarget;
				EXPECT_FALSE(CharmProc::allows(hit)) << "autoAttack " << autoAttack << ", mainTarget " << mainTarget;
			}
		}
	}

	TEST_F(CharmProcTest, ExtensionAndConditionDamageNeverRoll) {
		CharmProc::Hit cleave = spellHit();
		cleave.extension = true;
		EXPECT_FALSE(CharmProc::allows(cleave)) << "a cleave hit is secondary accounting";

		CharmProc::Hit overTime = spellHit();
		overTime.conditionDamage = true;
		EXPECT_FALSE(CharmProc::allows(overTime)) << "damage over time is not a hit";
	}

	TEST_F(CharmProcTest, TheWholeTruthTableIsPinned) {
		// Five booleans, and the only combinations that roll are the ones with no
		// refusal set and either no auto attack or the main target of one.
		for (int bits = 0; bits < 32; ++bits) {
			const CharmProc::Hit hit {
				.noCharm = (bits & 1) != 0,
				.extension = (bits & 2) != 0,
				.conditionDamage = (bits & 4) != 0,
				.autoAttack = (bits & 8) != 0,
				.mainTarget = (bits & 16) != 0,
			};
			const bool expected = !hit.noCharm && !hit.extension && !hit.conditionDamage
				&& (!hit.autoAttack || hit.mainTarget);
			EXPECT_EQ(expected, CharmProc::allows(hit)) << "bits " << bits;
		}
	}

	// --- The context the rule reads -----------------------------------------------

	TEST_F(CharmProcTest, APlayerIsNotResolvingAnAutoAttackByDefault) {
		auto player = std::make_shared<Player>();
		EXPECT_FALSE(player->hasAutoAttackContext());
		EXPECT_FALSE(player->isAutoAttackMainTarget(1234));
	}

	TEST_F(CharmProcTest, TheContextNamesExactlyOneMainTarget) {
		auto player = std::make_shared<Player>();
		player->setAutoAttackContext(1234);

		EXPECT_TRUE(player->hasAutoAttackContext());
		EXPECT_TRUE(player->isAutoAttackMainTarget(1234));
		EXPECT_FALSE(player->isAutoAttackMainTarget(1235)) << "a creature beside it is splash";
		EXPECT_FALSE(player->isAutoAttackMainTarget(0)) << "and nothing matches the empty id";
	}

	TEST_F(CharmProcTest, AShotAimedAtATileHasNoMainTarget) {
		// Weapon::internalUseWeapon(player, item, tile): ammunition loosed where no
		// creature was targeted. The shot is still an auto attack, so nothing it
		// catches rolls a charm.
		auto player = std::make_shared<Player>();
		player->setAutoAttackContext(0);

		EXPECT_TRUE(player->hasAutoAttackContext());
		EXPECT_FALSE(player->isAutoAttackMainTarget(0));
		EXPECT_FALSE(player->isAutoAttackMainTarget(1234));
	}

	TEST_F(CharmProcTest, TheContextIsCleared) {
		auto player = std::make_shared<Player>();
		player->setAutoAttackContext(1234);
		player->clearAutoAttackContext();

		EXPECT_FALSE(player->hasAutoAttackContext());
		EXPECT_FALSE(player->isAutoAttackMainTarget(1234)) << "a spell cast after the shot is not an auto attack";
	}

	TEST_F(CharmProcTest, ASecondShotReplacesTheFirstsTarget) {
		auto player = std::make_shared<Player>();
		player->setAutoAttackContext(1234);
		player->setAutoAttackContext(5678);

		EXPECT_TRUE(player->isAutoAttackMainTarget(5678));
		EXPECT_FALSE(player->isAutoAttackMainTarget(1234));
	}

	TEST_F(CharmProcTest, ASpellCastAfterAShotRollsOnEverythingAgain) {
		// The guard in Weapon clears the context when the shot ends, so the very next
		// area spell is back to ordinary behaviour. This is the regression that would
		// bite if the context ever leaked.
		auto player = std::make_shared<Player>();
		player->setAutoAttackContext(1234);
		player->clearAutoAttackContext();

		const CharmProc::Hit hit {
			.autoAttack = player->hasAutoAttackContext(),
			.mainTarget = player->isAutoAttackMainTarget(9999),
		};
		EXPECT_TRUE(CharmProc::allows(hit));
	}
}
