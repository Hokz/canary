-- ================================================================
-- MASTER DEBATER - DOCUMENT DISCOVERY (Secret Library corrective repair pass, section 3-4)
-- ================================================================
-- The previous pass's physical audit inspected the achievement-marker display coordinates as if each
-- one were the exact interactive Use-target tile, found only generic decoration there, and correctly
-- declined to implement anything rather than guess. A corrected audit (see this pass's own handoff,
-- docs/ai-dev/quests/packages/secret-library/03_SECRET_LIBRARY_CORRECTIVE_REPAIR_PASS.md) inspected
-- the actual documented container coordinates instead and, cross-checked against this project's own
-- item data (data/items/items.xml and data/items/appearances.dat), confirmed six of the nine required
-- "Grand Master of Verbal Debate" volumes have a real, distinct, position-matched physical object:
--   - two "Writing Desk" objects: item 27880, confirmed by the identical item id recurring at both
--     independently-labeled desk positions (and nowhere else nearby);
--   - three "Pile of Bones" objects: item 4285, confirmed via items.xml/appearances name resolution
--     ("pile of bones"), recurring at all three independently-labeled positions;
--   - one "Chest" object: item 2472, confirmed via items.xml/appearances name resolution ("chest").
-- The remaining three reference positions (Wooden Trunk, Ashes, Remains of a Mummy) were physically
-- inspected (including a wide surrounding-radius sweep) but no single object at or near them could be
-- confidently identified against this project's own item data - NOT wired here, left NOT_PROVEN, not
-- guessed. See MasterDebaterRequiredDocumentKeys below: the achievement gate still honestly requires
-- all nine, so it remains correctly unattainable until the remaining three are resolved in a future
-- map pass - this is a disclosed limitation, not a defect.
--
-- No exact "Grand Master of Verbal Debate" volume item id/reward could be proven from any source
-- available to this pass (the six confirmed positions' items have no item.xml override and no
-- resolvable appearances name beyond the generic prop class itself), so this implements DISCOVERY
-- tracking only (a persistent per-player flag) - no physical book reward is granted. Inventing a
-- reward item id here would be exactly the kind of fabrication this pass's instructions prohibit.
--
-- Position-scoped Action registration (Action:position(...)), the same mechanism this codebase's own
-- register_actions.lua already uses for the Isle of Kings scythe entrance - narrow by construction
-- (fires only for a Use targeting one of these six exact tiles), so it cannot affect any unrelated
-- desk/bones/chest object anywhere else on the map even though the underlying item ids (27880, 4285,
-- 2472) are generic decoration classes reused elsewhere.
local DOCUMENTS = {
	{ key = "writing_desk_1", pos = Position(33369, 31348, 3) },
	{ key = "writing_desk_2", pos = Position(33374, 31336, 3) },
	{ key = "pile_of_bones_1", pos = Position(33368, 31325, 6) },
	{ key = "pile_of_bones_2", pos = Position(33368, 31327, 6) },
	{ key = "pile_of_bones_3", pos = Position(33387, 31285, 7) },
	{ key = "chest", pos = Position(33369, 31343, 8) },
}

-- Global (not local): the full required set for the achievement gate, including the three currently
-- unresolved documents (Wooden Trunk, Ashes, Remains of a Mummy) - listed here so the gate honestly
-- requires all nine even though only six can currently be discovered. No storage/AID/UID/item id is
-- invented for the unresolved three; their keys simply can never be set by anything in this file, so
-- MasterDebaterCheckAchievement below can never pass until a future pass adds their own discovery
-- trigger once the physical objects are identified.
MasterDebaterRequiredDocumentKeys = {
	"writing_desk_1",
	"writing_desk_2",
	"pile_of_bones_1",
	"pile_of_bones_2",
	"pile_of_bones_3",
	"chest",
	"wooden_trunk", -- NOT_PROVEN this pass - no discovery trigger wired
	"ashes", -- NOT_PROVEN this pass
	"remains_of_a_mummy", -- NOT_PROVEN this pass
}

-- DB-backed per-player KV storage (survives relog/restart), matching this project's own established
-- convention for equally-granular per-player discovery state (see lib/quests/measuring_tibia.lua's
-- own header comment: "this repo's own achievement system... and quest tracker... already use exactly
-- this pattern") rather than allocating nine more flat numeric storages for a still-partial mechanic.
local function documentsKV(player)
	return player:kv():scoped("secret-library-master-debater"):scoped("documents")
end

-- Global: called both when a document is discovered (below) and when Grand Master Oberon is
-- legitimately defeated (creaturescripts_kill.lua), so the achievement grants correctly regardless of
-- which of the two conditions completes last (order-independent per section 4.3).
function MasterDebaterCheckAchievement(player)
	if player:hasAchievement("Master Debater") then
		return
	end
	local kv = documentsKV(player)
	for _, key in ipairs(MasterDebaterRequiredDocumentKeys) do
		if not kv:get(key) then
			return
		end
	end
	-- "grand master oberon" is registered as sequential stage 6 (creaturescripts_kill.lua) - only
	-- reachable by a player who legitimately killed all 5 prior Falcon bosses in order, then Oberon
	-- himself. This is the project's own existing "legitimate Oberon completion" signal; no new
	-- storage is introduced to track it a second time.
	if player:getStorageValue(Storage.Quest.U11_80.TheSecretLibrary.FalconBastion.KillingBosses) < 6 then
		return
	end
	player:addAchievement("Master Debater")
end

local actions_master_debater_documents = Action()

function actions_master_debater_documents.onUse(player, item, fromPosition, target, toPosition, isHotkey)
	local pos = item:getPosition()
	local doc = nil
	for _, d in ipairs(DOCUMENTS) do
		if d.pos == pos then
			doc = d
			break
		end
	end
	if not doc then
		return true
	end

	local kv = documentsKV(player)
	-- Idempotent: a repeat Use is a safe no-op past the first discovery - no duplicate progression,
	-- no duplicate achievement side effect (MasterDebaterCheckAchievement's own hasAchievement guard
	-- covers that regardless, but this also avoids redundant work/messages on every re-Use).
	if kv:get(doc.key) then
		player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "You have already studied this debate volume.")
		return true
	end

	kv:set(doc.key, true)
	player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "You study the debate volume and commit its arguments to memory.")
	MasterDebaterCheckAchievement(player)
	return true
end

for _, doc in ipairs(DOCUMENTS) do
	actions_master_debater_documents:position(doc.pos)
end
actions_master_debater_documents:register()
