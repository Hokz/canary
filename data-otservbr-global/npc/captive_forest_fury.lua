local internalNpcName = "A Captive Forest Fury"
local npcType = Game.createNpcType(internalNpcName)
local npcConfig = {}

npcConfig.name = internalNpcName
npcConfig.description = internalNpcName

npcConfig.health = 100
npcConfig.maxHealth = npcConfig.health
npcConfig.walkInterval = 0
npcConfig.walkRadius = 1

npcConfig.outfit = {
	lookType = 130,
	lookHead = 20,
	lookBody = 30,
	lookLegs = 40,
	lookFeet = 50,
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

local ThreatenedDreams = Storage.Quest.U11_40.ThreatenedDreams

-- CUSTOM_GLOBAL_LIKE_PENDING_EXACT_REFERENCE: no exact transcript was provided for this NPC.
local function creatureSayCallback(npc, creature, type, message)
	local player = Player(creature)
	local playerId = player:getId()

	if not npcHandler:checkInteraction(npc, creature) then
		return false
	end

	if player:getStorageValue(ThreatenedDreams.Mission06.ForestFuryFreed) >= 1 then
		npcHandler:say("Thank you again for freeing me, mortal being. I owe you a debt I can never repay.", npc, creature)
		return true
	end

	if MsgContains(message, "help") then
		npcHandler:say({
			"Shh! Keep your voice down, or the Coryms will hear! I was captured long ago and locked in this cage, and I have grown weary of these dark markets. Would you help me escape?",
		}, npc, creature)
		npcHandler:setTopic(playerId, 1)
	elseif MsgContains(message, "yes") and npcHandler:getTopic(playerId) == 1 then
		npcHandler:say({
			"Bless you, mortal being! But this will not be easy. My cage is locked with an intricate key, hidden two floors below us. And even with the key, the Coryms will notice if you are seen freeing me. ...",
			"You will need to become invisible - a spell, or perhaps a stealth ring, would do. But invisibility alone is not enough; the Coryms must still believe I am here even as I vanish. Seek out Charlotta on the surface - she knows a trick with mirror images that may help.",
		}, npc, creature)
		player:setStorageValue(ThreatenedDreams.Mission06[1], 2)
		npcHandler:setTopic(playerId, 0)
	elseif MsgContains(message, "no") then
		npcHandler:say("I understand. Please, do think it over.", npc, creature)
		npcHandler:setTopic(playerId, 0)
	end
	return true
end

npcHandler:setMessage(MESSAGE_GREET, "...Psst. Over here. Can you {help} me?")
npcHandler:setCallback(CALLBACK_MESSAGE_DEFAULT, creatureSayCallback)
npcHandler:addModule(FocusModule:new(), npcConfig.name, true, true, true)

-- npcType registering the npcConfig table
npcType:register(npcConfig)
