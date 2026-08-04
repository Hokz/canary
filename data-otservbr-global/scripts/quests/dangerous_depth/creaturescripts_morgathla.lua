-- Final boss (Morgathla / Ancient Spawn of Morgathla) - a real 4-room gauntlet, not spawn-and-kill.
-- Reuses the exact reactive-scan style already established by this quest's other 3 bosses
-- (creaturescripts_the_baron_from_below.lua, creaturescripts_fiery_heart.lua,
-- actions_using_crystals.lua's checarSala/lavaHoles) rather than introducing a new pattern.
--
-- Per room: kill enough Ancient Scarabs to summon the boss (spawns in its invulnerable "Dormant"
-- form) -> lure it onto one of the room's blue portals to make it vulnerable (type-swaps to the
-- real "Ancient Spawn of Morgathla" type, preserving current
-- health, exactly like the pre-existing Fire Empowered Duke <-> Duke of the Depths swap) -> more
-- scarabs reinforce and strengthen the boss if killed carelessly, geysers and fire traps hit the
-- room periodically -> rooms 1-3 "retreat" once damaged to that room's health floor (boss removed,
-- not killed, room resets); room 4 is a real kill (achievement, loot, reward chest access).
--
-- MAP SETUP REQUIRED: every position below is nil until an owner configures it - see the Map
-- Setup Contract in the PR body. Until then this is fully inert code, same pattern as every other
-- position-dependent script built this session.
--
-- scarabsRequired is MAP SETUP GUIDANCE, not a runtime-enforced counter: watchScarabWave's actual
-- gate is "every currently-spawned Ancient Scarab in the room is dead", so the owner should place
-- exactly this many scarabSpawns positions per room for the intended per-room difficulty to apply.
local ROOMS = {
	[1] = {
		center = nil, -- Position: used for all spectator scans in this room
		scarabSpawns = {}, -- list of Position: initial trash wave, should have scarabsRequired entries
		scarabsRequired = 8,
		bossSpawn = nil, -- Position
		portals = {}, -- list of Position: blue portals the Dormant boss must be lured onto
		geysers = {}, -- list of Position
		fireTraps = {}, -- list of Position
		exitTeleport = nil, -- Position: opens once this room's boss retreats
		nextRoomEntry = nil, -- Position: where the exit teleport sends players
		retreatMessage = "THE SPAWN RETREATS TO ANOTHER AREA IN THE NORTH-EAST!",
		retreatHealthFloor = 180000, -- vulnerable-phase HP threshold that triggers the retreat
		final = false,
	},
	[2] = {
		center = nil,
		scarabSpawns = {},
		scarabsRequired = 10,
		bossSpawn = nil,
		portals = {},
		geysers = {},
		fireTraps = {},
		exitTeleport = nil,
		nextRoomEntry = nil,
		retreatMessage = "THE SPAWN RETREATS TO ANOTHER AREA IN THE NORTH-EAST!",
		retreatHealthFloor = 180000,
		final = false,
	},
	[3] = {
		center = nil,
		scarabSpawns = {},
		scarabsRequired = 12,
		bossSpawn = nil,
		portals = {},
		geysers = {},
		fireTraps = {},
		exitTeleport = nil,
		nextRoomEntry = nil,
		retreatMessage = "THE SPAWN RETREATS TO ANOTHER AREA IN THE SOUTH EAST!",
		retreatHealthFloor = 180000,
		final = false,
	},
	[4] = {
		center = nil,
		scarabSpawns = {},
		scarabsRequired = 15,
		bossSpawn = nil,
		portals = {},
		geysers = {},
		fireTraps = {},
		northRewardTeleport = nil, -- Position: leads to the reward chest room
		southReturnTeleport = nil, -- Position: leads back to the start near Gnomus
		final = true,
	},
}

local DORMANT_NAME = "ancient spawn of morgathla (dormant)"
local VULNERABLE_NAME = "ancient spawn of morgathla"
local SCARAB_NAME = "ancient scarab"
local GEYSER_DAMAGE = { 800, 1500 }
local FIRE_TRAP_DAMAGE = { 2000, 4000 }
local PORTAL_COOLDOWN = 20 * 1000
local HAZARD_INTERVAL = 12 * 1000
local SCARAB_REINFORCE_INTERVAL = 25 * 1000

local function spectatorsInRoom(room)
	if not room.center then
		return {}
	end
	return Game.getSpectators(room.center, false, false, 20, 20, 20, 20)
end

local function countMonsterByName(spectators, name)
	local count = 0
	for _, creature in ipairs(spectators) do
		if creature:isMonster() and creature:getName():lower() == name then
			count = count + 1
		end
	end
	return count
end

-- Geysers and fire traps: reuses the exact activate/warn-then-explode item-swap pattern already
-- established by actions_using_crystals.lua's lavaHoles (items 390/391), applied to two new hazard
-- pairs at higher damage. Runs for the room's whole active lifetime (room.active, set by startRoom
-- and cleared once the boss retreats/dies) - NOT gated on "is the boss currently summoned", since
-- that would kill the polling chain for good the moment it fires once during the scarab-wave
-- phase (before any boss exists yet) and hazards would never start once the boss did appear.
local function scheduleHazards(roomIndex)
	local room = ROOMS[roomIndex]
	local function tick()
		if not room.active then
			return
		end
		if #room.geysers > 0 then
			local position = room.geysers[math.random(1, #room.geysers)]
			position:sendMagicEffect(CONST_ME_GROUNDSHAKER)
			addEvent(function()
				for _, spectator in ipairs(Game.getSpectators(position, false, true, 2, 2, 2, 2)) do
					spectator:addHealth(-math.random(GEYSER_DAMAGE[1], GEYSER_DAMAGE[2]))
				end
				position:sendMagicEffect(CONST_ME_STONES)
			end, 2 * 1000)
		end
		if #room.fireTraps > 0 then
			local position = room.fireTraps[math.random(1, #room.fireTraps)]
			position:sendMagicEffect(CONST_ME_HITBYFIRE) -- visual warning, matches the reference's "active trap state indicates imminent explosion"
			addEvent(function()
				for _, spectator in ipairs(Game.getSpectators(position, false, true, 2, 2, 2, 2)) do
					spectator:addHealth(-math.random(FIRE_TRAP_DAMAGE[1], FIRE_TRAP_DAMAGE[2]))
				end
				position:sendMagicEffect(CONST_ME_FIREAREA)
			end, 3 * 1000)
		end
		addEvent(tick, HAZARD_INTERVAL)
	end
	addEvent(tick, HAZARD_INTERVAL)
end

-- Scarab trash wave: spawn it, then watch for it to be cleared before summoning the boss.

local function watchScarabWave(roomIndex)
	local room = ROOMS[roomIndex]
	if not room.center then
		return
	end
	local spectators = spectatorsInRoom(room)
	if countMonsterByName(spectators, DORMANT_NAME) > 0 or countMonsterByName(spectators, VULNERABLE_NAME) > 0 then
		return -- boss already summoned for this room
	end
	if countMonsterByName(spectators, SCARAB_NAME) > 0 then
		addEvent(watchScarabWave, HAZARD_INTERVAL, roomIndex)
		return
	end
	if room.bossSpawn then
		local boss = Game.createMonster("Ancient Spawn of Morgathla (Dormant)", room.bossSpawn, true, true)
		if boss then
			-- portal detection is a position-based MoveEvent (portalWatch, below), not a
			-- monster-side hook - no registerEvent needed here
			for _, spectator in ipairs(spectatorsInRoom(room)) do
				if spectator:isPlayer() then
					spectator:sendTextMessage(MESSAGE_EVENT_ADVANCE, "The Ancient Spawn of Morgathla rises! Lure it onto a blue portal to weaken it.")
				end
			end
		end
	end
end

local function startRoom(roomIndex)
	local room = ROOMS[roomIndex]
	if not room.center or room.active then
		return
	end
	room.active = true
	for _, position in ipairs(room.scarabSpawns) do
		Game.createMonster("Ancient Scarab", position, true, true)
	end
	addEvent(watchScarabWave, HAZARD_INTERVAL, roomIndex)
	scheduleHazards(roomIndex)
end

-- Scarab reinforcements while the boss is vulnerable - killing them carelessly strengthens the
-- boss, matching this quest's existing Ember Beast (Count of the Core) / Snail Slime retaliation
-- pattern. Started once, from portalWatch below, the moment a room's boss first becomes vulnerable.

local function reinforceScarabs(roomIndex)
	local room = ROOMS[roomIndex]
	if not room.active then
		return
	end
	local spectators = spectatorsInRoom(room)
	local bossPresent = countMonsterByName(spectators, VULNERABLE_NAME) > 0
	if not bossPresent then
		return
	end
	if #room.scarabSpawns > 0 then
		local position = room.scarabSpawns[math.random(1, #room.scarabSpawns)]
		Game.createMonster("Ancient Scarab", position, true, true)
	end
	addEvent(reinforceScarabs, SCARAB_REINFORCE_INTERVAL, roomIndex)
end

-- Blue portals: the Dormant boss stepping on one type-swaps it into the real, vulnerable form,
-- preserving current health exactly like the pre-existing Fiery-Heart/Duke swap trick. The portal
-- itself changes color (transform) and is inactive for PORTAL_COOLDOWN.

local portalsOnCooldown = {} -- position string -> true, cleared by addEvent after PORTAL_COOLDOWN

local portalWatch = MoveEvent()
function portalWatch.onStepIn(creature, item, position, fromPosition)
	local monster = creature:getMonster()
	if not monster or monster:getName():lower() ~= DORMANT_NAME then
		return true
	end
	local key = tostring(position)
	if portalsOnCooldown[key] then
		return true
	end
	portalsOnCooldown[key] = true
	addEvent(function()
		portalsOnCooldown[key] = nil
	end, PORTAL_COOLDOWN)

	local oldHealth = monster:getHealth()
	monster:setType(VULNERABLE_NAME)
	monster:addHealth(-(monster:getHealth() - oldHealth))
	position:sendMagicEffect(CONST_ME_MAGIC_BLUE)
	for _, spectator in ipairs(Game.getSpectators(position, false, true, 15, 15, 15, 15)) do
		spectator:sendTextMessage(MESSAGE_EVENT_ADVANCE, "The portal flares and fades - the spawn is weakened and vulnerable!")
	end

	for index, room in pairs(ROOMS) do
		if room.center and position:isInRange(room.center, 20, 20) then
			addEvent(reinforceScarabs, SCARAB_REINFORCE_INTERVAL, index)
			break
		end
	end
	return true
end
for _, room in pairs(ROOMS) do
	for _, position in ipairs(room.portals) do
		portalWatch:position(position)
	end
end
portalWatch:register()

local scarabStrengthen = CreatureEvent("MorgathlaScarabDeath")
function scarabStrengthen.onDeath(creature, corpse, lasthitkiller, mostdamagekiller)
	local position = creature:getPosition()
	local spectators = Game.getSpectators(position, false, false, 20, 20, 20, 20)
	for _, spectator in ipairs(spectators) do
		if spectator:isMonster() and spectator:getName():lower() == VULNERABLE_NAME then
			spectator:say("The spawn absorbs the scarab's essence and grows stronger!", TALKTYPE_MONSTER_YELL)
			spectator:addHealth(math.random(5000, 15000))
		end
	end
	return true
end
scarabStrengthen:register()

-- Retreat (rooms 1-3): the vulnerable boss's death is intercepted at its per-room health floor -
-- it doesn't actually die, it "retreats" to the next room, exactly matching the reference ("after
-- enough damage the spawn disappears", not "is killed").

local retreatGate = CreatureEvent("MorgathlaRetreatGate")
function retreatGate.onHealthChange(creature, attacker, primaryDamage, primaryType, secondaryDamage, secondaryType, origin)
	local roomIndex
	for index, room in pairs(ROOMS) do
		if not room.final and room.center and creature:getPosition():isInRange(room.center, 20, 20) then
			roomIndex = index
			break
		end
	end
	if not roomIndex then
		return primaryDamage, primaryType, secondaryDamage, secondaryType
	end
	local room = ROOMS[roomIndex]
	local incoming = math.abs(primaryDamage) + math.abs(secondaryDamage)
	if creature:getHealth() - incoming > room.retreatHealthFloor then
		return primaryDamage, primaryType, secondaryDamage, secondaryType
	end

	creature:remove()
	room.active = false
	for _, spectator in ipairs(Game.getSpectators(room.center, false, true, 20, 20, 20, 20)) do
		spectator:sendTextMessage(MESSAGE_EVENT_ADVANCE, room.retreatMessage)
	end
	if room.exitTeleport then
		local teleport = Game.createItem(1949, 1, room.exitTeleport)
		if teleport and room.nextRoomEntry then
			teleport:setDestination(room.nextRoomEntry)
		end
	end
	startRoom(roomIndex + 1)
	return 0, primaryType, 0, secondaryType
end
retreatGate:register()

-- Final room (4): real death. Achievement, one-time reward-chest access flag.

local morgathlaDeath = CreatureEvent("MorgathlaDeath")
function morgathlaDeath.onDeath(creature, corpse, lasthitkiller, mostdamagekiller)
	local room = ROOMS[4]
	if not room.center or not creature:getPosition():isInRange(room.center, 20, 20) then
		return true -- not the final room's real kill (rooms 1-3 never reach onDeath, see retreatGate)
	end
	room.active = false
	onDeathForDamagingPlayers(creature, function(_creature, player)
		if not player:hasAchievement("Scourge of Scarabs") then
			player:addAchievement("Scourge of Scarabs")
		end
		player:setStorageValue(Storage.Quest.U11_50.DangerousDepths.Morgathla.Defeated, 1)
		-- Advances the tracked questlog storage (Morgathla.MalletGiven) past its endValue=2 so the
		-- catalog mission (039_dangerous_depths.lua, missionId 10523) actually completes instead of
		-- staying stuck on its state[1] "strike the gong" text forever - see quests.lua's
		-- getMissionDescription/missionIsCompleted, which both key off this same storage.
		if player:getStorageValue(Storage.Quest.U11_50.DangerousDepths.Morgathla.MalletGiven) < 2 then
			player:setStorageValue(Storage.Quest.U11_50.DangerousDepths.Morgathla.MalletGiven, 2)
		end
	end)
	return true
end
morgathlaDeath:register()

local rewardChest = Action()
function rewardChest.onUse(player, item, fromPosition, target, toPosition, isHotkey)
	if player:getStorageValue(Storage.Quest.U11_50.DangerousDepths.Morgathla.Defeated) < 1 then
		player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "You haven't earned this reward yet.")
		return true
	end
	if player:getStorageValue(Storage.Quest.U11_50.DangerousDepths.Morgathla.RewardClaimed) >= 1 then
		player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "You already claimed this reward.")
		return true
	end
	-- CUSTOM_GLOBAL_LIKE_PENDING_EXACT_REFERENCE: the reference shows "5x" of 4 reward icons that
	-- couldn't be read from the source images. Mapped onto the 5-piece "gnome" equipment set
	-- (helmet/armor/legs/shield/sword, items 27647-27651) - unreferenced anywhere else in the
	-- repo, level-200-gated, vocation-split gear that fits this exact quest's theme and reward
	-- tier. Granted as 1 of each (not 5 copies each) since these are non-stackable equipment, not
	-- consumables - a disclosed judgment call on the PDF's "5x" wording, not a confirmed 1:1 match.
	for _, itemId in ipairs({ 27647, 27648, 27649, 27650, 27651 }) do
		player:addItem(itemId, 1)
	end
	player:setStorageValue(Storage.Quest.U11_50.DangerousDepths.Morgathla.RewardClaimed, 1)
	player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "You claim the treasures left behind by the Ancient Spawn of Morgathla!")
	return true
end
rewardChest:aid(57420)
rewardChest:register()

-- Room 1 entrance (stepped into after the gong teleport) starts the whole encounter.

local roomOneEntrance = MoveEvent()
function roomOneEntrance.onStepIn(creature, item, position, fromPosition)
	local player = creature:getPlayer()
	if not player then
		return true
	end
	startRoom(1)
	return true
end
roomOneEntrance:aid(57410)
roomOneEntrance:register()
