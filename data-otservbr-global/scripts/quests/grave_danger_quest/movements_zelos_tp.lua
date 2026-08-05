local zelos_tp = MoveEvent()

function zelos_tp.onStepIn(creature, item, position, fromPosition)
	if not creature:isPlayer() then
		return false
	end

	-- Gate on any wing lich-knight (or its intermediate form) still being alive anywhere in the
	-- arena. Creature(name) is a global-by-name lookup, so this also correctly blocks while a
	-- Regenerating Mass or Shard Of Magnor is up. Before the wing bosses were actually spawned
	-- (see actions_king_zelos.lua) none of these ever existed, so this gate always fell through to
	-- the else branch and the final teleport was open from the moment the lever was pulled.
	local knights = {
		"Nargol The Impaler",
		"Magnor Mournbringer",
		"The Red Knight",
		"Rewar The Bloody",
		"Rewar The Bloody Inv",
		"Shard Of Magnor",
		"Regenerating Mass",
	}

	for _, name in ipairs(knights) do
		if Creature(name) then
			creature:teleportTo(fromPosition)
			creature:sendTextMessage(MESSAGE_EVENT_ADVANCE, "The ritual still rages. The risen lich-knights must fall first.")
			creature:getPosition():sendMagicEffect(CONST_ME_POFF)
			return true
		end
	end

	creature:teleportTo(Position(33443, 31536, 13))

	return true
end

zelos_tp:aid(14579)
zelos_tp:register()
