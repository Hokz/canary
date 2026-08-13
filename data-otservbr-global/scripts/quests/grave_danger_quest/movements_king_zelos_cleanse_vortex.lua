-- ================================================================
-- KING ZELOS CLEANSE VORTEX (executor contract, sections 21/22)
-- ================================================================
-- Confirmed absent from the repository before this pass (recon: no vortex/cleanse/"Unleashed Hex"
-- reference anywhere for King Zelos - movements_soul_cleanse.lua is Lord Azaram's unrelated soul
-- teleport). Gameplay logic only: the physical vortex object's exact position/identity is
-- MAP_AUDIT_NOT_RUN / NOT_PROVEN (the configured data-otservbr-global/world/otservbr.otbm is absent
-- from this environment - gitignored, not present in the working tree). Bound to a newly allocated
-- action id (14580, following this quest's own 14562-14567/14579 King Zelos AID numbering) rather
-- than a guessed position - see the Manual RME Manifest for the required placement.
--
-- NOT implemented: the red/green visual item-transform the source describes (vortex changes colour
-- depending on whether any current-run participant remains Hexed). That needs a proven "red vortex"/
-- "green vortex" item id pair, which cannot be sourced without OTBM access - inventing item ids is
-- explicitly prohibited. Only the underlying gameplay state (KingZelosRun.hex) and the cleanse
-- transaction itself are implemented here.
local cleanse_vortex = MoveEvent()

function cleanse_vortex.onStepIn(creature, item, position, fromPosition)
	if not creature:isPlayer() then
		return true
	end

	local token = KingZelosRunCurrentToken()
	if not token or not KingZelosRunIsParticipant(token, creature:getId()) then
		creature:teleportTo(fromPosition)
		creature:sendTextMessage(MESSAGE_EVENT_ADVANCE, "You are not part of the current attempt.")
		return true
	end

	if not KingZelosRunHasHex(token, creature:getId()) then
		creature:sendTextMessage(MESSAGE_EVENT_ADVANCE, "The vortex has nothing to cleanse from you.")
		return true
	end

	local zelos = Creature("King Zelos")
	if not zelos or not KingZelosRunOwnsMonster(zelos) then
		return true
	end

	-- Commit the cleanse itself first - it does not depend on the Unleashed Hex spawn succeeding.
	removeGreaterHex(creature)
	KingZelosRunSetHex(token, creature:getId(), false)
	zelos:addHealth(15000)
	position:sendMagicEffect(CONST_ME_MAGIC_GREEN)
	creature:sendTextMessage(MESSAGE_EVENT_ADVANCE, "The vortex cleanses King Zelos's hex from you!")

	-- Mandatory consequence entity: bounded retry, verified. A failure here does not roll back the
	-- cleanse already granted (the player and Zelos's heal are not tied to this add existing) - it is
	-- only logged, per the "no permanent server-error punishment" engineering rule.
	local unleashedHex = nil
	for attempt = 1, 3 do
		unleashedHex = Game.createMonster("Unleashed Hex", position, false, true)
		if unleashedHex then
			break
		end
		logger.error("GraveDanger/KingZelos: failed to create Unleashed Hex on cleanse (attempt {}/3)", attempt)
	end
	if unleashedHex then
		KingZelosRunTrackMonster(unleashedHex)
	else
		logger.error("GraveDanger/KingZelos: Unleashed Hex failed to spawn after bounded retries")
	end

	return true
end

cleanse_vortex:aid(14580)
cleanse_vortex:register()
