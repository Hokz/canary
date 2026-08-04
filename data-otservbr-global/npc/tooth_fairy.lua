local internalNpcName = "Tooth Fairy"
local npcType = Game.createNpcType(internalNpcName)
local npcConfig = {}

npcConfig.name = internalNpcName
npcConfig.description = internalNpcName

npcConfig.health = 100
npcConfig.maxHealth = npcConfig.health
npcConfig.walkInterval = 2000
npcConfig.walkRadius = 2

npcConfig.outfit = {
	lookType = 223,
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

local ThreatenedDreams = Storage.Quest.U11_40.ThreatenedDreams

local tooth = {
	["orc"] = { item = 10196, storage = ThreatenedDreams.Mission04.ToothOrc, name = "an orc tooth" },
	["shark"] = { item = 22649, storage = ThreatenedDreams.Mission04.ToothShark, name = "shark teeth" },
	["vampire"] = { item = 9685, storage = ThreatenedDreams.Mission04.ToothVampire, name = "vampire teeth" },
	["behemoth"] = { item = 5893, storage = ThreatenedDreams.Mission04.ToothBehemoth, name = "a behemoth fang" },
	["carrion worm"] = { item = 10275, storage = ThreatenedDreams.Mission04.ToothCarrionWorm, name = "a carrion worm fang" },
	["werewolf"] = { item = 22052, storage = ThreatenedDreams.Mission04.ToothWerewolf, name = "werewolf fangs" },
}

local function checkAllTeeth(player)
	for _, t in pairs(tooth) do
		if player:getStorageValue(t.storage) < 1 then
			return false
		end
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
		if player:getStorageValue(ThreatenedDreams.Mission04[1]) < 1 then
			npcHandler:say({
				"You've got me, I really have a little problem here. What gave it away? My sorrowful expression? Yes, I thought so. This is what troubles me: I'm the tooth fairy. Well, this wouldn't be a problem at all under normal circumstances. ...",
				"I love gathering children's milk teeth and bringing presents for them. Until now, I did so by using a spell. This spell teleported me into the children's bedrooms and - after carrying out my duty - back to my secret realm. ...",
				"But then I made the mistake of using a magical portal and entering this part of the world. Everything is strange and different here and the worst thing: my spells don't work! It will take some time until I can use the portal again. ...",
				"Thus I'm stuck here for a while. But there are some children who lost their first milk tooth and are now waiting for their presents. Without my spells, I'm feeling utterly helpless. ...",
				"I don't dare going to their homes at night but I know they will be sad about the missing presents. Would you help me?",
			}, npc, creature)
			npcHandler:setTopic(playerId, 1)
		elseif player:getStorageValue(ThreatenedDreams.Mission04[1]) == 1 and player:getStorageValue(ThreatenedDreams.Mission04.MilkTeeth) >= 3 then
			npcHandler:say({
				"You're bringing the milk teeth! Thank you, human being; you were of great assistance to me! Please take this in return. It's the part of a map. If you find the other parts, it will show you the way to a hidden fairy treasure. ...",
				"Oh, and if you're interested, there's still another cause you could help me with.",
			}, npc, creature)
			player:addItem(24943, 1)
			player:setStorageValue(ThreatenedDreams.Mission04.MapToothFairy, 1)
			player:setStorageValue(ThreatenedDreams.Mission04[1], 2)
			npcHandler:setTopic(playerId, 0)
		elseif player:getStorageValue(ThreatenedDreams.Mission04[1]) == 1 then
			npcHandler:say("Please visit the children first and bring me their milk teeth.", npc, creature)
			npcHandler:setTopic(playerId, 0)
		else
			npcHandler:say("Thank you again for your help with the children's presents, human being.", npc, creature)
			npcHandler:setTopic(playerId, 0)
		end
	elseif MsgContains(message, "feud") or (MsgContains(message, "mission") and player:getStorageValue(ThreatenedDreams.Mission06[1]) >= 17) then
		local m6 = player:getStorageValue(ThreatenedDreams.Mission06[1])
		local toothbrushDelivered = math.max(player:getStorageValue(ThreatenedDreams.Mission06.ToothbrushDelivered), 0)
		-- Completion/already-completed must be checked before the m6==17 briefing, otherwise
		-- m6 staying at 17 during delivery makes the reward branch unreachable dead code.
		if m6 == 18 then
			npcHandler:say("You already brought me such good news about the toothbrushes. Thank you.", npc, creature)
		elseif m6 == 17 and toothbrushDelivered == 7 then
			npcHandler:say("You delivered all three toothbrushes! Perhaps my sister means well after all. Here, take this - and thank you for your help.", npc, creature)
			player:addItem(48424, 1)
			player:setStorageValue(ThreatenedDreams.Mission06.PegasusFeather, 1)
			player:setStorageValue(ThreatenedDreams.Mission06[1], 18)
		elseif m6 == 17 and toothbrushDelivered == 0 then
			npcHandler:say({
				"Oh, Dulcineo sent you? That Candy Carnival is going to rot every child's teeth in Tibia, I just know it! Someone has to think of the children. ...",
				"Would you bring toothbrushes to three children for me - Rowenna's child in Carlin, Quero's child in Thais, and Allen's child in Venore - and leave one on each of their pillows?",
			}, npc, creature)
		else
			npcHandler:say("Please bring toothbrushes to the three children and leave them on their pillows.", npc, creature)
		end
	elseif MsgContains(message, "cause") and player:getStorageValue(ThreatenedDreams.Mission04[1]) >= 2 then
		npcHandler:say({
			"As I'm the tooth fairy it should not surprise you to hear that I have a small collection. Yes, a tooth collection, of course. But I'm still lacking some special specimens. ...",
			"I would give you a little reward if you bring me one of the following - or all of them: an orc tooth, a shark tooth, a vampire tooth, a behemoth fang, a carrion worm fang or a werewolf fangs.",
		}, npc, creature)
		npcHandler:setTopic(playerId, 0)
	elseif MsgContains(message, "yes") and npcHandler:getTopic(playerId) == 1 then
		npcHandler:say({
			"Thank you very much, human being! You have to find three children: Quero's daughter in Thais, Allen's son in Venore and Rowenna's daughter in Carlin. Go to their bedrooms and find their milk teeth. ...",
			"Usually they put them on their bed-stands. Then you have to put the gifts on their beds. Please take these presents and go to Thais, Carlin and Venore. Come back with the milk teeth.",
		}, npc, creature)
		player:addItem(37547, 3)
		player:setStorageValue(ThreatenedDreams.Mission04[1], 1)
		if player:getStorageValue(ThreatenedDreams.QuestLine) < 1 then
			player:setStorageValue(ThreatenedDreams.QuestLine, 1)
		end
		npcHandler:setTopic(playerId, 0)
	elseif player:getStorageValue(ThreatenedDreams.Mission04[1]) >= 2 then
		for keyword, t in pairs(tooth) do
			if MsgContains(message, keyword) then
				if player:getStorageValue(t.storage) >= 1 then
					npcHandler:say("You already gave me " .. t.name .. ". Thank you again, human being!", npc, creature)
				elseif player:getItemCount(t.item) >= 1 then
					player:removeItem(t.item, 1)
					player:addItem(3026, 1)
					player:setStorageValue(t.storage, 1)
					npcHandler:say("Oh, I see! You really found " .. t.name .. " for me! Thank you, human being! Please take this in return.", npc, creature)
					if checkAllTeeth(player) and player:getStorageValue(ThreatenedDreams.Mission04.ToothfairyAssistant) < 1 then
						player:setStorageValue(ThreatenedDreams.Mission04.ToothfairyAssistant, 1)
						player:addAchievement("Toothfairy Assistant")
					end
				else
					npcHandler:say("I don't think you have " .. t.name .. " with you right now.", npc, creature)
				end
				return true
			end
		end
	elseif MsgContains(message, "no") then
		npcHandler:say("Then not.", npc, creature)
		npcHandler:setTopic(playerId, 0)
	end
	return true
end

npcHandler:setMessage(MESSAGE_GREET, "Greetings, human being.")
npcHandler:setCallback(CALLBACK_MESSAGE_DEFAULT, creatureSayCallback)
npcHandler:addModule(FocusModule:new(), npcConfig.name, true, true, true)

-- npcType registering the npcConfig table
npcType:register(npcConfig)
