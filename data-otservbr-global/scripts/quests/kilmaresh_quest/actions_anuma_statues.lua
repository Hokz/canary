-- "Aspiring Oracle" (added 12.70) - the 7 Anuma statue sacrifices did not exist before this pass.
-- Source: "Take this wine and sacrifice it at each of the statues by pouring it out in front of
-- them." Modelled on the same one-time bitmask pattern already used for Fafnar's Wrath's 5 statues
-- (1-fafnars-wrath/8-blessing-the-statues.lua). All 7 real positions are unknown this pass (Kematef -
-- hanging gardens of Issavi 2 floors up; Nesertis - south gate; Yaeta - catacombs; Zabaya - east Nykri
-- delta; Anunit - west Nykri delta; Nasramet - east central Kilmaresh steppe; Rimush - ruins of Nuur)
-- - registered against placeholder uids, flagged CODE_READY_MAP_REQUIRED in the PR's Map Setup
-- Contract.
local statues = {
	[57554] = { name = "Kematef", bit = 1 },
	[57555] = { name = "Nesertis", bit = 2 },
	[57556] = { name = "Yaeta", bit = 4 },
	[57557] = { name = "Zabaya", bit = 8 },
	[57558] = { name = "Anunit", bit = 16 },
	[57559] = { name = "Nasramet", bit = 32 },
	[57560] = { name = "Rimush", bit = 64 },
}

-- CONFIRMED BLOCKER (found in review): this used to be registered as `anumaStatues:id(2) -- wine`,
-- with the wine used ON the statue. Item id 2 is not a carryable item at all - it is the LIQUID TYPE
-- "wine" from the fluid enumeration at the very top of data/items/items.xml ("<!-- Liquids -->",
-- water 1, wine 2, beer 3 ... ink 18). Nothing else in the entire repository grants item 2 or
-- registers an action on it. Wine is carried as a fluid CONTAINER holding the wine subtype - the
-- convention the repo itself uses elsewhere, e.g. hot_cuisine's recipe text "1 Vial of wine".
-- Narsai now hands out vials of wine (2874, subtype 2) and the sacrifice is triggered by USING THE
-- STATUE, with the wine verified in inventory.
--
-- The trigger deliberately did NOT move onto item 2874: that id already carries two Action
-- registrations (scripts/actions/other/fluids.lua and threatened_dreams/action_candia_misc.lua) and is
-- one of the four standing Repository Audit blocking findings. A third registration would add a brand
-- new "Duplicate registered item with id: 2874" line to the --fail-on-warnings runtime smoke. Using
-- the statues' own unique ids keeps this quest out of that collision entirely - the same reasoning
-- that moved the Suon shrine off the knife (item 3291) in an earlier pass.
local anumaStatues = Action()

function anumaStatues.onUse(player, item, fromPosition, target, toPosition, isHotkey)
	-- Registered by unique id, so `item` is the statue itself.
	local statue = statues[item and item.uid]
	if not statue then
		return false
	end

	if player:getStorageValue(Storage.Quest.U12_20.KilmareshQuest.AspiringOracle.Questline) ~= 3 then
		player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "Nothing happens.")
		return true
	end

	-- CONFIRMED BUG (found via review): reaching Questline == 3 requires having combined the Eye of
	-- Suon once (Narsai only advances to this stage after seeing item 36708), but nothing re-checked
	-- it was still held at the moment of each individual sacrifice - the source is explicit that the
	-- Eye of Suon itself must be worn while performing the ritual, not just combined once beforehand.
	-- A player who discarded, traded away, or otherwise lost it could still bless every statue.
	if not player:getItemById(36708, 1) then
		player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "You need the Eye of Suon for this ritual.")
		return true
	end

	local blessed = player:getStorageValue(Storage.Quest.U12_20.KilmareshQuest.AspiringOracle.AnumaBlessed)
	if blessed < 0 then
		blessed = 0
	end

	if testFlag(blessed, statue.bit) then
		player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "You already made a sacrifice at the statue of " .. statue.name .. ".")
		return true
	end

	-- CONFIRMED BUG (found via review): wine was removed and the statue bit set unconditionally,
	-- without ever checking the wine was actually present, so no wine still meant progress.
	--
	-- getItemCount IS subtype-aware (player_functions.cpp:1838-1839), so this counts only vials that
	-- actually hold wine - an empty vial, or one of the five ink vials Shimun's ritual needs, will not
	-- do. getItemById could not express this: its second argument is deepSearch, not a count.
	-- Transactional: the bit is set only after the wine is provably consumed, so a failed removal
	-- leaves the statue re-blessable rather than silently burning the sacrifice.
	if player:getItemCount(KilmareshQuest.FLUID_CONTAINER_VIAL, KilmareshQuest.WINE_FLUID) < 1 then
		player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "You need a vial of wine to make a sacrifice.")
		return true
	end

	if not player:removeItem(KilmareshQuest.FLUID_CONTAINER_VIAL, 1, KilmareshQuest.WINE_FLUID) then
		player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "You need a vial of wine to make a sacrifice.")
		return true
	end

	player:setStorageValue(Storage.Quest.U12_20.KilmareshQuest.AspiringOracle.AnumaBlessed, blessed + statue.bit)
	player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "You pour the wine in front of the statue of " .. statue.name .. " as a sacrifice.")
	player:getPosition():sendMagicEffect(CONST_ME_MAGIC_BLUE)

	return true
end

-- action:uid(uids) accepts a varargs list (action_functions.cpp:120-138), so all seven statues share
-- one registration. Keyed off the `statues` table above so the two can never drift apart.
for uid in pairs(statues) do
	anumaStatues:uid(uid)
end
anumaStatues:register()
