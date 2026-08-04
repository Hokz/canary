-- CUSTOM_GLOBAL_LIKE_PENDING_EXACT_REFERENCE: outfit/appearance not specified in the reference,
-- built to match the established Rascoohan-race look (lookType 1371/1372, see gnomfurry.lua).
local internalNpcName = "Tik'hi Tak'he"
local npcType = Game.createNpcType(internalNpcName)
local npcConfig = {}

npcConfig.name = internalNpcName
npcConfig.description = internalNpcName

npcConfig.health = 100
npcConfig.maxHealth = npcConfig.health
npcConfig.walkInterval = 2000
npcConfig.walkRadius = 2

npcConfig.outfit = {
	lookType = 1371,
	lookHead = 20,
	lookBody = 40,
	lookLegs = 60,
	lookFeet = 80,
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

local APiratesTail = Storage.Quest.U12_60.APiratesTail

-- CUSTOM_GLOBAL_LIKE_PENDING_EXACT_REFERENCE: the reference lists Rascoohan wares only by
-- category and price ("necklaces at 4,000 TP and 10,000 TP", "backpack at 15,000 TP", "6 wall
-- decorations at 4,000/5,000/5,000/8,000/12,000/6,000 TP") without naming the exact items -
-- source images were not extractable. Mapped onto items.xml's unreferenced, unallocated
-- Rascoohan-adjacent item set (6 necklaces, 1 raccoon backpack, and exactly 6 trophy/wall-decor
-- items matching the 6 listed prices) - a reasonable, disclosed judgment call, not confirmed 1:1.
local wares = {
	["sapphire necklace"] = { item = 35604, price = 4000 },
	["emerald necklace"] = { item = 35605, price = 4000 },
	["garnet necklace"] = { item = 35606, price = 4000 },
	["rhodolith necklace"] = { item = 35608, price = 4000 },
	["amethyst necklace"] = { item = 35609, price = 4000 },
	["diamond necklace"] = { item = 35607, price = 10000 },
	["raccoon backpack"] = { item = 35577, price = 15000 },
	["blue shark trophy"] = { item = 35582, price = 4000 },
	["striped shark trophy"] = { item = 35584, price = 5000 },
	["brown shark trophy"] = { item = 35585, price = 5000 },
	["golden shark trophy"] = { item = 35586, price = 8000 },
	["hammerhead trophy"] = { item = 35599, price = 12000 },
	["shark jaws"] = { item = 35587, price = 6000 },
}

local function greetCallback(npc, creature)
	local player = Player(creature)
	if player:getStorageValue(APiratesTail.Mission02[1]) >= 2 then
		npcHandler:setMessage(MESSAGE_GREET, "Hail, visitor! Welcome! You can ask me about your 'trust points'!")
	else
		npcHandler:setMessage(MESSAGE_GREET, "Hail, visitor! Welcome!")
	end
	return true
end

local function creatureSayCallback(npc, creature, type, message)
	local player = Player(creature)
	local playerId = player:getId()

	if not npcHandler:checkInteraction(npc, creature) then
		return false
	end

	if MsgContains(message, "mission") then
		if player:getStorageValue(APiratesTail.Mission02[1]) < 2 then
			npcHandler:say("Do you want to help our colony, to earn our trust and respect?", npc, creature)
			npcHandler:setTopic(playerId, 1)
		else
			npcHandler:say("Go ahead then. You will get what I like to call 'trust points' for different tasks.", npc, creature)
		end
	elseif MsgContains(message, "yes") and npcHandler:getTopic(playerId) == 1 then
		npcHandler:say("Go ahead then. You will get what I like to call 'trust points' for different tasks.", npc, creature)
		player:setStorageValue(APiratesTail.Mission02[1], 2)
		player:setStorageValue(APiratesTail.RascacoonShortcut, 1)
		if player:getStorageValue(APiratesTail.Mission03[1]) < 1 then
			player:setStorageValue(APiratesTail.Mission03[1], 1)
		end
		npcHandler:setTopic(playerId, 0)
	elseif MsgContains(message, "no") and npcHandler:getTopic(playerId) == 1 then
		npcHandler:say("Very well. Come back if you change your mind.", npc, creature)
		npcHandler:setTopic(playerId, 0)
	elseif MsgContains(message, "trust points") or MsgContains(message, "trust") then
		local points = math.max(player:getStorageValue(APiratesTail.Mission03.TrustPoints), 0)
		if player:getStorageValue(APiratesTail.Mission02[1]) < 2 then
			npcHandler:say("You haven't offered to help our colony yet.", npc, creature)
		elseif player:getStorageValue(APiratesTail.Mission03.TrustPoints1200Reached) < 1 then
			if points >= 1200 then
				npcHandler:say({
					"You held out for a long time. I think you earned our trust. ...",
					"Listen closely. There is a teleporter in the east of the island. It is used by pirats to go on board of their ship. ...",
					"If you really want to help against the pirats, go through it and find out what's going on. But there is one catch! ...",
					"You need to look like a pirat to go thorugh the teleporter. For 1200 trust points, I will cast a permanent entchantment on you that transforms you into a pirat for fifteen minutes every time you step through the teleporter. ...",
					"I will also grant you access to my special assortment of rascoohan wares after you reached the pirats hideout. Do you want to advance?",
				}, npc, creature)
				npcHandler:setTopic(playerId, 2)
			else
				npcHandler:say("You currently have " .. points .. " out of 1200 trust points. Keep helping our colony!", npc, creature)
			end
		else
			npcHandler:say("You are a trusted friend of the Rascoohan people. Ask me about my {wares} if you'd like to trade your trust points for something.", npc, creature)
		end
	elseif MsgContains(message, "yes") and npcHandler:getTopic(playerId) == 2 then
		npcHandler:say("I hereby name you trusted friend of the Rascoohan people!", npc, creature)
		player:setStorageValue(APiratesTail.Mission03.TrustPoints1200Reached, 1)
		player:setStorageValue(APiratesTail.Mission03[1], 2)
		npcHandler:setTopic(playerId, 0)
	elseif MsgContains(message, "no") and npcHandler:getTopic(playerId) == 2 then
		npcHandler:say("Very well, ask me again whenever you're ready.", npc, creature)
		npcHandler:setTopic(playerId, 0)
	elseif MsgContains(message, "wares") and player:getStorageValue(APiratesTail.Mission05[1]) >= 1 then
		npcHandler:say("Take a look at my assortment - just tell me the name of what you'd like, and I'll trade it for your trust points.", npc, creature)
	elseif MsgContains(message, "wares") then
		npcHandler:say("That assortment is only for those who've reached the pirats' hideout, my friend.", npc, creature)
	elseif player:getStorageValue(APiratesTail.Mission05[1]) >= 1 then
		for name, ware in pairs(wares) do
			if MsgContains(message, name) then
				local points = math.max(player:getStorageValue(APiratesTail.Mission03.TrustPoints), 0)
				if points < ware.price then
					npcHandler:say("You need " .. ware.price .. " trust points for that - you only have " .. points .. ".", npc, creature)
				else
					player:setStorageValue(APiratesTail.Mission03.TrustPoints, points - ware.price)
					player:addItem(ware.item, 1)
					npcHandler:say("Here you go, my friend. Thank you for your continued help.", npc, creature)
				end
				return true
			end
		end
	end
	return true
end

npcHandler:setMessage(MESSAGE_GREET, "Hail, visitor! Welcome! You can ask me about your 'trust points'!")
npcHandler:setCallback(CALLBACK_MESSAGE_DEFAULT, creatureSayCallback)
npcHandler:addModule(FocusModule:new(), npcConfig.name, true, true, true)

-- npcType registering the npcConfig table
npcType:register(npcConfig)
