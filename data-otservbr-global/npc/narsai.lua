local internalNpcName = "Narsai"
local npcType = Game.createNpcType(internalNpcName)
local npcConfig = {}

npcConfig.name = internalNpcName
npcConfig.description = internalNpcName

npcConfig.health = 100
npcConfig.maxHealth = npcConfig.health
npcConfig.walkInterval = 2000
npcConfig.walkRadius = 2

npcConfig.outfit = {
	lookType = 1199,
	lookHead = 114,
	lookBody = 74,
	lookLegs = 10,
	lookFeet = 79,
	lookAddons = 1,
}

npcConfig.flags = {
	floorchange = false,
	profession = "trader",
}
npcConfig.speechBubble = SPEECHBUBBLE_TRADE

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

	-- CONFIRMED BUG (found in review): this greetCallback branched on
	-- KilmareshQuest.First.Access / .JamesfrancisTask / .Mission, none of which exist - `First`
	-- defines only `Title` (lib/core/storages.lua). They are copy-pasted from the unrelated
	-- CultsOfTibia.Minotaurs block. Every branch resolved against a nil key and all three set the same
	-- greeting anyway, but they also pre-seeded a conversation topic purely by greeting - and topic 1
	-- is consumed by live "yes" branches in this file, so a bare "yes" straight after hello could
	-- advance a mission without ever being offered it. Replaced with the unconditional greeting the
	-- branches all produced, and no topic seeding.
	npcHandler:setMessage(MESSAGE_GREET, "How could I help you?") -- It needs to be revised, it's not the same as the global
	return true
end

local function creatureSayCallback(npc, creature, type, message)
	local player = Player(creature)
	local playerId = player:getId()

	if not npcHandler:checkInteraction(npc, creature) then
		return false
	end

	-- Legacy repair for players stranded by the missing Eighth.* initialisation (see
	-- lib/quests/kilmaresh.lua). Idempotent, grants nothing, never lowers an existing stage.
	KilmareshQuest.migrateMidnightRituals(player)

	if MsgContains(message, "mission") and player:getStorageValue(Storage.Quest.U12_20.KilmareshQuest.Eighth.Narsai) == 1 then
		if player:getStorageValue(Storage.Quest.U12_20.KilmareshQuest.Eighth.Narsai) == 1 then
			npcHandler:say({ "Could you help me do a ritual?" }, npc, creature) -- It needs to be revised, it's not the same as the global
			npcHandler:setTopic(playerId, 1)
			npcHandler:setTopic(playerId, 1)
		end
	elseif MsgContains(message, "yes") and npcHandler:getTopic(playerId) == 1 and player:getStorageValue(Storage.Quest.U12_20.KilmareshQuest.Eighth.Narsai) == 1 then
		if player:getStorageValue(Storage.Quest.U12_20.KilmareshQuest.Eighth.Narsai) == 1 then
			player:addItem(31714, 1)
			npcHandler:say({ "Here is the list of ingredients that are missing to complete the ritual. " }, npc, creature) -- It needs to be revised, it's not the same as the global
			player:setStorageValue(Storage.Quest.U12_20.KilmareshQuest.Eighth.Narsai, 2)
			npcHandler:setTopic(playerId, 2)
			npcHandler:setTopic(playerId, 2)
		else
			npcHandler:say({ "Sorry." }, npc, creature) -- It needs to be revised, it's not the same as the global
		end
	end
	if MsgContains(message, "mission") and player:getStorageValue(Storage.Quest.U12_20.KilmareshQuest.Eighth.Narsai) == 2 then
		if player:getStorageValue(Storage.Quest.U12_20.KilmareshQuest.Eighth.Narsai) == 2 then
			npcHandler:say({ "Did you bring all the materials I informed you about?" }, npc, creature) -- It needs to be revised, it's not the same as the global
			npcHandler:setTopic(playerId, 3)
			npcHandler:setTopic(playerId, 3)
		end
	elseif MsgContains(message, "yes") and npcHandler:getTopic(playerId) == 3 and player:getStorageValue(Storage.Quest.U12_20.KilmareshQuest.Eighth.Narsai) == 2 then
		if player:getStorageValue(Storage.Quest.U12_20.KilmareshQuest.Eighth.Narsai) == 2 and player:getItemById(31335, 10) and player:getItemById(10279, 2) and player:getItemById(31332, 5) then
			player:removeItem(31335, 10)
			player:removeItem(10279, 2)
			player:removeItem(31332, 5)
			npcHandler:say({ "Thank you this stage of the ritual is complete." }, npc, creature) -- It needs to be revised, it's not the same as the global
			player:setStorageValue(Storage.Quest.U12_20.KilmareshQuest.Eighth.Narsai, 3)
			npcHandler:setTopic(playerId, 4)
			npcHandler:setTopic(playerId, 4)
		else
			npcHandler:say({ "Sorry." }, npc, creature) -- It needs to be revised, it's not the same as the global
		end
	end

	-- "Aspiring Oracle" (added 12.70) - entirely absent before this pass. Uses fresh topic numbers
	-- (30-32) to avoid colliding with the "Midnight Rituals" dialogue above (topics 1-4), since both
	-- missions share this same Narsai NPC file.
	if MsgContains(message, "eye of suon") and player:getStorageValue(Storage.Quest.U12_20.KilmareshQuest.AspiringOracle.Questline) == 1 then
		npcHandler:say({
			"The young woman is right. There is in fact an artefact that might bestow the power of true seeing on a mortal human being. It is called the Eye of Suon. ...",
			"The legends tell that it consists of two parts: a precious red gem an a golden frame shaped like an eye. But the two parts were separated long ago and are now lost. ...",
			"My second sight tells me that the frame is still here in Kilmaresh. But it is far away ... in the Salt Caves underneath the Green Belt. Be careful, they are inhabited by Bashmu. ...",
			"Although some of them are benevolent creatures they despise it if someone enters their lairs. The gem on the other hand is quite far away. ...",
			"You can find it in the former part of Kilmaresh, now known as Krailos. You can take a ship to get there, but there is also a secret tunnel in the Ruins of Nuur. ...",
			"It still connects the ruins to the lost part of the Old Empire. A seeled door prevents theogres from coming through. ...",
			"But you can open it by drawing a sun symbol on the door with your finger, right above the door knob.",
			"You will find the gem in the ruins of the Old Empire underneath Krailos. ...",
			"Find the two parts and combine them to restore the Eye of Suon. The return to me and I will tell you more.",
		}, npc, creature)
		player:setStorageValue(Storage.Quest.U12_20.KilmareshQuest.AspiringOracle.Questline, 2)
		npcHandler:setTopic(playerId, 0)
	elseif MsgContains(message, "eye of suon") and player:getStorageValue(Storage.Quest.U12_20.KilmareshQuest.AspiringOracle.Questline) == 2 then
		if player:getItemById(36708, 1) then
			npcHandler:say({
				"You really found the parts and restored the Eye of Suon! I'm impressed! But the artefact won't grant the second sight yet. It has to be activated by a special blessing. ...",
				"There have been several Anuma, all of them lamassu und sphinxes, who were patrons of seers and oracles. Each of them has a statue, some here in Issavi, some elsewhere in Kilmaresh. ...",
				"Take this wine and sacrifice it at each of the statues by pouring it out in front of them. Here is a scroll that lists the names of the holy Anuma whose statues you have to find. ...",
				"If you bring all sacrifices the Eye of Suon will awake.",
			}, npc, creature)
			-- Transactional, with the same tool/document distinction used in npc/yonan.lua:
			--   * wine (item 2) is MECHANICALLY REQUIRED - actions_anuma_statues.lua consumes one per
			--     statue and refuses to bless without it, and Questline 2 -> 3 is one-way, so
			--     advancing without it would strand the player.
			--   * the scroll (31709) is INFORMATIONAL (it only lists the statue names), so its
			--     delivery is deliberately not treated as blocking.
			if not player:addItem(2, 7) then
				npcHandler:say("You cannot carry the wine right now. Return when you have room for it.", npc, creature)
				npcHandler:setTopic(playerId, 0)
				return true
			end

			if not player:getItemById(31709, 1) then
				player:addItem(31709, 1) -- scroll of Anuma names (informational, non-blocking)
			end

			player:setStorageValue(Storage.Quest.U12_20.KilmareshQuest.AspiringOracle.Questline, 3)
		else
			npcHandler:say("You still need to find and combine both parts of the Eye of Suon.", npc, creature)
		end
		npcHandler:setTopic(playerId, 0)
	elseif MsgContains(message, "eye of suon") and player:getStorageValue(Storage.Quest.U12_20.KilmareshQuest.AspiringOracle.Questline) == 3 then
		local blessed = player:getStorageValue(Storage.Quest.U12_20.KilmareshQuest.AspiringOracle.AnumaBlessed)
		if blessed >= 127 then
			npcHandler:say("You offered all the sacrifices. Now you can tell Taya about the good news and bring her the Eye of Suon.", npc, creature)
			player:setStorageValue(Storage.Quest.U12_20.KilmareshQuest.AspiringOracle.Questline, 5)
		else
			npcHandler:say("You still have to offer a sacrifice at every Anuma statue on the scroll I gave you.", npc, creature)
		end
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
