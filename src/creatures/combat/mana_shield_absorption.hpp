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

#include <algorithm>
#include <cstdint>

// The arithmetic of a mana shield taking a hit, kept pure so it can be proven on
// its own. Two shields share it:
//
//   Magic Shield (the spell)   1 mana per hit point, with a capacity
//   Energy Ring (15.25)        2 mana per hit point, no capacity
//
// The rule is "absorb what the mana can pay for, exactly". The hit points covered
// are decided first, from the mana available at the exchange rate, and the mana
// spent is exactly that many hit points times the rate - so no mana is ever spent
// on a fraction of a hit point. With 3 mana at 2:1 the shield covers 1 hit point
// for 2 mana and 1 mana stays; the old order (spend everything, divide after) took
// all 3 and covered the same 1.
struct ManaShieldAbsorption {
	int32_t manaSpent = 0;
	int32_t healthAbsorbed = 0;
};

[[nodiscard]] constexpr ManaShieldAbsorption computeManaShieldAbsorption(int32_t currentMana, int32_t incomingHealthDamage, int32_t manaPerHitPoint) {
	if (currentMana <= 0 || incomingHealthDamage <= 0 || manaPerHitPoint <= 0) {
		return {};
	}
	const int32_t affordable = currentMana / manaPerHitPoint; // integer division floors on purpose
	const int32_t absorbed = std::min<int32_t>(incomingHealthDamage, affordable);
	return { absorbed * manaPerHitPoint, absorbed };
}

// Takes the absorbed hit points off a damage packet: the primary component first,
// then the secondary, and neither ever goes below zero.
inline void takeAbsorbedHealthOff(CombatDamage &damage, int32_t healthAbsorbed) {
	if (healthAbsorbed <= 0) {
		return;
	}
	const int32_t fromPrimary = std::min<int32_t>(std::max<int32_t>(0, damage.primary.value), healthAbsorbed);
	damage.primary.value = std::max<int32_t>(0, damage.primary.value - fromPrimary);
	const int32_t remaining = healthAbsorbed - fromPrimary;
	if (remaining > 0) {
		damage.secondary.value = std::max<int32_t>(0, damage.secondary.value - remaining);
	}
}
