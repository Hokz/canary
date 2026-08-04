local internalNpcName = "Corym Footman"
local npcType = Game.createNpcType(internalNpcName)
local npcConfig = {}

npcConfig.name = internalNpcName
npcConfig.description = internalNpcName

npcConfig.health = 100
npcConfig.maxHealth = npcConfig.health
npcConfig.walkInterval = 2000
npcConfig.walkRadius = 2

npcConfig.outfit = {
	lookType = 533,
	lookHead = 0,
	lookBody = 0,
	lookLegs = 115,
	lookFeet = 0,
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

local HiddenThreats = Storage.Quest.U11_50.HiddenThreats
-- Corrected to the PDF's exact transcript for Corym Footman ("My hero! ... little reward."), which
-- matches the reward-granting line used by the other freed coryms in this role (Corym Worker (1)/
-- (3)/(5)). This file previously used an invented "hunger" greeting/keyword with no PDF source,
-- unmarked as custom - a transcript-fidelity violation, fixed here.
--
-- No addItem call despite the "reward" line: a direct player report on the source page (correcting
-- the article's own reward infobox) lists the quest's complete reward set as "2 gold nuggets, a
-- small amethyst, a small emerald, a small ruby" - exactly the 4 items Corym Worker (1)/(3)/(5) and
-- Corym Servant already grant, with no 5th item. Adding one here would exceed that confirmed total.
-- OWNER_DECISION_REWARD_REFERENCE_CONFLICT: the PDF's literal transcript implies Footman also hands
-- over a physical trinket like the other two reward-granting workers; the confirmed aggregate total
-- says otherwise. Flagged for owner verification rather than guessed.
local function greetCallback(npc, creature, message)
	local player = Player(creature)

	if player:getStorageValue(HiddenThreats.CorymRescued08) < 0 then
		npcHandler:setMessage(MESSAGE_GREET, {
			"My hero! A friend of mine sent you to liberate me? A true friend! I am poor but nevertheless I give you this as little reward.",
		})
		player:setStorageValue(HiddenThreats.CorymRescueMission, player:getStorageValue(HiddenThreats.CorymRescueMission) + 1)
		player:setStorageValue(HiddenThreats.CorymRescued08, 1)
	else
		npcHandler:setMessage(MESSAGE_GREET, "My hero! A friend of mine sent you to liberate me? A true friend!")
	end
	return true
end

local function creatureSayCallback(npc, creature, type, message)
	if not npcHandler:checkInteraction(npc, creature) then
		return false
	end
	return true
end

-- Greeting message
npcHandler:setMessage(MESSAGE_FAREWELL, "Good bye, |PLAYERNAME|.")

npcHandler:setCallback(CALLBACK_GREET, greetCallback)
npcHandler:setCallback(CALLBACK_MESSAGE_DEFAULT, creatureSayCallback)

npcHandler:addModule(FocusModule:new(), npcConfig.name, true, true, true)

-- npcType registering the npcConfig table
npcType:register(npcConfig)
