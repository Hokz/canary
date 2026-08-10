local function setStorage()
	local upConer = { x = 32126, y = 31296, z = 14 } -- upLeftCorner
	local downConer = { x = 32162, y = 31322, z = 14 } -- downRightCorner
	for i = upConer.x, downConer.x do
		for j = upConer.y, downConer.y do
			for k = upConer.z, downConer.z do
				local room = { x = i, y = j, z = k }
				local tile = Tile(room)
				if tile then
					local creatures = tile:getCreatures()
					if creatures and #creatures > 0 then
						for _, creature in pairs(creatures) do
							if creature:isPlayer() and creature:getStorageValue(14324) < 1 then -- hardcoded storges
								creature:setStorageValue(14324, 1) -- Access to boss realityquake
							end
						end
					end
				end
			end
		end
	end
end

local sparkDeath = CreatureEvent("SparkDeath")
function sparkDeath.onDeath(creature)
	-- CONFIRMED BUG (found during the HOD repair audit): the increment and the completion check
	-- used to be mutually exclusive branches of the same if/elseif, so the kill that brought the
	-- count from 9 to 10 only ever ran the increment branch - "elseif count == 10" could only be
	-- reached by a LATER, 11th death re-entering this function and finding the count already at
	-- 10. The owner reference requires exactly 10 kills, not 11. Incrementing unconditionally
	-- before branching fixes this: the 10th kill's own death event now sees count==10 and
	-- completes immediately.
	unstableSparksCount = unstableSparksCount + 1
	if unstableSparksCount < 10 then
		creature:say("The death of the spark charges the room!", TALKTYPE_MONSTER_YELL, isInGhostMode, pid, { x = 32143, y = 31308, z = 14 })
	elseif unstableSparksCount == 10 then
		setStorage()
		creature:say("The room is fully charged up! You are permeated with its power and can venture deeper into the heart of destruction now!", TALKTYPE_MONSTER_YELL, isInGhostMode, pid, { x = 32143, y = 31308, z = 14 })
	end
	return true
end

sparkDeath:register()
