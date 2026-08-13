-- ================================================================
-- KING ZELOS "GREATER HEX" (executor contract, section 20)
-- ================================================================
-- Confirmed absent from the repository before this pass: no beam attack, no
-- CONDITION_PARAM_STAT_MAXHITPOINTSPERCENT usage, and no COMBAT_PARAM_BLOCKSHIELD usage anywhere in
-- data-otservbr-global/scripts (mechanical grep during recon). Built entirely from the engine's own
-- native primitives for exactly this purpose.
--
-- GREATER_HEX_SUBID tags this specific condition instance so removeGreaterHex() (creaturescripts_
-- king_zelos.lua) can remove only this Hex, never any unrelated CONDITION_ATTRIBUTES effect a
-- player might be carrying from something else.
GREATER_HEX_SUBID = 90210

local combat = Combat()
combat:setParameter(COMBAT_PARAM_EFFECT, CONST_ME_MAGIC_RED)
-- Bypasses Magic Shield (executor contract, section 20).
combat:setParameter(COMBAT_PARAM_BLOCKSHIELD, true)
-- Beam-shaped, same range/shape as Great Energy Beam (data/scripts/spells/attack/great_energy_beam.lua).
combat:setArea(createCombatArea(AREA_BEAM8))

local condition = Condition(CONDITION_ATTRIBUTES)
condition:setParameter(CONDITION_PARAM_SUBID, GREATER_HEX_SUBID)
-- Encounter-scoped/transient: does not expire on its own (-1 ticks). Removed explicitly by the
-- cleanse vortex or by KingZelosRunTerminate - never left to corrupt max HP permanently.
condition:setParameter(CONDITION_PARAM_TICKS, -1)
-- Effective maximum HP becomes 40% of normal.
condition:setParameter(CONDITION_PARAM_STAT_MAXHITPOINTSPERCENT, 40)
combat:addCondition(condition)

function onTargetCreature(creature, target)
	if not target or not target:isPlayer() then
		return true
	end
	local token = KingZelosRunCurrentToken()
	if not token or not KingZelosRunIsParticipant(token, target:getId()) then
		return true
	end
	KingZelosRunSetHex(token, target:getId(), true)
	target:sendTextMessage(MESSAGE_EVENT_ADVANCE, "King Zelos's hex sinks into you, sapping your vitality! Seek the northern vortex to cleanse it.")
	return true
end

combat:setCallback(CALLBACK_PARAM_TARGETCREATURE, "onTargetCreature")

local spell = Spell("instant")

function spell.onCastSpell(creature, var)
	return combat:execute(creature, var)
end

spell:name("king zelos greater hex")
spell:words("###7100")
spell:needLearn(true)
spell:needDirection(true)
spell:blockWalls(true)
spell:register()
