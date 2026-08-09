-- The three world interactions of the Zzuppliezz task. Task state and the transactional turn-in
-- live in lib/quests/zzuppliezz.lua; see npc/zalamon.lua and npc/chartan.lua for the dialogue.
--
-- Physical positions are startup-wired in startup/tables/item.lua (uids 57570-57572) using
-- position-first, read-only OTBM evidence - not guessed and not requiring any OTBM edit.
--
-- Each source grants its item(s) exactly once per cycle. Without that, a player could keep
-- re-triggering a source to farm quest items indefinitely; with it, losing an item mid-cycle means
-- starting a fresh cycle (re-accepting the task) rather than an infinite replacement supply.
local WEAPONS_RACK_UID = 57570
local FISH_SOURCE_UID = 57571
local PRISONER_FENCE_UID = 57572

local rack = Action()

function rack.onUse(player, item, fromPosition, target, toPosition, isHotkey)
	if not Zzuppliezz.isActive(player) then
		player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "A rack of lizard weapons. You have no reason to take any.")
		return true
	end

	if Zzuppliezz.hasTakenCrate(player) then
		player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "You already took what you need from this rack this cycle.")
		return true
	end

	if not player:addItem(Zzuppliezz.ITEM_WEAPONS_CRATE, 1, false) then
		player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "You cannot carry the heavy crate right now.")
		return true
	end

	Zzuppliezz.markCrateTaken(player)
	player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "You quietly lift a crate of weapons from the rack.")
	return true
end

rack:uid(WEAPONS_RACK_UID)
rack:register()

local supplies = Action()

function supplies.onUse(player, item, fromPosition, target, toPosition, isHotkey)
	if not Zzuppliezz.isActive(player) then
		player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "Salted provisions, stacked for the emperor's soldiers.")
		return true
	end

	if Zzuppliezz.hasTakenFish(player) then
		player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "You already took what you need from this store this cycle.")
		return true
	end

	if not player:addItem(Zzuppliezz.ITEM_CORNED_FISH, Zzuppliezz.FISH_REQUIRED, false) then
		player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "You cannot carry the fish right now.")
		return true
	end

	Zzuppliezz.markFishTaken(player)
	player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "You take two salted fish from the store.")
	return true
end

supplies:uid(FISH_SOURCE_UID)
supplies:register()

-- This is the step the task exists for, so completion requires proof it happened
-- (Zzuppliezz.hasFedPrisoners), not merely that the right items are carried. First successful
-- feeding grants "Vive la Resistance" (owner reference), once only.
local prisoners = Action()

function prisoners.onUse(player, item, fromPosition, target, toPosition, isHotkey)
	if not Zzuppliezz.isActive(player) then
		player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "Hollow-eyed prisoners watch you from behind the bars.")
		return true
	end

	if Zzuppliezz.hasFedPrisoners(player) then
		player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "You already fed the prisoners this cycle.")
		return true
	end

	-- Two fish are needed: one is given away now, one must survive for the turn-in. Requiring both
	-- prevents a player from feeding their turn-in fish and stranding their own cycle.
	if player:getItemCount(Zzuppliezz.ITEM_CORNED_FISH) < Zzuppliezz.FISH_REQUIRED then
		player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "You need two salted fish: one for the prisoners, one to bring back.")
		return true
	end

	if not player:removeItem(Zzuppliezz.ITEM_CORNED_FISH, 1) then
		player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "You need two salted fish: one for the prisoners, one to bring back.")
		return true
	end

	Zzuppliezz.markPrisonersFed(player)
	player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "You push a salted fish through the bars. Thin hands take it without a sound.")

	if not player:hasAchievement("Vive la Resistance") then
		player:addAchievement("Vive la Resistance")
	end

	return true
end

prisoners:uid(PRISONER_FENCE_UID)
prisoners:register()
