-- ================================================================
-- SECRET LIBRARY FINAL INVASION RUN OWNERSHIP (Secret Library repair v2, sections 19-23, 32-33)
-- ================================================================
-- Confirmed pre-existing state: the whole 26:20/4-wing encounter was authored entirely on Game-global
-- storages (Storage.Quest.U11_80.TheSecretLibrary.SecretLibraryInvasion.*) with no run/attempt
-- identity at all - any monster sharing a wing boss's name anywhere on the map could credit/mutate the
-- "current" attempt, a stale delayed callback from a finished/reset attempt could still fire against a
-- brand new one, and the lever itself checked no eligibility beyond a flat requiredLevel. This file
-- replaces that Game-storage authority with SecretLibraryInvasionRun - the same bare-global-table
-- token/ownership convention already used by this quest's own Lokathmor/Gorzindel/Mazzinor/Ghulosh
-- rebuilds. The pre-existing SecretLibraryInvasion.* Game storages are left in storages.lua and still
-- written to below (observability/backward compatibility only, per the owner contract's explicit
-- allowance) - they are no longer read by anything as an authority.
local Invasion = Storage.Quest.U11_80.TheSecretLibrary.SecretLibraryInvasion
local Library = Storage.Quest.U11_80.TheSecretLibrary.Library

SecretLibraryInvasionRun = {
	token = 0,
	active = false,
	participants = {}, -- set: playerId -> true, fixed at the moment the encounter starts
	startedAt = 0,
	hardDeadline = 0, -- os.time() startedAt + 26:20 - the exact, owner-given total duration
	phase = "idle", -- "central_intro" | "wing" | "scourge" | "ended"
	wingIndex = 0, -- 1..4 into WINGS (movements_invasion_start.lua)
	wingGeneration = 0, -- bumped once per wing's mandatory-entity spawn attempt; guards stale add callbacks
	wingBossIds = {}, -- key -> creatureId, or {chill=id, freeze=id} for the "brothers" wing
	wingAddIds = {}, -- key -> set: creatureId -> true (current wing-generation owned adds)
	wingDefeated = {}, -- key -> true once legitimately resolved
	brothersAlive = {}, -- {chill = bool, freeze = bool} - current wing-generation only
	scourgeCreatureId = nil, -- constant across every setType phase-swap (dormant -> real -> reflective/immune -> real)
	scourgePhase = 0, -- 0 not yet active, 1 yellow (vulnerable), 2 red (reflective), 3 blue (beam)
	scourgePhaseGeneration = 0, -- bumped on every phase change; a delayed beam must match this exactly
	-- CORRECTION (Secret Library corrective repair pass, section 5): central-hall raid wave state -
	-- see movements_invasion_start.lua's spawnCentralWave/clearCentralWave. Generation-tagged exactly
	-- like every other owned-entity set in this run, so a stale wave-clear callback from an earlier
	-- round can never touch a later round's creatures.
	centralWaveGeneration = 0,
	centralWaveCreatureIds = {}, -- set: creatureId -> true, current central-wave-generation only
	events = {}, -- set: eventId -> true
}

function SecretLibraryInvasionRunIsCurrent(token)
	return token ~= nil and token > 0 and SecretLibraryInvasionRun.active and SecretLibraryInvasionRun.token == token
end

function SecretLibraryInvasionRunCurrentToken()
	if SecretLibraryInvasionRun.active then
		return SecretLibraryInvasionRun.token
	end
	return nil
end

function SecretLibraryInvasionRunIsParticipant(token, playerId)
	return SecretLibraryInvasionRunIsCurrent(token) and SecretLibraryInvasionRun.participants[playerId] == true
end

function SecretLibraryInvasionRunTrackEvent(token, eventId)
	if SecretLibraryInvasionRunIsCurrent(token) and eventId then
		SecretLibraryInvasionRun.events[eventId] = true
	end
end

function SecretLibraryInvasionRunOwnsScourge(creature)
	return creature ~= nil and SecretLibraryInvasionRun.active and SecretLibraryInvasionRun.scourgeCreatureId == creature:getId()
end

function SecretLibraryInvasionRunOwnsWingBoss(key, creature)
	if not creature or not SecretLibraryInvasionRun.active then
		return false
	end
	local owned = SecretLibraryInvasionRun.wingBossIds[key]
	if type(owned) == "table" then
		return owned.chill == creature:getId() or owned.freeze == creature:getId()
	end
	return owned == creature:getId()
end

function SecretLibraryInvasionRunOwnsWingAdd(key, creature)
	if not creature or not SecretLibraryInvasionRun.active then
		return false
	end
	local set = SecretLibraryInvasionRun.wingAddIds[key]
	return set ~= nil and set[creature:getId()] == true
end

-- Single terminal lifecycle path. kind is one of "technical_abort", "normal_timeout", "success".
-- Success cleanup is left entirely to BossLeverOnDeath (registered on the Scourge, both dynamically at
-- Dormant spawn and statically on the real form) - matching every other boss in this quest, this
-- terminator must not race ahead of it on success, only on the two non-success paths.
function SecretLibraryInvasionRunTerminate(token, kind, reason)
	if not SecretLibraryInvasionRunIsCurrent(token) then
		return
	end
	logger.info("SecretLibrary/Invasion: run {} terminated ({}) - {}", token, kind, reason or "")

	SecretLibraryInvasionRun.active = false
	for eventId in pairs(SecretLibraryInvasionRun.events) do
		stopEvent(eventId)
	end

	if kind == "technical_abort" then
		for playerId in pairs(SecretLibraryInvasionRun.participants) do
			local player = Player(playerId)
			if player then
				player:setBossCooldown("the scourge of oblivion (dormant)", 0)
			end
		end
	end

	if kind ~= "success" then
		for _, ownedIds in pairs(SecretLibraryInvasionRun.wingBossIds) do
			if type(ownedIds) == "table" then
				for _, id in pairs(ownedIds) do
					local monster = Creature(id)
					if monster then
						monster:remove()
					end
				end
			else
				local monster = Creature(ownedIds)
				if monster then
					monster:remove()
				end
			end
		end
		for _, set in pairs(SecretLibraryInvasionRun.wingAddIds) do
			for creatureId in pairs(set) do
				local monster = Creature(creatureId)
				if monster then
					monster:remove()
				end
			end
		end
		for creatureId in pairs(SecretLibraryInvasionRun.centralWaveCreatureIds) do
			local monster = Creature(creatureId)
			if monster then
				monster:remove()
			end
		end
		if SecretLibraryInvasionRun.scourgeCreatureId then
			local scourge = Creature(SecretLibraryInvasionRun.scourgeCreatureId)
			if scourge then
				scourge:remove()
			end
		end

		local bossLever = BossLever["the scourge of oblivion (dormant)"]
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

	Game.setStorageValue(Invasion.Started, 0)
	Game.setStorageValue(Invasion.ScourgePhase, 0)

	SecretLibraryInvasionRun.participants = {}
	SecretLibraryInvasionRun.phase = "idle"
	SecretLibraryInvasionRun.wingIndex = 0
	SecretLibraryInvasionRun.wingGeneration = 0
	SecretLibraryInvasionRun.wingBossIds = {}
	SecretLibraryInvasionRun.wingAddIds = {}
	SecretLibraryInvasionRun.wingDefeated = {}
	SecretLibraryInvasionRun.brothersAlive = {}
	SecretLibraryInvasionRun.scourgeCreatureId = nil
	SecretLibraryInvasionRun.scourgePhase = 0
	SecretLibraryInvasionRun.scourgePhaseGeneration = 0
	SecretLibraryInvasionRun.centralWaveGeneration = 0
	SecretLibraryInvasionRun.centralWaveCreatureIds = {}
	SecretLibraryInvasionRun.events = {}
end

-- CORRECTION (Secret Library surgical correction pass, Defect B): this encounter's own BossLever
-- specPos (config.specPos below) covers only the central hall - (32712,32723,11)-(32738,32748,11).
-- The previous pass's own OTBM evidence proved the wing halls extend physically outside that
-- rectangle, and legitimate wing combat has no player-teleport step (players walk there over the
-- proven corridor connections) - so during a genuine, in-progress wing fight, this central-only zone's
-- player count legitimately drops to 0. Both this watcher AND BossLever's own generic emptyRoomEvent
-- watcher (see the lever instance override near the bottom of this file) previously treated that as
-- room abandonment and could terminate/reset a fully legitimate attempt. Guarded on
-- SecretLibraryInvasionRun.phase == "wing" - the phase is set by InvasionAdvanceWing the moment a wing
-- starts and is only cleared by the next InvasionAdvanceWing/InvasionActivateScourge call, so it
-- already covers the whole unsafe window: the wing fight itself, the post-wing grace delay, and every
-- central-wave round that follows before the next wing (during which players are legitimately back in
-- the central hall anyway, so the guard is a safe no-op there, not a loosened check). central_intro
-- and scourge phases are unaffected - genuine abandonment during those still times out normally.
local function watchEmptyRoom(token)
	if not SecretLibraryInvasionRunIsCurrent(token) then
		return
	end
	if SecretLibraryInvasionRun.phase ~= "wing" then
		local zone = Zone("boss." .. toKey("the scourge of oblivion (dormant)"))
		if zone and zone:countPlayers() == 0 then
			SecretLibraryInvasionRunTerminate(token, "normal_timeout", "room emptied before the encounter concluded")
			return
		end
	end
	SecretLibraryInvasionRunTrackEvent(token, addEvent(watchEmptyRoom, 20 * 1000, token))
end

-- CORRECTION (section 19): every accepted participant independently verified - Premium, library
-- access, and all four inner Library bosses legitimately completed (their own persistent per-player
-- completion flags, allocated in storages.lua section 13). BossLever's own onUseExtra/setCondition
-- calls this once per lever-position player and fails the WHOLE start if any one of them fails, so no
-- one is ever accepted merely because a teammate on the lever is eligible.
local function validateParticipant(player)
	if not player:isPremium() then
		player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "You need a premium account to face the Scourge of Oblivion.")
		return false
	end
	if player:getStorageValue(Storage.Quest.U11_80.TheSecretLibrary.LibraryPermission) < 7 then
		player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "You have not yet been granted access to the Secret Library.")
		return false
	end
	if player:getStorageValue(Library.LokathmorDefeated) < 1 or player:getStorageValue(Library.GorzindelDefeated) < 1 or player:getStorageValue(Library.MazzinorDefeated) < 1 or player:getStorageValue(Library.GhuloshDefeated) < 1 then
		player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "You must first defeat Lokathmor, Gorzindel, Mazzinor and Ghulosh before facing the invasion's leader.")
		return false
	end
	return true
end

-- CORRECTION (section 21): "do NOT start an inert 26-minute encounter" - before any irreversible
-- commit (teleport, cooldown, the 26:20 timer), every wing's mandatory physical surface must be
-- proven. InvasionMapReady() (movements_invasion_start.lua) mechanically checks every WINGS entry's
-- roomCenter/spawnPositions/(Spellstealer's green+red teleports) for nil - all four are currently nil
-- (honest pre-existing "MAP SETUP REQUIRED" placeholders, never populated with real coordinates
-- anywhere in this repo or the reference). Until an owner-provided OTBM/manual RME pass fills them in,
-- this correctly and honestly refuses to start - see the Manual RME Manifest / map status matrix
-- (MAP_REQUIRED) for the full disclosure, not a guessed rectangle.
local mapWarningKey = nil

local function mapReadyGate(player)
	local ready, missingKey = InvasionMapReady()
	if ready then
		return true
	end
	mapWarningKey = missingKey
	player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "The invasion's wings have not yet been prepared. This encounter cannot begin.")
	return false
end

local lastInfoPositions = nil

local function createInvasionEncounter()
	if SecretLibraryInvasionRun.active then
		logger.error("SecretLibrary/Invasion: a run is already active, refusing a second concurrent start")
		return false
	end

	local dormant = Game.createMonster("The Scourge of Oblivion (Dormant)", Position(32726, 32727, 11), false, true)
	if not dormant then
		logger.error("SecretLibrary/Invasion: technical abort - dormant Scourge of Oblivion failed to spawn")
		return false
	end
	dormant:registerEvent("BossLeverOnDeath")

	SecretLibraryInvasionRun.token = SecretLibraryInvasionRun.token + 1
	local token = SecretLibraryInvasionRun.token
	SecretLibraryInvasionRun.active = true
	SecretLibraryInvasionRun.participants = {}
	SecretLibraryInvasionRun.startedAt = os.time()
	SecretLibraryInvasionRun.hardDeadline = SecretLibraryInvasionRun.startedAt + (26 * 60 + 20)
	SecretLibraryInvasionRun.phase = "central_intro"
	SecretLibraryInvasionRun.wingIndex = 0
	SecretLibraryInvasionRun.wingGeneration = 0
	SecretLibraryInvasionRun.wingBossIds = {}
	SecretLibraryInvasionRun.wingAddIds = {}
	SecretLibraryInvasionRun.wingDefeated = {}
	SecretLibraryInvasionRun.brothersAlive = {}
	SecretLibraryInvasionRun.scourgeCreatureId = dormant:getId()
	SecretLibraryInvasionRun.scourgePhase = 0
	SecretLibraryInvasionRun.scourgePhaseGeneration = 0
	SecretLibraryInvasionRun.centralWaveGeneration = 0
	SecretLibraryInvasionRun.centralWaveCreatureIds = {}
	SecretLibraryInvasionRun.events = {}

	if lastInfoPositions then
		for _, posInfo in pairs(lastInfoPositions) do
			local player = posInfo.creature
			if player and player:isPlayer() then
				SecretLibraryInvasionRun.participants[player:getId()] = true
			end
		end
	end

	-- Room-shared observability storages only (see header comment) - not read back as authority.
	Game.setStorageValue(Invasion.Started, SecretLibraryInvasionRun.startedAt)
	Game.setStorageValue(Invasion.SpellstealerDefeated, 0)
	Game.setStorageValue(Invasion.ScionOfHavocDefeated, 0)
	Game.setStorageValue(Invasion.BrothersDefeated, 0)
	Game.setStorageValue(Invasion.BrothersDeathCount, 0)
	Game.setStorageValue(Invasion.DevourerDefeated, 0)
	Game.setStorageValue(Invasion.ScourgePhase, 0)

	-- CORRECTION (section 21): exact, owner-given 26:20 total duration - normal_timeout, not a poll
	-- loop, so it is guaranteed cancelled (via SecretLibraryInvasionRunTerminate's event sweep) the
	-- moment the encounter ends any other way.
	SecretLibraryInvasionRunTrackEvent(
		token,
		addEvent(function()
			SecretLibraryInvasionRunTerminate(token, "normal_timeout", "26:20 encounter time limit exceeded")
		end, (26 * 60 + 20) * 1000)
	)
	SecretLibraryInvasionRunTrackEvent(token, addEvent(watchEmptyRoom, 20 * 1000, token))

	-- CORRECTION (corrective repair pass, section 5): current reliable reference describes invasion
	-- creatures beginning to appear in the central hall "about 1 minute after entry" - replaces the
	-- previous pass's ~30s value (which additionally skipped the central-wave phase entirely and went
	-- straight to the first wing breach). CUSTOM_GLOBAL_LIKE_PENDING_EXACT_TIMING: "about 1 minute" is
	-- the reference's own approximate phrasing, not an exact figure.
	SecretLibraryInvasionRunTrackEvent(token, addEvent(InvasionStartCentralWaveRound, 60 * 1000, token, 1))

	return true
end

local config = {
	boss = {
		name = "The Scourge of Oblivion (Dormant)",
		createFunction = createInvasionEncounter,
	},
	requiredLevel = 250,
	timeToDefeat = 26 * 60 + 20, -- exact total encounter duration per the reference
	playerPositions = {
		{ pos = Position(32676, 32743, 11), teleport = Position(32726, 32733, 11), effect = CONST_ME_TELEPORT },
		{ pos = Position(32676, 32744, 11), teleport = Position(32726, 32733, 11), effect = CONST_ME_TELEPORT },
		{ pos = Position(32676, 32745, 11), teleport = Position(32726, 32733, 11), effect = CONST_ME_TELEPORT },
		{ pos = Position(32676, 32741, 11), teleport = Position(32726, 32733, 11), effect = CONST_ME_TELEPORT },
		{ pos = Position(32676, 32742, 11), teleport = Position(32726, 32733, 11), effect = CONST_ME_TELEPORT },
		{ pos = Position(32677, 32741, 11), teleport = Position(32726, 32733, 11), effect = CONST_ME_TELEPORT },
		{ pos = Position(32677, 32742, 11), teleport = Position(32726, 32733, 11), effect = CONST_ME_TELEPORT },
		{ pos = Position(32677, 32743, 11), teleport = Position(32726, 32733, 11), effect = CONST_ME_TELEPORT },
		{ pos = Position(32677, 32744, 11), teleport = Position(32726, 32733, 11), effect = CONST_ME_TELEPORT },
		{ pos = Position(32677, 32745, 11), teleport = Position(32726, 32733, 11), effect = CONST_ME_TELEPORT },
	},
	specPos = {
		from = Position(32712, 32723, 11),
		to = Position(32738, 32748, 11),
	},
	exit = Position(32480, 32599, 15),
	onUseExtra = function(player, infoPositions)
		lastInfoPositions = infoPositions
		return validateParticipant(player) and mapReadyGate(player)
	end,
}

local lever = BossLever(config)

-- CORRECTION (Defect B): instance-only override of BossLever's own generic empty-room watcher
-- (data/libs/functions/boss_lever.lua's BossLever:watchEmptyRoom/handleEmptyRoom), scoped to this one
-- lever instance only - assigning directly on the `lever` table shadows the shared BossLever method
-- via Lua's normal instance-before-metatable lookup order, so every other BossLever-based boss in this
-- codebase keeps its unmodified default behavior; data/libs/functions/boss_lever.lua itself is not
-- touched. Logic is identical to the framework's own BossLever:watchEmptyRoom, with one addition: while
-- SecretLibraryInvasionRun.phase == "wing" (see the local watchEmptyRoom function above for the exact
-- rationale - the central-only specPos zone legitimately empties during a real wing fight), this skips
-- the abandonment check for this poll and simply reschedules, instead of calling
-- self:handleEmptyRoom(zone) (which would set bossAlive=false, stop events, and clean/reset the room).
function lever:watchEmptyRoom(zone)
	if not self.bossAlive then
		return
	end
	if SecretLibraryInvasionRun.active and SecretLibraryInvasionRun.phase == "wing" then
		self.emptyRoomEvent = addEvent(function(bossLever, zn)
			bossLever:watchEmptyRoom(zn)
		end, BossLever.emptyRoomCheckInterval, self, zone)
		return
	end
	if zone:countPlayers() == 0 then
		self:handleEmptyRoom(zone)
		return
	end
	self.emptyRoomEvent = addEvent(function(bossLever, zn)
		bossLever:watchEmptyRoom(zn)
	end, BossLever.emptyRoomCheckInterval, self, zone)
end

lever:position(Position(32675, 32743, 11))
lever:register()
