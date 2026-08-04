-- Final boss (Morgathla) access chain: crystal (gated on all 3 area bosses defeated) -> mallet-
-- assembly NPC room -> gong (mallet destroyed on use, 7-second teleport to the first Morgathla
-- room) -> creaturescripts_morgathla.lua's roomOneEntrance (aid 57410) takes over from there.
--
-- MAP SETUP REQUIRED: mostRoomPosition/gongTeleportPosition are nil until an owner configures
-- them - see the Map Setup Contract in the PR body.
local GONG_ID = 25768
local MALLET_ID = 27523
local mostRoomPosition = nil -- Position: where the crystal sends players (the mallet-NPC room)
local gongTeleportPosition = nil -- Position: appears next to the gong for 7 seconds
local morgathlaRoom1Entry = nil -- Position: the destination of that 7-second teleport (stepping
-- onto it also triggers creaturescripts_morgathla.lua's roomOneEntrance, aid 57410)

local Bosses = Storage.Quest.U11_50.DangerousDepths.Bosses

local accessCrystal = Action()
function accessCrystal.onUse(player, item, fromPosition, target, toPosition, isHotkey)
	if player:getStorageValue(Bosses.TheBaronFromBelowAchiev) < 1 or player:getStorageValue(Bosses.TheCountOfTheCoreAchiev) < 1 or player:getStorageValue(Bosses.TheDukeOfTheDepthsAchiev) < 1 then
		player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "The crystal stays dark. You must defeat all three champions of the depths first.")
		return true
	end
	if not mostRoomPosition then
		player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "The crystal hums, but nothing happens yet.")
		return true
	end
	player:teleportTo(mostRoomPosition)
	player:getPosition():sendMagicEffect(CONST_ME_TELEPORT)
	return true
end
accessCrystal:aid(57400)
accessCrystal:register()

-- Used mallet-on-gong (mallet is the source item, gong is the target), matching the reference
-- exactly ("use the mallet on the gong"), not the other way around.
local gong = Action()
function gong.onUse(player, item, fromPosition, target, toPosition, isHotkey)
	if not target or target:getId() ~= GONG_ID then
		return false
	end
	item:remove(1)
	toPosition:sendMagicEffect(CONST_ME_SOUND_WHITE)
	if not gongTeleportPosition then
		player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "The gong rings out, but nothing appears yet.")
		return true
	end
	local teleport = Game.createItem(1949, 1, gongTeleportPosition)
	if teleport and morgathlaRoom1Entry then
		teleport:setDestination(morgathlaRoom1Entry)
	end
	addEvent(function()
		local existing = Tile(gongTeleportPosition) and Tile(gongTeleportPosition):getItemById(1949)
		if existing then
			existing:remove()
		end
	end, 7 * 1000)
	return true
end
gong:id(MALLET_ID)
gong:register()
