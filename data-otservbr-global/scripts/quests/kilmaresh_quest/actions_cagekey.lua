local cagekey = Action()

function cagekey.onUse(player, item, frompos, item2, topos)
	-- Uses RevengeOfTheOgres.Questline (stage 1 = mission accepted) instead of the old
	-- Fourteen.Remains, which belonged to "The Boards that Mean the World" and gated this mission
	-- behind that one - see the comment in npc/saideh.lua.
	if player:getStorageValue(Storage.Quest.U12_20.KilmareshQuest.RevengeOfTheOgres.Questline) == 1 then
		-- Transactional: stage 2 is one-way and this chest cannot be re-searched, so a failed delivery
		-- would permanently strand the player without the key the dungeon requires.
		if not player:addItem(31379, 1, false) then -- Wooden Cage Key
			player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "You cannot carry the cage key right now.")
			return true
		end

		player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "You have found a wooden cage key.")
		player:setStorageValue(Storage.Quest.U12_20.KilmareshQuest.RevengeOfTheOgres.Questline, 2)
	else
		player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "Empty.")
	end

	return true
end

cagekey:uid(57530)
cagekey:register()
