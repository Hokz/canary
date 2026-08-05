local config = {
	[57535] = { tileId = 416, positionTo = { x = 33829, y = 31635, z = 9 } },
	[57536] = { tileId = 417, positionTo = { x = 33831, y = 31635, z = 9 } },
	[57537] = { tileId = 418, positionTo = { x = 33833, y = 31635, z = 9 } },
	[57538] = { tileId = 423, positionTo = { x = 33835, y = 31635, z = 9 } },
}

local destination = { x = 33826, y = 31611, z = 9 }

local tileOne = { x = 33829, y = 31616, z = 9 }

local stepTile = MoveEvent()

function stepTile.onStepIn(player, item, frompos, item2, topos)
	local tiles = config[item.actionid]
	if not tiles then
		return true
	end

	-- CONFIRMED BUG (pre-existing): two independent bugs made every teleport in this puzzle
	-- unreachable regardless of which one was actually correct. First, the reference tile was always
	-- checked for a hardcoded item id (416) instead of the id matching the specific teleport the
	-- player just used (tiles.tileId, one of 416/417/418/423). Second, even had that matched,
	-- `tiles.tileId == tile` compared a number against an Item userdata (or nil) - a comparison Lua
	-- can never consider true - so the success branch was dead code, and it also read the nonexistent
	-- field `tile.positionTo` on that Item rather than `tiles.positionTo` on the config entry. Every
	-- step, correct or not, fell through to the "wrong" branch and bounced the player back to start.
	local currentTile = Tile(tileOne):getItemById(tiles.tileId)
	if currentTile then
		player:teleportTo(tiles.positionTo)
	else
		player:teleportTo(destination)
	end
	return false
end

stepTile:aid(57535, 57536, 57537, 57538)
stepTile:register()
