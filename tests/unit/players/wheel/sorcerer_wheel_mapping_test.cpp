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
#include "creatures/combat/combat.hpp"
#include "io/io_wheel.hpp"
#include "utils/tools.hpp"

namespace {

	// The post-July Sorcerer Wheel. Two augment pairs changed what they apply to:
	// the old Magic Shield pair now carries Special Spells, and the old Sap Strength
	// pair - the spell this lane retired - now carries Death Echo. These tests pin
	// the mapping, the exact spell set and the exact augment values, because every
	// one of them is a decision that a later edit could silently undo.
	//
	// The bonus table and the slot grants are asserted separately on purpose: they
	// are two different code paths that have to agree, and the whole point of the
	// alias is that they cannot drift apart.
	class SorcererWheelMappingTest : public ::testing::Test {
	protected:
		IOWheel ioWheel;

		void SetUp() override {
			UPDATE_OTSYS_TIME();
			// Registers the tables and builds the slot function map. The spells
			// themselves are not loaded in a unit test, so the registration half
			// finds nothing to attach the bonuses to - the data this fixture reads
			// is filled in before that and is unaffected.
			ioWheel.initializeGlobalData(false);
		}

		const IOWheelBonusData::DataArray::Spells::Sorcerer &sorcerer(size_t index) const {
			return ioWheel.getWheelBonusData().spells.sorcerer.at(index);
		}

		// Runs the real slot function for a Sorcerer who has maxed that slot, and
		// answers which spells it granted.
		std::vector<std::string> grantedSpells(WheelSlots_t slot, uint8_t vocationCipId) const {
			auto player = std::make_shared<Player>();
			const uint16_t maxPoints = player->wheel().getMaxPointsPerSlot(slot);
			player->wheel().setTestSlotPoints(slot, maxPoints);

			PlayerWheelMethodsBonusData bonusData;
			const auto &functions = ioWheel.getWheelMapFunctions();
			const auto it = functions.find(slot);
			EXPECT_NE(functions.end(), it) << "slot " << static_cast<int>(slot) << " has no function";
			if (it == functions.end()) {
				return {};
			}
			it->second(player, maxPoints, vocationCipId, bonusData);
			return bonusData.spells;
		}

		static bool contains(const std::vector<std::string> &haystack, const std::string &needle) {
			return std::find(haystack.begin(), haystack.end(), needle) != haystack.end();
		}
	};

	// --- The Special Spells set -------------------------------------------------

	TEST_F(SorcererWheelMappingTest, SpecialSpellsIsExactlyThreeSpells) {
		const auto &special = ioWheel.getSpecialSpells();
		ASSERT_EQ(3u, special.size()) << "the set is exactly three spells, no more and no fewer";
		EXPECT_EQ("Lightning", special[0]);
		EXPECT_EQ("Strong Energy Strike", special[1]);
		EXPECT_EQ("Strong Flame Strike", special[2]);
	}

	TEST_F(SorcererWheelMappingTest, NoFourthSpellIsInTheSpecialSpellsSet) {
		// The mapping names three spells. The Ultimate strikes and every other strike
		// are deliberately out, and so is any generic class of spell.
		const auto &special = ioWheel.getSpecialSpells();
		for (const auto &name : { "Ultimate Energy Strike", "Ultimate Flame Strike", "Energy Strike", "Flame Strike", "Ice Strike", "Terra Strike", "Death Strike", "Divine Caldera" }) {
			EXPECT_FALSE(contains(special, name)) << name << " must not receive the Special Spells augments";
		}
	}

	TEST_F(SorcererWheelMappingTest, TheSpecialSpellsAugmentsAreMinusFourSecondsAndPlusFiftyPercent) {
		EXPECT_EQ(IOWheel::getSpecialSpellsAlias(), sorcerer(0).name);
		// Augment I.
		EXPECT_EQ(4, sorcerer(0).grade[1].decrease.cooldown) << "Augment I is -4 seconds of cooldown";
		EXPECT_EQ(0, sorcerer(0).grade[1].increase.damage) << "Augment I carries no damage";
		// Augment II.
		EXPECT_EQ(50, sorcerer(0).grade[2].increase.damage) << "Augment II is +50% base damage";
		EXPECT_EQ(0, sorcerer(0).grade[2].decrease.cooldown) << "Augment II carries no cooldown";
	}

	TEST_F(SorcererWheelMappingTest, MagicShieldNoLongerReceivesAnySorcererWheelAugment) {
		for (size_t i = 0; i < 5; ++i) {
			EXPECT_NE("Magic Shield", sorcerer(i).name) << "entry " << i << " still names Magic Shield";
		}
	}

	TEST_F(SorcererWheelMappingTest, TheOldMagicShieldSlotsNowGrantTheThreeSpecialSpells) {
		for (const auto slot : { WheelSlots_t::SLOT_GREEN_MIDDLE_100, WheelSlots_t::SLOT_PURPLE_TOP_100 }) {
			const auto granted = grantedSpells(slot, Vocation_t::VOCATION_SORCERER_CIP);
			EXPECT_EQ(3u, granted.size()) << "slot " << static_cast<int>(slot) << " grants all three at once";
			EXPECT_TRUE(contains(granted, "Lightning"));
			EXPECT_TRUE(contains(granted, "Strong Energy Strike"));
			EXPECT_TRUE(contains(granted, "Strong Flame Strike"));
			EXPECT_FALSE(contains(granted, "Magic Shield"));
			EXPECT_FALSE(contains(granted, IOWheel::getSpecialSpellsAlias())) << "the alias itself is never granted - it is not a spell";
		}
	}

	TEST_F(SorcererWheelMappingTest, TheOldMagicShieldSlotsAreUnchangedForEveryOtherVocation) {
		// The remap is the Sorcerer's alone.
		EXPECT_TRUE(contains(grantedSpells(WheelSlots_t::SLOT_GREEN_MIDDLE_100, Vocation_t::VOCATION_DRUID_CIP), "Mass Healing"));
		EXPECT_TRUE(contains(grantedSpells(WheelSlots_t::SLOT_GREEN_MIDDLE_100, Vocation_t::VOCATION_KNIGHT_CIP), "Groundshaker"));
		EXPECT_TRUE(contains(grantedSpells(WheelSlots_t::SLOT_PURPLE_TOP_100, Vocation_t::VOCATION_PALADIN_CIP), "Strong Ethereal Spear"));
		EXPECT_TRUE(contains(grantedSpells(WheelSlots_t::SLOT_PURPLE_TOP_100, Vocation_t::VOCATION_MONK_CIP), "Mass Spirit Mend"));
	}

	// --- Death Echo -------------------------------------------------------------

	TEST_F(SorcererWheelMappingTest, TheDeathEchoAugmentsAreMinusTwoSecondsAndPlusTwelvePercent) {
		EXPECT_EQ("Death Echo", sorcerer(1).name);
		EXPECT_EQ(2, sorcerer(1).grade[1].decrease.cooldown) << "Augment I is -2 seconds of cooldown";
		EXPECT_EQ(0, sorcerer(1).grade[1].increase.damage);
		// +12%, not the +8% of the original release: CipSoft raised it on 7 July.
		EXPECT_EQ(12, sorcerer(1).grade[2].increase.damage) << "Augment II is +12% base damage, the post-July value";
		EXPECT_EQ(0, sorcerer(1).grade[2].decrease.cooldown);
	}

	TEST_F(SorcererWheelMappingTest, TheOldSapStrengthSlotsNowGrantDeathEcho) {
		for (const auto slot : { WheelSlots_t::SLOT_RED_MIDDLE_100, WheelSlots_t::SLOT_BLUE_MIDDLE_100 }) {
			const auto granted = grantedSpells(slot, Vocation_t::VOCATION_SORCERER_CIP);
			EXPECT_TRUE(contains(granted, "Death Echo")) << "slot " << static_cast<int>(slot) << " grants no Death Echo";
			EXPECT_FALSE(granted.empty()) << "a Sorcerer must not lose this slot's spell entirely";
		}
	}

	TEST_F(SorcererWheelMappingTest, TheDruidKeepsNaturesEmbraceInThoseSlots) {
		for (const auto slot : { WheelSlots_t::SLOT_RED_MIDDLE_100, WheelSlots_t::SLOT_BLUE_MIDDLE_100 }) {
			const auto granted = grantedSpells(slot, Vocation_t::VOCATION_DRUID_CIP);
			EXPECT_TRUE(contains(granted, "Nature's Embrace"));
			EXPECT_FALSE(contains(granted, "Death Echo")) << "Death Echo is the Sorcerer's, not the Druid's";
		}
	}

	TEST_F(SorcererWheelMappingTest, SapStrengthIsNotReintroducedAnywhereOnTheWheel) {
		// The castable spell was retired with its scripts; the Wheel must not bring it
		// back by name, in any vocation's table.
		const auto &data = ioWheel.getWheelBonusData().spells;
		for (size_t i = 0; i < 5; ++i) {
			EXPECT_NE("Sap Strength", data.sorcerer.at(i).name);
			EXPECT_NE("Sap Strength", data.druid.at(i).name);
			EXPECT_NE("Sap Strength", data.knight.at(i).name);
			EXPECT_NE("Sap Strength", data.paladin.at(i).name);
			EXPECT_NE("Sap Strength", data.monk.at(i).name);
			EXPECT_NE("Expose Weakness", data.sorcerer.at(i).name);
		}
	}

	TEST_F(SorcererWheelMappingTest, EverySorcererEntryNamesSomething) {
		// The nameless entry this lane left behind while the mapping was unproven is
		// gone: an empty name registers nothing, which was safe but meant a Sorcerer
		// got no spell from two maxed slots.
		for (size_t i = 0; i < 5; ++i) {
			EXPECT_FALSE(sorcerer(i).name.empty()) << "sorcerer entry " << i << " is nameless";
		}
	}

	TEST_F(SorcererWheelMappingTest, NoWheelEntryNamesASpellTheDatapackCannotResolve) {
		// Every name the tables carry is either a real spell or an alias that expands
		// to real spells. A name that is neither makes registerWheelSpellTable warn,
		// and the runtime smoke test fails the build on any warning line - which is
		// exactly how the retired Sap Strength was caught.
		const auto &data = ioWheel.getWheelBonusData().spells;
		const std::vector<std::string> aliases { "Any_Focus_Mage_Spell", IOWheel::getSpecialSpellsAlias() };
		const auto isAlias = [&aliases](const std::string &name) {
			return std::find(aliases.begin(), aliases.end(), name) != aliases.end();
		};

		size_t named = 0;
		for (size_t i = 0; i < 5; ++i) {
			for (const auto &name : { data.sorcerer.at(i).name, data.druid.at(i).name, data.knight.at(i).name, data.paladin.at(i).name, data.monk.at(i).name }) {
				if (name.empty()) {
					continue;
				}
				++named;
				// An alias is resolved through the shared list; a plain name is a spell
				// the datapack has to define, which the runtime smoke test proves.
				EXPECT_FALSE(name.find('_') != std::string::npos && !isAlias(name))
					<< "'" << name << "' looks like an alias but is not a known one";
			}
		}
		EXPECT_EQ(25u, named) << "every vocation entry should be named";
	}

	// --- Beam Mastery -----------------------------------------------------------

	TEST_F(SorcererWheelMappingTest, BeamMasteryAdjacentDamageIsTwentyFiveFortySeventy) {
		auto player = std::make_shared<Player>();
		EXPECT_EQ(0, player->wheel().getBeamMasteryAdjacentDamagePercent()) << "no stage, no adjacent damage";

		player->wheel().setStage(WheelStage_t::BEAM_MASTERY, 1);
		EXPECT_EQ(25, player->wheel().getBeamMasteryAdjacentDamagePercent());
		player->wheel().setStage(WheelStage_t::BEAM_MASTERY, 2);
		EXPECT_EQ(40, player->wheel().getBeamMasteryAdjacentDamagePercent());
		player->wheel().setStage(WheelStage_t::BEAM_MASTERY, 3);
		EXPECT_EQ(70, player->wheel().getBeamMasteryAdjacentDamagePercent());
	}

	TEST_F(SorcererWheelMappingTest, TheCentralBeamKeepsItsOwnPerTargetIncrease) {
		// The adjacent scale is a second, separate number. Overwriting the central
		// beam's per-target damage increase with 25/40/70 is the mistake this pins.
		auto player = std::make_shared<Player>();
		EXPECT_EQ(0, player->wheel().checkBeamMasteryDamage());

		player->wheel().setStage(WheelStage_t::BEAM_MASTERY, 1);
		EXPECT_EQ(10, player->wheel().checkBeamMasteryDamage());
		player->wheel().setStage(WheelStage_t::BEAM_MASTERY, 2);
		EXPECT_EQ(12, player->wheel().checkBeamMasteryDamage());
		player->wheel().setStage(WheelStage_t::BEAM_MASTERY, 3);
		EXPECT_EQ(14, player->wheel().checkBeamMasteryDamage());
	}

	TEST_F(SorcererWheelMappingTest, TheTwoBeamMasteryScalesAreNeverTheSameNumber) {
		auto player = std::make_shared<Player>();
		for (uint8_t stage = 1; stage <= 3; ++stage) {
			player->wheel().setStage(WheelStage_t::BEAM_MASTERY, stage);
			EXPECT_NE(player->wheel().checkBeamMasteryDamage(), player->wheel().getBeamMasteryAdjacentDamagePercent())
				<< "stage " << static_cast<int>(stage) << ": the central and adjacent scales collapsed into one";
		}
	}

	// --- The Beam Mastery flank pass -------------------------------------------
	//
	// The flank Combat carries the same instant spell name as the central beam - it has
	// to, so that spell augments, the elemental stance and the natural-element rules all
	// apply to it. That means the name cannot tell the two passes apart, and without an
	// explicit flag the flank's targets would be counted as central ones: they would
	// feed the per-target cooldown reduction and take the central damage increase.

	TEST_F(SorcererWheelMappingTest, ACombatIsNotAFlankPassUnlessItSaysSo) {
		Combat combat;
		EXPECT_FALSE(combat.getCombatParams().beamMasteryFlank) << "the default must be the central beam";
	}

	TEST_F(SorcererWheelMappingTest, TheFlankParameterIsSettableAndClearable) {
		Combat combat;
		ASSERT_TRUE(combat.setParam(COMBAT_PARAM_BEAM_MASTERY_FLANK, 1));
		EXPECT_TRUE(combat.getCombatParams().beamMasteryFlank);

		ASSERT_TRUE(combat.setParam(COMBAT_PARAM_BEAM_MASTERY_FLANK, 0));
		EXPECT_FALSE(combat.getCombatParams().beamMasteryFlank) << "false must be honoured, not just true";
	}

	TEST_F(SorcererWheelMappingTest, TheFlankParameterDoesNotDisturbAnyOtherCombatParameter) {
		// A new parameter that quietly changed another one would be a nasty way to break
		// an unrelated spell.
		Combat combat;
		ASSERT_TRUE(combat.setParam(COMBAT_PARAM_TYPE, COMBAT_DEATHDAMAGE));
		ASSERT_TRUE(combat.setParam(COMBAT_PARAM_AGGRESSIVE, 1));
		ASSERT_TRUE(combat.setParam(COMBAT_PARAM_NOCHARM, 1));
		ASSERT_TRUE(combat.setParam(COMBAT_PARAM_BEAM_MASTERY_FLANK, 1));

		const auto &params = combat.getCombatParams();
		EXPECT_TRUE(params.beamMasteryFlank);
		EXPECT_EQ(COMBAT_DEATHDAMAGE, params.combatType);
		EXPECT_TRUE(params.aggressive);
		EXPECT_TRUE(params.noCharm);
	}

	TEST_F(SorcererWheelMappingTest, OnlyABeamSpellGetsTheCentralTargetAccounting) {
		// getBeamAffectedTotal is what CombatFunc consults for the central pass, and it
		// answers only for a spell in the Beam Mastery set. CombatFunc skips the call
		// entirely when params.beamMasteryFlank is set, which is what keeps a flank hit
		// out of the count; this pins the other half - an unrelated spell was never in
		// the count to begin with.
		auto player = std::make_shared<Player>();
		player->wheel().setStage(WheelStage_t::BEAM_MASTERY, 3);
		ASSERT_TRUE(player->wheel().getInstant("Beam Mastery"));

		CombatDamage damage;
		damage.instantSpellName = "Death Echo";
		EXPECT_EQ(0, player->wheel().getBeamAffectedTotal(damage)) << "a non-beam spell must never be counted";

		damage.instantSpellName.clear();
		EXPECT_EQ(0, player->wheel().getBeamAffectedTotal(damage)) << "and neither must an unnamed one";
	}

	TEST_F(SorcererWheelMappingTest, TheAdjacentPercentIsWhatTheDatapackWillRead) {
		// player:getBeamMasteryAdjacentDamage() returns exactly this, and a beam script
		// divides it by 100 to get its factor. Zero means the flank does not execute.
		auto player = std::make_shared<Player>();
		EXPECT_EQ(0, player->wheel().getBeamMasteryAdjacentDamagePercent());

		const std::array<std::pair<uint8_t, int32_t>, 3> expectations { { { 1, 25 }, { 2, 40 }, { 3, 70 } } };
		for (const auto &[stage, percent] : expectations) {
			player->wheel().setStage(WheelStage_t::BEAM_MASTERY, stage);
			EXPECT_EQ(percent, player->wheel().getBeamMasteryAdjacentDamagePercent()) << "stage " << static_cast<int>(stage);
			// The factor the datapack computes, stated as the arithmetic it performs.
			EXPECT_DOUBLE_EQ(percent / 100.0, player->wheel().getBeamMasteryAdjacentDamagePercent() / 100.0);
		}
	}

}
