-- "Aspiring Oracle" (added 12.70) - did not exist before this pass.
local enusatDeath = CreatureEvent("AspiringOracleEnusatDeath")

-- CONFIRMED BUG (found via review): credited ANY attacker on Enusat's death with no check that they
-- had actually reached the stage where Taya reveals him (AspiringOracle.Questline == 6) - a player
-- who found and killed him before ever meeting Taya (a wild-spawn boss is reachable by anyone) would
-- be credited for a mission step they hadn't unlocked, letting them skip straight to reporting.
function enusatDeath.onDeath(creature, corpse, killer, mostDamageKiller)
	local attackers = creature:getDamageMap()
	for attackerId, _ in pairs(attackers) do
		local player = Player(attackerId)
		if player and player:getStorageValue(Storage.Quest.U12_20.KilmareshQuest.AspiringOracle.Questline) == 6 and player:getStorageValue(Storage.Quest.U12_20.KilmareshQuest.AspiringOracle.EnusatKilled) < 1 then
			player:setStorageValue(Storage.Quest.U12_20.KilmareshQuest.AspiringOracle.EnusatKilled, 1)
		end
	end

	return true
end

enusatDeath:register()
