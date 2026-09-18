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

#ifndef USE_PRECOMPILED_HEADERS
	#include <optional>
	#include <string>
	#include <string_view>
#endif

// Master of Flames / Thunder / Decay (15.25): after casting a spell of the stance's
// element, the next instant spell of a different element is converted to it.
//
// The rule is a three-state machine and it used to live inline in
// Combat::getCombatDamage, where the only way to exercise it was to run a whole
// combat. It is a pure function of three inputs, so it is one here: what the spell's
// element is, which stance is held, and what is currently armed.
//
// A Beam Mastery cast is two Combat executions - the central beam and its flank
// lines - and both reach getCombatDamage. The machine must therefore run for exactly
// one of them, or one cast resolves two elements: the centre consumes an armed fire
// conversion and the flanks, finding nothing armed, stay energy. resolvePass below is
// the whole decision for one execution, including which of the two it is, so the
// central/flank split is testable without running a combat.
namespace ElementalStance {
	// What the central pass resolved, kept only until its own flank pass reads it.
	// Runtime state on the Player, never persisted, and keyed by the spell name so one
	// beam can never inherit another's element.
	struct BeamMasteryCastContext {
		std::string spellName;
		CombatType_t resolvedPrimaryType = COMBAT_NONE;
		bool valid = false;

		void publish(std::string_view name, CombatType_t resolvedType) {
			spellName = name;
			resolvedPrimaryType = resolvedType;
			valid = true;
		}

		void clear() {
			spellName.clear();
			resolvedPrimaryType = COMBAT_NONE;
			valid = false;
		}

		// The element published for this spell, if any. A name that does not match
		// leaves the context exactly as it was; a match takes it and clears it, so it
		// can be read once.
		[[nodiscard]] std::optional<CombatType_t> consume(std::string_view name) {
			if (!valid || spellName != name) {
				return std::nullopt;
			}
			const CombatType_t resolved = resolvedPrimaryType;
			clear();
			return resolved;
		}
	};

	struct Resolution {
		// The element the spell will actually deal.
		CombatType_t resolvedType = COMBAT_NONE;
		// What the player's armed conversion becomes. The caller writes this back
		// verbatim, so a transition that changes nothing returns what it was given.
		CombatType_t pendingAfter = COMBAT_NONE;
	};

	// naturalType is the spell's own element, before any conversion. stanceElement is
	// the element of the stance the player holds, or COMBAT_NONE for no stance.
	// pendingBefore is the element currently armed, or COMBAT_NONE.
	[[nodiscard]] constexpr Resolution resolve(CombatType_t naturalType, CombatType_t stanceElement, CombatType_t pendingBefore) {
		// No stance: nothing is converted and nothing stays armed. Dropping the armed
		// element here is deliberate - the stance that armed it is gone.
		if (stanceElement == COMBAT_NONE) {
			return { naturalType, COMBAT_NONE };
		}

		// A spell of the stance's own element arms the conversion. Arming is
		// idempotent: casting two fire spells in a row leaves one armed conversion.
		if (naturalType == stanceElement) {
			return { naturalType, stanceElement };
		}

		// A spell of another element consumes an armed conversion, exactly once.
		if (pendingBefore == stanceElement) {
			return { stanceElement, COMBAT_NONE };
		}

		// A stance is held but nothing is armed: the spell keeps its own element and
		// the armed state is left exactly as it was.
		return { naturalType, pendingBefore };
	}

	// One Combat execution, as getCombatDamage sees it.
	struct Pass {
		// The spell's own element for this execution, after the Monk elemental bond.
		CombatType_t naturalType = COMBAT_NONE;
		// The stance the caster holds, or COMBAT_NONE.
		CombatType_t stanceElement = COMBAT_NONE;
		std::string_view instantSpellName;
		// True for a Beam Mastery flank execution (CombatParams::beamMasteryFlank).
		bool isFlank = false;
		// Whether the name is in the wheel's Beam Mastery spell set.
		bool beamMasterySpell = false;
		// Whether Beam Mastery's adjacent-square damage is active at all, which is the
		// same condition under which the datapack runs a flank execution.
		bool beamMasteryFlankActive = false;
	};

	// Resolves the element one execution deals. pending is the caster's armed
	// conversion and context its Beam Mastery cast context; both are updated in place,
	// so this function is the single place either changes.
	[[nodiscard]] inline CombatType_t resolvePass(const Pass &pass, CombatType_t &pending, BeamMasteryCastContext &context) {
		if (pass.isFlank) {
			// Inherit, and nothing else: no arming, no consuming, no second
			// resolution. A missing or mismatched context falls back to the spell's
			// own element and still leaves the armed conversion alone.
			if (const auto inherited = context.consume(pass.instantSpellName)) {
				return *inherited;
			}
			return pass.naturalType;
		}

		// Any other instant cast means an earlier Beam Mastery cast never reached its
		// flank pass. Drop that context before it can be inherited by something it was
		// not resolved for.
		context.clear();

		const auto resolution = resolve(pass.naturalType, pass.stanceElement, pending);
		pending = resolution.pendingAfter;

		// Publish for the flank pass of this cast only, and only when there will be one.
		if (pass.beamMasterySpell && pass.beamMasteryFlankActive) {
			context.publish(pass.instantSpellName, resolution.resolvedType);
		}

		return resolution.resolvedType;
	}
}
