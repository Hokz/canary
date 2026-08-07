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
-- actions.
--
-- REAL BEHAVIOUR (stated plainly rather than overclaimed): the player uses the SHRINE, and the knife,
-- sooted mirror and ivory mask are verified as carried items. This is not literally "use the knife on
-- the mirror while wearing the mask" - the knife is not the dispatch trigger (registering it caused
-- the item-3291 range collision with destroy.lua), and the mask cannot be equipped at all (no slot
-- attribute in items.xml). Classified PDF_VISUAL_DETAIL_PENDING_OWNER_VALIDATION.
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

	-- ACCURACY NOTE (review): the source says the mask must be *worn*. That cannot be enforced here:
	-- the ivory mask (item 31371, data/items/items.xml:58328) carries no slot/slotType attribute at
	-- all, so the engine cannot equip it and `player:getSlotItem(CONST_SLOT_HEAD)` could never match
	-- it. Possession is therefore the strongest check available without adding a slot to a shared
	-- item, which would be an items.xml change well outside this quest's scope.
	-- Classified PDF_VISUAL_DETAIL_PENDING_OWNER_VALIDATION - see the PR body.
	if not player:getItemById(31371, 1) then
		player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "You need the ivory mask with you for this ritual.")
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
