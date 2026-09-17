/**
 * Canary - A free and open-source MMORPG server emulator
 * Copyright (©) 2019–present OpenTibiaBR <opentibiabr@outlook.com>
 * Repository: https://github.com/opentibiabr/canary
 * License: https://github.com/opentibiabr/canary/blob/main/LICENSE
 * Contributors: https://github.com/opentibiabr/canary/graphs/contributors
 * Website: https://docs.opentibiabr.com/
 */

#include "creatures/combat/crippling_aura.hpp"

#include "creatures/combat/condition.hpp"
#include "creatures/players/player.hpp"
#include "utils/utils_definitions.hpp"

namespace CripplingAura {
	bool qualifies(const CombatDamage &damage, int32_t realDamage) {
		if (realDamage <= 0 || damage.extension) {
			return false;
		}
		switch (damage.origin) {
			case ORIGIN_MELEE:
			case ORIGIN_RANGED:
			case ORIGIN_FIST:
				return true;
			case ORIGIN_SPELL:
				return !damage.instantSpellName.empty() || !damage.runeSpellName.empty();
			default:
				return false;
		}
	}

	std::shared_ptr<Condition> sappedStrength() {
		auto condition = Condition::createCondition(CONDITIONID_DEFAULT, CONDITION_ATTRIBUTES, SAPPED_STRENGTH_DURATION_MS, 0, false, magic_enum::enum_integer(AttrSubId_t::DebuffSappedStrength));
		if (condition) {
			condition->setParam(CONDITION_PARAM_BUFF_DAMAGEDEALT, SAPPED_STRENGTH_DAMAGE_PERCENT);
		}
		return condition;
	}

	std::shared_ptr<Condition> exposedWeakness() {
		auto condition = Condition::createCondition(CONDITIONID_DEFAULT, CONDITION_ATTRIBUTES, EXPOSED_WEAKNESS_DURATION_MS, 0, false, magic_enum::enum_integer(AttrSubId_t::DebuffExposedWeakness));
		if (condition) {
			condition->setParam(CONDITION_PARAM_ELEMENTAL_PIERCE_RECEIVED, EXPOSED_WEAKNESS_PIERCE_PERCENT);
		}
		return condition;
	}

	bool apply(const std::shared_ptr<Player> &attacker, const std::shared_ptr<Creature> &target, const CombatDamage &damage, int32_t realDamage) {
		if (!attacker || !target || !target->getMonster() || target->getMaster() || !qualifies(damage, realDamage)) {
			return false;
		}

		bool applied = false;
		if (attacker->hasStance(AttrSubId_t::StanceSappedStrength)) {
			applied = target->addCondition(sappedStrength()) || applied;
		}
		if (attacker->hasStance(AttrSubId_t::StanceExposedWeakness)) {
			applied = target->addCondition(exposedWeakness()) || applied;
		}
		return applied;
	}
}
