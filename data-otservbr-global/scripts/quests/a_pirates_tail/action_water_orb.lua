-- A Pirate's Tail - water attack raid: use the Magical Water Orb on a contaminated water tile
-- within the active raid's water zone to create a temporary platform to stand on. Eustacio's
-- dialogue ("Take care of it this time") implies this is a reusable tool, not a one-shot
-- consumable, so the orb is never removed - only usable while a matching water raid is active.
local ORB_ID = 35376 -- Magical Water Orb
local PLATFORM_ID = 38348 -- "stepping stones" - existing artificial-tile item, unused elsewhere
local PLATFORM_DURATION = 60 * 1000 -- 1 minute

local waterOrb = Action()
function waterOrb.onUse(player, item, fromPosition, target, toPosition, isHotkey)
	if Game.getStorageValue(GlobalStorage.APiratesTailRaid.Active) ~= 1 or Game.getStorageValue(GlobalStorage.APiratesTailRaid.Type) ~= 2 then
		player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "The water isn't contaminated with raiding pirats right now.")
		return true
	end

	local location = getAPiratesTailActiveLocation()
	if not location.waterZone or not toPosition:isInRange(location.waterZone.from, location.waterZone.to) then
		player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "This isn't the water the pirats are attacking from.")
		return true
	end

	-- Water-tile detection is left to the waterZone rectangle configured by the map editor
	-- (the owner is expected to draw it tightly around the actual contaminated water) rather
	-- than a tile-flag check here - this codebase has no established Lua-side "is this water"
	-- helper to build one safely on.
	local tile = Tile(toPosition)
	if not tile or not tile:getGround() then
		return true
	end

	local platform = Game.createItem(PLATFORM_ID, 1, toPosition)
	if not platform then
		return true
	end
	toPosition:sendMagicEffect(CONST_ME_WATERSPLASH)
	addEvent(function()
		local existing = Tile(toPosition) and Tile(toPosition):getItemById(PLATFORM_ID)
		if existing then
			existing:remove()
		end
	end, PLATFORM_DURATION)
	return true
end
waterOrb:id(ORB_ID)
waterOrb:register()
