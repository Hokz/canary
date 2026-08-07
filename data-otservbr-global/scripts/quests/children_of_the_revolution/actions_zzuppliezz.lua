-- "Zzuppliezz" - the three world interactions of Zalamon's repeatable supply task.
-- Task state and the transactional turn-in live in lib/quests/zzuppliezz.lua; see npc/zalamon.lua for
-- the dialogue. Provenance of each design detail is documented in the lib file - the owner WOTE
-- reference names this task but specifies none of the mechanics below.
--
-- MAP_REQUIRED: neither the weapons crate (10247) nor the corned fish (10218) is placed anywhere in
-- the runtime map - verified by scanning the exact configured artifact (otservbr.otbm v3.6.1,
-- sha256 a80de1dd...), which returned zero placements for both ids. No startup table wires these
-- interactions either, so BOTH possible sources were checked. The three triggers below use reserved
-- unique ids (57570-57572, verified free repo-wide AND inside the OTBM) and the physical objects must
-- still be given those uids. No coordinates were guessed.
--
-- Each world source grants its items ONCE PER RUN. Without that, a player could bank fish elsewhere and
-- keep re-triggering the supply store to farm quest items indefinitely.
local WEAPONS_RACK_UID = 57570
local SUPPLY_STORE_UID = 57571
local PRISONER_FENCE_UID = 57572

-- Weapons rack -> one weapons crate, once per run.
local rack = Action()

function rack.onUse(player, item, fromPosition, target, toPosition, isHotkey)
	if not Zzuppliezz.isActive(player) then
		player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "A rack of lizard weapons. You have no reason to take any.")
		return true
	end

	if Zzuppliezz.hasTakenCrate(player) then
		player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "You already took a crate for this run.")
		return true
	end

	-- canDropOnMap = false: the crate is needed for the turn-in, so a truthy result must prove it
	-- reached the inventory. The run flag is set only after delivery is confirmed, so a refused
	-- attempt can simply be retried once the player makes room.
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

-- Supply store -> the run's fish, once per run.
local supplies = Action()

function supplies.onUse(player, item, fromPosition, target, toPosition, isHotkey)
	if not Zzuppliezz.isActive(player) then
		player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "Salted provisions, stacked for the emperor's soldiers.")
		return true
	end

	if Zzuppliezz.hasTakenFish(player) then
		player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "You already took fish for this run.")
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

supplies:uid(SUPPLY_STORE_UID)
supplies:register()

-- Prisoner fence -> feed one corned fish. This is the step the task exists for, so completing the run
-- requires proof it happened (Zzuppliezz.KEY_PRISONERS_FED), not merely that items are carried.
-- First successful feeding grants "Vive la Resistance", whose registered description
-- ("Supplying prisoners, caring for outcasts...") matches this act.
local prisoners = Action()

function prisoners.onUse(player, item, fromPosition, target, toPosition, isHotkey)
	if not Zzuppliezz.isActive(player) then
		player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "Hollow-eyed prisoners watch you from behind the fence.")
		return true
	end

	if Zzuppliezz.hasFedPrisoners(player) then
		player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "You already fed the prisoners on this run.")
		return true
	end

	-- Two fish are needed here: one is given away now, one must survive for Zalamon. Requiring both
	-- prevents a player from feeding their turn-in fish and stranding their own run.
	if player:getItemCount(Zzuppliezz.ITEM_CORNED_FISH) < Zzuppliezz.FISH_REQUIRED then
		player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "You need two salted fish: one for the prisoners, one to bring back.")
		return true
	end

	if not player:removeItem(Zzuppliezz.ITEM_CORNED_FISH, 1) then
		player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "You need two salted fish: one for the prisoners, one to bring back.")
		return true
	end

	Zzuppliezz.markPrisonersFed(player)
	player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "You push a salted fish through the fence. Thin hands take it without a sound.")

	if not player:hasAchievement("Vive la Resistance") then
		player:addAchievement("Vive la Resistance")
	end

	return true
end

prisoners:uid(PRISONER_FENCE_UID)
prisoners:register()
