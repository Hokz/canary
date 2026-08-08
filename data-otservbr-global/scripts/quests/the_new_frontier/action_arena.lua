local config = {
	bosses = {
		{ "Baron Brute", "The Axeorcist" },
		{ "Menace", "Fatality" },
		{ "Incineron", "Coldheart" },
		{ "Dreadwing", "Doomhowl" },
		{ "Haunter", "The Dreadorian" },
		{ "Rocko", "Tremorak" },
		{ "Tirecz" },
	},

	playerPos = {
		Position(33080, 31014, 2),
		Position(33081, 31014, 2),
	},

	teleportPositions = {
		Position(33059, 31032, 3),
		Position(33057, 31034, 3),
	},

	positions = {
		-- other bosses
		Position(33065, 31035, 3),
		Position(33068, 31034, 3),

		-- first 2 bosses
		Position(33065, 31033, 3),
		Position(33066, 31037, 3),
	},
}
local TheNewFrontier = Storage.Quest.U8_54.TheNewFrontier

-- CONFIRMED BUG (found in review): the arena lock (TheNewFrontier.Mission09[1], global scope via
-- Game.setStorageValue - a separate storage space from the same-numbered PLAYER storage used
-- elsewhere for personal Mortal Combat progress) was a bare boolean. Every scheduled callback
-- (summonBoss waves, the 30-minute timeout) carried no notion of WHICH run it belonged to, so:
--   * if Tirecz was never killed, the 30-minute timeout swept the room but never reset the lock
--     (only TireczDeath did), permanently rejecting every future attempt;
--   * even a naive `clearArena(); setStorageValue(-1)` timeout fix would be wrong on its own: if run A
--     finishes and run B starts before A's 30-minute timer fires, A's stale timeout would still fire
--     and rip run B's monsters and players out mid-fight;
--   * the same staleness applies to every individual wave's summonBoss callback.
-- Fixed with a run token: each successful lever pull gets a locally-unique, monotonically increasing
-- token (a module-level counter - guaranteed unique for the server's lifetime, no collision risk from
-- time-based seeds). The lock now stores the CURRENT run's token instead of a bare 1, and every
-- scheduled callback is handed that same token and checks it still owns the lock before doing
-- anything. A callback whose token no longer matches belongs to an abandoned run and is a silent no-op.
local currentRunToken = 0

local function isCurrentRun(runToken)
	return runToken > 0 and Game.getStorageValue(TheNewFrontier.Mission09[1]) == runToken
end

local function sweepArena(destination)
	local spectators = Game.getSpectators(Position(33063, 31034, 3), false, false, 10, 10, 10, 10)
	for i = 1, #spectators do
		local spectator = spectators[i]
		if spectator:isPlayer() then
			spectator:teleportTo(destination)
			destination:sendMagicEffect(CONST_ME_TELEPORT)
		else
			spectator:remove()
		end
	end
end

-- Shared by the 30-minute timeout and by an aborted run (monster creation failure): both must sweep
-- the room and release the lock, and both must be a no-op if a newer run has since taken over.
local function endRun(runToken)
	if not isCurrentRun(runToken) then
		return
	end

	sweepArena(Position(33049, 31017, 2))
	Game.setStorageValue(TheNewFrontier.Mission09[1], -1)
end

local function summonBoss(runToken, name, position)
	if not isCurrentRun(runToken) then
		return
	end

	-- CONFIRMED GAP (found in review): Game.createMonster's result was previously discarded. On
	-- failure (bad name, no free tile) the wave silently never arrived, and since this and every later
	-- wave still fire on schedule, the two trapped players (the arena has no normal exit once locked)
	-- would wait indefinitely for a Tirecz that was never going to appear. A failure now aborts only
	-- this run - sweeps both players out and releases the lock - rather than leaving them stuck.
	local monster = Game.createMonster(name, position)
	if not monster then
		endRun(runToken)
		return
	end

	position:sendMagicEffect(CONST_ME_TELEPORT)
end

local theNewFrontierArena = Action()
function theNewFrontierArena.onUse(player, item, fromPosition, target, toPosition, isHotkey)
	-- CONFIRMED GAP (found in review): this only rejected players who had already FINISHED the fight
	-- (Questline >= 26). It never checked that a platform occupant was actually eligible to be here in
	-- the first place - Questline == 25 is set only after speaking to Chrak and agreeing to the poison
	-- ("battle"/"yes"), which is the reference's real entry requirement. Without it, an uninvolved
	-- bystander standing on the platform (deliberately or by accident) could be pulled into a lethal,
	-- inescapable arena alongside a real participant, for no possible benefit to either of them, and
	-- with no way for the bystander to ever be credited at Tirecz's death. The reference also states a
	-- minimum level of 70, which was not checked anywhere in this quest.
	for a = 1, #config.playerPos do
		local creature = Tile(config.playerPos[a]):getTopCreature()
		if not creature or not creature:isPlayer() then
			return player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "Both platforms must be occupied by players.")
		end

		if creature:getStorageValue(TheNewFrontier.Questline) >= 26 then
			return player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "You already finished this battle.")
		end

		if creature:getStorageValue(TheNewFrontier.Questline) ~= 25 then
			return player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "Both competitors must have agreed to the tournament with Chrak first.")
		end

		if creature:getLevel() < 70 then
			return player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "Both competitors must be at least level 70.")
		end
	end

	if Game.getStorageValue(TheNewFrontier.Mission09[1]) > 0 then
		return player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "The arena is already in use.")
	end

	currentRunToken = currentRunToken + 1
	local runToken = currentRunToken
	Game.setStorageValue(TheNewFrontier.Mission09[1], runToken)
	addEvent(endRun, 30 * 60 * 1000, runToken)

	for b = 1, #config.playerPos do
		local creature = Tile(config.playerPos[b]):getTopCreature()
		creature:getPosition():sendMagicEffect(CONST_ME_TELEPORT)
		creature:teleportTo(config.teleportPositions[b])
		creature:getPosition():sendMagicEffect(CONST_ME_TELEPORT)
	end

	for i = 1, #config.bosses do
		for j = 1, #config.bosses[i] do
			addEvent(summonBoss, (i - 1) * 90 * 1000, runToken, config.bosses[i][j], config.positions[j + (i == 1 and 2 or 0)])
		end
	end
	return true
end

theNewFrontierArena:aid(30003)
theNewFrontierArena:register()
