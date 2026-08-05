-- "A Shark in Need" (Ninev, south-west Issavi) - source: "scissors from a sarcophagus one level
-- below," reused on a living sheep to obtain wool. Reuses the same "ritual scissors" item (31327)
-- already used by Midnight Rituals rather than fabricating a duplicate scissors item. Real target
-- uid unknown (no map/position reference available this pass); 57551 is a placeholder reserved for
-- this fix - flagged CODE_READY_MAP_REQUIRED in the PR's Map Setup Contract.
local sharkSarcophagus = Action()

function sharkSarcophagus.onUse(player, item, fromPosition, target, toPosition, isHotkey)
	if player:getStorageValue(Storage.Quest.U12_20.KilmareshQuest.NinevShark.Questline) ~= 1 then
		player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "An old, empty sarcophagus.")
		return true
	end

	if player:getItemById(31327, 1) then
		player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "You already have a pair of scissors.")
		return true
	end

	player:addItem(31327, 1)
	player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "You find a pair of scissors hidden inside the sarcophagus.")

	return true
end

sharkSarcophagus:uid(57551)
sharkSarcophagus:register()

-- Source: "Use scissors on living sheep... Do not kill sheep." Shears wool from a live Sheep without
-- harming it - explicitly NOT the same as looting a killed sheep's corpse (sheep.lua already drops
-- wool as ordinary loot at 1% per kill, but the source is emphatic that killing the sheep is wrong
-- here). No civic fine/guard-report system for killing a quest-relevant sheep exists anywhere in this
-- repo (confirmed via a broad repo-wide search) - not implemented, since inventing an entire
-- city-guard fine mechanic is outside a single mission's scope; classified as a documented Global-like
-- gap rather than silently skipped.
local sharkShear = Action()

function sharkShear.onUse(player, item, fromPosition, target, toPosition, isHotkey)
	if not target or not target:isMonster() or target:getName():lower() ~= "sheep" then
		return false
	end

	if player:getStorageValue(Storage.Quest.U12_20.KilmareshQuest.NinevShark.Questline) ~= 1 then
		return false
	end

	local progress = player:getStorageValue(Storage.Quest.U12_20.KilmareshQuest.NinevShark.Progress)
	if progress < 0 then
		progress = 0
	end

	if testFlag(progress, 2) then
		player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "You already sheared enough wool.")
		return true
	end

	player:addItem(10319, 1)
	player:setStorageValue(Storage.Quest.U12_20.KilmareshQuest.NinevShark.Progress, progress + 2)
	player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "You carefully shear a bundle of wool from the sheep, unharmed.")
	target:getPosition():sendMagicEffect(CONST_ME_MAGIC_GREEN)

	return true
end

sharkShear:id(31327)
sharkShear:register()
