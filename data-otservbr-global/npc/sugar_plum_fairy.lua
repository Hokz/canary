local internalNpcName = "Sugar Plum Fairy"
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
	lookHead = 0,
	lookBody = 0,
	lookLegs = 0,
	lookFeet = 0,
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
		npcHandler:setMessage(MESSAGE_GREET, "*She waves and points cheerfully at your mouth, then shrugs - she cannot understand you, nor you her.*")
	else
		npcHandler:setMessage(MESSAGE_GREET, "Ooooh, a visitor who can actually talk! Welcome to Candia, sweet thing!")
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

	if MsgContains(message, "mission") then
		local m6 = player:getStorageValue(ThreatenedDreams.Mission06[1])
		if m6 < 9 then
			npcHandler:say({
				"Oh, it's just terrible! My favourite sweets, my precious collection, all stolen! A dreadful creature called Kroazur took the first of them, over in Feyrist. ...",
				"But that's not all - I've heard he sold the rest to other unsavoury sorts. There's a Katex Blood Tongue, a Flaming Orchid, and someone called Gorga, each hoarding one of my sweets now. Would you get them back for me?",
			}, npc, creature)
			player:setStorageValue(ThreatenedDreams.Mission06[1], 9)
		elseif m6 == 9 then
			npcHandler:say("Have you found my sweets yet? There's Matcha Turtle, Rainbow Waffles, Rose Milk Cake and Nightsky Cupcake.", npc, creature)
		elseif m6 >= 15 and m6 < 16 then
			npcHandler:say({
				"Candis told me everything! Thank you for helping stabilize the mines, sweet thing. The Candy Carnival can finally reopen - Coco and Toffee will be so pleased! ...",
				"You've done so much for us. If you ever want to help with one more little thing, just ask.",
			}, npc, creature)
			player:setStorageValue(ThreatenedDreams.Mission06.CandyCarnivalOpen, 1)
			player:setStorageValue(ThreatenedDreams.Mission06[1], 16)
		else
			npcHandler:say("Thank you again, sweet thing! I don't know what Candia would do without you.", npc, creature)
		end
	elseif MsgContains(message, "matcha turtle") or MsgContains(message, "rainbow waffles") or MsgContains(message, "rose milk cake") or MsgContains(message, "nightsky cupcake") then
		if player:getStorageValue(ThreatenedDreams.Mission06[1]) ~= 9 then
			return true
		end
		if player:getStorageValue(ThreatenedDreams.Mission06.SweetKroazur) >= 1 and player:getStorageValue(ThreatenedDreams.Mission06.SweetKatex) >= 1 and player:getStorageValue(ThreatenedDreams.Mission06.SweetOrchid) >= 1 and player:getStorageValue(ThreatenedDreams.Mission06.SweetGorga) >= 1 then
			npcHandler:say({
				"You found them all! My sweets, back at last! You have my deepest thanks, sweet thing. Go speak to Candis at the Chocolate Mines - I believe some of my workers went missing near a dangerous portal, and she could use your help too.",
			}, npc, creature)
			player:setStorageValue(ThreatenedDreams.Mission06[1], 10)
		else
			npcHandler:say("You haven't found them all yet, sweet thing. Keep looking!", npc, creature)
		end
	elseif MsgContains(message, "taffy bunny") then
		if player:getStorageValue(ThreatenedDreams.Mission06[1]) == 19 then
			npcHandler:say({
				"Oh no, oh no! One of my taffy bunnies, Cherry, has gone missing! She must have hopped off into the Dessert Dungeons below. She's terribly quick, but perhaps you could find some trace of her?",
			}, npc, creature)
		elseif player:getStorageValue(ThreatenedDreams.Mission06[1]) > 19 then
			npcHandler:say("Have you seen any sign of Cherry down in the Dessert Dungeons?", npc, creature)
		end
	elseif MsgContains(message, "bunny") then
		if player:getStorageValue(ThreatenedDreams.Mission06[1]) >= 19 and player:getStorageValue(ThreatenedDreams.Mission06.CherryFound) >= 1 then
			npcHandler:say("Oh, she's just too fast for anyone to catch, isn't she? But knowing she's safe and sound down there is enough for me. Thank you, sweet thing - you have given this whole realm a much sweeter dream.", npc, creature)
			player:setStorageValue(ThreatenedDreams.Mission06.TaffyBunnyReported, 1)
			player:setStorageValue(ThreatenedDreams.Mission06[1], 20)
		end
	end
	return true
end

npcHandler:setCallback(CALLBACK_GREET, greetCallback)
npcHandler:setCallback(CALLBACK_MESSAGE_DEFAULT, creatureSayCallback)
npcHandler:addModule(FocusModule:new(), npcConfig.name, true, true, true)

-- npcType registering the npcConfig table
npcType:register(npcConfig)
