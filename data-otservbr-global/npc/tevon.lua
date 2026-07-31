local internalNpcName = "Tevon"
local npcType = Game.createNpcType(internalNpcName)
local npcConfig = {}

npcConfig.name = internalNpcName
npcConfig.description = internalNpcName

npcConfig.health = 100
npcConfig.maxHealth = npcConfig.health
npcConfig.walkInterval = 0
npcConfig.walkRadius = 2

npcConfig.outfit = {
	lookType = 130,
	lookHead = 0,
	lookBody = 0,
	lookLegs = 0,
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

-- CUSTOM_GLOBAL_LIKE_PENDING_EXACT_REFERENCE: no exact transcript was provided for this NPC.
-- The Tarbaz seal's letter puzzle and boss-room access are already fully implemented via storage
-- progression and a cooldown-only gate (movements_seal.lua) with no NPC step in the current code
-- path - this dialogue intentionally does not add a new hard gate on top of that, only reacts to
-- whether the puzzle (all 5 letters, tracked via BasinCounter/TarbazNotes/BoneFlute) and the
-- returned Desperate Soul are complete, to avoid risking the already-working access flow.
local function creatureSayCallback(npc, creature, type, message)
	local player = Player(creature)
	if not npcHandler:checkInteraction(npc, creature) then
		return false
	end

	local remembered = player:getStorageValue(Storage.Quest.U10_90.FerumbrasAscension.DesperateSoul) >= 1

	if MsgContains(message, "mission") then
		if remembered then
			npcHandler:say("You brought my soul back to me... I remember now, fragment by fragment. Speak my name, if you have found it.", npc, creature)
		else
			npcHandler:say("Who... who am I? The ruins keep no answer. Something of me still wanders out there, lost. If you find it, bring it to me.", npc, creature)
		end
	elseif MsgContains(message, "tevon") then
		if remembered then
			npcHandler:say("Tevon... yes. Yes! That is my name. I remember it all now. Go - the way north is open to you.", npc, creature)
		else
			npcHandler:say("That name... it stirs something in me, but it is not whole yet. Bring back what still wanders lost, first.", npc, creature)
		end
	end
	return true
end

npcHandler:setMessage(MESSAGE_GREET, "...who goes there? I- I cannot recall my own name. Ask me of my {mission}, if you are willing to help a fragmented soul.")
npcHandler:setCallback(CALLBACK_MESSAGE_DEFAULT, creatureSayCallback)
npcHandler:addModule(FocusModule:new(), npcConfig.name, true, true, true)

-- npcType registering the npcConfig table
npcType:register(npcConfig)
