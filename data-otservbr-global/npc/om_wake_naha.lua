local internalNpcName = "Om'Wake Naha"
local npcType = Game.createNpcType(internalNpcName)
local npcConfig = {}

npcConfig.name = internalNpcName
npcConfig.description = internalNpcName

npcConfig.health = 100
npcConfig.maxHealth = npcConfig.health
npcConfig.walkInterval = 2000
npcConfig.walkRadius = 2

-- CUSTOM_GLOBAL_LIKE_PENDING_EXACT_REFERENCE: outfit not specified in the reference, built to
-- match the established Rascoohan-race look (lookType 1371/1372, see gnomfurry.lua).
npcConfig.outfit = {
	lookType = 1372,
	lookHead = 10,
	lookBody = 30,
	lookLegs = 50,
	lookFeet = 70,
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

local function creatureSayCallback(npc, creature, type, message)
	local player = Player(creature)

	if not npcHandler:checkInteraction(npc, creature) then
		return false
	end

	if MsgContains(message, "supplies") then
		npcHandler:say("Pesky ratmen are constantly raiding our cheese supplies. I could use a helping hand or two, to get rid of this problem.", npc, creature)
	elseif MsgContains(message, "helping") then
		npcHandler:say("The pirats use transformation magic to enter my cheese cellar as rats and they devour and steal our precious cheese.", npc, creature)
	elseif MsgContains(message, "cheese") then
		npcHandler:say("Push as many cheese as you can into the cheese larder in the center of the cellar. Use the staffs that our shaman supplied to dispel the disguise of the rats to fight the intruders.", npc, creature)
	end
	return true
end

npcHandler:setMessage(MESSAGE_GREET, "Hello, traveller! Be welcome!")
npcHandler:setCallback(CALLBACK_MESSAGE_DEFAULT, creatureSayCallback)
npcHandler:addModule(FocusModule:new(), npcConfig.name, true, true, true)

-- npcType registering the npcConfig table
npcType:register(npcConfig)
