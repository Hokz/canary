-- "Aspiring Oracle" (added 12.70) - Taya did not exist in this repo at all before this pass. Built
-- from the owner-provided package transcript, which is given as exact English dialogue.
local internalNpcName = "Taya"
local npcType = Game.createNpcType(internalNpcName)
local npcConfig = {}

npcConfig.name = internalNpcName
npcConfig.description = internalNpcName

npcConfig.health = 100
npcConfig.maxHealth = npcConfig.health
npcConfig.walkInterval = 2000
npcConfig.walkRadius = 2

npcConfig.outfit = {
	lookType = 1199,
	lookHead = 78,
	lookBody = 39,
	lookLegs = 39,
	lookFeet = 76,
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

local function greetCallback(npc, creature)
	local player = Player(creature)
	local playerId = player:getId()

	if player:getStorageValue(Storage.Quest.U12_20.KilmareshQuest.AspiringOracle.Questline) >= 6 then
		npcHandler:setMessage(MESSAGE_GREET, "A gryphon rider! What a rare honour!")
	elseif player:getStorageValue(Storage.Quest.U12_20.KilmareshQuest.AspiringOracle.Questline) == 5 then
		npcHandler:setMessage(MESSAGE_GREET, "A gryphon rider! What a rare honour!")
		npcHandler:setTopic(playerId, 10)
	else
		npcHandler:setMessage(MESSAGE_GREET, "A gryphon rider! What a rare honour!")
	end

	return true
end

local function creatureSayCallback(npc, creature, type, message)
	local player = Player(creature)
	local playerId = player:getId()

	if not npcHandler:checkInteraction(npc, creature) then
		return false
	end

	if MsgContains(message, "oracle") and player:getStorageValue(Storage.Quest.U12_20.KilmareshQuest.AspiringOracle.Questline) < 1 then
		npcHandler:say({
			"Have you ever heard of the Circle of the Midnight Flame? They are an order of seers and prophets. Since I was a little girl it was my greatest dream to join them. ...",
			"Sadly, I was not born with the gift of true seeing. But I firmly believe there is a way. I heard stories about an artefact that can grant the power of seeing. ...",
			"But I have no idea how to get this artefact. I really want to be an oracle and join the Midnight Flame. Would you help me?",
		}, npc, creature)
		npcHandler:setTopic(playerId, 1)
	elseif MsgContains(message, "yes") and npcHandler:getTopic(playerId) == 1 then
		npcHandler:say("Suon be praised. Ask Narsai in Issavi about it. I guess she knows more.", npc, creature)
		player:setStorageValue(Storage.Quest.U12_20.KilmareshQuest.AspiringOracle.Questline, 1)
		npcHandler:setTopic(playerId, 0)
	elseif npcHandler:getTopic(playerId) == 10 and player:getStorageValue(Storage.Quest.U12_20.KilmareshQuest.AspiringOracle.Questline) == 5 then
		npcHandler:say("You offered a sacrifice for the holy seer sphinxes and lamassu! The Eye of Suon is now blessed and I can be an oracle. ... And, wait ... I already see a danger. Enusat the Onyx Wing! He is a black Manticore who threatens the people living in the small steppe villages. ...", npc, creature)
		npcHandler:say("Please, find and kill him to protect those people. He might be high up in the mountains but could also dwell in one of the old tombs underneath the steppe.", npc, creature)
		player:setStorageValue(Storage.Quest.U12_20.KilmareshQuest.AspiringOracle.Questline, 6)
		npcHandler:setTopic(playerId, 0)
	elseif MsgContains(message, "report") and player:getStorageValue(Storage.Quest.U12_20.KilmareshQuest.AspiringOracle.Questline) == 6 and player:getStorageValue(Storage.Quest.U12_20.KilmareshQuest.AspiringOracle.EnusatKilled) < 1 then
		npcHandler:say("Please, find and kill him to protect those people. He might be high up in the mountains but could also dwell in one of the old tombs underneath the steppe.", npc, creature)
		npcHandler:setTopic(playerId, 0)
	elseif MsgContains(message, "report") and player:getStorageValue(Storage.Quest.U12_20.KilmareshQuest.AspiringOracle.Questline) == 6 and player:getStorageValue(Storage.Quest.U12_20.KilmareshQuest.AspiringOracle.EnusatKilled) >= 1 then
		npcHandler:say("You killed the Onyx Wing! Well done, you saved the lives of many villagers out there! Please take this mosaic as a sign of my gratitude.", npc, creature)
		player:addItem(30669, 1) -- sun mosaic
		player:setStorageValue(Storage.Quest.U12_20.KilmareshQuest.AspiringOracle.Questline, 7)
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
