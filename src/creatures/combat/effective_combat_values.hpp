/**
 * Canary - A free and open-source MMORPG server emulator
 * Copyright (©) 2019–present OpenTibiaBR <opentibiabr@outlook.com>
 * Repository: https://github.com/opentibiabr/canary
 * License: https://github.com/opentibiabr/canary/blob/main/LICENSE
 * Contributors: https://github.com/opentibiabr/canary/graphs/contributors
 * Website: https://docs.opentibiabr.com/
 */

#pragma once

#include "items/items.hpp"

// The 15.25 global compensation for the removal of the combat tactics: every
// weapon's Attack value counts 20% higher, every shield's Defence 30% higher and
// every spellbook's Defence 60% higher than the raw item data says.
//
// This is the one place those three numbers live. Raw item data is canonical and
// untouched (Item::getAttack / getDefense stay raw, and that is what the client's
// item descriptions, the market and serialisation read); the Player reads its
// combat values through here exactly once, and every consumer - the weapon
// formulas, blocking, mitigation, Shield Bash / Slam, the client's stat payload -
// takes the value from the Player instead of from the item. Nothing else may
// multiply by these percentages again.
//
// Values are kept in double so the formulas downstream keep the fraction; the
// engine's existing integer outputs (a max damage, a defence, a wire field) round
// where they always did, and toInteger() is the one rounding point for anything
// that needs an integer before that.
namespace EffectiveCombatValues {
	inline constexpr int32_t WEAPON_ATTACK_PERCENT = 120;
	inline constexpr int32_t SHIELD_DEFENSE_PERCENT = 130;
	inline constexpr int32_t SPELLBOOK_DEFENSE_PERCENT = 160;

	// What an item in the off hand is, for the purpose of the Defence rules above.
	// Decided from item metadata alone: a spellbook is flagged as one in items.xml
	// (weaponType="spellbook"), a shield is any other WEAPON_SHIELD.
	enum class OffhandKind : uint8_t {
		None,
		Shield,
		Spellbook,
		Other,
	};

	[[nodiscard]] inline OffhandKind classify(const ItemType &itemType) {
		if (itemType.isSpellBook()) {
			return OffhandKind::Spellbook;
		}
		if (itemType.weaponType == WEAPON_SHIELD) {
			return OffhandKind::Shield;
		}
		return OffhandKind::Other;
	}

	// A raw value scaled by a percentage. Nothing below zero is scaled: a raw value
	// that is zero or negative has no compensation to receive.
	[[nodiscard]] constexpr double scaled(int32_t raw, int32_t percent) {
		if (raw <= 0) {
			return raw;
		}
		return static_cast<double>(raw) * percent / 100.0;
	}

	[[nodiscard]] constexpr double weaponAttack(int32_t rawAttack) {
		return scaled(rawAttack, WEAPON_ATTACK_PERCENT);
	}

	[[nodiscard]] constexpr double shieldDefense(int32_t rawDefense) {
		return scaled(rawDefense, SHIELD_DEFENSE_PERCENT);
	}

	[[nodiscard]] constexpr double spellbookDefense(int32_t rawDefense) {
		return scaled(rawDefense, SPELLBOOK_DEFENSE_PERCENT);
	}

	// The Defence an off-hand item contributes: a shield's and a spellbook's are
	// compensated, anything else (a quiver, a one-handed weapon's own defence read
	// through this path) is left raw.
	[[nodiscard]] constexpr double offhandDefense(OffhandKind kind, int32_t rawDefense) {
		switch (kind) {
			case OffhandKind::Shield:
				return shieldDefense(rawDefense);
			case OffhandKind::Spellbook:
				return spellbookDefense(rawDefense);
			default:
				return rawDefense;
		}
	}

	// The one rounding point for a consumer that needs an integer: half away from
	// zero, so 51.5 is 52 and a negative value mirrors it.
	[[nodiscard]] constexpr int32_t toInteger(double value) {
		return static_cast<int32_t>(value >= 0 ? value + 0.5 : value - 0.5);
	}
}
