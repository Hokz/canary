-- ================================================================
-- DUKE KRULE ELEMENTAL ENCOUNTER (executor contract, section 13)
-- ================================================================
-- Confirmed absent from the repository before this pass: this file previously contained only the
-- generic BossLever boilerplate, with no transformation/AoE mechanic anywhere (recon: no
-- transform/addOutfit/Combat/timer code at all; the monster type's own summon table only spawns
-- "Soul Scourge", unrelated to elements). movements_duke_exit_tp.lua already called
-- creature:removeCondition(CONDITION_OUTFIT) on exit, which was the only trace this feature was ever
-- planned. Built using the CONDITION_OUTFIT + periodic self-cast pattern already proven elsewhere in
-- this repository (the_dream_courts_quest/creaturescripts_nightmareCurse.lua for the transform,
-- data/scripts/runes/great_fireball.lua and avalanche.lua for the damage-type/effect pairing).
DukeKruleRun = {
	token = 0,
	active = false,
	participants = {}, -- map: playerId -> "fire" | "water"
	events = {}, -- set: eventId -> true
}

function DukeKruleRunIsCurrent(token)
	return token ~= nil and token > 0 and DukeKruleRun.active and DukeKruleRun.token == token
end

function DukeKruleRunCurrentToken()
	if DukeKruleRun.active then
		return DukeKruleRun.token
	end
	return nil
end

local function trackEvent(token, eventId)
	if DukeKruleRunIsCurrent(token) and eventId then
		DukeKruleRun.events[eventId] = true
	end
end

-- Reuses monster/elementals/fire_elemental.lua and monster/elementals/water_elemental.lua's own
-- outfit lookTypes rather than inventing new ones.
local fireOutfit = createConditionObject(CONDITION_OUTFIT)
setConditionParam(fireOutfit, CONDITION_PARAM_TICKS, -1)
addOutfitCondition(fireOutfit, { lookType = 49 })

local waterOutfit = createConditionObject(CONDITION_OUTFIT)
setConditionParam(waterOutfit, CONDITION_PARAM_TICKS, -1)
addOutfitCondition(waterOutfit, { lookType = 286 })

local function clearElementalState(playerId)
	local player = Player(playerId)
	if player then
		player:removeCondition(CONDITION_OUTFIT)
	end
end

function DukeKruleRunTerminate(token, kind, reason)
	if not DukeKruleRunIsCurrent(token) then
		return
	end
	logger.info("GraveDanger/DukeKrule: run {} terminated ({}) - {}", token, kind, reason or "")

	DukeKruleRun.active = false

	for eventId in pairs(DukeKruleRun.events) do
		stopEvent(eventId)
	end

	for playerId in pairs(DukeKruleRun.participants) do
		clearElementalState(playerId)
	end

	if kind == "technical_abort" then
		for playerId in pairs(DukeKruleRun.participants) do
			local player = Player(playerId)
			if player then
				player:setBossCooldown("duke krule", 0)
			end
		end
	end

	DukeKruleRun.participants = {}
	DukeKruleRun.events = {}
end

-- CUSTOM_GLOBAL_LIKE_PENDING_EXACT_TIMING (executor contract, section 13): neither the
-- re-randomization interval nor the self-cast blast interval is provable from the owner reference -
-- both are stable functional values, not claimed Global-exact.
local REASSIGN_INTERVAL = 15 * 1000
local BLAST_INTERVAL = 5 * 1000
-- "~2000" per the owner reference.
local BLAST_DAMAGE = 2000
local BLAST_RADIUS = 3

local reassignAll
local blastAll

reassignAll = function(token)
	if not DukeKruleRunIsCurrent(token) then
		return
	end
	for playerId in pairs(DukeKruleRun.participants) do
		local player = Player(playerId)
		if player and player:isPlayer() and player:getHealth() > 0 then
			local element = math.random(1, 2) == 1 and "fire" or "water"
			DukeKruleRun.participants[playerId] = element
			player:removeCondition(CONDITION_OUTFIT)
			player:addCondition(element == "fire" and fireOutfit or waterOutfit)
			player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "Duke Krule's magic courses through you - you have become a " .. element .. " elemental!")
		end
	end
	trackEvent(token, addEvent(reassignAll, REASSIGN_INTERVAL, token))
end

-- Same-element participants must not damage each other, opposite elements must. Combat's own
-- CALLBACK_PARAM_TARGETCREATURE fires only AFTER damage has already been applied (confirmed against
-- src/creatures/combat/combat.cpp - it cannot prevent a hit, only react to one), so this is done
-- manually: spectators are gathered directly and doTargetCombatHealth is called per eligible target,
-- skipping the caster and any same-element participant before damage is ever computed.
blastAll = function(token)
	if not DukeKruleRunIsCurrent(token) then
		return
	end
	for playerId, element in pairs(DukeKruleRun.participants) do
		local player = Player(playerId)
		if player and player:isPlayer() and player:getHealth() > 0 then
			local pos = player:getPosition()
			local combatType = element == "fire" and COMBAT_FIREDAMAGE or COMBAT_ICEDAMAGE
			local effect = element == "fire" and CONST_ME_FIREAREA or CONST_ME_ICEAREA
			pos:sendMagicEffect(effect)
			local spectators = Game.getSpectators(pos, false, true, BLAST_RADIUS, BLAST_RADIUS, BLAST_RADIUS, BLAST_RADIUS)
			for _, target in pairs(spectators) do
				if target:isPlayer() and target:getId() ~= playerId then
					local targetElement = DukeKruleRun.participants[target:getId()]
					if targetElement and targetElement ~= element then
						doTargetCombatHealth(0, target, combatType, -BLAST_DAMAGE, -BLAST_DAMAGE, effect)
					end
				end
			end
		end
	end
	trackEvent(token, addEvent(blastAll, BLAST_INTERVAL, token))
end

-- Snapshot of the most recent onUseExtra call's infoPositions, consumed synchronously by
-- createDukeKruleEncounter() moments later in the same synchronous BossLever:onUse() call.
local lastInfoPositions = nil

-- CORRECTION (executor contract, section 13): mirrors the Count Vlarkorth / Lord Azaram / King Zelos
-- fix - the boss is now created via config.boss.createFunction (invoked after Zone:removeMonsters())
-- so his mandatory creation is verified before the lever commits cooldown/teleport, and the
-- per-participant elemental assignment starts only once that is confirmed.
local function createDukeKruleEncounter()
	if DukeKruleRun.active then
		logger.error("GraveDanger/DukeKrule: a run is already active, refusing a second concurrent start")
		return false
	end

	local boss = Game.createMonster("Duke Krule", Position(33456, 31473, 13), false, true)
	if not boss then
		logger.error("GraveDanger/DukeKrule: technical abort - Duke Krule failed to spawn")
		return false
	end

	DukeKruleRun.token = DukeKruleRun.token + 1
	local token = DukeKruleRun.token
	DukeKruleRun.active = true
	DukeKruleRun.participants = {}
	DukeKruleRun.events = {}

	if lastInfoPositions then
		for _, posInfo in pairs(lastInfoPositions) do
			local player = posInfo.creature
			if player and player:isPlayer() then
				DukeKruleRun.participants[player:getId()] = math.random(1, 2) == 1 and "fire" or "water"
			end
		end
	end

	for playerId, element in pairs(DukeKruleRun.participants) do
		local player = Player(playerId)
		if player then
			player:removeCondition(CONDITION_OUTFIT)
			player:addCondition(element == "fire" and fireOutfit or waterOutfit)
			player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "Duke Krule's magic courses through you - you have become a " .. element .. " elemental!")
		end
	end

	trackEvent(token, addEvent(reassignAll, REASSIGN_INTERVAL, token))
	trackEvent(token, addEvent(blastAll, BLAST_INTERVAL, token))
	-- Matches BOSS_DEFAULT_TIME_TO_DEFEAT (20 minutes, the same default this lever otherwise relies
	-- on) so this run's own state/condition cleanup fires alongside the framework's generic timeout.
	trackEvent(
		token,
		addEvent(function()
			DukeKruleRunTerminate(token, "normal_timeout", "encounter time limit exceeded")
		end, 20 * 60 * 1000, token)
	)

	return true
end

local config = {
	boss = {
		name = "Duke Krule",
		createFunction = createDukeKruleEncounter,
	},
	requiredLevel = 250,
	playerPositions = {
		{ pos = Position(33455, 31493, 13), teleport = Position(33455, 31464, 13), effect = CONST_ME_TELEPORT },
		{ pos = Position(33456, 31493, 13), teleport = Position(33455, 31464, 13), effect = CONST_ME_TELEPORT },
		{ pos = Position(33457, 31493, 13), teleport = Position(33455, 31464, 13), effect = CONST_ME_TELEPORT },
		{ pos = Position(33458, 31493, 13), teleport = Position(33455, 31464, 13), effect = CONST_ME_TELEPORT },
		{ pos = Position(33459, 31493, 13), teleport = Position(33455, 31464, 13), effect = CONST_ME_TELEPORT },
	},
	specPos = {
		from = Position(33447, 31464, 13),
		to = Position(33464, 31481, 13),
	},
	exit = Position(32347, 32167, 12),
	onUseExtra = function(creature, infoPositions)
		lastInfoPositions = infoPositions
		return true
	end,
}

local lever = BossLever(config)
lever:position(Position(33454, 31493, 13))
lever:register()
