-- Secret Library final invasion ("Scourge of Oblivion") - the 4 wing-boss mechanics.
--
-- Previously these 5 monsters (The Spellstealer, The Scion of Havoc, Brother Chill, Brother Freeze,
-- The Devourer of Secrets) existed only as plain, unreferenced stat blocks with zero mechanic
-- scripts and zero spawn wiring anywhere in the repo - this file (plus movements_invasion_start.lua
-- for the room/wave orchestration) is what actually implements the reference's described mechanics.
local Invasion = Storage.Quest.U11_80.TheSecretLibrary.SecretLibraryInvasion

-- The Spellstealer: starts grey (vulnerable, the base monster file). Periodically swaps into an
-- immune GREEN or RED colored form; luring it onto the matching-colored teleport (set up in
-- movements_invasion_start.lua) swaps it back to grey/vulnerable, preserving current HP - matching
-- "during the fight changes into one of two colored forms... lure/stand boss on [matching] teleport".

local spellstealerColorSwap = CreatureEvent("InvasionSpellstealerColorSwap")
function spellstealerColorSwap.onThink(creature, interval)
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
	if Game.getStorageValue(Invasion.SpellstealerDefeated) < 1 then
		Game.setStorageValue(Invasion.SpellstealerDefeated, 1)
		InvasionCheckWingsCleared()
	end
	return true
end
spellstealerDeath:register()

-- The Scion of Havoc: spawns "Spawn of Havoc" adds. Killing one explodes it (3000+ AoE damage) and
-- heals the boss - players are meant to avoid/ignore them, not required to kill anything but the
-- boss itself.

local scionAddDeath = CreatureEvent("InvasionSpawnOfHavocDeath")
function scionAddDeath.onDeath(creature, corpse, lasthitkiller, mostdamagekiller)
	local position = creature:getPosition()
	position:sendMagicEffect(CONST_ME_EXPLOSIONAREA)
	for _, spectator in ipairs(Game.getSpectators(position, false, true, 3, 3, 3, 3)) do
		spectator:addHealth(-math.random(3000, 4000))
	end
	for _, spectator in ipairs(Game.getSpectators(position, false, false, 8, 8, 8, 8)) do
		if spectator:isMonster() and spectator:getName():lower() == "the scion of havoc" then
			spectator:addHealth(math.random(2000, 4000))
			break
		end
	end
	return true
end
scionAddDeath:register()

local scionOfHavocDeath = CreatureEvent("InvasionScionOfHavocDeath")
function scionOfHavocDeath.onDeath(creature, corpse, lasthitkiller, mostdamagekiller)
	if Game.getStorageValue(Invasion.ScionOfHavocDefeated) < 1 then
		Game.setStorageValue(Invasion.ScionOfHavocDefeated, 1)
		InvasionCheckWingsCleared()
	end
	return true
end
scionOfHavocDeath:register()

-- Brother Chill & Brother Freeze: heal each other periodically, and are healed rather than damaged
-- by ice attacks. monster.elements can't produce healing (this engine clamps elemental resistance
-- at 100% = 0 damage, confirmed via src/creatures/monsters/monster.cpp - it never goes negative), so
-- the ice-heals-them part reuses the exact onHealthChange redirect technique this quest's own
-- Mazzinor already uses (creaturescripts_mazzinor.lua's mazzinorHealth).

local brothersHealIce = CreatureEvent("InvasionBrothersHealIce")
function brothersHealIce.onHealthChange(creature, attacker, primaryDamage, primaryType, secondaryDamage, secondaryType, origin)
	if primaryType == COMBAT_ICEDAMAGE or secondaryType == COMBAT_ICEDAMAGE then
		creature:addHealth(-(primaryDamage or 0) - (secondaryDamage or 0))
		return 0, primaryType, 0, secondaryType
	end
	return primaryDamage, primaryType, secondaryDamage, secondaryType
end
brothersHealIce:register()

local brothersHealEachOther = CreatureEvent("InvasionBrothersHealEachOther")
function brothersHealEachOther.onThink(creature, interval)
	local name = creature:getName():lower()
	if name ~= "brother chill" and name ~= "brother freeze" then
		return true
	end
	local otherName = name == "brother chill" and "brother freeze" or "brother chill"
	for _, spectator in ipairs(Game.getSpectators(creature:getPosition(), false, false, 10, 10, 10, 10)) do
		if spectator:isMonster() and spectator:getName():lower() == otherName then
			if spectator:getHealth() < spectator:getMaxHealth() then
				spectator:addHealth(math.random(400, 800))
				spectator:getPosition():sendMagicEffect(CONST_ME_MAGIC_BLUE)
			end
			break
		end
	end
	return true
end
brothersHealEachOther:register()

-- REVIEW FIX: a live Game.getSpectators re-scan for "is the other brother still alive" has a real
-- race if both die in the same combat tick (e.g. one AoE hit killing both) - the engine may not have
-- fully removed the first one from the world by the time the second's onDeath call re-scans, so
-- both calls could see the other as "still alive" and BrothersDefeated would never be set, softlocking
-- this wing (and therefore the whole invasion, since all 4 wings are required). This is the exact bug
-- class already found and fixed this session in A Pirate's Tail's Ratmiral encounter - same fix: a
-- storage counter written synchronously in each call, which has no such race.
local brothersDeath = CreatureEvent("InvasionBrothersDeath")
function brothersDeath.onDeath(creature, corpse, lasthitkiller, mostdamagekiller)
	local deaths = Game.getStorageValue(Invasion.BrothersDeathCount) + 1
	Game.setStorageValue(Invasion.BrothersDeathCount, deaths)
	if deaths < 2 then
		return true -- wait for the second brother
	end
	if Game.getStorageValue(Invasion.BrothersDefeated) < 1 then
		Game.setStorageValue(Invasion.BrothersDefeated, 1)
		InvasionCheckWingsCleared()
	end
	return true
end
brothersDeath:register()

-- The Devourer of Secrets: spawns book adds ("The Book of Secrets" / "Stolen Tome of Portals"). If a
-- book dies, the Devourer becomes stronger and less vulnerable (a stacking damage reduction here) -
-- best strategy is ignoring the adds and focusing the boss, matching the reference exactly.

local bookNames = {
	["the book of secrets"] = true,
	["stolen tome of portals"] = true,
}

local devourerBookDeath = CreatureEvent("InvasionBookDeath")
function devourerBookDeath.onDeath(creature, corpse, lasthitkiller, mostdamagekiller)
	if not bookNames[creature:getName():lower()] then
		return true
	end
	for _, spectator in ipairs(Game.getSpectators(creature:getPosition(), false, false, 10, 10, 10, 10)) do
		if spectator:isMonster() and spectator:getName():lower() == "the devourer of secrets" then
			local stacks = spectator:getStorageValue(1) -- monster-local storage, not a player/Game id
			if stacks < 0 then
				stacks = 0
			end
			spectator:setStorageValue(1, math.min(stacks + 1, 5))
			spectator:say("MY POWER GROWS!", TALKTYPE_MONSTER_SAY)
			break
		end
	end
	return true
end
devourerBookDeath:register()

-- Each surviving book adds 10% incoming-damage reduction, capped at 5 stacks (50%) - the exact
-- percentage/cap isn't given by the reference (only "becomes stronger and less vulnerable"), a
-- disclosed, moderate judgment call.
local devourerDamageGate = CreatureEvent("InvasionDevourerDamageGate")
function devourerDamageGate.onHealthChange(creature, attacker, primaryDamage, primaryType, secondaryDamage, secondaryType, origin)
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
	if Game.getStorageValue(Invasion.DevourerDefeated) < 1 then
		Game.setStorageValue(Invasion.DevourerDefeated, 1)
		InvasionCheckWingsCleared()
	end
	return true
end
devourerDeath:register()
