local scissors = Action()

function scissors.onUse(player, item, frompos, item2, topos)
	if player:getStorageValue(Storage.Quest.U12_20.KilmareshQuest.Set.Ritual) == 1 then
		-- Transactional: Set.Ritual 1 -> 2 is one-way and this pickup cannot be repeated, so a failed
		-- delivery would leave the player permanently without the scissors that four Midnight Rituals
		-- gathering steps require.
		if not player:addItem(31327, 1, false) then
			player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "You cannot carry the scissors right now.")
			return true
		end

		player:setStorageValue(Storage.Quest.U12_20.KilmareshQuest.Set.Ritual, 2)
		player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "You have found a  ritual scissors.")
	else
		player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "Empty.")
	end

	return true
end

-- CONFIRMED BUG (pre-existing): registered against the undefined global "uniqueid" instead of a real
-- unique id, which the engine rejects at load time - this pickup could never fire for any player.
-- Real target uid unknown (no map/position reference available); flagged CODE_READY_MAP_REQUIRED in
-- the PR's Map Setup Contract. 57549 is a placeholder reserved specifically for this fix, chosen to
-- avoid every uid already used elsewhere in this quest folder - replace with the real sarcophagus uid.
scissors:uid(57549)
scissors:register()
