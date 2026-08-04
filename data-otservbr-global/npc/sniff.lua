local internalNpcName = "Sniff"
local npcType = Game.createNpcType(internalNpcName)
local npcConfig = {}

npcConfig.name = internalNpcName
npcConfig.description = internalNpcName

npcConfig.health = 100
npcConfig.maxHealth = npcConfig.health
npcConfig.walkInterval = 2000
npcConfig.walkRadius = 2

-- CUSTOM_GLOBAL_LIKE_PENDING_EXACT_REFERENCE: outfit not specified in the reference - a corym,
-- matching Ra'Clette/Queso's shared Corym Black Market / swamp family background.
npcConfig.outfit = {
	lookType = 160,
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

local APiratesTail = Storage.Quest.U12_60.APiratesTail

local function creatureSayCallback(npc, creature, type, message)
	local player = Player(creature)

	if not npcHandler:checkInteraction(npc, creature) then
		return false
	end

	local mission = player:getStorageValue(APiratesTail.Mission06[1])

	if MsgContains(message, "rhyme") then
		if mission < 1 then
			npcHandler:say("Me knows nothing about that, you.", npc, creature)
		elseif mission == 1 then
			npcHandler:say("Hunting the treasure, you, heh? Yes, me knows one part of portal opener. You help me, I tell you! Deal?", npc, creature)
		elseif mission >= 3 then
			npcHandler:say("Already told you my line, you! ,Mould is blue!' Don't forget! Ra'Clette knows third part.", npc, creature)
		else
			npcHandler:say("Found my precious goods yet?", npc, creature)
		end
	elseif MsgContains(message, "yes") and mission == 1 then
		npcHandler:say({
			"Good choice, you! Listen: Me has bad luck lately. Me had small boat, but heavy storm came ... boat sinks. And with it my goods. Me a merchant, you know. Rich and important corym merchant. ...",
			"Without my goods, me will be poor and miserable merchant. You get back my goods, me tells you line. Boat sank on southern coast of Plains of Havoc. Small bay there. ...",
			"Goods are in barrel between wreckage, me seen them from the shore! But many sharks in the water! Me not brave enough to swim there. But you look brave. You can do! ...",
			"Be careful. Can't swim everywhere without being attacked by sharks. Some spots safe, others not.",
		}, npc, creature)
		player:setStorageValue(APiratesTail.Mission06[1], 2)
	elseif (MsgContains(message, "found") or MsgContains(message, "mission")) and mission == 2 then
		npcHandler:say("Found my precious goods?", npc, creature)
	elseif MsgContains(message, "yes") and mission == 2 then
		if player:getStorageValue(APiratesTail.Mission06.SniffGoodsRecovered) >= 1 then
			npcHandler:say({
				"There they are, precious goods! Thank you! As promised, I tell you line now: ,Mould is blue!' Don't forget!",
				"Ra'Clette knows third part.",
			}, npc, creature)
			player:setStorageValue(APiratesTail.Mission06[1], 3)
		else
			npcHandler:say("You don't have my goods yet, you!", npc, creature)
		end
	end
	return true
end

npcHandler:setMessage(MESSAGE_GREET, "Ahoy, matey!")
npcHandler:setCallback(CALLBACK_MESSAGE_DEFAULT, creatureSayCallback)
npcHandler:addModule(FocusModule:new(), npcConfig.name, true, true, true)

-- npcType registering the npcConfig table
npcType:register(npcConfig)
