local doors = {
	[1] = { doorPosition = Position(32963, 32319, 9), storage = Storage.Quest.U11_80.TheSecretLibrary.Darashia.PuzzleSqm, value = 39 },
	-- CORRECTION (Secret Library repair v2, section 6): was value = 40. The 39-step numbered-tile
	-- puzzle (movements_teleportTo.lua) increments PuzzleSqm up to exactly #puzzle == 39 and never
	-- higher - a threshold of 40 made this door permanently unopenable regardless of legitimate
	-- completion. Corrected to the actual maximum the puzzle logic can produce, matching door 1's own
	-- threshold (both gate on "puzzle complete").
	[2] = { doorPosition = Position(32955, 32304, 9), storage = Storage.Quest.U11_80.TheSecretLibrary.Darashia.PuzzleSqm, value = 39 },
	[3] = { doorPosition = Position(32984, 32314, 9), storage = Storage.Quest.U11_80.TheSecretLibrary.Darashia.FirstChest, value = 1 },
	[4] = { doorPosition = Position(32968, 32324, 9), storage = Storage.Quest.U11_80.TheSecretLibrary.Darashia.SecondChest, value = 1 },
	[5] = { doorPosition = Position(32978, 32290, 10), storage = Storage.Quest.U11_80.TheSecretLibrary.Darashia.EatenFood, value = 4 },
	[6] = { doorPosition = Position(32963, 32297, 8), storage = Storage.Quest.U11_80.TheSecretLibrary.Darashia.Questline, value = 7 },
	[7] = { doorPosition = Position(32963, 32299, 8), storage = Storage.Quest.U11_80.TheSecretLibrary.Darashia.Questline, value = 7 },
	[8] = { doorPosition = Position(32963, 32301, 8), storage = Storage.Quest.U11_80.TheSecretLibrary.Darashia.Questline, value = 7 },
	[9] = { doorPosition = Position(32963, 32303, 8), storage = Storage.Quest.U11_80.TheSecretLibrary.Darashia.Questline, value = 7 },
}

local actions_desert_doors = Action()

function actions_desert_doors.onUse(player, item, fromPosition, target, toPosition, isHotkey)
	for _, p in pairs(doors) do
		if (item:getPosition() == p.doorPosition) and not (Tile(item:getPosition()):getTopCreature()) and isInArray({ 8361, 8355, 20450 }, item.itemid) then
			if player:getStorageValue(p.storage) >= p.value then
				player:teleportTo(toPosition, true)
				item:transform(item.itemid + 1)
			else
				player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "The door seems to be sealed against unwanted intruders.")
			end
		end
	end
	return true
end

actions_desert_doors:aid(4930)
actions_desert_doors:register()
