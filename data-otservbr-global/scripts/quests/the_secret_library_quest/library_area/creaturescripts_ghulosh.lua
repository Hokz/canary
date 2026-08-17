local ROOM_FROM = Position(32748, 32713, 10)
local ROOM_TO = Position(32763, 32729, 10)

local function isInsideRoom(player)
	local pos = player:getPosition()
	return pos.x >= ROOM_FROM.x and pos.x <= ROOM_TO.x and pos.y >= ROOM_FROM.y and pos.y <= ROOM_TO.y and pos.z == ROOM_FROM.z
end

-- CORRECTION (Secret Library repair v2, section 17): drives GhuloshRunCheckHealthThreshold
-- (actions_ghulosh.lua) instead of the previous dead-code stage lookup (Game.getStorageValue
-- defaulting to -1 could never match the stage table's 1/2/3 values).
local creaturescripts_library_ghulosh = CreatureEvent("ghuloshThink")

function creaturescripts_library_ghulosh.onThink(creature, interval)
	if not creature:isMonster() then
		return true
	end
	local token = GhuloshRunCurrentToken()
	if not token or not GhuloshRunOwnsBoss(creature) then
		return true
	end
	GhuloshRunCheckHealthThreshold(token, creature)
	return true
end

creaturescripts_library_ghulosh:register()

local creaturescripts_library_ghulosh_death = CreatureEvent("ghuloshDeath")

function creaturescripts_library_ghulosh_death.onDeath(creature, corpse, killer, mostDamageKiller, unjustified, mostDamageUnjustified)
	local cPos = creature:getPosition()
	local name = creature:getName():lower()
	local token = GhuloshRunCurrentToken()

	-- CORRECTION (section 17): boss ownership is checked FIRST, by id, not by name - this same
	-- creature instance may currently be typed/named "Ghulosh' Deathgaze" (setType, not a
	-- remove+recreate swap) when it dies, e.g. from the persistent phase's reflected damage, so a
	-- name == "ghulosh" check alone would miss that death entirely.
	if token and GhuloshRunOwnsBoss(creature) then
		-- CORRECTION (section 13/18): persistent per-player completion credit, restricted to this
		-- run's own roster, still physically present at the moment of death.
		for playerId in pairs(GhuloshRun.participants) do
			local player = Player(playerId)
			if player and isInsideRoom(player) then
				if player:getStorageValue(Storage.Quest.U11_80.TheSecretLibrary.Library.GhuloshDefeated) < 1 then
					player:setStorageValue(Storage.Quest.U11_80.TheSecretLibrary.Library.GhuloshDefeated, 1)
				end
			end
		end
		GhuloshRunTerminate(token, "success", "Ghulosh defeated")
		return true
	end

	-- CORRECTION (section 17): ownership-scoped - a stale Book of Death/Concentrated Death from a
	-- different/finished run can no longer mutate this run's Ghulosh.
	if name == "the book of death" then
		if token and GhuloshRunOwnsBook(creature) then
			GhuloshRunBookDied(token, cPos)
		end
	elseif name == "concentrated death" then
		if token and GhuloshRunOwnsSlime(creature) then
			GhuloshRunSlimeDied(token)
		end
	end

	return true
end

creaturescripts_library_ghulosh_death:register()

-- ================================================================
-- REFLECTED DAMAGE THROUGH THE SLIME (Secret Library repair v2, section 17)
-- ================================================================
-- While GhuloshRun is in its persistent Deathgaze phase, Concentrated Death is the required damage
-- path (Deathgaze himself carries ~100% resistance to most combat types on his own monster type,
-- confirmed pre-existing on "Ghulosh' Deathgaze"). Damage dealt to the current-run-owned slime is
-- redirected to Deathgaze as COMBAT_LIFEDRAIN (0% resisted by Deathgaze, unlike the physical/elemental
-- types he blocks almost entirely) instead of being applied to the slime itself.
local concentratedDeathReflect = CreatureEvent("ghuloshSlimeReflect")

function concentratedDeathReflect.onHealthChange(creature, attacker, primaryDamage, primaryType, secondaryDamage, secondaryType, origin)
	local token = GhuloshRunCurrentToken()
	if not token or not GhuloshRunOwnsSlime(creature) or GhuloshRun.phase ~= "deathgaze_persistent" then
		return primaryDamage, primaryType, secondaryDamage, secondaryType
	end
	if primaryType == COMBAT_HEALING then
		return primaryDamage, primaryType, secondaryDamage, secondaryType
	end

	local boss = Creature(GhuloshRun.bossId)
	if boss and GhuloshRunOwnsBoss(boss) then
		local total = math.abs(primaryDamage or 0) + math.abs(secondaryDamage or 0)
		if total > 0 then
			doTargetCombatHealth(0, boss, COMBAT_LIFEDRAIN, -total, -total, CONST_ME_MAGIC_RED)
		end
	end

	-- The slime itself takes no damage from this - it is a conduit, not the actual target.
	return 0, primaryType, 0, secondaryType
end

concentratedDeathReflect:register()
