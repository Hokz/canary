local internalNpcName = "Cerebrir"
local npcType = Game.createNpcType(internalNpcName)
local npcConfig = {}

npcConfig.name = internalNpcName
npcConfig.description = internalNpcName

npcConfig.health = 100
npcConfig.maxHealth = npcConfig.health
npcConfig.walkInterval = 0
npcConfig.walkRadius = 2

npcConfig.outfit = {
	lookType = 1067,
}

npcConfig.flags = {
	floorchange = false,
	profession = "normal",
}
npcConfig.speechBubble = SPEECHBUBBLE_NORMAL

local keywordHandler = KeywordHandler:new()
local npcHandler = NpcHandler:new(keywordHandler)

npcType.onThink = function(npc, interval)
	npcHandler:onThink(npc, interval)
end

npcType.onAppear = function(npc, creature)
	npcHandler:onAppear(npc, creature)
end

npcType.onDisappear = function(npc, creature)
	npcHandler:onDisappear(npc, creature)
end

npcType.onMove = function(npc, creature, fromPosition, toPosition)
	npcHandler:onMove(npc, creature, fromPosition, toPosition)
end

npcType.onSay = function(npc, creature, type, message)
	npcHandler:onSay(npc, creature, type, message)
end

npcType.onCloseChannel = function(npc, creature)
	npcHandler:onCloseChannel(npc, creature)
end

-- ================================================================
-- POST-SCOURGE-OF-OBLIVION EPILOGUE (Secret Library final functional closure pass, P0 section 1)
-- ================================================================
-- PROVEN_REFERENCE full dialogue transcript (TibiaWiki main quest page, fetched this pass) - a linear
-- keyword-advance conversation. State is entirely per-player: npcHandler:getTopic(playerId) for the
-- in-conversation position, and player:kv():scoped("secret-library-cerebrir") (DB-backed, matching this
-- quest's own established documentsKV/rewardKV convention in
-- actions_master_debater_documents.lua) for the two persistent flags:
--   epiloguePending  - set on legitimate current-run Scourge-of-Oblivion kill credit
--                      (creaturescripts_scourge_of_oblivion_phases.lua), survives logout/relog because
--                      the KV store is DB-backed, not a runtime table.
--   epilogueComplete - set once this conversation reaches its end; gates the whole tree closed
--                      afterward (idempotent - re-greeting after completion neither re-grants anything
--                      nor advances any storage a second time).
-- A player who never received epiloguePending (never fought, or was not physically present at the
-- legitimate kill) gets only a neutral greeting and topic stays 0 - no keyword branch below can ever
-- fire for them, so a non-participant cannot talk their way into completion. Topic and KV are both keyed
-- per player, so one player's own conversation can never advance or complete a teammate's state. Library
-- Liberator (achievement, granted on the kill itself) remains completely independent of this epilogue/
-- true-completion state machine, per the task's own explicit requirement.
local function cerebrirKV(player)
	return player:kv():scoped("secret-library-cerebrir")
end

local function greetCallback(npc, creature)
	local player = Player(creature)
	if not player then
		return true
	end
	local playerId = player:getId()
	if cerebrirKV(player):get("epilogueComplete") then
		npcHandler:setMessage(MESSAGE_GREET, "The battle was won but ultimately we lost. There is nothing more to add for now - prepare yourself, for more trials are yet to come.")
		npcHandler:setTopic(playerId, 0)
	elseif cerebrirKV(player):get("epiloguePending") then
		npcHandler:setMessage(MESSAGE_GREET, "The battle was won but ultimately we lost.")
		npcHandler:setTopic(playerId, 1)
	else
		npcHandler:setMessage(MESSAGE_GREET, "There is nothing for us to discuss right now.")
		npcHandler:setTopic(playerId, 0)
	end
	return true
end

local function creatureSayCallback(npc, creature, type, message)
	local player = Player(creature)
	local playerId = player:getId()

	if not npcHandler:checkInteraction(npc, creature) then
		return false
	end

	if not cerebrirKV(player):get("epiloguePending") or cerebrirKV(player):get("epilogueComplete") then
		return true
	end

	local topic = npcHandler:getTopic(playerId)

	if MsgContains(message, "lost") and topic == 1 then
		npcHandler:say("Their major attack was a feint! While we were fighting, someone secretly passed the wards and stole the knowledge of the godbreaker.", npc, creature)
		npcHandler:setTopic(playerId, 2)
	elseif MsgContains(message, "someone") and topic == 2 then
		npcHandler:say("It must have been the high-ranking traitor himself. Someone with intimate knowledge of the wards that were woven and the powers to pass them unnoticed.", npc, creature)
		npcHandler:setTopic(playerId, 3)
	elseif MsgContains(message, "unnoticed") and topic == 3 then
		npcHandler:say("Only someone who was present when the wards were created could have done this at all. This narrows the number of suspects significantly.", npc, creature)
		npcHandler:setTopic(playerId, 4)
	elseif MsgContains(message, "suspects") and topic == 4 then
		npcHandler:say({
			"Demons are prone to infighting and the wards are older than you could comprehend. So most of the participants are dead by now. ...",
			"Prince Drazzak was mindwiped, locked away and is probably dead by now anyway. This leaves only select few candidates.",
		}, npc, creature)
		npcHandler:setTopic(playerId, 5)
	elseif MsgContains(message, "candidates") and topic == 5 then
		npcHandler:say("The hints are there, beginning with the acquisition of the godbreaker parts by Variphors minions. Considering all evidence and information, the traitor is none other than... ...", npc, creature)
		npcHandler:setTopic(playerId, 6)
	elseif MsgContains(message, "seven") and topic == 6 then
		npcHandler:say("The minions used in this coup will be worthless as sources of information, but there are other clues and leads. Trust in the fact that Zathroth will not take this insult lightly. The master of forbidden knowledge and secrets will not tolerate this treachery and find out who is behind this betrayal.", npc, creature)
		npcHandler:setTopic(playerId, 7)
	elseif MsgContains(message, "betrayal") and topic == 7 then
		npcHandler:say({
			"The time of reckoning will come and one of the seven will fall. Zathroth's wrath will know no bounds and he will choose the executors to carry out his will. ...",
			"You have proven competent in fighting the forces from beyond and their traitorous allies. ...",
			"When the time comes, Zathroth will remember this and you might be called to serve him in his judgment. Until then, prepare yourself. ...",
			"The battles to come will be challenging and deadly. Hone your skills, improve your equipment and gather allies. You need all of those when the time comes. ...",
			"Now leave this place and spread the word that Zathroth goes to war. Tell the world that his wrath will crush anyone who dares to betray the gods to the powers from beyond!",
		}, npc, creature)
		cerebrirKV(player):set("epilogueComplete", true)
		cerebrirKV(player):set("epiloguePending", false)
		if player:getStorageValue(Storage.Quest.U11_80.TheSecretLibrary.Library.Questline) < 2 then
			player:setStorageValue(Storage.Quest.U11_80.TheSecretLibrary.Library.Questline, 2)
		end
		npcHandler:setTopic(playerId, 0)
	end

	return true
end

npcHandler:setMessage(MESSAGE_WALKAWAY, "Well, bye then.")

npcHandler:setCallback(CALLBACK_GREET, greetCallback)
npcHandler:setCallback(CALLBACK_MESSAGE_DEFAULT, creatureSayCallback)

npcHandler:addModule(FocusModule:new(), npcConfig.name, true, true, true)

-- npcType registering the npcConfig table
npcType:register(npcConfig)
