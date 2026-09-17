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

	TEST_F(EffectiveSkillPercentTest, AWeaponProficiencySkillBonusCountsTowardsThePercentage) {
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

	TEST_F(EffectiveSkillPercentTest, TheBaseSkillStaysRawThroughoutAndUnrelatedSkillsAreUntouched) {
		auto player = std::make_shared<Player>();
		equipFlatDistance(player, 90);
		const auto swordBefore = player->getSkillLevel(SKILL_SWORD);

		ASSERT_TRUE(player->addCondition(sharpshooter()));

		EXPECT_EQ(kTrainedSkill, player->getBaseSkill(SKILL_DISTANCE)) << "getBaseSkill is the trained skill and nothing else";
		EXPECT_EQ(swordBefore, player->getSkillLevel(SKILL_SWORD));
		EXPECT_EQ(swordBefore, player->getSkillLevelForPercentScaling(SKILL_SWORD));
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

}
