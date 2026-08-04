-- Fairy Treasure / Tooth Fairy mission - the 3 children's bedrooms (Thais/Venore/Carlin).
-- Map Setup Contract: aid 45706-45708 must be placed on the "chest of drawers" furniture item
-- next to each child's bed; aid 45703-45705 must be placed on the head part of each child's bed.
-- (45700-45702 intentionally avoided - already reserved by bigfoot_burden's warzone MoveEvent.)
local ThreatenedDreams = Storage.Quest.U11_40.ThreatenedDreams

local drawerAids = { [45706] = true, [45707] = true, [45708] = true }

local beds = {
	[45703] = ThreatenedDreams.Mission04.BedThais,
	[45704] = ThreatenedDreams.Mission04.BedVenore,
	[45705] = ThreatenedDreams.Mission04.BedCarlin,
}

-- Family Feud toothbrush delivery reuses the same 3 beds. No exact "toothbrush" item exists in
-- items.xml (the nearest match, item 36544 "brush", is an unrelated generic item and the only
-- other close hit, item 29943 "Alptramun's toothbrush", is a differently-branded boss trophy) -
-- GLOBAL_ITEM_PENDING_XML_VALIDATION / ACCEPTABLE_STORAGE_BACKED_FALLBACK. Delivery is tracked
-- purely through this storage-backed bed interaction rather than requiring a misleading carried
-- item; one bit per child packed into the existing ToothbrushDelivered slot.
local toothbrushBits = {
	[45703] = 1, -- Quero's child, Thais
	[45704] = 2, -- Allen's child, Venore
	[45705] = 4, -- Rowenna's child, Carlin
}

local drawerAction = Action()
function drawerAction.onUse(player, item, fromPosition, target, toPosition, isHotkey)
	if not drawerAids[item:getActionId()] then
		return false
	end
	if player:getStorageValue(ThreatenedDreams.Mission04[1]) ~= 1 then
		player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "You find nothing of interest here.")
		return true
	end
	player:addItem(25303, 1)
	player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "You found a milk tooth on the bed-stand.")
	return true
end

drawerAction:aid(45706, 45707, 45708)
drawerAction:register()

local bedAction = Action()
function bedAction.onUse(player, item, fromPosition, target, toPosition, isHotkey)
	local storageKey = beds[item:getActionId()]
	if not storageKey then
		return false
	end

	if player:getStorageValue(ThreatenedDreams.Mission06[1]) == 17 then
		local flag = toothbrushBits[item:getActionId()]
		local delivered = math.max(player:getStorageValue(ThreatenedDreams.Mission06.ToothbrushDelivered), 0)
		if bit.band(delivered, flag) ~= 0 then
			player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "You already left a toothbrush for this child.")
			return true
		end
		player:setStorageValue(ThreatenedDreams.Mission06.ToothbrushDelivered, bit.bor(delivered, flag))
		player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "You leave a toothbrush on the child's pillow, a small gift from the Tooth Fairy.")
		toPosition:sendMagicEffect(CONST_ME_MAGIC_GREEN)
		return true
	end

	if player:getStorageValue(ThreatenedDreams.Mission04[1]) ~= 1 then
		return false
	end
	if player:getStorageValue(storageKey) >= 1 then
		player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "You already left presents for this child.")
		return true
	end
	if player:getItemCount(37547) < 1 then
		player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "You have no presents left to leave for this child.")
		return true
	end
	player:removeItem(37547, 1)
	player:setStorageValue(storageKey, 1)
	player:setStorageValue(ThreatenedDreams.Mission04.MilkTeeth, math.max(player:getStorageValue(ThreatenedDreams.Mission04.MilkTeeth), 0) + 1)
	player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "You leave the presents on the bed for the child to find.")
	toPosition:sendMagicEffect(CONST_ME_MAGIC_GREEN)
	return true
end

bedAction:aid(45703, 45704, 45705)
bedAction:register()
