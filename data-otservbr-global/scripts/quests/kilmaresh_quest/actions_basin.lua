-- CONFIRMED BLOCKER (found in review): this checked only Tem.Bleeds == 1 and then unconditionally
-- granted item 31431 and WROTE Eleven.Basin = 1. Tem.Bleeds is never cleared, so a player who had
-- already completed the Midnight Pilgrimage (Eleven.Basin == 2) could reuse the basin to obtain a
-- second symbol AND regress Basin 2 -> 1, then report to Kallimae again for another Regalia part
-- (31572) - an unbounded reward loop, repeatable indefinitely.
--
-- Now monotonic and transactional:
--   * only starts the basin state when Tem.Bleeds == 1 AND Eleven.Basin < 1, so the storage can never
--     be lowered from 2 (or from 1) by this action;
--   * delivers the symbol with canDropOnMap = false (Lua arg 3 -> stack index 4,
--     player_functions.cpp:2378). With the engine default of true an over-capacity player would have
--     the unique quest item silently dropped on the ground while the storage advanced anyway, which
--     for a one-time pilgrimage item is unrecoverable. With false, addItem returns nil instead, so a
--     truthy result genuinely proves the item is in the player's inventory;
--   * advances the storage only after delivery is confirmed, so a failed attempt leaves the player
--     free to retry once they have space;
--   * if the player already holds a symbol but the storage is somehow unset, the storage is repaired
--     without granting a second one.
local basin = Action()

function basin.onUse(player, item, frompos, item2, topos)
	local basinValue = player:getStorageValue(Storage.Quest.U12_20.KilmareshQuest.Eleven.Basin)

	if basinValue >= 1 then
		player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "You have already taken the golden symbol from the basin.")
		return true
	end

	if player:getStorageValue(Storage.Quest.U12_20.KilmareshQuest.Tem.Bleeds) ~= 1 then
		player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "Sorry")
		return true
	end

	-- Already holding the symbol from an interrupted attempt: repair the storage, grant nothing.
	if player:getItemById(31431, 1) then
		player:setStorageValue(Storage.Quest.U12_20.KilmareshQuest.Eleven.Basin, 1)
		player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "You already carry the golden symbol from this basin.")
		return true
	end

	if not player:addItem(31431, 1, false) then
		player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "You cannot carry the golden symbol right now.")
		return true
	end

	player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "You find a golden symbol at the bottom of the blood-filled basin.")
	player:setStorageValue(Storage.Quest.U12_20.KilmareshQuest.Eleven.Basin, 1)

	return true
end

basin:uid(57527)
basin:register()
