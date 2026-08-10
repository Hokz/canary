-- Small, scoped shared state/helpers for WOTE Mission 11's boss-form encounter (the "Zalamon"
-- arena fight: Snake God Essence -> Snake Thing -> Lizard Abomination -> Mutated Zalamon). NOT a
-- generic arena framework - this exists only so
-- scripts/quests/wrath_of_the_emperor/actions_mission11_payback_time_lever.lua (starts the run,
-- owns the run-token counter and the shared arena lock) and
-- scripts/quests/wrath_of_the_emperor/creaturescripts_zalamon_kill.lua (advances the boss-form
-- chain on each kill) can share the same abort/cleanup logic without duplicating it.
--
-- The arena lock is Storage.Quest.U8_6.WrathOfTheEmperor.Mission11 via the GLOBAL storage
-- namespace (Game.getStorageValue/setStorageValue) - a separate storage space from the
-- same-numbered PLAYER storage used elsewhere for personal Mission 11 questlog progress.

WoteMission11 = WoteMission11 or {}

WoteMission11.Mission11 = Storage.Quest.U8_6.WrathOfTheEmperor.Mission11
WoteMission11.arenaPosition = Position(33359, 31406, 10)

---True while runToken still owns the shared arena lock.
---@param runToken number
---@return boolean
function WoteMission11.isCurrentRun(runToken)
	return runToken > 0 and Game.getStorageValue(WoteMission11.Mission11) == runToken
end

---Releases the arena lock and removes every monster currently in the arena (bosses/forms and
---traps). A no-op if runToken no longer owns the lock (a stale/already-ended run's callback).
---@param runToken number
function WoteMission11.releaseRun(runToken)
	if not WoteMission11.isCurrentRun(runToken) then
		return
	end

	Game.setStorageValue(WoteMission11.Mission11, -1)

	local spectators = Game.getSpectators(WoteMission11.arenaPosition, false, false, 10, 10, 10, 10)
	for i = 1, #spectators do
		if spectators[i]:isMonster() then
			spectators[i]:remove()
		end
	end
end

---Aborts an in-progress run after a confirmed monster-spawn failure (a required next boss form, or
---the first boss, could not be created): logs the failure, tells any player currently in the arena,
---removes the encounter's monsters, and releases the lock so the arena can be retried later. Does
---NOT teleport players anywhere - whether the arena has a reachable exit without a forced teleport
---was not independently proven, so the safer, smaller change is to release the lock/clear the
---encounter and let a survivor leave the way they came in. CUSTOM_GLOBAL_LIKE_FAILURE_RECOVERY -
---the owner reference does not document what should happen if a boss-form transition fails to
---spawn; this is the smallest recovery that avoids a permanently locked arena.
---@param runToken number
---@param currentForm string
---@param requiredNextForm string
---@param position Position
function WoteMission11.abortRun(runToken, currentForm, requiredNextForm, position)
	if not WoteMission11.isCurrentRun(runToken) then
		return
	end

	logger.error("[WOTE Mission11] Failed to spawn required next form '{}' after '{}' died at {} - aborting run {}", requiredNextForm, currentForm, position:toString(), runToken)

	local spectators = Game.getSpectators(WoteMission11.arenaPosition, false, true, 10, 10, 10, 10)
	for i = 1, #spectators do
		spectators[i]:sendTextMessage(MESSAGE_EVENT_ADVANCE, "The presence of the emperor falters and fades. Something has gone wrong - try again later.")
	end

	WoteMission11.releaseRun(runToken)
end

---Attempts to spawn the required next boss form, with one bounded retry before giving up (the
---monster creation call already uses extended=true, which lets the engine place it on a nearby
---free tile if the exact spot is blocked - a second attempt covers a transient failure rather than
---silently dropping the rest of the mandatory form chain, as the un-audited code used to). A hard
---failure (both attempts return nil) aborts the run via WoteMission11.abortRun instead of pretending
---progression occurred.
---@param currentForm string
---@param nextForm string
---@param position Position
---@param runToken number
---@param sayText string
---@return boolean
function WoteMission11.spawnNextForm(currentForm, nextForm, position, runToken, sayText)
	local monster = Game.createMonster(nextForm, position, false, true)
	if not monster then
		monster = Game.createMonster(nextForm, position, false, true)
	end

	if not monster then
		WoteMission11.abortRun(runToken, currentForm, nextForm, position)
		return false
	end

	monster:say(sayText, TALKTYPE_MONSTER_SAY)
	return true
end
