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
	-- CORRECTION (final fidelity pass, section 7): exact PROVEN_REFERENCE message, replacing this
	-- pass's previous invented flavor text ("The Spellstealer channels %s energy!"). "creation" = green,
	-- "destruction" = red, per the reference's own vortex naming.
	local absorbMessage = color == "green" and "The spellstealer absorbs the power of creation!" or "The spellstealer absorbs the power of destruction!"
	for _, spectator in ipairs(Game.getSpectators(creature:getPosition(), false, true, 10, 10, 10, 10)) do
		spectator:sendTextMessage(MESSAGE_EVENT_ADVANCE, absorbMessage)
	end
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

-- CORRECTION (final functional closure pass, P1 section 3): PROVEN_REFERENCE - the Scion of Havoc's own
-- dedicated monster page states "-100% Cura-se quando atacado com Fogo" (heals when attacked with
-- Fire), confirming this is a genuine "fire heals it" mechanic (distinct from, and additional to, the
-- already-implemented Spawn-of-Havoc-explosion heal above). This engine clamps an elements-table percent
-- at 100% = 0 damage rather than converting it into a heal (same limitation already documented for the
-- Brothers' ice-heal mechanic), so this reuses that exact onHealthChange redirect technique instead of a
-- monster.lua elements value.
local scionHealFire = CreatureEvent("InvasionScionHealFire")
function scionHealFire.onHealthChange(creature, attacker, primaryDamage, primaryType, secondaryDamage, secondaryType, origin)
	local token = SecretLibraryInvasionRunCurrentToken()
	if not token or not SecretLibraryInvasionRunOwnsWingBoss("scionOfHavoc", creature) then
		return primaryDamage, primaryType, secondaryDamage, secondaryType
	end
	if primaryType == COMBAT_FIREDAMAGE or secondaryType == COMBAT_FIREDAMAGE then
		creature:addHealth(-(primaryDamage or 0) - (secondaryDamage or 0))
		return 0, primaryType, 0, secondaryType
	end
	return primaryDamage, primaryType, secondaryDamage, secondaryType
end
scionHealFire:register()

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

-- CORRECTION (final functional closure pass, P1 section 4): PROVEN_REFERENCE - "Os bosses e os Biting
-- Colds se curam" (the bosses AND the Biting Colds heal [each other]) - the mutual-heal mechanic
-- previously only covered the two bosses healing each other; Biting Cold adds now participate in the
-- same pool (registered on all three monster types: brother_chill.lua, brother_freeze.lua,
-- biting_cold.lua). Ownership-gated for boss OR add via the existing
-- SecretLibraryInvasionRunOwnsWingBoss/OwnsWingAdd helpers, current-run-only, bounded to the current
-- wing generation's own pool - a stale/foreign same-name creature from a different run or a Biting Cold
-- from an earlier wing generation can neither heal nor be healed. Stops naturally when the wing ends
-- (InvasionWingBossDied removes every wingAddIds[key] entry and the run's ownership checks then fail for
-- any survivor). Exact proximity-gating ("mantê-los afastados um do outro") is not reproduced here -
-- CUSTOM_GLOBAL_LIKE_PENDING_EXACT_TIMING/VALUE, a disclosed non-blocking simplification, not a P0/P1
-- functional gap (the mutual-heal mechanic itself - the required behavior - is fully present).
local function brothersHealPoolIds()
	local pool = {}
	local ids = SecretLibraryInvasionRun.wingBossIds.brothers
	if ids then
		if SecretLibraryInvasionRun.brothersAlive.chill then
			pool[#pool + 1] = ids.chill
		end
		if SecretLibraryInvasionRun.brothersAlive.freeze then
			pool[#pool + 1] = ids.freeze
		end
	end
	for addId in pairs(SecretLibraryInvasionRun.wingAddIds.brothers or {}) do
		pool[#pool + 1] = addId
	end
	return pool
end

local brothersHealEachOther = CreatureEvent("InvasionBrothersHealEachOther")
function brothersHealEachOther.onThink(creature, interval)
	local token = SecretLibraryInvasionRunCurrentToken()
	if not token then
		return true
	end
	local isBoss = SecretLibraryInvasionRunOwnsWingBoss("brothers", creature)
	local isAdd = not isBoss and SecretLibraryInvasionRunOwnsWingAdd("brothers", creature)
	if not isBoss and not isAdd then
		return true
	end
	local selfId = creature:getId()
	local candidates = {}
	for _, id in ipairs(brothersHealPoolIds()) do
		if id ~= selfId then
			candidates[#candidates + 1] = id
		end
	end
	if #candidates == 0 then
		return true
	end
	local other = Creature(candidates[math.random(#candidates)])
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

-- The Devourer of Secrets: spawns exactly 4 "The Book of Secrets" adds (PROVEN_REFERENCE count) owned
-- by the current wing generation. If a book dies, the CURRENT-RUN Devourer becomes stronger/less
-- vulnerable (a stacking damage reduction) - best strategy is ignoring the adds and focusing the boss.
--
-- CORRECTION (completion mechanics pass, section 8/18): "Stolen Tome of Portals" removed from this
-- table - no reference fetched across this whole engagement ever placed it in the Devourer wing (it is
-- exclusively a Gorzindel-encounter entity, WINGS[4].addSpawns no longer lists it either). The
-- SecretLibraryInvasionRunOwnsWingAdd("devourer", creature) check below already made a stray Gorzindel
-- Stolen Tome harmless even before this cleanup (it could never be owned as a "devourer" wing add), but
-- leaving it declared here was misleading/stale.
local bookNames = {
	["the book of secrets"] = true,
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
		-- CORRECTION (section 8): capped at 4, matching the PROVEN_REFERENCE exact book count (there are
		-- only ever 4 Books of Secrets to destroy - a 5-stack cap was structurally inconsistent).
		boss:setStorageValue(1, math.min(stacks + 1, 4))
		boss:say("MY POWER GROWS!", TALKTYPE_MONSTER_SAY)
	end
	return true
end
devourerBookDeath:register()

-- Each surviving book adds 10% incoming-damage reduction, capped at 4 stacks (40%) -
-- CUSTOM_GLOBAL_LIKE_PENDING_EXACT_VALUE: the exact percentage isn't given by the reference (only
-- "becomes stronger and less vulnerable"), a disclosed, moderate judgment call. The cap was corrected
-- this pass from 5 to 4 (completion mechanics pass, section 8) - matching the PROVEN_REFERENCE exact
-- book count; a 5-stack cap was structurally inconsistent with there only ever being 4 books.
local devourerDamageGate = CreatureEvent("InvasionDevourerDamageGate")
function devourerDamageGate.onHealthChange(creature, attacker, primaryDamage, primaryType, secondaryDamage, secondaryType, origin)
	local token = SecretLibraryInvasionRunCurrentToken()
	if not token or not SecretLibraryInvasionRunOwnsWingBoss("devourer", creature) then
		return primaryDamage, primaryType, secondaryDamage, secondaryType
	end
	local stacks = creature:getStorageValue(1)
	if stacks and stacks > 0 then
		local reduction = math.min(stacks, 4) * 0.10
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
