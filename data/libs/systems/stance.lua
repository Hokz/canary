-- Stances (15.25 vocation balancing update).
--
-- A stance is not a timed buff. It is switched on and stays on: it survives logout,
-- it survives death, and it ends only when the player recasts it or activates another
-- stance of the same family. Having no stance at all is a valid state.
--
-- PERSISTENCE
--   Condition(type, id, subId, true) with TICKS = -1. That fourth argument is the
--   engine's isPersistent flag, and both halves are needed:
--     - Condition::isPersistent() short-circuits on the flag, so the condition is
--       written to the player's `conditions` blob on save and put back by
--       addCondition on login. A TICKS = -1 condition WITHOUT the flag is
--       deliberately not saved, so an infinite duration alone would silently lose
--       the stance on logout.
--     - Condition::isRemovableOnDeath() returns false for it, so dying does not
--       clear the stance.
--
-- EXCLUSIVITY
--   Each stance has its own subId, and this file groups them into families. Turning
--   one on clears the rest of its family; recasting the one already held turns it
--   off. Three families, which is exactly the official rule:
--
--     General    one at a time, across Knight, Paladin and Druid
--     Elemental  Sorcerer: Master of Flames / Thunder / Decay
--     Crippling  Sorcerer: Aura of Sapped Strength / Exposed Weakness
--
--   A Sorcerer may hold one Elemental and one Crippling stance at once, and nobody
--   can hold two of either. Nothing enforces that beyond these tables.
--
--   A per-family shared subId would have given exclusivity for free, but the
--   condition would then carry no identity: the engine could not tell a player
--   switching stances from a player turning the current one off, and both are real
--   actions here.

Stance = {}

Stance.Family = {
	General = {
		AttrSubId_StanceBloodRage,
		AttrSubId_StanceProtector,
		AttrSubId_StanceSharpshooter,
		AttrSubId_StanceDivineDefiance,
		AttrSubId_StanceSharedConservation,
		AttrSubId_StanceElementalSynthesis,
	},
	Elemental = {
		AttrSubId_StanceMasterOfFlames,
		AttrSubId_StanceMasterOfThunder,
		AttrSubId_StanceMasterOfDecay,
	},
	Crippling = {
		AttrSubId_StanceSappedStrength,
		AttrSubId_StanceExposedWeakness,
	},
}

--- Builds the persistent condition a stance applies.
-- @param subId this stance's AttrSubId
-- @param apply function(condition) setting the stance's own parameters
-- @return Condition
function Stance.condition(subId, apply)
	local condition = Condition(CONDITION_ATTRIBUTES, CONDITIONID_COMBAT, subId, true)
	condition:setParameter(CONDITION_PARAM_SUBID, subId)
	condition:setParameter(CONDITION_PARAM_TICKS, -1)
	condition:setParameter(CONDITION_PARAM_BUFF_SPELL, true)
	apply(condition)
	return condition
end

--- Whether this creature holds the given stance.
function Stance.active(creature, subId)
	return creature:getCondition(CONDITION_ATTRIBUTES, CONDITIONID_COMBAT, subId) ~= nil
end

--- Removes every stance in a family. Returns how many came off.
function Stance.clearFamily(creature, family)
	local removed = 0
	for _, subId in ipairs(family) do
		if Stance.active(creature, subId) then
			creature:removeCondition(CONDITION_ATTRIBUTES, CONDITIONID_COMBAT, subId)
			removed = removed + 1
		end
	end
	return removed
end

--- The body of a stance spell.
--
-- Recasting the stance you hold turns it off; casting a different one in the same
-- family replaces it. Both paths report success, because both are things the player
-- asked for and neither should refund the cast.
--
-- @param creature the caster
-- @param subId this stance's AttrSubId
-- @param family the Stance.Family table this stance belongs to
-- @param build function() returning the Condition to apply
-- @param effect optional magic effect shown on activation
-- @return boolean
function Stance.cast(creature, subId, family, build, effect)
	if Stance.active(creature, subId) then
		creature:removeCondition(CONDITION_ATTRIBUTES, CONDITIONID_COMBAT, subId)
		creature:getPosition():sendMagicEffect(CONST_ME_POFF)
		return true
	end

	Stance.clearFamily(creature, family)
	creature:addCondition(build())
	creature:getPosition():sendMagicEffect(effect or CONST_ME_MAGIC_GREEN)
	return true
end

--- Shared Conservation: whom a Heal Friend or Nature's Embrace also heals.
--
-- The stance makes those two spells heal a second party member on screen for 30% of
-- the amount. This picks that member: the party member with the LOWEST CURRENT
-- HEALTH - absolute hit points, not a fraction of maximum, which can pick a
-- different player (a Knight at 2000/10000 loses to a Sorcerer at 1000/2000) - who
-- is on the caster's game window and visible to them, never the spell's own target.
-- The caster counts as a party member: the update says "a second member of the
-- party" and does not exclude them. Party:getMembers() does not include the leader,
-- so the leader is added once.
--
-- Returns nil when the caster has no Shared Conservation stance, is not in a party,
-- or nobody else on screen qualifies - and the healing spell then behaves exactly as
-- it did before the stance existed.
--
-- @param caster Player casting the heal
-- @param primaryTarget Creature the heal was aimed at
-- @return Player|nil
function Stance.sharedConservationTarget(caster, primaryTarget)
	if not Stance.active(caster, AttrSubId_StanceSharedConservation) then
		return nil
	end

	local party = caster:getParty()
	if not party then
		return nil
	end

	local candidates = party:getMembers() or {}
	local leader = party:getLeader()
	if leader then
		local listed = false
		for _, member in ipairs(candidates) do
			if member:getId() == leader:getId() then
				listed = true
				break
			end
		end
		if not listed then
			table.insert(candidates, leader)
		end
	end

	local primaryId = primaryTarget and primaryTarget:getId() or nil
	local best, bestHealth = nil, nil
	for _, member in ipairs(candidates) do
		if member and member:getId() ~= primaryId and member:getHealth() > 0 and caster:canSee(member:getPosition()) and caster:canSeeCreature(member) then
			local health = member:getHealth()
			if bestHealth == nil or health < bestHealth then
				best, bestHealth = member, health
			end
		end
	end

	return best
end

--- The 30% companion heal. A Combat of its own, built once per healing spell with a
--- formula scaled to 30% of that spell's, so the secondary heal goes through the
--- same pipeline as any other healing - critical heals, healing buffs, the Wheel -
--- and the same rules: Combat::doCombatHealth refuses to heal a monster, a summon
--- of another player, or a player from a monster, exactly as it does for the main
--- heal. The +10% self-heal of the stance never reaches it, because its target is
--- never the caster.
-- @param combat Combat to execute on the secondary target
-- @param caster Player
-- @param secondary Player returned by Stance.sharedConservationTarget
function Stance.castSharedConservation(combat, caster, secondary)
	if not secondary then
		return
	end

	combat:execute(caster, Variant(secondary:getId()))
end
