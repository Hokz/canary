-- Final boss (Morgathla) access. The reference gives no name for this gnome, only that using the
-- large crystal below Gnomus teleports to a room with an NPC who assembles the mallet from 3
-- parts. CUSTOM_GLOBAL_LIKE_PENDING_EXACT_REFERENCE: name and full dialogue text are invented,
-- lore-consistent with Gnomus/Klom Stonecutter/Lardoc Bashsmite's established writing style; the
-- required player keywords (mallet/yes) match the reference exactly.
local internalNpcName = "Gimlet Forgehammer"
local npcType = Game.createNpcType(internalNpcName)
local npcConfig = {}

npcConfig.name = internalNpcName
npcConfig.description = internalNpcName

npcConfig.health = 100
npcConfig.maxHealth = npcConfig.health
npcConfig.walkInterval = 2000
npcConfig.walkRadius = 2

npcConfig.outfit = {
	lookType = 493,
	lookHead = 20,
	lookBody = 20,
	lookLegs = 20,
	lookFeet = 20,
	lookAddons = 0,
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

local MALLET_HEAD = 27524
local MALLET_HANDLE = 27525
local MALLET_POMMEL = 27526
local MALLET = 27523

local function creatureSayCallback(npc, creature, type, message)
	local player = Player(creature)
	local playerId = player:getId()

	if not npcHandler:checkInteraction(npc, creature) then
		return false
	end

	if MsgContains(message, "mallet") then
		if player:getStorageValue(Storage.Quest.U11_50.DangerousDepths.Morgathla.Defeated) >= 1 then
			npcHandler:say("You already carried a mallet down into the depths, friend. No need for another.", npc, creature)
		elseif player:getItemCount(MALLET_HEAD) < 1 or player:getItemCount(MALLET_HANDLE) < 1 or player:getItemCount(MALLET_POMMEL) < 1 then
			npcHandler:say("You'll need a mallet head, a mallet handle and a mallet pommel - one from each of the three area champions - before I can put this together for you.", npc, creature)
		else
			npcHandler:say("All three parts, at last! Shall I assemble them into a proper mallet for you?", npc, creature)
			npcHandler:setTopic(playerId, 1)
		end
	elseif MsgContains(message, "yes") and npcHandler:getTopic(playerId) == 1 then
		if player:getItemCount(MALLET_HEAD) < 1 or player:getItemCount(MALLET_HANDLE) < 1 or player:getItemCount(MALLET_POMMEL) < 1 then
			npcHandler:say("Wait, you don't have all three parts anymore!", npc, creature)
		else
			player:removeItem(MALLET_HEAD, 1)
			player:removeItem(MALLET_HANDLE, 1)
			player:removeItem(MALLET_POMMEL, 1)
			player:addItem(MALLET, 1)
			player:setStorageValue(Storage.Quest.U11_50.DangerousDepths.Morgathla.MalletGiven, 1)
			npcHandler:say("There you go, a proper mallet. Strike the gong with it when you're ready to face what waits below - but mind you, the mallet won't survive the blow.", npc, creature)
		end
		npcHandler:setTopic(playerId, 0)
	end
	return true
end

npcHandler:setMessage(MESSAGE_GREET, "Well met. If you've gathered the three {mallet} parts from the champions of the depths, I can put them together for you.")
npcHandler:setCallback(CALLBACK_MESSAGE_DEFAULT, creatureSayCallback)
npcHandler:addModule(FocusModule:new(), npcConfig.name, true, true, true)

-- npcType registering the npcConfig table
npcType:register(npcConfig)
