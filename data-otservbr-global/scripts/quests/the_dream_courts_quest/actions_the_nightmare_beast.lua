local config = {
	boss = {
		name = "The Nightmare Beast",
		position = Position(32208, 32046, 15),
	},
	requiredLevel = 250,
	playerPositions = {
		{ pos = Position(32212, 32070, 15), teleport = Position(32208, 32052, 15), effect = CONST_ME_TELEPORT },
		{ pos = Position(32210, 32070, 15), teleport = Position(32208, 32052, 15), effect = CONST_ME_TELEPORT },
		{ pos = Position(32211, 32070, 15), teleport = Position(32208, 32052, 15), effect = CONST_ME_TELEPORT },
		{ pos = Position(32213, 32070, 15), teleport = Position(32208, 32052, 15), effect = CONST_ME_TELEPORT },
		{ pos = Position(32214, 32070, 15), teleport = Position(32208, 32052, 15), effect = CONST_ME_TELEPORT },
		{ pos = Position(32210, 32071, 15), teleport = Position(32208, 32052, 15), effect = CONST_ME_TELEPORT },
		{ pos = Position(32211, 32071, 15), teleport = Position(32208, 32052, 15), effect = CONST_ME_TELEPORT },
		{ pos = Position(32212, 32071, 15), teleport = Position(32208, 32052, 15), effect = CONST_ME_TELEPORT },
		{ pos = Position(32213, 32071, 15), teleport = Position(32208, 32052, 15), effect = CONST_ME_TELEPORT },
		{ pos = Position(32214, 32071, 15), teleport = Position(32208, 32052, 15), effect = CONST_ME_TELEPORT },
	},
	specPos = {
		from = Position(32195, 32035, 15),
		to = Position(32220, 32055, 15),
	},
	exit = Position(32211, 32084, 15),
	-- The curse mechanic is gated by a SERVER-WIDE lock (DreamScarGlobal.LastBossCurse). Releasing it
	-- on the boss's death alone is not sufficient: a party wipe or the fight timeout tears the room
	-- down through BossLever's watchEmptyRoom -> handleEmptyRoom -> cleanRoom() / removePlayers()
	-- paths, none of which fire onDeath - so a lock set mid-fight would survive the reset and silently
	-- disable the curse for every future party until someone finally killed the boss. Clearing it as
	-- each fight begins makes the lock self-healing regardless of how the previous attempt ended.
	-- Must not return false: BossLever aborts the lever when onUseExtra returns exactly false.
	onUseExtra = function()
		Game.setStorageValue(Storage.Quest.U12_00.TheDreamCourts.DreamScarGlobal.LastBossCurse, 0)
	end,
}

local lever = BossLever(config)
lever:position({ x = 32212, y = 32069, z = 15 })
lever:register()
