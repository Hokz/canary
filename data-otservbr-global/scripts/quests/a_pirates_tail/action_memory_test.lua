-- Rascacoon Trust Points / Memory Test - memorize a shell pattern shown briefly at the center
-- tile, then step onto the matching one of 8 candidate tiles. 10 correct in a row completes the
-- task (5 trust points each, 50 total); a wrong answer ejects the player, keeping points earned
-- so far. Cooldown 2 hours. Multiple players may attempt independently at the same time.
--
-- ACCEPTABLE_GLOBAL_LIKE simplification, disclosed: the reference shows a literal shell-pattern
-- mosaic; without exact art assets this represents each of the 8 patterns as a distinct magic
-- effect at the center tile plus a text message naming it, rather than a rendered mosaic. The
-- underlying memorize-then-match mechanic is otherwise unchanged.
--
-- MAP SETUP REQUIRED: MEMORY_ROOM below needs real positions - see the Map Setup Contract.
local MEMORY_ROOM = {
	startAid = 45930, -- the sparkling area between rocks that begins a round
	center = nil, -- Position: where the pattern is displayed
	exit = nil, -- Position: where a wrong-answer/completed player is sent
	answers = {}, -- list of 8 Position: the candidate tiles, index = pattern id 1-8
}

local PATTERN_EFFECTS = {
	CONST_ME_MAGIC_BLUE, CONST_ME_MAGIC_RED, CONST_ME_MAGIC_GREEN, CONST_ME_HOLYAREA,
	CONST_ME_ICEAREA, CONST_ME_FIREAREA, CONST_ME_POISONAREA, CONST_ME_ENERGYAREA,
}

local COOLDOWN = 2 * 3600
local PATTERN_DISPLAY_TIME = 5 * 1000
local TARGET_CORRECT = 10
local POINTS_PER_CORRECT = 5

local APiratesTail = Storage.Quest.U12_60.APiratesTail

local function startRound(player)
	if #MEMORY_ROOM.answers < 8 then
		return
	end
	local pattern = math.random(1, 8)
	player:setStorageValue(APiratesTail.Mission03.MemoryTestPattern, pattern)
	player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "Memorize the pattern!")
	MEMORY_ROOM.center:sendMagicEffect(PATTERN_EFFECTS[pattern])
	addEvent(function()
		player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "The pattern fades. Step onto the matching tile!")
	end, PATTERN_DISPLAY_TIME)
end

local startMemoryTest = MoveEvent()
function startMemoryTest.onStepIn(creature, item, position, fromPosition)
	local player = creature:getPlayer()
	if not player then
		return true
	end
	if player:getStorageValue(APiratesTail.Mission03.MemoryTestCooldown) > os.time() then
		player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "You need to wait before attempting the Memory Test again.")
		return true
	end
	if not MEMORY_ROOM.center then
		player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "The memory test isn't ready yet.")
		return true
	end
	player:setStorageValue(APiratesTail.Mission03.MemoryTestCorrect, 0)
	startRound(player)
	return true
end
startMemoryTest:aid(MEMORY_ROOM.startAid)
startMemoryTest:register()

local answerTile = MoveEvent()
function answerTile.onStepIn(creature, item, position, fromPosition)
	local player = creature:getPlayer()
	if not player then
		return true
	end
	local pattern = player:getStorageValue(APiratesTail.Mission03.MemoryTestPattern)
	if pattern < 1 then
		return true -- not currently in a round
	end

	local answered = item:getActionId() - MEMORY_ROOM.startAid -- see aid registration below
	if answered ~= pattern then
		local correct = math.max(player:getStorageValue(APiratesTail.Mission03.MemoryTestCorrect), 0)
		local earned = correct * POINTS_PER_CORRECT
		if earned > 0 then
			local trust = math.max(player:getStorageValue(APiratesTail.Mission03.TrustPoints), 0)
			player:setStorageValue(APiratesTail.Mission03.TrustPoints, trust + earned)
		end
		player:setStorageValue(APiratesTail.Mission03.MemoryTestPattern, -1)
		player:setStorageValue(APiratesTail.Mission03.MemoryTestCooldown, os.time() + COOLDOWN)
		player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "Wrong pattern! You are ejected, having earned " .. earned .. " trust points.")
		if MEMORY_ROOM.exit then
			player:teleportTo(MEMORY_ROOM.exit)
		end
		return true
	end

	local correct = math.max(player:getStorageValue(APiratesTail.Mission03.MemoryTestCorrect), 0) + 1
	player:setStorageValue(APiratesTail.Mission03.MemoryTestCorrect, correct)
	if correct >= TARGET_CORRECT then
		local trust = math.max(player:getStorageValue(APiratesTail.Mission03.TrustPoints), 0)
		player:setStorageValue(APiratesTail.Mission03.TrustPoints, trust + TARGET_CORRECT * POINTS_PER_CORRECT)
		player:setStorageValue(APiratesTail.Mission03.MemoryTestPattern, -1)
		player:setStorageValue(APiratesTail.Mission03.MemoryTestCooldown, os.time() + COOLDOWN)
		player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "Correct! You completed the Memory Test and earned 50 trust points.")
		if MEMORY_ROOM.exit then
			player:teleportTo(MEMORY_ROOM.exit)
		end
	else
		player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "Correct! " .. correct .. "/" .. TARGET_CORRECT .. ".")
		startRound(player)
	end
	return true
end

for index, position in ipairs(MEMORY_ROOM.answers) do
	answerTile:aid(MEMORY_ROOM.startAid + index)
	answerTile:position(position)
end
answerTile:register()
