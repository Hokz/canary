local armorId = 31482
local armorPos = Position(33398, 32640, 6)
local metalWallId = 31449
local EXIT_POSITION = Position(33395, 32665, 6)

local function createArmor(id, amount, pos)
	local armor = Game.createItem(id, amount, pos)
	if armor then
		armor:setActionId(40003)
	end
end

local mirror = {
	fromPos = Position(33389, 32641, 6),
	toPos = Position(33403, 32655, 6),
	mirrors = { 31474, 31475, 31476, 31477 },
}

-- CORRECTION (two-blocker closure pass section B): moved above terminateRun (was previously declared
-- much later in this file, after the run-lifecycle section) so terminateRun's own room-state
-- restoration can call it directly as a local upvalue instead of risking a forward reference to a
-- not-yet-defined local.
local function backMirror()
	for x = mirror.fromPos.x, mirror.toPos.x do
		for y = mirror.fromPos.y, mirror.toPos.y do
			local sqm = Tile(Position(x, y, 6))

			if sqm then
				for _, id in pairs(mirror.mirrors) do
					local item = sqm:getItemById(id)
					if item then
						item:transform(mirror.mirrors[math.random(#mirror.mirrors)])
						item:getPosition():sendMagicEffect(CONST_ME_POFF)
					end
				end
			end
		end
	end
end

-- CORRECTION (two-blocker closure pass section B): run-independent room-state restoration - Galthen's
-- chestplate's own 30-second respawn and the 10-second mirror reset are both scheduled as ScarlettRun-
-- owned events (see graveScarlettAid below) and get cancelled outright by terminateRun's own event
-- sweep on EVERY terminal path, including a success that happens well before either timer fires. Left
-- alone, that meant the next attempt could start with no chestplate on the ground and mirrors left in
-- a solved/stale state. Called synchronously, once, from terminateRun AFTER old run events are
-- stopped, on every terminal kind (success/normal_timeout/technical_abort) - this restores physical
-- room state, it is not BossLever lifecycle cleanup (see the comment on the BossLever block below).
local function restoreScarlettRoomState()
	local tile = Tile(armorPos)
	local existingArmor = tile and tile:getItemById(armorId)
	if existingArmor then
		-- Idempotent - ensures the action id is correct without duplicating the item.
		existingArmor:setActionId(40003)
	else
		createArmor(armorId, 1, armorPos)
	end
	backMirror()
end

-- ================================================================
-- SCARLETT RUN OWNERSHIP (executor contract, sections 31/34; correction pass section M/N)
-- ================================================================
ScarlettRun = {
	token = 0,
	active = false,
	bossId = nil, -- the one Scarlett Etzel instance this run owns
	participants = {}, -- set: playerId -> true
	events = {}, -- set: eventId -> true
	-- CORRECTION (section M): replaces the previous bare globals SCARLETT_MAY_TRANSFORM/
	-- SCARLETT_MAY_DIE, which belonged to no run/token and could be mutated by a stale callback from
	-- an already-finished attempt affecting a brand new one.
	transformArmed = false, -- mirrors are correctly aligned and the transform sequence may begin
	vulnerable = false, -- Scarlett is currently in her 8-second vulnerability window
	strikeConsumed = false, -- the one legitimate hit for the CURRENT vulnerability window has landed
}

function ScarlettRunIsCurrent(token)
	return token ~= nil and token > 0 and ScarlettRun.active and ScarlettRun.token == token
end

function ScarlettRunCurrentToken()
	if ScarlettRun.active then
		return ScarlettRun.token
	end
	return nil
end

-- CORRECTION (section B/M3): the exact boss identity check - a monster named Scarlett Etzel dying (or
-- taking damage) must belong to the current run before any of it counts.
function ScarlettRunOwnsBoss(creature)
	return creature ~= nil and ScarlettRun.active and ScarlettRun.bossId == creature:getId()
end

function ScarlettRunIsParticipant(token, playerId)
	return ScarlettRunIsCurrent(token) and ScarlettRun.participants[playerId] == true
end

function ScarlettRunTrackEvent(token, eventId)
	if ScarlettRunIsCurrent(token) and eventId then
		ScarlettRun.events[eventId] = true
	end
end

function ScarlettRunSetTransformArmed(token, armed)
	if ScarlettRunIsCurrent(token) then
		ScarlettRun.transformArmed = armed
	end
end

function ScarlettRunIsTransformArmed(token)
	return ScarlettRunIsCurrent(token) and ScarlettRun.transformArmed == true
end

function ScarlettRunSetVulnerable(token, vulnerable)
	if ScarlettRunIsCurrent(token) then
		ScarlettRun.vulnerable = vulnerable
		if vulnerable then
			ScarlettRun.strikeConsumed = false
		end
	end
end

function ScarlettRunIsVulnerable(token)
	return ScarlettRunIsCurrent(token) and ScarlettRun.vulnerable == true and ScarlettRun.strikeConsumed == false
end

-- CORRECTION (section M2): atomic (single synchronous call, no addEvent boundary in between) check-
-- and-set. The FIRST caller within a vulnerability window to reach this sees strikeConsumed still
-- false, flips it to true AND closes vulnerable in the same call, and receives true back; every
-- subsequent call within the same window (even one arriving moments later, before the delayed
-- eventDoDamage callback has actually unlocked her) sees strikeConsumed already true and receives
-- false - it cannot schedule a second special hit.
function ScarlettRunTryConsumeStrike(token)
	if not ScarlettRunIsCurrent(token) or not ScarlettRun.vulnerable or ScarlettRun.strikeConsumed then
		return false
	end
	ScarlettRun.strikeConsumed = true
	ScarlettRun.vulnerable = false
	return true
end

local function terminateRun(token, kind, reason)
	if not ScarlettRunIsCurrent(token) then
		return
	end
	logger.info("GraveDanger/Scarlett: run {} terminated ({}) - {}", token, kind, reason or "")
	ScarlettRun.active = false

	for eventId in pairs(ScarlettRun.events) do
		stopEvent(eventId)
	end

	-- CORRECTION (two-blocker closure pass section B): stale run events (the pending 30s armor
	-- respawn, the pending 10s mirror reset) are cancelled above before they ever run - restoring the
	-- room synchronously here, on every terminal kind, is what actually leaves it ready for the next
	-- attempt instead of depending on those now-dead callbacks. This is physical room-state
	-- restoration only, not BossLever lifecycle cleanup - it runs even on success, where the
	-- kind ~= "success" block below (BossLever's own bossAlive/timeoutEvent/emptyRoomEvent/zone state)
	-- is intentionally still skipped.
	restoreScarlettRoomState()

	if kind == "technical_abort" then
		for playerId in pairs(ScarlettRun.participants) do
			local player = Player(playerId)
			if player then
				player:setBossCooldown("scarlett etzel", 0)
			end
		end
	end

	-- CORRECTION (lifecycle closure pass section A): success cleanup belongs entirely to
	-- BossLeverOnDeath (registered on Scarlett's own monster.events) - see the matching comment in
	-- actions_count_vlarkorth_.lua for the full race-condition rationale.
	if kind ~= "success" then
		local boss = Creature(ScarlettRun.bossId)
		if boss then
			boss:remove()
		end

		-- CORRECTION (correction pass section N, refined by lifecycle closure pass section A): closes
		-- out BossLever's own internal state via a local reference. Order matches BossLever's own
		-- generic timeout callback exactly (refresh, then remove players, then clean) so a
		-- normal_timeout racing ahead of and cancelling BossLever's own timeoutEvent cannot leave
		-- players stranded in an already-cleaned room.
		local bossLever = BossLever["scarlett etzel"]
		if bossLever and bossLever.bossAlive then
			bossLever.bossAlive = false
			if bossLever.emptyRoomEvent then
				stopEvent(bossLever.emptyRoomEvent)
				bossLever.emptyRoomEvent = nil
			end
			if bossLever.timeoutEvent then
				stopEvent(bossLever.timeoutEvent)
				bossLever.timeoutEvent = nil
			end
			local zone = bossLever:getZone()
			zone:refresh()
			zone:removePlayers()
			zone:cleanRoom()
		end
	end

	ScarlettRun.bossId = nil
	ScarlettRun.participants = {}
	ScarlettRun.events = {}
	ScarlettRun.transformArmed = false
	ScarlettRun.vulnerable = false
	ScarlettRun.strikeConsumed = false
end

function ScarlettRunTerminate(token, kind, reason)
	terminateRun(token, kind, reason)
end

-- CORRECTION (section M): a timed-out or emptied attempt previously left ScarlettRun.active stuck
-- true forever (only a legitimate Scarlett kill ever cleared it via creaturescripts_boss_kill.lua),
-- permanently blocking every future Scarlett attempt. Mirrors the fix already applied to every other
-- Lich/Cobra boss in this quest: a flat deadline at the shared BOSS_DEFAULT_TIME_TO_DEFEAT (no custom
-- timeToDefeat is set below) plus a 20-second empty-room poll.
local function watchEmptyRoom(token)
	if not ScarlettRunIsCurrent(token) then
		return
	end
	local zone = Zone("boss." .. toKey("scarlett etzel"))
	if zone and zone:countPlayers() == 0 then
		terminateRun(token, "normal_timeout", "room emptied before the encounter concluded")
		return
	end
	ScarlettRunTrackEvent(token, addEvent(watchEmptyRoom, 20 * 1000, token))
end

-- CORRECTION (executor contract, section 31): every room occupant is now independently verified
-- (level/Premium/Gaffir/Custodian/Quaid), not just whichever single player had earlier interacted
-- with the pillar item at aid 40003.
--
-- CORRECTION (correction pass section K/M4): chess/Roaring Lion completion (ChessComplete) is now
-- REQUIRED, reversing the original pass's deliberate omission. That omission reasoned that gating on
-- an unsatisfiable storage would permanently brick the boss - which is true only if nothing can ever
-- set ChessComplete. This correction pass instead builds the fail-closed path deliberately: the
-- physical chess/Roaring Lion mechanic remains MAP_REQUIRED (see the Manual RME Manifest) and no code
-- path sets ChessComplete yet, so Scarlett is intentionally unreachable until that mechanic is built -
-- this is the explicit project decision in section K, not an accidental brick.
local function validateParticipant(creature)
	if not creature or not creature:isPlayer() then
		return true
	end
	if creature:getLevel() < 250 then
		creature:sendTextMessage(MESSAGE_EVENT_ADVANCE, "All players need to be level 250 or higher.")
		return false
	end
	if not creature:isPremium() then
		creature:sendTextMessage(MESSAGE_EVENT_ADVANCE, "You need a premium account to face Scarlett.")
		return false
	end
	if creature:getStorageValue(Storage.Quest.U12_20.GraveDanger.GaffirKilled) < 1 or creature:getStorageValue(Storage.Quest.U12_20.GraveDanger.CustodianKilled) < 1 or creature:getStorageValue(Storage.Quest.U12_20.GraveDanger.QuaidKilled) < 1 then
		creature:sendTextMessage(MESSAGE_EVENT_ADVANCE, "You are not allowed to face Scarlett yet.")
		return false
	end
	if creature:getStorageValue(Storage.Quest.U12_20.GraveDanger.CobraBastion.ChessComplete) < 1 then
		creature:sendTextMessage(MESSAGE_EVENT_ADVANCE, "You are not allowed to face Scarlett yet.")
		return false
	end
	return true
end

-- Snapshot of the most recent onUseExtra call's infoPositions, consumed synchronously by
-- createFunction below in the same synchronous BossLever:onUse() call.
local lastInfoPositions = nil

local function createScarlettEncounter()
	if ScarlettRun.active then
		logger.error("GraveDanger/Scarlett: a run is already active, refusing a second concurrent start")
		return false
	end

	local scarlett = nil
	for attempt = 1, 3 do
		scarlett = Game.createMonster("Scarlett Etzel", Position(33396, 32643, 6), true, true)
		if scarlett then
			break
		end
		logger.error("GraveDanger/Scarlett: failed to create Scarlett Etzel (attempt {}/3)", attempt)
	end
	if not scarlett then
		logger.error("GraveDanger/Scarlett: technical abort - Scarlett Etzel failed to spawn")
		return false
	end

	scarlett:setStorageValue(Storage.Quest.U12_20.GraveDanger.CobraBastion.Questline, 1)

	ScarlettRun.token = ScarlettRun.token + 1
	local token = ScarlettRun.token
	ScarlettRun.active = true
	ScarlettRun.bossId = scarlett:getId()
	ScarlettRun.participants = {}
	ScarlettRun.events = {}
	ScarlettRun.transformArmed = false
	ScarlettRun.vulnerable = false
	ScarlettRun.strikeConsumed = false

	if lastInfoPositions then
		for _, posInfo in pairs(lastInfoPositions) do
			local player = posInfo.creature
			if player and player:isPlayer() then
				ScarlettRun.participants[player:getId()] = true
			end
		end
	end

	ScarlettRunTrackEvent(
		token,
		addEvent(function()
			terminateRun(token, "normal_timeout", "encounter time limit exceeded")
		end, configManager.getNumber(configKeys.BOSS_DEFAULT_TIME_TO_DEFEAT) * 1000)
	)
	ScarlettRunTrackEvent(token, addEvent(watchEmptyRoom, 20 * 1000, token))

	return true
end

local config = {
	boss = {
		name = "Scarlett Etzel",
		createFunction = createScarlettEncounter,
	},
	requiredLevel = 250,
	playerPositions = {
		{ pos = Position(33395, 32661, 6), teleport = Position(33396, 32651, 6) },
		{ pos = Position(33394, 32662, 6), teleport = Position(33396, 32651, 6) },
		{ pos = Position(33396, 32662, 6), teleport = Position(33396, 32651, 6) },
		{ pos = Position(33395, 32662, 6), teleport = Position(33396, 32651, 6) },
		{ pos = Position(33395, 32663, 6), teleport = Position(33396, 32651, 6) },
	},
	specPos = {
		from = Position(33385, 32638, 6),
		to = Position(33406, 32660, 6),
	},
	onUseExtra = function(creature, infoPositions)
		lastInfoPositions = infoPositions
		return validateParticipant(creature)
	end,
	exit = EXIT_POSITION,
}

local lever = BossLever(config)
lever:position(Position(33395, 32660, 6))
lever:register()

local transformTo = {
	[31474] = 31475,
	[31475] = 31476,
	[31476] = 31477,
	[31477] = 31474,
}

local graveScarlettAid = Action()

function graveScarlettAid.onUse(player, item, fromPosition, target, toPosition, isHotkey)
	-- CONFIRMED BUG (pre-existing): this used `and` between three "not killed" tests, so it only
	-- blocked a player who had killed NONE of the three minibosses - killing any single one granted
	-- full access to the Scarlett encounter. The source requires all three (Gaffir, Custodian, Guard
	-- Captain Quaid). Also switched `~= 1` to `< 1` so any future value >1 still counts as done.
	--
	-- CORRECTION (correction pass section K/M4): also requires ChessComplete, matching the lever's own
	-- validateParticipant - defense in depth for this in-room mechanic, though the lever remains the
	-- authoritative gate.
	if player:getStorageValue(Storage.Quest.U12_20.GraveDanger.GaffirKilled) < 1 or player:getStorageValue(Storage.Quest.U12_20.GraveDanger.CustodianKilled) < 1 or player:getStorageValue(Storage.Quest.U12_20.GraveDanger.QuaidKilled) < 1 or player:getStorageValue(Storage.Quest.U12_20.GraveDanger.CobraBastion.ChessComplete) < 1 then
		player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "You are not allowed to use this yet.")
		return true
	end

	local token = ScarlettRunCurrentToken()

	-- CORRECTION (lifecycle closure pass section E3): mirror rotation and the chestplate transform
	-- sequence must belong to the CURRENT Scarlett attempt's own roster - a player who merely owns the
	-- three-miniboss/chess prerequisite storages but is not part of the currently active run must not
	-- be able to rotate this run's mirrors, consume/use its chestplate, or arm its transform sequence.
	-- The metal-wall interaction below is a separate exit/passage mechanic that legitimately needs to
	-- keep working even with no active run, so it is intentionally NOT gated on this check.
	local isParticipant = token ~= nil and ScarlettRunIsParticipant(token, player:getId())

	if table.contains(transformTo, item.itemid) then
		if not isParticipant then
			return true
		end
		local pilar = transformTo[item.itemid]
		if pilar then
			item:transform(pilar)
			item:getPosition():sendMagicEffect(CONST_ME_POFF)
		end
	elseif item.itemid == armorId then
		if not isParticipant then
			return true
		end
		item:getPosition():sendMagicEffect(CONST_ME_THUNDER)
		item:remove(1)
		player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "You hold the old chestplate of Galthein in front of you. It does not fit and far too old to withstand any attack.")
		-- CORRECTION (correction pass section M1): armor respawn corrected from 20 to the frozen
		-- execution contract's ~30 seconds. Every delayed callback triggered from this interaction is
		-- now run-owned/tracked so a stale chain from an already-finished attempt can never fire
		-- against a newer one.
		ScarlettRunTrackEvent(token, addEvent(createArmor, 30 * 1000, armorId, 1, armorPos))
		ScarlettRunTrackEvent(token, addEvent(backMirror, 10 * 1000))
		ScarlettRunSetTransformArmed(token, true)
		ScarlettRunTrackEvent(
			token,
			addEvent(function()
				ScarlettRunSetTransformArmed(token, false)
			end, 2000)
		)
	elseif item.itemid == metalWallId then
		if player:getPosition().y == 32666 then
			player:teleportTo(Position(33395, 32668, 6))
		else
			player:teleportTo(Position(33395, 32666, 6))
		end
	end

	return true
end

graveScarlettAid:aid(40003)
graveScarlettAid:register()
