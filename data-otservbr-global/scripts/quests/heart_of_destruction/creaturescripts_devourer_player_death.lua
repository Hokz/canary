local devourerStorage = CreatureEvent("DevourerStorage")
function devourerStorage.onDeath(player)
	player:setStorageValue(Storage.HeartOfDestructionFinalBattle.HungerTeam, -1)
	player:setStorageValue(Storage.HeartOfDestructionFinalBattle.DestructionTeam, -1)
	player:setStorageValue(Storage.HeartOfDestructionFinalBattle.RageTeam, -1)
	player:unregisterEvent("DevourerStorage")
	return true
end

devourerStorage:register()
