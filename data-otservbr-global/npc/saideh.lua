local internalNpcName = "Saideh"
local npcType = Game.createNpcType(internalNpcName)
local npcConfig = {}

npcConfig.name = internalNpcName
npcConfig.description = internalNpcName

npcConfig.health = 100
npcConfig.maxHealth = npcConfig.health
npcConfig.walkInterval = 2000
npcConfig.walkRadius = 2

npcConfig.outfit = {
	lookType = 330,
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

	if player:getStorageValue(Storage.Quest.U12_20.KilmareshQuest.First.Access) < 1 then
		npcHandler:setMessage(MESSAGE_GREET, "Hello, my name is Saideh. Once this was the entry to the crypt of our heroes. One of the graves belongs to our beloved hero Dayyan. Nowadays it is not a good idea to visit this place.")
		npcHandler:setTopic(playerId, 1)
	end
	return true
end

local function creatureSayCallback(npc, creature, type, message)
	local player = Player(creature)
	local playerId = player:getId()

	if not npcHandler:checkInteraction(npc, creature) then
		return false
	end

	if MsgContains(message, "mission") and player:getStorageValue(Storage.Quest.U12_20.KilmareshQuest.Fourteen.Remains) == 1 then
		if player:getStorageValue(Storage.Quest.U12_20.KilmareshQuest.Fourteen.Remains) == 1 then
			npcHandler:say({ " I would like you to visit the grave of our beloved hero Dayyan. His remains have to be reburied, because a horde of ogres controls this place. Do you want to start this holy mission?" }, npc, creature)
			npcHandler:setTopic(playerId, 1)
			npcHandler:setTopic(playerId, 1)
		end
	elseif MsgContains(message, "yes") and npcHandler:getTopic(playerId) == 1 and player:getStorageValue(Storage.Quest.U12_20.KilmareshQuest.Fourteen.Remains) == 1 then
		if player:getStorageValue(Storage.Quest.U12_20.KilmareshQuest.Fourteen.Remains) == 1 then
			npcHandler:say({ "Well, I appreciate that. Good luck!" }, npc, creature)
			player:setStorageValue(Storage.Quest.U12_20.KilmareshQuest.Fourteen.Remains, 2)
			npcHandler:setTopic(playerId, 2)
			npcHandler:setTopic(playerId, 2)
		else
			npcHandler:say({ "Sorry." }, npc, creature)
		end
	-- CONFIRMED BLOCKER (pre-existing): this NPC never had a report/reward branch at all. The
	-- dungeon's cage key (actions_cagekey.lua) and the grave search (actions_tumulo.lua) both existed
	-- (the latter as a stub, now fixed) and correctly advanced Fourteen.Remains up to 4, but nothing
	-- anywhere ever read that value back or granted the mission's reward - the source's explicit
	-- 20000 XP could never be claimed no matter how far a player got.
	elseif MsgContains(message, "report") and player:getStorageValue(Storage.Quest.U12_20.KilmareshQuest.Fourteen.Remains) == 4 then
		npcHandler:say({
			"The grave has been violated? It seems that the ogres aren't the most dangerous threat. These creatures are not capable to surpass the second floor with all the puzzles. But the monsters around the desecrated grave are different, much more intelligent. ...",
			"Although your mission was not as successful as I hoped, I would like to thank you for your help. Take this as a little reward.",
		}, npc, creature)
		player:addExperience(20000, true)
		player:setStorageValue(Storage.Quest.U12_20.KilmareshQuest.Fourteen.Remains, 5)
		npcHandler:setTopic(playerId, 0)
	end
	return true
end

npcHandler:setMessage(MESSAGE_WALKAWAY, "Well, bye then.")

npcHandler:setCallback(CALLBACK_SET_INTERACTION, onAddFocus)
npcHandler:setCallback(CALLBACK_REMOVE_INTERACTION, onReleaseFocus)
npcHandler:setCallback(CALLBACK_GREET, greetCallback)
npcHandler:setCallback(CALLBACK_MESSAGE_DEFAULT, creatureSayCallback)

npcHandler:addModule(FocusModule:new(), npcConfig.name, true, true, true)

-- npcType registering the npcConfig table
npcType:register(npcConfig)
