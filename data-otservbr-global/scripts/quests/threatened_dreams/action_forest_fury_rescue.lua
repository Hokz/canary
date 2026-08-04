-- Sweet Dreams / Captive Forest Fury rescue - Corym Black Market.
-- Map Setup Contract: aid 45730 must be placed on an object 2 floors below the Captive Forest
-- Fury, granting the Intricate Cage Key (item 48190, already exists in items.xml). aid 45731
-- must be placed on the fury's cage itself.
local ThreatenedDreams = Storage.Quest.U11_40.ThreatenedDreams

local keyAction = Action()
function keyAction.onUse(player, item, fromPosition, target, toPosition, isHotkey)
	if player:getStorageValue(ThreatenedDreams.Mission06[1]) ~= 2 then
		player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "You find nothing of interest here.")
		return true
	end
	if player:getStorageValue(ThreatenedDreams.Mission06.IntricateCageKey) >= 1 then
		player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "You already took the key.")
		return true
	end
	player:addItem(48190, 1)
	player:setStorageValue(ThreatenedDreams.Mission06.IntricateCageKey, 1)
	player:setStorageValue(ThreatenedDreams.Mission06[1], 3)
	player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "You find an intricate cage key hidden here.")
	return true
end

keyAction:aid(45730)
keyAction:register()

local cageAction = Action()
function cageAction.onUse(player, item, fromPosition, target, toPosition, isHotkey)
	if player:getStorageValue(ThreatenedDreams.Mission06.ForestFuryFreed) >= 1 then
		player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "The cage is already empty.")
		return true
	end
	if player:getStorageValue(ThreatenedDreams.Mission06.IntricateCageKey) < 1 or player:getStorageValue(ThreatenedDreams.Mission06.MirrorImagePaid) < 1 then
		player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "You are missing something you need before you can safely open this cage.")
		return true
	end
	if not player:getCondition(CONDITION_INVISIBLE) then
		player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "You need to be invisible to open this cage without the Coryms noticing.")
		return true
	end
	player:removeItem(48190, 1)
	player:setStorageValue(ThreatenedDreams.Mission06.ForestFuryFreed, 1)
	player:setStorageValue(ThreatenedDreams.Mission06[1], 5)
	player:addAchievement("A Friend in Need")
	player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "You unlock the cage and the forest fury slips away unseen. She presses a scrap of paper - the recipe for a gingerbread key - into your hand before vanishing.")
	toPosition:sendMagicEffect(CONST_ME_MAGIC_GREEN)
	return true
end

cageAction:aid(45731)
cageAction:register()
