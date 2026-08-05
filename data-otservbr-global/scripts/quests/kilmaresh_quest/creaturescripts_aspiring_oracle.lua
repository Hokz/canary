-- "Aspiring Oracle" (added 12.70) - did not exist before this pass.
local enusatDeath = CreatureEvent("AspiringOracleEnusatDeath")

function enusatDeath.onDeath(creature, corpse, killer, mostDamageKiller)
	local attackers = creature:getDamageMap()
	for attackerId, _ in pairs(attackers) do
		local player = Player(attackerId)
		if player and player:getStorageValue(Storage.Quest.U12_20.KilmareshQuest.AspiringOracle.EnusatKilled) < 1 then
			player:setStorageValue(Storage.Quest.U12_20.KilmareshQuest.AspiringOracle.EnusatKilled, 1)
		end
	end

	return true
end

enusatDeath:register()
