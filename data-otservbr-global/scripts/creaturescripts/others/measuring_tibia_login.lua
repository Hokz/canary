-- Measuring Tibia - reapplies the movement speed bonus on login.
--
-- Creature:changeSpeed only modifies the in-memory speed field (confirmed via Game::changeSpeed in
-- src/game/game.cpp - it calls creature->setSpeed(), never a DB save), so any bonus granted during a
-- previous session is gone the moment the player logs back in. This restores it from scratch, based
-- on the player's real current position and their persisted CompletedAreaCount - not by trusting
-- whatever SpeedBonusApplied says was left over from before.
local measuringTibiaLogin = CreatureEvent("MeasuringTibiaLogin")

function measuringTibiaLogin.onLogin(player)
	player:setStorageValue(Storage.Quest.U11_80.MeasuringTibia.SpeedBonusApplied, 0)
	MeasuringTibia.recalculateSpeedBonus(player)
	return true
end

measuringTibiaLogin:register()
