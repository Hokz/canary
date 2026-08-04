local internalNpcName = "Dulcineo"
local npcType = Game.createNpcType(internalNpcName)
local npcConfig = {}

npcConfig.name = internalNpcName
npcConfig.description = internalNpcName

npcConfig.health = 100
npcConfig.maxHealth = npcConfig.health
npcConfig.walkInterval = 2000
npcConfig.walkRadius = 2

npcConfig.outfit = {
	lookType = 267,
	lookHead = 20,
	lookBody = 20,
	lookLegs = 20,
	lookFeet = 20,
	lookAddons = 3,
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

local ThreatenedDreams = Storage.Quest.U11_40.ThreatenedDreams

-- CUSTOM_GLOBAL_LIKE_PENDING_EXACT_REFERENCE: no exact transcript was provided for this NPC.
local function greetCallback(npc, creature)
	local player = Player(creature)
	if player:getStorageValue(ThreatenedDreams.Mission06.LipstickUsed) < 1 then
		npcHandler:setMessage(MESSAGE_GREET, "*He waves happily and mimes eating candy, then frowns and points between two directions, as if torn.*")
	else
		npcHandler:setMessage(MESSAGE_GREET, "Oh, hello there! Welcome, welcome!")
	end
	return true
end

local function creatureSayCallback(npc, creature, type, message)
	local player = Player(creature)
	local playerId = player:getId()

	if not npcHandler:checkInteraction(npc, creature) then
		return false
	end

	if player:getStorageValue(ThreatenedDreams.Mission06.LipstickUsed) < 1 then
		return true
	end

	local m6 = player:getStorageValue(ThreatenedDreams.Mission06[1])
	if MsgContains(message, "mission") then
		if m6 == 16 then
			npcHandler:say({
				"I'm so happy the Candy Carnival is open again! But... there's a shadow over my joy. My dear friend Sugar Plum Fairy and her sister, the Tooth Fairy, have been feuding for ages now over all this candy. ...",
				"They haven't spoken properly in so long. Would you go speak with the Tooth Fairy? Maybe you can help patch things up between them.",
			}, npc, creature)
			player:setStorageValue(ThreatenedDreams.Mission06[1], 17)
		elseif m6 == 17 then
			npcHandler:say("Have you spoken to the Tooth Fairy yet? I do hope she'll hear us out.", npc, creature)
		elseif m6 == 18 then
			npcHandler:say({
				"You brought the toothbrushes to the children and made peace with the Tooth Fairy? That's wonderful news! Perhaps this silly feud can finally end. Thank you, truly, for everything you've done for Candia.",
			}, npc, creature)
			player:setStorageValue(ThreatenedDreams.Mission06[1], 19)
		else
			npcHandler:say("Thank you again for helping patch things up, friend!", npc, creature)
		end
	end
	return true
end

npcHandler:setCallback(CALLBACK_GREET, greetCallback)
npcHandler:setCallback(CALLBACK_MESSAGE_DEFAULT, creatureSayCallback)
npcHandler:addModule(FocusModule:new(), npcConfig.name, true, true, true)

-- npcType registering the npcConfig table
npcType:register(npcConfig)
