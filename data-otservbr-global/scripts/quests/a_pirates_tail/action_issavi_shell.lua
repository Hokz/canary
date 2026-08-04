-- A Pirate's Tail - the shell on the sand near Issavi's depot/temple, revealed by Eustacio after
-- reaching 1500 raid points. Leads to Rascacoon via a secret passage the reference describes as
-- populated with exotic bats, exotic cave spiders, and many rats.
-- Map Setup Contract: aid 45913 must be placed on a shell item on the sand next to the temple in
-- Issavi. Ideally a proper underground passage with those monster spawns connects it to
-- Rascacoon; without exact positions this teleports directly to the same arrival point the
-- existing Rascacoon shortcut already uses (Position(33774, 31347, 7)), so the quest remains
-- fully functional without the passage.
local APiratesTail = Storage.Quest.U12_60.APiratesTail

local issaviShell = Action()
function issaviShell.onUse(player, item, fromPosition, target, toPosition, isHotkey)
	if math.max(player:getStorageValue(APiratesTail.Mission01.RaidPoints), 0) < 1500 then
		player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "This is just an ordinary shell.")
		return true
	end
	player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "You crawl through a secret passage beneath the shell.")
	player:teleportTo(Position(33774, 31347, 7))
	player:getPosition():sendMagicEffect(CONST_ME_TELEPORT)
	if player:getStorageValue(APiratesTail.Mission02[1]) < 1 then
		player:setStorageValue(APiratesTail.Mission02[1], 1)
	end
	return true
end

issaviShell:aid(45913)
issaviShell:register()
