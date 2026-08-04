local internalNpcName = "Charos"
local npcType = Game.createNpcType(internalNpcName)
local npcConfig = {}

npcConfig.name = internalNpcName
npcConfig.description = internalNpcName

npcConfig.health = 100
npcConfig.maxHealth = npcConfig.health
npcConfig.walkInterval = 0
npcConfig.walkRadius = 2

npcConfig.outfit = {
	lookType = 133,
	lookHead = 60,
	lookBody = 94,
	lookLegs = 114,
	lookFeet = 115,
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

local config = {
	towns = {
		["venore"] = TOWNS_LIST.VENORE,
		["thais"] = TOWNS_LIST.THAIS,
		["kazordoon"] = TOWNS_LIST.KAZORDOON,
		["carlin"] = TOWNS_LIST.CARLIN,
		["ab'dendriel"] = TOWNS_LIST.AB_DENDRIEL,
		["liberty bay"] = TOWNS_LIST.LIBERTY_BAY,
		["port hope"] = TOWNS_LIST.PORT_HOPE,
		["ankrahmun"] = TOWNS_LIST.ANKRAHMUN,
		["darashia"] = TOWNS_LIST.DARASHIA,
		["edron"] = TOWNS_LIST.EDRON,
	},
}

local function greetCallback(npc, creature)
	local player = Player(creature)
	local playerId = player:getId()

	if player:getStorageValue(Storage.Quest.U9_80.AdventurersGuild.CharosTrav) > 6 then
		npcHandler:say("Sorry, you have traveled a lot.", npc, creature)
		npcHandler:resetNpc(npc, creature)
		return false
	else
		npcHandler:setMessage(
			MESSAGE_GREET,
			"Hello young friend! I can attune you to a city of your choice. \z
		If you step to the teleporter here you will not appear in the city you came from as usual, \z
		but the city of your choice. Is it what you wish?"
		)
	end
	return true
end

-- Measuring Tibia (World Discovery / Discoverer outfit) - Charos no longer STARTS this quest (modern
-- 11.80+ behavior per owner clarification: discovery is automatic, no NPC keyword required to
-- begin) - he only provides information and grants the outfit/addon/achievement rewards at 10/15/20
-- fully-discovered areas. Exact PDF transcript keywords: discovering -> outfit -> yes -> yes ->
-- ten/fifteen/twenty.
--
-- CONFLICT DISCLOSED (see PR body): the source PDF's exact transcript shows Charos's greeting itself
-- as "I'm sorry but you are no longer eligible for my travelling services..." in ALL its examples,
-- implying the old attunement-travel service is fully retired in the current game. This repo's
-- pre-existing CharosTrav/city-teleport service (above) is real, working, unrelated content from the
-- old Adventurer's Guild quest - preserved exactly as-is per this package's own explicit instruction
-- ("If Charos has unrelated travel services, preserve repo behavior"), rather than replaced with the
-- "no longer eligible" line as a universal greeting. The Discoverer dialogue below is reachable via
-- keyword at any time, independent of travel-service topic state, satisfying the modern transcript's
-- keyword requirements without deleting or gating the existing travel feature.
local DISCOVERING_TOPIC_OUTFIT_ASKED = 10
local DISCOVERING_TOPIC_ADDON_INFO_GIVEN = 11
local DISCOVERING_TOPIC_COUNT_ASKED = 12

local DiscovererOutfits = Storage.Quest.U11_80.DiscovererOutfits

local tierByWord = {
	ten = { count = 10, storage = DiscovererOutfits.BaseClaimed, grant = function(player)
		player:addOutfit(MeasuringTibia.OUTFIT_LOOKTYPE_MALE)
		player:addOutfit(MeasuringTibia.OUTFIT_LOOKTYPE_FEMALE)
		if not player:hasAchievement("Widely Travelled") then
			player:addAchievement("Widely Travelled")
		end
	end, replyLine = "Very good! You gained the Discoverer outfit." },
	fifteen = { count = 15, storage = DiscovererOutfits.Addon1Claimed, grant = function(player)
		player:addOutfitAddon(MeasuringTibia.OUTFIT_LOOKTYPE_MALE, 1)
		player:addOutfitAddon(MeasuringTibia.OUTFIT_LOOKTYPE_FEMALE, 1)
	end, replyLine = "Very good! You gained the first addon to the Discoverer outfit." },
	twenty = { count = 20, storage = DiscovererOutfits.Addon2Claimed, grant = function(player)
		player:addOutfitAddon(MeasuringTibia.OUTFIT_LOOKTYPE_MALE, 2)
		player:addOutfitAddon(MeasuringTibia.OUTFIT_LOOKTYPE_FEMALE, 2)
		if not player:hasAchievement("Measuring the World") then
			player:addAchievement("Measuring the World")
		end
	end, replyLine = "Very good! You gained the second addon to the Discoverer outfit" },
}

local function creatureSayCallback(npc, creature, type, message)
	local player = Player(creature)
	local playerId = player:getId()

	if not npcHandler:checkInteraction(npc, creature) then
		return false
	end

	-- Guarded against topic 1 (mid city-selection in the old travel flow, below): without this, a
	-- player who typed "outfit"/"discovering" out of curiosity while picking a destination city
	-- would silently overwrite that in-progress topic, abandoning the travel flow with no message
	-- explaining why their next reply (a city name) stopped being recognized.
	if npcHandler:getTopic(playerId) == 1 then
		-- fall through to the travel-service handling below
	elseif MsgContains(message, "discovering") then
		npcHandler:say({
			"We are currently working on a huge and very ambitious project: We try to chart the world of Tibia! I know what you might think: Are there so many undiscovered places on this world? And the answer is: Yes! ...",
			"There are many secret, hidden or hardly accessible places and sites. We want to create a detailed and accurate map of our world - and we are searching for assistance concerning this project. ...",
			"So, if you want to discover Tibia's secrets, go out and discover our world, step by step and area by area. If you contribute to this project to a certain extent, you can gain the right to wear our Discoverer outfit.",
		}, npc, creature)
		return true
	elseif MsgContains(message, "outfit") then
		npcHandler:say("Are you interested in wearing our Discoverer outfit?", npc, creature)
		npcHandler:setTopic(playerId, DISCOVERING_TOPIC_OUTFIT_ASKED)
		return true
	elseif MsgContains(message, "yes") and npcHandler:getTopic(playerId) == DISCOVERING_TOPIC_OUTFIT_ASKED then
		npcHandler:say({
			"I provide the outfit as well as two addons. For the outfit you need to fully discover ten areas of Tibia, for the first addon you have to discover fifteen. For the second addon you need to discover twenty areas. ...",
			"Are you interested in dressing like a real discoverer?",
		}, npc, creature)
		npcHandler:setTopic(playerId, DISCOVERING_TOPIC_ADDON_INFO_GIVEN)
		return true
	elseif MsgContains(message, "yes") and npcHandler:getTopic(playerId) == DISCOVERING_TOPIC_ADDON_INFO_GIVEN then
		npcHandler:say("How many areas do you have fully discovered yet: ten, fifteen or twenty?", npc, creature)
		npcHandler:setTopic(playerId, DISCOVERING_TOPIC_COUNT_ASKED)
		return true
	elseif npcHandler:getTopic(playerId) == DISCOVERING_TOPIC_COUNT_ASKED then
		local tier = tierByWord[message:lower()]
		if not tier then
			npcHandler:say("I don't understand, please say ten, fifteen or twenty.", npc, creature)
			return true
		end
		if player:getStorageValue(tier.storage) >= 1 then
			npcHandler:say("You already claimed that reward.", npc, creature)
			npcHandler:resetNpc(npc, creature)
			return true
		end
		local completed = player:getStorageValue(Storage.Quest.U11_80.MeasuringTibia.CompletedAreaCount)
		if completed < tier.count then
			npcHandler:say(("You have only fully discovered %d areas so far. Come back once you have discovered %d."):format(math.max(completed, 0), tier.count), npc, creature)
			npcHandler:resetNpc(npc, creature)
			return true
		end
		tier.grant(player)
		player:setStorageValue(tier.storage, 1)
		npcHandler:say(tier.replyLine, npc, creature)
		npcHandler:resetNpc(npc, creature)
		return true
	end

	if npcHandler:getTopic(playerId) == 0 then
		if MsgContains(message, "yes") then
			npcHandler:say("Fine. You have " .. -player:getStorageValue(Storage.Quest.U9_80.AdventurersGuild.CharosTrav) + 7 .. " \z
			attunements left. What is the new city of your choice? Thais, Carlin, Ab'Dendriel, Kazordoon, Venore, \z
			Ankrahmun, Edron, Darashia, Liberty Bay or Port Hope?", npc, creature)
			npcHandler:setTopic(playerId, 1)
		end
	elseif npcHandler:getTopic(playerId) == 1 then
		local cityTable = config.towns[message:lower()]
		if cityTable then
			player:setStorageValue(Storage.Quest.U9_80.AdventurersGuild.CharosTrav, player:getStorageValue(Storage.Quest.U9_80.AdventurersGuild.CharosTrav) + 1)
			player:setStorageValue(Storage.Quest.U9_80.AdventurersGuild.Stone, cityTable)
			npcHandler:say("Goodbye traveler!", npc, creature)
		else
			npcHandler:say("Sorry, I don't know about this place.", npc, creature)
		end
	end
	return true
end

npcHandler:setCallback(CALLBACK_SET_INTERACTION, onAddFocus)
npcHandler:setCallback(CALLBACK_REMOVE_INTERACTION, onReleaseFocus)
npcHandler:setCallback(CALLBACK_GREET, greetCallback)
npcHandler:setCallback(CALLBACK_MESSAGE_DEFAULT, creatureSayCallback)
npcHandler:addModule(FocusModule:new(), npcConfig.name, true, true, true)

-- npcType registering the npcConfig table
npcType:register(npcConfig)
