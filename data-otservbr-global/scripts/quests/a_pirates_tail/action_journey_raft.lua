-- Rascacoon Trust Points / The Journey - protect the raft and its Raccoon Supplies for 10-12
-- minutes while Captain Coohan calls out waves of attacks. Only available after Hidden Treasure's
-- Queso mission (Mission06[1] >= 7). 200 trust points always; carrying the key dropped by
-- Tentugly's Head (item 35508, "cheesy key") additionally grants a vocation-specific reward
-- through the pink portal.
--
-- Raft health and supply crates are tracked as ONE SHARED attempt (not per-player) since up to 5
-- players ride the same raft together - this codebase has no generic multi-party room-instance
-- primitive to build a cleaner shared-but-isolated state on, so only one Journey attempt can be
-- in progress server-wide at a time. Documented simplification, not a silent gap.
--
-- MAP SETUP REQUIRED: JOURNEY_ROOM below needs real positions - see the Map Setup Contract.
local JOURNEY_ROOM = {
	entryAid = 45950,
	raftPosition = nil, -- Position: where the raft group appears
	zoneFrom = nil, -- raft bounding box, used to find players currently aboard
	zoneTo = nil,
	windCatcherTile = nil, -- Position: the gray tile near the mast that lures Gusts of Wind
	cannonAid = 45951, -- fires at incoming hazard trash
	trashSpawn = nil, -- Position: where hazard trash appears before drifting toward the raft
	islandExit = nil, -- Position: where players land after 10-12 minutes
	northExit = nil, -- Position: the always-available exit without the key
	pinkPortal = nil, -- Position: the key-gated reward portal
}

local CRATE_ID = 116 -- "crate" - existing generic item, reused as the Raccoon Supplies container
local TENTUGLY_KEY_ID = 35508 -- "cheesy key"
local RAFT_DURATION = 11 * 60 * 1000 -- 10-12 minutes, midpoint
local COOLDOWN = 20 * 3600
local TRUST_REWARD = 200
local COMMAND_INTERVAL = 50 * 1000
local MAX_HEALTH = 100

-- CUSTOM_GLOBAL_LIKE_QUESTLOG_PENDING_EXACT_REFERENCE: exact vocation reward pairs are not fully
-- recoverable (source images not extractable) - only 1 of the "2 items per vocation" the
-- reference describes could be confidently identified (the vocation figurine, matching the
-- overall quest's own "statuette" reward description) via unreferenced, unallocated items.xml
-- entries; the second item per vocation and the entire Monk reward (no monk figurine exists
-- anywhere in items.xml) are classified OWNER_DECISION_CLIENT_ASSET_REQUIRED.
local VOCATION_REWARDS = {
	knight = { 35589 }, -- snowbash figurine
	paladin = { 35590 }, -- sandscourge figurine
	sorcerer = { 35592 }, -- bladespark figurine
	druid = { 35591 }, -- mossmasher figurine
	monk = {}, -- OWNER_DECISION_CLIENT_ASSET_REQUIRED - no monk figurine exists in items.xml
}

local APiratesTail = Storage.Quest.U12_60.APiratesTail

local function raftPlayers()
	if not JOURNEY_ROOM.zoneFrom or not JOURNEY_ROOM.zoneTo then
		return {}
	end
	local players = {}
	for _, spectator in ipairs(Game.getSpectators(JOURNEY_ROOM.zoneFrom, false, true)) do
		if spectator:isPlayer() and spectator:getPosition():isInRange(JOURNEY_ROOM.zoneFrom, JOURNEY_ROOM.zoneTo) then
			table.insert(players, spectator)
		end
	end
	return players
end

local function broadcastToRaft(message)
	for _, player in ipairs(raftPlayers()) do
		player:sendTextMessage(MESSAGE_EVENT_ADVANCE, message)
		player:setIcon("journey-raft", CreatureIconCategory_Quests, CreatureIconQuests_GreenShield, math.max(APiratesTailJourneyRaft.health, 0))
	end
end

local function healRaft(amount)
	APiratesTailJourneyRaft.health = math.min(APiratesTailJourneyRaft.health + amount, MAX_HEALTH)
	for _, player in ipairs(raftPlayers()) do
		player:setIcon("journey-raft", CreatureIconCategory_Quests, CreatureIconQuests_GreenShield, APiratesTailJourneyRaft.health)
	end
end

local function windAttack()
	broadcastToRaft("Captain Coohan: WIND AHOY! CATCH THE BUGGERS WITH THE WIND CATCHER!")
	if not JOURNEY_ROOM.raftPosition then
		return
	end
	for _ = 1, 3 do
		Game.createMonster("Gust of Wind", JOURNEY_ROOM.raftPosition, true, true)
	end
end

local function hazardAttack()
	broadcastToRaft("Captain Coohan: HAZARD AHEAD! MAN THE COOHAN CANNONS! BLAST IT TO PIECES!")
	if not JOURNEY_ROOM.trashSpawn then
		return
	end
	local trash = Game.createItem(CRATE_ID, 1, JOURNEY_ROOM.trashSpawn)
	addEvent(function()
		if trash and not trash:isRemoved() then
			trash:remove()
			damageAPiratesTailRaft(5)
			broadcastToRaft("The hazard slams into the raft!")
		end
	end, 15 * 1000)
end

local function serpentAttack()
	broadcastToRaft("Captain Coohan: SEA SEERPENT STARBOARD! AHOY! BRACE YOURSELF!")
	addEvent(function()
		for _, player in ipairs(raftPlayers()) do
			player:addHealth(-math.random(400, 600))
		end
	end, 4 * 1000)
end

local function elementalAttack()
	broadcastToRaft("Captain Coohan: WATER ELEMENTALS! GET RID OF THEM")
	if not JOURNEY_ROOM.raftPosition then
		return
	end
	for _ = 1, 2 do
		Game.createMonster("Water Elemental", JOURNEY_ROOM.raftPosition, true, true)
	end
end

local function quarraAttack()
	broadcastToRaft("Captain Coohan: QUARAS AHOY! PROTECT ME SUPPLIES!")
	if not JOURNEY_ROOM.raftPosition then
		return
	end
	for _ = 1, 2 do
		Game.createMonster("Quarra Saboteur", JOURNEY_ROOM.raftPosition, true, true)
	end
end

local ATTACKS = { windAttack, hazardAttack, serpentAttack, elementalAttack, quarraAttack }

local function commandLoop(elapsed)
	if not APiratesTailJourneyRaft.active then
		return
	end
	if elapsed >= RAFT_DURATION then
		APiratesTailJourneyRaft.active = false
		local success = APiratesTailJourneyRaft.health > 0
		for _, player in ipairs(raftPlayers()) do
			player:removeIcon("journey-raft")
			if success then
				local trust = math.max(player:getStorageValue(APiratesTail.Mission03.TrustPoints), 0)
				player:setStorageValue(APiratesTail.Mission03.TrustPoints, trust + TRUST_REWARD)
				if player:getItemCount(TENTUGLY_KEY_ID) >= 1 and JOURNEY_ROOM.pinkPortal then
					player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "The raft made it! Carrying Tentugly's key, you may pass through the pink portal for a special reward.")
				elseif JOURNEY_ROOM.islandExit then
					player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "The raft made it safely to the small island.")
				end
				if JOURNEY_ROOM.islandExit then
					player:teleportTo(JOURNEY_ROOM.islandExit)
				end
			else
				player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "The raft was lost to the sea! You are washed ashore empty-handed.")
				if JOURNEY_ROOM.northExit then
					player:teleportTo(JOURNEY_ROOM.northExit)
				end
			end
		end
		return
	end
	ATTACKS[math.random(1, #ATTACKS)]()
	addEvent(commandLoop, COMMAND_INTERVAL, elapsed + COMMAND_INTERVAL)
end

local journeyEntry = Action()
function journeyEntry.onUse(player, item, fromPosition, target, toPosition, isHotkey)
	if player:getStorageValue(APiratesTail.Mission06[1]) < 7 then
		player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "This teleporter needs Hidden Treasure's Queso mission completed first.")
		return true
	end
	if player:getStorageValue(APiratesTail.Mission03.JourneyCooldown) > os.time() then
		player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "You need to wait before attempting The Journey again.")
		return true
	end
	if not JOURNEY_ROOM.raftPosition then
		player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "The raft isn't ready to sail yet.")
		return true
	end
	player:setStorageValue(APiratesTail.Mission03.JourneyCooldown, os.time() + COOLDOWN)
	player:teleportTo(JOURNEY_ROOM.raftPosition)

	if not APiratesTailJourneyRaft.active then
		APiratesTailJourneyRaft.active = true
		APiratesTailJourneyRaft.health = MAX_HEALTH
		addEvent(commandLoop, COMMAND_INTERVAL, COMMAND_INTERVAL)
	end
	player:setIcon("journey-raft", CreatureIconCategory_Quests, CreatureIconQuests_GreenShield, APiratesTailJourneyRaft.health)
	return true
end
journeyEntry:aid(JOURNEY_ROOM.entryAid)
journeyEntry:register()

local windCatcher = MoveEvent()
function windCatcher.onStepIn(creature, item, position, fromPosition)
	local monster = creature:getMonster()
	if monster and monster:getName():lower() == "gust of wind" then
		monster:remove()
		healRaft(3)
		broadcastToRaft("The wind catcher reels in a gust of wind!")
	end
	return true
end
if JOURNEY_ROOM.windCatcherTile then
	windCatcher:position(JOURNEY_ROOM.windCatcherTile)
end
windCatcher:register()

local cannon = Action()
function cannon.onUse(player, item, fromPosition, target, toPosition, isHotkey)
	if not JOURNEY_ROOM.trashSpawn then
		return true
	end
	local trashTile = Tile(JOURNEY_ROOM.trashSpawn)
	local trash = trashTile and trashTile:getItemById(CRATE_ID)
	if trash then
		trash:remove()
		player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "You blast the hazard to pieces!")
		JOURNEY_ROOM.trashSpawn:sendMagicEffect(CONST_ME_EXPLOSIONHIT)
	end
	return true
end
cannon:aid(JOURNEY_ROOM.cannonAid)
cannon:register()

local pinkPortal = MoveEvent()
function pinkPortal.onStepIn(creature, item, position, fromPosition)
	local player = creature:getPlayer()
	if not player then
		return true
	end
	if player:getItemCount(TENTUGLY_KEY_ID) < 1 then
		player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "You need Tentugly's key to pass through here.")
		if JOURNEY_ROOM.islandExit then
			player:teleportTo(JOURNEY_ROOM.islandExit)
		end
		return true
	end
	if player:getStorageValue(APiratesTail.Mission06[1]) ~= 7 then
		player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "You already claimed the hidden treasure.")
		return true
	end
	local vocation = player:getVocation():getBase():getName():lower()
	local reward = VOCATION_REWARDS[vocation]
	if reward and #reward > 0 then
		for _, itemId in ipairs(reward) do
			player:addItem(itemId, 1)
		end
	end
	player:setStorageValue(APiratesTail.Mission06[1], 8)
	player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "You claim the hidden treasure!")
	return true
end
if JOURNEY_ROOM.pinkPortal then
	pinkPortal:position(JOURNEY_ROOM.pinkPortal)
end
pinkPortal:register()
