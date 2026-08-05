-- "Aspiring Oracle" (added 12.70) - did not exist before this pass. Both find-spots' real positions
-- are unknown this pass (Salt Caves under the Green Belt for the frame; ruins of the Old Empire under
-- Krailos, reachable via a sun-symbol door in the Ruins of Nuur, for the gem) - registered against
-- placeholder uids, flagged CODE_READY_MAP_REQUIRED in the PR's Map Setup Contract.
local frameSpot = Action()

function frameSpot.onUse(player, item, fromPosition, target, toPosition, isHotkey)
	if player:getStorageValue(Storage.Quest.U12_20.KilmareshQuest.AspiringOracle.Questline) ~= 2 then
		player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "There is nothing of interest here.")
		return true
	end

	if player:getItemById(36707, 1) or player:getItemById(36708, 1) then
		player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "You already found the eye-shaped frame.")
		return true
	end

	player:addItem(36707, 1)
	player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "Among the salt-crusted stones, you find a golden, eye-shaped frame.")

	return true
end

frameSpot:uid(57552)
frameSpot:register()

local gemSpot = Action()

function gemSpot.onUse(player, item, fromPosition, target, toPosition, isHotkey)
	if player:getStorageValue(Storage.Quest.U12_20.KilmareshQuest.AspiringOracle.Questline) ~= 2 then
		player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "There is nothing of interest here.")
		return true
	end

	if player:getItemById(36706, 1) or player:getItemById(36708, 1) then
		player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "You already found the red gem.")
		return true
	end

	player:addItem(36706, 1)
	player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "Buried in the ruins of the Old Empire, you find a precious red gem.")

	return true
end

gemSpot:uid(57553)
gemSpot:register()

-- Source: "Find the two parts and combine them to restore the Eye of Suon." Using either part on
-- the other assembles the finished artefact.
local eyeCombine = Action()

function eyeCombine.onUse(player, item, fromPosition, target, toPosition, isHotkey)
	if not target or type(target) ~= "userdata" or not target.getId then
		return false
	end

	local otherId = item.itemid == 36707 and 36706 or (item.itemid == 36706 and 36707 or nil)
	if not otherId or target.itemid ~= otherId then
		return false
	end

	player:removeItem(36707, 1)
	player:removeItem(36706, 1)
	player:addItem(36708, 1)
	player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "You set the red gem into the eye-shaped frame. The two parts fuse together, restoring the Eye of Suon!")
	player:getPosition():sendMagicEffect(CONST_ME_MAGIC_BLUE)

	return true
end

eyeCombine:id(36706, 36707)
eyeCombine:register()
