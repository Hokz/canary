local tortoise = Action()

function tortoise.onUse(player, item, frompos, item2, topos)
	if player:getStorageValue(Storage.Quest.U12_20.KilmareshQuest.Thirteen.Presente) == 1 then
		-- CONFIRMED BLOCKER (found in review): the animal present (31445) was created and
		-- Thirteen.Presente advanced 1 -> 2 unconditionally. The nest only yields it at exactly stage
		-- 1, so an over-capacity player had it dropped on the ground while the storage moved past the
		-- only gate that can produce it - permanently unable to deliver it. Same fix as
		-- actions_lyre.lua: transactional, canDropOnMap = false, non-duplicating on retry.
		if not player:getItemById(31445, 1) and not player:addItem(31445, 1, false) then
			player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "You cannot carry the animal present right now.")
			return true
		end

		player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "Tortoise.")
		player:setStorageValue(Storage.Quest.U12_20.KilmareshQuest.Thirteen.Presente, 2)
	else
		player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "The tortoise nest empty.")
	end

	return true
end

tortoise:uid(57528)
tortoise:register()
