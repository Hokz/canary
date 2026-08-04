-- Rascacoon Trust Points / Supply Mission - protect the cheese cellar from disguised pirat rats
-- for 6 minutes, delivering as much cheese as possible to the central larder. 200 trust points on
-- completion, 20h cooldown. Score is tracked per-player (5-25 range, shown under the nickname via
-- setIcon) rather than a single shared team score, since the reference shows it under each
-- character's own name individually.
--
-- ACCEPTABLE_GLOBAL_LIKE simplifications, disclosed:
-- - Cheese delivery is "use cheese item on the larder" rather than push-physics landing a pushed
--   item exactly on the trapdoor tile - this codebase has no established item-push-into-hole
--   detection hook to build that on safely. The cooperative "push toward whoever stands at the
--   larder" tactic the reference describes still works exactly the same way under this design.
-- - A rat "eating" a cheese (if not revealed with the staff in time) deducts points from every
--   player currently in the room rather than attributing loss to a specific player, since there
--   is no reliable way to attribute "whose cheese" once several players are pushing cooperatively.
--
-- MAP SETUP REQUIRED: ROOM below needs real positions before any of this spawns anything - see
-- the Map Setup Contract in the PR body.
local ROOM = {
	entry = nil, -- teleport destination inside the cellar
	exit = nil, -- where players are ejected on completion/failure/timeout
	larderAid = 45921, -- the trapdoor/larder players use cheese on
	chestAid = 45922, -- the chest holding the shaman's staff
	cheeseSpawns = {}, -- list of Position: where cheese periodically appears
	ratSpawns = {}, -- list of Position: where disguised rats periodically appear
	zoneFrom = nil, -- room bounding box, used to find players currently inside
	zoneTo = nil,
}

local ENTRY_AID = 45920
local CHEESE_ID = 3607 -- "cheese" - existing generic food item, matches Om'Wake Naha's own wording
local MISSION_DURATION = 6 * 60 * 1000 -- 6 minutes
local COOLDOWN = 20 * 3600 -- 20 hours
local STAFF_DURATION = 60 * 1000 -- 1 minute per pickup, matches the reference's "disappears after some time"
local RAT_INTERVAL = 20 * 1000 -- a new disguised rat appears roughly every 20 seconds
local RAT_EAT_DELAY = 25 * 1000 -- an unrevealed rat "eats" a cheese after this long
local CHEESE_RESPAWN_DELAY = 15 * 1000
local START_SCORE = 15
local MAX_SCORE = 25
local TRUST_REWARD = 200

local APiratesTail = Storage.Quest.U12_60.APiratesTail

local function roomPlayers()
	if not ROOM.zoneFrom or not ROOM.zoneTo then
		return {}
	end
	local players = {}
	for _, spectator in ipairs(Game.getSpectators(ROOM.zoneFrom, false, true)) do
		if spectator:isPlayer() and spectator:getPosition():isInRange(ROOM.zoneFrom, ROOM.zoneTo) then
			table.insert(players, spectator)
		end
	end
	return players
end

local function setScore(player, score)
	score = math.max(0, math.min(MAX_SCORE, score))
	player:setStorageValue(APiratesTail.Mission03.SupplyMissionScore, score)
	player:setIcon("supply-mission", CreatureIconCategory_Quests, CreatureIconQuests_GreenBall, score)
	return score
end

local function endAttempt(player, success)
	player:removeIcon("supply-mission")
	if ROOM.exit then
		player:teleportTo(ROOM.exit)
	end
	if success then
		local trust = math.max(player:getStorageValue(APiratesTail.Mission03.TrustPoints), 0)
		player:setStorageValue(APiratesTail.Mission03.TrustPoints, trust + TRUST_REWARD)
		player:setStorageValue(APiratesTail.Mission03.SupplyMissionCooldown, os.time() + COOLDOWN)
		player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "You held out the full six minutes! The Rascoohan people thank you for protecting their cheese.")
	else
		player:setStorageValue(APiratesTail.Mission03.SupplyMissionCooldown, os.time() + COOLDOWN)
		player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "The rats overwhelmed the cheese cellar. You are thrown out.")
	end
end

local function spawnRat()
	if #ROOM.ratSpawns == 0 then
		return
	end
	local position = ROOM.ratSpawns[math.random(1, #ROOM.ratSpawns)]
	local rat = Game.createMonster("Disguised Rat", position, true, true)
	if not rat then
		return
	end
	local ratId = rat:getId()
	addEvent(function()
		local stillDisguised = Creature(ratId)
		if not stillDisguised then
			return -- already revealed by the staff, see creaturescripts_supply_mission_reveal.lua
		end
		-- still disguised after the grace period - it "eats" a cheese
		stillDisguised:remove()
		if #ROOM.cheeseSpawns > 0 then
			local spot = ROOM.cheeseSpawns[math.random(1, #ROOM.cheeseSpawns)]
			local tile = Tile(spot)
			local cheese = tile and tile:getItemById(CHEESE_ID)
			if cheese then
				cheese:remove()
				for _, player in ipairs(roomPlayers()) do
					setScore(player, math.max(player:getStorageValue(APiratesTail.Mission03.SupplyMissionScore) - 3, 0))
					player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "A disguised rat devoured a cheese!")
					if player:getStorageValue(APiratesTail.Mission03.SupplyMissionScore) <= 0 then
						endAttempt(player, false)
					end
				end
				addEvent(function()
					Game.createItem(CHEESE_ID, 1, spot)
				end, CHEESE_RESPAWN_DELAY)
			end
		end
	end, RAT_EAT_DELAY)
end

local supplyEntry = Action()
function supplyEntry.onUse(player, item, fromPosition, target, toPosition, isHotkey)
	if not ROOM.entry then
		player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "This entrance leads nowhere yet.")
		return true
	end
	local cooldown = player:getStorageValue(APiratesTail.Mission03.SupplyMissionCooldown)
	if cooldown > os.time() then
		player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "You need to wait before attempting the Supply Mission again.")
		return true
	end
	player:teleportTo(ROOM.entry)
	setScore(player, START_SCORE)

	addEvent(function()
		if player:getStorageValue(APiratesTail.Mission03.SupplyMissionScore) > 0 then
			endAttempt(player, true)
		end
	end, MISSION_DURATION)

	local ratSpawner
	local elapsed = 0
	local function tickRats()
		if player:getStorageValue(APiratesTail.Mission03.SupplyMissionScore) <= 0 then
			return -- attempt already ended
		end
		elapsed = elapsed + RAT_INTERVAL
		if elapsed >= MISSION_DURATION then
			return
		end
		spawnRat()
		addEvent(tickRats, RAT_INTERVAL)
	end
	addEvent(tickRats, RAT_INTERVAL)
	return true
end
supplyEntry:aid(ENTRY_AID)
supplyEntry:register()

local staffChest = Action()
function staffChest.onUse(player, item, fromPosition, target, toPosition, isHotkey)
	player:setStorageValue(APiratesTail.Mission03.SupplyStaffExpiry, os.time() + STAFF_DURATION / 1000)
	player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "You take the shaman's staff. It will only work for a short while.")
	return true
end
staffChest:aid(ROOM.chestAid)
staffChest:register()

local deliverCheese = Action()
function deliverCheese.onUse(player, item, fromPosition, target, toPosition, isHotkey)
	if not target or target:getActionId() ~= ROOM.larderAid then
		return false
	end
	item:remove(1)
	local score = setScore(player, player:getStorageValue(APiratesTail.Mission03.SupplyMissionScore) + 2)
	player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "You push the cheese into the larder.")
	toPosition:sendMagicEffect(CONST_ME_POFF)
	return true
end
deliverCheese:id(CHEESE_ID)
deliverCheese:register()
