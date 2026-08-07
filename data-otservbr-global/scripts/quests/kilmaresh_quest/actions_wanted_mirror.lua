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

	if not player:addItem(36875, 1, false) then
		player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "You cannot carry the golden hand mirror right now.")
		return true
	end

	player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "Among the ruins, you find a precious golden hand mirror.")

	return true
end

mirrorSpot:uid(57561)
mirrorSpot:register()

-- Source: "blacken it over a fire and cover it in soot."
--
-- Using the mirror ON a real fire object is now the faithful path: campfires (items.xml 1996-2003) and
-- fire fields (2118, 2119) are accepted, all verified present in data/items/items.xml rather than
-- guessed. Self-use is deliberately RETAINED as a fallback rather than made an error, because no fire
-- object is proven to exist near the Ruins of Nuur or Issavi in this repository - requiring one would
-- risk soft-locking "Wanted" on a step that is pure flavour, and Wanted.MirrorSoot gates the Suon
-- shrine ritual, so it is required progression that must never become unreachable. If the map is later
-- given a fire near the ruins, the faithful path is already implemented and no code change is needed.
local FIRE_SOURCE_IDS = {
	[1996] = true,
	[1997] = true,
	[1998] = true,
	[1999] = true,
	[2000] = true,
	[2002] = true,
	[2003] = true,
	[2118] = true,
	[2119] = true,
}

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

	-- Target may be absent (self-use), an Item userdata, a Creature, or - when the client sends no
	-- target at all - a plain metatable-less table (Lua::pushThing, lua_functions_loader.cpp:190-213).
	-- Only a genuine Item is inspected, and Item is registered with no base class, so calling
	-- isMonster()/getId() on the wrong kind of userdata would crash. Hence the explicit shape check.
	local usedOnFire = false
	if target and type(target) == "userdata" and target.isItem and target:isItem() then
		usedOnFire = FIRE_SOURCE_IDS[target.itemid] == true
	end

	player:setStorageValue(Storage.Quest.U12_20.KilmareshQuest.Wanted.MirrorSoot, 1)
	if usedOnFire then
		player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "You hold the golden hand mirror over the open flame until it is thoroughly blackened with soot.")
	else
		player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "You blacken the golden hand mirror with soot until its surface is entirely dulled.")
	end
	player:getPosition():sendMagicEffect(CONST_ME_SMOKE)

	return true
end

mirrorSoot:id(36875)
mirrorSoot:register()
