local internalNpcName = "Demonic Messenger"
local npcType = Game.createNpcType(internalNpcName)
local npcConfig = {}

npcConfig.name = internalNpcName
npcConfig.description = internalNpcName

npcConfig.health = 100
npcConfig.maxHealth = npcConfig.health
npcConfig.walkInterval = 0
npcConfig.walkRadius = 2

npcConfig.outfit = {
	lookType = 35,
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
-- Purely informational - stands at the entrance to the Halls of Ascension and explains the
-- betrayal and the final fight's mechanics. Does not gate any progression.
local function creatureSayCallback(npc, creature, type, message)
	if not npcHandler:checkInteraction(npc, creature) then
		return false
	end

	if MsgContains(message, "mission") or MsgContains(message, "help") then
		npcHandler:say({
			"You should not be here, mortal - and yet, perhaps you are the only chance left. Mazarius, the one you trusted, serves Variphor. He stole the Godbreaker parts you retrieved and delivered them straight into the ritual. ...",
			"Ferumbras is ascending even now. You cannot simply strike him down - his ascension must be unravelled, piece by piece, the same way it was built.",
		}, npc, creature)
	elseif MsgContains(message, "ferumbras") then
		npcHandler:say("Ferumbras reaches for godhood through stolen rites. Every stage of his ascension has a weakness, if you know where to look.", npc, creature)
	elseif MsgContains(message, "crystals") then
		npcHandler:say("Eight crystals bind the ritual in place. Rift Invaders spawn near them - lead the creatures close and let their instability crack the crystals open.", npc, creature)
	elseif MsgContains(message, "splinters") then
		npcHandler:say("Once the crystals shatter, Ferumbras' will fractures into Soul Splinters. Face them one at a time - together they are overwhelming, but alone each falls quickly and leaves behind a harmless essence.", npc, creature)
	elseif MsgContains(message, "fragments") then
		npcHandler:say("Lead the essences onto the rifts the invaders leave behind - that is how you unmake them. Only then will Rift Fragments answer a Convince Creature Rune. Bind them - they alone can wound what Ferumbras is becoming.", npc, creature)
	elseif MsgContains(message, "mortal shell") then
		npcHandler:say("What remains after the fragments have done their work is only a shell - mortal again, if only for a moment. That moment is all you will need.", npc, creature)
	end
	return true
end

npcHandler:setMessage(MESSAGE_GREET, "Do not fear me, mortal - I am no friend of the one you seek, either. Ask me for {help} if you wish to understand what lies ahead.")
npcHandler:setCallback(CALLBACK_MESSAGE_DEFAULT, creatureSayCallback)
npcHandler:addModule(FocusModule:new(), npcConfig.name, true, true, true)

-- npcType registering the npcConfig table
npcType:register(npcConfig)
