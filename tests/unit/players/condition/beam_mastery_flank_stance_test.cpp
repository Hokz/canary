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
#include "creatures/combat/elemental_stance.hpp"
#include "creatures/players/player.hpp"
#include "utils/tools.hpp"

namespace {

	// A Beam Mastery cast is two Combat executions - the central beam and its two flank
	// lines - and both reach Combat::getCombatDamage. The elemental stance conversion is
	// a state machine on the player, so running it twice let one cast resolve two
	// elements: the centre consumed an armed fire conversion and the flanks, finding
	// nothing armed, stayed energy.
	//
	// ElementalStance::resolvePass is the whole per-execution decision and is what
	// getCombatDamage calls. These tests drive it exactly as getCombatDamage does -
	// stance and armed element read off a real Player, the result written back - so what
	// is proven here is the production path, not a restatement of it.
	class BeamMasteryFlankStanceTest : public ::testing::Test {
	protected:
		void SetUp() override {
			UPDATE_OTSYS_TIME();
		}

		// A player whose wheel has the given Beam Mastery stage, through the real
		// registration path: that is what fills the beam spell set and the stage the
		// adjacent percentage is read from.
		static std::shared_ptr<Player> beamPlayer(uint8_t beamMasteryStage) {
			auto player = std::make_shared<Player>();
			PlayerWheelMethodsBonusData bonusData;
			bonusData.stages.beamMastery = beamMasteryStage;
			player->wheel().setWheelBonusData(bonusData);
			player->wheel().registerPlayerBonusData();
			return player;
		}

		static void giveStance(const std::shared_ptr<Player> &player, AttrSubId_t subId) {
			auto condition = Condition::createCondition(CONDITIONID_COMBAT, CONDITION_ATTRIBUTES, -1, 0, false, magic_enum::enum_integer(subId), true);
			ASSERT_NE(nullptr, condition);
			ASSERT_TRUE(player->addCondition(condition));
		}

		// One Combat execution, assembled exactly as Combat::getCombatDamage assembles
		// it: the held stance and the armed conversion come off the player, the decision
		// is the production one, and the armed conversion is written back.
		static CombatType_t runPass(const std::shared_ptr<Player> &player, CombatType_t naturalType, const std::string &spellName, bool isFlank) {
			const ElementalStance::Pass pass {
				.naturalType = naturalType,
				.stanceElement = player->getElementalStanceElement(),
				.instantSpellName = spellName,
				.isFlank = isFlank,
				.beamMasterySpell = player->wheel().isBeamMasterySpell(spellName),
				.beamMasteryFlankActive = player->wheel().getBeamMasteryAdjacentDamagePercent() > 0,
			};

			CombatType_t pending = player->getPendingElementalConversion();
			const CombatType_t resolved = ElementalStance::resolvePass(pass, pending, player->beamMasteryCastContext());
			player->setPendingElementalConversion(pending);
			return resolved;
		}

		struct Cast {
			CombatType_t central = COMBAT_NONE;
			CombatType_t flank = COMBAT_NONE;
			bool flankRan = false;
		};

		// A whole beam cast the way the datapack runs it: the central Combat, then the
		// flank Combat, and the flank only when there is adjacent damage to deal.
		static Cast castBeam(const std::shared_ptr<Player> &player, CombatType_t naturalType, const std::string &spellName) {
			Cast cast;
			cast.central = runPass(player, naturalType, spellName, false);
			if (player->wheel().getBeamMasteryAdjacentDamagePercent() > 0) {
				cast.flank = runPass(player, naturalType, spellName, true);
				cast.flankRan = true;
			}
			return cast;
		}
	};

	// --- The state machine itself ------------------------------------------------

	TEST_F(BeamMasteryFlankStanceTest, NoStanceConvertsNothingAndDisarms) {
		const auto resolution = ElementalStance::resolve(COMBAT_ENERGYDAMAGE, COMBAT_NONE, COMBAT_FIREDAMAGE);
		EXPECT_EQ(COMBAT_ENERGYDAMAGE, resolution.resolvedType);
		EXPECT_EQ(COMBAT_NONE, resolution.pendingAfter) << "the stance that armed it is gone";
	}

	TEST_F(BeamMasteryFlankStanceTest, TheStancesOwnElementArmsAndArmingIsIdempotent) {
		const auto first = ElementalStance::resolve(COMBAT_FIREDAMAGE, COMBAT_FIREDAMAGE, COMBAT_NONE);
		EXPECT_EQ(COMBAT_FIREDAMAGE, first.resolvedType);
		EXPECT_EQ(COMBAT_FIREDAMAGE, first.pendingAfter);

		const auto second = ElementalStance::resolve(COMBAT_FIREDAMAGE, COMBAT_FIREDAMAGE, first.pendingAfter);
		EXPECT_EQ(COMBAT_FIREDAMAGE, second.pendingAfter) << "two fire spells still leave one armed conversion";
	}

	TEST_F(BeamMasteryFlankStanceTest, ADifferentElementConsumesTheArmedConversionOnce) {
		const auto first = ElementalStance::resolve(COMBAT_ENERGYDAMAGE, COMBAT_FIREDAMAGE, COMBAT_FIREDAMAGE);
		EXPECT_EQ(COMBAT_FIREDAMAGE, first.resolvedType);
		EXPECT_EQ(COMBAT_NONE, first.pendingAfter);

		const auto second = ElementalStance::resolve(COMBAT_ENERGYDAMAGE, COMBAT_FIREDAMAGE, first.pendingAfter);
		EXPECT_EQ(COMBAT_ENERGYDAMAGE, second.resolvedType) << "there is nothing left to consume";
	}

	TEST_F(BeamMasteryFlankStanceTest, AHeldStanceWithNothingArmedLeavesBothAlone) {
		const auto resolution = ElementalStance::resolve(COMBAT_ENERGYDAMAGE, COMBAT_FIREDAMAGE, COMBAT_NONE);
		EXPECT_EQ(COMBAT_ENERGYDAMAGE, resolution.resolvedType);
		EXPECT_EQ(COMBAT_NONE, resolution.pendingAfter);
	}

	// --- A) B) C) consuming a pending conversion ---------------------------------

	TEST_F(BeamMasteryFlankStanceTest, FlamesPendingFireMakesBothPassesOfEnergyBeamFire) {
		auto player = beamPlayer(3);
		giveStance(player, AttrSubId_t::StanceMasterOfFlames);
		player->setPendingElementalConversion(COMBAT_FIREDAMAGE);

		const auto cast = castBeam(player, COMBAT_ENERGYDAMAGE, "Energy Beam");
		ASSERT_TRUE(cast.flankRan);
		EXPECT_EQ(COMBAT_FIREDAMAGE, cast.central);
		EXPECT_EQ(COMBAT_FIREDAMAGE, cast.flank) << "one cast, one element";
		EXPECT_EQ(COMBAT_NONE, player->getPendingElementalConversion()) << "consumed exactly once";
	}

	TEST_F(BeamMasteryFlankStanceTest, DecayPendingDeathMakesBothPassesOfGreatEnergyBeamDeath) {
		auto player = beamPlayer(2);
		giveStance(player, AttrSubId_t::StanceMasterOfDecay);
		player->setPendingElementalConversion(COMBAT_DEATHDAMAGE);

		const auto cast = castBeam(player, COMBAT_ENERGYDAMAGE, "Great Energy Beam");
		ASSERT_TRUE(cast.flankRan);
		EXPECT_EQ(COMBAT_DEATHDAMAGE, cast.central);
		EXPECT_EQ(COMBAT_DEATHDAMAGE, cast.flank);
		EXPECT_EQ(COMBAT_NONE, player->getPendingElementalConversion());
	}

	TEST_F(BeamMasteryFlankStanceTest, ThunderPendingEnergyMakesBothPassesOfGreatDeathBeamEnergy) {
		auto player = beamPlayer(1);
		giveStance(player, AttrSubId_t::StanceMasterOfThunder);
		player->setPendingElementalConversion(COMBAT_ENERGYDAMAGE);

		const auto cast = castBeam(player, COMBAT_DEATHDAMAGE, "Great Death Beam");
		ASSERT_TRUE(cast.flankRan);
		EXPECT_EQ(COMBAT_ENERGYDAMAGE, cast.central);
		EXPECT_EQ(COMBAT_ENERGYDAMAGE, cast.flank);
		EXPECT_EQ(COMBAT_NONE, player->getPendingElementalConversion());
	}

	// --- D) E) arming a conversion -----------------------------------------------

	TEST_F(BeamMasteryFlankStanceTest, ThunderAndEnergyBeamArmOnceAndTheNextSpellConsumesIt) {
		auto player = beamPlayer(3);
		giveStance(player, AttrSubId_t::StanceMasterOfThunder);

		const auto cast = castBeam(player, COMBAT_ENERGYDAMAGE, "Energy Beam");
		ASSERT_TRUE(cast.flankRan);
		EXPECT_EQ(COMBAT_ENERGYDAMAGE, cast.central);
		EXPECT_EQ(COMBAT_ENERGYDAMAGE, cast.flank);
		EXPECT_EQ(COMBAT_ENERGYDAMAGE, player->getPendingElementalConversion()) << "armed once by the whole cast";

		// The next instant spell of another element is the one that gets it.
		EXPECT_EQ(COMBAT_ENERGYDAMAGE, runPass(player, COMBAT_FIREDAMAGE, "Great Fire Wave", false));
		EXPECT_EQ(COMBAT_NONE, player->getPendingElementalConversion());
		EXPECT_EQ(COMBAT_FIREDAMAGE, runPass(player, COMBAT_FIREDAMAGE, "Great Fire Wave", false)) << "and only that one";
	}

	TEST_F(BeamMasteryFlankStanceTest, DecayAndGreatDeathBeamArmOnceAcrossBothPasses) {
		auto player = beamPlayer(3);
		giveStance(player, AttrSubId_t::StanceMasterOfDecay);

		const auto cast = castBeam(player, COMBAT_DEATHDAMAGE, "Great Death Beam");
		ASSERT_TRUE(cast.flankRan);
		EXPECT_EQ(COMBAT_DEATHDAMAGE, cast.central);
		EXPECT_EQ(COMBAT_DEATHDAMAGE, cast.flank);
		EXPECT_EQ(COMBAT_DEATHDAMAGE, player->getPendingElementalConversion()) << "the flank did not re-arm or clear it";
	}

	// --- F) G) no conversion ------------------------------------------------------

	TEST_F(BeamMasteryFlankStanceTest, WithoutAStanceBothPassesKeepTheBeamsOwnElement) {
		auto player = beamPlayer(3);
		ASSERT_EQ(COMBAT_NONE, player->getElementalStanceElement());

		const auto energy = castBeam(player, COMBAT_ENERGYDAMAGE, "Energy Beam");
		EXPECT_EQ(COMBAT_ENERGYDAMAGE, energy.central);
		EXPECT_EQ(COMBAT_ENERGYDAMAGE, energy.flank);
		EXPECT_EQ(COMBAT_NONE, player->getPendingElementalConversion());

		const auto death = castBeam(player, COMBAT_DEATHDAMAGE, "Great Death Beam");
		EXPECT_EQ(COMBAT_DEATHDAMAGE, death.central);
		EXPECT_EQ(COMBAT_DEATHDAMAGE, death.flank);
		EXPECT_EQ(COMBAT_NONE, player->getPendingElementalConversion());
	}

	TEST_F(BeamMasteryFlankStanceTest, AHeldStanceWithNothingArmedConvertsNeitherPass) {
		auto player = beamPlayer(3);
		giveStance(player, AttrSubId_t::StanceMasterOfFlames);
		ASSERT_EQ(COMBAT_NONE, player->getPendingElementalConversion());

		const auto cast = castBeam(player, COMBAT_ENERGYDAMAGE, "Energy Beam");
		EXPECT_EQ(COMBAT_ENERGYDAMAGE, cast.central);
		EXPECT_EQ(COMBAT_ENERGYDAMAGE, cast.flank);
		EXPECT_EQ(COMBAT_NONE, player->getPendingElementalConversion());
	}

	// --- H) I) J) context isolation ----------------------------------------------

	TEST_F(BeamMasteryFlankStanceTest, AFlankNeverInheritsAnotherBeamsElement) {
		auto player = beamPlayer(3);
		giveStance(player, AttrSubId_t::StanceMasterOfFlames);
		player->setPendingElementalConversion(COMBAT_FIREDAMAGE);

		// Energy Beam's central pass resolves fire and publishes it.
		EXPECT_EQ(COMBAT_FIREDAMAGE, runPass(player, COMBAT_ENERGYDAMAGE, "Energy Beam", false));
		ASSERT_TRUE(player->beamMasteryCastContext().valid);

		// A flank tagged as another beam must not pick it up.
		EXPECT_EQ(COMBAT_DEATHDAMAGE, runPass(player, COMBAT_DEATHDAMAGE, "Great Death Beam", true)) << "its own element, never the other beam's";
		EXPECT_EQ(COMBAT_NONE, player->getPendingElementalConversion()) << "a flank never touches the armed conversion";
		EXPECT_TRUE(player->beamMasteryCastContext().valid) << "and never consumes a context that is not its own";
		EXPECT_EQ("Energy Beam", player->beamMasteryCastContext().spellName);
	}

	TEST_F(BeamMasteryFlankStanceTest, AnUnrelatedInstantSpellClearsAStaleContext) {
		auto player = beamPlayer(3);
		giveStance(player, AttrSubId_t::StanceMasterOfFlames);
		player->setPendingElementalConversion(COMBAT_FIREDAMAGE);

		EXPECT_EQ(COMBAT_FIREDAMAGE, runPass(player, COMBAT_ENERGYDAMAGE, "Energy Beam", false));
		ASSERT_TRUE(player->beamMasteryCastContext().valid);

		// The flank never ran. Any other non-flank instant cast invalidates it.
		runPass(player, COMBAT_FIREDAMAGE, "Great Fire Wave", false);
		EXPECT_FALSE(player->beamMasteryCastContext().valid);

		// A late flank can no longer inherit it.
		EXPECT_EQ(COMBAT_ENERGYDAMAGE, runPass(player, COMBAT_ENERGYDAMAGE, "Energy Beam", true));
	}

	TEST_F(BeamMasteryFlankStanceTest, StageZeroPublishesNoContext) {
		auto player = beamPlayer(0);
		ASSERT_EQ(0, player->wheel().getBeamMasteryAdjacentDamagePercent());
		giveStance(player, AttrSubId_t::StanceMasterOfFlames);
		player->setPendingElementalConversion(COMBAT_FIREDAMAGE);

		const auto cast = castBeam(player, COMBAT_ENERGYDAMAGE, "Energy Beam");
		EXPECT_FALSE(cast.flankRan) << "no adjacent damage, no flank execution";
		EXPECT_EQ(COMBAT_FIREDAMAGE, cast.central) << "an ordinary single spell cast, converted as always";
		EXPECT_EQ(COMBAT_NONE, player->getPendingElementalConversion());
		EXPECT_FALSE(player->beamMasteryCastContext().valid) << "nothing to inherit means nothing to publish";
	}

	// --- The beam set and the flank's hands-off rule -------------------------------

	TEST_F(BeamMasteryFlankStanceTest, TheBeamSetIsTheWheelsOwn) {
		auto without = std::make_shared<Player>();
		EXPECT_FALSE(without->wheel().isBeamMasterySpell("Energy Beam")) << "no Beam Mastery, no beam set";

		auto player = beamPlayer(1);
		EXPECT_TRUE(player->wheel().isBeamMasterySpell("Energy Beam"));
		EXPECT_TRUE(player->wheel().isBeamMasterySpell("Great Energy Beam"));
		EXPECT_TRUE(player->wheel().isBeamMasterySpell("Great Death Beam"));
		EXPECT_FALSE(player->wheel().isBeamMasterySpell("Great Fire Wave")) << "Beam Mastery is only the three beams";
		EXPECT_FALSE(player->wheel().isBeamMasterySpell(""));
	}

	TEST_F(BeamMasteryFlankStanceTest, AFlankNeverMutatesTheArmedConversion) {
		// Whatever the stance and whatever is armed, a flank execution on its own leaves
		// the armed element exactly as it found it.
		for (const auto stance : { AttrSubId_t::StanceMasterOfFlames, AttrSubId_t::StanceMasterOfThunder, AttrSubId_t::StanceMasterOfDecay }) {
			for (const auto armed : { COMBAT_NONE, COMBAT_FIREDAMAGE, COMBAT_ENERGYDAMAGE, COMBAT_DEATHDAMAGE }) {
				auto player = beamPlayer(3);
				giveStance(player, stance);
				player->setPendingElementalConversion(armed);

				runPass(player, COMBAT_ENERGYDAMAGE, "Energy Beam", true);
				EXPECT_EQ(armed, player->getPendingElementalConversion())
					<< "stance " << magic_enum::enum_integer(stance) << ", armed " << static_cast<int>(armed);
			}
		}
	}

	TEST_F(BeamMasteryFlankStanceTest, TheResolvedElementNeverReplacesTheNaturalOne) {
		// getCombatDamage records damage.naturalPrimaryType from the element the spell
		// had before this decision, on both passes. The decision only answers what the
		// execution deals, so the natural element it was handed is untouched by it -
		// which is what keeps natural-element critical and bonus rules on ENERGY while
		// the hit lands as FIRE.
		auto player = beamPlayer(3);
		giveStance(player, AttrSubId_t::StanceMasterOfFlames);
		player->setPendingElementalConversion(COMBAT_FIREDAMAGE);

		const ElementalStance::Pass central {
			.naturalType = COMBAT_ENERGYDAMAGE,
			.stanceElement = player->getElementalStanceElement(),
			.instantSpellName = "Energy Beam",
			.isFlank = false,
			.beamMasterySpell = true,
			.beamMasteryFlankActive = true,
		};
		CombatType_t pending = player->getPendingElementalConversion();
		EXPECT_EQ(COMBAT_FIREDAMAGE, ElementalStance::resolvePass(central, pending, player->beamMasteryCastContext()));
		EXPECT_EQ(COMBAT_ENERGYDAMAGE, central.naturalType) << "the natural element the caller records";
		player->setPendingElementalConversion(pending);

		const ElementalStance::Pass flank {
			.naturalType = COMBAT_ENERGYDAMAGE,
			.stanceElement = player->getElementalStanceElement(),
			.instantSpellName = "Energy Beam",
			.isFlank = true,
			.beamMasterySpell = true,
			.beamMasteryFlankActive = true,
		};
		EXPECT_EQ(COMBAT_FIREDAMAGE, ElementalStance::resolvePass(flank, pending, player->beamMasteryCastContext()));
		EXPECT_EQ(COMBAT_ENERGYDAMAGE, flank.naturalType) << "and it is still native on the flank";
	}
}
