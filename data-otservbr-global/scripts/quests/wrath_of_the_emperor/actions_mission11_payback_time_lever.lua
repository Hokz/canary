local config = {
	firstboss = "snake god essence",
	bossPosition = Position(33365, 31407, 10),

	trap = "plaguethrower",
	trapPositions = {
		Position(33355, 31403, 10),
		Position(33364, 31403, 10),
		Position(33355, 31410, 10),
		Position(33364, 31410, 10),
	},
	startAreaPosition = Position(33357, 31404, 9),
	arenaPosition = Position(33359, 31406, 10),
}

-- CONFIRMED BUG (found during the WOTE reconciliation audit): the arena lock (Mission11, global
-- scope via Game.setStorageValue - a separate storage space from the same-numbered PLAYER storage
-- used elsewhere for personal Mission 11 progress) was a bare boolean, and its 10-minute safety-net
-- addEvent was never cancelled or tied to a specific run. If run A finished (or was itself swept by
-- this same bug) before its 10-minute timer fired, A's stale callback would free the lock while a
-- newer run B was still in progress, letting a third lever-pull fire the unconditional monster-sweep
-- below and wipe B's live boss/traps with no kill event ever firing - silently stalling B's Mission11
-- progress at 1. This is the exact same bug class already found and fixed in
-- scripts/quests/the_new_frontier/action_arena.lua for that quest's structurally identical lever
-- fight; fixed here the same way, with a run token (shared with creaturescripts_zalamon_kill.lua's
-- boss-form chain via lib/quests/wote_mission11.lua) so a stale callback can never affect a later run.
local currentRunToken = 0

local wrathEmperorMiss11Payback = Action()
function wrathEmperorMiss11Payback.onUse(player, item, fromPosition, target, toPosition, isHotkey)
	if player:getStorageValue(Storage.Quest.U8_6.WrathOfTheEmperor.Questline) ~= 31 then
		-- CONFIRMED GAP (found in review): this only ever checked the shared arena lock, never
		-- whether the player using the lever (or anyone swept in below) was actually sent here by
		-- Awareness Of The Emperor (Questline == 31, set alongside Mission11 == 1 in
		-- npc/awarness_of_the_emperor.lua). Without it, anyone who wandered into the small waiting
		-- room could pull the lever and be dragged into a lethal, scripted boss fight uninvited.
		player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "Nothing happens.")
		return true
	end

	if Game.getStorageValue(WoteMission11.Mission11) > 0 then
		player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "The arena is already in use.")
		return true
	end

	currentRunToken = currentRunToken + 1
	local runToken = currentRunToken
	Game.setStorageValue(WoteMission11.Mission11, runToken)
	addEvent(WoteMission11.releaseRun, 10 * 60 * 1000, runToken)

	local monsters = Game.getSpectators(config.arenaPosition, false, false, 10, 10, 10, 10)
	for i = 1, #monsters do
		if monsters[i]:isMonster() then
			monsters[i]:remove()
		end
	end

	-- Only sweep in players who are themselves eligible (Questline == 31, same check as above) -
	-- an uninvolved bystander standing in the small waiting room is left behind rather than being
	-- dragged into the fight.
	local spectators = Game.getSpectators(config.startAreaPosition, false, true, 0, 5, 0, 5)
	for i = 1, #spectators do
		local spectator = spectators[i]
		if spectator:getStorageValue(Storage.Quest.U8_6.WrathOfTheEmperor.Questline) == 31 then
			spectator:getPosition():sendMagicEffect(CONST_ME_TELEPORT)
			spectator:teleportTo(config.arenaPosition)
			config.arenaPosition:sendMagicEffect(CONST_ME_TELEPORT)
		end
	end

	for i = 1, #config.trapPositions do
		Game.createMonster(config.trap, config.trapPositions[i])
	end

	-- CONFIRMED GAP (found in review): Game.createMonster's result for the first boss was previously
	-- discarded. On failure (bad name, blocked tile), the swept-in players would face empty traps
	-- with no boss ever appearing, stuck until the (previously stale/uncancellable) 10-minute timer
	-- eventually released the lock. A failure now aborts this run immediately via the shared
	-- WoteMission11 helper (clears the traps, releases the lock, logs the failure, and notifies
	-- anyone currently in the arena) rather than leaving players waiting for a boss that was never
	-- going to appear.
	local boss = Game.createMonster(config.firstboss, config.bossPosition)
	if not boss then
		WoteMission11.abortRun(runToken, "(lever pull)", config.firstboss, config.bossPosition)
		player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "The presence of the emperor resists your call. Try again in a moment.")
		return true
	end

	item:transform(item.itemid == 2772 and 2773 or 2772)
	return true
end

wrathEmperorMiss11Payback:uid(3198)
wrathEmperorMiss11Payback:register()
