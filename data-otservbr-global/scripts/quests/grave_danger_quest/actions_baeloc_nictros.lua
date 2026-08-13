local nictrosPosition = Position(33427, 31428, 13)
local baelocPosition = Position(33422, 31428, 13)

local healthStates = {
	nictros60 = false,
	baeloc60 = false,
}

-- ================================================================
-- NICTROS/BAELOC RUN OWNERSHIP (executor contract, section 12)
-- ================================================================
local NictrosBaelocRun = {
	token = 0,
	active = false,
	events = {}, -- set: eventId -> true
}

local function trackEvent(token, eventId)
	if NictrosBaelocRun.active and NictrosBaelocRun.token == token and eventId then
		NictrosBaelocRun.events[eventId] = true
	end
end

local function isCurrent(token)
	return token ~= nil and token > 0 and NictrosBaelocRun.active and NictrosBaelocRun.token == token
end

-- Bare global so BossHealthCheck (further below) and the Lesser Hex handler can read run state.
NictrosBaelocRunIsActive = function()
	return NictrosBaelocRun.active
end

local ROOM_FROM = Position(33414, 31426, 13)
local ROOM_TO = Position(33433, 31449, 13)

local function isInsideRoom(creature)
	local pos = creature:getPosition()
	return pos.x >= ROOM_FROM.x and pos.x <= ROOM_TO.x and pos.y >= ROOM_FROM.y and pos.y <= ROOM_TO.y and pos.z == ROOM_FROM.z
end

-- CORRECTION (executor contract, section 12): functional Lesser Hex - the source gives "these bosses
-- can reduce the power of healing spells" with no exact numeric value, so 50% is used here.
-- CUSTOM_GLOBAL_LIKE_PENDING_EXACT_VALUE - not claimed Global-exact. Encounter-scoped/transient: it
-- only ever applies while NictrosBaelocRun is active AND the player is physically in the room, so
-- there is no persistent condition to clean up on leave/success/timeout.
local lesser_hex_healing = CreatureEvent("NictrosBaelocLesserHex")

function lesser_hex_healing.onHealthChange(creature, attacker, primaryDamage, primaryType, secondaryDamage, secondaryType)
	if primaryType ~= COMBAT_HEALING or not creature or not creature:isPlayer() then
		return primaryDamage, primaryType, secondaryDamage, secondaryType
	end
	if not NictrosBaelocRun.active or not isInsideRoom(creature) then
		return primaryDamage, primaryType, secondaryDamage, secondaryType
	end
	return primaryDamage * 0.5, primaryType, secondaryDamage, secondaryType
end

lesser_hex_healing:register()

-- Mirrors the King Zelos Greater Hex registration pattern (soul_war_mechanics.lua's SoulWarLogin
-- precedent) - CREATURE_EVENT_HEALTHCHANGE only fires on the recipient's own registered events, so
-- reducing healing a PLAYER receives needs registration on players, not on Nictros/Baeloc.
local lesser_hex_login = CreatureEvent("NictrosBaelocLesserHexLogin")

function lesser_hex_login.onLogin(player)
	player:registerEvent("NictrosBaelocLesserHex")
	return true
end

lesser_hex_login:register()

-- CORRECTION (executor contract, section 12): mandatory bounded-verified creation of BOTH bosses was
-- already correctly implemented here (config.boss.createFunction) - unchanged. Reads the token
-- onUseExtra already incremented for this pull (see below; onUseExtra runs during
-- Lever:checkConditions(), before createFunction, so the token must originate there) and only marks
-- the run active once both bosses are confirmed created.
local config = {
	boss = {
		name = "Sir Nictros",
		createFunction = function()
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
			NictrosBaelocRun.active = true
			NictrosBaelocRun.events = {}

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
		from = Position(33414, 31426, 13),
		to = Position(33433, 31449, 13),
	},
	-- CORRECTION (executor contract, section 12): Lever:checkConditions() calls this once per
	-- occupied platform position (mechanically confirmed against data/libs/functions/lever.lua during
	-- the King Zelos work in this same pass), not once per lever pull - previously this scheduled the
	-- whole narrative dialogue/retreat-setup addEvent chain unconditionally on every call, so a
	-- 2-5 player pull could schedule the same banter and Nictros repositioning 2-5 times over. Now
	-- memoized on infoPositions' own identity (the same table object across every call within one
	-- pull, a new object on the next pull) so the sequence is scheduled exactly once, and every event
	-- it schedules is tracked under this pull's token so a later encounter can never inherit or be
	-- disrupted by a stale chain from an earlier one.
	onUseExtra = function(player, infoPositions)
		if NictrosBaelocRun.seenPulls == nil then
			NictrosBaelocRun.seenPulls = setmetatable({}, { __mode = "k" })
		end
		if NictrosBaelocRun.seenPulls[infoPositions] then
			return true
		end
		NictrosBaelocRun.seenPulls[infoPositions] = true

		NictrosBaelocRun.token = NictrosBaelocRun.token + 1
		local token = NictrosBaelocRun.token

		trackEvent(
			token,
			addEvent(function()
				if not isCurrent(token) then
					return
				end
				local baeloc = Creature("Sir Baeloc")
				local nictros = Creature("Sir Nictros")

				if baeloc then
					baeloc:say("Ah look my Brother! Challengers! After all this time finally a chance to prove our skills!")
					trackEvent(
						token,
						addEvent(function()
							if not isCurrent(token) then
								return
							end
							local currentNictros = Creature("Sir Nictros")
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
						local currentBaeloc = Creature("Sir Baeloc")
						local currentNictros = Creature("Sir Nictros")
						if currentBaeloc then
							currentBaeloc:say("Oh, man! You always get the fun!")
							currentBaeloc:setMoveLocked(true)
						end
						if currentNictros then
							currentNictros:teleportTo(Position(33426, 31437, 13))
							currentNictros:setMoveLocked(false)
						end
					end, 12 * 1000)
				)
			end, 4 * 1000)
		)

		return true
	end,
	exit = Position(33290, 32474, 9),
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
local function siblingHeal(creature, siblingName)
	local sibling = Creature(siblingName)
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

	-- CORRECTION (executor contract, section 12): run-owned - a stale Nictros/Baeloc instance left
	-- over from an already-terminated encounter can no longer sibling-heal or transition state.
	if not NictrosBaelocRun.active then
		return primaryDamage, primaryType, secondaryDamage, secondaryType
	end

	local name = creature:getName()

	if name == "Sir Nictros" then
		siblingHeal(creature, "Sir Baeloc")
	elseif name == "Sir Baeloc" then
		siblingHeal(creature, "Sir Nictros")
	end

	local healthPercent = getHealthPercentage(creature)

	-- CORRECTION (executor contract, section 12): thresholds corrected from 85% to the accepted 60%.
	if name == "Sir Nictros" and not healthStates.nictros60 and healthPercent <= 60 then
		healthStates.nictros60 = true

		creature:say("I'll step back now. Let's see how you handle my brother!")
		creature:teleportTo(nictrosPosition)
		creature:setMoveLocked(true)

		-- Release Baeloc to fight
		local baeloc = Creature("Sir Baeloc")
		if baeloc then
			baeloc:teleportTo(Position(33426, 31435, 13))
			baeloc:setDirection(DIRECTION_SOUTH)
			baeloc:setMoveLocked(false)
			baeloc:say("My turn! Let me show you my skills!")
		end
	elseif name == "Sir Baeloc" and healthStates.nictros60 and not healthStates.baeloc60 and healthPercent <= 60 then
		healthStates.baeloc60 = true

		creature:say("Brother! I need your assistance!")

		-- Release Nictros to join the fight
		local nictros = Creature("Sir Nictros")
		if nictros then
			nictros:setMoveLocked(false)
			nictros:teleportTo(Position(33424, 31435, 13))
			nictros:say("Now we fight together, brother!")
		end
	end

	return primaryDamage, primaryType, secondaryDamage, secondaryType
end

BossHealthCheck:register()

-- Deactivates the run (stopping Lesser Hex/sibling-heal from applying to any leftover/future
-- creature and cancelling any still-pending dialogue events) once BOTH brothers are confirmed dead -
-- not on the first death, since the survivor's sibling-heal/Lesser Hex must keep applying until the
-- fight is actually over. Their own grave/boss credit is unaffected - handled separately by the
-- pre-existing generic creaturescripts_boss_kill.lua path (sir baeloc -> Graves.Darashia).
local nictros_baeloc_success = CreatureEvent("nictros_baeloc_success")

function nictros_baeloc_success.onDeath(creature)
	local targetMonster = creature:getMonster()
	if not targetMonster or targetMonster:getMaster() then
		return true
	end

	if not Creature("Sir Nictros") and not Creature("Sir Baeloc") then
		NictrosBaelocRun.active = false
		for eventId in pairs(NictrosBaelocRun.events) do
			stopEvent(eventId)
		end
		NictrosBaelocRun.events = {}
	end

	return true
end

nictros_baeloc_success:register()
