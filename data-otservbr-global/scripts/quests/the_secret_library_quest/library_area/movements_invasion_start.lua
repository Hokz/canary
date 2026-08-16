-- Secret Library final invasion ("Scourge of Oblivion") - sequential wing orchestration.
--
-- CORRECTION (Secret Library repair v2, sections 21/24-28; corrective repair pass, section 5): the
-- run/ownership object (SecretLibraryInvasionRun) and the lever itself now live in
-- actions_the_scourge_of_oblivion.lua. This file previously started ALL FOUR wings simultaneously in
-- one loop (startWaves()) with zero ownership - any monster sharing a wing boss's name anywhere on
-- the map could set that wing's "Defeated" flag. Rebuilt as an event-driven sequential state machine:
-- central wave round 1 -> NE Spellstealer -> central wave round 2 -> SE Scion of Havoc -> central wave
-- round 3 -> SW Brothers Chill & Freeze -> central wave round 4 -> NW Devourer of Secrets -> central
-- wave round 5 -> Scourge activation, each wing's mandatory boss(es) transactionally spawned and
-- exact-id-owned, advancing only once the CURRENT wing's own owned boss(es) are confirmed dead - never
-- while a required prior wing remains incomplete.
--
-- MAP SETUP REQUIRED (unchanged from the pre-existing disclosure this repair inherited): none of the 4
-- wing rooms have real coordinates anywhere in the source (only directional/narrative description) or
-- in the repository (these 5 boss monsters had zero spawn wiring before the original pass). All wing
-- positions below remain nil pending owner map data - see the Map Setup Contract / Manual RME Manifest
-- in the PR body. InvasionMapReady() (used by the lever's onUseExtra) mechanically refuses to start the
-- encounter at all while any of them are missing - MAP_REQUIRED, not a guessed rectangle, and not an
-- inert 26-minute encounter that can never finish.
local centralHall = Position(32726, 32733, 11) -- real - the lever's own teleport destination
local Invasion = Storage.Quest.U11_80.TheSecretLibrary.SecretLibraryInvasion

-- CUSTOM_GLOBAL_LIKE_PENDING_EXACT_TIMING: no exact inter-wing gap is given by the reference - a
-- stable functional delay, not claimed Global-exact.
local WING_TRANSITION_DELAY = 30 * 1000

-- ================================================================
-- CENTRAL HALL RAID WAVES (Secret Library corrective repair pass, section 5)
-- ================================================================
-- CORRECTION: the previous pass replaced the central-hall invasion phases described by the current
-- reliable reference with a breach message plus a fixed transition delay - no central-hall creatures
-- ever appeared. Current reference: players enter the central hall, invasion creatures begin
-- appearing about 1 minute after entry, continue until a wing is breached, and after each wing dies
-- players return to the central hall for a new attack wave before the next wing breach - the
-- encounter alternates central-hall attack phases and the four wing bosses. After the Spellstealer
-- wing, Invading Demons are added to the central attack. The central raid creature family (per the
-- reference and the monster types already defined in this repository, none invented here): Imp
-- Intruder, Invading Demon, Ravenous Beyondling, Rift Breacher, Rift Minion, Rift Spawn, Yalahari
-- Despoiler.
--
-- CUSTOM_GLOBAL_LIKE_PENDING_EXACT_COUNT / _TIMING: no exact per-round roster beyond "Invading Demons
-- are added after Spellstealer" is given, and no exact wave duration/despawn timing is given either
-- (only "about 1 minute" for the very first appearance). This is a disclosed, escalating
-- approximation - not claimed Global-exact - matching the one confirmed escalation point (Invading
-- Demon appearing from round 2 onward) and otherwise adding one more established central-raid
-- monster type per round so the final (5th, pre-Scourge) round uses the full roster.
local CENTRAL_WAVE_DURATION = 60 * 1000

local CENTRAL_WAVE_ROSTERS = {
	{ "Imp Intruder", "Rift Minion", "Rift Spawn" },
	{ "Imp Intruder", "Rift Minion", "Rift Spawn", "Invading Demon" },
	{ "Imp Intruder", "Rift Minion", "Rift Spawn", "Invading Demon", "Rift Breacher" },
	{ "Imp Intruder", "Rift Minion", "Rift Spawn", "Invading Demon", "Rift Breacher", "Ravenous Beyondling" },
	{ "Imp Intruder", "Rift Minion", "Rift Spawn", "Invading Demon", "Rift Breacher", "Ravenous Beyondling", "Yalahari Despoiler" },
}

-- CUSTOM_GLOBAL_LIKE_PENDING_EXACT_POSITION: these 7 tiles are physically PROVEN_PRESENT (real,
-- walkable central-hall floor - confirmed against the exact configured otservbr.otbm this pass, see
-- docs/ai-dev/quests/packages/secret-library/03_SECRET_LIBRARY_CORRECTIVE_REPAIR_PASS.md), not
-- guessed void/wall tiles - but the exact CipSoft spawn SQMs are not proven, so these are a disclosed,
-- reasonable choice among many equally-valid real floor tiles inside the already-proven central hall.
local CENTRAL_WAVE_POSITIONS = {
	Position(32716, 32729, 11),
	Position(32723, 32729, 11),
	Position(32730, 32729, 11),
	Position(32737, 32729, 11),
	Position(32722, 32730, 11),
	Position(32729, 32730, 11),
	Position(32736, 32730, 11),
}

-- CORRECTION (section 39): best-effort ambient spawn (not mandatory - the central wave is flavor
-- combat, not a progression gate the way a wing boss is), but still fully generation-owned so a
-- stale clear callback from an earlier round can never touch a later one. Returns the generation this
-- spawn committed, so the caller's own end-of-round clear can verify it is clearing the round it
-- itself started (not a newer one that started in the meantime, which cannot happen on this single
-- sequential timeline but is guarded anyway for consistency with this project's other owned-entity
-- sets).
local function spawnCentralWave(token, roundIndex)
	if not SecretLibraryInvasionRunIsCurrent(token) then
		return nil
	end
	local roster = CENTRAL_WAVE_ROSTERS[math.min(roundIndex, #CENTRAL_WAVE_ROSTERS)]
	SecretLibraryInvasionRun.centralWaveGeneration = SecretLibraryInvasionRun.centralWaveGeneration + 1
	local generation = SecretLibraryInvasionRun.centralWaveGeneration
	SecretLibraryInvasionRun.centralWaveCreatureIds = {}
	for i, name in ipairs(roster) do
		local pos = CENTRAL_WAVE_POSITIONS[((i - 1) % #CENTRAL_WAVE_POSITIONS) + 1]
		local monster = Game.createMonster(name, pos, true, true)
		if monster then
			SecretLibraryInvasionRun.centralWaveCreatureIds[monster:getId()] = true
		end
	end
	return generation
end

local function clearCentralWave(generation)
	if SecretLibraryInvasionRun.centralWaveGeneration ~= generation then
		return
	end
	for creatureId in pairs(SecretLibraryInvasionRun.centralWaveCreatureIds) do
		local monster = Creature(creatureId)
		if monster then
			monster:remove()
		end
	end
	SecretLibraryInvasionRun.centralWaveCreatureIds = {}
end

-- Global: called once per central-wave round (1..4 precede a wing breach, round 5 precedes Scourge
-- activation). Invoked from the lever's initial delay (round 1) and from InvasionWingBossDied (every
-- subsequent round).
function InvasionStartCentralWaveRound(token, roundIndex)
	if not SecretLibraryInvasionRunIsCurrent(token) then
		return
	end
	-- CORRECTION (phase-state correction pass): central combat is authoritative again the instant a
	-- round actually starts (central_intro/wing_transition -> central_wave) - central-zone emptiness
	-- becomes a valid abandonment signal from this exact point, not only once the next wing begins.
	SecretLibraryInvasionRun.phase = "central_wave"
	for _, spectator in ipairs(Game.getSpectators(centralHall, false, true, 15, 15, 15, 15)) do
		if roundIndex == 1 then
			spectator:sendTextMessage(MESSAGE_EVENT_ADVANCE, "The central hall shudders as the invasion begins!")
		else
			spectator:sendTextMessage(MESSAGE_EVENT_ADVANCE, "The invaders press their attack on the central hall once more!")
		end
	end
	local generation = spawnCentralWave(token, roundIndex)
	SecretLibraryInvasionRunTrackEvent(
		token,
		addEvent(function()
			if not SecretLibraryInvasionRunIsCurrent(token) then
				return
			end
			clearCentralWave(generation)
			if roundIndex <= 4 then
				InvasionAdvanceWing(token, roundIndex)
			else
				InvasionActivateScourge(token)
			end
		end, CENTRAL_WAVE_DURATION)
	)
end

local WINGS = {
	{
		key = "spellstealer",
		breachMessage = "THE NORTH EASTERN WING HAS BEEN BREACHED! RUSH TO CRUSH THE INTRUDERS!",
		monsters = { "The Spellstealer" },
		roomCenter = nil, -- Position, MAP SETUP REQUIRED (northeast wing)
		spawnPositions = {}, -- list of Position, MAP SETUP REQUIRED
		greenTeleport = nil, -- Position, MAP SETUP REQUIRED (northwest part of the wing room)
		redTeleport = nil, -- Position, MAP SETUP REQUIRED (southeast part of the wing room)
		defeatedStorage = Invasion.SpellstealerDefeated,
	},
	{
		key = "scionOfHavoc",
		breachMessage = "THE SOUTH EASTERN WING HAS BEEN BREACHED! RUSH TO CRUSH THE INTRUDERS!",
		monsters = { "The Scion of Havoc" },
		addMonsters = { "Spawn of Havoc" },
		roomCenter = nil, -- MAP SETUP REQUIRED (southeast wing)
		spawnPositions = {},
		addSpawnPositions = {},
		defeatedStorage = Invasion.ScionOfHavocDefeated,
	},
	{
		key = "brothers",
		breachMessage = "THE SOUTH WESTERN WING HAS BEEN BREACHED! RUSH TO CRUSH THE INTRUDERS!",
		monsters = { "Brother Chill", "Brother Freeze" },
		roomCenter = nil, -- MAP SETUP REQUIRED (southwest wing)
		spawnPositions = {},
		defeatedStorage = Invasion.BrothersDefeated,
	},
	{
		key = "devourer",
		breachMessage = "THE NORTH WESTERN WING HAS BEEN BREACHED! RUSH TO CRUSH THE INTRUDERS!",
		monsters = { "The Devourer of Secrets" },
		addMonsters = { "The Book of Secrets", "Stolen Tome of Portals" },
		roomCenter = nil, -- MAP SETUP REQUIRED (northwest wing)
		spawnPositions = {},
		addSpawnPositions = {},
		defeatedStorage = Invasion.DevourerDefeated,
	},
}

-- Global (not local): called from the lever's onUseExtra (actions_the_scourge_of_oblivion.lua) before
-- any irreversible commit.
function InvasionMapReady()
	for _, wing in ipairs(WINGS) do
		if not wing.roomCenter or not wing.spawnPositions or #wing.spawnPositions == 0 then
			return false, wing.key
		end
		if wing.key == "spellstealer" and (not wing.greenTeleport or not wing.redTeleport) then
			return false, wing.key
		end
	end
	return true
end

-- CORRECTION (section 39): validate -> create the wing's full mandatory-entity generation -> verify ->
-- commit ownership. A wing boss is mandatory (progression cannot continue without it); adds are
-- flavor/mechanic, spawned best-effort and ownership-tagged, never gating completion themselves.
local function spawnWingTransactional(wing, token, retriesLeft)
	retriesLeft = retriesLeft or 3
	if not SecretLibraryInvasionRunIsCurrent(token) then
		return
	end

	local spawned = {}
	local allOk = true
	for i, name in ipairs(wing.monsters) do
		local pos = wing.spawnPositions[i] or wing.spawnPositions[1]
		if not pos then
			allOk = false
			break
		end
		local monster = Game.createMonster(name, pos, false, true)
		if monster then
			table.insert(spawned, monster)
		else
			allOk = false
		end
	end

	if not allOk then
		for _, monster in ipairs(spawned) do
			monster:remove()
		end
		logger.error("SecretLibrary/Invasion: wing '{}' mandatory boss(es) failed to fully spawn (retries left: {})", wing.key, retriesLeft)
		if retriesLeft > 0 then
			SecretLibraryInvasionRunTrackEvent(token, addEvent(spawnWingTransactional, 1000, wing, token, retriesLeft - 1))
		else
			SecretLibraryInvasionRunTerminate(token, "technical_abort", "wing '" .. wing.key .. "' mandatory boss(es) failed to spawn after bounded retries")
		end
		return
	end

	SecretLibraryInvasionRun.wingGeneration = SecretLibraryInvasionRun.wingGeneration + 1
	if wing.key == "brothers" then
		SecretLibraryInvasionRun.wingBossIds.brothers = { chill = spawned[1]:getId(), freeze = spawned[2]:getId() }
		SecretLibraryInvasionRun.brothersAlive = { chill = true, freeze = true }
	else
		SecretLibraryInvasionRun.wingBossIds[wing.key] = spawned[1]:getId()
	end
	SecretLibraryInvasionRun.wingAddIds[wing.key] = {}
	SecretLibraryInvasionRun.wingDefeated[wing.key] = false

	for _, position in ipairs(wing.addSpawnPositions or {}) do
		for _, name in ipairs(wing.addMonsters or {}) do
			local add = Game.createMonster(name, position, true, true)
			if add then
				SecretLibraryInvasionRun.wingAddIds[wing.key][add:getId()] = true
			end
		end
	end
end

-- Global: called once per wing start (index 1..4).
function InvasionAdvanceWing(token, index)
	if not SecretLibraryInvasionRunIsCurrent(token) then
		return
	end
	local wing = WINGS[index]
	if not wing then
		return
	end
	SecretLibraryInvasionRun.phase = "wing"
	SecretLibraryInvasionRun.wingIndex = index
	for _, spectator in ipairs(Game.getSpectators(centralHall, false, true, 15, 15, 15, 15)) do
		spectator:sendTextMessage(MESSAGE_EVENT_ADVANCE, wing.breachMessage)
	end
	spawnWingTransactional(wing, token)
end

-- Global: called from InvasionStartCentralWaveRound once the 5th (final, post-wing-4) central wave
-- round ends.
function InvasionActivateScourge(token)
	if not SecretLibraryInvasionRunIsCurrent(token) then
		return
	end
	local dormant = Creature(SecretLibraryInvasionRun.scourgeCreatureId)
	if not dormant or not SecretLibraryInvasionRunOwnsScourge(dormant) then
		SecretLibraryInvasionRunTerminate(token, "technical_abort", "the dormant Scourge of Oblivion could not be found for activation")
		return
	end
	local oldHealth = dormant:getHealth()
	dormant:setType("The Scourge of Oblivion")
	dormant:addHealth(-(dormant:getHealth() - oldHealth))
	SecretLibraryInvasionRun.phase = "scourge"
	for _, player in ipairs(Game.getSpectators(centralHall, false, true, 15, 15, 15, 15)) do
		player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "The Leader of the invasion finally joins the battle! Beware, the Scourge of Oblivion enters the fray!")
	end
end

-- Global: called from creaturescripts_invasion_wings.lua's per-wing onDeath handlers when the current
-- run's exact owned wing boss(es) are confirmed dead - never on a stale/foreign monster of the same
-- name, and never while a prior required wing remains incomplete (this is only ever invoked for the
-- CURRENT wingIndex's own key).
function InvasionWingBossDied(token, key)
	if not SecretLibraryInvasionRunIsCurrent(token) then
		return
	end
	local wing = WINGS[SecretLibraryInvasionRun.wingIndex]
	if not wing or wing.key ~= key or SecretLibraryInvasionRun.wingDefeated[key] then
		return
	end
	SecretLibraryInvasionRun.wingDefeated[key] = true
	Game.setStorageValue(wing.defeatedStorage, 1)

	-- CORRECTION (phase-state correction pass): wing -> wing_transition. Players are still walking
	-- back from the wing room to the central hall for the WING_TRANSITION_DELAY grace period below -
	-- central-zone emptiness must remain tolerated through that walk, but the ambiguous "still wing"
	-- label (which previously also silently covered the following central-wave round) is now scoped
	-- to only this grace window; InvasionStartCentralWaveRound moves it to "central_wave" the instant
	-- central combat actually becomes authoritative again.
	SecretLibraryInvasionRun.phase = "wing_transition"

	for creatureId in pairs(SecretLibraryInvasionRun.wingAddIds[key] or {}) do
		local monster = Creature(creatureId)
		if monster then
			monster:remove()
		end
	end

	-- CORRECTION (section 5): the next phase is always another central-hall raid round (round
	-- nextIndex) before the next wing breach (or, for nextIndex == 5, before Scourge activation) -
	-- never a direct jump straight to the next wing/Scourge the way the previous pass did.
	local nextIndex = SecretLibraryInvasionRun.wingIndex + 1
	SecretLibraryInvasionRunTrackEvent(token, addEvent(InvasionStartCentralWaveRound, WING_TRANSITION_DELAY, token, nextIndex))
end

-- The Spellstealer's colored-phase teleports. Registered unconditionally on nil positions currently
-- has no effect - MoveEvent:position(nil) would error, so these are guarded and simply skipped until
-- the wing room (and therefore these two tiles) exist.
local spellstealerWing = WINGS[1]
if spellstealerWing.greenTeleport and spellstealerWing.redTeleport then
	local colorTeleports = MoveEvent()
	function colorTeleports.onStepIn(creature, item, position, fromPosition)
		local token = SecretLibraryInvasionRunCurrentToken()
		local monster = creature:getMonster()
		if not monster or not token or not SecretLibraryInvasionRunOwnsWingBoss("spellstealer", monster) then
			return true
		end
		local name = monster:getName():lower()
		local matches = (name == "the spellstealer (green)" and position == spellstealerWing.greenTeleport) or (name == "the spellstealer (red)" and position == spellstealerWing.redTeleport)
		if not matches then
			return true
		end
		local oldHealth = monster:getHealth()
		monster:setType("The Spellstealer")
		monster:addHealth(-(monster:getHealth() - oldHealth))
		position:sendMagicEffect(CONST_ME_MAGIC_BLUE)
		for _, spectator in ipairs(Game.getSpectators(position, false, true, 10, 10, 10, 10)) do
			spectator:sendTextMessage(MESSAGE_EVENT_ADVANCE, "The Spellstealer is drained of its stolen energy and becomes vulnerable again!")
		end
		return true
	end
	colorTeleports:position(spellstealerWing.greenTeleport)
	colorTeleports:position(spellstealerWing.redTeleport)
	colorTeleports:register()
end
