local internalNpcName = "Eustacio"
local npcType = Game.createNpcType(internalNpcName)
local npcConfig = {}

npcConfig.name = internalNpcName
npcConfig.description = internalNpcName

npcConfig.health = 100
npcConfig.maxHealth = npcConfig.health
npcConfig.walkInterval = 2000
npcConfig.walkRadius = 2

npcConfig.outfit = {
	lookType = 471,
	lookHead = 97,
	lookBody = 110,
	lookLegs = 71,
	lookFeet = 116,
	lookAddons = 2,
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

local RAID_TYPE_NAMES = {
	[1] = "a land attack",
	[2] = "a water attack",
	[3] = "a ship attack",
}

local function greetCallback(npc, creature)
	local player = Player(creature)

	if player:getStorageValue(APiratesTail.RascacoonShortcut) == 1 then
		npcHandler:setMessage(MESSAGE_GREET, {
			"Hello my friend. What a delight to see you, even on a {busy} day. I see you already talked to my agent. I'm willing to lend you my boat if you want to take a {shortcut}. ...",
		})
	elseif player:getStorageValue(APiratesTail.Mission01[1]) >= 1 then
		npcHandler:setMessage(MESSAGE_GREET, "Hello my friend. What a delight to see you, even on a busy day. You can check your status or ask me about the location of ongoing raids.")
	else
		npcHandler:setMessage(MESSAGE_GREET, "Hello my friend. What a delight to see you, even on a busy day.")
	end
	return true
end

local function creatureSayCallback(npc, creature, type, message)
	local player = Player(creature)
	local playerId = player:getId()

	if not npcHandler:checkInteraction(npc, creature) then
		return false
	end
	if MsgContains(message, "name") then
		npcHandler:say("I am Eustacio. At your service.", npc, creature)
	elseif MsgContains(message, "time") then
		npcHandler:say("It's just the time to make a fortune.", npc, creature)
	elseif MsgContains(message, "busy") or MsgContains(message, "job") then
		npcHandler:say(" I am an aspiring businessman, who thrives to climb the ladder of success in the Venorean society.", npc, creature)
	elseif MsgContains(message, "shortcut") then
		if player:getStorageValue(APiratesTail.RascacoonShortcut) == 1 then
			npcHandler:say({
				"You are trustworthy enough to take my boat. My agent made sure it takes me to their island. Do you want to take it?",
			}, npc, creature)
			npcHandler:setTopic(playerId, 1)
		end
	elseif MsgContains(message, "mission") then
		if player:getStorageValue(APiratesTail.Mission01[1]) < 1 then
			npcHandler:say({
				"Yes, yes, reports of Pirats came in. My goal is to weaken them significantly to get more information. ...",
				"Can you help me defend the cities and coasts against them? I will share all further details I gathered as soon as I can trust you!",
			}, npc, creature)
			npcHandler:setTopic(playerId, 2)
		elseif player:getStorageValue(APiratesTail.Mission01[1]) == 1 then
			npcHandler:say("Find them, kill them and destroy their ship! Ask me about a {flintstone} or an {orb} if you need more, or ask about your {status} or the {location} of ongoing raids.", npc, creature)
		else
			npcHandler:say("You already proved your worth to me, my friend. Ask me about your {status} if you're curious.", npc, creature)
		end
	elseif MsgContains(message, "yes") and npcHandler:getTopic(playerId) == 1 then
		creature:teleportTo(Position(33774, 31347, 7))
	elseif MsgContains(message, "yes") and npcHandler:getTopic(playerId) == 2 then
		npcHandler:say({
			"That lifts a burden off my shoulders. Ask me about a flintstone and an orb then I will give them to you. ...",
			"They are supposed to help you to fend off the pirats. You also might want to take a pick! ...",
			"Check in with me any time if you want to know about your status or whether my agents have new information about the location of the occurring pirat attacks. ...",
			"Find them, kill them and destroy their ship!",
		}, npc, creature)
		player:setStorageValue(APiratesTail.QuestLine, 1)
		player:setStorageValue(APiratesTail.Mission01[1], 1)
		npcHandler:setTopic(playerId, 0)
	elseif MsgContains(message, "flintstone") and player:getStorageValue(APiratesTail.Mission01[1]) >= 1 then
		player:addItem(35337, 1)
		npcHandler:say("Ah it's you again! Take another one then! Do not set too much on fire!", npc, creature)
	elseif MsgContains(message, "orb") and player:getStorageValue(APiratesTail.Mission01[1]) >= 1 then
		player:addItem(35376, 1)
		npcHandler:say("Good thing I like to collect everything! Take care of it this time and use it on water that is contaminated with rats!", npc, creature)
	elseif MsgContains(message, "status") then
		local points = math.max(player:getStorageValue(APiratesTail.Mission01.RaidPoints), 0)
		if player:getStorageValue(APiratesTail.Mission01[1]) < 1 then
			npcHandler:say("You haven't offered to help me yet.", npc, creature)
		elseif points < 1500 then
			npcHandler:say("You currently have " .. points .. " out of 1500 points. Keep fighting off the pirats!", npc, creature)
		elseif player:getStorageValue(APiratesTail.Mission01[1]) < 2 then
			npcHandler:say({
				"I am surprised. Due to your tireless effort and because I like numbers, I can proudly tell you that you reached a score of 1500. ...",
				"I know from my agents that there is a secret passage below Kilmaresh which leads you to their home. But they might not be what you expect. ...",
				"The entrance can be found on the coast next to the temple. You have to use a certain shell lying in the sand.",
			}, npc, creature)
			player:setStorageValue(APiratesTail.Mission01[1], 2)
			if not player:hasAchievement("Pied Piper") then
				player:addAchievement("Pied Piper")
			end
		else
			npcHandler:say("You already know about the secret passage below Kilmaresh, my friend.", npc, creature)
		end
	elseif MsgContains(message, "location") then
		if player:getStorageValue(APiratesTail.Mission01[1]) < 1 then
			npcHandler:say("Ask me about the mission first, my friend.", npc, creature)
		elseif Game.getStorageValue(GlobalStorage.APiratesTailRaid.Active) == 1 then
			local raidType = Game.getStorageValue(GlobalStorage.APiratesTailRaid.Type)
			local location = getAPiratesTailActiveLocation()
			npcHandler:say("My agents report " .. (RAID_TYPE_NAMES[raidType] or "an attack") .. " happening right now, " .. location.name .. "!", npc, creature)
		else
			npcHandler:say("No raids are happening right now, my friend. Check back soon.", npc, creature)
		end
	elseif MsgContains(message, "house") and player:getStorageValue(APiratesTail.Mission06[1]) == 4 and math.max(player:getStorageValue(APiratesTail.Mission01.RaidPoints), 0) >= 1500 then
		npcHandler:say({
			"I have to say, you did an amazing job with those pirats. Very courageous and determined, my friend! May I call you a friend? I'm sure, I may! ...",
			"Maybe I can call upon you for a favour in the future? Friends help each other, don't they? In return for possible future services, I grant you access to my home. Just in case you ever need lodging whilst in Venore. You can find it in the southern part of the city. I marked it on your map.",
		}, npc, creature)
		player:setStorageValue(APiratesTail.Mission06.EustacioHouseDoor, 1)
		player:setStorageValue(APiratesTail.Mission06[1], 5)
	end
	return true
end

npcHandler:setCallback(CALLBACK_GREET, greetCallback)
npcHandler:setCallback(CALLBACK_MESSAGE_DEFAULT, creatureSayCallback)

npcHandler:addModule(FocusModule:new(), npcConfig.name, true, true, true)

-- npcType registering the npcConfig table
npcType:register(npcConfig)
