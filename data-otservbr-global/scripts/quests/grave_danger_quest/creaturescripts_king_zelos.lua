local zelos_damage = CreatureEvent("zelos_damage")

-- Source: "the further the ritual progresses when you face him, he will become considerably more
-- powerful" - i.e. the longer the team takes to clear the four wings, the less damage King Zelos
-- takes, but also (executor contract, section 18) the MORE damage he deals back. `ritualSeconds`
-- (creature storage 1) is the elapsed clear time written by zelos_init.
local RITUAL_FULL_SECONDS = 800

-- Registered on King Zelos himself, so CREATURE_EVENT_HEALTHCHANGE only ever fires here with
-- `creature` = Zelos as the damage RECIPIENT (incoming, player -> Zelos). His own outbound damage
-- (Zelos -> player) cannot be scaled from this side - see zelos_outgoing_damage below.
function zelos_damage.onHealthChange(creature, attacker, primaryDamage, primaryType, secondaryDamage, secondaryType)
	if primaryType == COMBAT_HEALING then
		return primaryDamage, primaryType, -secondaryDamage, secondaryType
	end

	local ritualSeconds = creature:getStorageValue(1)
	if ritualSeconds < 0 then
		ritualSeconds = 0
	end
	-- CUSTOM_GLOBAL_LIKE_PENDING_EXACT_FORMULA (executor contract, section 18): the owner reference
	-- confirms ritual time scales damage BOTH ways but does not give an exact formula for either
	-- direction. progress/outgoingMultiplier below are this pass's functional implementation, not
	-- claimed to be Global-exact.
	local progress = math.min(ritualSeconds / RITUAL_FULL_SECONDS, 0.99)
	primaryDamage = (primaryDamage + secondaryDamage) * (1 - progress)
	secondaryDamage = 0

	-- CUSTOM_GLOBAL_LIKE_PENDING_EXACT_VALUE (executor contract, section 20): Greater Hex also
	-- reduces the Hexed player's own damage output. 50% is a functional value, not Global-exact.
	local token = KingZelosRunCurrentToken()
	if token and attacker and attacker:isPlayer() and KingZelosRunHasHex(token, attacker:getId()) then
		primaryDamage = primaryDamage * 0.5
	end

	return primaryDamage, primaryType, -secondaryDamage, secondaryType
end

zelos_damage:register()

-- CORRECTION (executor contract, section 18): onHealthChange registered on King Zelos only ever
-- sees damage being dealt TO him (he is always `creature` there), never damage he deals out - Lua
-- health-change events fire per damage-recipient. The outgoing Zelos -> player scaling therefore
-- cannot live in zelos_damage above; it needs its own hook on the RECIPIENT side. Reusing the
-- already-accepted onHealthChange pattern, registered on players instead, scoped to only scale
-- damage whose attacker is the current run's own King Zelos.
local zelos_outgoing_damage = CreatureEvent("zelos_outgoing_damage")

function zelos_outgoing_damage.onHealthChange(creature, attacker, primaryDamage, primaryType, secondaryDamage, secondaryType)
	if not creature or not creature:isPlayer() then
		return primaryDamage, primaryType, secondaryDamage, secondaryType
	end

	if primaryType == COMBAT_HEALING then
		-- CORRECTION (executor contract, section 20): Greater Hex reduces healing received.
		-- CONDITION_PARAM_BUFF_HEALINGRECEIVED is clamped non-negative in the engine (src/creatures/
		-- combat/condition.cpp), so it cannot express a reduction - handled manually here instead.
		-- CUSTOM_GLOBAL_LIKE_PENDING_EXACT_VALUE: 50% is a functional value, not Global-exact.
		local token = KingZelosRunCurrentToken()
		if token and KingZelosRunHasHex(token, creature:getId()) then
			primaryDamage = primaryDamage * 0.5
		end
		return primaryDamage, primaryType, secondaryDamage, secondaryType
	end

	if not attacker or not attacker:isMonster() or attacker:getName():lower() ~= "king zelos" then
		return primaryDamage, primaryType, secondaryDamage, secondaryType
	end
	if not KingZelosRunOwnsMonster(attacker) then
		return primaryDamage, primaryType, secondaryDamage, secondaryType
	end

	local ritualSeconds = attacker:getStorageValue(1)
	if ritualSeconds < 0 then
		ritualSeconds = 0
	end
	local progress = math.min(ritualSeconds / RITUAL_FULL_SECONDS, 0.99)
	local outgoingMultiplier = 1 + progress

	return primaryDamage * outgoingMultiplier, primaryType, secondaryDamage * outgoingMultiplier, secondaryType
end

zelos_outgoing_damage:register()

-- CREATURE_EVENT_HEALTHCHANGE only fires on the DAMAGE RECIPIENT's own registered events (confirmed
-- against src/game/game.cpp's applyHealthChange, `target->getCreatureEvents(CREATURE_EVENT_HEALTHCHANGE)`),
-- so the outgoing (Zelos -> player) scaling above must be registered on players, not on Zelos. This
-- mirrors the already-accepted pattern in soul_war_mechanics.lua (SoulWarLogin registering
-- "GoshnarsHatredBuff" on every player at login so a boss-dealt-damage handler can run on the
-- recipient side) rather than inventing a new registration mechanism.
local zelos_login = CreatureEvent("GraveDangerZelosLogin")

function zelos_login.onLogin(player)
	player:registerEvent("zelos_outgoing_damage")

	-- CORRECTION (correction pass section J8): defensive cleanup - if this player is carrying a
	-- Greater Hex condition (CONDITION_ATTRIBUTES tagged GREATER_HEX_SUBID) but is NOT a legitimate
	-- participant of the currently-active King Zelos run (e.g. they logged out mid-encounter and the
	-- run has since ended, or the condition otherwise survived past its owning encounter), it is
	-- removed here. Only ever touches the GREATER_HEX_SUBID-tagged instance - never any unrelated
	-- CONDITION_ATTRIBUTES effect.
	local token = KingZelosRunCurrentToken()
	if not KingZelosRunIsParticipant(token, player:getId()) then
		removeGreaterHex(player)
	end

	return true
end

zelos_login:register()

-- Called by KingZelosRunTerminate (actions_king_zelos.lua) and by the cleanse vortex
-- (movements_king_zelos_cleanse_vortex.lua) - removes only the Greater Hex condition instance
-- (matched by GREATER_HEX_SUBID, king_zelos_greater_hex.lua), never any unrelated CONDITION_ATTRIBUTES
-- effect the player might otherwise be carrying. Does not touch KingZelosRun.hex bookkeeping itself -
-- callers own that (KingZelosRunTerminate clears the whole table after sweeping every hexed player;
-- the vortex clears just the one participant it cleansed).
function removeGreaterHex(player)
	if player then
		player:removeCondition(CONDITION_ATTRIBUTES, CONDITIONID_COMBAT, GREATER_HEX_SUBID)
	end
end

-- ================================================================
-- KING ZELOS SUCCESS (executor contract, section 24)
-- ================================================================
-- "king zelos" was deliberately removed from creaturescripts_boss_kill.lua's generic damage-map
-- table (see the comment left there) - a legitimate King Zelos kill must credit only participants of
-- the CURRENT run who are still physically inside the arena at the moment of death, not every
-- damage-map entry regardless of roster or presence.
local ARENA_FROM = Position(33414, 31520, 13)
local ARENA_TO = Position(33474, 31574, 13)

local function isInsideArena(creature)
	local pos = creature:getPosition()
	return pos.x >= ARENA_FROM.x and pos.x <= ARENA_TO.x and pos.y >= ARENA_FROM.y and pos.y <= ARENA_TO.y and pos.z == ARENA_FROM.z
end

local zelos_success = CreatureEvent("zelos_success")

function zelos_success.onDeath(creature)
	local targetMonster = creature:getMonster()

	if not targetMonster or targetMonster:getMaster() then
		return true
	end

	if not KingZelosRunOwnsMonster(creature) then
		return true
	end

	local token = KingZelosRunCurrentToken()

	for playerId in pairs(KingZelosRun.participants) do
		local player = Player(playerId)
		if player and isInsideArena(player) then
			player:setStorageValue(Storage.Quest.U12_20.GraveDanger.Bosses.KingZelos.Killed, 1)
		end
	end

	-- CORRECTION (correction pass section J2): King Zelos's own corpse/reward pipeline is still being
	-- processed by the engine at this point (we are inside his own onDeath handler chain) - passing
	-- his id here excludes only him from KingZelosRunTerminate's owned-monster sweep, while every other
	-- still-alive run-owned temporary entity (Risen Soldiers, an Unleashed Hex, wing leftovers) is
	-- still removed even on this success path.
	KingZelosRunTerminate(token, "success", "King Zelos defeated", creature:getId())

	return true
end

zelos_success:register()

-- CORRECTION (correction pass section J6): replaces the previous "are all six names absent" global
-- scan (fooled by Rewar's own live-name transform on his invulnerable form, and by any stale/unrelated
-- monster sharing one of those six names) with this run's own authoritative wing state. Stamps the
-- elapsed ritual-clear time onto the CURRENT run's own owned King Zelos only, exactly once, the moment
-- the fourth wing legitimately completes. Called both from zelos_init (on every relevant wing-entity
-- death) and from massTimeoutCheck below (Nargol's own wing can complete on a TIMED poll, with no
-- further death to re-trigger zelos_init afterward) so the stamp cannot be missed regardless of which
-- wing happens to finish last.
local function stampRitualClearTimeIfComplete(token)
	if not KingZelosRunAllWingsComplete(token) then
		return
	end
	local zelos = Creature(KingZelosRun.bossId)
	if not zelos or not KingZelosRunOwnsBoss(zelos) then
		return
	end
	if zelos:getStorageValue(1) > 0 then
		-- Already stamped for this run - do not overwrite with a later, larger elapsed value.
		return
	end
	local startedAt = Game.getStorageValue(Storage.Quest.U12_20.GraveDanger.KingZelosRitualStart)
	local elapsed = 0
	if startedAt > 0 then
		elapsed = math.max(os.time() - startedAt, 0)
	end
	zelos:setStorageValue(1, elapsed)
end

local zelos_init = CreatureEvent("zelos_init")

function zelos_init.onDeath(creature)
	local targetMonster = creature:getMonster()

	if not targetMonster or targetMonster:getMaster() then
		return true
	end

	-- CORRECTION (executor contract, sections 16/17): explicit per-wing completion, independent of
	-- any generation-blind global name presence/absence check. Rewar's own transform (his live name
	-- changes from "Rewar The Bloody" to "Rewar The Bloody Inv" mid-fight) means a name-presence
	-- lookup cannot tell "transformed" apart from "dead" - relying on one for the green teleport's
	-- wing-complete gate would have let players through while Rewar was still alive in his
	-- invulnerable form. Marking directly off which entity's own onDeath just fired is exact.
	local token = KingZelosRunCurrentToken()
	if not token or not KingZelosRunOwnsMonster(creature) then
		return true
	end

	local dyingName = creature:getName():lower()
	if dyingName == "the red knight" then
		KingZelosRunMarkWing(token, "redKnight")
	elseif dyingName == "rewar the bloody" or dyingName == "rewar the bloody inv" then
		KingZelosRunMarkWing(token, "rewar")
	end
	-- Nargol's wing is marked by massTimeoutCheck() (his exact owned Regenerating Mass staying dead
	-- through its window) and Magnor's by shard_death() (all four exact owned Shards Of Magnor gone)
	-- further below - both are the true completion signal for those two wings, not their primary
	-- boss's death.

	stampRitualClearTimeIfComplete(token)

	return true
end

zelos_init:register()

local blood_explode = Combat()
local area = createCombatArea(AREA_SQUARE1X1)
blood_explode:setArea(area)

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

-- ================================================================
-- NARGOL / REGENERATING MASS (executor contract, section 16)
-- ================================================================
local NARGOL_CENTER_ROOM = Position(33443, 31545, 13)
local NARGOL_POSITION = Position(33423, 31529, 13)

local attemptNargolRespawn
local attemptRegeneratingMassSpawn
local massTimeoutCheck

attemptNargolRespawn = function(token, retriesLeft)
	retriesLeft = retriesLeft or 3
	if not KingZelosRunIsCurrent(token) then
		return
	end
	local nargol = Game.createMonster("Nargol The Impaler", NARGOL_POSITION, false, true)
	if nargol then
		KingZelosRunTrackMonster(nargol)
		return
	end
	logger.error("GraveDanger/KingZelos: Nargol The Impaler failed to respawn (retries left: {})", retriesLeft)
	if retriesLeft > 0 then
		KingZelosRunTrackEvent(token, addEvent(attemptNargolRespawn, 1000, token, retriesLeft - 1))
	else
		KingZelosRunTerminate(token, "technical_abort", "Nargol failed to respawn after the Regenerating Mass survived")
	end
end

-- PROJECT DECISION (REFERENCE_CONFLICT, executor contract, section 16): the owner reference gives
-- approximately one minute; the pre-repair implementation used a flat 60 seconds. Per this
-- contract's explicit instruction, this pass uses 30 seconds.
--
-- CORRECTION (correction pass section J3): decides off the CURRENT run's own exact owned Regenerating
-- Mass id (KingZelosRun.nargolMassId, set by attemptRegeneratingMassSpawn below) instead of a
-- generation-blind `Creature("Regenerating Mass")` name lookup, which could not tell this run's own
-- mass apart from a stale/unrelated one and had no way to detect "already handled".
massTimeoutCheck = function(token)
	if not KingZelosRunIsCurrent(token) then
		return
	end
	local mass = Creature(KingZelosRun.nargolMassId)
	if mass and KingZelosRunOwnsNargolMass(mass) then
		mass:remove()
		attemptNargolRespawn(token, 3)
	else
		KingZelosRunMarkWing(token, "nargol")
		stampRitualClearTimeIfComplete(token)
	end
end

attemptRegeneratingMassSpawn = function(token, retriesLeft)
	retriesLeft = retriesLeft or 3
	if not KingZelosRunIsCurrent(token) then
		return
	end
	local mass = Game.createMonster("Regenerating Mass", NARGOL_CENTER_ROOM, false, true)
	if mass then
		KingZelosRunTrackMonster(mass)
		KingZelosRunSetNargolMass(token, mass)
		KingZelosRunTrackEvent(token, addEvent(massTimeoutCheck, 30 * 1000, token))
		return
	end
	logger.error("GraveDanger/KingZelos: Regenerating Mass failed to spawn (retries left: {})", retriesLeft)
	if retriesLeft > 0 then
		KingZelosRunTrackEvent(token, addEvent(attemptRegeneratingMassSpawn, 1000, token, retriesLeft - 1))
	else
		KingZelosRunTerminate(token, "technical_abort", "Regenerating Mass failed to spawn after Nargol's death")
	end
end

local nargol_death = CreatureEvent("nargol_death")

function nargol_death.onDeath(creature)
	local targetMonster = creature:getMonster()

	if not targetMonster or targetMonster:getMaster() then
		return true
	end

	local token = KingZelosRunCurrentToken()
	if not token or not KingZelosRunOwnsMonster(creature) then
		return true
	end

	attemptRegeneratingMassSpawn(token, 3)

	return true
end

nargol_death:register()

local shard_explode = Combat()
shard_explode:setParameter(COMBAT_PARAM_EFFECT, CONST_ME_MAGIC_RED)

local area = createCombatArea(AREA_CIRCLE2X2)
shard_explode:setArea(area)

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

	-- CORRECTION (correction pass section J4): decides off the CURRENT run's own exact owned Shard Of
	-- Magnor generation (KingZelosRun.magnorShardIds, set by attemptMagnorShards below) instead of a
	-- generation-blind `not Creature("Shard Of Magnor")` name-absence check, which could be fooled by
	-- a stale/unrelated shard elsewhere in the world and had no notion of "this run's own set". All
	-- four shards share one life pool, so they die together; whichever death event happens to run last
	-- will find none of THIS run's own tracked shards still alive and mark the wing complete.
	-- Idempotent - safe to call repeatedly.
	local token = KingZelosRunCurrentToken()
	if token and KingZelosRunOwnsMagnorShard(creature) then
		KingZelosRunClearMagnorShard(creature:getId())
		if not KingZelosRunAnyMagnorShardAlive() then
			KingZelosRunMarkWing(token, "magnor")
			stampRitualClearTimeIfComplete(token)
		end
	end

	return true
end

shard_death:register()

-- ================================================================
-- MAGNOR / SHARDS (executor contract, section 16)
-- ================================================================
local function attemptMagnorShards(token, position, retriesLeft)
	retriesLeft = retriesLeft or 3
	if not KingZelosRunIsCurrent(token) then
		return
	end

	local id = os.time()
	local shards = {}
	local allOk = true
	for _ = 1, 4 do
		local shard = Game.createMonster("Shard Of Magnor", position, false, true)
		if shard then
			table.insert(shards, shard)
		else
			allOk = false
		end
	end

	if allOk then
		local shardIds = {}
		for _, shard in pairs(shards) do
			shard:beginSharedLife(id)
			shard:registerEvent("SharedLife")
			shard:registerEvent("shard_death")
			KingZelosRunTrackMonster(shard)
			shardIds[shard:getId()] = true
		end
		-- CORRECTION (correction pass section J4): establishes this wave as the current run's own
		-- exact-owned shard set, consumed by shard_death above.
		KingZelosRunSetMagnorShards(token, shardIds)
		return
	end

	-- Do not accept a partial 1/2/3 shard generation - they share one life pool. Clean up whatever
	-- did spawn and retry the full set of 4.
	for _, shard in pairs(shards) do
		shard:remove()
	end
	logger.error("GraveDanger/KingZelos: Magnor's 4 Shards failed to fully spawn (retries left: {})", retriesLeft)
	if retriesLeft > 0 then
		KingZelosRunTrackEvent(token, addEvent(attemptMagnorShards, 1000, token, position, retriesLeft - 1))
	else
		KingZelosRunTerminate(token, "technical_abort", "Magnor's mandatory Shards failed to spawn after bounded retries")
	end
end

local magnor_death = CreatureEvent("magnor_death")

function magnor_death.onDeath(creature)
	local targetMonster = creature:getMonster()

	if not targetMonster or targetMonster:getMaster() then
		return true
	end

	local token = KingZelosRunCurrentToken()
	if not token or not KingZelosRunOwnsMonster(creature) then
		return true
	end

	attemptMagnorShards(token, creature:getPosition(), 3)

	return true
end

magnor_death:register()

-- ================================================================
-- REWAR / FETTERS (executor contract, section 16)
-- ================================================================
local function attemptFetters(token, bossId, retriesLeft)
	retriesLeft = retriesLeft or 3
	if not KingZelosRunIsCurrent(token) then
		return
	end
	local creature = Creature(bossId)
	if not creature or not KingZelosRunOwnsMonster(creature) then
		return
	end

	local fetters = math.random(1, 3)
	local fromPos, toPos = Position(33458, 31556, 13), Position(33467, 31566, 13)
	local spawnedCount = 0
	local fetterIds = {}

	for _ = 1, fetters do
		local position = Position(math.random(fromPos.x, toPos.x), math.random(fromPos.y, toPos.y), fromPos.z)
		local fetter = Game.createMonster("Fetter", position, false, true)
		if fetter then
			spawnedCount = spawnedCount + 1
			creature:setStorageValue(2, creature:getStorageValue(2) + 1)
			KingZelosRunTrackMonster(fetter)
			fetterIds[fetter:getId()] = true
		end
	end

	if spawnedCount > 0 then
		-- CORRECTION (correction pass section J5): establishes this wave as the current run's own
		-- exact-owned Fetter cycle, consumed by fetter_death below - a leftover Fetter from an earlier
		-- cycle can no longer decrement THIS cycle's obligation.
		KingZelosRunSetRewarFetters(token, fetterIds)
		-- CORRECTION (executor contract, section 16): never transform into the invulnerable form
		-- unless at least one Fetter actually exists to end it - the pre-repair code transformed
		-- unconditionally, so an all-Fetter-spawns-failed edge case left Rewar permanently
		-- invulnerable with nothing in the world able to revert him.
		creature:setType("Rewar The Bloody Inv")
		return
	end

	logger.error("GraveDanger/KingZelos: all Fetter spawns failed for Rewar the Bloody (retries left: {})", retriesLeft)
	if retriesLeft > 0 then
		KingZelosRunTrackEvent(token, addEvent(attemptFetters, 1000, token, bossId, retriesLeft - 1))
	else
		KingZelosRunTerminate(token, "technical_abort", "Rewar's mandatory Fetters failed to spawn after bounded retries")
	end
end

local fetter_death = CreatureEvent("fetter_death")

function fetter_death.onDeath(creature)
	local targetMonster = creature:getMonster()

	if not targetMonster or targetMonster:getMaster() then
		return true
	end

	-- CORRECTION (correction pass section J5): the dying Fetter must belong to the CURRENT run's
	-- CURRENT cycle before it may decrement Rewar's obligation - a Fetter left over from an earlier
	-- cycle/run must never unlock the current one.
	if not KingZelosRunOwnsRewarFetter(creature) then
		return true
	end
	KingZelosRunClearRewarFetter(creature:getId())

	local boss = Creature("Rewar The Bloody Inv") or Creature("Rewar The Bloody")

	if boss and KingZelosRunOwnsMonster(boss) then
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

		local token = KingZelosRunCurrentToken()
		if token and KingZelosRunOwnsMonster(creature) then
			attemptFetters(token, creature:getId(), 3)
		end
	end

	return primaryDamage, primaryType, -secondaryDamage, secondaryType
end

rewar_the_bloody:register()
