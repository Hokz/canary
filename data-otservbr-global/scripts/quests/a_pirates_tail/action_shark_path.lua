-- Hidden Treasure / Mission Sniff - retrieve the corym's goods from a barrel between wreckage on
-- the southern coast of the Plains of Havoc, guarded by sharks. Stepping on an unsafe water tile
-- sends the player back to the start and halves their current HP, matching the reference exactly.
--
-- MAP SETUP REQUIRED: HAZARD_TILES/startPosition/barrelAid need real positions - see the Map
-- Setup Contract. Hazard tiles share one action id; safe stepping-stones need no script at all.
local HAZARD_AID = 45970
local BARREL_AID = 45971
local startPosition = nil -- Position: where a caught player is sent back to

local APiratesTail = Storage.Quest.U12_60.APiratesTail

local hazardTile = MoveEvent()
function hazardTile.onStepIn(creature, item, position, fromPosition)
	local player = creature:getPlayer()
	if not player then
		return true
	end
	player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "A shark lunges at you! You swim back to shore, badly hurt.")
	player:addHealth(-math.floor(player:getHealth() / 2))
	if startPosition then
		player:teleportTo(startPosition)
	end
	return true
end
hazardTile:aid(HAZARD_AID)
hazardTile:register()

local barrel = Action()
function barrel.onUse(player, item, fromPosition, target, toPosition, isHotkey)
	if player:getStorageValue(APiratesTail.Mission06[1]) ~= 2 then
		player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "There is nothing of interest here.")
		return true
	end
	if player:getStorageValue(APiratesTail.Mission06.SniffGoodsRecovered) >= 1 then
		player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "You already recovered the goods from this barrel.")
		return true
	end
	player:setStorageValue(APiratesTail.Mission06.SniffGoodsRecovered, 1)
	player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "You find Sniff's precious goods in the barrel between the wreckage!")
	toPosition:sendMagicEffect(CONST_ME_POFF)
	return true
end
barrel:aid(BARREL_AID)
barrel:register()
