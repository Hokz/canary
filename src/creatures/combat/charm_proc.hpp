/**
 * Canary - A free and open-source MMORPG server emulator
 * Copyright (©) 2019–present OpenTibiaBR <opentibiabr@outlook.com>
 * Repository: https://github.com/opentibiabr/canary
 * License: https://github.com/opentibiabr/canary/blob/main/LICENSE
 * Contributors: https://github.com/opentibiabr/canary/graphs/contributors
 * Website: https://docs.opentibiabr.com/
 */

#pragma once

// 15.25: an auto attack rolls its charms on the creature the player is attacking and
// on nothing else.
//
// This only became visible with the area ammunition the update adds. A storm arrow is
// one auto attack that runs a single Combat over thirteen squares, and every creature
// it damaged used to roll the offensive charm separately - one shot, up to thirteen
// procs. Spells and runes are areas by design and are not touched by this rule.
//
// The decision is a pure function of five booleans, so it is one here rather than a
// condition buried in Game::combatChangeHealth where only a live area shot could
// exercise it.
namespace CharmProc {
	struct Hit {
		// damage.noCharm: the spell or effect asked for no charm at all.
		bool noCharm = false;
		// damage.extension: secondary accounting, such as a cleave hit.
		bool extension = false;
		// damage.origin == ORIGIN_CONDITION: damage over time, never a charm.
		bool conditionDamage = false;
		// The attacker is resolving a weapon auto attack right now.
		bool autoAttack = false;
		// This creature is that auto attack's own target.
		bool mainTarget = false;
	};

	[[nodiscard]] constexpr bool allows(const Hit &hit) {
		if (hit.noCharm || hit.extension || hit.conditionDamage) {
			return false;
		}

		// The splash of an area auto attack. A shot with no creature targeted at all -
		// ammunition loosed at a tile - has no main target, so nothing it hits rolls.
		if (hit.autoAttack && !hit.mainTarget) {
			return false;
		}

		return true;
	}
}
