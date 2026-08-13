-- ================================================================
-- COUNT VLARKORTH RUN OWNERSHIP (executor contract, section 8; correction pass section C/D/E/N/O)
-- ================================================================
-- Bare global (no `local`), matching the King Zelos / HOD HODFinalRun precedent already accepted in
-- this engagement, so creaturescripts_count_vlarkorth.lua and actions_dark_remains.lua can read/
-- mutate it directly while every cross-file mutation goes through the token-checked helpers below.
VlarkorthRun = {
	token = 0,
	active = false,
	bossId = nil, -- the one Count Vlarkorth instance this run owns
	generation = 0, -- current shield-obligation generation (bumped each summonDarks() wave)
	participants = {}, -- set: playerId -> true
	timerWritten = {}, -- set: playerId -> true (this attempt wrote Bosses.CountVlarkorth.Timer for them)
	monsters = {}, -- set: creatureId -> true (dark summons owned by this attempt)
	events = {}, -- set: eventId -> true
}

function VlarkorthRunIsCurrent(token)
	return token ~= nil and token > 0 and VlarkorthRun.active and VlarkorthRun.token == token
end

function VlarkorthRunCurrentToken()
	if VlarkorthRun.active then
		return VlarkorthRun.token
	end
	return nil
end

function VlarkorthRunOwnsMonster(creature)
	return creature ~= nil and VlarkorthRun.active and VlarkorthRun.monsters[creature:getId()] == true
end

-- CORRECTION (section B): boss-identity check used by grave_danger_death to require actual run
-- ownership, not just a damage-map entry, before crediting Count Vlarkorth's grave/boss kill.
function VlarkorthRunOwnsBoss(creature)
	return creature ~= nil and VlarkorthRun.active and VlarkorthRun.bossId == creature:getId()
end

function VlarkorthRunIsParticipant(token, playerId)
	return VlarkorthRunIsCurrent(token) and VlarkorthRun.participants[playerId] == true
end

function VlarkorthRunTrackMonster(monster)
	if monster and VlarkorthRun.active then
		VlarkorthRun.monsters[monster:getId()] = true
	end
end

function VlarkorthRunTrackEvent(token, eventId)
	if VlarkorthRunIsCurrent(token) and eventId then
		VlarkorthRun.events[eventId] = true
	end
end

-- CORRECTION (section D): called once per summonDarks() wave to establish the CURRENT shield
-- generation, so remains tagged with a superseded generation can never weaken a newer one.
function VlarkorthRunCurrentGeneration()
	if VlarkorthRun.active then
		return VlarkorthRun.generation
	end
	return nil
end

-- CORRECTION (section O): records that THIS attempt (not a previous one) wrote the legacy
-- Bosses.CountVlarkorth.Timer lockout for this player, so a technical_abort knows exactly whose
-- timer it is responsible for rolling back.
function VlarkorthRunMarkTimerWritten(token, playerId)
	if VlarkorthRunIsCurrent(token) then
		VlarkorthRun.timerWritten[playerId] = true
	end
end

local EXIT_POSITION = Position(33195, 31690, 8)

-- Single terminal lifecycle path (mirrors the King Zelos HODFinalRunTerminate-style pattern already
-- accepted in this engagement). kind is one of "technical_abort", "normal_timeout", "success".
function VlarkorthRunTerminate(token, kind, reason)
	if not VlarkorthRunIsCurrent(token) then
		return
	end
	logger.info("GraveDanger/CountVlarkorth: run {} terminated ({}) - {}", token, kind, reason or "")

	VlarkorthRun.active = false

	for eventId in pairs(VlarkorthRun.events) do
		stopEvent(eventId)
	end

	if kind == "technical_abort" then
		for playerId in pairs(VlarkorthRun.participants) do
			local player = Player(playerId)
			if player then
				player:setBossCooldown("count vlarkorth", 0)
				-- CORRECTION (section O): only rolled back for participants THIS attempt actually
				-- wrote the legacy Timer lockout for - never touches a lockout an earlier, unrelated
				-- attempt legitimately set.
				if VlarkorthRun.timerWritten[playerId] then
					player:setStorageValue(Storage.Quest.U12_20.GraveDanger.Bosses.CountVlarkorth.Timer, 0)
				end
			end
		end
	end

	-- CORRECTION (lifecycle closure pass section A): on a legitimate SUCCESS, BossLeverOnDeath (now
	-- registered on this boss's own monster.events) already owns the framework's normal victory
	-- behavior - bossAlive=false, cancelling timeoutEvent/emptyRoomEvent, the timeAfterKill grace
	-- period, and the eventual zone:cleanRoom()/removePlayers(). This terminator must not compete with
	-- or race ahead of that: closing BossLever's internal state here on success (as an earlier version
	-- of this file did, unconditionally) set bossAlive=false and wiped the room BEFORE BossLeverOnDeath
	-- ever got a chance to run its own onDeath handler (both are registered on the same death), which
	-- made BossLeverOnDeath's own `if not bossLever.bossAlive then return true end` guard treat it as
	-- an already-handled duplicate - the victory message and grace period silently never fired. Every
	-- other kind (technical_abort, normal_timeout) still owns this cleanup itself, since neither of
	-- those reaches a natural boss death for BossLeverOnDeath to fire from.
	if kind ~= "success" then
		for monsterId in pairs(VlarkorthRun.monsters) do
			local monster = Creature(monsterId)
			if monster then
				monster:remove()
			end
		end

		-- CORRECTION (section N, refined by lifecycle closure pass section A): closes out BossLever's
		-- own internal state directly (a local reference, not a change to the shared framework file).
		-- Order matches BossLever's own generic timeout callback exactly (refresh, THEN remove players,
		-- THEN clean) so a normal_timeout that races ahead of and cancels BossLever's own timeoutEvent
		-- (both are scheduled for essentially the same encounter deadline) cannot leave players
		-- stranded in an already-cleaned room - this terminator now performs the player-removal step
		-- itself before cleaning, exactly as BossLever's own cancelled timeoutEvent would have.
		local bossLever = BossLever["count vlarkorth"]
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

	VlarkorthRun.bossId = nil
	VlarkorthRun.generation = 0
	VlarkorthRun.participants = {}
	VlarkorthRun.timerWritten = {}
	VlarkorthRun.monsters = {}
	VlarkorthRun.events = {}
end

-- CORRECTION (section E): Count Vlarkorth previously had no phase timeout of its own, relying solely
-- on BossLever's generic room timer - which never calls back into this file's run state, so a timed
---out/emptied attempt left VlarkorthRun.active stuck true forever, permanently blocking every future
-- Count Vlarkorth attempt (createVlarkorthEncounter's own "a run is already active" guard would never
-- clear). Two run-owned watchdogs close that gap without inventing a new gameplay-facing duration:
-- a flat deadline at the same BOSS_DEFAULT_TIME_TO_DEFEAT this lever already implicitly runs under
-- (no custom timeToDefeat is set in config below), and a 20-second empty-room poll mirroring
-- BossLever.emptyRoomCheckInterval so a room that empties out early is not held hostage for the full
-- default duration.
local function watchEmptyRoom(token)
	if not VlarkorthRunIsCurrent(token) then
		return
	end
	local zone = Zone("boss." .. toKey("count vlarkorth"))
	if zone and zone:countPlayers() == 0 then
		VlarkorthRunTerminate(token, "normal_timeout", "room emptied before the encounter concluded")
		return
	end
	VlarkorthRunTrackEvent(token, addEvent(watchEmptyRoom, 20 * 1000, token))
end

-- CORRECTION (section C): Dark Merudri / Monk remains stay ASSET_REQUIRED - no canonical monster or
-- item exists anywhere in the repository (confirmed by repo-wide search during the original pass).
-- A Monk roster participant previously generated no summon and no obligation, which made the shield
-- phase EASIER (fail-open) instead of blocking the encounter. This now rejects the lever entirely,
-- before any monster is created, cooldown is burned, or player is teleported, whenever a legitimate
-- roster participant is a Monk.
local function hasUnresolvedMonk(infoPositions)
	for _, posInfo in pairs(infoPositions) do
		local player = posInfo.creature
		if player and player:isPlayer() and player:getVocation():getBase():getId() == 9 then
			return player
		end
	end
	return nil
end

-- CORRECTION (section A): the lever itself now independently verifies Premium and that the Lich line
-- has actually been started for every occupied platform position, matching the same defense-in-depth
-- already applied to King Zelos/Scarlett - a non-Lich-line or non-Premium player must be rejected
-- here, not merely denied credit later at grave_danger_death.
local function validateParticipant(creature)
	if not creature or not creature:isPlayer() then
		return true
	end
	if not creature:isPremium() then
		creature:sendTextMessage(MESSAGE_EVENT_ADVANCE, "You need a premium account to face Count Vlarkorth.")
		return false
	end
	if creature:getStorageValue(Storage.Quest.U12_20.GraveDanger.Questline) < 1 then
		creature:sendTextMessage(MESSAGE_EVENT_ADVANCE, "You have not yet started this quest.")
		return false
	end
	return true
end

-- Snapshot of the most recent onUseExtra call's infoPositions, consumed synchronously by
-- createVlarkorthEncounter() moments later in the same synchronous BossLever:onUse() call.
local lastInfoPositions = nil

-- CORRECTION (executor contract, section 8): mirrors the King Zelos fix - Count Vlarkorth is now
-- created via config.boss.createFunction (invoked by boss_lever.lua AFTER Zone:removeMonsters(),
-- unlike onUseExtra which runs during Lever:checkConditions() and would have its creation undone by
-- that same removeMonsters() call moments later) so the mandatory boss creation is verified before
-- Lever:teleportPlayers()/setCooldownAllPlayers() ever commit.
local function createVlarkorthEncounter()
	if VlarkorthRun.active then
		logger.error("GraveDanger/CountVlarkorth: a run is already active, refusing a second concurrent start")
		return false
	end

	local boss = Game.createMonster("Count Vlarkorth", Position(33456, 31434, 13), false, true)
	if not boss then
		logger.error("GraveDanger/CountVlarkorth: technical abort - Count Vlarkorth failed to spawn")
		return false
	end

	VlarkorthRun.token = VlarkorthRun.token + 1
	local token = VlarkorthRun.token
	VlarkorthRun.active = true
	VlarkorthRun.bossId = boss:getId()
	VlarkorthRun.generation = 0
	VlarkorthRun.participants = {}
	VlarkorthRun.timerWritten = {}
	VlarkorthRun.monsters = {}
	VlarkorthRun.events = {}

	if lastInfoPositions then
		for _, posInfo in pairs(lastInfoPositions) do
			local player = posInfo.creature
			if player and player:isPlayer() then
				VlarkorthRun.participants[player:getId()] = true
			end
		end
	end

	VlarkorthRunTrackMonster(boss)
	VlarkorthRunTrackEvent(
		token,
		addEvent(function()
			VlarkorthRunTerminate(token, "normal_timeout", "encounter time limit exceeded")
		end, configManager.getNumber(configKeys.BOSS_DEFAULT_TIME_TO_DEFEAT) * 1000)
	)
	VlarkorthRunTrackEvent(token, addEvent(watchEmptyRoom, 20 * 1000, token))
	return true
end

local config = {
	boss = {
		name = "Count Vlarkorth",
		-- No `position` field: created transactionally by createFunction above.
		createFunction = createVlarkorthEncounter,
	},
	requiredLevel = 250,
	playerPositions = {
		{ pos = Position(33455, 31413, 13), teleport = Position(33454, 31445, 13), effect = CONST_ME_TELEPORT },
		{ pos = Position(33456, 31413, 13), teleport = Position(33454, 31445, 13), effect = CONST_ME_TELEPORT },
		{ pos = Position(33457, 31413, 13), teleport = Position(33454, 31445, 13), effect = CONST_ME_TELEPORT },
		{ pos = Position(33458, 31413, 13), teleport = Position(33454, 31445, 13), effect = CONST_ME_TELEPORT },
		{ pos = Position(33459, 31413, 13), teleport = Position(33454, 31445, 13), effect = CONST_ME_TELEPORT },
	},
	specPos = {
		from = Position(33448, 31428, 13),
		to = Position(33464, 31446, 13),
	},
	exit = EXIT_POSITION,
	onUseExtra = function(creature, infoPositions)
		lastInfoPositions = infoPositions
		if not validateParticipant(creature) then
			return false
		end
		-- CORRECTION (section C): checked once per occupied position via Lever:checkConditions(), but
		-- hasUnresolvedMonk scans the whole roster every time, so this is safely idempotent and always
		-- rejects the pull as soon as any position is evaluated if a Monk is present anywhere in it.
		local monk = hasUnresolvedMonk(infoPositions)
		if monk then
			monk:sendTextMessage(MESSAGE_EVENT_ADVANCE, "Count Vlarkorth's shield ritual has no proven counter for your vocation yet - this attempt cannot proceed with a Monk in the party.")
			if creature ~= monk then
				creature:sendTextMessage(MESSAGE_EVENT_ADVANCE, "A member of your team's vocation is not yet supported for this encounter.")
			end
			return false
		end
		return true
	end,
}

local lever = BossLever(config)
lever:position(Position(33454, 31413, 13))
lever:register()
