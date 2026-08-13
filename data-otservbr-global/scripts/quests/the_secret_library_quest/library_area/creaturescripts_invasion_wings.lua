-- Secret Library final invasion ("Scourge of Oblivion") - the 4 wing-boss mechanics.
--
-- CORRECTION (Secret Library repair v2, sections 24-28): every handler below is now scoped through
-- SecretLibraryInvasionRun (actions_the_scourge_of_oblivion.lua) - exact current-run token +
-- exact-creature-id ownership, replacing the pre-existing Game-storage-only / bare-name-match
-- implementation. A wing boss or add that does not belong to the CURRENT run and CURRENT wing
-- generation can no longer mutate progress, heal/explode against the wrong encounter, or credit a
-- wing as cleared.

-- The Spellstealer: starts grey (vulnerable). Periodically swaps into an immune GREEN or RED colored
-- form; luring it onto the matching-colored teleport (movements_invasion_start.lua) swaps it back to
-- grey/vulnerable, preserving current HP.

local spellstealerColorSwap = CreatureEvent("InvasionSpellstealerColorSwap")
function spellstealerColorSwap.onThink(creature, interval)
	local token = SecretLibraryInvasionRunCurrentToken()
	if not token or not SecretLibraryInvasionRunOwnsWingBoss("spellstealer", creature) then
		return true
	end
	if creature:getName():lower() ~= "the spellstealer" then
		return true
	end
	if math.random(1, 100) > 4 then -- roughly every ~25 ticks on average, not every single tick
		return true
	end
	local color = math.random(2) == 1 and "green" or "red"
	local oldHealth = creature:getHealth()
	creature:setType(("The Spellstealer (%s)"):format(color))
	creature:addHealth(-(creature:getHealth() - oldHealth))
	creature:say(("The Spellstealer channels %s energy!"):format(color), TALKTYPE_MONSTER_SAY)
	return true
end
spellstealerColorSwap:register()

local spellstealerDeath = CreatureEvent("InvasionSpellstealerDeath")
function spellstealerDeath.onDeath(creature, corpse, lasthitkiller, mostdamagekiller)
	local token = SecretLibraryInvasionRunCurrentToken()
	if token and SecretLibraryInvasionRunOwnsWingBoss("spellstealer", creature) then
		InvasionWingBossDied(token, "spellstealer")
	end
	return true
end
spellstealerDeath:register()

-- The Scion of Havoc: spawns "Spawn of Havoc" adds owned by the current wing generation. Killing one
-- explodes it (3000-4000 AoE damage) and heals the CURRENT-RUN Scion only - players are meant to
-- avoid/ignore them, not required to kill anything but the boss itself.

local scionAddDeath = CreatureEvent("InvasionSpawnOfHavocDeath")
function scionAddDeath.onDeath(creature, corpse, lasthitkiller, mostdamagekiller)
	local token = SecretLibraryInvasionRunCurrentToken()
	if not token or not SecretLibraryInvasionRunOwnsWingAdd("scionOfHavoc", creature) then
		return true
	end
	local position = creature:getPosition()
	position:sendMagicEffect(CONST_ME_EXPLOSIONAREA)
	for _, spectator in ipairs(Game.getSpectators(position, false, true, 3, 3, 3, 3)) do
		spectator:addHealth(-math.random(3000, 4000))
	end
	local boss = Creature(SecretLibraryInvasionRun.wingBossIds.scionOfHavoc)
	if boss and SecretLibraryInvasionRunOwnsWingBoss("scionOfHavoc", boss) then
		boss:addHealth(math.random(2000, 4000))
	end
	return true
end
scionAddDeath:register()

local scionOfHavocDeath = CreatureEvent("InvasionScionOfHavocDeath")
function scionOfHavocDeath.onDeath(creature, corpse, lasthitkiller, mostdamagekiller)
	local token = SecretLibraryInvasionRunCurrentToken()
	if token and SecretLibraryInvasionRunOwnsWingBoss("scionOfHavoc", creature) then
		InvasionWingBossDied(token, "scionOfHavoc")
	end
	return true
end
scionOfHavocDeath:register()

-- Brother Chill & Brother Freeze: heal each other periodically, and are healed rather than damaged by
-- ice attacks (this engine clamps elemental resistance at 100% = 0 damage, so the "ice heals them"
-- part reuses the onHealthChange redirect technique this quest's own Mazzinor already used).

local brothersHealIce = CreatureEvent("InvasionBrothersHealIce")
function brothersHealIce.onHealthChange(creature, attacker, primaryDamage, primaryType, secondaryDamage, secondaryType, origin)
	local token = SecretLibraryInvasionRunCurrentToken()
	if not token or not SecretLibraryInvasionRunOwnsWingBoss("brothers", creature) then
		return primaryDamage, primaryType, secondaryDamage, secondaryType
	end
	if primaryType == COMBAT_ICEDAMAGE or secondaryType == COMBAT_ICEDAMAGE then
		creature:addHealth(-(primaryDamage or 0) - (secondaryDamage or 0))
		return 0, primaryType, 0, secondaryType
	end
	return primaryDamage, primaryType, secondaryDamage, secondaryType
end
brothersHealIce:register()

local brothersHealEachOther = CreatureEvent("InvasionBrothersHealEachOther")
function brothersHealEachOther.onThink(creature, interval)
	local token = SecretLibraryInvasionRunCurrentToken()
	if not token or not SecretLibraryInvasionRunOwnsWingBoss("brothers", creature) then
		return true
	end
	local ids = SecretLibraryInvasionRun.wingBossIds.brothers
	local otherId = creature:getId() == ids.chill and ids.freeze or ids.chill
	local other = Creature(otherId)
	if other and other:getHealth() > 0 and other:getHealth() < other:getMaxHealth() then
		other:addHealth(math.random(400, 800))
		other:getPosition():sendMagicEffect(CONST_ME_MAGIC_BLUE)
	end
	return true
end
brothersHealEachOther:register()

-- CORRECTION (section 25): each brother's own death independently flips its own current-wing-
-- generation flag (SecretLibraryInvasionRun.brothersAlive) rather than a live Game.getSpectators
-- re-scan - the exact same-tick-death race class already found and fixed this session in this quest's
-- own Lokathmor/Mazzinor precedent work and in A Pirate's Tail's Ratmiral encounter.
local brothersDeath = CreatureEvent("InvasionBrothersDeath")
function brothersDeath.onDeath(creature, corpse, lasthitkiller, mostdamagekiller)
	local token = SecretLibraryInvasionRunCurrentToken()
	if not token or not SecretLibraryInvasionRunOwnsWingBoss("brothers", creature) then
		return true
	end
	local ids = SecretLibraryInvasionRun.wingBossIds.brothers
	if creature:getId() == ids.chill then
		SecretLibraryInvasionRun.brothersAlive.chill = false
	elseif creature:getId() == ids.freeze then
		SecretLibraryInvasionRun.brothersAlive.freeze = false
	end
	if not SecretLibraryInvasionRun.brothersAlive.chill and not SecretLibraryInvasionRun.brothersAlive.freeze then
		InvasionWingBossDied(token, "brothers")
	end
	return true
end
brothersDeath:register()

-- The Devourer of Secrets: spawns book adds ("The Book of Secrets" / "Stolen Tome of Portals") owned
-- by the current wing generation. If a book dies, the CURRENT-RUN Devourer becomes stronger/less
-- vulnerable (a stacking damage reduction) - best strategy is ignoring the adds and focusing the boss.

local bookNames = {
	["the book of secrets"] = true,
	["stolen tome of portals"] = true,
}

local devourerBookDeath = CreatureEvent("InvasionBookDeath")
function devourerBookDeath.onDeath(creature, corpse, lasthitkiller, mostdamagekiller)
	local token = SecretLibraryInvasionRunCurrentToken()
	if not token or not bookNames[creature:getName():lower()] or not SecretLibraryInvasionRunOwnsWingAdd("devourer", creature) then
		return true
	end
	local boss = Creature(SecretLibraryInvasionRun.wingBossIds.devourer)
	if boss and SecretLibraryInvasionRunOwnsWingBoss("devourer", boss) then
		local stacks = boss:getStorageValue(1)
		if stacks < 0 then
			stacks = 0
		end
		boss:setStorageValue(1, math.min(stacks + 1, 5))
		boss:say("MY POWER GROWS!", TALKTYPE_MONSTER_SAY)
	end
	return true
end
devourerBookDeath:register()

-- Each surviving book adds 10% incoming-damage reduction, capped at 5 stacks (50%) -
-- CUSTOM_GLOBAL_LIKE_PENDING_EXACT_VALUE: the exact percentage/cap isn't given by the reference (only
-- "becomes stronger and less vulnerable"), a disclosed, moderate judgment call, unchanged from the
-- pre-existing value.
local devourerDamageGate = CreatureEvent("InvasionDevourerDamageGate")
function devourerDamageGate.onHealthChange(creature, attacker, primaryDamage, primaryType, secondaryDamage, secondaryType, origin)
	local token = SecretLibraryInvasionRunCurrentToken()
	if not token or not SecretLibraryInvasionRunOwnsWingBoss("devourer", creature) then
		return primaryDamage, primaryType, secondaryDamage, secondaryType
	end
	local stacks = creature:getStorageValue(1)
	if stacks and stacks > 0 then
		local reduction = math.min(stacks, 5) * 0.10
		primaryDamage = math.floor(primaryDamage * (1 - reduction))
		secondaryDamage = math.floor(secondaryDamage * (1 - reduction))
	end
	return primaryDamage, primaryType, secondaryDamage, secondaryType
end
devourerDamageGate:register()

local devourerDeath = CreatureEvent("InvasionDevourerDeath")
function devourerDeath.onDeath(creature, corpse, lasthitkiller, mostdamagekiller)
	local token = SecretLibraryInvasionRunCurrentToken()
	if token and SecretLibraryInvasionRunOwnsWingBoss("devourer", creature) then
		InvasionWingBossDied(token, "devourer")
	end
	return true
end
devourerDeath:register()
