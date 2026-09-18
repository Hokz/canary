/**
 * Canary - A free and open-source MMORPG server emulator
 * Copyright (©) 2019–present OpenTibiaBR <opentibiabr@outlook.com>
 * Repository: https://github.com/opentibiabr/canary
 * License: https://github.com/opentibiabr/canary/blob/main/LICENSE
 * Contributors: https://github.com/opentibiabr/canary/graphs/contributors
 * Website: https://docs.opentibiabr.com/
 */

#pragma once

// The modern (15.25) mitigation tuning of one vocation, as independent knobs.
//
// Why this exists: the legacy <mitigation multiplier primaryShield secondaryShield />
// carried only three numbers, and the formula used the same two of them in two
// different mathematical positions depending on what the player held - sometimes as
// a factor on the Defence contribution, sometimes as a multiplier on the whole
// result. That made "primaryShield" mean two things and left no way to tune a bow
// apart from a spellbook. Each position now has its own named field.
//
// The pipeline these feed, in order:
//
//   effective Shielding x skillFactor                  -> skill contribution
//   effective Defence   x <source>DefenseFactor        -> Defence contribution
//   (skill + Defence) / 100                            -> base mitigation
//   base x <category>EquipmentMultiplier               -> equipment-adjusted
//   equipment-adjusted x Wheel mitigation multiplier   -> final mitigation, in %
//
// There is no fight-mode multiplier on the modern model.
//
// UNITS. Every field is a dimensionless multiplier, never a percentage and never a
// flat addend. 1.0 means "contributes exactly its own value"; 2.05 means "counts
// slightly more than twice". A DefenseFactor weights one source of Defence before
// the sum; an EquipmentMultiplier weights the whole result afterwards, and only one
// of them ever applies - the category the player's equipment resolves to.
//
// CONFIDENCE. skillFactor and the shield/one-handed/two-handed factors are the
// project's audited values, carried over unchanged from the legacy three. The
// category multipliers for bows, crossbows, quivers and Elemental Bond are
// COMMUNITY_DERIVED_TUNABLE / FIDELITY_PENDING_EVIDENCE: CipSoft has not published
// the post-15.25 coefficients, so they are initialised from the behaviour this
// server already had rather than from an invented number, and they are knobs in
// data/XML/vocations.xml precisely so a future capture can correct them without a
// recompile. None of them is an exact Global value and none is presented as one.
struct VocationMitigationProfile {
	// BASE. What a point of effective Shielding is worth.
	float skillFactor = 1.0f;

	// DEFENCE-CONTRIBUTION FACTORS. What a point of effective Defence is worth,
	// by where the Defence came from. The Defence itself already carries the 15.25
	// equipment compensation (shield +30%, spellbook +60%) exactly once.
	float shieldDefenseFactor = 1.0f;
	float spellbookDefenseFactor = 1.0f;
	float oneHandedDefenseFactor = 1.0f;
	float twoHandedDefenseFactor = 1.0f;

	// CATEGORY MULTIPLIERS. Applied once, after the sum, for the one category the
	// player's equipment resolves to.
	float shieldEquipmentMultiplier = 1.0f;
	float spellbookEquipmentMultiplier = 1.0f;
	float oneHandedEquipmentMultiplier = 1.0f;
	float twoHandedEquipmentMultiplier = 1.0f;
	float bowEquipmentMultiplier = 1.0f;
	float crossbowEquipmentMultiplier = 1.0f;
	float quiverEquipmentMultiplier = 1.0f;
	float elementalBondEquipmentMultiplier = 1.0f;

	// Fills every modern field from the legacy three, so a vocations.xml that was
	// never updated keeps the numbers it had. This mapping is what the pre-refactor
	// formula did, written out: a shield's and a one-handed weapon's Defence were
	// weighted by primaryShield, a two-hander's by secondaryShield, and a spellbook,
	// quiver, bow or crossbow multiplied the whole result by secondaryShield instead.
	constexpr void deriveFromLegacy(float mitigationFactor, float primaryShield, float secondaryShield) {
		skillFactor = mitigationFactor;

		shieldDefenseFactor = primaryShield;
		oneHandedDefenseFactor = primaryShield;
		twoHandedDefenseFactor = secondaryShield;
		// A spellbook's Defence was never weighted; only the result was.
		spellbookDefenseFactor = 1.0f;

		shieldEquipmentMultiplier = 1.0f;
		oneHandedEquipmentMultiplier = 1.0f;
		twoHandedEquipmentMultiplier = 1.0f;
		spellbookEquipmentMultiplier = secondaryShield;
		bowEquipmentMultiplier = secondaryShield;
		crossbowEquipmentMultiplier = secondaryShield;
		quiverEquipmentMultiplier = secondaryShield;
		// Never modelled before, and no evidence for a post-15.25 value: neutral
		// until one exists. FIDELITY_PENDING_EVIDENCE.
		elementalBondEquipmentMultiplier = 1.0f;
	}
};
