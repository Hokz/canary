local team = {}

-- ===== ANOMALY PRE-MISSION ATTEMPT OWNERSHIP (executor contract, section G) =====
-- A small namespaced attempt token, analogous to HODFinalRun (actions_final_lever.lua) but scoped
-- to just this pre-mission. Every phase-shift callback and the 6th-Overcharge retry (in
-- creaturescripts_overcharge_death.lua) captures and re-checks this token, so a stale callback
-- from a cleared/completed attempt can never act on a newer one.
local HODAnomalyPremission = {
	token = 0,
	active = false,
}

function HODAnomalyPremissionIsCurrent(token)
	return token ~= nil and token > 0 and HODAnomalyPremission.active and HODAnomalyPremission.token == token
end

-- Lets creaturescripts_overcharge_death.lua's 6th-Overcharge retry thread the current attempt's
-- token through without needing direct access to HODAnomalyPremission itself.
function HODAnomalyPremissionCurrentToken()
	if HODAnomalyPremission.active then
		return HODAnomalyPremission.token
	end
	return nil
end

-- FUNCTIONS

local function doCheckArea()
	--Room 1
	local upConer = { x = 32133, y = 31341, z = 14 } -- upLeftCorner
	local downConer = { x = 32174, y = 31375, z = 14 } -- downRightCorner

	for i = upConer.x, downConer.x do
		for j = upConer.y, downConer.y do
			for k = upConer.z, downConer.z do
				local room = { x = i, y = j, z = k }
				local tile = Tile(room)
				if tile then
					local creatures = tile:getCreatures()
					if creatures and #creatures > 0 then
						for _, creature in pairs(creatures) do
							local player = Player(creature)
							if player then
								return true
							end
						end
					end
				end
			end
		end
	end

	--Room 2
	local upConer2 = { x = 32140, y = 31340, z = 15 } -- upLeftCorner
	local downConer2 = { x = 32174, y = 31375, z = 15 } -- downRightCorner

	for f = upConer2.x, downConer2.x do
		for g = upConer2.y, downConer2.y do
			for h = upConer2.z, downConer2.z do
				local room = { x = f, y = g, z = h }
				local tile = Tile(room)
				if tile then
					local creatures = tile:getCreatures()
					if creatures and #creatures > 0 then
						for _, creature in pairs(creatures) do
							local player = Player(creature)
							if player then
								return true
							end
						end
					end
				end
			end
		end
	end

	if spawningCharge == true then
		return true
	end

	return false
end

-- Pure physical hygiene - no token, no lifecycle logic. Used both for synchronous pre-attempt
-- hygiene (lever-pull time, before a fresh attempt is even started - there is no attempt yet at
-- that point) and inside HODAnomalyPremissionAbort's own teardown.
local function sweepChargesRooms()
	--Room 1
	local upConer = { x = 32133, y = 31341, z = 14 } -- upLeftCorner
	local downConer = { x = 32174, y = 31375, z = 14 } -- downRightCorner

	for i = upConer.x, downConer.x do
		for j = upConer.y, downConer.y do
			for k = upConer.z, downConer.z do
				local room = { x = i, y = j, z = k }
				local tile = Tile(room)
				if tile then
					local creatures = tile:getCreatures()
					if creatures and #creatures > 0 then
						for _, creatureUid in pairs(creatures) do
							local creature = Creature(creatureUid)
							if creature then
								if creature:isPlayer() then
									creature:teleportTo({ x = 32092, y = 31330, z = 12 })
								elseif creature:isMonster() then
									creature:remove()
								end
							end
						end
					end
				end
			end
		end
	end

	--Room 2
	local upConer2 = { x = 32140, y = 31340, z = 15 } -- upLeftCorner
	local downConer2 = { x = 32174, y = 31375, z = 15 } -- downRightCorner

	for f = upConer2.x, downConer2.x do
		for g = upConer2.y, downConer2.y do
			for h = upConer2.z, downConer2.z do
				local room = { x = f, y = g, z = h }
				local tile = Tile(room)
				if tile then
					local creatures = tile:getCreatures()
					if creatures and #creatures > 0 then
						for _, creatureUid in pairs(creatures) do
							local creature = Creature(creatureUid)
							if creature then
								if creature:isPlayer() then
									creature:teleportTo({ x = 32092, y = 31330, z = 12 })
								elseif creature:isMonster() then
									creature:remove()
								end
							end
						end
					end
				end
			end
		end
	end
	team = {}
end

-- CORRECTION (executor contract, section G): replaces the generic global `clearArea` introduced by
-- the previous pass. Namespaced, token-checked - a stale timeout or a stale 6th-Overcharge retry
-- from an already-cleared attempt can no longer abort a NEWER attempt that has since started.
function HODAnomalyPremissionAbort(token, reason)
	if not HODAnomalyPremissionIsCurrent(token) then
		return
	end
	logger.error("HeartOfDestruction: Anomaly pre-mission attempt {} aborted - {}", token, reason)

	-- Invalidate first so any callback racing in after this point is a no-op.
	HODAnomalyPremission.active = false

	stopEvent(areaHeart1)
	stopEvent(areaHeart2)
	stopEvent(areaHeart3)

	sweepChargesRooms()
end

local teleportToCrackler, teleportToCharger

teleportToCrackler = function(token)
	if not HODAnomalyPremissionIsCurrent(token) then
		return
	end
	-- CONFIRMED BUG (found during the HOD repair audit): this used to shuffle the whole team and
	-- always phase-shift whichever 2 players landed in slots 1/2 after the shuffle - a random pair
	-- each cycle. The owner reference requires a fixed positional grouping instead: the 2nd and 4th
	-- players to enter (by original lever-slot order, preserved in `team`'s insertion order) are the
	-- ones who shift phase, while the 1st/3rd/5th group stays behind - deterministic, not random.

	--Room 1
	local upConer = { x = 32142, y = 31341, z = 14 } -- upLeftCorner
	local downConer = { x = 32176, y = 31375, z = 14 } -- downRightCorner

	for i = upConer.x, downConer.x do
		for j = upConer.y, downConer.y do
			for k = upConer.z, downConer.z do
				local room = { x = i, y = j, z = k }
				local tile = Tile(room)
				if tile then
					local creatures = tile:getCreatures()
					if creatures and #creatures > 0 then
						for _, c in pairs(creatures) do
							if c == team[2] or c == team[4] then
								c:teleportTo({ x = c:getPosition().x, y = c:getPosition().y, z = c:getPosition().z + 1 })
								c:say("A shift in polarity switches creatures with coresponding polarity into another phase of existence!", TALKTYPE_MONSTER_YELL, isInGhostMode, pid, { x = 32158, y = 31355, z = 14 })
							end
						end
					end
				end
			end
		end
	end
	-- Owner reference proves ~12 seconds of shifted-phase residence.
	areaHeart3 = addEvent(teleportToCharger, 12000, token)
end

teleportToCharger = function(token)
	if not HODAnomalyPremissionIsCurrent(token) then
		return
	end
	--Room 1
	local upConer = { x = 32142, y = 31341, z = 15 } -- upLeftCorner
	local downConer = { x = 32176, y = 31375, z = 15 } -- downRightCorner

	for i = upConer.x, downConer.x do
		for j = upConer.y, downConer.y do
			for k = upConer.z, downConer.z do
				local room = { x = i, y = j, z = k }
				local tile = Tile(room)
				if tile then
					local creatures = tile:getCreatures()
					if creatures and #creatures > 0 then
						for _, creature in pairs(creatures) do
							local player = Player(creature)
							if player then
								player:teleportTo({ x = player:getPosition().x, y = player:getPosition().y, z = player:getPosition().z - 1 })
							end
						end
					end
				end
			end
		end
	end
	areaHeart2 = addEvent(teleportToCrackler, 25000, token)
end

-- FUNCTIONS END

local heartDestructionCharges = Action()
function heartDestructionCharges.onUse(player, item, fromPosition, itemEx, toPosition)
	local config = {
		playerPositions = {
			Position(32091, 31327, 12),
			Position(32092, 31327, 12),
			Position(32093, 31327, 12),
			Position(32094, 31327, 12),
			Position(32095, 31327, 12),
		},

		newPos = { x = 32135, y = 31363, z = 14 },
	}

	local pushPos = { x = 32091, y = 31327, z = 12 }

	if item.actionid == 14320 then
		if item.itemid == 8911 then
			if player:getPosition().x == pushPos.x and player:getPosition().y == pushPos.y and player:getPosition().z == pushPos.z then
				local storePlayers = {}
				for i = 1, #config.playerPositions do
					local tile = Tile(Position(config.playerPositions[i]))
					if tile then
						local playerTile = tile:getTopCreature()
						if playerTile and playerTile:isPlayer() then
							storePlayers[#storePlayers + 1] = playerTile
						end
					end
				end

				if doCheckArea() == false then
					sweepChargesRooms()

					-- The 5 initial Overcharges are mandatory - the 6th (spawned later at the 5th
					-- kill, see creaturescripts_overcharge_death.lua) only ever exists because these
					-- 5 already do. All 5 are created and verified BEFORE the group is
					-- committed/teleported in; a failure removes only what this attempt created and
					-- leaves the room retryable, instead of committing a mission that can never
					-- reach 6 kills.
					local overchargePositions = {
						{ x = 32152, y = 31355, z = 15 },
						{ x = 32154, y = 31360, z = 15 },
						{ x = 32160, y = 31360, z = 15 },
						{ x = 32162, y = 31356, z = 15 },
						{ x = 32158, y = 31352, z = 15 },
					}
					local overcharges = {}
					local allSpawned = true
					for i = 1, #overchargePositions do
						local monster = Game.createMonster("Overcharge", overchargePositions[i], false, true)
						if monster then
							overcharges[#overcharges + 1] = monster
						else
							allSpawned = false
							break
						end
					end

					if not allSpawned then
						for i = 1, #overcharges do
							overcharges[i]:remove()
						end
						logger.error("HeartOfDestruction: failed to create the mandatory 5 initial Overcharges")
						player:sendTextMessage(19, "The heart of destruction resists your assault. Try again.")
						return true
					end

					-- COMMIT: this attempt gets its own token; every timeout/phase-shift/retry
					-- callback scheduled below captures it.
					HODAnomalyPremission.token = HODAnomalyPremission.token + 1
					local token = HODAnomalyPremission.token
					HODAnomalyPremission.active = true

					local players

					for i = 1, #storePlayers do
						players = storePlayers[i]
						table.insert(team, players) -- Insert players on table to get a random teleport
						config.playerPositions[i]:sendMagicEffect(CONST_ME_POFF)
						players:teleportTo(config.newPos)
						Position(config.newPos):sendMagicEffect(11)
					end

					areaHeart1 = addEvent(HODAnomalyPremissionAbort, 15 * 60000, token, "15-minute pre-mission timeout")
					areaHeart2 = addEvent(teleportToCrackler, 25000, token)

					Game.setStorageValue(14321, 0) -- Overcharge Count

					spawningCharge = false

					Game.createMonster("Charger", { x = 32151, y = 31356, z = 14 }, false, true)
					Game.createMonster("Charger", { x = 32154, y = 31353, z = 14 }, false, true)
					Game.createMonster("Charger", { x = 32153, y = 31361, z = 14 }, false, true)
					Game.createMonster("Charger", { x = 32158, y = 31362, z = 14 }, false, true)
					Game.createMonster("Charger", { x = 32161, y = 31360, z = 14 }, false, true)
					Game.createMonster("Charger", { x = 32156, y = 31357, z = 14 }, false, true)
					Game.createMonster("Charger", { x = 32159, y = 31354, z = 14 }, false, true)
					Game.createMonster("Charger", { x = 32163, y = 31356, z = 14 }, false, true)
					Game.createMonster("Charger", { x = 32162, y = 31352, z = 14 }, false, true)
					Game.createMonster("Charger", { x = 32158, y = 31350, z = 14 }, false, true)
				else
					player:sendTextMessage(19, "Someone is in the area.")
				end
			else
				return true
			end
		end
		item:transform(item.itemid == 8911 and 8912 or 8911)
	end

	return true
end

heartDestructionCharges:aid(14320)
heartDestructionCharges:register()
