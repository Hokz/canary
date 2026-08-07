-- Kilmaresh Quest shared helpers.
--
-- Centralised so the two 12.70 side-missions (Aspiring Oracle via npc/taya.lua and Wanted via
-- npc/eshaya.lua) cannot drift apart in what they consider "the base quest is finished".
--
-- The source states the base Kilmaresh quest consists of Fafnar's Wrath plus the four missions it
-- unlocks, and that Aspiring Oracle and Wanted become available afterwards. The predicate therefore
-- requires all five, each read from that mission's own completion storage:
--
--   Fafnar's Wrath   Sixth.Favor >= 11              (npc/the_empress.lua, on handing over the Regalia part)
--   A Shark in Need  NinevShark.Questline >= 2      (npc/ninev.lua)
--   Midnight Rituals Eleven.Basin >= 2              (npc/kallimae.lua)
--   The Boards       Twelve.Boss >= 5               (npc/alyxo.lua)  [legacy: Fourteen.Remains >= 1]
--   Revenge of Ogres RevengeOfTheOgres.Questline >= 4 (npc/saideh.lua) [legacy: Fourteen.Remains >= 5]
--
-- Deliberately NOT required: owning the Gryphon mount. That was considered and rejected - no canonical
-- evidence supports it. The Regalia of Suon combine (npc/yonan.lua) is optional side content, nothing
-- in the repo gates any mission on the mount, and scripts/actions/mounts/mounts.lua has no Kilmaresh
-- awareness at all. The "Gryphon Rider" achievement text enumerates Kilmaresh activities, but an
-- achievement is a reward description, not a prerequisite.
--
-- Legacy compatibility: players from before this PR split Boards/Revenge apart tracked both through
-- Fourteen.Remains (1 = Boards rewarded, 2..5 = Revenge stages, 5 = Revenge reported), so those values
-- are accepted as equivalent evidence of completion.

KilmareshQuest = KilmareshQuest or {}

-- Wine is not item id 2. Ids 1-20 in data/items/items.xml are the LIQUID TYPE enumeration
-- ("<!-- Liquids -->": water 1, wine 2, beer 3 ... ink 18), not carryable items - nothing else in the
-- repository grants item 2. Wine is carried in a fluid container holding the wine subtype, which is
-- the convention the repo uses elsewhere (hot_cuisine's recipe text: "1 Vial of wine").
-- Shared here so npc/narsai.lua (which hands the wine out) and the Anuma statue sacrifices (which
-- consume it) can never disagree about what "wine" is.
KilmareshQuest.WINE_FLUID = 2
KilmareshQuest.FLUID_CONTAINER_VIAL = 2874

-- CONFIRMED BLOCKER (found in review): every ingredient turn-in in this quest checked quantities with
--   player:getItemById(itemId, count)
-- but that signature is `getItemById(itemId, deepSearch[, subType = -1])`
-- (src/lua/functions/creatures/player/player_functions.cpp:1891-1892). The second argument is a
-- BOOLEAN deep-search flag, not a count - so every one of those checks passed as soon as the player
-- held a SINGLE unit of the item.
--
-- The removal side then failed silently in the player's favour: Player::removeItemOfType
-- (src/creatures/players/player.cpp:5186) only calls internalRemoveItems once it has accumulated
-- `count >= amount`, and otherwise returns false having removed NOTHING. The callers ignored that
-- return value, so a player carrying one of each ingredient passed the gate, lost no items at all, and
-- still had their stage storage advanced - skipping the entire gathering mission at zero cost.
--
-- These two helpers do it properly: getItemCount is genuinely count-aware
-- (player_functions.cpp:1838-1839), and consumption is verified rather than assumed.

---Does the player hold every {id, count} pair in `list`?
---@param player Player
---@param list table  array of { id = number, count = number }
---@return boolean
function KilmareshQuest.hasIngredients(player, list)
	if not player or not list then
		return false
	end

	for _, entry in ipairs(list) do
		if player:getItemCount(entry.id) < entry.count then
			return false
		end
	end

	return true
end

---Remove every {id, count} pair in `list`, but only if ALL of them are present first.
---Returns false and consumes nothing when the player is short of any entry.
---@param player Player
---@param list table  array of { id = number, count = number }
---@return boolean
function KilmareshQuest.consumeIngredients(player, list)
	if not KilmareshQuest.hasIngredients(player, list) then
		return false
	end

	-- Counts were all verified immediately above and nothing here can add or drop items in between,
	-- so each removal is expected to succeed. The result is still checked so that a partial consume
	-- can never pass unnoticed.
	for _, entry in ipairs(list) do
		if not player:removeItem(entry.id, entry.count) then
			return false
		end
	end

	return true
end

---@param player Player
---@return boolean
function KilmareshQuest.isBaseQuestComplete(player)
	if not player then
		return false
	end

	local storage = Storage.Quest.U12_20.KilmareshQuest

	if player:getStorageValue(storage.Sixth.Favor) < 11 then
		return false
	end

	if player:getStorageValue(storage.NinevShark.Questline) < 2 then
		return false
	end

	if player:getStorageValue(storage.Eleven.Basin) < 2 then
		return false
	end

	local legacyBoardsAndRevenge = player:getStorageValue(storage.Fourteen.Remains)

	-- Boards: current marker, or the legacy "reward already claimed" value.
	if player:getStorageValue(storage.Twelve.Boss) < 5 and legacyBoardsAndRevenge < 1 then
		return false
	end

	-- Revenge: current marker, or the legacy "already reported" value.
	if player:getStorageValue(storage.RevengeOfTheOgres.Questline) < 4 and legacyBoardsAndRevenge < 5 then
		return false
	end

	return true
end

-- Midnight Rituals: has the pilgrimage already been started or finished?
--
-- Nine.Owl, Tem.Bleeds and Eleven.Basin are all one-way pilgrimage progress markers, so any of them
-- being set proves the pilgrimage is already under way.
---@param player Player
---@return boolean
function KilmareshQuest.hasPilgrimageStarted(player)
	if not player then
		return false
	end

	local storage = Storage.Quest.U12_20.KilmareshQuest

	return player:getStorageValue(storage.Nine.Owl) >= 1 or player:getStorageValue(storage.Tem.Bleeds) >= 1 or player:getStorageValue(storage.Eleven.Basin) >= 1
end

-- Midnight Rituals: idempotent "all four members helped -> pilgrimage unlocked" transition.
--
-- CONFIRMED BLOCKER (found in review): Kallimae used to write Set.Ritual = 4 and Nine.Owl = 1
-- unconditionally whenever all four Eighth.* equalled 3 - which stays true forever once the members
-- are done. A player who had already advanced the pilgrimage (Nine.Owl 2, Tem.Bleeds 1, Eleven.Basin
-- 1) or even finished it (Basin 2) could re-trigger the dialogue and have Nine.Owl forced back to 1,
-- restarting the omen chain. This centralises the transition so both the "mission" offer and the
-- "yes" confirmation share one predicate, and every write is monotonic.
---@param player Player
---@return boolean true if the transition was applied
function KilmareshQuest.startMidnightPilgrimage(player)
	if not player then
		return false
	end

	local storage = Storage.Quest.U12_20.KilmareshQuest

	if player:getStorageValue(storage.Eighth.Yonan) < 3 or player:getStorageValue(storage.Eighth.Narsai) < 3 or player:getStorageValue(storage.Eighth.Shimun) < 3 or player:getStorageValue(storage.Eighth.Tefrit) < 3 then
		return false
	end

	-- Already started or completed: never rewind any pilgrimage marker.
	if KilmareshQuest.hasPilgrimageStarted(player) then
		return false
	end

	-- Set.Ritual is monotonic - only ever raised to the completion marker, never lowered.
	if player:getStorageValue(storage.Set.Ritual) < 4 then
		player:setStorageValue(storage.Set.Ritual, 4)
	end

	if player:getStorageValue(storage.Nine.Owl) < 1 then
		player:setStorageValue(storage.Nine.Owl, 1)
	end

	return true
end

-- Midnight Rituals legacy repair.
--
-- The four member NPCs each require their own Eighth.* storage to equal 1 before they will offer
-- their subtask. Before this PR nothing ever wrote those storages, so players who accepted Midnight
-- Rituals under the old code are stuck: acceptance also advanced Sixth.Favor 11 -> 12, and Kallimae's
-- (now fixed) acceptance branch only fires at exactly 11, so they can never re-enter it and every
-- member stays mute forever.
--
-- This is idempotent and deliberately conservative:
--   * it only acts on players with concrete evidence that Midnight Rituals was already accepted;
--   * it never lowers or overwrites a member already at 2 (list given) or 3 (ingredients delivered);
--   * it does nothing once the mission is complete (Eleven.Basin >= 2), so a finished mission can
--     never restart;
--   * it grants no items at all, so no list, pick, wine, Regalia part, achievement or pilgrimage item
--     can be duplicated by running it.
---@param player Player
---@return boolean true if any storage was repaired
function KilmareshQuest.migrateMidnightRituals(player)
	if not player then
		return false
	end

	local storage = Storage.Quest.U12_20.KilmareshQuest

	-- Never touch a completed mission.
	if player:getStorageValue(storage.Eleven.Basin) >= 2 then
		return false
	end

	local members = {
		storage.Eighth.Yonan,
		storage.Eighth.Narsai,
		storage.Eighth.Shimun,
		storage.Eighth.Tefrit,
	}

	-- Evidence that the mission was genuinely accepted at some point.
	local accepted = player:getStorageValue(storage.Sixth.Favor) >= 12 or player:getStorageValue(storage.Set.Ritual) >= 1 or player:getStorageValue(storage.Nine.Owl) >= 1 or player:getStorageValue(storage.Tem.Bleeds) >= 1 or player:getStorageValue(storage.Eleven.Basin) >= 1

	if not accepted then
		for _, memberStorage in ipairs(members) do
			if player:getStorageValue(memberStorage) >= 1 then
				accepted = true
				break
			end
		end
	end

	if not accepted then
		return false
	end

	local repaired = false
	for _, memberStorage in ipairs(members) do
		if player:getStorageValue(memberStorage) < 1 then
			player:setStorageValue(memberStorage, 1)
			repaired = true
		end
	end

	return repaired
end
