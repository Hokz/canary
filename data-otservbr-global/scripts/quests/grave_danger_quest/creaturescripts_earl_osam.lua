local config = {
	centerRoom = Position(33488, 31438, 13),
	newPosition = Position(33489, 31441, 13),
	exitPos = Position(33261, 31985, 8),
	x = 10,
	y = 10,
	timer = Storage.Quest.U12_20.GraveDanger.Bosses.EarlOsam.Timer,
	room = Storage.Quest.U12_20.GraveDanger.Bosses.EarlOsam.Room,
	fromPos = Position(33479, 31429, 13),
	toPos = Position(33497, 31447, 13),
	spheres = {
		Position(33480, 31438, 13),
		Position(33488, 31430, 13),
		Position(33496, 31438, 13),
		Position(33488, 31446, 13),
	},
}

-- CORRECTION (executor contract, section 10; correction pass section G): "Sphere movement callbacks
-- must be attempt-owned." Earl Osam's own storage(4) is a monotonic "generation" counter, bumped once
-- per initMech() call. Each Magical Sphere is tagged with the generation that spawned it (storage(1)).
-- moveSphere's recurring addEvent chain and sphere_death's count-decrement both verify BOTH the
-- current run token AND their generation still matches the boss's CURRENT one before acting - a late
-- callback from a superseded phase, OR from an already-terminated run, can no longer move/heal-check
-- for, or decrement the count of, a newer phase's or a newer run's spheres.
local function moveSphere(token, generation)
	if not EarlOsamRunIsCurrent(token) then
		return true
	end
	local boss = Creature(EarlOsamRun.bossId)
	if not boss or not EarlOsamRunOwnsBoss(boss) or boss:getStorageValue(4) ~= generation or boss:getStorageValue(3) <= 0 then
		return true
	end

	local spectators = Game.getSpectators(config.centerRoom, false, false, config.x, config.x, config.y, config.y)
	local nextPos = nil

	for _, spheres in pairs(spectators) do
		if spheres:isMonster() and spheres:getName():lower() == "magical sphere" then
			local pos = spheres:getPosition()

			if pos.y == 31438 then
				if pos.x > 33488 then
					nextPos = Position(pos.x - 1, pos.y, pos.z)
				elseif pos.x < 33488 then
					nextPos = Position(pos.x + 1, pos.y, pos.z)
				end
			elseif pos.x == 33488 then
				if pos.y > 31438 then
					nextPos = Position(pos.x, pos.y - 1, pos.z)
				elseif pos.y < 31438 then
					nextPos = Position(pos.x, pos.y + 1, pos.z)
				end
			end

			if nextPos then
				local nextTile = Tile(nextPos)
				if nextTile then
					local nextCreature = nextTile:getTopCreature()
					if nextCreature then
						if nextPos == config.centerRoom and nextCreature:getName():lower() == "earl osam" and EarlOsamRunOwnsBoss(nextCreature) then
							spheres:remove()
							nextCreature:addHealth(80000)
							-- CORRECTION: never allow this obligation counter to go negative (matches
							-- the same clamp applied to Count Vlarkorth's shield counter).
							nextCreature:setStorageValue(3, math.max(0, nextCreature:getStorageValue(3) - 1))
							if nextCreature:isMoveLocked() then
								nextCreature:setMoveLocked(false)
							end
						else
							spheres:remove()
						end
					else
						spheres:teleportTo(nextPos)
					end
				end
			end
		end
	end

	if boss:getHealth() > 0 and boss:getStorageValue(4) == generation then
		EarlOsamRunTrackEvent(token, addEvent(moveSphere, 4 * 1000, token, generation))
	end

	return true
end

-- CORRECTION (executor contract, section 10; correction pass section G): the four Magical Spheres are
-- one mandatory phase generation - verified with bounded retry, never silently accepting a partial
-- 1/2/3. Recovery exhaustion previously released the boss's move-lock and let the fight continue with
-- the mandatory mechanic simply skipped (fail-open); it now technical-aborts the whole encounter
-- instead, matching the Lord Azaram Tainted Soul Splinters / King Zelos wing-entity precedent - a
-- mandatory phase entity that cannot be verified must end the attempt, not quietly make it easier.
local function attemptSpheres(token, generation, retriesLeft)
	retriesLeft = retriesLeft or 3
	if not EarlOsamRunIsCurrent(token) then
		return
	end
	local boss = Creature(EarlOsamRun.bossId)
	if not boss or not EarlOsamRunOwnsBoss(boss) or boss:getStorageValue(4) ~= generation then
		return
	end

	local spheres = {}
	local allOk = true
	for _, sphereSpot in pairs(config.spheres) do
		local sphere = Game.createMonster("Magical Sphere", sphereSpot, false, true)
		if sphere then
			sphere:setStorageValue(1, generation)
			table.insert(spheres, sphere)
		else
			allOk = false
		end
	end

	if allOk then
		for _, sphere in pairs(spheres) do
			EarlOsamRunTrackMonster(sphere)
		end
		boss:setStorageValue(3, #spheres)
		EarlOsamRunTrackEvent(token, addEvent(moveSphere, 4 * 1000, token, generation))
		return
	end

	for _, sphere in pairs(spheres) do
		sphere:remove()
	end
	logger.error("GraveDanger/EarlOsam: Magical Spheres failed to fully spawn (retries left: {})", retriesLeft)
	if retriesLeft > 0 then
		EarlOsamRunTrackEvent(token, addEvent(attemptSpheres, 1000, token, generation, retriesLeft - 1))
	else
		logger.error("GraveDanger/EarlOsam: technical abort - Magical Spheres failed to spawn after bounded retries")
		EarlOsamRunTerminate(token, "technical_abort", "Magical Spheres failed to spawn after bounded retries")
	end
end

local function initMech(token)
	if not EarlOsamRunIsCurrent(token) then
		return true
	end
	local boss = Creature(EarlOsamRun.bossId)
	if boss and EarlOsamRunOwnsBoss(boss) then
		local topCenter = Tile(config.centerRoom):getTopCreature()
		if topCenter and topCenter ~= boss then
			topCenter:teleportTo(Position(config.centerRoom.x, config.centerRoom.y + 2, config.centerRoom.z))
		end

		boss:teleportTo(config.centerRoom)
		boss:setMoveLocked(true)

		local generation = boss:getStorageValue(4)
		if generation < 0 then
			generation = 0
		end
		generation = generation + 1
		boss:setStorageValue(4, generation)

		attemptSpheres(token, generation, 3)
	end

	return true
end

local earl_osam_transform = CreatureEvent("earl_osam_transform")

function earl_osam_transform.onHealthChange(creature, attacker, primaryDamage, primaryType, secondaryDamage, secondaryType)
	-- CORRECTION (correction pass section G): run-owned - a stale Earl Osam instance left over from an
	-- already-terminated encounter can no longer progress or gate this handler's phase logic.
	if not creature or not EarlOsamRunOwnsBoss(creature) then
		return primaryDamage, primaryType, secondaryDamage, secondaryType
	end
	local token = EarlOsamRunCurrentToken()

	local players = Game.getSpectators(config.centerRoom, false, true, config.x, config.x, config.y, config.y)
	for _, player in pairs(players) do
		if player:isPlayer() then
			if player:getStorageValue(config.timer) < os.time() then
				player:setStorageValue(config.timer, os.time() + 20 * 3600)
				-- CORRECTION (section O): remembers that THIS attempt wrote the legacy Timer lockout
				-- for this player, so a later technical_abort knows it is safe to roll back.
				EarlOsamRunMarkTimerWritten(token, player:getId())
			end
			if player:getStorageValue(config.room) < os.time() then
				player:setStorageValue(config.room, os.time() + 30 * 60)
			end
		end
	end

	if primaryType == COMBAT_HEALING then
		return primaryDamage, primaryType, -secondaryDamage, secondaryType
	end

	local chance = math.random(1, 100)
	local position = Position(math.random(config.fromPos.x, config.toPos.x), math.random(config.fromPos.y, config.toPos.y), config.fromPos.z)
	local tile = Tile(position)

	if chance >= 95 and tile and tile:isWalkable() then
		Game.createMonster("Frozen Soul", position)
	end

	local healthThreshold = creature:getMaxHealth() * 0.15
	local currentDamage = creature:getStorageValue(1)
	if currentDamage < 0 then
		creature:setStorageValue(1, 0)
	end

	-- CORRECTION (correction pass section G): true invulnerability while mandatory Magical Spheres
	-- remain - previously this only displayed the BLOCKHIT effect while returning the incoming damage
	-- completely unmodified, so Earl Osam kept taking full damage during what looked like a shielded
	-- phase (the exact same bug already fixed for Count Vlarkorth's own shield in the original pass).
	if creature:getStorageValue(3) > 0 then
		creature:getPosition():sendMagicEffect(CONST_ME_BLOCKHIT)
		return 0, primaryType, 0, secondaryType
	end

	creature:setStorageValue(1, currentDamage + primaryDamage + secondaryDamage)

	if creature:getStorageValue(1) >= healthThreshold then
		creature:setStorageValue(1, 0)
		creature:setStorageValue(3, 0)
		initMech(token)
	end

	return primaryDamage, primaryType, -secondaryDamage, secondaryType
end

earl_osam_transform:register()

local sphere_death = CreatureEvent("sphere_death")

function sphere_death.onDeath(creature)
	local token = EarlOsamRunCurrentToken()
	if not token then
		return true
	end
	local boss = Creature(EarlOsamRun.bossId)
	if not boss or not EarlOsamRunOwnsBoss(boss) then
		return true
	end
	-- A sphere from a superseded generation dying late must not decrement the CURRENT generation's
	-- count (see the comment on moveSphere/attemptSpheres above).
	if creature:getStorageValue(1) ~= boss:getStorageValue(4) then
		return true
	end
	local currentSphereCount = boss:getStorageValue(3)
	boss:setStorageValue(3, math.max(0, currentSphereCount - 1))
	if boss:getStorageValue(3) <= 0 and boss:isMoveLocked() then
		boss:setMoveLocked(false)
	end
	return true
end

sphere_death:register()

-- ================================================================
-- EARL OSAM SUCCESS (correction pass section G)
-- ================================================================
-- Releases EarlOsamRun's own bookkeeping on a legitimate kill. Earl Osam's own grave/boss credit is
-- unaffected - handled separately by the pre-existing generic creaturescripts_boss_kill.lua path
-- (earl osam -> Graves.Cormaya).
local earl_osam_success = CreatureEvent("earl_osam_success")

function earl_osam_success.onDeath(creature)
	local targetMonster = creature:getMonster()
	if not targetMonster or targetMonster:getMaster() then
		return true
	end
	if not EarlOsamRunOwnsBoss(creature) then
		return true
	end
	EarlOsamRunTerminate(EarlOsamRunCurrentToken(), "success", "Earl Osam defeated")
	return true
end

earl_osam_success:register()
