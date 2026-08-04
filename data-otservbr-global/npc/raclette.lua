-- Hidden Treasure sidequest, Mission Ra'Clette. Filename avoids the apostrophe in "Ra'Clette" for
-- filesystem safety; npcConfig.name below is the exact in-game display name.
local internalNpcName = "Ra'Clette"
local npcType = Game.createNpcType(internalNpcName)
local npcConfig = {}

npcConfig.name = internalNpcName
npcConfig.description = internalNpcName

npcConfig.health = 100
npcConfig.maxHealth = npcConfig.health
npcConfig.walkInterval = 2000
npcConfig.walkRadius = 2

-- CUSTOM_GLOBAL_LIKE_PENDING_EXACT_REFERENCE: outfit not specified in the reference.
npcConfig.outfit = {
	lookType = 160,
	lookHead = 60,
	lookBody = 10,
	lookLegs = 20,
	lookFeet = 30,
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

local APiratesTail = Storage.Quest.U12_60.APiratesTail

local function creatureSayCallback(npc, creature, type, message)
	local player = Player(creature)
	local playerId = player:getId()

	if not npcHandler:checkInteraction(npc, creature) then
		return false
	end

	local mission = player:getStorageValue(APiratesTail.Mission06[1])

	if MsgContains(message, "rhyme") and mission == 3 then
		npcHandler:say("You are looking for our treasure, hm? Yes, this pretty rat lady knows a part of the rhyme. But this witch won't tell just like that. Needs some help first. You agree?", npc, creature)
		npcHandler:setTopic(playerId, 1)
	elseif MsgContains(message, "yes") and npcHandler:getTopic(playerId) == 1 then
		npcHandler:say({
			"A merchant, he annoys this pretty rat lady again and again. This witch has to teach him a lesson. Already made a nice little voodoo doll to do so. But this rat lady needs something personal. ...",
			"Something that belongs to the merchant. His name is Eustacio. Maybe you find something of use in his house. Go, bring some of his belongings, then this pretty rat will tell you more about the treasure.",
		}, npc, creature)
		player:setStorageValue(APiratesTail.Mission06[1], 4)
		npcHandler:setTopic(playerId, 0)
	elseif MsgContains(message, "mission") and mission == 4 then
		npcHandler:say("Do you have it?", npc, creature)
		npcHandler:setTopic(playerId, 2)
	elseif MsgContains(message, "mission") and mission >= 6 then
		npcHandler:say("Already told you the line, handsome: ,You look like a donkey'. Little brother Queso knows another part.", npc, creature)
	elseif MsgContains(message, "yes") and npcHandler:getTopic(playerId) == 2 then
		if player:getStorageValue(APiratesTail.Mission06.GarmentObtained) >= 1 then
			npcHandler:say({
				"You did it! Thank you, this ruffian has another thing coming now! As promised, this pretty rat lady tells you what you want to know: ,You look like a donkey'. ...",
				"Yes, you do. But that's the line, understand?. Don't forget this! Little brother Queso knows another part.",
			}, npc, creature)
			player:setStorageValue(APiratesTail.Mission06[1], 6)
		else
			npcHandler:say("You don't have it yet, handsome.", npc, creature)
		end
		npcHandler:setTopic(playerId, 0)
	end
	return true
end

npcHandler:setMessage(MESSAGE_GREET, "Ahoy, handsome!")
npcHandler:setCallback(CALLBACK_MESSAGE_DEFAULT, creatureSayCallback)
npcHandler:addModule(FocusModule:new(), npcConfig.name, true, true, true)

-- npcType registering the npcConfig table
npcType:register(npcConfig)
