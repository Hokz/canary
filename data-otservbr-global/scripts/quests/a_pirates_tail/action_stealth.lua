-- Rascacoon Trust Points / Stealth - sneak through the pirats' laboratory complex unnoticed
-- within 300 seconds while wearing a time-limited enchanted rat disguise, staying clear of
-- guards/patrols and away from lit lamps. 200 trust points on completion via the chest at the
-- end, 20h cooldown. Up to 3 players may attempt together.
--
-- ACCEPTABLE_GLOBAL_LIKE simplification, disclosed: the reference has a stationary Pirate Guard,
-- a moving Pirate Patrol, and separate wall lamps with independent flicker timing. Without exact
-- positions/paths, this generalizes both guards and patrol into a single "danger zone" list
-- (position + radius, checked periodically) and lamps into a second list whose on/off state
-- flickers on a shared world timer - the core "stay out of lit areas, keep distance from guards,
-- the disguise can expire" loop is preserved even though patrol movement itself isn't animated.
--
-- MAP SETUP REQUIRED: STEALTH_ROOM below needs real positions - see the Map Setup Contract.
local STEALTH_ROOM = {
	entryAid = 45940,
	entry = nil, -- Position
	disguiseAid = 45941, -- the disguise item placed at the entrance
	exitAids = { 45942, 45943 }, -- either works, per the reference
	chestRoom = nil, -- Position: where both exit teleports lead
	rewardChestAid = 45944,
	dangerZones = {}, -- list of { position = Position, radius = number } (guards + patrol)
	lamps = {}, -- list of Position
	checkZone = nil, -- { from = Position, to = Position } - bounds used to know a player is still inside
}

local DURATION = 300 * 1000 -- 5 minutes
local DISGUISE_DURATION = 240 * 1000 -- 4 minutes - deliberately less than the full run time, matching "don't be too tardy"
local COOLDOWN = 20 * 3600
local TRUST_REWARD = 200
local CHECK_INTERVAL = 3 * 1000
local LAMP_FLICKER_INTERVAL = 8 * 1000

local APiratesTail = Storage.Quest.U12_60.APiratesTail

local lampsOn = {} -- lamp index -> bool, shared world state (physical lamps, not per-player)

local lampFlicker = GlobalEvent("APiratesTailStealthLamps")
function lampFlicker.onThink(interval)
	for i = 1, #STEALTH_ROOM.lamps do
		lampsOn[i] = math.random() < 0.5
	end
	return true
end
lampFlicker:interval(LAMP_FLICKER_INTERVAL)
lampFlicker:register()

local function isDetected(player)
	local expiry = player:getStorageValue(APiratesTail.Mission03.StealthDisguiseExpiry)
	if expiry < os.time() then
		return true -- disguise expired
	end
	local position = player:getPosition()
	for _, zone in ipairs(STEALTH_ROOM.dangerZones) do
		if position:isInRange(zone.position, zone.radius, zone.radius) then
			return true
		end
	end
	for i, lampPosition in ipairs(STEALTH_ROOM.lamps) do
		if lampsOn[i] and position:isInRange(lampPosition, 1, 1) then
			return true
		end
	end
	return false
end

local function failAttempt(player)
	if player:getStorageValue(APiratesTail.Mission03.StealthDisguiseExpiry) < 0 then
		return -- already ended
	end
	player:setStorageValue(APiratesTail.Mission03.StealthDisguiseExpiry, -1)
	player:removeIcon("stealth-timer")
	player:setStorageValue(APiratesTail.Mission03.StealthCooldown, os.time() + COOLDOWN)
	player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "You've been spotted! The guards throw you out.")
	if STEALTH_ROOM.entry then
		-- ejected back near the start; the reference doesn't specify a separate fail-exit
		player:teleportTo(STEALTH_ROOM.entry)
	end
end

local function tickStealth(player, remainingSeconds)
	if player:getStorageValue(APiratesTail.Mission03.StealthDisguiseExpiry) < 0 then
		return -- attempt already ended (success or failure)
	end
	if isDetected(player) then
		failAttempt(player)
		return
	end
	if remainingSeconds <= 0 then
		failAttempt(player)
		return
	end
	player:setIcon("stealth-timer", CreatureIconCategory_Quests, CreatureIconQuests_ExclamationMark, remainingSeconds)
	addEvent(tickStealth, CHECK_INTERVAL, player, remainingSeconds - (CHECK_INTERVAL / 1000))
end

local stealthEntry = Action()
function stealthEntry.onUse(player, item, fromPosition, target, toPosition, isHotkey)
	if not STEALTH_ROOM.entry then
		player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "This entrance leads nowhere yet.")
		return true
	end
	if player:getStorageValue(APiratesTail.Mission03.StealthCooldown) > os.time() then
		player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "You need to wait before attempting Stealth again.")
		return true
	end
	player:teleportTo(STEALTH_ROOM.entry)
	player:setStorageValue(APiratesTail.Mission03.StealthDisguiseExpiry, 0) -- marks the attempt as active, disguise not yet picked up; the countdown only starts once the disguise is worn
	return true
end
stealthEntry:aid(STEALTH_ROOM.entryAid)
stealthEntry:register()

local disguisePickup = Action()
function disguisePickup.onUse(player, item, fromPosition, target, toPosition, isHotkey)
	player:setStorageValue(APiratesTail.Mission03.StealthDisguiseExpiry, os.time() + DISGUISE_DURATION / 1000)
	player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "You put on the enchanted rat disguise. It won't last forever.")
	tickStealth(player, DURATION / 1000)
	return true
end
disguisePickup:aid(STEALTH_ROOM.disguiseAid)
disguisePickup:register()

local stealthExit = MoveEvent()
function stealthExit.onStepIn(creature, item, position, fromPosition)
	local player = creature:getPlayer()
	if not player then
		return true
	end
	if STEALTH_ROOM.chestRoom then
		player:teleportTo(STEALTH_ROOM.chestRoom)
		player:getPosition():sendMagicEffect(CONST_ME_TELEPORT)
	end
	return true
end
for _, aid in ipairs(STEALTH_ROOM.exitAids) do
	stealthExit:aid(aid)
end
stealthExit:register()

local rewardChest = Action()
function rewardChest.onUse(player, item, fromPosition, target, toPosition, isHotkey)
	if player:getStorageValue(APiratesTail.Mission03.StealthDisguiseExpiry) <= os.time() then
		player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "There is nothing here for you.")
		return true
	end
	player:setStorageValue(APiratesTail.Mission03.StealthDisguiseExpiry, -1)
	player:removeIcon("stealth-timer")
	player:setStorageValue(APiratesTail.Mission03.StealthCooldown, os.time() + COOLDOWN)
	local trust = math.max(player:getStorageValue(APiratesTail.Mission03.TrustPoints), 0)
	player:setStorageValue(APiratesTail.Mission03.TrustPoints, trust + TRUST_REWARD)
	player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "You slip away unnoticed, having sabotaged the green powder production. You earned 200 trust points.")
	return true
end
rewardChest:aid(STEALTH_ROOM.rewardChestAid)
rewardChest:register()
