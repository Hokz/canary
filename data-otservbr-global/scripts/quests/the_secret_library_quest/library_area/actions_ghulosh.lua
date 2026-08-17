-- ================================================================
-- GHULOSH RUN OWNERSHIP (Secret Library repair v2, section 17)
-- ================================================================
-- Confirmed pre-existing state: the Ghulosh -> Deathgaze stage transform was entirely unreachable
-- (Game.getStorageValue defaults to -1, which never matched the stage table's 1/2/3 values, so the
-- only writer of that storage never ran); the Deathgaze form had no monster.events at all so even a
-- forced transform could never re-trigger; there was no slime-interaction-returns-Ghulosh code, no
-- persistent-Deathgaze/reflected-damage mechanic, and no low-health-return-to-original-form code
-- anywhere. This file builds the whole state machine using ONLY the monster types already defined in
-- this repository (Ghulosh, Ghulosh' Deathgaze, The Book of Death, Concentrated Death) - no new
-- monster/item asset is invented.
--
-- Uses setType() (matching the accepted King Zelos Rewar/Rewar-Inv precedent) rather than a
-- remove-and-recreate swap for the Ghulosh<->Deathgaze transform: the underlying creature id/ownership
-- never changes, which sidesteps the whole "verify replacement before removing the old one" class of
-- risk entirely for this specific transform (there is no separate creation call that can fail).
GhuloshRun = {
	token = 0,
	active = false,
	bossId = nil, -- the one creature id this run owns - constant across every Ghulosh<->Deathgaze setType
	participants = {},
	phase = "normal", -- "normal" | "deathgaze_cycle" | "deathgaze_persistent" | "normal_final"
	stageIndex = 0, -- how many of the 3 health-threshold stages have been consumed
	bookId = nil,
	slimeId = nil,
	events = {},
}

function GhuloshRunIsCurrent(token)
	return token ~= nil and token > 0 and GhuloshRun.active and GhuloshRun.token == token
end

function GhuloshRunCurrentToken()
	if GhuloshRun.active then
		return GhuloshRun.token
	end
	return nil
end

function GhuloshRunOwnsBoss(creature)
	return creature ~= nil and GhuloshRun.active and GhuloshRun.bossId == creature:getId()
end

function GhuloshRunOwnsBook(creature)
	return creature ~= nil and GhuloshRun.active and GhuloshRun.bookId == creature:getId()
end

function GhuloshRunOwnsSlime(creature)
	return creature ~= nil and GhuloshRun.active and GhuloshRun.slimeId == creature:getId()
end

function GhuloshRunIsParticipant(token, playerId)
	return GhuloshRunIsCurrent(token) and GhuloshRun.participants[playerId] == true
end

function GhuloshRunTrackEvent(token, eventId)
	if GhuloshRunIsCurrent(token) and eventId then
		GhuloshRun.events[eventId] = true
	end
end

local EXIT_POSITION = Position(32660, 32713, 13)
local BOSS_POSITION = Position(32756, 32720, 10)
local BOOK_POSITION = Position(32756, 32718, 10)

function GhuloshRunTerminate(token, kind, reason)
	if not GhuloshRunIsCurrent(token) then
		return
	end
	logger.info("SecretLibrary/Ghulosh: run {} terminated ({}) - {}", token, kind, reason or "")

	GhuloshRun.active = false
	for eventId in pairs(GhuloshRun.events) do
		stopEvent(eventId)
	end

	if kind == "technical_abort" then
		for playerId in pairs(GhuloshRun.participants) do
			local player = Player(playerId)
			if player then
				player:setBossCooldown("ghulosh", 0)
			end
		end
	end

	if kind ~= "success" then
		local book = Creature(GhuloshRun.bookId)
		if book then
			book:remove()
		end
		local slime = Creature(GhuloshRun.slimeId)
		if slime then
			slime:remove()
		end
		local boss = Creature(GhuloshRun.bossId)
		if boss then
			boss:remove()
		end

		local bossLever = BossLever["ghulosh"]
		if bossLever and bossLever.bossAlive then
			bossLever.bossAlive = false
			if bossLever.emptyRoomEvent then
				stopEvent(bossLever.emptyRoomEvent)
				bossLever.emptyRoomEvent = nil
			end
			if bossLever.timeoutEvent then
				stopEvent(bossLever.timeoutEvent)
				bossLever.timeoutEvent = nil
			end
			local zone = bossLever:getZone()
			zone:refresh()
			zone:removePlayers()
			zone:cleanRoom()
		end
	end

	GhuloshRun.bossId = nil
	GhuloshRun.participants = {}
	GhuloshRun.phase = "normal"
	GhuloshRun.stageIndex = 0
	GhuloshRun.bookId = nil
	GhuloshRun.slimeId = nil
	GhuloshRun.events = {}
end

local function watchEmptyRoom(token)
	if not GhuloshRunIsCurrent(token) then
		return
	end
	local zone = Zone("boss." .. toKey("ghulosh"))
	if zone and zone:countPlayers() == 0 then
		GhuloshRunTerminate(token, "normal_timeout", "room emptied before the encounter concluded")
		return
	end
	GhuloshRunTrackEvent(token, addEvent(watchEmptyRoom, 20 * 1000, token))
end

-- ================================================================
-- FORM STATE MACHINE (Secret Library repair v2, section 17)
-- ================================================================
-- CUSTOM_GLOBAL_LIKE_PENDING_EXACT_REFERENCE: the owner reference states "Deathgaze must interact/hit
-- the slime to return Ghulosh to vulnerable form" without giving the exact trigger mechanics. This
-- pass uses the slime's own death (by any legitimate means) as that trigger - matching the separately
-- and explicitly stated "if slime dies, Book of Death returns" behavior - rather than inventing a
-- scripted Deathgaze-attacks-slime AI behavior with no comparable precedent anywhere in this codebase.
local STAGES = { 75, 50, 25 } -- health percentage thresholds
-- CUSTOM_GLOBAL_LIKE_PENDING_EXACT_VALUE: the exact "low health" percentage at which persistent
-- Deathgaze returns to original form permanently is not given by the owner reference.
local PERSISTENT_RETURN_HEALTH_PERCENT = 10

local function attemptSpawnBook(token, retriesLeft)
	retriesLeft = retriesLeft or 3
	if not GhuloshRunIsCurrent(token) then
		return
	end
	if Creature(GhuloshRun.bookId) then
		return
	end
	local book = Game.createMonster("The Book of Death", BOOK_POSITION, false, true)
	if book then
		GhuloshRun.bookId = book:getId()
		return
	end
	logger.error("SecretLibrary/Ghulosh: The Book of Death failed to spawn (retries left: {})", retriesLeft)
	if retriesLeft > 0 then
		GhuloshRunTrackEvent(token, addEvent(attemptSpawnBook, 1000, token, retriesLeft - 1))
	else
		GhuloshRunTerminate(token, "technical_abort", "The Book of Death failed to spawn after bounded retries")
	end
end

-- Entering a Deathgaze phase (either the temporary cycle or the final persistent one).
local function enterDeathgaze(token, persistent)
	if not GhuloshRunIsCurrent(token) then
		return
	end
	local boss = Creature(GhuloshRun.bossId)
	if not boss or not GhuloshRunOwnsBoss(boss) then
		return
	end
	boss:setType("Ghulosh' Deathgaze")
	boss:say("FEEL MY WRATH!!", TALKTYPE_MONSTER_SAY)
	GhuloshRun.phase = persistent and "deathgaze_persistent" or "deathgaze_cycle"
	attemptSpawnBook(token, 3)
end

-- CORRECTION (section 14.1-style precedent applied here): setType back to "Ghulosh" is atomic - no
-- separate creation/verification is needed, unlike a remove+recreate swap.
local function returnToGhulosh(token, finalReturn)
	if not GhuloshRunIsCurrent(token) then
		return
	end
	local boss = Creature(GhuloshRun.bossId)
	if not boss or not GhuloshRunOwnsBoss(boss) then
		return
	end
	boss:setType("Ghulosh")
	boss:say("NOOO! MY POWER WANES!", TALKTYPE_MONSTER_SAY)
	GhuloshRun.phase = finalReturn and "normal_final" or "normal"
end

function GhuloshRunSlimeDied(token)
	if not GhuloshRunIsCurrent(token) then
		return
	end
	GhuloshRun.slimeId = nil
	-- "if slime dies, Book of Death returns" - tracked/owned respawn, matching the original 4s
	-- delay, replacing the previous raw untracked addEvent whose own event id was discarded.
	GhuloshRunTrackEvent(
		token,
		addEvent(function()
			attemptSpawnBook(token, 3)
		end, 4 * 1000)
	)
	if GhuloshRun.phase == "deathgaze_cycle" then
		returnToGhulosh(token, false)
	end
	-- In "deathgaze_persistent", the slime respawning is what re-establishes the reflected-damage
	-- path - Deathgaze himself remains in that phase until the low-health return trigger below.
end

function GhuloshRunBookDied(token, cPos)
	if not GhuloshRunIsCurrent(token) then
		return
	end
	GhuloshRun.bookId = nil
	local slime = Game.createMonster("Concentrated Death", cPos, false, true)
	if slime then
		GhuloshRun.slimeId = slime:getId()
	else
		logger.error("SecretLibrary/Ghulosh: Concentrated Death failed to spawn on book death")
	end
end

-- Called from creaturescripts_ghulosh.lua's onHealthChange, registered on the boss - drives the stage
-- transitions and the persistent-phase low-health return.
function GhuloshRunCheckHealthThreshold(token, boss)
	if not GhuloshRunIsCurrent(token) or not GhuloshRunOwnsBoss(boss) then
		return
	end
	local percent = (boss:getHealth() / boss:getMaxHealth()) * 100

	if GhuloshRun.phase == "normal" and GhuloshRun.stageIndex < #STAGES and percent <= STAGES[GhuloshRun.stageIndex + 1] then
		GhuloshRun.stageIndex = GhuloshRun.stageIndex + 1
		local isFinalStage = GhuloshRun.stageIndex >= #STAGES
		enterDeathgaze(token, isFinalStage)
	elseif GhuloshRun.phase == "deathgaze_persistent" and percent <= PERSISTENT_RETURN_HEALTH_PERCENT then
		local book = Creature(GhuloshRun.bookId)
		if book then
			book:remove()
		end
		local slime = Creature(GhuloshRun.slimeId)
		if slime then
			slime:remove()
		end
		GhuloshRun.bookId = nil
		GhuloshRun.slimeId = nil
		returnToGhulosh(token, true)
	end
end

local function validateParticipant(creature)
	if not creature or not creature:isPlayer() then
		return true
	end
	if not creature:isPremium() then
		creature:sendTextMessage(MESSAGE_EVENT_ADVANCE, "You need a premium account to face Ghulosh.")
		return false
	end
	if creature:getStorageValue(Storage.Quest.U11_80.TheSecretLibrary.LibraryPermission) < 7 then
		creature:sendTextMessage(MESSAGE_EVENT_ADVANCE, "You have not yet been granted access to the Secret Library.")
		return false
	end
	return true
end

local lastInfoPositions = nil

local function createGhuloshEncounter()
	if GhuloshRun.active then
		logger.error("SecretLibrary/Ghulosh: a run is already active, refusing a second concurrent start")
		return false
	end

	local boss = Game.createMonster("Ghulosh", BOSS_POSITION, false, true)
	if not boss then
		logger.error("SecretLibrary/Ghulosh: technical abort - Ghulosh failed to spawn")
		return false
	end
	boss:registerEvent("BossLeverOnDeath")

	GhuloshRun.token = GhuloshRun.token + 1
	local token = GhuloshRun.token
	GhuloshRun.active = true
	GhuloshRun.bossId = boss:getId()
	GhuloshRun.participants = {}
	GhuloshRun.phase = "normal"
	GhuloshRun.stageIndex = 0
	GhuloshRun.bookId = nil
	GhuloshRun.slimeId = nil
	GhuloshRun.events = {}

	if lastInfoPositions then
		for _, posInfo in pairs(lastInfoPositions) do
			local player = posInfo.creature
			if player and player:isPlayer() then
				GhuloshRun.participants[player:getId()] = true
			end
		end
	end

	GhuloshRunTrackEvent(
		token,
		addEvent(function()
			GhuloshRunTerminate(token, "normal_timeout", "encounter time limit exceeded")
		end, 17 * 60 * 1000)
	)
	GhuloshRunTrackEvent(token, addEvent(watchEmptyRoom, 20 * 1000, token))

	return true
end

local config = {
	boss = {
		name = "Ghulosh",
		createFunction = createGhuloshEncounter,
	},
	requiredLevel = 250,
	timeToDefeat = 17 * 60,
	playerPositions = {
		{ pos = Position(32747, 32773, 10), teleport = Position(32757, 32727, 10), effect = CONST_ME_TELEPORT },
		{ pos = Position(32748, 32773, 10), teleport = Position(32757, 32727, 10), effect = CONST_ME_TELEPORT },
		{ pos = Position(32749, 32773, 10), teleport = Position(32757, 32727, 10), effect = CONST_ME_TELEPORT },
		{ pos = Position(32750, 32773, 10), teleport = Position(32757, 32727, 10), effect = CONST_ME_TELEPORT },
		{ pos = Position(32751, 32773, 10), teleport = Position(32757, 32727, 10), effect = CONST_ME_TELEPORT },
	},
	specPos = {
		from = Position(32748, 32713, 10),
		to = Position(32763, 32729, 10),
	},
	exit = EXIT_POSITION,
	onUseExtra = function(player, infoPositions)
		lastInfoPositions = infoPositions
		return validateParticipant(player)
	end,
}

local lever = BossLever(config)
lever:position(Position(32746, 32773, 10))
lever:register()
