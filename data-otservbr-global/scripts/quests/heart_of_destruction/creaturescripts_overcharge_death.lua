local function setStorage()
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
							if creature:isPlayer() and creature:getStorageValue(14320) < 1 then
								creature:setStorageValue(14320, 1) -- Access to boss Anomaly
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
							if creature:isPlayer() and creature:getStorageValue(14320) < 1 then -- hardcoded storges
								creature:setStorageValue(14320, 1) -- Access to boss Anomaly
							end
						end
					end
				end
			end
		end
	end
end

-- Same 5 tiles actions_charges_lever.lua already spawns Overcharge on (proven-valid, not guessed).
local overchargePositions = {
	{ x = 32152, y = 31355, z = 15 },
	{ x = 32154, y = 31360, z = 15 },
	{ x = 32160, y = 31360, z = 15 },
	{ x = 32162, y = 31356, z = 15 },
	{ x = 32158, y = 31352, z = 15 },
}

local overchargeDeath = CreatureEvent("OverchargeDeath")
function overchargeDeath.onDeath(creature)
	-- CONFIRMED BUG (found during the HOD repair audit): the owner reference requires 6 Overcharge
	-- kills to complete the Anomaly pre-mission, not 5 - but the lever only ever spawns 5. Rather
	-- than guess an unproven 6th map coordinate, the 5th kill spawns one extra Overcharge on one of
	-- the 5 tiles already proven valid (the lever already spawns monsters there), making 6 kills
	-- actually reachable.
	local count = Game.getStorageValue(14321) + 1
	Game.setStorageValue(14321, count)

	if count == 6 then
		setStorage()
		creature:say("You have reached enough charges to pass further into the destruction!", TALKTYPE_MONSTER_YELL, isInGhostMode, pid, { x = 32162, y = 31356, z = 15 })
		Game.setStorageValue(14321, -1)
	elseif count == 5 then
		local pos = overchargePositions[math.random(1, #overchargePositions)]
		Game.createMonster("Overcharge", pos, false, true)
	end

	return true
end

overchargeDeath:register()
