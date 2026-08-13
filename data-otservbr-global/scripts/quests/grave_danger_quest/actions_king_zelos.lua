-- ================================================================
-- KING ZELOS RUN OWNERSHIP (executor contract, sections 14-24)
-- ================================================================
-- One namespaced run/session per lever pull. Declared as a bare global (no `local`), matching the
-- Heart of Destruction HODFinalRun precedent, so creaturescripts_king_zelos.lua, movements_zelos_tp.lua
-- and the cleanse-vortex script can all read/mutate it directly while every cross-file mutation still
-- goes through the token-checked helper functions below.
KingZelosRun = {
	token = 0,
	active = false,
	participants = {}, -- set: playerId -> true
	startTime = 0,
	events = {}, -- set: eventId -> true
	monsters = {}, -- set: creatureId -> true
	wings = { redKnight = false, nargol = false, magnor = false, rewar = false },
	hex = {}, -- set: playerId -> true (Greater Hex currently applied, current run only)
}

function KingZelosRunIsCurrent(token)
	return token ~= nil and token > 0 and KingZelosRun.active and KingZelosRun.token == token
end

function KingZelosRunCurrentToken()
	if KingZelosRun.active then
		return KingZelosRun.token
	end
	return nil
end

function KingZelosRunOwnsMonster(creature)
	return creature ~= nil and KingZelosRun.active and KingZelosRun.monsters[creature:getId()] == true
end

function KingZelosRunTrackMonster(monster)
	if monster and KingZelosRun.active then
		KingZelosRun.monsters[monster:getId()] = true
	end
end

function KingZelosRunTrackEvent(token, eventId)
	if KingZelosRunIsCurrent(token) and eventId then
		KingZelosRun.events[eventId] = true
	end
end

function KingZelosRunIsParticipant(token, playerId)
	return KingZelosRunIsCurrent(token) and KingZelosRun.participants[playerId] == true
end

function KingZelosRunMarkWing(token, wingKey)
	if KingZelosRunIsCurrent(token) then
		KingZelosRun.wings[wingKey] = true
	end
end

function KingZelosRunAllWingsComplete(token)
	if not KingZelosRunIsCurrent(token) then
		return false
	end
	return KingZelosRun.wings.redKnight and KingZelosRun.wings.nargol and KingZelosRun.wings.magnor and KingZelosRun.wings.rewar
end

function KingZelosRunSetHex(token, playerId, active)
	if not KingZelosRunIsCurrent(token) then
		return
	end
	if active then
		KingZelosRun.hex[playerId] = true
	else
		KingZelosRun.hex[playerId] = nil
	end
end

function KingZelosRunHasHex(token, playerId)
	return KingZelosRunIsCurrent(token) and KingZelosRun.hex[playerId] == true
end

-- Single terminal lifecycle path (mirrors the HOD HODFinalRunTerminate pattern accepted in the
-- Heart of Destruction repair). kind is one of "technical_abort", "normal_timeout", "success".
function KingZelosRunTerminate(token, kind, reason)
	if not KingZelosRunIsCurrent(token) then
		return
	end
	logger.info("GraveDanger/KingZelos: run {} terminated ({}) - {}", token, kind, reason or "")

	-- Invalidate first (contract-mandated order) so any in-flight callback racing in after this
	-- point is a no-op against a stale token.
	KingZelosRun.active = false

	for eventId in pairs(KingZelosRun.events) do
		stopEvent(eventId)
	end

	-- Greater Hex must never outlive its encounter - no permanent max-HP corruption is acceptable.
	-- removeGreaterHex is defined in creaturescripts_king_zelos.lua (bare global, cross-file).
	for playerId in pairs(KingZelosRun.hex) do
		local player = Player(playerId)
		if player then
			removeGreaterHex(player)
		end
	end

	-- Only a technical abort refunds the server-caused cooldown; a normal timeout is a legitimate
	-- loss and its cooldown is preserved.
	if kind == "technical_abort" then
		for playerId in pairs(KingZelosRun.participants) do
			local player = Player(playerId)
			if player then
				player:setBossCooldown("king zelos", 0)
			end
		end
	end

	-- A legitimate boss death does not need its corpse force-removed; only non-success paths sweep
	-- the run's owned monsters (mandatory wing bosses/adds that would otherwise be left behind).
	if kind ~= "success" then
		for monsterId in pairs(KingZelosRun.monsters) do
			local monster = Creature(monsterId)
			if monster then
				monster:remove()
			end
		end
	end

	KingZelosRun.participants = {}
	KingZelosRun.events = {}
	KingZelosRun.monsters = {}
	KingZelosRun.wings = { redKnight = false, nargol = false, magnor = false, rewar = false }
	KingZelosRun.hex = {}
	Game.setStorageValue(Storage.Quest.U12_20.GraveDanger.KingZelosRitualStart, 0)
end

local function kingZelosPhaseTimeout(token)
	KingZelosRunTerminate(token, "normal_timeout", "24-minute ritual limit exceeded")
end

-- ================================================================
-- TRANSACTIONAL START (executor contract, section 15)
-- ================================================================
local KING_ZELOS_POSITION = Position(33443, 31545, 13)
local WING_MONSTERS = {
	redKnight = { name = "The Red Knight", pos = Position(33423, 31562, 13) },
	nargol = { name = "Nargol The Impaler", pos = Position(33423, 31529, 13) },
	magnor = { name = "Magnor Mournbringer", pos = Position(33463, 31529, 13) },
	rewar = { name = "Rewar The Bloody", pos = Position(33463, 31562, 13) },
}

local function createMonsterVerified(name, pos, maxAttempts)
	maxAttempts = maxAttempts or 3
	for attempt = 1, maxAttempts do
		local monster = Game.createMonster(name, pos, false, true)
		if monster then
			return monster
		end
		logger.error("GraveDanger/KingZelos: failed to create {} (attempt {}/{})", name, attempt, maxAttempts)
	end
	return nil
end

-- Per-participant prerequisite check (executor contract, section 5). Runs inside onUseExtra, which
-- fires during Lever:checkConditions() - BEFORE Zone:removeMonsters() - so it must stay side-effect
-- free with respect to monster creation (see the createFunction note below for why).
local function validateParticipant(creature)
	if not creature or not creature:isPlayer() then
		return true
	end

	if not creature:isPremium() then
		creature:sendTextMessage(MESSAGE_EVENT_ADVANCE, "You need a premium account to face King Zelos.")
		return false
	end

	if creature:getStorageValue(Storage.Quest.U12_20.GraveDanger.Graves.Progress) < 12 then
		creature:sendTextMessage(MESSAGE_EVENT_ADVANCE, "You have not yet secured all twelve graves of the fallen knights.")
		return false
	end

	if creature:getStorageValue(Storage.Quest.U12_20.GraveDanger.Questline) < 2 then
		creature:sendTextMessage(MESSAGE_EVENT_ADVANCE, "You have not yet reported the full threat to Jack Springer.")
		return false
	end

	if creature:getStorageValue(Storage.Quest.U12_20.GraveDanger.Bosses.KingZelos.Room) < 1 then
		creature:sendTextMessage(MESSAGE_EVENT_ADVANCE, "You have not been granted access to King Zelos's grave.")
		return false
	end

	if not creature:canFightBoss("king zelos") then
		creature:sendTextMessage(MESSAGE_EVENT_ADVANCE, "You have to wait before facing King Zelos again.")
		return false
	end

	return true
end

-- Snapshot of the most recent onUseExtra call's infoPositions, consumed synchronously by
-- createKingZelosEncounter() a few lines later in the same BossLever:onUse() call stack (Lua is
-- single-threaded and this all happens within one synchronous lever pull, so a plain local is safe -
-- no addEvent/coroutine boundary crosses between the two).
local lastInfoPositions = nil

-- ================================================================
-- RISEN SOLDIERS (executor contract, section 23)
-- ================================================================
-- Confirmed absent from the repository before this pass: monster/quests/grave_danger/risen_soldier.lua
-- already defines the monster, but nothing spawned or maintained it anywhere.
local RISEN_SOLDIER_POSITIONS = {
	Position(33438, 31545, 13),
	Position(33443, 31540, 13),
	Position(33448, 31545, 13),
}

local risenSoldierMaintenance

local function attemptRisenSoldierSpawn(token, index, retriesLeft)
	retriesLeft = retriesLeft or 3
	if not KingZelosRunIsCurrent(token) then
		return
	end
	local pos = RISEN_SOLDIER_POSITIONS[index] or KING_ZELOS_POSITION
	local soldier = Game.createMonster("Risen Soldier", pos, false, true)
	if soldier then
		KingZelosRunTrackMonster(soldier)
		return
	end
	if retriesLeft > 0 then
		KingZelosRunTrackEvent(token, addEvent(attemptRisenSoldierSpawn, 2000, token, index, retriesLeft - 1))
		return
	end
	-- Risen Soldiers are a recurring hazard, not a mandatory phase-gating entity like the wing
	-- bosses - exhausting bounded retries here does not technical-abort the run, only logs; the
	-- periodic maintenance check below will try this slot again on its next pass.
	logger.error("GraveDanger/KingZelos: Risen Soldier failed to spawn at slot {} (retries exhausted)", index)
end

risenSoldierMaintenance = function(token)
	if not KingZelosRunIsCurrent(token) then
		return
	end
	local alive = 0
	for monsterId in pairs(KingZelosRun.monsters) do
		local monster = Creature(monsterId)
		if monster and monster:getName():lower() == "risen soldier" then
			alive = alive + 1
		end
	end
	for i = alive + 1, 3 do
		attemptRisenSoldierSpawn(token, i, 3)
	end
	KingZelosRunTrackEvent(token, addEvent(risenSoldierMaintenance, 15 * 1000, token))
end

-- CORRECTION (executor contract, section 15): mechanically confirmed via data/libs/functions/
-- boss_lever.lua that Zone:removeMonsters() runs immediately after Lever:checkConditions() succeeds
-- and BEFORE the generic self.bossPosition/self.monsters creation block - so any monster created
-- inside onUseExtra (which runs DURING checkConditions()) would be destroyed by that same
-- removeMonsters() call moments later. boss_lever.lua also already exposes a purpose-built hook for
-- exactly this ordering problem: config.boss.createFunction, invoked AFTER removeMonsters() as
-- "if not self.createBoss() then return true end" - a false return aborts the lever immediately,
-- before Lever:teleportPlayers()/setCooldownAllPlayers() ever run. Using that existing hook (rather
-- than the unverified self.bossPosition/self.monsters paths) makes the mandatory King Zelos + four
-- wing-boss creation fully transactional without editing the shared boss_lever.lua framework.
local function createKingZelosEncounter()
	if KingZelosRun.active then
		logger.error("GraveDanger/KingZelos: a run is already active, refusing a second concurrent start")
		return false
	end

	local zelos = createMonsterVerified("King Zelos", KING_ZELOS_POSITION, 3)
	if not zelos then
		logger.error("GraveDanger/KingZelos: technical abort - King Zelos failed to spawn")
		return false
	end

	local wings = {}
	for key, wing in pairs(WING_MONSTERS) do
		local monster = createMonsterVerified(wing.name, wing.pos, 3)
		if not monster then
			logger.error("GraveDanger/KingZelos: technical abort - {} failed to spawn", wing.name)
			zelos:remove()
			for _, spawned in pairs(wings) do
				spawned:remove()
			end
			return false
		end
		wings[key] = monster
	end

	KingZelosRun.token = KingZelosRun.token + 1
	local token = KingZelosRun.token
	KingZelosRun.active = true
	KingZelosRun.startTime = os.time()
	KingZelosRun.participants = {}
	KingZelosRun.events = {}
	KingZelosRun.monsters = {}
	KingZelosRun.wings = { redKnight = false, nargol = false, magnor = false, rewar = false }
	KingZelosRun.hex = {}

	if lastInfoPositions then
		for _, posInfo in pairs(lastInfoPositions) do
			local player = posInfo.creature
			if player and player:isPlayer() then
				KingZelosRun.participants[player:getId()] = true
			end
		end
	end

	-- zelos_damage/grave_danger_death are already declared in king_zelos.lua's monster.events and
	-- are auto-registered by the monster type loader - re-registering them here would double-fire
	-- both the ritual damage scaling and the death/credit handler on every trigger.
	KingZelosRunTrackMonster(zelos)
	for _, monster in pairs(wings) do
		KingZelosRunTrackMonster(monster)
	end

	Game.setStorageValue(Storage.Quest.U12_20.GraveDanger.KingZelosRitualStart, os.time())
	KingZelosRunTrackEvent(token, addEvent(kingZelosPhaseTimeout, 24 * 60 * 1000, token))
	risenSoldierMaintenance(token)
	return true
end

local config = {
	boss = {
		name = "King Zelos",
		-- No `position` field: King Zelos is created transactionally by createFunction below, not by
		-- BossLever's generic unverified self.bossPosition path.
		createFunction = createKingZelosEncounter,
	},
	requiredLevel = 250,
	playerPositions = {
		{ pos = Position(33485, 31546, 13), teleport = Position(33443, 31554, 13), effect = CONST_ME_TELEPORT },
		{ pos = Position(33485, 31547, 13), teleport = Position(33443, 31554, 13), effect = CONST_ME_TELEPORT },
		{ pos = Position(33485, 31548, 13), teleport = Position(33443, 31554, 13), effect = CONST_ME_TELEPORT },
		{ pos = Position(33485, 31545, 13), teleport = Position(33443, 31554, 13), effect = CONST_ME_TELEPORT },
		{ pos = Position(33485, 31544, 13), teleport = Position(33443, 31554, 13), effect = CONST_ME_TELEPORT },
		{ pos = Position(33486, 31546, 13), teleport = Position(33443, 31554, 13), effect = CONST_ME_TELEPORT },
		{ pos = Position(33486, 31547, 13), teleport = Position(33443, 31554, 13), effect = CONST_ME_TELEPORT },
		{ pos = Position(33486, 31548, 13), teleport = Position(33443, 31554, 13), effect = CONST_ME_TELEPORT },
		{ pos = Position(33486, 31545, 13), teleport = Position(33443, 31554, 13), effect = CONST_ME_TELEPORT },
		{ pos = Position(33486, 31544, 13), teleport = Position(33443, 31554, 13), effect = CONST_ME_TELEPORT },
	},
	-- The source gives a hard 24-minute limit from pulling the lever. Without this the shared
	-- BossLever default (BOSS_DEFAULT_TIME_TO_DEFEAT, 20 minutes) applied silently. This is the
	-- framework's own generic room/player-kick timeout; KingZelosRun's own kingZelosPhaseTimeout
	-- (above) fires on the same 24-minute mark to clean up this file's run-state, Greater Hex, and
	-- owned-monster tracking, which the generic framework timeout knows nothing about.
	timeToDefeat = 24 * 60,
	-- specPos covers the full arena bounds (central room + all four wing rooms), so BossLever's own
	-- room cleanup on wipe/timeout also reaches the wing bosses.
	specPos = {
		from = Position(33414, 31520, 13),
		to = Position(33474, 31574, 13),
	},
	exit = Position(32172, 31918, 8),
	-- CORRECTION (executor contract, section 5): independent, fail-closed per-participant
	-- verification. Premium/12-grave/Jack-Springer-stage/access-storage/cooldown are no longer
	-- implied solely by the far-away Isle of Kings map door - the lever itself now refuses anyone
	-- who does not independently qualify. Level 250 is already enforced generically above via
	-- requiredLevel. onUseExtra also captures infoPositions for createKingZelosEncounter() to
	-- consume once checkConditions() succeeds for the whole roster.
	onUseExtra = function(creature, infoPositions)
		lastInfoPositions = infoPositions
		return validateParticipant(creature)
	end,
}

local lever = BossLever(config)
lever:position(Position(33484, 31546, 13))
lever:register()
