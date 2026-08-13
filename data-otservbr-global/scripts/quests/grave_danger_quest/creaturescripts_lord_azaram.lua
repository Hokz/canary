local config = {
	centerRoom = Position(33424, 31472, 13),
	newPosition = Position(33424, 31478, 13),
	exitPos = Position(32190, 31819, 8),
	x = 10,
	y = 10,
	timer = Storage.Quest.U12_20.GraveDanger.Bosses.LordAzaram.Timer,
	room = Storage.Quest.U12_20.GraveDanger.Bosses.LordAzaram.Room,
	soulPos = Position(33426, 31471, 13),
	bossPos = Position(33423, 31471, 13),
	tainted = {
		Position(33422, 31470, 13),
		Position(33427, 31470, 13),
		Position(33422, 31476, 13),
		Position(33427, 31476, 13),
	},
	fromPos = Position(33414, 31463, 13),
	toPos = Position(33433, 31481, 13),
}

-- CORRECTION (section F): scoped to entities the CURRENT run actually owns - a generation-blind
-- name-based sweep could otherwise remove a stale/unrelated Tainted Soul Splinter (or, worse, one
-- belonging to a different concurrent room state) rather than only this run's own.
local function removeTainted()
	local spectators = Game.getSpectators(config.centerRoom, false, false, config.x, config.x, config.y, config.y)
	for _, creature in pairs(spectators) do
		if creature:isMonster() and creature:getName():lower() == "tainted soul splinter" and AzaramRunOwnsMonster(creature) then
			creature:remove()
		end
	end
	return true
end

-- CORRECTION (executor contract, section 9): the four Tainted Soul Splinters are a mandatory phase
-- entity - verified with bounded retry, and a technical abort (rather than silently continuing with
-- a partially-created phase) if recovery is exhausted.
local function attemptTaintedSplinters(token, retriesLeft)
	retriesLeft = retriesLeft or 3
	if not AzaramRunIsCurrent(token) then
		return
	end

	local spawned = {}
	local allOk = true
	for _, pos in pairs(config.tainted) do
		local splinter = Game.createMonster("Tainted Soul Splinter", pos, true, true)
		if splinter then
			table.insert(spawned, splinter)
		else
			allOk = false
		end
	end

	if allOk then
		for _, splinter in pairs(spawned) do
			AzaramRunTrackMonster(splinter)
		end
		return
	end

	for _, splinter in pairs(spawned) do
		splinter:remove()
	end
	logger.error("GraveDanger/LordAzaram: Tainted Soul Splinters failed to fully spawn (retries left: {})", retriesLeft)
	if retriesLeft > 0 then
		addEvent(attemptTaintedSplinters, 1000, token, retriesLeft - 1)
	else
		AzaramRunTerminate(token, "technical_abort", "Tainted Soul Splinters failed to spawn after bounded retries")
	end
end

local azaram_health = CreatureEvent("azaram_health")

function azaram_health.onHealthChange(creature, attacker, primaryDamage, primaryType, secondaryDamage, secondaryType)
	if not creature or not AzaramRunOwnsMonster(creature) then
		return primaryDamage, primaryType, secondaryDamage, secondaryType
	end
	local token = AzaramRunCurrentToken()

	local players = Game.getSpectators(config.centerRoom, false, true, config.x, config.x, config.y, config.y)
	for _, player in pairs(players) do
		if player:isPlayer() then
			if player:getStorageValue(config.timer) < os.time() then
				player:setStorageValue(config.timer, os.time() + 20 * 3600)
				-- CORRECTION (section O): remembers that THIS attempt wrote the legacy Timer lockout
				-- for this player, so a later technical_abort knows it is safe to roll back.
				AzaramRunMarkTimerWritten(token, player:getId())
			end
			if player:getStorageValue(config.room) < os.time() then
				player:setStorageValue(config.room, os.time() + 30 * 60)
			end
		end
	end

	local health = creature:getMaxHealth() * 0.10
	local damageStorage = creature:getStorageValue(1)
	if damageStorage == -1 then
		creature:setStorageValue(1, 0)
	end

	creature:setStorageValue(1, damageStorage + primaryDamage)
	local stor = creature:getStorageValue(1)
	if stor >= health then
		local bossTile = Tile(config.bossPos)
		if bossTile and bossTile:isWalkable() then
			creature:teleportTo(config.bossPos)
		end
		creature:setStorageValue(1, 0)
		-- CORRECTION (section F): resolved through the current run's own owned Soul id, never a bare
		-- name lookup - a stale Soul instance from a finished attempt could otherwise be found here.
		local soul = Creature(AzaramRun.soulId)
		if soul and AzaramRunOwnsSoul(soul) then
			soul:teleportTo(config.centerRoom)
			attemptTaintedSplinters(token, 3)
		end
	end
	return primaryDamage, primaryType, -secondaryDamage, secondaryType
end

azaram_health:register()

local azaram_summon = CreatureEvent("azaram_summon")

function azaram_summon.onHealthChange(creature, attacker, primaryDamage, primaryType, secondaryDamage, secondaryType)
	if not creature or not AzaramRunOwnsMonster(creature) then
		return primaryDamage, primaryType, secondaryDamage, secondaryType
	end
	local chance = math.random(1, 100)
	if chance < 90 then
		return primaryDamage, primaryType, secondaryDamage, secondaryType
	end

	local position = Position(math.random(config.fromPos.x, config.toPos.x), math.random(config.fromPos.y, config.toPos.y), config.fromPos.z)
	local tile = Tile(position)
	if tile and tile:isWalkable() then
		local spawnPos = position
		local topThing = tile:getTopCreature()
		if topThing then
			spawnPos = topThing:getClosestFreePosition(topThing:getPosition(), true) or position
		end
		-- Condensed Sin is a recurring flavour add (not a mandatory phase gate like the Tainted Soul
		-- Splinters above) - a light bounded retry is enough; a miss here does not abort the fight.
		for attempt = 1, 2 do
			local sin = Game.createMonster("Condensed Sin", spawnPos, false, true)
			if sin then
				AzaramRunTrackMonster(sin)
				break
			end
			logger.error("GraveDanger/LordAzaram: failed to create Condensed Sin (attempt {}/2)", attempt)
		end
	end
	return primaryDamage, primaryType, -secondaryDamage, secondaryType
end

azaram_summon:register()

local soul_heal = CreatureEvent("soul_heal")

function soul_heal.onHealthChange(creature, attacker, primaryDamage, primaryType, secondaryDamage, secondaryType)
	-- CORRECTION (section F): the Soul itself must belong to the current run - a stale Soul left over
	-- from an already-terminated attempt can no longer progress that attempt's phase.
	if not creature or not AzaramRunOwnsSoul(creature) then
		return primaryDamage, primaryType, secondaryDamage, secondaryType
	end
	if not attacker or not attacker:isPlayer() then
		return primaryDamage, primaryType, secondaryDamage, secondaryType
	end
	if primaryType == COMBAT_HEALING then
		local health = (creature:getHealth() / creature:getMaxHealth()) * 100
		local healStorage = creature:getStorageValue(2)
		if healStorage == -1 then
			creature:setStorageValue(2, 0)
		end

		if health < 100 and health >= healStorage * 15 then
			creature:setStorageValue(2, healStorage + 1)
			if config.soulPos:isWalkable() then
				creature:teleportTo(config.soulPos)
			end
			removeTainted()
			-- CORRECTION (executor contract, section 9): ownership-checked - never teleports a stale/
			-- unrelated "Lord Azaram" instance.
			local boss = Creature(AzaramRun.bossId)
			if boss and AzaramRunOwnsBoss(boss) and config.centerRoom:isWalkable() then
				boss:teleportTo(config.centerRoom)
			end
		end
	end
	return primaryDamage, primaryType, -secondaryDamage, secondaryType
end

soul_heal:register()

-- ================================================================
-- LORD AZARAM SUCCESS (correction pass section F)
-- ================================================================
-- Releases AzaramRun's own bookkeeping on a legitimate kill. Lord Azaram's own grave/boss credit is
-- unaffected - handled separately by the pre-existing generic creaturescripts_boss_kill.lua path
-- (lord azaram -> Graves.Ghostlands).
local azaram_success = CreatureEvent("azaram_success")

function azaram_success.onDeath(creature)
	local targetMonster = creature:getMonster()
	if not targetMonster or targetMonster:getMaster() then
		return true
	end
	if not AzaramRunOwnsBoss(creature) then
		return true
	end
	AzaramRunTerminate(AzaramRunCurrentToken(), "success", "Lord Azaram defeated")
	return true
end

azaram_success:register()
