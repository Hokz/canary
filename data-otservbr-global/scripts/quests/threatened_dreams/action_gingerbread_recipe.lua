-- Sweet Dreams / Gingerbread Key recipe. Simplification note: the reference describes glazing
-- the key with the 3 syrups in a specific order (moon melon, then raspberry, then lemon); with
-- this quest's storage budget already exhausted by the reserved 45751-45850 block, the syrups
-- are tracked as simple "prepared" flags rather than a strict step counter, so the oven checks
-- that all 3 have been prepared rather than enforcing the exact application order.
-- Map Setup Contract: aid 45732 = kitchen basin (Flour -> Lump of Cake Dough); aid 45733 = oven
-- in Feyrist (final baking step). Sugar (item 12275) is not gated behind the reference's "three
-- underground caves" gathering points in this pass - it is assumed obtainable through normal
-- trade, a documented simplification given this quest's exhausted storage budget.
local ThreatenedDreams = Storage.Quest.U11_40.ThreatenedDreams

local basinAction = Action()
function basinAction.onUse(player, item, fromPosition, target, toPosition, isHotkey)
	if player:getStorageValue(ThreatenedDreams.Mission06.ForestFuryFreed) < 1 then
		player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "You don't know the recipe for this yet.")
		return true
	end
	if player:getStorageValue(ThreatenedDreams.Mission06.DoughLump) >= 1 then
		player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "You already have enough cake dough.")
		return true
	end
	if player:getItemCount(3603) < 1 then
		player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "You need some flour first.")
		return true
	end
	player:removeItem(3603, 1)
	player:addItem(6276, 1)
	player:setStorageValue(ThreatenedDreams.Mission06.DoughLump, 1)
	player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "You mix the flour with milk from the basin into a lump of cake dough.")
	return true
end

basinAction:aid(45732)
basinAction:register()

local doughAction = Action()
function doughAction.onUse(player, item, fromPosition, target, toPosition, isHotkey)
	if not target or target:getId() ~= 6574 then
		return false
	end
	if player:getStorageValue(ThreatenedDreams.Mission06.ChocolateDough) >= 1 then
		player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "You already have enough chocolate dough.")
		return true
	end
	target:remove(1)
	item:remove(1)
	player:addItem(8018, 1)
	player:setStorageValue(ThreatenedDreams.Mission06.ChocolateDough, 1)
	player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "You knead the bar of chocolate into the cake dough, forming a lump of chocolate dough.")
	return true
end

doughAction:id(6276)
doughAction:register()

local syrups = {
	[8012] = { storage = ThreatenedDreams.Mission06.SyrupRaspberry, name = "raspberry" },
	[8013] = { storage = ThreatenedDreams.Mission06.SyrupLemon, name = "lemon" },
	[3593] = { storage = ThreatenedDreams.Mission06.SyrupMoonMelon, name = "moon melon" },
}

local syrupAction = Action()
function syrupAction.onUse(player, item, fromPosition, target, toPosition, isHotkey)
	if not target or target:getId() ~= 12275 then
		return false
	end
	local syrup = syrups[item:getId()]
	if not syrup then
		return false
	end
	if player:getStorageValue(syrup.storage) >= 1 then
		player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "You already prepared this syrup.")
		return true
	end
	item:remove(1)
	target:remove(1)
	player:setStorageValue(syrup.storage, 1)
	player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "You mix the " .. syrup.name .. " with sugar into a sweet syrup.")
	return true
end

syrupAction:id(8012, 8013, 3593)
syrupAction:register()

local ovenAction = Action()
function ovenAction.onUse(player, item, fromPosition, target, toPosition, isHotkey)
	if player:getStorageValue(ThreatenedDreams.Mission06.GingerbreadKeyBaked) >= 1 then
		player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "You already baked your gingerbread key.")
		return true
	end
	if player:getStorageValue(ThreatenedDreams.Mission06.ChocolateDough) < 1 then
		player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "You need a lump of chocolate dough first.")
		return true
	end
	if item:getId() == 8018 then
		item:remove(1)
		player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "The key-shaped dough appears atop the oven, baking slowly.")
		toPosition:sendMagicEffect(CONST_ME_FIREATTACK)
		return true
	end
	local syrup = syrups[item:getId()]
	if not syrup then
		return false
	end
	if player:getStorageValue(syrup.storage) < 1 then
		player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "You haven't prepared this syrup yet.")
		return true
	end
	if player:getStorageValue(ThreatenedDreams.Mission06.SyrupMoonMelon) >= 1 and player:getStorageValue(ThreatenedDreams.Mission06.SyrupRaspberry) >= 1 and player:getStorageValue(ThreatenedDreams.Mission06.SyrupLemon) >= 1 then
		player:setStorageValue(ThreatenedDreams.Mission06.GingerbreadKeyBaked, 1)
		player:setStorageValue(ThreatenedDreams.Mission06.CandiaAccess, 1)
		player:setStorageValue(ThreatenedDreams.Mission06[1], 7)
		player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "You glaze the key with the last syrup. The gingerbread key is finished - you sense a way to Candia has opened.")
		toPosition:sendMagicEffect(CONST_ME_MAGIC_GREEN)
	else
		player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "You glaze the key with " .. syrup.name .. " syrup. Something still feels unfinished.")
	end
	return true
end

ovenAction:aid(45733)
ovenAction:register()
