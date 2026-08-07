local internalNpcName = "Alyxo"
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

	-- CONFIRMED BUG (found in review): Twelve.Boss is Boards' own progress storage, but the only thing
	-- that ever initialised it to 1 was npc/kallimae.lua at the *end* of Midnight Rituals - so Boards
	-- was chained behind Midnight Rituals, contradicting the source's "after Fafnar's Wrath the later
	-- missions may be performed in any order". Seeding it here from the canonical Fafnar's Wrath
	-- completion marker (Sixth.Favor >= 11, set by the Empress) makes Boards independently available
	-- without touching any downstream stage: 2, 3 and 4 and every Thirteen.* subtask are unchanged.
	-- Kallimae's own write becomes redundant rather than wrong, so no migration is needed - players
	-- already at Twelve.Boss >= 1 are untouched by this seed.
	if player:getStorageValue(Storage.Quest.U12_20.KilmareshQuest.Sixth.Favor) >= 11 and player:getStorageValue(Storage.Quest.U12_20.KilmareshQuest.Twelve.Boss) < 1 then
		player:setStorageValue(Storage.Quest.U12_20.KilmareshQuest.Twelve.Boss, 1)
	end

	-- Legacy migration: before this PR, Boards' completion was recorded only as Fourteen.Remains = 1
	-- (that storage also doubled as Revenge's chain). Twelve.Boss is now Boards' questline with 5 as
	-- its completed value, so a player who finished Boards under the old flow would otherwise show as
	-- incomplete in the new questlog forever. Promote them once. Deliberately does NOT re-grant item
	-- 31574 and does NOT touch any Thirteen.* subtask.
	if player:getStorageValue(Storage.Quest.U12_20.KilmareshQuest.Fourteen.Remains) >= 1 and player:getStorageValue(Storage.Quest.U12_20.KilmareshQuest.Twelve.Boss) < 5 then
		player:setStorageValue(Storage.Quest.U12_20.KilmareshQuest.Twelve.Boss, 5)
	end

	-- Parent questlog visibility anchor for legacy players: KilmareshQuest.Questline was unused before
	-- this PR, so an existing player with real Kilmaresh progress would have no questlog at all until
	-- they happened to re-trigger an entry point. Any evidence of genuine progress exposes it.
	if player:getStorageValue(Storage.Quest.U12_20.KilmareshQuest.Questline) < 1 and player:getStorageValue(Storage.Quest.U12_20.KilmareshQuest.First.Title) >= 1 then
		player:setStorageValue(Storage.Quest.U12_20.KilmareshQuest.Questline, 1)
	end

	-- Mission 3 Steal The Ambassador Ring
	if MsgContains(message, "mission") then
		if player:getStorageValue(Storage.Quest.U12_20.KilmareshQuest.Twelve.Boss) == 1 then
			npcHandler:setTopic(playerId, 1)
		end
		npcHandler:say({ "Could you kill 3 bosses for me?" }, npc, creature) -- needs review, this is not the speech of the global
	elseif MsgContains(message, "yes") then
		if npcHandler:getTopic(playerId) == 1 and player:getStorageValue(Storage.Quest.U12_20.KilmareshQuest.Twelve.Boss) == 1 then
			npcHandler:say({ "Come back as soon as you kill all 3 bosses." }, npc, creature) -- needs review, this is not the speech of the global
			player:setStorageValue(Storage.Quest.U12_20.KilmareshQuest.Twelve.Boss, 2)
			player:setStorageValue(Storage.Quest.U12_20.KilmareshQuest.Twelve.Bragrumol, 1)
			player:setStorageValue(Storage.Quest.U12_20.KilmareshQuest.Twelve.Mozradek, 1)
			player:setStorageValue(Storage.Quest.U12_20.KilmareshQuest.Twelve.Xogixath, 1)
			npcHandler:setTopic(playerId, 2)
		else
			npcHandler:say({ "Sorry, you do not have access." }, npc, creature)
			npcHandler:setTopic(playerId, 0)
		end
	end
	-- Mission 3 Steal The Ambassador Ring
	if MsgContains(message, "mission") and player:getStorageValue(Storage.Quest.U12_20.KilmareshQuest.Twelve.Boss) == 2 then
		if player:getStorageValue(Storage.Quest.U12_20.KilmareshQuest.Twelve.Boss) == 2 then
			npcHandler:say({ "Did you manage to face all 3 bosses?" }, npc, creature) -- needs review, this is not the speech of the global
			npcHandler:setTopic(playerId, 3)
		end
	elseif MsgContains(message, "yes") and npcHandler:getTopic(playerId) == 3 and player:getStorageValue(Storage.Quest.U12_20.KilmareshQuest.Twelve.Boss) == 2 then
		if player:getStorageValue(Storage.Quest.U12_20.KilmareshQuest.Twelve.Bragrumol) == 2 and player:getStorageValue(Storage.Quest.U12_20.KilmareshQuest.Twelve.Mozradek) == 2 and player:getStorageValue(Storage.Quest.U12_20.KilmareshQuest.Twelve.Xogixath) == 2 then
			npcHandler:say({ "I am very satisfied." }, npc, creature) -- needs review, this is not the speech of the global
			player:setStorageValue(Storage.Quest.U12_20.KilmareshQuest.Twelve.Boss, 3)
			npcHandler:setTopic(playerId, 4)
		else
			npcHandler:say({ "Sorry." }, npc, creature)
			npcHandler:setTopic(playerId, 0)
		end
	end
	if MsgContains(message, "mission") and player:getStorageValue(Storage.Quest.U12_20.KilmareshQuest.Twelve.Boss) == 3 then
		if player:getStorageValue(Storage.Quest.U12_20.KilmareshQuest.Twelve.Boss) == 3 then
			npcHandler:say({ "Could you help me with some more work?" }, npc, creature) -- needs review, this is not the speech of the global
			npcHandler:setTopic(playerId, 5)
			npcHandler:setTopic(playerId, 5)
		end
	elseif MsgContains(message, "yes") and npcHandler:getTopic(playerId) == 5 and player:getStorageValue(Storage.Quest.U12_20.KilmareshQuest.Twelve.Boss) == 3 then
		if player:getStorageValue(Storage.Quest.U12_20.KilmareshQuest.Twelve.Boss) == 3 then
			npcHandler:say({ "Kill 300 members of the Fafnar cult, help me find Ivory Lyre and help me find an animal to stone." }, npc, creature) -- needs review, this is not the speech of the global
			player:setStorageValue(Storage.Quest.U12_20.KilmareshQuest.Twelve.Boss, 4)
			-- CONFIRMED BUG (pre-existing): this baseline was 1, not 0, so the kill counter in
			-- creaturescripts_fafnar.lua (which increments from whatever this starts at) reached the
			-- ==300 threshold after only 299 real kills. Starting at 0 makes the count exact; see the
			-- matching fix in that file for the other half (an uncapped counter that could overshoot
			-- past 300 with no way back, since this "report" check is a strict equality).
			player:setStorageValue(Storage.Quest.U12_20.KilmareshQuest.Thirteen.Fafnar, 0)
			player:setStorageValue(Storage.Quest.U12_20.KilmareshQuest.Thirteen.Lyre, 1)
			player:setStorageValue(Storage.Quest.U12_20.KilmareshQuest.Thirteen.Presente, 1)
			npcHandler:setTopic(playerId, 6)
		else
			npcHandler:say({ "Sorry." }, npc, creature)
			npcHandler:setTopic(playerId, 0)
		end
	end
	if MsgContains(message, "report") and player:getStorageValue(Storage.Quest.U12_20.KilmareshQuest.Thirteen.Fafnar) == 300 then
		if player:getStorageValue(Storage.Quest.U12_20.KilmareshQuest.Thirteen.Fafnar) == 300 then
			npcHandler:say({ "Have you finished killing the 300 members of Fafnar's cult?" }, npc, creature) -- needs review, this is not the speech of the global
			npcHandler:setTopic(playerId, 7)
		end
	elseif MsgContains(message, "yes") and npcHandler:getTopic(playerId) == 7 and player:getStorageValue(Storage.Quest.U12_20.KilmareshQuest.Thirteen.Fafnar) == 300 then
		if player:getStorageValue(Storage.Quest.U12_20.KilmareshQuest.Thirteen.Fafnar) == 300 then
			npcHandler:say({ "Thanks. You killed the 300 members of the Fafnar cult." }, npc, creature) -- needs review, this is not the speech of the global
			player:setStorageValue(Storage.Quest.U12_20.KilmareshQuest.Thirteen.Fafnar, 301)
			npcHandler:setTopic(playerId, 8)
		else
			npcHandler:say({ "Sorry." }, npc, creature)
			npcHandler:setTopic(playerId, 0)
		end
	end
	if MsgContains(message, "report") and player:getStorageValue(Storage.Quest.U12_20.KilmareshQuest.Thirteen.Lyre) == 3 then
		if player:getStorageValue(Storage.Quest.U12_20.KilmareshQuest.Thirteen.Lyre) == 3 then
			npcHandler:say({ "Did you manage to find Lyre?" }, npc, creature) -- needs review, this is not the speech of the global
			npcHandler:setTopic(playerId, 9)
		end
	elseif MsgContains(message, "yes") and npcHandler:getTopic(playerId) == 9 and player:getStorageValue(Storage.Quest.U12_20.KilmareshQuest.Thirteen.Lyre) == 3 then
		if player:getStorageValue(Storage.Quest.U12_20.KilmareshQuest.Thirteen.Lyre) == 3 and player:getItemById(31447, 1) then
			player:removeItem(31447, 1)
			npcHandler:say({ "Thanks. I was looking for Lyre for a long time." }, npc, creature) -- needs review, this is not the speech of the global
			player:setStorageValue(Storage.Quest.U12_20.KilmareshQuest.Thirteen.Lyre, 4)
		else
			npcHandler:say({ "Sorry." }, npc, creature)
			npcHandler:setTopic(playerId, 0)
		end
	end
	if MsgContains(message, "report") and player:getStorageValue(Storage.Quest.U12_20.KilmareshQuest.Thirteen.Presente) == 2 then
		if player:getStorageValue(Storage.Quest.U12_20.KilmareshQuest.Thirteen.Presente) == 2 then
			npcHandler:say({ "Did you manage to find Small Tortoise?" }, npc, creature) -- needs review, this is not the speech of the global
			npcHandler:setTopic(playerId, 11)
		end
	elseif MsgContains(message, "yes") and npcHandler:getTopic(playerId) == 11 and player:getStorageValue(Storage.Quest.U12_20.KilmareshQuest.Thirteen.Presente) == 2 then
		if player:getStorageValue(Storage.Quest.U12_20.KilmareshQuest.Thirteen.Presente) == 2 and player:getItemById(31445, 1) then
			player:removeItem(31445, 1)
			npcHandler:say({ "Thanks. I was looking for Small Tortoise." }, npc, creature) -- needs review, this is not the speech of the global
			player:setStorageValue(Storage.Quest.U12_20.KilmareshQuest.Thirteen.Presente, 3)
			npcHandler:setTopic(playerId, 12)
		else
			npcHandler:say({ "Sorry." }, npc, creature)
			npcHandler:setTopic(playerId, 0)
		end
	end
	-- CONFIRMED BUG (pre-existing): this "petrify a keepsake" side-branch had no gate beyond simply
	-- holding item 31445 - the exact same item the main "report" turn-in above needs. A player who
	-- said "small tortoise" before ever reporting would have their only copy silently converted to
	-- item 31446 with Thirteen.Presente never advancing past 1, permanently soft-locking the
	-- required report step (which checks Presente==2). Per the source, Alyxo only offers to petrify a
	-- SECOND tortoise ("if you find another one, I can petrify it for you, too") - i.e. after the
	-- first one has already been reported. Gating on Presente>=3 (report already completed) prevents
	-- the softlock entirely.
	if MsgContains(message, "small tortoise") then
		if player:getStorageValue(Storage.Quest.U12_20.KilmareshQuest.Thirteen.Presente) >= 3 and player:getItemById(31445, 1) then
			npcHandler:say({ "Do you want me to stone a small tortoise?" }, npc, creature) -- needs review, this is not the speech of the global
			npcHandler:setTopic(playerId, 15)
		end
	elseif MsgContains(message, "yes") and npcHandler:getTopic(playerId) == 15 then
		if player:getStorageValue(Storage.Quest.U12_20.KilmareshQuest.Thirteen.Presente) >= 3 and player:getItemById(31445, 1) then
			player:removeItem(31445, 1)
			player:addItem(31446, 1)
			-- CONFIRMED BUG (pre-existing, my own earlier fix in this same pass had it wrong too):
			-- "Sculptor Apprentice"'s real registry description (register_achievements.lua) is "helping
			-- a medusa to find proper objects and even watching her using her petrifying gaze" - this
			-- is explicitly about THIS moment (Alyxo, a medusa, petrifying a tortoise), not the Regalia
			-- of Suon combination (npc/yonan.lua) I mistakenly moved it to earlier in this same pass,
			-- and not the unrelated "3 jobs complete" milestone it was originally (also wrongly)
			-- attached to. Corrected here, at the one place that actually matches the description.
			if not player:hasAchievement("Sculptor Apprentice") then
				player:addAchievement("Sculptor Apprentice")
			end
			npcHandler:say({ "Here's your Small Petrified Tortoise." }, npc, creature) -- needs review, this is not the speech of the global
			npcHandler:setTopic(playerId, 16)
		else
			npcHandler:say({ "Sorry." }, npc, creature)
			npcHandler:setTopic(playerId, 0)
		end
	end
	-- CONFIRMED BLOCKER (found via review - reachability check, not just claim comparison): this
	-- branch only ever checked Thirteen.Fafnar == 301 (the 300-cultist report), completely ignoring
	-- Thirteen.Lyre and Thirteen.Presente. Alyxo explicitly asked for THREE favors ("Did you finish
	-- the 3 jobs I gave you?"), but a player could report and claim the full reward - including
	-- unlocking The Revenge of the Ogres via Fourteen.Remains - having only ever killed 300 cultists,
	-- without ever recovering the lyre or reporting the animal present. Now requires all three
	-- sub-tasks' own completion values (Lyre reaches 4 only after being turned in at topic 9; Presente
	-- reaches 3 only after being turned in at topic 11 - see those branches above).
	if MsgContains(message, "mission") and player:getStorageValue(Storage.Quest.U12_20.KilmareshQuest.Thirteen.Fafnar) == 301 and player:getStorageValue(Storage.Quest.U12_20.KilmareshQuest.Thirteen.Lyre) == 4 and player:getStorageValue(Storage.Quest.U12_20.KilmareshQuest.Thirteen.Presente) == 3 then
		npcHandler:say({ "Did you finish the 3 jobs I gave you?" }, npc, creature) -- needs review, this is not the speech of the global
		npcHandler:setTopic(playerId, 13)
	elseif MsgContains(message, "yes") and npcHandler:getTopic(playerId) == 13 then
		if player:getStorageValue(Storage.Quest.U12_20.KilmareshQuest.Thirteen.Fafnar) == 301 and player:getStorageValue(Storage.Quest.U12_20.KilmareshQuest.Thirteen.Lyre) == 4 and player:getStorageValue(Storage.Quest.U12_20.KilmareshQuest.Thirteen.Presente) == 3 and player:getStorageValue(Storage.Quest.U12_20.KilmareshQuest.Fourteen.Remains) < 1 then
			-- "Sculptor Apprentice" is granted at the tortoise-petrify branch above (topic 15/16), not
			-- here - see the comment there for why (its registered description is about Alyxo, a
			-- medusa, petrifying an animal, not about finishing these three favors).
			-- Transactional: Fourteen.Remains 1 is the one-time Boards completion marker, so the Regalia
			-- part must be delivered before it advances.
			if not player:addItem(31574, 1, false) then
				npcHandler:say({ "You cannot carry your reward right now. Return when you have room for it." }, npc, creature)
				npcHandler:setTopic(playerId, 0)
				return true
			end

			npcHandler:say({ "Congratulations, you have completed the 3 jobs I gave you." }, npc, creature) -- needs review, this is not the speech of the global
			-- Twelve.Boss 5 is Boards' own completion state, used by the questlog catalog. Fourteen.Remains
			-- is kept as the pre-existing one-time reward guard for backward compatibility.
			player:setStorageValue(Storage.Quest.U12_20.KilmareshQuest.Twelve.Boss, 5)
			player:setStorageValue(Storage.Quest.U12_20.KilmareshQuest.Fourteen.Remains, 1)
			npcHandler:setTopic(playerId, 14)
		else
			npcHandler:say({ "Sorry." }, npc, creature)
			npcHandler:setTopic(playerId, 0)
		end
	end
	return true
end

npcHandler:setMessage(MESSAGE_WALKAWAY, "Well, bye then.")

npcHandler:setCallback(CALLBACK_GREET, greetCallback)
npcHandler:setCallback(CALLBACK_MESSAGE_DEFAULT, creatureSayCallback)

npcHandler:addModule(FocusModule:new(), npcConfig.name, true, true, true)

-- npcType registering the npcConfig table
npcType:register(npcConfig)
