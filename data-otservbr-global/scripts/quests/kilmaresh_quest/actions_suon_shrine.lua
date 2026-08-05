-- "Wanted" (added 12.70) - did not exist before this pass. Source: "in front of the Benevolent
-- King's statue, you have to scratch the soot off the mirror whilst wearing the ivory mask" - use the
-- knife on the sooted golden hand mirror while carrying the Ivory Mask (item 31371, obtained during
-- Fafnar's Wrath - 1-fafnars-wrath/7-four-masks.lua / scripts/actions/other/gems.lua), at the shrine.
-- Real shrine object uid unknown this pass; registered against a placeholder, flagged
-- CODE_READY_MAP_REQUIRED in the PR's Map Setup Contract. Source explicitly states Petaris is the
-- innocent suspect - this is a fixed reveal, not randomised.
-- CONFIRMED BUG (found via the Global datapack runtime smoke log, which the Repository Audit does NOT
-- catch): this was registered as `suonShrine:id(3291)` - the ordinary knife. That collides with
-- scripts/actions/other/destroy.lua, which registers the whole range 3264-3292 (see its `for id =
-- 3264, 3292` loop), producing a new
--   [warning] [registerLuaItemEvent] - Duplicate registered item with id: 3291 ... for script: destroy.lua
-- on server start. The runtime smoke runs with --fail-on-warnings, so this was a failure genuinely
-- introduced by this PR. Registering on the shrine object's own unique id instead removes the
-- collision entirely and matches the uid-based pattern used by this quest's other position-bound
-- actions. The knife is still required - it is now checked as a carried item rather than being the
-- registered trigger, so the source's "scratch the soot off with a knife" requirement is preserved.
local suonShrine = Action()

function suonShrine.onUse(player, item, fromPosition, target, toPosition, isHotkey)
	if player:getStorageValue(Storage.Quest.U12_20.KilmareshQuest.Wanted.Questline) ~= 1 then
		return false
	end

	if not player:getItemById(3291, 1) then
		player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "You need a knife to scratch the soot from the mirror.")
		return true
	end

	if player:getStorageValue(Storage.Quest.U12_20.KilmareshQuest.Wanted.MirrorSoot) < 1 or not player:getItemById(36875, 1) then
		player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "You need the soot-blackened golden hand mirror for this ritual.")
		return true
	end

	if not player:getItemById(31371, 1) then
		player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "You need to be wearing the ivory mask for this ritual.")
		return true
	end

	if player:getStorageValue(Storage.Quest.U12_20.KilmareshQuest.Wanted.InnocentRevealed) >= 1 then
		player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "The face of Petaris already appeared in the mirror. You know what you need to know.")
		return true
	end

	player:say("Suon, Benevolent Sun, grant me a glimpse of the past.", TALKTYPE_MONSTER_SAY)
	player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "You scratch the soot from the mirror. The face of Petaris appears in the glass, and the wind whispers a name into your ear: innocent.")
	player:setStorageValue(Storage.Quest.U12_20.KilmareshQuest.Wanted.InnocentRevealed, 1)
	player:getPosition():sendMagicEffect(CONST_ME_MAGIC_BLUE)

	return true
end

suonShrine:uid(57562) -- the Suon shrine / Benevolent King's statue object
suonShrine:register()
