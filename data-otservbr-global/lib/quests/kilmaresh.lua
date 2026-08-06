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
