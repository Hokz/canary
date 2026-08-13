local nictrosPosition = Position(33427, 31428, 13)
local baelocPosition = Position(33422, 31428, 13)
local EXIT_POSITION = Position(33290, 32474, 9)
local ROOM_FROM = Position(33414, 31426, 13)
local ROOM_TO = Position(33433, 31449, 13)

local healthStates = {
	nictros60 = false,
	baeloc60 = false,
}

-- ================================================================
-- NICTROS/BAELOC RUN OWNERSHIP (executor contract, section 12; correction pass section A/H/N/O;
-- lifecycle closure pass section A/C)
-- ================================================================
local NictrosBaelocRun = {
	token = 0,
	active = false,
	nictrosId = nil, -- the one Sir Nictros instance this run owns
	baelocId = nil, -- the one Sir Baeloc instance this run owns
	participants = {}, -- set: playerId -> true
	timerWritten = {}, -- set: playerId -> true (this attempt wrote Bosses.BaelocNictros.Timer for them)
	events = {}, -- set: eventId -> true
	-- CORRECTION (lifecycle closure pass section C): explicit per-brother death flags, replacing the
	-- previous "is either Creature(id) still resolvable" check. A dying creature is not guaranteed to
	-- have already disappeared from the global creature registry during the execution of its OWN
	-- onDeath callback - relying on that as the completion signal is fragile. These are the
	-- authoritative signal instead, set directly by nictros_baeloc_success below off exactly which
	-- owned id died.
	nictrosDead = false,
	baelocDead = false,
}

local function trackEvent(token, eventId)
	if NictrosBaelocRun.active and NictrosBaelocRun.token == token and eventId then
		NictrosBaelocRun.events[eventId] = true
	end
end

local function isCurrent(token)
	return token ~= nil and token > 0 and NictrosBaelocRun.active and NictrosBaelocRun.token == token
end

-- Bare globals so BossHealthCheck/nictros_baeloc_success (further below and in creaturescripts_
-- boss_kill.lua) and the Lesser Hex handler can read run state.
NictrosBaelocRunIsActive = function()
	return NictrosBaelocRun.active
end

function NictrosBaelocRunCurrentToken()
	if NictrosBaelocRun.active then
		return NictrosBaelocRun.token
	end
	return nil
end

-- CORRECTION (section H): true if either boss belongs to the current run.
function NictrosBaelocRunOwnsBoss(creature)
	if not creature or not NictrosBaelocRun.active then
		return false
	end
	local id = creature:getId()
	return id == NictrosBaelocRun.nictrosId or id == NictrosBaelocRun.baelocId
end

function NictrosBaelocRunIsParticipant(token, playerId)
	return isCurrent(token) and NictrosBaelocRun.participants[playerId] == true
end

function NictrosBaelocRunMarkTimerWritten(token, playerId)
	if isCurrent(token) then
		NictrosBaelocRun.timerWritten[playerId] = true
	end
end

local function isInsideRoom(player)
	local pos = player:getPosition()
	return pos.x >= ROOM_FROM.x and pos.x <= ROOM_TO.x and pos.y >= ROOM_FROM.y and pos.y <= ROOM_TO.y and pos.z == ROOM_FROM.z
end

-- CORRECTION (lifecycle closure pass section A/C2): non-success termination (technical_abort/
-- normal_timeout) still closes BossLever's own internal state directly, since this two-boss encounter
-- has no single natural death to trigger a framework BossLeverOnDeath from in those cases either.
-- Order matches BossLever's own generic timeout callback exactly (refresh, then remove players, then
-- clean) so a normal_timeout racing ahead of and cancelling BossLever's own timeoutEvent cannot leave
-- players stranded in an already-cleaned room. SUCCESS is handled entirely separately by
-- completePairSuccess below, which preserves the framework's own post-victory grace period instead of
-- cleaning immediately.
local function terminateRun(kind, reason)
	if not NictrosBaelocRun.active then
		return
	end
	local token = NictrosBaelocRun.token
	logger.info("GraveDanger/NictrosBaeloc: run {} terminated ({}) - {}", token, kind, reason or "")

	NictrosBaelocRun.active = false
	for eventId in pairs(NictrosBaelocRun.events) do
		stopEvent(eventId)
	end

	if kind == "technical_abort" then
		for playerId in pairs(NictrosBaelocRun.participants) do
			local player = Player(playerId)
			if player then
				player:setBossCooldown("sir nictros", 0)
				if NictrosBaelocRun.timerWritten[playerId] then
					player:setStorageValue(Storage.Quest.U12_20.GraveDanger.Bosses.BaelocNictros.Timer, 0)
				end
			end
		end
	end

	local nictros = Creature(NictrosBaelocRun.nictrosId)
	if nictros then
		nictros:remove()
	end
	local baeloc = Creature(NictrosBaelocRun.baelocId)
	if baeloc then
		baeloc:remove()
	end

	local bossLever = BossLever["sir nictros"]
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

	healthStates.nictros60 = false
	healthStates.baeloc60 = false
	NictrosBaelocRun.nictrosId = nil
	NictrosBaelocRun.baelocId = nil
	NictrosBaelocRun.participants = {}
	NictrosBaelocRun.timerWritten = {}
	NictrosBaelocRun.events = {}
	NictrosBaelocRun.nictrosDead = false
	NictrosBaelocRun.baelocDead = false
end

-- CORRECTION (lifecycle closure pass section C2): both owned brothers are confirmed dead - grant
-- legitimate credit FIRST (while the run is still active, so room-presence/participant checks read
-- correctly), then invalidate the run and stop its own owned events, THEN manually preserve the
-- equivalent of BossLever's own post-victory grace (bossAlive/timeoutEvent/emptyRoomEvent handling,
-- the timeAfterKill leave window) instead of cleaning the zone immediately - this two-boss encounter
-- has no single boss death BossLeverOnDeath could correctly fire from to get that behavior for free.
local function completePairSuccess(reason)
	if not NictrosBaelocRun.active then
		return
	end
	local token = NictrosBaelocRun.token
	logger.info("GraveDanger/NictrosBaeloc: run {} terminated (success) - {}", token, reason or "")

	-- CORRECTION (section C1): Darashia credit belongs to the PAIR's completion, not to Baeloc dying
	-- first while Nictros still lives. Granted here, once, to every legitimate current-run participant
	-- still physically present - never through creaturescripts_boss_kill.lua's generic damage-map path.
	for playerId in pairs(NictrosBaelocRun.participants) do
		local player = Player(playerId)
		if player and player:getLevel() >= 250 and player:isPremium() and player:getStorageValue(Storage.Quest.U12_20.GraveDanger.Questline) >= 1 and isInsideRoom(player) then
			if player:getStorageValue(Storage.Quest.U12_20.GraveDanger.Bosses.BaelocNictros.Killed) < 1 then
				player:setStorageValue(Storage.Quest.U12_20.GraveDanger.Bosses.BaelocNictros.Killed, 1)
				player:setStorageValue(Storage.Quest.U12_20.GraveDanger.Graves.Darashia, 1)
				local graves = math.max(player:getStorageValue(Storage.Quest.U12_20.GraveDanger.Graves.Progress), 0)
				player:setStorageValue(Storage.Quest.U12_20.GraveDanger.Graves.Progress, graves + 1)
			end
		end
	end

	NictrosBaelocRun.active = false
	for eventId in pairs(NictrosBaelocRun.events) do
		stopEvent(eventId)
	end

	local bossLever = BossLever["sir nictros"]
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
		-- CORRECTION (section C2): replicates boss_lever_death.lua's own BossLeverOnDeath grace-period
		-- behavior manually - the framework event has no way to fire correctly for a two-boss
		-- encounter, so this preserves the same player-facing leave window instead of wiping the room
		-- the instant the second brother dies.
		if bossLever.timeAfterKill > 0 then
			zone:sendTextMessage(MESSAGE_EVENT_ADVANCE, "Sir Nictros and Sir Baeloc have been defeated. You have " .. bossLever.timeAfterKill .. " seconds to leave the room.")
			bossLever.timeoutEvent = addEvent(function(zn)
				zn:refresh()
				zn:cleanRoom()
				zn:removePlayers()
			end, bossLever.timeAfterKill * 1000, zone)
		else
			zone:refresh()
			zone:cleanRoom()
		end
	end

	healthStates.nictros60 = false
	healthStates.baeloc60 = false
	NictrosBaelocRun.nictrosId = nil
	NictrosBaelocRun.baelocId = nil
	NictrosBaelocRun.participants = {}
	NictrosBaelocRun.timerWritten = {}
	NictrosBaelocRun.events = {}
	NictrosBaelocRun.nictrosDead = false
	NictrosBaelocRun.baelocDead = false
end

-- CORRECTION (section H): previously no watchdog existed at all - a timed-out or emptied attempt left
-- NictrosBaelocRun.active stuck true forever (only the both-dead success path ever cleared it),
-- permanently blocking every future Nictros/Baeloc attempt. Mirrors the fix already applied to Count
-- Vlarkorth/Lord Azaram/Earl Osam.
local function watchEmptyRoom(token)
	if not isCurrent(token) then
		return
	end
	local zone = Zone("boss." .. toKey("sir nictros"))
	if zone and zone:countPlayers() == 0 then
		terminateRun("normal_timeout", "room emptied before the encounter concluded")
		return
	end
	trackEvent(token, addEvent(watchEmptyRoom, 20 * 1000, token))
end

-- CORRECTION (section A): the lever now independently verifies Premium and that the Lich line has
-- actually been started for every occupied platform position.
local function validateParticipant(creature)
	if not creature or not creature:isPlayer() then
		return true
	end
	if not creature:isPremium() then
		creature:sendTextMessage(MESSAGE_EVENT_ADVANCE, "You need a premium account to face Sir Nictros and Sir Baeloc.")
		return false
	end
	if creature:getStorageValue(Storage.Quest.U12_20.GraveDanger.Questline) < 1 then
		creature:sendTextMessage(MESSAGE_EVENT_ADVANCE, "You have not yet started this quest.")
		return false
	end
	return true
end

-- CORRECTION (executor contract, section 12; correction pass section H): mandatory bounded-verified
-- creation of BOTH bosses was already correctly implemented here (config.boss.createFunction) -
-- unchanged in that respect. Now also establishes bossId ownership for both bosses and schedules the
-- narrative dialogue chain (moved out of onUseExtra - see the note on the old onUseExtra below) and
-- the run's own watchdog timers only once the run is genuinely active.
local config = {
	boss = {
		name = "Sir Nictros",
		createFunction = function()
			if NictrosBaelocRun.active then
				logger.error("GraveDanger/NictrosBaeloc: a run is already active, refusing a second concurrent start")
				return false
			end

			local nictros = Game.createMonster("Sir Nictros", nictrosPosition, true, true)
			local baeloc = Game.createMonster("Sir Baeloc", baelocPosition, true, true)

			if nictros then
				nictros:registerEvent("BossHealthCheck")
				-- Start with Nictros active
				nictros:setMoveLocked(false)
			end
			if baeloc then
				-- Start with Baeloc locked
				baeloc:setMoveLocked(true)
				baeloc:registerEvent("BossHealthCheck")
			end

			if not (nictros and baeloc) then
				if nictros then
					nictros:remove()
				end
				if baeloc then
					baeloc:remove()
				end
				return false
			end

			healthStates.nictros60 = false
			healthStates.baeloc60 = false
			NictrosBaelocRun.token = NictrosBaelocRun.token + 1
			local token = NictrosBaelocRun.token
			NictrosBaelocRun.active = true
			NictrosBaelocRun.nictrosId = nictros:getId()
			NictrosBaelocRun.baelocId = baeloc:getId()
			NictrosBaelocRun.participants = {}
			NictrosBaelocRun.timerWritten = {}
			NictrosBaelocRun.events = {}
			NictrosBaelocRun.nictrosDead = false
			NictrosBaelocRun.baelocDead = false

			if config.lastInfoPositions then
				for _, posInfo in pairs(config.lastInfoPositions) do
					local player = posInfo.creature
					if player and player:isPlayer() then
						NictrosBaelocRun.participants[player:getId()] = true
					end
				end
			end

			trackEvent(
				token,
				addEvent(function()
					if not isCurrent(token) then
						return
					end
					local currentBaeloc = Creature(NictrosBaelocRun.baelocId)
					if currentBaeloc then
						currentBaeloc:say("Ah look my Brother! Challengers! After all this time finally a chance to prove our skills!")
						trackEvent(
							token,
							addEvent(function()
								if not isCurrent(token) then
									return
								end
								local currentNictros = Creature(NictrosBaelocRun.nictrosId)
								if currentNictros then
									currentNictros:say("Indeed! It has been a while! As the elder one I request the right of the first battle!")
								end
							end, 6 * 1000)
						)
					end

					trackEvent(
						token,
						addEvent(function()
							if not isCurrent(token) then
								return
							end
							local finalBaeloc = Creature(NictrosBaelocRun.baelocId)
							local finalNictros = Creature(NictrosBaelocRun.nictrosId)
							if finalBaeloc then
								finalBaeloc:say("Oh, man! You always get the fun!")
								finalBaeloc:setMoveLocked(true)
							end
							if finalNictros then
								finalNictros:teleportTo(Position(33426, 31437, 13))
								finalNictros:setMoveLocked(false)
							end
						end, 12 * 1000)
					)
				end, 4 * 1000)
			)

			trackEvent(
				token,
				addEvent(function()
					terminateRun("normal_timeout", "encounter time limit exceeded")
				end, configManager.getNumber(configKeys.BOSS_DEFAULT_TIME_TO_DEFEAT) * 1000)
			)
			trackEvent(token, addEvent(watchEmptyRoom, 20 * 1000, token))

			return true
		end,
	},
	requiredLevel = 250,
	playerPositions = {
		{ pos = Position(33424, 31413, 13), teleport = Position(33423, 31448, 13) },
		{ pos = Position(33425, 31413, 13), teleport = Position(33423, 31448, 13) },
		{ pos = Position(33426, 31413, 13), teleport = Position(33423, 31448, 13) },
		{ pos = Position(33427, 31413, 13), teleport = Position(33423, 31448, 13) },
		{ pos = Position(33428, 31413, 13), teleport = Position(33423, 31448, 13) },
	},
	specPos = {
		from = ROOM_FROM,
		to = ROOM_TO,
	},
	-- CORRECTION (section H): the narrative dialogue chain that used to be scheduled here (during
	-- Lever:checkConditions(), i.e. BEFORE the run is active) has moved into createFunction above,
	-- where trackEvent's `NictrosBaelocRun.active and NictrosBaelocRun.token == token` guard can
	-- actually succeed - previously it always evaluated against the STALE active/token state from the
	-- prior attempt (or the initial false), so trackEvent silently discarded every event id from this
	-- chain and none of it was ever cancellable by a terminate. Only the level/Premium/Questline
	-- validation and the infoPositions snapshot remain here, matching the King Zelos/Count Vlarkorth/
	-- Lord Azaram/Duke Krule onUseExtra pattern.
	onUseExtra = function(player, infoPositions)
		config.lastInfoPositions = infoPositions
		return validateParticipant(player)
	end,
	exit = EXIT_POSITION,
}

local lever = BossLever(config)
lever:position(Position(33423, 31413, 13))
lever:register()

local function getHealthPercentage(creature)
	local health = creature:getHealth()
	local maxHealth = creature:getMaxHealth()
	return (health / maxHealth) * 100
end

-- Ported from the dead creaturescripts_sir_baeloc_health.lua (removed - it was never registered on
-- either boss's monster.events, so it never actually ran). If the sibling is meaningfully healthier
-- (>5 percentage points) while this boss has dropped below 55%, this boss heals - the accepted
-- sibling-healing behavior the source describes, now on the one live health-change path.
local function siblingHeal(creature, siblingId)
	local sibling = Creature(siblingId)
	if not sibling then
		return
	end
	local selfPercent = getHealthPercentage(creature)
	if selfPercent >= 55 then
		return
	end
	local siblingPercent = getHealthPercentage(sibling)
	if (siblingPercent - selfPercent) > 5 then
		creature:addHealth(28000)
	end
end

-- Health Trigger Logic
local BossHealthCheck = CreatureEvent("BossHealthCheck")

function BossHealthCheck.onHealthChange(creature, attacker, primaryDamage, primaryType, secondaryDamage, secondaryType, origin)
	if not creature or not creature:isMonster() then
		return primaryDamage, primaryType, secondaryDamage, secondaryType
	end

	-- CORRECTION (executor contract, section 12; correction pass section H): run-owned - a stale
	-- Nictros/Baeloc instance left over from an already-terminated encounter can no longer sibling-heal
	-- or transition state.
	if not NictrosBaelocRunOwnsBoss(creature) then
		return primaryDamage, primaryType, secondaryDamage, secondaryType
	end

	local id = creature:getId()

	if id == NictrosBaelocRun.nictrosId then
		siblingHeal(creature, NictrosBaelocRun.baelocId)
	elseif id == NictrosBaelocRun.baelocId then
		siblingHeal(creature, NictrosBaelocRun.nictrosId)
	end

	local healthPercent = getHealthPercentage(creature)

	-- CORRECTION (executor contract, section 12): thresholds corrected from 85% to the accepted 60%.
	if id == NictrosBaelocRun.nictrosId and not healthStates.nictros60 and healthPercent <= 60 then
		healthStates.nictros60 = true

		creature:say("I'll step back now. Let's see how you handle my brother!")
		creature:teleportTo(nictrosPosition)
		creature:setMoveLocked(true)

		-- Release Baeloc to fight
		local baeloc = Creature(NictrosBaelocRun.baelocId)
		if baeloc then
			baeloc:teleportTo(Position(33426, 31435, 13))
			baeloc:setDirection(DIRECTION_SOUTH)
			baeloc:setMoveLocked(false)
			baeloc:say("My turn! Let me show you my skills!")
		end
	elseif id == NictrosBaelocRun.baelocId and healthStates.nictros60 and not healthStates.baeloc60 and healthPercent <= 60 then
		healthStates.baeloc60 = true

		creature:say("Brother! I need your assistance!")

		-- Release Nictros to join the fight
		local nictros = Creature(NictrosBaelocRun.nictrosId)
		if nictros then
			nictros:setMoveLocked(false)
			nictros:teleportTo(Position(33424, 31435, 13))
			nictros:say("Now we fight together, brother!")
		end
	end

	return primaryDamage, primaryType, secondaryDamage, secondaryType
end

BossHealthCheck:register()

-- CORRECTION (lifecycle closure pass section C): explicit per-brother death flags replace the
-- previous "is either Creature(id) still resolvable" world-disappearance check. Marks exactly which
-- owned brother just died, then completes the pair only once BOTH flags are true - not on the first
-- death, since the survivor's sibling-heal/Lesser Hex must keep applying until the fight is actually
-- over.
local nictros_baeloc_success = CreatureEvent("nictros_baeloc_success")

function nictros_baeloc_success.onDeath(creature)
	local targetMonster = creature:getMonster()
	if not targetMonster or targetMonster:getMaster() then
		return true
	end
	if not NictrosBaelocRunOwnsBoss(creature) then
		return true
	end

	local id = creature:getId()
	if id == NictrosBaelocRun.nictrosId then
		NictrosBaelocRun.nictrosDead = true
	elseif id == NictrosBaelocRun.baelocId then
		NictrosBaelocRun.baelocDead = true
	end

	if NictrosBaelocRun.nictrosDead and NictrosBaelocRun.baelocDead then
		completePairSuccess("Sir Nictros and Sir Baeloc defeated")
	end

	return true
end

nictros_baeloc_success:register()
