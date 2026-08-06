local peeler = Action()

function peeler.onUse(player, item, frompos, item2, topos)
	if player:getStorageValue(Storage.Quest.U12_20.KilmareshQuest.Set.Ritual) == 2 then
		-- Transactional: item 31328 (bark peeler) is MECHANICALLY REQUIRED - it is the registered
		-- trigger of actions_peelerfun.lua, the only way to obtain the twenty pieces of honey palm bark
		-- Tefrit needs. Set.Ritual 2 -> 3 is one-way and this pickup only fires at exactly 2, so
		-- advancing without the tool would strand the player with no way to re-acquire it. Created only
		-- when not already held, so a retry after a failed attempt cannot hand out a second peeler.
		--
		-- canDropOnMap: left at the engine default (true, player_functions.cpp:2378), matching every
		-- other quest-tool grant in this repo - an over-capacity player gets the peeler on the ground
		-- rather than losing it. addItem still returns nil on a genuine creation/placement failure, and
		-- that is what this check catches.
		if not player:getItemById(31328, 1) and not player:addItem(31328, 1, false) then
			player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "You cannot carry the bark peeler right now.")
			return true
		end

		player:setStorageValue(Storage.Quest.U12_20.KilmareshQuest.Set.Ritual, 3)
		player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "You have found a bark peeler.")
	else
		player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "Empty.")
	end

	return true
end

peeler:uid(57518)
peeler:register()
