local lyre = Action()

function lyre.onUse(player, item, frompos, item2, topos)
	if player:getStorageValue(Storage.Quest.U12_20.KilmareshQuest.Thirteen.Lyre) == 2 then
		-- CONFIRMED BLOCKER (found in review): the stolen ivory lyre (31447) was created and
		-- Thirteen.Lyre advanced 2 -> 3 unconditionally. The bag only yields the lyre at exactly
		-- stage 2, so an over-capacity player had it dropped on the ground (addItem defaults
		-- canDropOnMap = true, player_functions.cpp:2378) while the storage moved past the only gate
		-- that can produce it - permanently unable to return it to Alyxo.
		-- Now transactional and non-duplicating: canDropOnMap = false so a truthy result proves the
		-- lyre is in the player's inventory, the storage advances only after that, and a player who
		-- already holds it simply has the storage repaired.
		if not player:getItemById(31447, 1) and not player:addItem(31447, 1, false) then
			player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "You cannot carry the ivory lyre right now.")
			return true
		end

		player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "You have found Lyre.")
		player:setStorageValue(Storage.Quest.U12_20.KilmareshQuest.Thirteen.Lyre, 3)
	else
		player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "The bag can not be opened.")
	end

	return true
end

lyre:uid(57529)
lyre:register()
