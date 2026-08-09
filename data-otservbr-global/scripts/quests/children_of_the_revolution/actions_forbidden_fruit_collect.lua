-- Physical collection sources for 3 of the 7 Forbidden Fruit samples. Task state and the
-- eat/report flow live in lib/quests/forbidden_fruit.lua; see actions_forbidden_fruit_eat.lua for
-- consumption and npc/chartan.lua for the dialogue.
--
-- Physical positions are startup-wired in startup/tables/item.lua (uids 57573-57575) - each is the
-- ONLY instance of its item id within a +/-5 tile radius of its externally-referenced plant marker
-- (re-scanned against the exact configured OTBM), not a guess among several nearby identical
-- decorations. No OTBM edit.
--
-- The remaining 4 samples (Screaming Cherry Tree, Wraithtongue, Rotten Witches' Cauldron Plant,
-- Witherstem) have no anchor meeting that bar yet and are intentionally NOT wired here - their
-- markers either contain a mismatched named object or several indistinguishable candidates within
-- the same radius. See the PR body for the full 7-position audit matrix. Collecting all 3 wired
-- samples is not sufficient to complete the task - ForbiddenFruit.hasCollectedAll still requires
-- all 7.
local SOURCES = {
	[57573] = 12234, -- Sprocketwhip -> Sprocketwhip Cone
	[57574] = 12230, -- Carnivortex -> Meaty Vortex
	[57575] = 12233, -- Toxic Tulip -> Toxic Tulip Seed
}

local collectPlant = Action()

function collectPlant.onUse(player, item, fromPosition, target, toPosition, isHotkey)
	local sampleId = SOURCES[item.uid]
	if not sampleId then
		return false
	end

	if not ForbiddenFruit.isActive(player) then
		player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "An unusual plant. You have no reason to pick from it right now.")
		return true
	end

	if ForbiddenFruit.hasCollected(player, sampleId) then
		player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "You already collected a sample from this plant this run.")
		return true
	end

	if not player:addItem(sampleId, 1, false) then
		player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "You have no room to carry the sample.")
		return true
	end

	ForbiddenFruit.markCollected(player, sampleId)
	player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "You carefully gather a sample from the plant.")
	return true
end

for uid in pairs(SOURCES) do
	collectPlant:uid(uid)
end
collectPlant:register()
