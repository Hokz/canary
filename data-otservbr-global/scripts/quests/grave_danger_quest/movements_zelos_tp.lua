local zelos_tp = MoveEvent()

function zelos_tp.onStepIn(creature, item, position, fromPosition)
	if not creature:isPlayer() then
		return false
	end

	-- CORRECTION (executor contract, sections 16/17): a generation-blind global monster-name
	-- presence/absence check is not authoritative run state - it cannot tell "still alive" apart
	-- from "renamed by a form transform" (Rewar's own Inv transform blinded the old check to his
	-- name the moment he transformed, well before he was actually dead), and a stale/unrelated
	-- monster sharing one of these names could lock or unlock an unrelated run. The green teleport
	-- now checks the CURRENT King Zelos run's own tracked wing-completion state instead.
	local token = KingZelosRunCurrentToken()
	if not token or not KingZelosRunAllWingsComplete(token) then
		creature:teleportTo(fromPosition)
		creature:sendTextMessage(MESSAGE_EVENT_ADVANCE, "The ritual still rages. The risen lich-knights must fall first.")
		creature:getPosition():sendMagicEffect(CONST_ME_POFF)
		return true
	end

	if not KingZelosRunIsParticipant(token, creature:getId()) then
		creature:teleportTo(fromPosition)
		creature:sendTextMessage(MESSAGE_EVENT_ADVANCE, "You are not part of the current attempt.")
		creature:getPosition():sendMagicEffect(CONST_ME_POFF)
		return true
	end

	creature:teleportTo(Position(33443, 31536, 13))

	return true
end

zelos_tp:aid(14579)
zelos_tp:register()
