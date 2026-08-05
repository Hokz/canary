local config = {
	centerRoom = Position(33443, 31545, 13),
	newPosition = Position(33436, 31572, 13),
	exitPos = Position(32172, 31917, 8),
	x = 30,
	y = 30,
	summons = {
		{
			name = "Rewar The Bloody",
			pos = Position(33463, 31562, 13),
		},
		{
			name = "The Red Knight",
			pos = Position(33423, 31562, 13),
		},
		{
			name = "Magnor Mournbringer",
			pos = Position(33463, 31529, 13),
		},
		{
			name = "Nargol the Impaler",
			pos = Position(33423, 31529, 13),
		},
		{
			name = "King Zelos",
			pos = Position(33443, 31545, 13),
		},
	},
	timer = Storage.Quest.U12_20.GraveDanger.Bosses.KingZelos.Timer,
	room = Storage.Quest.U12_20.GraveDanger.Bosses.KingZelos.Room,
	fromPos = Position(33414, 31520, 13),
	toPos = Position(33474, 31574, 13),
}

local zelos_damage = CreatureEvent("zelos_damage")

-- Source: "the further the ritual progresses when you face him, he will become considerably more
-- powerful" - i.e. the longer the team takes to clear the four wings, the less damage King Zelos
-- takes. `ritualSeconds` (creature storage 1) is the elapsed clear time written by zelos_init.
--
-- CONFIRMED BUG (pre-existing): storage 1 was never initialised on King Zelos, so it read -1 and the
-- old formula produced `dmg - dmg * (-1/800)` = 100.125% damage forever - the scaling never applied.
-- Worse, zelos_init wrote `os.time() - (-1)` (~1.7e9) into it, which would have hit the `else` branch
-- and left Zelos taking 1% damage, i.e. effectively invulnerable. Both ends are fixed: zelos_init now
-- records a real elapsed time, and an unset/!invalid value here is clamped to "ritual just started".
local RITUAL_FULL_SECONDS = 800

function zelos_damage.onHealthChange(creature, attacker, primaryDamage, primaryType, secondaryDamage, secondaryType)
	if primaryType ~= COMBAT_HEALING then
		local ritualSeconds = creature:getStorageValue(1)
		if ritualSeconds < 0 then
			ritualSeconds = 0
		end

		local progress = math.min(ritualSeconds / RITUAL_FULL_SECONDS, 0.99)
		primaryDamage = (primaryDamage + secondaryDamage) * (1 - progress)
		secondaryDamage = 0
	end

	return primaryDamage, primaryType, -secondaryDamage, secondaryType
end

zelos_damage:register()

local zelos_init = CreatureEvent("zelos_init")

function zelos_init.onDeath(creature)
	local targetMonster = creature:getMonster()

	if not targetMonster or targetMonster:getMaster() then
		return true
	end

	local knights = { "Nargol The Impaler", "Magnor Mournbringer", "The Red Knight", "Rewar The Bloody", "Shard Of Magnor", "Regenerating Mass" }

	for _, knight in pairs(knights) do
		local boss = Creature(knight)
		if boss and boss:getId() ~= creature:getId() then
			return true
		end
	end

	local zelos = Creature("King Zelos")

	if zelos then
		-- This runs when the LAST wing lich-knight dies. Record how long the whole clear took, so
		-- zelos_damage can scale his resistance by it. Previously this computed
		-- `os.time() - zelos:getStorageValue(1)` against an uninitialised storage (-1), yielding a
		-- ~1.7-billion-second "elapsed time" that would have made him take 1% damage. The fight start
		-- time is stamped by the lever (actions_king_zelos.lua sets it via the BossLever onUseExtra
		-- hook); if it is somehow missing we fall back to 0 = "no ritual progress", which is the
		-- player-favourable direction rather than an accidental invulnerability.
		local startedAt = Game.getStorageValue(Storage.Quest.U12_20.GraveDanger.KingZelosRitualStart)
		local elapsed = 0

		if startedAt > 0 then
			elapsed = math.max(os.time() - startedAt, 0)
		end

		zelos:setStorageValue(1, elapsed)
	end

	return true
end

zelos_init:register()

local blood_explode = Combat()
local area = createCombatArea(AREA_SQUARE1X1)
blood_explode:setArea(area)

-- CONFIRMED BUG (pre-existing): this callback was named `onTargetTile`, and the shard explosion
-- further down defined a SECOND global with the exact same name. Combat callbacks are resolved by
-- name at execution time, so the later definition silently won and BOTH explosions ran the shard's
-- lifedrain body - meaning the Red Knight's drown-explosion (the only thing that can damage him,
-- since the_red_knight.lua resists everything except drown) never fired and the southwest wing boss
-- was unkillable. Renamed to a unique name; the shard one is renamed to match below.
-- Also reordered: `tile:getTopCreature()` was dereferenced BEFORE the `if tile` nil check.
function onTargetTileBloodExplode(cid, pos)
	local tile = Tile(pos)
	if not tile then
		return
	end

	local target = tile:getTopCreature()
	if target and target:getId() ~= cid:getId() then
		if (target:isMonster() and target:getName():lower() == "the red knight") or target:isPlayer() then
			doTargetCombatHealth(0, target, COMBAT_DROWNDAMAGE, -20000, -25000)
		end
	end
end

blood_explode:setCallback(CALLBACK_PARAM_TARGETTILE, "onTargetTileBloodExplode")

local blood_death = CreatureEvent("blood_death")

function blood_death.onDeath(creature)
	local targetMonster = creature:getMonster()

	if not targetMonster or targetMonster:getMaster() then
		return true
	end

	local var = { type = 1, number = creature:getId() }

	blood_explode:execute(creature, var)

	return true
end

blood_death:register()

local nargol_death = CreatureEvent("nargol_death")

function nargol_death.onDeath(creature)
	local targetMonster = creature:getMonster()

	if not targetMonster or targetMonster:getMaster() then
		return true
	end

	-- Source: killing Nargol spawns a Regenerating Mass in the CENTRAL room; if it is not killed
	-- within one minute the attempt fails and Nargol returns. This previously spawned the mass back
	-- at Nargol's own wing position rather than the centre, and used a 30-second timer.
	local centerRoom = Position(33443, 31545, 13)
	local nargolPos = Position(33423, 31529, 13)

	Game.createMonster("Regenerating Mass", centerRoom, false, true)

	addEvent(function()
		local mass = Creature("Regenerating Mass")
		if mass then
			mass:remove()
			Game.createMonster("Nargol The Impaler", nargolPos, false, true)
		end
	end, 60 * 1000)

	return true
end

nargol_death:register()

local shard_explode = Combat()
shard_explode:setParameter(COMBAT_PARAM_EFFECT, CONST_ME_MAGIC_RED)

local area = createCombatArea(AREA_CIRCLE2X2)
shard_explode:setArea(area)

-- Renamed from the colliding global `onTargetTile` - see the comment on the blood explosion above.
function onTargetTileShardExplode(cid, pos)
	local tile = Tile(pos)
	if not tile then
		return
	end

	local target = tile:getTopCreature()
	if target and target:isPlayer() then
		doTargetCombatHealth(0, target, COMBAT_LIFEDRAIN, -2000, -2500)
	end
end

shard_explode:setCallback(CALLBACK_PARAM_TARGETTILE, "onTargetTileShardExplode")

local shard_death = CreatureEvent("shard_death")

function shard_death.onDeath(creature)
	local targetMonster = creature:getMonster()

	if not targetMonster or targetMonster:getMaster() then
		return true
	end

	local var = { type = 1, number = creature:getId() }

	shard_explode:execute(creature, var)

	return true
end

shard_death:register()

local magnor_death = CreatureEvent("magnor_death")

function magnor_death.onDeath(creature)
	local targetMonster = creature:getMonster()

	if not targetMonster or targetMonster:getMaster() then
		return true
	end

	local id = os.time()

	for i = 1, 4 do
		local shards = Game.createMonster("Shard Of Magnor", creature:getClosestFreePosition(creature:getPosition(), true))
		-- Game.createMonster returns nil when no free position is available (a crowded room is
		-- entirely plausible here); the result was previously dereferenced immediately.
		if shards then
			shards:beginSharedLife(id)
			shards:registerEvent("SharedLife")
			shards:registerEvent("shard_death")
		end
	end

	return true
end

magnor_death:register()

local fetter_death = CreatureEvent("fetter_death")

function fetter_death.onDeath(creature)
	local targetMonster = creature:getMonster()

	if not targetMonster or targetMonster:getMaster() then
		return true
	end

	local boss = Creature("Rewar The Bloody")

	if boss then
		boss:setStorageValue(2, boss:getStorageValue(2) - 1)

		if boss:getStorageValue(2) <= 0 then
			boss:setType("Rewar The Bloody")
		end
	end

	return true
end

fetter_death:register()

local rewar_the_bloody = CreatureEvent("rewar_the_bloody")

rewar_the_bloody:type("healthchange")

function rewar_the_bloody.onHealthChange(creature, attacker, primaryDamage, primaryType, secondaryDamage, secondaryType)
	if primaryType == COMBAT_HEALING then
		return primaryDamage, primaryType, -secondaryDamage, secondaryType
	end

	local health = creature:getMaxHealth() * 0.05

	creature:setStorageValue(1, creature:getStorageValue(1) + primaryDamage + secondaryDamage)

	if creature:getStorageValue(1) >= health then
		creature:setStorageValue(1, 0)
		creature:setStorageValue(2, 0)

		local fetters = math.random(1, 3)
		local fromPos, toPos = Position(33458, 31556, 13), Position(33467, 31566, 13)

		for i = 1, fetters do
			local position = Position(math.random(fromPos.x, toPos.x), math.random(fromPos.y, toPos.y), fromPos.z)
			local fetter = Game.createMonster("Fetter", position, true, true)
			if fetter then
				creature:setStorageValue(2, creature:getStorageValue(2) + 1)
			end
		end
		creature:setType("Rewar The Bloody Inv")
	end

	return primaryDamage, primaryType, -secondaryDamage, secondaryType
end

rewar_the_bloody:register()
