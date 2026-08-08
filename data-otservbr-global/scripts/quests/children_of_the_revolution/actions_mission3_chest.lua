local childrenMission3 = Action()

function childrenMission3.onUse(player, item, fromPosition, target, toPosition, isHotkey)
	-- CONFIRMED (bounded research): the Flask of Poison is renewable from this storage room for
	-- as long as Mission 3 is still active and the poison hasn't been used yet - losing it must
	-- not permanently block the mission. Questline 9 = mission accepted, not yet picked up.
	-- Questline 10 = already picked up once, not yet poured (i.e. lost and needs a replacement).
	--
	-- CONFIRMED BUG (found in review): the flask (item 10183) has no moveable="0" attribute, so
	-- it can be dropped/traded/deposited like any other item, and player:getItemCount() only
	-- searches inventory + backpacks (Player::getItemTypeCount, player.cpp) - never the depot.
	-- Gating on Questline alone let a player holding the flask simply reopen the chest and get a
	-- second one with no loss at all. Requiring possession == 0 closes that trivial case. A
	-- player who deposits the flask in their depot could still, in principle, obtain a second
	-- copy this way, but it buys them nothing: only one flask is ever consumable (the pour action
	-- requires Questline == 10 exactly and advances it to 11 on success), so a stashed spare is
	-- permanently inert quest clutter, not a farmable resource.
	local questline = player:getStorageValue(Storage.Quest.U8_54.ChildrenOfTheRevolution.Questline)
	if (questline == 9 or questline == 10) and player:getItemCount(10183) == 0 then
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
