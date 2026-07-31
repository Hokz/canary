local internalNpcName = "Tired Tree"
local npcType = Game.createNpcType(internalNpcName)
local npcConfig = {}

npcConfig.name = internalNpcName
npcConfig.description = internalNpcName

npcConfig.health = 100
npcConfig.maxHealth = npcConfig.health
npcConfig.walkInterval = 2000
npcConfig.walkRadius = 2

npcConfig.outfit = {
	lookTypeEx = 25405,
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

	if MsgContains(message, "mission") then
		if player:getStorageValue(ThreatenedDreams.Mission04.MapTiredTree) >= 1 then
			npcHandler:say("I already told you my favourite bedtime story, human being. Rest well.", npc, creature)
		else
			npcHandler:say({
				"*yaaawn* Oh, a visitor. Forgive my drowsiness, I am terribly tired but I cannot find rest. My roots ache for a bedtime story, one about the dryads who once tended these woods. ...",
				"If you know such a story, or find one written down somewhere, tell it to me and I will finally be able to sleep. Do you know where I might find such a tale?",
			}, npc, creature)
			npcHandler:setTopic(playerId, 1)
		end
	elseif MsgContains(message, "the seeds of life") then
		if player:getStorageValue(ThreatenedDreams.Mission04.MapTiredTree) < 1 then
			npcHandler:say({
				"'The Seeds of Life'... yes, yes, I remember that tale now, of the dryads and the first seeds. My branches feel lighter already. Thank you, traveller - take this in return, I found it tangled in my roots long ago.",
			}, npc, creature)
			player:addItem(24945, 1)
			player:setStorageValue(ThreatenedDreams.Mission04.MapTiredTree, 1)
		else
			npcHandler:say("Sleep well, indeed. Thank you again.", npc, creature)
		end
		npcHandler:setTopic(playerId, 0)
	elseif MsgContains(message, "yes") and npcHandler:getTopic(playerId) == 1 then
		npcHandler:say("There is said to be a book called 'The Seeds of Life' in the library of Ab'Dendriel. If you find it and read it, come back and tell me the story.", npc, creature)
		npcHandler:setTopic(playerId, 0)
	elseif MsgContains(message, "no") then
		npcHandler:say("*sigh* Then I suppose I shall remain awake a while longer.", npc, creature)
		npcHandler:setTopic(playerId, 0)
	end
	return true
end

npcHandler:setMessage(MESSAGE_GREET, "*yaaawn* Nature's blessing, traveller.")
npcHandler:setCallback(CALLBACK_MESSAGE_DEFAULT, creatureSayCallback)
npcHandler:addModule(FocusModule:new(), npcConfig.name, true, true, true)

-- npcType registering the npcConfig table
npcType:register(npcConfig)
