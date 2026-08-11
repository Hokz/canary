-- ===== REALITYQUAKE ENCOUNTER OWNERSHIP (executor contract, section H) =====
-- A small namespaced encounter token for the Foreshock->Aftershock->Realityquake chain, used by
-- creaturescripts_shocks_death.lua's bounded-retry handoffs so a stale retry from a finished/
-- aborted encounter can never spawn into (or abort) a newer one.
--
-- Mechanically verified against data/libs/functions/lever.lua's Lever:checkConditions(): the
-- BossLever condition wrapper (and therefore onUseExtra below) is called ONCE PER OCCUPIED
-- PLATFORM POSITION (up to 5 times for this lever's 5 playerPositions), not once per lever pull -
-- naively creating a new token directly in onUseExtra's body would increment it up to 5 times for
-- a single legitimate encounter start. `infoPositions` (BossLever's own per-pull snapshot array,
-- from Lever:checkPositions()) is the SAME table object across every onUseExtra call within one
-- lever pull and a NEW object on the next pull, so memoizing on its identity gives exactly one
-- token per actual encounter start regardless of how many positions are occupied.
local HODRealityquakeEncounter = {
	token = 0,
	active = false,
	events = {}, -- set: eventId -> true, every retry addEvent this encounter owns
}

local seenPulls = setmetatable({}, { __mode = "k" })

local function currentEncounterToken(infoPositions)
	local token = seenPulls[infoPositions]
	if token then
		return token
	end
	HODRealityquakeEncounter.token = HODRealityquakeEncounter.token + 1
	token = HODRealityquakeEncounter.token
	HODRealityquakeEncounter.active = true
	seenPulls[infoPositions] = token
	return token
end

function HODRealityquakeEncounterIsCurrent(token)
	return token ~= nil and token > 0 and HODRealityquakeEncounter.active and HODRealityquakeEncounter.token == token
end

function HODRealityquakeEncounterCurrentToken()
	if HODRealityquakeEncounter.active then
		return HODRealityquakeEncounter.token
	end
	return nil
end

-- CORRECTION (micro-correction, section E): lets creaturescripts_shocks_death.lua register every
-- retry addEvent id it schedules under this encounter, so a stale retry can be positively
-- identified and cancelled rather than merely ignored via the token check.
function HODRealityquakeEncounterTrackEvent(token, eventId)
	if HODRealityquakeEncounterIsCurrent(token) and eventId then
		HODRealityquakeEncounter.events[eventId] = true
	end
end

-- Called on a technical abort (invalidates FIRST, before any cleanup) and on the successful
-- Aftershock->Realityquake handoff (the chain is complete - nothing further will ever retry under
-- this token, so it's finished cleanly rather than left inertly "active"). Either way, every
-- still-pending retry event this encounter owns is stopped/cleared - a new legitimate encounter
-- never inherits scheduled work from a prior one.
function HODRealityquakeEncounterFinish(token)
	if not (HODRealityquakeEncounter.active and HODRealityquakeEncounter.token == token) then
		return
	end
	HODRealityquakeEncounter.active = false
	for eventId in pairs(HODRealityquakeEncounter.events) do
		stopEvent(eventId)
	end
	HODRealityquakeEncounter.events = {}
end

local config = {
	boss = {
		name = "Foreshock",
		position = Position(32208, 31248, 14),
	},
	requiredLevel = 150,
	playerPositions = {
		{ pos = Position(32182, 31244, 14), teleport = Position(32208, 31256, 14), effect = CONST_ME_TELEPORT },
		{ pos = Position(32182, 31245, 14), teleport = Position(32208, 31256, 14), effect = CONST_ME_TELEPORT },
		{ pos = Position(32182, 31246, 14), teleport = Position(32208, 31256, 14), effect = CONST_ME_TELEPORT },
		{ pos = Position(32182, 31247, 14), teleport = Position(32208, 31256, 14), effect = CONST_ME_TELEPORT },
		{ pos = Position(32182, 31248, 14), teleport = Position(32208, 31256, 14), effect = CONST_ME_TELEPORT },
	},
	specPos = {
		from = Position(32197, 31236, 14),
		to = Position(32220, 31260, 14),
	},
	monsters = {
		{ name = "Spark of Destruction", pos = Position(32203, 31246, 14) },
		{ name = "Spark of Destruction", pos = Position(32205, 31251, 14) },
		{ name = "Spark of Destruction", pos = Position(32210, 31251, 14) },
		{ name = "Spark of Destruction", pos = Position(32212, 31246, 14) },
	},
	onUseExtra = function(player, infoPositions)
		currentEncounterToken(infoPositions)
		Game.setStorageValue(GlobalStorage.HeartOfDestruction.ForeshockHealth, 105000)
		Game.setStorageValue(GlobalStorage.HeartOfDestruction.AftershockHealth, 105000)
		Game.setStorageValue(GlobalStorage.HeartOfDestruction.ForeshockStage, -1)
		Game.setStorageValue(GlobalStorage.HeartOfDestruction.AftershockStage, -1)
		player:setBossCooldown("Realityquake", os.time() + configManager.getNumber(configKeys.BOSS_DEFAULT_TIME_TO_FIGHT_AGAIN))
		player:sendBosstiaryCooldownTimer()
		local tile = Tile(Position(32199, 31248, 14))
		if tile then
			local vortex = tile:getItemById(23482)
			if vortex then
				vortex:transform(23483)
				vortex:setActionId(14345)
			end
		end
	end,
	exit = Position(32230, 31358, 11),
}

local lever = BossLever(config)
lever:position(Position(32182, 31243, 14))
lever:register()
