-- "Higher minions of destruction" for the destructive-charges system (see movements_teleport_heart.lua
-- worldDevourerEnter and 05_HOD_BOSS_MECHANICS_CONTRACT.md): Frenzy, Charged Disruption, and Overcharged
-- Disruption. This is an inferred classification, not exact wiki text — reasoning: these are the escalated/
-- empowered forms that appear during the final battle and World Devourer fight (as opposed to the base
-- "Disruption" or common "Spark of Destruction" spawns), and they die via normal combat (unlike Greed,
-- which is despawned via the vortex mechanic and never actually "killed").
local function grantDestructiveCharge(killer, mostDamageKiller)
	local player = mostDamageKiller and mostDamageKiller:getPlayer() or (killer and killer:getPlayer())
	if not player then
		return
	end
	local charges = math.min(math.max(player:getStorageValue(Storage.Quest.U10_94.HeartOfDestruction.DestructiveCharges), 0) + 1, 5)
	player:setStorageValue(Storage.Quest.U10_94.HeartOfDestruction.DestructiveCharges, charges)
end

-- The Hunger/Destruction/Rage rotate through 3 rooms via changeArea() (actions_final_lever.lua):
-- every 30 seconds players are moved Hunger->Rage->Destruction->Hunger, and whichever of these
-- three is currently marked killed gets a fresh copy respawned in its room for the newly-rotated-in
-- team. A boss can therefore die and respawn several times before all three are simultaneously
-- dead (devourerBossesKilled reaching 3) and the fight moves on to World Devourer.
--
-- Because of that rotation, a flat "60 seconds after death, clear the room" is unsafe on its own:
-- by the time the timer fires, changeArea() may already have respawned the boss for a new team,
-- and nuking the room would kill a legitimate in-progress fight. The guard below only runs the
-- cleanup if the boss is STILL in the dead/not-yet-respawned state 60 seconds later - i.e. nothing
-- has rotated back into that room since this specific death.
--
-- No empty-room watchdog is implemented for these three rooms. Unlike a static BossLever room,
-- these rooms are *routinely* empty of players for stretches of totally normal play - every
-- 30-second rotation empties one room while filling another - so "0 players present" is not a
-- reliable failure signal here. Wiring one up would risk aborting legitimate, in-progress attempts
-- during a normal rotation gap. The existing 45-minute failsafe (areaDevourer1/2/3, unchanged)
-- remains the safety net for a room that's abandoned for good.
local miniBossRooms = {
	hunger = {
		from = { x = 32233, y = 31360, z = 14 },
		to = { x = 32256, y = 31384, z = 14 },
		isStillDead = function()
			return theHungerKilled == true
		end,
	},
	destruction = {
		from = { x = 32260, y = 31304, z = 14 },
		to = { x = 32283, y = 31328, z = 14 },
		isStillDead = function()
			return theDestructionKilled == true
		end,
	},
	rage = {
		from = { x = 32288, y = 31360, z = 14 },
		to = { x = 32311, y = 31384, z = 14 },
		isStillDead = function()
			return theRageKilled == true
		end,
	},
}
local miniBossExitPosition = { x = 32208, y = 31372, z = 14 }

local function cleanMiniBossRoom(key)
	local room = miniBossRooms[key]
	if not room or not room.isStillDead() then
		-- Already respawned for a rotated-in team (or the encounter has since moved on) -
		-- a live fight may be using this room now, so leave it alone.
		return
	end
	for i = room.from.x, room.to.x do
		for j = room.from.y, room.to.y do
			for k = room.from.z, room.to.z do
				local tile = Tile(i, j, k)
				if tile then
					local creatures = tile:getCreatures()
					if creatures and #creatures > 0 then
						for _, creatureUid in pairs(creatures) do
							local creature = Creature(creatureUid)
							if creature then
								if creature:isPlayer() then
									creature:teleportTo(miniBossExitPosition)
									creature:getPosition():sendMagicEffect(CONST_ME_TELEPORT)
								elseif creature:isMonster() then
									creature:remove()
								end
							end
						end
					end
					for _, item in ipairs(tile:getItems() or {}) do
						if not item:hasAttribute("aid") and not item:hasAttribute("uid") then
							local itemType = ItemType(item:getId())
							if itemType:isMagicField() or itemType:isCorpse() or (itemType:isMovable() and itemType:isPickupable()) then
								item:remove()
							end
						end
					end
				end
			end
		end
	end
end

local heartMinionDeath = CreatureEvent("HeartMinionDeath")
function heartMinionDeath.onDeath(creature, corpse, killer, mostDamageKiller, unjustified, mostDamageUnjustified)
	if not creature or not creature:isMonster() then -- éMonstro!
		return true
	end
	local monster = creature:getName():lower()
	if monster == "frenzy" then
		rageSummon = rageSummon - 1
		devourerSummon = devourerSummon - 1
		grantDestructiveCharge(killer, mostDamageKiller)
	elseif monster == "damage resonance" then
		Game.setStorageValue(GlobalStorage.HeartOfDestruction.RuptureResonanceActive, 0)
	elseif monster == "disruption" then
		destructionSummon = destructionSummon - 1
		devourerSummon = devourerSummon - 1
	elseif monster == "charged disruption" or monster == "overcharged disruption" then
		destructionSummon = destructionSummon - 1
		devourerSummon = devourerSummon - 1
		grantDestructiveCharge(killer, mostDamageKiller)
	elseif monster == "the hunger" then
		devourerBossesKilled = devourerBossesKilled + 1
		theHungerKilled = true
		addEvent(cleanMiniBossRoom, 60 * 1000, "hunger")
	elseif monster == "the destruction" then
		devourerBossesKilled = devourerBossesKilled + 1
		theDestructionKilled = true
		addEvent(cleanMiniBossRoom, 60 * 1000, "destruction")
	elseif monster == "the rage" then
		devourerBossesKilled = devourerBossesKilled + 1
		theRageKilled = true
		addEvent(cleanMiniBossRoom, 60 * 1000, "rage")
	end
	return true
end

heartMinionDeath:register()
