local teleportHeart = MoveEvent()

local vortexTeleports = {
	[14321] = { pos = Position(32149, 31359, 14) }, -- Charger TP 1
	[14322] = { pos = Position(32092, 31330, 12) }, -- Charger Exit
	[14324] = { pos = Position(32104, 31329, 12) }, -- Anomaly Exit
	[14325] = { pos = Position(32216, 31380, 14) }, -- Main Room
	[14340] = { pos = Position(32159, 31329, 11) }, -- Main Room Exit
	[14341] = { pos = Position(32078, 31320, 13) }, -- Cracklers Exit
	[14343] = { pos = Position(32088, 31321, 13) }, -- Rupture Exit
	[14345] = { pos = Position(32230, 31358, 11) }, -- Realityquake Exit
	[14347] = { pos = Position(32225, 31347, 11) }, -- Unstable Sparks Exit
	[14348] = { pos = Position(32218, 31375, 14) }, -- Eradicator Exit (Main Room)
	[14350] = { pos = Position(32208, 31372, 14) }, -- Outburst Exit (Main Room)
	[14352] = { pos = Position(32214, 31376, 14) }, -- World Devourer Exit (Main Room)
	[14354] = { pos = Position(32112, 31375, 14) }, -- World Devourer (Reward Room)

	[14323] = { -- Anomaly
		position = Position(32246, 31252, 14),
		storage = 14320,
		boss = "Anomaly",
	},
	[14342] = { -- Rupture
		position = Position(32305, 31249, 14),
		storage = 14322,
		boss = "Rupture",
	},
	[14344] = { -- Realityquake
		position = Position(32181, 31240, 14),
		storage = 14324,
		boss = "Realityquake",
	},

	[14346] = { -- Eradicator
		position = Position(32336, 31293, 14),
		storage1 = 14326,
		storage2 = 14327,
		storage3 = 14328,
		boss = "Eradicator",
	},
	[14349] = { -- Outburst
		position = Position(32204, 31290, 14),
		storage1 = 14326,
		storage2 = 14327,
		storage3 = 14328,
		boss = "Outburst",
	},

	[14351] = { special = "worldDevourerEnter" },
	[14353] = { special = "worldDevourerExit" },
}

local function denyAndReturn(player, fromPosition, message)
	player:teleportTo(fromPosition)
	player:sendTextMessage(19, message)
end

function teleportHeart.onStepIn(creature, item, position, fromPosition)
	local player = creature:getPlayer()
	if not player then
		return true
	end

	local data = vortexTeleports[item.actionid]

	if data.pos then
		player:teleportTo(data.pos)
	elseif data.storage then
		if player:getStorageValue(data.storage) >= 1 then
			if player:canFightBoss(data.boss) then
				player:teleportTo(data.position)
			else
				denyAndReturn(player, fromPosition, "It's too early for you to endure this challenge again.")
			end
		else
			denyAndReturn(player, fromPosition, "You don't have access to this portal.")
		end
	elseif data.storage1 then
		if player:getStorageValue(data.storage1) >= 1 and player:getStorageValue(data.storage2) >= 1 and player:getStorageValue(data.storage3) >= 1 then
			if player:canFightBoss(data.boss) then
				player:teleportTo(data.position)
			else
				denyAndReturn(player, fromPosition, "It's too early for you to endure this challenge again.")
			end
		else
			denyAndReturn(player, fromPosition, "You don't have access to this portal.")
		end
	elseif data.special == "worldDevourerEnter" then
		if player:getStorageValue(14330) >= 1 and player:getStorageValue(14332) >= 1 then
			if not player:canFightBoss("World Devourer") then
				denyAndReturn(player, fromPosition, "It's too early for you to endure this challenge again.")
			else
				-- CORRECTION (executor contract, section A): this portal is a checkpoint, not the
				-- commit point. It still requires 5 charges to proceed past it, but no longer deducts
				-- them here - actions_final_lever.lua independently re-validates every participant
				-- (including this same >=5 charge check) and only deducts charges once the full
				-- encounter (roster, room, all 3 mandatory boss spawns) has actually been committed.
				-- Deducting at this portal let a player pay the cost and then have the attempt fail for
				-- an unrelated reason (room occupied, a participant not qualifying, a spawn failure)
				-- with no way to recover the spent charges.
				local charges = math.max(player:getStorageValue(Storage.Quest.U10_94.HeartOfDestruction.DestructiveCharges), 0)
				if charges < 5 then
					denyAndReturn(player, fromPosition, "To face the heart of destruction, you have to gather destructive charges to enter its lair. You gain charges by defeating the masters of the incursions. You have gathered " .. charges .. " of 5 charges.")
				else
					player:teleportTo(Position(32272, 31384, 14))
				end
			end
		else
			denyAndReturn(player, fromPosition, "You don't have access to this portal.")
		end
	elseif data.special == "worldDevourerExit" then
		player:teleportTo(Position(32214, 31376, 14))
		player:setStorageValue(Storage.HeartOfDestructionFinalBattle.HungerTeam, -1)
		player:setStorageValue(Storage.HeartOfDestructionFinalBattle.DestructionTeam, -1)
		player:setStorageValue(Storage.HeartOfDestructionFinalBattle.RageTeam, -1)
		player:unregisterEvent("DevourerStorage")
	end
	return true
end

teleportHeart:type("stepin")

for aid in pairs(vortexTeleports) do
	teleportHeart:aid(aid)
end

teleportHeart:register()
