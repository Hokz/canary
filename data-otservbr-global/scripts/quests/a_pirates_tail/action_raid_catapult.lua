-- A Pirate's Tail - ship attack raid: pick a stone from the pile, load it with a Greenish
-- Flintstone onto the catapult, then pull the lever to fire (6 points per shot, capped at 300
-- points per raid by the scheduler). The same 3 action ids are reused at all 5 raid locations -
-- see the Map Setup Contract for exact placement, one stone pile/catapult/lever set per location.
local STONE_PILE_AID = 45910
local CATAPULT_AID = 45911
local LEVER_AID = 45912
local HEAVY_STONE_ID = 12724 -- "heavy stone" - existing generic quest item, already described in
-- items.xml as "It can be used to arm catapults" (reused from The Rookie Guard's identical
-- stone-pile/catapult mechanic, not fabricated for this quest)
local FLINTSTONE_ID = 35337 -- Greenish Flintstone

local function shipRaidActive()
	return Game.getStorageValue(GlobalStorage.APiratesTailRaid.Active) == 1 and Game.getStorageValue(GlobalStorage.APiratesTailRaid.Type) == 3
end

local stonePile = Action()
function stonePile.onUse(player, item, fromPosition, target, toPosition, isHotkey)
	if not shipRaidActive() then
		player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "There is no pirat ship attacking right now.")
		return true
	end
	player:addItem(HEAVY_STONE_ID, 1)
	player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "You pick up a heavy stone to arm the catapult with.")
	return true
end
stonePile:aid(STONE_PILE_AID)
stonePile:register()

-- Loading: use the heavy stone on the catapult, then use the flintstone on the catapult to
-- light it. Both steps must be done before the lever will fire.
local catapultLoaded = {} -- creature id -> true, cleared once fired; ship encounters are short-lived so this doesn't need to survive a restart

local loadStone = Action()
function loadStone.onUse(player, item, fromPosition, target, toPosition, isHotkey)
	if not target or target:getActionId() ~= CATAPULT_AID then
		return false
	end
	if not shipRaidActive() then
		player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "There is no pirat ship attacking right now.")
		return true
	end
	item:remove(1)
	player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "You load the heavy stone onto the catapult. Now light it with a greenish flintstone.")
	return true
end
loadStone:id(HEAVY_STONE_ID)
loadStone:register()

local lightCatapult = Action()
function lightCatapult.onUse(player, item, fromPosition, target, toPosition, isHotkey)
	if not target or target:getActionId() ~= CATAPULT_AID then
		return false
	end
	if not shipRaidActive() then
		player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "There is no pirat ship attacking right now.")
		return true
	end
	catapultLoaded[player:getId()] = true
	player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "You light the catapult with the flintstone. Pull the lever to fire!")
	toPosition:sendMagicEffect(CONST_ME_FIREATTACK)
	return true
end
lightCatapult:id(FLINTSTONE_ID)
lightCatapult:register()

local fireCatapult = Action()
function fireCatapult.onUse(player, item, fromPosition, target, toPosition, isHotkey)
	if not shipRaidActive() then
		player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "There is no pirat ship attacking right now.")
		return true
	end
	if not catapultLoaded[player:getId()] then
		player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "The catapult isn't loaded and lit yet.")
		return true
	end
	catapultLoaded[player:getId()] = nil

	local shipPoints = Game.getStorageValue(GlobalStorage.APiratesTailRaid.ShipPoints)
	if shipPoints >= 300 then
		player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "The ship has already taken enough damage this raid.")
		return true
	end
	Game.setStorageValue(GlobalStorage.APiratesTailRaid.ShipPoints, shipPoints + 6)

	local total = math.max(player:getStorageValue(Storage.Quest.U12_60.APiratesTail.Mission01.RaidPoints), 0)
	player:setStorageValue(Storage.Quest.U12_60.APiratesTail.Mission01.RaidPoints, total + 6)
	player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "The catapult fires at the pirat ship!")
	toPosition:sendMagicEffect(CONST_ME_EXPLOSIONHIT)
	return true
end
fireCatapult:aid(LEVER_AID)
fireCatapult:register()
