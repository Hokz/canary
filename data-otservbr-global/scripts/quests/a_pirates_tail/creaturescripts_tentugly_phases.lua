-- The Wreckoning / Tentugly's Head - real 2-phase encounter, not spawn-and-kill: the head is
-- attacked until it would die, then vanishes and tentacles rise on both floors of the ship
-- (see specPos in actions_tentuglys_head.lua for the room rectangle, which already has real
-- positions - no map setup needed for this phase transition). Once every tentacle is destroyed,
-- the head reappears on the lower deck for its final, real kill. Phase/tentacle-count state is
-- boss-room-scoped (GlobalStorage), matching how BossLever rooms already only host one attempt
-- at a time.
local TENTACLE_COUNT = 6
local ROOM = {
	from = Position(33705, 31176, 6),
	to = Position(33736, 31190, 7),
}
local FINAL_HEAD_POSITION = Position(33722, 31182, 7) -- same spawn point used for the first form

local function randomRoomPosition()
	for _ = 1, 20 do
		local x = math.random(ROOM.from.x, ROOM.to.x)
		local y = math.random(ROOM.from.y, ROOM.to.y)
		local z = math.random(ROOM.from.z, ROOM.to.z)
		local position = Position(x, y, z)
		local tile = position:getTile()
		if tile and tile:isWalkable(false, false, false, false, true) then
			return position
		end
	end
	return FINAL_HEAD_POSITION
end

local phaseGate = CreatureEvent("TentuglyPhaseGate")

function phaseGate.onHealthChange(creature, attacker, primaryDamage, primaryType, secondaryDamage, secondaryType, origin)
	local phase = Game.getStorageValue(GlobalStorage.APiratesTailBosses.TentuglyPhase)
	if phase ~= 1 and phase ~= 3 then
		return primaryDamage, primaryType, secondaryDamage, secondaryType
	end
	local incoming = math.abs(primaryDamage) + math.abs(secondaryDamage)
	if creature:getHealth() - incoming > 0 then
		return primaryDamage, primaryType, secondaryDamage, secondaryType
	end
	if phase == 3 then
		-- final form - let it actually die, TentuglysHeadDeath handles the reward
		return primaryDamage, primaryType, secondaryDamage, secondaryType
	end

	-- phase 1 -> phase 2: the head vanishes and tentacles rise
	local position = creature:getPosition()
	creature:remove()
	position:sendMagicEffect(CONST_ME_MAGIC_BLUE)
	Game.setStorageValue(GlobalStorage.APiratesTailBosses.TentuglyPhase, 2)
	Game.setStorageValue(GlobalStorage.APiratesTailBosses.TentuglyTentaclesRemaining, TENTACLE_COUNT)
	for _ = 1, TENTACLE_COUNT do
		Game.createMonster("Tentugly's Tentacle", randomRoomPosition(), true, true)
	end
	for _, spectator in ipairs(Game.getSpectators(ROOM.from, false, true)) do
		if spectator:isPlayer() then
			spectator:sendTextMessage(MESSAGE_EVENT_ADVANCE, "Tentugly's Head vanishes! Tentacles rise across the ship - destroy them all.")
		end
	end
	return 0, primaryType, 0, secondaryType
end

phaseGate:register()

local tentacleDeath = CreatureEvent("TentuglyTentacleDeath")

function tentacleDeath.onDeath(creature, corpse, lasthitkiller, mostdamagekiller)
	local remaining = math.max(Game.getStorageValue(GlobalStorage.APiratesTailBosses.TentuglyTentaclesRemaining) - 1, 0)
	Game.setStorageValue(GlobalStorage.APiratesTailBosses.TentuglyTentaclesRemaining, remaining)
	if remaining > 0 then
		return true
	end

	Game.setStorageValue(GlobalStorage.APiratesTailBosses.TentuglyPhase, 3)
	local finalHead = Game.createMonster("Tentugly's Head", FINAL_HEAD_POSITION, true, true)
	if finalHead then
		-- The phase 1 head never truly dies (its death is intercepted above), so it never fires
		-- BossLeverOnDeath - the room's "boss defeated" cleanup/empty-room bookkeeping only needs
		-- to run once, on this final form's real death, exactly like every other BossLever room.
		finalHead:registerEvent("BossLeverOnDeath")
	end
	for _, spectator in ipairs(Game.getSpectators(ROOM.from, false, true)) do
		if spectator:isPlayer() then
			spectator:sendTextMessage(MESSAGE_EVENT_ADVANCE, "The last tentacle falls - Tentugly's Head reappears on the lower deck!")
		end
	end
	return true
end

tentacleDeath:register()
