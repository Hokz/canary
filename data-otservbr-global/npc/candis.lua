local internalNpcName = "Candis"
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
	lookHead = 10,
	lookBody = 10,
	lookLegs = 10,
	lookFeet = 10,
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
		npcHandler:setMessage(MESSAGE_GREET, "*She points worriedly down the mine shaft, miming digging, then shakes her head sadly.*")
	else
		npcHandler:setMessage(MESSAGE_GREET, "Oh! A visitor who speaks! I run the Chocolate Mines, or - well, I try to.")
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
		if m6 == 10 then
			npcHandler:say({
				"Some of my workers went digging too close to a strange portal deep in the mines and haven't come back. Something calling itself Sugar Daddy is down there - I fear he's got them trapped. ...",
				"Would you go in and free them? I'd be ever so grateful.",
			}, npc, creature)
			player:setStorageValue(ThreatenedDreams.Mission06[1], 11)
		elseif m6 == 11 then
			npcHandler:say("Please, if you can, put a stop to whatever Sugar Daddy is doing down there and free my workers.", npc, creature)
		elseif m6 == 12 then
			npcHandler:say({
				"You did it! You freed my workers from Sugar Daddy! Thank you so much. But the mines are still unstable - there are broken walls that need sealing and some Honey Elementals have gotten loose. ...",
				"There is a chest to the north with candy canes in it - use them to seal the broken walls, two on the upper level and one further down. And if you could catch the loose Honey Elementals in jars, I would be very grateful.",
			}, npc, creature)
			player:setStorageValue(ThreatenedDreams.Mission06[1], 13)
		elseif m6 == 13 then
			npcHandler:say("Have you sealed the broken walls and caught the Honey Elementals yet?", npc, creature)
		elseif m6 == 14 then
			if player:getStorageValue(ThreatenedDreams.Mission06.CandyCaneCount) >= 3 and player:getStorageValue(ThreatenedDreams.Mission06.HoneyElementalCount) >= 5 then
				npcHandler:say({
					"The mines feel steady again, thank you! Please, go tell Sugar Plum Fairy the good news - I think the Candy Carnival can finally reopen.",
				}, npc, creature)
				player:setStorageValue(ThreatenedDreams.Mission06[1], 15)
			else
				npcHandler:say("The mines still aren't quite stable. Please finish sealing the walls and catching the Honey Elementals.", npc, creature)
			end
		elseif m6 > 14 then
			npcHandler:say("Thank you again for stabilizing the mines!", npc, creature)
		else
			npcHandler:say("I don't have anything for you to do just yet, sweet thing.", npc, creature)
		end
	end
	return true
end

npcHandler:setCallback(CALLBACK_GREET, greetCallback)
npcHandler:setCallback(CALLBACK_MESSAGE_DEFAULT, creatureSayCallback)
npcHandler:addModule(FocusModule:new(), npcConfig.name, true, true, true)

-- npcType registering the npcConfig table
npcType:register(npcConfig)
