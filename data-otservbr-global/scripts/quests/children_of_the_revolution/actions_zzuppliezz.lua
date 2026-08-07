-- "Zzuppliezz" - the three world interactions of Zalamon's repeatable supply task.
-- Task state and the transactional turn-in live in lib/quests/zzuppliezz.lua; this file is only the
-- physical half. See npc/zalamon.lua for the dialogue.
--
-- MAP_REQUIRED: neither the weapons crate (10247) nor the corned fish (10218) is placed anywhere in
-- the runtime map - verified by scanning the exact configured artifact
-- (otservbr.otbm v3.6.1, sha256 a80de1dd...), which returned zero placements for both ids. Nor does
-- any startup table wire these interactions. The three triggers below are therefore registered on
-- reserved unique ids (57570-57572, verified free both repo-wide and inside the OTBM itself) and the
-- physical objects still have to be given those uids before the task can be completed in-world.
--
-- No coordinates were guessed. The reference places all three inside the existing Children of the
-- Revolution lizard camp, but it supplies no x/y/z and no object item id, so nothing is asserted here.
local WEAPONS_RACK_UID = 57570
local SUPPLY_STORE_UID = 57571
local PRISONER_FENCE_UID = 57572

-- Weapons rack -> one weapons crate.
local rack = Action()

function rack.onUse(player, item, fromPosition, target, toPosition, isHotkey)
	if not Zzuppliezz.isActive(player) then
		player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "A rack of lizard weapons. You have no reason to take any.")
		return true
	end

	if player:getItemCount(Zzuppliezz.ITEM_WEAPONS_CRATE) >= 1 then
		player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "You already carry a crate of weapons.")
		return true
	end

	-- canDropOnMap = false: the crate is required for the turn-in, so a truthy result must prove it
	-- reached the inventory rather than the floor. Nothing is recorded unless delivery succeeded, so a
	-- refused attempt is simply retried once the player makes room.
	if not player:addItem(Zzuppliezz.ITEM_WEAPONS_CRATE, 1, false) then
		player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "You cannot carry the heavy crate right now.")
		return true
	end

	player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "You quietly lift a crate of weapons from the rack.")
	return true
end

rack:uid(WEAPONS_RACK_UID)
rack:register()

-- Supply store -> two corned fish.
local supplies = Action()

function supplies.onUse(player, item, fromPosition, target, toPosition, isHotkey)
	if not Zzuppliezz.isActive(player) then
		player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "Salted provisions, stacked for the emperor's soldiers.")
		return true
	end

	if player:getItemCount(Zzuppliezz.ITEM_CORNED_FISH) >= Zzuppliezz.FISH_REQUIRED then
		player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "You already took enough fish.")
		return true
	end

	local missing = Zzuppliezz.FISH_REQUIRED - math.max(player:getItemCount(Zzuppliezz.ITEM_CORNED_FISH), 0)
	if not player:addItem(Zzuppliezz.ITEM_CORNED_FISH, missing, false) then
		player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "You cannot carry the fish right now.")
		return true
	end

	player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "You take salted fish from the store.")
	return true
end

supplies:uid(SUPPLY_STORE_UID)
supplies:register()

-- Prisoner fence -> feed one corned fish. First successful feeding grants "Vive la Resistance", whose
-- registered description ("Supplying prisoners, caring for outcasts...") matches this exact act.
local prisoners = Action()

function prisoners.onUse(player, item, fromPosition, target, toPosition, isHotkey)
	if not Zzuppliezz.isActive(player) then
		player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "Hollow-eyed prisoners watch you from behind the fence.")
		return true
	end

	-- One fish feeds the prisoners, the other is returned to Zalamon, so refuse when only the
	-- turn-in fish remains - otherwise the player could feed it and strand their own turn-in.
	if player:getItemCount(Zzuppliezz.ITEM_CORNED_FISH) < Zzuppliezz.FISH_REQUIRED then
		player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "You need two salted fish: one for the prisoners, one to bring back.")
		return true
	end

	if not player:removeItem(Zzuppliezz.ITEM_CORNED_FISH, 1) then
		player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "You need two salted fish: one for the prisoners, one to bring back.")
		return true
	end

	player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "You push a salted fish through the fence. Thin hands take it without a sound.")

	if not player:hasAchievement("Vive la Resistance") then
		player:addAchievement("Vive la Resistance")
	end

	return true
end

prisoners:uid(PRISONER_FENCE_UID)
prisoners:register()
