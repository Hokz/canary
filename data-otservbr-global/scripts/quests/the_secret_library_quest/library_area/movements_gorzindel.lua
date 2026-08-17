local tomesPosition = {
	[1] = { position = Position(32687, 32707, 10), open = true },
	[2] = { position = Position(32698, 32715, 10), open = true },
	[3] = { position = Position(32693, 32729, 10), open = true },
	[4] = { position = Position(32681, 32729, 10), open = true },
	[5] = { position = Position(32676, 32715, 10), open = true },
}

local middlePosition = Position(32687, 32719, 10)

local movements_library_gorzindel = MoveEvent()

function movements_library_gorzindel.onStepIn(creature, item, position, fromPosition)
	if not creature:isPlayer() then
		return false
	end

	local player = Player(creature:getId())

	for _, k in pairs(tomesPosition) do
		if k.open then
			player:teleportTo(k.position)
			k.open = false
			-- CORRECTION (Secret Library repair v2, section 15): k.open is now always restored,
			-- whether or not the player is still online/alive to be teleported back - previously the
			-- reset lived inside `if p then`, so a player who logged out or died during the 10-second
			-- window left this side-room slot permanently unusable for the rest of the attempt.
			addEvent(function(cid)
				local p = Player(cid)
				if p then
					p:teleportTo(middlePosition)
				end
				k.open = true
			end, 10 * 1000, player:getId())
			break
		end
	end

	return true
end

movements_library_gorzindel:aid(4952)
movements_library_gorzindel:register()
