-- "A Shark in Need" (Ninev, south-west Issavi) was entirely unimplemented before this pass - see
-- npc/ninev.lua for the mission dialogue. Source: "salve found in ashes" at a marked spot near the
-- city. No "healing salve" item exists anywhere in items.xml, so this step (and the later
-- "waterproof salve" it becomes once combined with wool) is tracked as a storage bit rather than a
-- fabricated item, per the item-fallback rule. Real target uid unknown (no map/position reference
-- available this pass); 57550 is a placeholder reserved for this fix - flagged
-- CODE_READY_MAP_REQUIRED in the PR's Map Setup Contract. Replace with the real ash pile's uid.
local PROGRESS_SALVE = 1
local PROGRESS_WOOL = 2
local PROGRESS_COMBINED = 4

local sharkSalve = Action()

function sharkSalve.onUse(player, item, fromPosition, target, toPosition, isHotkey)
	if player:getStorageValue(Storage.Quest.U12_20.KilmareshQuest.NinevShark.Questline) ~= 1 then
		player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "Cold ashes. Nothing of interest here.")
		return true
	end

	local progress = player:getStorageValue(Storage.Quest.U12_20.KilmareshQuest.NinevShark.Progress)
	if progress < 0 then
		progress = 0
	end

	if testFlag(progress, PROGRESS_SALVE) then
		player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "You already found the healing salve here.")
		return true
	end

	player:setStorageValue(Storage.Quest.U12_20.KilmareshQuest.NinevShark.Progress, progress + PROGRESS_SALVE)
	player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "Digging through the cold ashes, you find a small pot of healing salve that resists salt water.")

	return true
end

sharkSalve:uid(57550)
sharkSalve:register()

-- Source: "Use sheep-derived item on salve to create waterproof salve." The wool obtained from
-- shearing a live sheep (see actions_shark_scissors.lua) is used back on this same ash pile to
-- combine it with the salve found here.
local sharkCombine = Action()

function sharkCombine.onUse(player, item, fromPosition, target, toPosition, isHotkey)
	if not target or target.uid ~= 57550 then
		return false
	end

	if player:getStorageValue(Storage.Quest.U12_20.KilmareshQuest.NinevShark.Questline) ~= 1 then
		return false
	end

	local progress = player:getStorageValue(Storage.Quest.U12_20.KilmareshQuest.NinevShark.Progress)
	if progress < 0 then
		progress = 0
	end

	if not testFlag(progress, PROGRESS_SALVE) or not testFlag(progress, PROGRESS_WOOL) then
		player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "You need both the healing salve and some wool before you can prepare the mixture.")
		return true
	end

	if testFlag(progress, PROGRESS_COMBINED) then
		player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "You already prepared the waterproof salve.")
		return true
	end

	player:removeItem(10319, 1)
	player:setStorageValue(Storage.Quest.U12_20.KilmareshQuest.NinevShark.Progress, progress + PROGRESS_COMBINED)
	player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "You work the wool into the salve until it turns thick and waterproof. This should help the injured shark.")

	return true
end

sharkCombine:id(10319)
sharkCombine:register()
