-- Hidden Treasure sidequest - Eustacio's house garment (Mission Ra'Clette) and Queso's wall
-- carving (Mission Queso), both simple discovery actions rather than NPC dialogue.
-- Map Setup Contract: aid 45980 = the wardrobe/chest inside Eustacio's house (southern Venore,
-- behind the door gated on APiratesTail.Mission06.EustacioHouseDoor); aid 45981 = the wall
-- carving in Queso's cell (Thais prison, northwest of the stairs).
local APiratesTail = Storage.Quest.U12_60.APiratesTail

local garmentSearch = Action()
function garmentSearch.onUse(player, item, fromPosition, target, toPosition, isHotkey)
	if player:getStorageValue(APiratesTail.Mission06.EustacioHouseDoor) < 1 then
		player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "This isn't your house to search.")
		return true
	end
	if player:getStorageValue(APiratesTail.Mission06[1]) ~= 4 then
		player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "You find nothing of further interest here.")
		return true
	end
	if player:getStorageValue(APiratesTail.Mission06.GarmentObtained) >= 1 then
		player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "You already took a garment from here.")
		return true
	end
	player:setStorageValue(APiratesTail.Mission06.GarmentObtained, 1)
	player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "You search the room and find a scarf belonging to Eustacio.")
	toPosition:sendMagicEffect(CONST_ME_POFF)
	return true
end
garmentSearch:aid(45980)
garmentSearch:register()

-- CUSTOM_GLOBAL_LIKE_PENDING_EXACT_REFERENCE: the reference says only that a rhyme line is
-- carved into the cell wall, not its exact wording - the line below is invented flavor text.
local quesoWall = Action()
function quesoWall.onUse(player, item, fromPosition, target, toPosition, isHotkey)
	if player:getStorageValue(APiratesTail.Mission06[1]) ~= 6 then
		player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "The wall is covered in scratches and stains, nothing more.")
		return true
	end
	player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "Carved into the wall: ,Rita, Sniff, Ra'Clette and I know the way - find the sun where shadows fade, and the treasure waits for day.' You now know the complete rhyme.")
	player:setStorageValue(APiratesTail.Mission06[1], 7)
	return true
end
quesoWall:aid(45981)
quesoWall:register()
