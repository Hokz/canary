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

	local zelos = Creature(KingZelosRun.bossId)
	if not zelos or not KingZelosRunOwnsBoss(zelos) then
		return true
	end

	-- CORRECTION (correction pass section J7): Unleashed Hex is a MANDATORY consequence of the
	-- cleanse, not an optional flourish - reordered to verify-then-commit instead of commit-then-log.
	-- Nothing about King Zelos's own creation ordering constraints (the BossLever removeMonsters()-
	-- before-createFunction issue documented elsewhere in this quest) applies here - a MoveEvent
	-- onStepIn has no such ordering requirement, so verifying the mandatory entity BEFORE granting the
	-- cleanse is possible and is the correct transactional shape: if the Unleashed Hex cannot be
	-- verified after bounded retries, the cleanse is not granted at all (no state change), and the
	-- player can simply step on the vortex again - safer than technical-aborting the whole encounter
	-- for every other participant over one player's transient cleanse attempt.
	-- CUSTOM_GLOBAL_LIKE_FAILURE_RECOVERY: this specific retry-then-decline behavior (rather than a
	-- whole-run technical_abort) is this pass's own invented recovery shape for this one mandatory
	-- entity, not sourced from the owner reference.
	local unleashedHex = nil
	for attempt = 1, 3 do
		unleashedHex = Game.createMonster("Unleashed Hex", position, false, true)
		if unleashedHex then
			break
		end
		logger.error("GraveDanger/KingZelos: failed to create Unleashed Hex on cleanse (attempt {}/3)", attempt)
	end

	if not unleashedHex then
		logger.error("GraveDanger/KingZelos: cleanse declined - Unleashed Hex failed to spawn after bounded retries")
		creature:sendTextMessage(MESSAGE_EVENT_ADVANCE, "The vortex flickers but fails to cleanse you - try again.")
		return true
	end

	KingZelosRunTrackMonster(unleashedHex)

	removeGreaterHex(creature)
	KingZelosRunSetHex(token, creature:getId(), false)
	zelos:addHealth(15000)
	position:sendMagicEffect(CONST_ME_MAGIC_GREEN)
	creature:sendTextMessage(MESSAGE_EVENT_ADVANCE, "The vortex cleanses King Zelos's hex from you!")

	return true
end

cleanse_vortex:aid(14580)
cleanse_vortex:register()
