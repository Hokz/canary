-- Fairy Treasure / Beset Stones - 5 sentient stones around Grumpy Stone, raked with a Rake (3452).
-- Map Setup Contract: aid 45710-45714 must be placed on the 5 sentient stone items (25446-25465
-- range) around Grumpy Stone, between Kazordoon and Femor Hills.
local ThreatenedDreams = Storage.Quest.U11_40.ThreatenedDreams

local stoneGuards = {
	[45710] = ThreatenedDreams.Mission04.Stone1,
	[45711] = ThreatenedDreams.Mission04.Stone2,
	[45712] = ThreatenedDreams.Mission04.Stone3,
	[45713] = ThreatenedDreams.Mission04.Stone4,
	[45714] = ThreatenedDreams.Mission04.Stone5,
}

local rakeAction = Action()
function rakeAction.onUse(player, item, fromPosition, target, toPosition, isHotkey)
	if not target then
		return false
	end
	local guardStorage = stoneGuards[target:getActionId()]
	if not guardStorage then
		return false
	end
	if player:getStorageValue(ThreatenedDreams.Mission04.MapGrumpyStone) >= 1 then
		player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "This stone is already well kept.")
		return true
	end
	if player:getStorageValue(guardStorage) >= 1 then
		player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "You already raked this stone.")
		return true
	end
	player:setStorageValue(guardStorage, 1)
	toPosition:sendMagicEffect(CONST_ME_POFF)
	player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "You rake away the weeds and moss covering the stone. It seems to sigh in relief.")
	local raked = math.max(player:getStorageValue(ThreatenedDreams.Mission04.StonesRaked), 0) + 1
	player:setStorageValue(ThreatenedDreams.Mission04.StonesRaked, raked)
	return true
end

rakeAction:id(3452)
rakeAction:register()

-- The Last Part - Big Fly Agaric, Fields of Glory (item 25385/25386, no new aid needed).
local agaricAction = Action()
function agaricAction.onUse(player, item, fromPosition, target, toPosition, isHotkey)
	if player:getStorageValue(ThreatenedDreams.Mission04.MapGrumpyStone) < 1 then
		player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "You search around but find nothing of interest yet.")
		return true
	end
	if player:getStorageValue(ThreatenedDreams.Mission04.MapLastPart) >= 1 then
		player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "You already searched this agaric.")
		return true
	end
	player:setStorageValue(ThreatenedDreams.Mission04.MapLastPart, 1)
	player:addItem(24946, 1)
	player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "You discover the fourth map part between the big fly agaric's gills.")
	return true
end

agaricAction:id(25385, 25386)
agaricAction:register()

-- Combine all 4 parts into the Old Map.
local mapParts = { 24943, 24944, 24945, 24946 }
local combineAction = Action()
function combineAction.onUse(player, item, fromPosition, target, toPosition, isHotkey)
	for _, partId in ipairs(mapParts) do
		if player:getItemCount(partId) < 1 then
			player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "You need all four parts of the old map before you can piece them together.")
			return true
		end
	end
	for _, partId in ipairs(mapParts) do
		player:removeItem(partId, 1)
	end
	player:addItem(24947, 1)
	player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "You piece the four parts together into a complete old map.")
	return true
end

combineAction:id(24943, 24944, 24945, 24946)
combineAction:register()

-- Use the assembled Old Map to reveal the hint, then dig at the Thais sun mosaic.
local oldMapAction = Action()
function oldMapAction.onUse(player, item, fromPosition, target, toPosition, isHotkey)
	player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "The old map is artfully drawn. It tells you to search for a stone sun mosaic in the very south of Thais.")
	player:setStorageValue(ThreatenedDreams.Mission04.OldMapAssembled, 1)
	return true
end

oldMapAction:id(24947)
oldMapAction:register()

-- Map Setup Contract: aid 45715 must be placed on the small stones at the center of the sun
-- mosaic in the very south of Thais.
local treasureAction = Action()
function treasureAction.onUse(player, item, fromPosition, target, toPosition, isHotkey)
	if player:getStorageValue(ThreatenedDreams.Mission04.OldMapAssembled) < 1 then
		player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "These stones are arranged in an odd mosaic, but you see nothing of interest.")
		return true
	end
	if player:getStorageValue(ThreatenedDreams.Mission04.TreasureFound) >= 1 then
		player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "You already found the fairy treasure hidden here.")
		return true
	end
	player:setStorageValue(ThreatenedDreams.Mission04.TreasureFound, 1)
	player:addItem(25698, 1) -- butterfly ring
	player:addItem(25737, 5) -- rainbow quartz
	player:addItem(24390, 5) -- ancient coin
	player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "You discover something shiny that is hidden beneath the stones.")
	toPosition:sendMagicEffect(CONST_ME_HOLYAREA)
	return true
end

treasureAction:aid(45715)
treasureAction:register()
