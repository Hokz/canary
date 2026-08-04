local Invasion = Storage.Quest.U11_80.TheSecretLibrary.SecretLibraryInvasion

local config = {
	boss = {
		-- Spawns the 100%-immune placeholder, not the real fight, matching "the leader of the
		-- invasion finally joins the battle" only after all 4 wings are cleared - see
		-- movements_invasion_start.lua's InvasionCheckWingsCleared, which swaps this to the real
		-- "The Scourge of Oblivion" type once that happens. Previously this spawned the real boss
		-- immediately with zero wave/wing sequence at all.
		name = "The Scourge of Oblivion (Dormant)",
		position = Position(32726, 32727, 11),
	},
	requiredLevel = 250,
	timeToDefeat = 26 * 60 + 20, -- exact total encounter duration per the reference
	onUseExtra = function(player, infoPositions)
		-- Resets this quest's own invasion state at the start of every fresh attempt, independent
		-- of whether the previous attempt was won, lost, or timed out - movements_invasion_start.lua
		-- would otherwise see a stale non-zero Started value and refuse to restart the wave timer.
		Game.setStorageValue(Invasion.Started, 0)
		Game.setStorageValue(Invasion.SpellstealerDefeated, 0)
		Game.setStorageValue(Invasion.ScionOfHavocDefeated, 0)
		Game.setStorageValue(Invasion.BrothersDefeated, 0)
		Game.setStorageValue(Invasion.DevourerDefeated, 0)
		Game.setStorageValue(Invasion.ScourgePhase, 0)
		return true
	end,
	playerPositions = {
		{ pos = Position(32676, 32743, 11), teleport = Position(32726, 32733, 11), effect = CONST_ME_TELEPORT },
		{ pos = Position(32676, 32744, 11), teleport = Position(32726, 32733, 11), effect = CONST_ME_TELEPORT },
		{ pos = Position(32676, 32745, 11), teleport = Position(32726, 32733, 11), effect = CONST_ME_TELEPORT },
		{ pos = Position(32676, 32741, 11), teleport = Position(32726, 32733, 11), effect = CONST_ME_TELEPORT },
		{ pos = Position(32676, 32742, 11), teleport = Position(32726, 32733, 11), effect = CONST_ME_TELEPORT },
		{ pos = Position(32677, 32741, 11), teleport = Position(32726, 32733, 11), effect = CONST_ME_TELEPORT },
		{ pos = Position(32677, 32742, 11), teleport = Position(32726, 32733, 11), effect = CONST_ME_TELEPORT },
		{ pos = Position(32677, 32743, 11), teleport = Position(32726, 32733, 11), effect = CONST_ME_TELEPORT },
		{ pos = Position(32677, 32744, 11), teleport = Position(32726, 32733, 11), effect = CONST_ME_TELEPORT },
		{ pos = Position(32677, 32745, 11), teleport = Position(32726, 32733, 11), effect = CONST_ME_TELEPORT },
	},
	specPos = {
		from = Position(32712, 32723, 11),
		to = Position(32738, 32748, 11),
	},
	exit = Position(32480, 32599, 15),
}

local lever = BossLever(config)
lever:position(Position(32675, 32743, 11))
lever:register()
