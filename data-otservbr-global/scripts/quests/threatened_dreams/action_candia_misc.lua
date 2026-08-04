-- Sweet Dreams / Candia misc mechanics: Candy Lipstick, Sugar Daddy access, candy cane repairs,
-- Honey Elemental catching.
-- Map Setup Contract: aid 45740 = Candy Lipstick spot atop the Gingerbread Castle; aid 45741 =
-- Sugar Daddy's portal in the Chocolate Mines; aid 45742-45744 = the 3 broken wall locations
-- (2 on floor -1, 1 on floor -2); aid 45745 = the chest north of Candis holding candy canes.
local ThreatenedDreams = Storage.Quest.U11_40.ThreatenedDreams

local lipstickAction = Action()
function lipstickAction.onUse(player, item, fromPosition, target, toPosition, isHotkey)
	if player:getStorageValue(ThreatenedDreams.Mission06.CandiaAccess) < 1 then
		player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "You find nothing of interest here.")
		return true
	end
	if player:getStorageValue(ThreatenedDreams.Mission06.LipstickUsed) >= 1 then
		player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "You already understand the Candian tongue.")
		return true
	end
	player:setStorageValue(ThreatenedDreams.Mission06.LipstickUsed, 1)
	player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "You apply the candy lipstick. Suddenly, the strange gestures and murmurs of Candia's inhabitants make perfect sense!")
	toPosition:sendMagicEffect(CONST_ME_MAGIC_GREEN)
	return true
end

lipstickAction:aid(45740)
lipstickAction:register()

local candyCaneAids = { [45742] = true, [45743] = true, [45744] = true }

local candyCaneAction = Action()
function candyCaneAction.onUse(player, item, fromPosition, target, toPosition, isHotkey)
	if not target or not candyCaneAids[target:getActionId()] then
		return false
	end
	if player:getStorageValue(ThreatenedDreams.Mission06[1]) ~= 13 then
		return false
	end
	if player:getStorageValue(ThreatenedDreams.Mission06.CandyCaneCount) >= 3 then
		player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "This wall is already sealed.")
		return true
	end
	item:remove(1)
	toPosition:sendMagicEffect(CONST_ME_POFF)
	player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "You seal the broken wall with the candy cane.")
	local count = math.max(player:getStorageValue(ThreatenedDreams.Mission06.CandyCaneCount), 0) + 1
	player:setStorageValue(ThreatenedDreams.Mission06.CandyCaneCount, count)
	if count >= 3 and player:getStorageValue(ThreatenedDreams.Mission06.HoneyElementalCount) >= 5 then
		player:setStorageValue(ThreatenedDreams.Mission06[1], 14)
	end
	return true
end

candyCaneAction:id(3599)
candyCaneAction:register()

local caneChestAction = Action()
function caneChestAction.onUse(player, item, fromPosition, target, toPosition, isHotkey)
	if player:getStorageValue(ThreatenedDreams.Mission06[1]) ~= 13 then
		player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "The chest is empty.")
		return true
	end
	player:addItem(3599, 3)
	player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "You take 3 candy canes from the chest.")
	return true
end

caneChestAction:aid(45745)
caneChestAction:register()

-- Honey Elemental catching - use an empty jar (vial 2874, reused since no dedicated "jar" item
-- exists) on a live Honey Elemental to catch it.
local jarAction = Action()
function jarAction.onUse(player, item, fromPosition, target, toPosition, isHotkey)
	if not target or not target:isMonster() or target:getName():lower() ~= "honey elemental" then
		return false
	end
	if player:getStorageValue(ThreatenedDreams.Mission06[1]) ~= 13 then
		return false
	end
	if player:getStorageValue(ThreatenedDreams.Mission06.HoneyElementalCount) >= 5 then
		player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "You already caught enough Honey Elementals.")
		return true
	end
	item:remove(1)
	target:remove()
	player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "You catch the Honey Elemental in your jar!")
	local count = math.max(player:getStorageValue(ThreatenedDreams.Mission06.HoneyElementalCount), 0) + 1
	player:setStorageValue(ThreatenedDreams.Mission06.HoneyElementalCount, count)
	if count >= 5 and player:getStorageValue(ThreatenedDreams.Mission06.CandyCaneCount) >= 3 then
		player:setStorageValue(ThreatenedDreams.Mission06[1], 14)
	end
	return true
end

jarAction:id(2874)
jarAction:register()
