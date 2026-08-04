-- Furious Scorpion boss room - the reference describes two extra add-waves inside this room
-- ("entering the room spawns 4 skeleton elite warriors when moving left, moving deeper spawns 2
-- undead elite gladiators") that the pre-existing implementation (movements_teleportTo.lua's
-- startBattle) never spawned at all - the room was just the boss alone. The existing, already-working
-- boss-spawn/5-minute-timer/20h-cooldown mechanic in that file is untouched (only 2 reset lines added
-- there, see the end of that file); this adds the two supplementary one-time add-waves inside the
-- same, already-real room bounds.
--
-- Exact tile-level trigger positions aren't given anywhere in the source (only the narrative
-- "moving left"/"moving deeper" description, no coordinates) - the two trigger tiles below are a
-- disclosed, reasonable placement along the same walking corridor (y=32309) the player already
-- crosses between the entry point (32958,32309,8) and the boss spawn (32951,32309,8), not a
-- fabricated new area.
local ScorpionRoomAdds = Storage.Quest.U11_80.TheSecretLibrary.ScorpionRoomAdds
local roomFrom = Position(32943, 32303, 8)
local roomTo = Position(32960, 32315, 8)
local westTrigger = Position(32955, 32309, 8) -- "moving left" from the entry point
local deepTrigger = Position(32949, 32309, 8) -- "moving deeper", just past the boss's spawn point

local function isScorpionAttemptActive()
	local spectators = Game.getSpectators(roomFrom, false, false, 0, 0, 0, 0, roomTo)
	for _, spectator in ipairs(spectators) do
		if spectator:isMonster() and spectator:getName():lower() == "furious scorpion" then
			return true
		end
	end
	return false
end

local addsRoom = MoveEvent()

function addsRoom.onStepIn(creature, item, position, fromPosition)
	local player = creature:getPlayer()
	if not player then
		return true
	end
	if not isScorpionAttemptActive() then
		return true
	end

	if position == westTrigger then
		if Game.getStorageValue(ScorpionRoomAdds.EliteWarriorsSpawned) < 1 then
			Game.setStorageValue(ScorpionRoomAdds.EliteWarriorsSpawned, 1)
			local spawnPositions = {
				Position(32954, 32307, 8),
				Position(32954, 32308, 8),
				Position(32954, 32310, 8),
				Position(32954, 32311, 8),
			}
			for _, spawnPosition in ipairs(spawnPositions) do
				Game.createMonster("Skeleton Elite Warrior", spawnPosition, true, true)
			end
			position:sendMagicEffect(CONST_ME_TELEPORT)
		end
	elseif position == deepTrigger then
		if Game.getStorageValue(ScorpionRoomAdds.EliteGladiatorsSpawned) < 1 then
			Game.setStorageValue(ScorpionRoomAdds.EliteGladiatorsSpawned, 1)
			local spawnPositions = {
				Position(32948, 32308, 8),
				Position(32948, 32310, 8),
			}
			for _, spawnPosition in ipairs(spawnPositions) do
				Game.createMonster("Undead Elite Gladiator", spawnPosition, true, true)
			end
			position:sendMagicEffect(CONST_ME_TELEPORT)
		end
	end
	return true
end

addsRoom:position(westTrigger)
addsRoom:position(deepTrigger)
addsRoom:register()
