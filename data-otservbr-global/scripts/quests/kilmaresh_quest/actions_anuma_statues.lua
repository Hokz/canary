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

local anumaStatues = Action()

function anumaStatues.onUse(player, item, fromPosition, target, toPosition, isHotkey)
	local statue = statues[target and target.uid]
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
	-- without ever checking the wine was actually present. Checking possession first (rather than
	-- trusting removeItem's return value, which this repo's convention doesn't rely on for these
	-- storage-gated one-time actions - see e.g. actions_eye_of_suon.lua's combine action) guarantees
	-- no wine means no progress.
	if not player:getItemById(2, 1) then
		player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "You need a bottle of wine to make a sacrifice.")
		return true
	end

	player:removeItem(2, 1) -- wine
	player:setStorageValue(Storage.Quest.U12_20.KilmareshQuest.AspiringOracle.AnumaBlessed, blessed + statue.bit)
	player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "You pour the wine in front of the statue of " .. statue.name .. " as a sacrifice.")
	player:getPosition():sendMagicEffect(CONST_ME_MAGIC_BLUE)

	return true
end

anumaStatues:id(2) -- wine
anumaStatues:register()
