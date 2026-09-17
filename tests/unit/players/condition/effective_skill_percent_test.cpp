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
#include "io/fileloader.hpp"
#include "utils/tools.hpp"

namespace {

	// A percent skill recipe - Blood Rage +25% melee, Protector +30% shielding,
	// Sharpshooter +32% distance - scales the player's TOTAL skill, equipment and
	// other flat bonuses included, and it must do that without ever scaling what a
	// percent recipe itself added. These tests pin both halves: the value it lands
	// on, and that applying it again, reloading it or changing the equipment under
	// it never compounds.
	//
	// A Player with no vocation is used on purpose: getLoyaltySkill returns the base
	// skill unchanged, so the trained skill is exactly 10 and every number below is
	// arithmetic rather than a curve.
	class EffectiveSkillPercentTest : public ::testing::Test {
	protected:
		static constexpr int32_t kTrainedSkill = 10;
		// 10 trained + 95 = 105 Distance, for the tests that move Positional Tactics'
		// +3 under an active stance. NOT the 100 the other tests use: 32% of 100 and
		// 32% of 103 both truncate to 32, so at 100 a stance that never re-derived
		// would land on the right answer by accident. 105 -> 33 and 108 -> 34 do not.
		static constexpr int32_t kDistanceEquipment = 95;

		void SetUp() override {
			UPDATE_OTSYS_TIME();
		}

		// A stance: persistent, +percent on one skill.
		static std::shared_ptr<Condition> percentStance(AttrSubId_t stance, ConditionParam_t param, int32_t percent) {
			auto condition = Condition::createCondition(CONDITIONID_COMBAT, CONDITION_ATTRIBUTES, -1, 0, false, magic_enum::enum_integer(stance), true);
			EXPECT_NE(nullptr, condition);
			EXPECT_TRUE(condition->setParam(param, percent));
			return condition;
		}

		// Sharpshooter: +32% Distance Fighting.
		static std::shared_ptr<Condition> sharpshooter() {
			return percentStance(AttrSubId_t::StanceSharpshooter, CONDITION_PARAM_SKILL_DISTANCEPERCENT, 132);
		}

		// Equipment, an imbuement or a flat condition bonus all arrive the same way.
		static void equipFlatDistance(const std::shared_ptr<Player> &player, int32_t amount) {
			player->setVarSkill(SKILL_DISTANCE, amount);
		}

		static void equipFlatShielding(const std::shared_ptr<Player> &player, int32_t amount) {
			player->setVarSkill(SKILL_SHIELD, amount);
		}

		// Protector: +30% Shielding.
		static std::shared_ptr<Condition> protector() {
			return percentStance(AttrSubId_t::StanceProtector, CONDITION_PARAM_SKILL_SHIELDPERCENT, 130);
		}

		static std::shared_ptr<Condition> readBack(PropWriteStream &out) {
			size_t size = 0;
			const char* bytes = out.getStream(size);
			PropStream in;
			in.init(bytes, size);
			auto restored = Condition::createCondition(in);
			if (restored && !restored->unserialize(in)) {
				return nullptr;
			}
			return restored;
		}
	};

	TEST_F(EffectiveSkillPercentTest, TheTrainedSkillIsTheStartingPoint) {
		auto player = std::make_shared<Player>();
		EXPECT_EQ(kTrainedSkill, player->getBaseSkill(SKILL_DISTANCE));
		EXPECT_EQ(kTrainedSkill, player->getSkillLevel(SKILL_DISTANCE));
		EXPECT_EQ(kTrainedSkill, player->getSkillLevelForPercentScaling(SKILL_DISTANCE));
	}

	TEST_F(EffectiveSkillPercentTest, ThirtyPercentOfOneHundredIsOneHundredAndThirty) {
		// The brief's own example: base 100, +30%, 130.
		auto player = std::make_shared<Player>();
		equipFlatDistance(player, 90); // 10 trained + 90 equipment = 100
		ASSERT_EQ(100, player->getSkillLevel(SKILL_DISTANCE));

		ASSERT_TRUE(player->addCondition(percentStance(AttrSubId_t::StanceSharpshooter, CONDITION_PARAM_SKILL_DISTANCEPERCENT, 130)));
		EXPECT_EQ(130, player->getSkillLevel(SKILL_DISTANCE));
	}

	TEST_F(EffectiveSkillPercentTest, EquipmentCountsTowardsThePercentage) {
		// The 15.25 rule the old base-skill computation could not express.
		auto player = std::make_shared<Player>();
		ASSERT_TRUE(player->addCondition(sharpshooter()));
		EXPECT_EQ(kTrainedSkill + 3, player->getSkillLevel(SKILL_DISTANCE)) << "32% of 10 is 3.2, truncated";

		equipFlatDistance(player, 90); // now 100 before the percentage
		EXPECT_EQ(132, player->getSkillLevel(SKILL_DISTANCE)) << "the bonus follows the equipment up";

		equipFlatDistance(player, -90);
		EXPECT_EQ(kTrainedSkill + 3, player->getSkillLevel(SKILL_DISTANCE)) << "and back down, to exactly where it was";
	}

	TEST_F(EffectiveSkillPercentTest, ThePercentageNeverScalesWhatItAlreadyAdded) {
		// The self-referential loop the brief warns about: if the recipe read the
		// player's current total, 100 -> 130 -> 169 -> 219 on every refresh.
		auto player = std::make_shared<Player>();
		equipFlatDistance(player, 90);
		ASSERT_TRUE(player->addCondition(percentStance(AttrSubId_t::StanceSharpshooter, CONDITION_PARAM_SKILL_DISTANCEPERCENT, 130)));
		ASSERT_EQ(130, player->getSkillLevel(SKILL_DISTANCE));

		for (int i = 0; i < 5; ++i) {
			player->refreshPercentSkillRecipes();
			EXPECT_EQ(130, player->getSkillLevel(SKILL_DISTANCE)) << "refresh " << i << " compounded";
			EXPECT_EQ(100, player->getSkillLevelForPercentScaling(SKILL_DISTANCE)) << "the source must stay the pre-percent skill";
		}
	}

	TEST_F(EffectiveSkillPercentTest, RecastingTheStanceAppliesItOnceAndRemovingItTakesItAllOff) {
		auto player = std::make_shared<Player>();
		equipFlatDistance(player, 90);
		const auto before = player->getSkillLevel(SKILL_DISTANCE);

		ASSERT_TRUE(player->addCondition(sharpshooter()));
		const auto withStance = player->getSkillLevel(SKILL_DISTANCE);
		EXPECT_EQ(132, withStance);

		ASSERT_TRUE(player->addCondition(sharpshooter())); // a merge, not a second stance
		EXPECT_EQ(withStance, player->getSkillLevel(SKILL_DISTANCE));

		const auto &held = player->getCondition(CONDITION_ATTRIBUTES, CONDITIONID_COMBAT, magic_enum::enum_integer(AttrSubId_t::StanceSharpshooter));
		ASSERT_NE(nullptr, held);
		player->removeCondition(held);
		EXPECT_EQ(before, player->getSkillLevel(SKILL_DISTANCE));
	}

	TEST_F(EffectiveSkillPercentTest, TwoPercentRecipesOnOneSkillAddAndDoNotMultiply) {
		// Each reads the same pre-percent source, so the order they arrive in cannot
		// change the answer: 100 + 30 + 20, never 100 x 1.3 x 1.2.
		auto player = std::make_shared<Player>();
		equipFlatDistance(player, 90);

		ASSERT_TRUE(player->addCondition(percentStance(AttrSubId_t::StanceSharpshooter, CONDITION_PARAM_SKILL_DISTANCEPERCENT, 130)));
		ASSERT_TRUE(player->addCondition(percentStance(AttrSubId_t::StanceDivineDefiance, CONDITION_PARAM_SKILL_DISTANCEPERCENT, 120)));
		EXPECT_EQ(150, player->getSkillLevel(SKILL_DISTANCE));

		auto reversed = std::make_shared<Player>();
		equipFlatDistance(reversed, 90);
		ASSERT_TRUE(reversed->addCondition(percentStance(AttrSubId_t::StanceDivineDefiance, CONDITION_PARAM_SKILL_DISTANCEPERCENT, 120)));
		ASSERT_TRUE(reversed->addCondition(percentStance(AttrSubId_t::StanceSharpshooter, CONDITION_PARAM_SKILL_DISTANCEPERCENT, 130)));
		EXPECT_EQ(150, reversed->getSkillLevel(SKILL_DISTANCE)) << "the order must not matter";

		// And removing one leaves exactly the other.
		const auto &defiance = reversed->getCondition(CONDITION_ATTRIBUTES, CONDITIONID_COMBAT, magic_enum::enum_integer(AttrSubId_t::StanceDivineDefiance));
		ASSERT_NE(nullptr, defiance);
		reversed->removeCondition(defiance);
		EXPECT_EQ(130, reversed->getSkillLevel(SKILL_DISTANCE));
	}

	TEST_F(EffectiveSkillPercentTest, ARelogRestoresTheBonusExactlyOnce) {
		PropWriteStream out;
		sharpshooter()->serialize(out);
		out.write<uint8_t>(CONDITIONATTR_END);

		auto restored = readBack(out);
		ASSERT_NE(nullptr, restored);

		auto player = std::make_shared<Player>();
		equipFlatDistance(player, 90);
		ASSERT_TRUE(player->addCondition(restored));
		EXPECT_EQ(132, player->getSkillLevel(SKILL_DISTANCE));
		EXPECT_EQ(100, player->getSkillLevelForPercentScaling(SKILL_DISTANCE));
	}

	TEST_F(EffectiveSkillPercentTest, ASavedStanceCarriesTheRecipeAndNotTheValueItProduced) {
		// The blob holds the percentage; the flat slot for that skill stays empty, so
		// a login on a player whose equipment changed derives the new value instead of
		// restoring the old one.
		auto player = std::make_shared<Player>();
		equipFlatDistance(player, 90);
		auto stance = sharpshooter();
		ASSERT_TRUE(player->addCondition(stance));
		ASSERT_EQ(132, player->getSkillLevel(SKILL_DISTANCE));

		PropWriteStream out;
		stance->serialize(out);
		out.write<uint8_t>(CONDITIONATTR_END);
		auto restored = readBack(out);
		ASSERT_NE(nullptr, restored);

		auto poorer = std::make_shared<Player>(); // same stance, no equipment at all
		ASSERT_TRUE(poorer->addCondition(restored));
		EXPECT_EQ(kTrainedSkill + 3, poorer->getSkillLevel(SKILL_DISTANCE)) << "32% of 10, not the 32 the richer player had";
	}

	TEST_F(EffectiveSkillPercentTest, AFlatRecipeAndAPercentRecipeCoexistWithoutEitherLeaking) {
		auto player = std::make_shared<Player>();
		equipFlatDistance(player, 90);

		auto flat = Condition::createCondition(CONDITIONID_COMBAT, CONDITION_ATTRIBUTES, 5000, 0, false, 77);
		ASSERT_NE(nullptr, flat);
		ASSERT_TRUE(flat->setParam(CONDITION_PARAM_SKILL_DISTANCE, 10));
		ASSERT_TRUE(player->addCondition(flat));
		ASSERT_EQ(110, player->getSkillLevel(SKILL_DISTANCE));

		ASSERT_TRUE(player->addCondition(percentStance(AttrSubId_t::StanceSharpshooter, CONDITION_PARAM_SKILL_DISTANCEPERCENT, 130)));
		EXPECT_EQ(143, player->getSkillLevel(SKILL_DISTANCE)) << "30% of 110, the flat condition counted as a source";

		player->removeCondition(flat);
		EXPECT_EQ(130, player->getSkillLevel(SKILL_DISTANCE)) << "the flat bonus and its share of the percentage both leave";

		const auto &stance = player->getCondition(CONDITION_ATTRIBUTES, CONDITIONID_COMBAT, magic_enum::enum_integer(AttrSubId_t::StanceSharpshooter));
		ASSERT_NE(nullptr, stance);
		player->removeCondition(stance);
		EXPECT_EQ(100, player->getSkillLevel(SKILL_DISTANCE));
	}

	TEST_F(EffectiveSkillPercentTest, AWeaponProficiencySkillBonusAlreadyHeldCountsTowardsThePercentage) {
		// Weapon Proficiency adds its skill bonus inside getSkillLevel, so it is part of
		// the skill the player actually has and the percentage scales from it - the same
		// rule equipment gets. The proficiency's own percentage perks keep reading the
		// total skill, which is what they already did.
		auto player = std::make_shared<Player>();
		equipFlatDistance(player, 90);
		player->weaponProficiency().addSkillBonus(SKILL_DISTANCE, 20);
		ASSERT_EQ(120, player->getSkillLevel(SKILL_DISTANCE));
		ASSERT_EQ(120, player->getSkillLevelForPercentScaling(SKILL_DISTANCE));

		ASSERT_TRUE(player->addCondition(percentStance(AttrSubId_t::StanceSharpshooter, CONDITION_PARAM_SKILL_DISTANCEPERCENT, 130)));
		EXPECT_EQ(156, player->getSkillLevel(SKILL_DISTANCE)) << "30% of 120";
		EXPECT_EQ(120, player->getSkillLevelForPercentScaling(SKILL_DISTANCE)) << "and the source is still the pre-percent skill";
	}

	TEST_F(EffectiveSkillPercentTest, AProficiencyBonusGainedWhileTheStanceIsOnRecalculatesAtOnce) {
		// The order that matters. Weapon Proficiency writes its skill bonus straight
		// into its own array and never goes through Player::setVarSkill, so with the
		// stance already active nothing would ask for the re-derivation unless the
		// component asks for it itself - the bonus would sit in the player's skill
		// while the percentage went on scaling from the skill he had before it.
		auto player = std::make_shared<Player>();
		equipFlatDistance(player, 90);
		ASSERT_TRUE(player->addCondition(sharpshooter()));
		ASSERT_EQ(132, player->getSkillLevel(SKILL_DISTANCE));

		player->weaponProficiency().addSkillBonus(SKILL_DISTANCE, 20);
		EXPECT_EQ(120, player->getSkillLevelForPercentScaling(SKILL_DISTANCE)) << "10 trained + 90 equipment + 20 proficiency";
		EXPECT_EQ(158, player->getSkillLevel(SKILL_DISTANCE)) << "32% of 120 is 38, on top of 10 + 90 + 20";

		for (int i = 0; i < 3; ++i) {
			player->refreshPercentSkillRecipes();
			EXPECT_EQ(158, player->getSkillLevel(SKILL_DISTANCE)) << "refresh " << i << " compounded";
		}

		player->weaponProficiency().resetSkillBonuses();
		EXPECT_EQ(132, player->getSkillLevel(SKILL_DISTANCE)) << "clearing it takes the bonus and its share of the percentage";
		EXPECT_EQ(100, player->getSkillLevelForPercentScaling(SKILL_DISTANCE));
	}

	TEST_F(EffectiveSkillPercentTest, AWheelSkillStatGainedWhileTheStanceIsOnRecalculatesAtOnce) {
		// Same rule, same reason: the Wheel's skill stats are part of the skill the
		// player has and never pass through setVarSkill either.
		auto player = std::make_shared<Player>();
		equipFlatDistance(player, 90);
		ASSERT_TRUE(player->addCondition(sharpshooter()));
		ASSERT_EQ(132, player->getSkillLevel(SKILL_DISTANCE));

		player->wheel().addStat(WheelStat_t::DISTANCE, 20);
		EXPECT_EQ(120, player->getSkillLevelForPercentScaling(SKILL_DISTANCE));
		EXPECT_EQ(158, player->getSkillLevel(SKILL_DISTANCE));

		for (int i = 0; i < 3; ++i) {
			player->refreshPercentSkillRecipes();
			EXPECT_EQ(158, player->getSkillLevel(SKILL_DISTANCE)) << "refresh " << i << " compounded";
		}

		player->wheel().resetStats();
		EXPECT_EQ(132, player->getSkillLevel(SKILL_DISTANCE));
		EXPECT_EQ(100, player->getSkillLevelForPercentScaling(SKILL_DISTANCE));
	}

	TEST_F(EffectiveSkillPercentTest, ProficiencyAndWheelStackOnTheSameSkillWithoutCompounding) {
		// Both sources at once, added after the stance: they add to the source, the
		// percentage is taken once against the sum, and removing them unwinds exactly.
		auto player = std::make_shared<Player>();
		equipFlatDistance(player, 90);
		ASSERT_TRUE(player->addCondition(sharpshooter()));

		player->weaponProficiency().addSkillBonus(SKILL_DISTANCE, 20);
		player->wheel().addStat(WheelStat_t::DISTANCE, 20);
		EXPECT_EQ(140, player->getSkillLevelForPercentScaling(SKILL_DISTANCE));
		EXPECT_EQ(184, player->getSkillLevel(SKILL_DISTANCE)) << "32% of 140 is 44, on top of 10 + 90 + 20 + 20";

		player->wheel().resetStats();
		EXPECT_EQ(158, player->getSkillLevel(SKILL_DISTANCE));
		player->weaponProficiency().resetSkillBonuses();
		EXPECT_EQ(132, player->getSkillLevel(SKILL_DISTANCE));

		const auto &stance = player->getCondition(CONDITION_ATTRIBUTES, CONDITIONID_COMBAT, magic_enum::enum_integer(AttrSubId_t::StanceSharpshooter));
		ASSERT_NE(nullptr, stance);
		player->removeCondition(stance);
		EXPECT_EQ(100, player->getSkillLevel(SKILL_DISTANCE));
	}

	TEST_F(EffectiveSkillPercentTest, TheBaseSkillStaysRawThroughoutAndUnrelatedSkillsAreUntouched) {
		auto player = std::make_shared<Player>();
		equipFlatDistance(player, 90);
		const auto swordBefore = player->getSkillLevel(SKILL_SWORD);

		ASSERT_TRUE(player->addCondition(sharpshooter()));

		EXPECT_EQ(kTrainedSkill, player->getBaseSkill(SKILL_DISTANCE)) << "getBaseSkill is the trained skill and nothing else";
		EXPECT_EQ(swordBefore, player->getSkillLevel(SKILL_SWORD));
		EXPECT_EQ(swordBefore, player->getSkillLevelForPercentScaling(SKILL_SWORD));
	}

	TEST_F(EffectiveSkillPercentTest, AConditionsOwnFlatRecipeCountsTowardsItsOwnPercentage) {
		// A condition carrying both recipes applies the flat one first, so the
		// percentage scales from a skill that already includes it, once and for good.
		// Deriving first and applying the flat afterwards left the value short until
		// the next unrelated refresh silently corrected it - which is the kind of
		// "it depends when you look" this whole design exists to rule out.
		auto player = std::make_shared<Player>();
		equipFlatDistance(player, 90); // 100 before the condition

		auto both = sharpshooter();
		ASSERT_TRUE(both->setParam(CONDITION_PARAM_SKILL_DISTANCE, 32));
		ASSERT_TRUE(player->addCondition(both));
		EXPECT_EQ(174, player->getSkillLevel(SKILL_DISTANCE)) << "100 + 32 flat, then 32% of the 132 that makes";
		EXPECT_EQ(132, player->getSkillLevelForPercentScaling(SKILL_DISTANCE));

		// Settled: refreshing again moves nothing.
		for (int i = 0; i < 3; ++i) {
			player->refreshPercentSkillRecipes();
			EXPECT_EQ(174, player->getSkillLevel(SKILL_DISTANCE)) << "refresh " << i << " moved a settled value";
		}
	}

	TEST_F(EffectiveSkillPercentTest, APreSeparationBlobDropsTheStaleDerivedValue) {
		// A blob written before the recipes were kept apart saved the percentage AND
		// the flat value it had produced, in the same slot a flat recipe uses.
		// Restoring both would hand every existing player a doubled bonus on their
		// first login after this change.
		//
		// The condition below carries both on purpose: 32 in the flat slot, as an old
		// build would have left behind, and the +32% recipe.
		auto stance = sharpshooter();
		ASSERT_TRUE(stance->setParam(CONDITION_PARAM_SKILL_DISTANCE, 32));

		PropWriteStream out;
		stance->serialize(out);
		out.write<uint8_t>(CONDITIONATTR_END);

		size_t size = 0;
		const char* bytes = out.getStream(size);
		std::string blob(bytes, size);

		// Condition::serialize writes a fixed 27-byte header (type, id, ticks, isBuff,
		// subId, tickSound, addSound, persistent) and ConditionAttributes::serialize
		// puts the marker first, so it is exactly one byte in at a known offset. The
		// assertion is the guard: if the header ever changes shape, this fails here
		// rather than silently testing the wrong blob.
		constexpr size_t kHeaderSize = 27;
		ASSERT_GT(blob.size(), kHeaderSize);
		ASSERT_EQ(static_cast<char>(CONDITIONATTR_PERCENT_RECIPES_SEPARATE), blob[kHeaderSize]);

		// With the marker: both recipes are real and both apply.
		{
			PropStream in;
			in.init(blob.data(), blob.size());
			auto restored = Condition::createCondition(in);
			ASSERT_NE(nullptr, restored);
			ASSERT_TRUE(restored->unserialize(in));

			auto player = std::make_shared<Player>();
			equipFlatDistance(player, 90);
			ASSERT_TRUE(player->addCondition(restored));
			EXPECT_EQ(174, player->getSkillLevel(SKILL_DISTANCE)) << "100 + 32 flat, then 32% of the 132 that makes";
		}

		// Without it, the blob is a pre-separation one: the flat 32 is the stale copy
		// of what the percentage produced, and only the percentage counts.
		{
			std::string legacy = blob;
			legacy.erase(kHeaderSize, 1);

			PropStream in;
			in.init(legacy.data(), legacy.size());
			auto restored = Condition::createCondition(in);
			ASSERT_NE(nullptr, restored);
			ASSERT_TRUE(restored->unserialize(in));

			auto player = std::make_shared<Player>();
			equipFlatDistance(player, 90);
			ASSERT_TRUE(player->addCondition(restored));
			EXPECT_EQ(132, player->getSkillLevel(SKILL_DISTANCE)) << "the percentage applies once, and the stale flat copy is gone";
		}
	}

	// --- The dynamic Wheel conditional bonuses -----------------------------------
	//
	// Positional Tactics and Battle Instinct do not add a stored skill stat: they move
	// a major stat that Player::computeSkillLevel reads back through
	// getMajorStatConditional, on and off, several times a minute, from onThink. That
	// makes them a skill source like any other, and an active percent stance has to
	// follow them the moment they move - not at the next equipment change, recast or
	// relog.
	//
	// The counting of adjacent monsters needs a map, so these drive the two production
	// helpers the ability functions delegate to: applyBattleInstinct /
	// applyPositionalTactics make the change, flushConditionalSkillSources is the end
	// of the evaluation, exactly as onThink and checkAbilities call them. Neither test
	// calls refreshPercentSkillRecipes: deleting the invalidation would fail them.

	TEST_F(EffectiveSkillPercentTest, PositionalTacticsDistanceMovesTheStanceWhileItIsActive) {
		auto player = std::make_shared<Player>();
		equipFlatDistance(player, kDistanceEquipment);

		// The stance goes on FIRST. The reverse order passes with or without the bug.
		ASSERT_TRUE(player->addCondition(sharpshooter()));
		ASSERT_EQ(105, player->getSkillLevelForPercentScaling(SKILL_DISTANCE));
		ASSERT_EQ(138, player->getSkillLevel(SKILL_DISTANCE)) << "32% of 105 is 33";

		player->wheel().setSpellInstant("Positional Tactics", true);

		// No monster adjacent: Positional Tactics grants its +3 Distance.
		EXPECT_TRUE(player->wheel().applyPositionalTactics(0));
		EXPECT_EQ(108, player->getSkillLevelForPercentScaling(SKILL_DISTANCE)) << "the conditional bonus is part of the source";
		EXPECT_TRUE(player->wheel().flushConditionalSkillSources()) << "the evaluation has to report that a skill moved";
		EXPECT_EQ(142, player->getSkillLevel(SKILL_DISTANCE)) << "32% of 108 is 34, on top of 108; a stance still derived from 105 gives 141";

		// A monster steps next to the player: the bonus goes away again.
		EXPECT_TRUE(player->wheel().applyPositionalTactics(1));
		EXPECT_EQ(105, player->getSkillLevelForPercentScaling(SKILL_DISTANCE));
		EXPECT_TRUE(player->wheel().flushConditionalSkillSources());
		EXPECT_EQ(138, player->getSkillLevel(SKILL_DISTANCE)) << "and the percentage unwinds to exactly where it was";
	}

	TEST_F(EffectiveSkillPercentTest, PositionalTacticsCyclesDoNotCompound) {
		auto player = std::make_shared<Player>();
		equipFlatDistance(player, kDistanceEquipment);
		ASSERT_TRUE(player->addCondition(sharpshooter()));
		player->wheel().setSpellInstant("Positional Tactics", true);

		for (int cycle = 0; cycle < 5; ++cycle) {
			player->wheel().applyPositionalTactics(0);
			player->wheel().flushConditionalSkillSources();
			EXPECT_EQ(142, player->getSkillLevel(SKILL_DISTANCE)) << "cycle " << cycle << " in";

			player->wheel().applyPositionalTactics(1);
			player->wheel().flushConditionalSkillSources();
			EXPECT_EQ(138, player->getSkillLevel(SKILL_DISTANCE)) << "cycle " << cycle << " out";
			EXPECT_EQ(105, player->getSkillLevelForPercentScaling(SKILL_DISTANCE)) << "cycle " << cycle << " left something behind";
		}
	}

	TEST_F(EffectiveSkillPercentTest, BattleInstinctShieldingMovesTheStanceWhileItIsActive) {
		auto player = std::make_shared<Player>();
		equipFlatShielding(player, 90); // 10 trained + 90 equipment = 100

		ASSERT_TRUE(player->addCondition(protector()));
		ASSERT_EQ(100, player->getSkillLevelForPercentScaling(SKILL_SHIELD));
		ASSERT_EQ(130, player->getSkillLevel(SKILL_SHIELD));

		player->wheel().setSpellInstant("Battle Instinct", true);

		// Six adjacent monsters: (6 - 4) x 6 = 12 Shielding.
		EXPECT_TRUE(player->wheel().applyBattleInstinct(6));
		EXPECT_EQ(112, player->getSkillLevelForPercentScaling(SKILL_SHIELD));
		EXPECT_TRUE(player->wheel().flushConditionalSkillSources());
		EXPECT_EQ(145, player->getSkillLevel(SKILL_SHIELD)) << "30% of 112 is 33, on top of 112";

		// Down to four: the grant is off entirely.
		EXPECT_TRUE(player->wheel().applyBattleInstinct(4));
		EXPECT_EQ(100, player->getSkillLevelForPercentScaling(SKILL_SHIELD));
		EXPECT_TRUE(player->wheel().flushConditionalSkillSources());
		EXPECT_EQ(130, player->getSkillLevel(SKILL_SHIELD));
	}

	TEST_F(EffectiveSkillPercentTest, BattleInstinctCyclesDoNotCompound) {
		auto player = std::make_shared<Player>();
		equipFlatShielding(player, 90);
		ASSERT_TRUE(player->addCondition(protector()));
		player->wheel().setSpellInstant("Battle Instinct", true);

		for (int cycle = 0; cycle < 5; ++cycle) {
			player->wheel().applyBattleInstinct(6);
			player->wheel().flushConditionalSkillSources();
			EXPECT_EQ(145, player->getSkillLevel(SKILL_SHIELD)) << "cycle " << cycle << " in";

			player->wheel().applyBattleInstinct(0);
			player->wheel().flushConditionalSkillSources();
			EXPECT_EQ(130, player->getSkillLevel(SKILL_SHIELD)) << "cycle " << cycle << " out";
			EXPECT_EQ(100, player->getSkillLevelForPercentScaling(SKILL_SHIELD)) << "cycle " << cycle << " left something behind";
		}
	}

	TEST_F(EffectiveSkillPercentTest, TheConditionalBonusOnlyCountsWhileItsInstantIsHeld) {
		// getMajorStatConditional is gated on the instant, so a stored major stat with
		// the instant off is worth nothing - and the percentage must agree with that.
		auto player = std::make_shared<Player>();
		equipFlatDistance(player, kDistanceEquipment);
		ASSERT_TRUE(player->addCondition(sharpshooter()));

		player->wheel().applyPositionalTactics(0);
		player->wheel().flushConditionalSkillSources();
		EXPECT_EQ(105, player->getSkillLevelForPercentScaling(SKILL_DISTANCE)) << "the instant was never granted";
		EXPECT_EQ(138, player->getSkillLevel(SKILL_DISTANCE));

		player->wheel().setSpellInstant("Positional Tactics", true);
		EXPECT_EQ(108, player->getSkillLevelForPercentScaling(SKILL_DISTANCE));
	}

	TEST_F(EffectiveSkillPercentTest, ANonSkillMajorStatDoesNotAskForARederivation) {
		// The narrow half of the contract. Divine Empowerment's damage bonus, Ballistic
		// Mastery's elemental bonuses and Combat Mastery's Defence are major stats too,
		// and no skill is built from any of them: a change there must not put the
		// percent recipes through a pass on every tick that moves one.
		auto player = std::make_shared<Player>();
		equipFlatDistance(player, 90);
		ASSERT_TRUE(player->addCondition(sharpshooter()));
		ASSERT_EQ(132, player->getSkillLevel(SKILL_DISTANCE));

		EXPECT_TRUE(player->wheel().applyConditionalMajorStat(WheelMajor_t::DAMAGE, 12)) << "the stat itself did change";
		EXPECT_FALSE(player->wheel().flushConditionalSkillSources()) << "but no skill source did";
		EXPECT_EQ(132, player->getSkillLevel(SKILL_DISTANCE));

		EXPECT_TRUE(player->wheel().applyConditionalMajorStat(WheelMajor_t::DEFENSE, 30));
		EXPECT_FALSE(player->wheel().flushConditionalSkillSources());

		// Melee is the one that looks like a skill source and is not: the melee skills
		// read WheelStat_t::MELEE, never this major stat.
		EXPECT_TRUE(player->wheel().applyConditionalMajorStat(WheelMajor_t::MELEE, 2));
		EXPECT_FALSE(player->wheel().flushConditionalSkillSources());

		// And a write that changes nothing is not a change at all.
		EXPECT_FALSE(player->wheel().applyConditionalMajorStat(WheelMajor_t::DISTANCE, 0));
		EXPECT_FALSE(player->wheel().flushConditionalSkillSources());
	}

	TEST_F(EffectiveSkillPercentTest, OneEvaluationThatMovesTwoStatsCostsOnePass) {
		// Battle Instinct moves MELEE and SHIELD in the same evaluation; only SHIELD is
		// a skill source, and the evaluation re-derives once, at its end.
		auto player = std::make_shared<Player>();
		equipFlatShielding(player, 90);
		ASSERT_TRUE(player->addCondition(protector()));
		player->wheel().setSpellInstant("Battle Instinct", true);

		ASSERT_TRUE(player->wheel().applyBattleInstinct(6));
		EXPECT_TRUE(player->wheel().flushConditionalSkillSources()) << "the first flush does the work";
		EXPECT_EQ(145, player->getSkillLevel(SKILL_SHIELD));
		EXPECT_FALSE(player->wheel().flushConditionalSkillSources()) << "and a second one has nothing left to do";
		EXPECT_EQ(145, player->getSkillLevel(SKILL_SHIELD));
	}

	TEST_F(EffectiveSkillPercentTest, TheGlobalConditionalResetTakesTheStanceDownWithIt) {
		// onThink's early branch - the player left combat, entered a protection zone or
		// holds no instant that grants a conditional stat - and every major stat goes
		// to zero at once.
		auto player = std::make_shared<Player>();
		equipFlatShielding(player, 90);
		equipFlatDistance(player, kDistanceEquipment);
		ASSERT_TRUE(player->addCondition(protector()));
		ASSERT_TRUE(player->addCondition(sharpshooter()));
		player->wheel().setSpellInstant("Battle Instinct", true);
		player->wheel().setSpellInstant("Positional Tactics", true);

		player->wheel().applyBattleInstinct(6);
		player->wheel().applyPositionalTactics(0);
		player->wheel().flushConditionalSkillSources();
		ASSERT_EQ(145, player->getSkillLevel(SKILL_SHIELD));
		ASSERT_EQ(142, player->getSkillLevel(SKILL_DISTANCE));

		EXPECT_TRUE(player->wheel().resetConditionalMajorStats());
		EXPECT_TRUE(player->wheel().flushConditionalSkillSources());
		EXPECT_EQ(130, player->getSkillLevel(SKILL_SHIELD)) << "both stances unwind to their equipment-only value";
		EXPECT_EQ(138, player->getSkillLevel(SKILL_DISTANCE));

		EXPECT_FALSE(player->wheel().resetConditionalMajorStats()) << "and a second reset has nothing to reset";
	}

}
