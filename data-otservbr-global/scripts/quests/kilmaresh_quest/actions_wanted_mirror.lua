-- "Wanted" (added 12.70) - did not exist before this pass. Source: golden hand mirror found in the
-- ruins of Nuur. Real position unknown this pass; registered against a placeholder uid, flagged
-- CODE_READY_MAP_REQUIRED in the PR's Map Setup Contract.
local mirrorSpot = Action()

function mirrorSpot.onUse(player, item, fromPosition, target, toPosition, isHotkey)
	if player:getStorageValue(Storage.Quest.U12_20.KilmareshQuest.Wanted.Questline) < 1 then
		player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "There is nothing of interest here.")
		return true
	end

	if player:getItemById(36875, 1) then
		player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "You already found the golden hand mirror.")
		return true
	end

	player:addItem(36875, 1)
	player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "Among the ruins, you find a precious golden hand mirror.")

	return true
end

mirrorSpot:uid(57561)
mirrorSpot:register()

-- Source: "blacken it over a fire and cover it in soot." No specific fire object position is
-- available this pass, so this is a self-use action (no target fire object required) - a minor,
-- explicitly documented simplification of this one flavor step; the ritual's actual gated
-- interaction (the Suon shrine, actions_suon_shrine.lua) is implemented faithfully.
local mirrorSoot = Action()

function mirrorSoot.onUse(player, item, fromPosition, target, toPosition, isHotkey)
	-- CONFIRMED HARDENING (found via review): the mirror pickup itself is gated on
	-- Wanted.Questline >= 1, but the item is an ordinary tradeable object - a player who received it
	-- by trade rather than picking it up themselves could self-soot without ever having accepted the
	-- mission from Eshaya.
	if player:getStorageValue(Storage.Quest.U12_20.KilmareshQuest.Wanted.Questline) < 1 then
		player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "Nothing happens.")
		return true
	end

	if player:getStorageValue(Storage.Quest.U12_20.KilmareshQuest.Wanted.MirrorSoot) >= 1 then
		player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "The mirror is already blackened with soot.")
		return true
	end

	player:setStorageValue(Storage.Quest.U12_20.KilmareshQuest.Wanted.MirrorSoot, 1)
	player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "You hold the golden hand mirror over an open flame until it is thoroughly blackened with soot.")
	player:getPosition():sendMagicEffect(CONST_ME_SMOKE)

	return true
end

mirrorSoot:id(36875)
mirrorSoot:register()
