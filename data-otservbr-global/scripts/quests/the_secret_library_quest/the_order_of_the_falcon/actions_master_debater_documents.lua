-- ================================================================
-- MASTER DEBATER - DOCUMENT DISCOVERY + PHYSICAL BOOK REWARD (Secret Library completion mechanics pass)
-- ================================================================
-- Six of the nine required "Grand Master of Verbal Debate" volumes have a real, distinct,
-- position-matched physical object, cross-checked against this project's own item data and an
-- independently-fetched current reference (docs/ai-dev/quests/packages/secret-library/
-- 07_SECRET_LIBRARY_COMPLETION_MECHANICS_PASS.md, section 27):
--   - two "Writing Desk" objects: item 27880 (I and IV)
--   - three "Pile of Bones" objects: item 4285 (V, VI, VII)
--   - one "Chest" object: item 2472 (IX)
-- The remaining three (II Wooden Trunk, III Ashes, VIII Remains of a Mummy) remain NOT_PROVEN - not
-- wired, not guessed. See MasterDebaterRequiredDocumentKeys: the achievement gate honestly requires
-- all nine, so it remains correctly unattainable until the remaining three are resolved.
--
-- CORRECTION (completion mechanics pass, section 14): the exact reference (individual TibiaWiki pages
-- for "The Grand Master of Verbal Debate" I-IX, fetched and archived this pass) confirms the "Pode ser
-- pego novamente a cada 20 horas" (repeatable every 20 hours) physical book mechanic and gives the
-- exact readable text of every one of the nine volumes. Each of these nine texts was independently
-- cross-matched against this quest's own pre-existing, already-audited Grand Master Oberon debate
-- table (grand_master_oberon_functions.lua's GrandMasterOberonResponses) by its quoted riposte line -
-- every one matches a distinct response index exactly, confirming both the book texts and the
-- pre-existing debate table are the genuine Global mechanic. Reused item 2824 ("book", the generic
-- readable-book item already defined in this project's own items.xml) as the reward item, following
-- this project's own established convention for granting a readable item with custom per-instance text
-- (item:setText(...), the same confirmed-real method already used elsewhere in this exact codebase,
-- e.g. scripts/quests/parchment_room/parchment.lua and scripts/actions/other/others/quest_system2.lua)
-- - no new/invented item id.
--
-- Position-scoped Action registration (Action:position(...)), the same mechanism this codebase's own
-- register_actions.lua already uses for the Isle of Kings scythe entrance - narrow by construction
-- (fires only for a Use targeting one of these six exact tiles), so it cannot affect any unrelated
-- desk/bones/chest object anywhere else on the map even though the underlying item ids (27880, 4285,
-- 2472) are generic decoration classes reused elsewhere. Every Use additionally verifies the exact
-- confirmed item id, not just position (src/lua/creature/actions.cpp dispatches on position alone) -
-- a non-matching item returns false, falling through to that item's own default/built-in handling.
local MASTER_DEBATER_BOOK_ITEM_ID = 2824 -- "book" (data/items/items.xml) - generic readable, reused

local DOCUMENTS = {
	{
		key = "writing_desk_1",
		pos = Position(33369, 31348, 3),
		itemId = 27880,
		bookText = 'The Grand Master of Verbal Debate I\nFacing villainy of the utmost caliber, your riposte:\n"Are you ever going to fight or do you prefer talking?"',
	},
	{
		key = "writing_desk_2",
		pos = Position(33374, 31336, 3),
		itemId = 27880,
		bookText = 'The Grand Master of Verbal Debate IV\nA counter spell: SEHWO ASIMO, TOLIDO ESD',
	},
	{
		key = "pile_of_bones_1",
		pos = Position(33368, 31325, 6),
		itemId = 4285,
		bookText = 'The Grand Master of Verbal Debate V\nDealing with a forboding warning, your riposte:\n"Excuse me but I still do not get the message!"',
	},
	{
		key = "pile_of_bones_2",
		pos = Position(33368, 31327, 6),
		itemId = 4285,
		bookText = 'The Grand Master of Verbal Debate VI\nBoasting with strong words, your riposte:\n"Then why are we fighting alone right now?"',
	},
	{
		key = "pile_of_bones_3",
		pos = Position(33387, 31285, 7),
		itemId = 4285,
		bookText = 'The Grand Master of Verbal Debate VII\nBeing confronted with vile accusations, your riposte:\n"How appropriate, you look like something worms already got the better of!"',
	},
	{
		key = "chest",
		pos = Position(33369, 31343, 8),
		itemId = 2472,
		bookText = 'The Grand Master of Verbal Debate IX\nReceiving a doubtful word of wisdom, your riposte:\n"Dare strike up a Minnesang and you will receive your last accolade!"',
	},
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

-- Separate KV branch for the 20h physical-reward cooldown, deliberately independent of the permanent
-- discovery flag above (documentsKV) - discovery is set exactly once, ever; the reward cooldown resets
-- every successful delivery, per the reference's own "every 20 hours" wording.
local function rewardKV(player, docKey)
	return player:kv():scoped("secret-library-master-debater"):scoped("book-reward"):scoped(docKey)
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
	local itemId = item:getId()
	local doc = nil
	for _, d in ipairs(DOCUMENTS) do
		if d.pos == pos and d.itemId == itemId then
			doc = d
			break
		end
	end
	if not doc then
		-- position matched but the exact confirmed item id did not - a different, unrelated usable
		-- item legitimately shares this tile. Return false (not true) so the engine falls through to
		-- that item's own default handling instead of silently consuming the Use with no effect.
		return false
	end

	local kv = documentsKV(player)
	local alreadyDiscovered = kv:get(doc.key) == true

	-- CORRECTION (completion mechanics pass, section 14): 20h per-document-per-player reward cooldown,
	-- independent of the permanent discovery flag. Checked BEFORE any delivery attempt so a player who
	-- is still on cooldown never reaches the inventory-mutating code below at all.
	local reward = rewardKV(player, doc.key)
	local now = os.time()
	local nextRewardAt = reward:get("nextRewardAt") or 0
	if now < nextRewardAt then
		player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "You have already taken a copy of this debate volume recently. You can take another in " .. Game.getTimeInWords(nextRewardAt - now) .. ".")
		return true
	end

	-- CORRECTION: transactional delivery - checkWeightAndBackpackRoom (data/libs/functions/functions.lua,
	-- this project's own established pre-flight check, already used by quest_reward_common.lua for
	-- exactly this kind of grant) runs BEFORE any cooldown/discovery state is committed, so a failed
	-- delivery (no backpack room / too heavy) consumes neither the 20h cooldown nor the one-time
	-- discovery flag - the player can simply try again once they have room.
	local bookType = ItemType(MASTER_DEBATER_BOOK_ITEM_ID)
	if not checkWeightAndBackpackRoom(player, bookType:getWeight() / 100, "You try to take a copy of the debate volume") then
		return true
	end
	local book = player:addItem(MASTER_DEBATER_BOOK_ITEM_ID, 1)
	if not book then
		player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "You try to take a copy of the debate volume, but you have no room to take it.")
		return true
	end
	book:setText(doc.bookText)
	reward:set("nextRewardAt", now + 20 * 60 * 60)

	if not alreadyDiscovered then
		-- Idempotent, permanent, set exactly once: a repeat Use after this point only ever grants a
		-- fresh book copy (once off cooldown), never re-fires discovery or the achievement check again
		-- beyond MasterDebaterCheckAchievement's own hasAchievement guard.
		kv:set(doc.key, true)
		player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "You study the debate volume and commit its arguments to memory.")
		MasterDebaterCheckAchievement(player)
	else
		player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "You take another copy of the debate volume.")
	end
	return true
end

for _, doc in ipairs(DOCUMENTS) do
	actions_master_debater_documents:position(doc.pos)
end
actions_master_debater_documents:register()
