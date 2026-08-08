local childrenMission3 = Action()

function childrenMission3.onUse(player, item, fromPosition, target, toPosition, isHotkey)
	-- CONFIRMED (bounded research): the Flask of Poison is renewable from this storage room for
	-- as long as Mission 3 is still active and the poison hasn't been used yet - losing it must
	-- not permanently block the mission. Questline 9 = mission accepted, not yet picked up.
	-- Questline 10 = already picked up once, not yet poured (i.e. lost and needs a replacement).
	local questline = player:getStorageValue(Storage.Quest.U8_54.ChildrenOfTheRevolution.Questline)
	if questline == 9 or questline == 10 then
		if questline == 9 then
			player:setStorageValue(Storage.Quest.U8_54.ChildrenOfTheRevolution.Questline, 10)
		end
		player:addItem(10183, 1)
		player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "You have found a flask of poison.")
	else
		player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "The chest is empty.")
	end

	return true
end

childrenMission3:uid(3164)
childrenMission3:register()
