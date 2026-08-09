local childrenMission3 = Action()

function childrenMission3.onUse(player, item, fromPosition, target, toPosition, isHotkey)
	-- REVERTED (found in review): an earlier revision made this renewable while Questline == 9
	-- or 10 to protect against a lost flask, gated only by player:getItemCount() == 0. That check
	-- only searches inventory/backpacks (Player::getItemTypeCount, player.cpp) - never the depot
	-- - and both the Flask of Poison and Flask of Extra Greasy Oil are confirmed tradeable/
	-- marketable, so a player could stash or trade away a "spare" and farm unlimited copies to
	-- transfer to other characters. No reliable source proves this chest is renewable after loss
	-- in the first place (LOST ITEM SOURCE RECOVERY: NOT_PROVEN FROM QUEST SOURCE - walkthroughs
	-- only describe a single pickup). Restored the original one-time gate rather than ship a
	-- speculative, exploitable recovery mechanism.
	if player:getStorageValue(Storage.Quest.U8_54.ChildrenOfTheRevolution.Questline) == 9 then
		player:setStorageValue(Storage.Quest.U8_54.ChildrenOfTheRevolution.Questline, 10)
		player:addItem(10183, 1)
		player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "You have found a flask of poison.")
	else
		player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "The chest is empty.")
	end

	return true
end

childrenMission3:uid(3164)
childrenMission3:register()
