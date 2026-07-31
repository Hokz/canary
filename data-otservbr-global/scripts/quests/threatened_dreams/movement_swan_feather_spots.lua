-- The Swan Feather Cloak (Valindara) - 8 feather-collection spots around Feyrist, day-only.
-- Each spot is a shared field node (matching how field-collectible resources work elsewhere in
-- Tibia) with its own independent 20h cooldown, tracked via Game-scoped string storage rather
-- than the numeric Storage.Quest range (Mission05's numeric budget was already exhausted by the
-- reserved 45751-45850 block). A player visiting all 8 spots nets the full 40-feather harvest
-- the reference describes; each spot then relocks independently for 20h.
-- Map Setup Contract: aid 45720-45727 must be placed on 8 tiles near swans around Feyrist.
local ThreatenedDreams = Storage.Quest.U11_40.ThreatenedDreams

local spotKeys = {
	[45720] = "SwanFeatherSpot1",
	[45721] = "SwanFeatherSpot2",
	[45722] = "SwanFeatherSpot3",
	[45723] = "SwanFeatherSpot4",
	[45724] = "SwanFeatherSpot5",
	[45725] = "SwanFeatherSpot6",
	[45726] = "SwanFeatherSpot7",
	[45727] = "SwanFeatherSpot8",
}

local feathersSpot = MoveEvent()

function feathersSpot.onStepIn(creature, item, position, fromPosition)
	local player = creature:getPlayer()
	if not player then
		return true
	end

	local key = spotKeys[item:getActionId()]
	if not key then
		return true
	end

	if getWorldLight().level > 40 then
		return true
	end

	if Game.getStorageValue(key) > os.time() then
		return true
	end

	player:addItem(26181, 5)
	player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "You gather 5 swan feathers from the grass.")
	Game.setStorageValue(key, os.time() + 20 * 3600)
	player:setStorageValue(ThreatenedDreams.Mission05.FeatherCount, math.max(player:getStorageValue(ThreatenedDreams.Mission05.FeatherCount), 0) + 5)
	return true
end

feathersSpot:type("stepin")
feathersSpot:aid(45720, 45721, 45722, 45723, 45724, 45725, 45726, 45727)
feathersSpot:register()
