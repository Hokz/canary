local armorId = 31482
local armorPos = Position(33398, 32640, 6)
local metalWallId = 31449

local function createArmor(id, amount, pos)
	local armor = Game.createItem(id, amount, pos)
	if armor then
		armor:setActionId(40003)
	end
end

-- ================================================================
-- SCARLETT RUN OWNERSHIP (executor contract, sections 31/34)
-- ================================================================
ScarlettRun = {
	token = 0,
	active = false,
	participants = {}, -- set: playerId -> true
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

function ScarlettRunIsParticipant(token, playerId)
	return ScarlettRunIsCurrent(token) and ScarlettRun.participants[playerId] == true
end

function ScarlettRunTerminate(token, kind, reason)
	if not ScarlettRunIsCurrent(token) then
		return
	end
	logger.info("GraveDanger/Scarlett: run {} terminated ({}) - {}", token, kind, reason or "")
	ScarlettRun.active = false
	ScarlettRun.participants = {}
end

-- Snapshot of the most recent onUseExtra call's infoPositions, consumed synchronously by
-- createFunction below in the same synchronous BossLever:onUse() call.
local lastInfoPositions = nil

-- CORRECTION (executor contract, section 31): every room occupant is now independently verified
-- (level/Premium/Gaffir/Custodian/Quaid), not just whichever single player had earlier interacted
-- with the pillar item at aid 40003. Chess/Roaring Lion completion is deliberately NOT checked here:
-- confirmed absent from the repository (no chess puzzle implementation exists anywhere - see the PR's
-- Manual RME Manifest) - gating on a storage nothing can ever set would permanently brick this boss,
-- which is worse than the pre-existing gap. This is a known, documented limitation, not a silent bypass.
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
	return true
end

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
	ScarlettRun.active = true
	ScarlettRun.participants = {}
	if lastInfoPositions then
		for _, posInfo in pairs(lastInfoPositions) do
			local player = posInfo.creature
			if player and player:isPlayer() then
				ScarlettRun.participants[player:getId()] = true
			end
		end
	end

	SCARLETT_MAY_TRANSFORM = 0
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
	exit = Position(33395, 32665, 6),
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

local mirror = {
	fromPos = Position(33389, 32641, 6),
	toPos = Position(33403, 32655, 6),
	mirrors = { 31474, 31475, 31476, 31477 },
}

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

local graveScarlettAid = Action()

function graveScarlettAid.onUse(player, item, fromPosition, target, toPosition, isHotkey)
	-- CONFIRMED BUG (pre-existing): this used `and` between three "not killed" tests, so it only
	-- blocked a player who had killed NONE of the three minibosses - killing any single one granted
	-- full access to the Scarlett encounter. The source requires all three (Gaffir, Custodian, Guard
	-- Captain Quaid). Also switched `~= 1` to `< 1` so any future value >1 still counts as done.
	if player:getStorageValue(Storage.Quest.U12_20.GraveDanger.GaffirKilled) < 1 or player:getStorageValue(Storage.Quest.U12_20.GraveDanger.CustodianKilled) < 1 or player:getStorageValue(Storage.Quest.U12_20.GraveDanger.QuaidKilled) < 1 then
		player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "You are not allowed to use this yet.")
		return true
	end

	if table.contains(transformTo, item.itemid) then
		local pilar = transformTo[item.itemid]
		if pilar then
			item:transform(pilar)
			item:getPosition():sendMagicEffect(CONST_ME_POFF)
		end
	elseif item.itemid == armorId then
		item:getPosition():sendMagicEffect(CONST_ME_THUNDER)
		item:remove(1)
		player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "You hold the old chestplate of Galthein in front of you. It does not fit and far too old to withstand any attack.")
		addEvent(createArmor, 20 * 1000, armorId, 1, armorPos)
		addEvent(backMirror, 10 * 1000)
		SCARLETT_MAY_TRANSFORM = 1
		addEvent(function()
			SCARLETT_MAY_TRANSFORM = 0
		end, 2000)
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
