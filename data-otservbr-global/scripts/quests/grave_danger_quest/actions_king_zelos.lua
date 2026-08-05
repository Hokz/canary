local config = {
	boss = {
		name = "King Zelos",
		position = Position(33443, 31545, 13),
	},
	requiredLevel = 250,
	playerPositions = {
		{ pos = Position(33485, 31546, 13), teleport = Position(33443, 31554, 13), effect = CONST_ME_TELEPORT },
		{ pos = Position(33485, 31547, 13), teleport = Position(33443, 31554, 13), effect = CONST_ME_TELEPORT },
		{ pos = Position(33485, 31548, 13), teleport = Position(33443, 31554, 13), effect = CONST_ME_TELEPORT },
		{ pos = Position(33485, 31545, 13), teleport = Position(33443, 31554, 13), effect = CONST_ME_TELEPORT },
		{ pos = Position(33485, 31544, 13), teleport = Position(33443, 31554, 13), effect = CONST_ME_TELEPORT },
		{ pos = Position(33486, 31546, 13), teleport = Position(33443, 31554, 13), effect = CONST_ME_TELEPORT },
		{ pos = Position(33486, 31547, 13), teleport = Position(33443, 31554, 13), effect = CONST_ME_TELEPORT },
		{ pos = Position(33486, 31548, 13), teleport = Position(33443, 31554, 13), effect = CONST_ME_TELEPORT },
		{ pos = Position(33486, 31545, 13), teleport = Position(33443, 31554, 13), effect = CONST_ME_TELEPORT },
		{ pos = Position(33486, 31544, 13), teleport = Position(33443, 31554, 13), effect = CONST_ME_TELEPORT },
	},
	-- CONFIRMED BLOCKER (pre-existing): the four wing lich-knights were never spawned by anything.
	-- creaturescripts_king_zelos.lua declares a `config.summons` table listing them, but that table is
	-- never referenced again anywhere in that file, and this lever config had no `monsters` list - so
	-- the four wing rooms were empty and movements_zelos_tp.lua (which gates the final green teleport
	-- on those four bosses being absent by name) let players walk straight to King Zelos from second
	-- zero. Positions are taken verbatim from that dead config table.
	monsters = {
		{ name = "Rewar The Bloody", pos = Position(33463, 31562, 13) },
		{ name = "The Red Knight", pos = Position(33423, 31562, 13) },
		{ name = "Magnor Mournbringer", pos = Position(33463, 31529, 13) },
		{ name = "Nargol The Impaler", pos = Position(33423, 31529, 13) },
	},
	-- The source gives a hard 24-minute limit from pulling the lever. Without this the shared
	-- BossLever default (BOSS_DEFAULT_TIME_TO_DEFEAT, 20 minutes) applied silently.
	timeToDefeat = 24 * 60,
	-- specPos previously covered only the central room (33433,31535)-(33453,31555), which does NOT
	-- contain the four wing rooms the bosses spawn in. That would leave the wing bosses outside the
	-- BossLever zone, so room cleanup on wipe/timeout would never remove them. Widened to the full
	-- arena bounds, taken verbatim from the dead config's fromPos/toPos.
	specPos = {
		from = Position(33414, 31520, 13),
		to = Position(33474, 31574, 13),
	},
	exit = Position(32172, 31918, 8),
	-- Stamps the ritual start time so creaturescripts_king_zelos.lua can scale King Zelos's power by
	-- how long the team took to clear the four wings ("the further the ritual progresses when you face
	-- him, he will become considerably more powerful"). Must not return false: BossLever aborts the
	-- lever when onUseExtra returns exactly false.
	onUseExtra = function()
		Game.setStorageValue(Storage.Quest.U12_20.GraveDanger.KingZelosRitualStart, os.time())
	end,
}

local lever = BossLever(config)
lever:position(Position(33484, 31546, 13))
lever:register()
