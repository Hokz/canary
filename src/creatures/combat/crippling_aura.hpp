/**
 * Canary - A free and open-source MMORPG server emulator
 * Copyright (©) 2019–present OpenTibiaBR <opentibiabr@outlook.com>
 * Repository: https://github.com/opentibiabr/canary
 * License: https://github.com/opentibiabr/canary/blob/main/LICENSE
 * Contributors: https://github.com/opentibiabr/canary/graphs/contributors
 * Website: https://docs.opentibiabr.com/
 */

#pragma once

#include "creatures/creatures_definitions.hpp"

#include <cstdint>
#include <memory>

class Condition;
class Creature;
class Player;

// The Crippling stances of the 15.25 vocation balancing: Aura of Sapped Strength
// and Aura of Exposed Weakness. With one held, every attack, spell and rune the
// Sorcerer LANDS applies its debuff to the enemy hit:
//
//   Sapped Strength    the enemy deals 10% less
//   Exposed Weakness   +8% Elemental Pierce against the enemy
//
// "Lands" is the point: the debuff is applied from Game::combatChangeHealth after
// the hit has resolved and taken health, so a hit that was dodged, blocked or
// cancelled applies nothing - the earlier callback on target selection did not
// know that yet. A hit that lands for zero (an immunity) also applies nothing;
// whether the official servers apply the aura on an immune hit is not proven, and
// that reading is stated in the PR rather than assumed.
namespace CripplingAura {
	// The debuff durations. Sapped Strength's official duration is not proven; the
	// 10 seconds are the Exposed Weakness value from the mechanics brief applied to
	// both, stated as such (FIDELITY_BLOCKER — VALUE_EVIDENCE_REQUIRED) rather than
	// the 16 seconds the old targeted Sap Strength spell used.
	inline constexpr int32_t SAPPED_STRENGTH_DAMAGE_PERCENT = 90;
	inline constexpr int32_t SAPPED_STRENGTH_DURATION_MS = 10 * 1000;
	inline constexpr int32_t EXPOSED_WEAKNESS_PIERCE_PERCENT = 8;
	inline constexpr int32_t EXPOSED_WEAKNESS_DURATION_MS = 10 * 1000;

	// Whether a resolved hit is one the auras act on: it took health, it came from
	// an instant spell, a rune or an auto attack, and it is not an extension
	// (reflection, leech, charm) or a condition tick.
	[[nodiscard]] bool qualifies(const CombatDamage &damage, int32_t realDamage);

	// The debuffs themselves, each on its own subId so refreshing one leaves the
	// other alone.
	[[nodiscard]] std::shared_ptr<Condition> sappedStrength();
	[[nodiscard]] std::shared_ptr<Condition> exposedWeakness();

	// Applies whichever aura the attacker holds to the target, once per landed hit.
	// Only masterless monsters receive it; players and summons do not. Re-adding
	// the same debuff refreshes its duration - it never stacks. Returns true when
	// at least one debuff was applied.
	bool apply(const std::shared_ptr<Player> &attacker, const std::shared_ptr<Creature> &target, const CombatDamage &damage, int32_t realDamage);
}
