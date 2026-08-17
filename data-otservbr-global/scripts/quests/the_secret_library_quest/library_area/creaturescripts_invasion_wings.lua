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

-- CORRECTION (final P1 surgical correction, section 1): PROVEN_REFERENCE - the Spellstealer's own
-- dedicated monster page lists "Summon Creature (4-5 Demon Slave)" among its abilities. The previous
-- pass only ever spawned Demon Slaves once, as a static ambient add at wing start
-- (movements_invasion_start.lua's WINGS[1].addSpawns) - this adds the boss's own active summon ability
-- during the fight, on top of (not replacing) that initial ambient add. Re-verifies exact current-run +
-- current-wing-generation ownership on every tick via SecretLibraryInvasionRunOwnsWingBoss - a stale
-- boss from a finished/reset run or an earlier wing generation cannot summon anything. Every summoned
-- slave is inserted into the SAME SecretLibraryInvasionRun.wingAddIds.spellstealer set the ambient add
-- already uses, so it is covered by the existing cleanup paths with no new code needed: InvasionWingBossDied
-- (movements_invasion_start.lua) removes every wingAddIds[key] entry on legitimate wing completion, and
-- SecretLibraryInvasionRunTerminate's non-success branch removes every wingAddIds entry on timeout/
-- technical_abort. Spawn positions are relative to the boss's OWN current position (not a fixed map
-- coordinate), so this works before wing room coordinates ever arrive and is not map work.
-- CUSTOM_GLOBAL_LIKE_PENDING_EXACT_CHANCE/_TIMING: no exact summon cooldown/chance is given by the
-- reference - reuses this file's own established periodic-chance idiom (spellstealerColorSwap.onThink).
-- CUSTOM_GLOBAL_LIKE_PENDING_EXACT_CAP: the simultaneous-population cap (10) is a disclosed, conservative
-- judgment call (2x one summon event's max size), not a reference-given number - bounds unbounded
-- stacking across repeated summon events without blocking the mechanic itself. Registered on all three
-- Spellstealer monster types (grey/green/red) since no evidence restricts the ability to one color
-- state - this does not alter setType/colorSwap/vortex logic in any way.
local spellstealerSummon = CreatureEvent("InvasionSpellstealerSummon")
function spellstealerSummon.onThink(creature, interval)
	local token = SecretLibraryInvasionRunCurrentToken()
	if not token or not SecretLibraryInvasionRunOwnsWingBoss("spellstealer", creature) then
		return true
	end
	if math.random(1, 100) > 3 then -- roughly every ~33 ticks on average, not every single tick
		return true
	end
	local addSet = SecretLibraryInvasionRun.wingAddIds.spellstealer
	if not addSet then
		return true
	end
	local alive = 0
	for creatureId in pairs(addSet) do
		local add = Creature(creatureId)
		if add and add:getName():lower() == "demon slave" then
			alive = alive + 1
		end
	end
	if alive >= 10 then
		return true
	end
	local position = creature:getPosition()
	for i = 1, math.random(4, 5) do
		local spawnPos = Position(position.x + math.random(-2, 2), position.y + math.random(-2, 2), position.z)
		local add = Game.createMonster("Demon Slave", spawnPos, true, true)
		if add then
			SecretLibraryInvasionRun.wingAddIds.spellstealer[add:getId()] = true
		end
	end
	return true
end
spellstealerSummon:register()

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
--
-- CORRECTION (final P1 surgical correction, section 2): component-wise fix. CreatureEvent::
-- executeHealthChange (src/lua/creature/creatureevent.cpp:465-474) takes abs() of BOTH returned values
-- independently, but decides whether to (re-)negate BOTH of them together based ONLY on the returned
-- primary.type - "if damage.primary.type != COMBAT_HEALING: negate both primary and secondary". The
-- previous version treated "primary OR secondary is fire" as one combined branch (heal from
-- primary+secondary, zero both) - on a mixed physical+fire hit this erased the physical component too,
-- converting real incoming damage into healing. Each component is now converted/zeroed independently:
-- only a FIRE component is folded into the manual addHealth() and its own return value zeroed; a non-fire
-- component's original value/type is returned untouched, so the single primary.type-driven negation
-- above reproduces its original sign exactly (abs() then re-negate is a no-op on an already-correctly-
-- signed value). A: physical-only -> untouched. B: fire-only -> heals. C/D: physical+fire in either slot
-- -> physical still damages, fire still heals. E: fire+fire -> both heal (single combined addHealth
-- call, no double-heal - each component contributes its own term to one sum, applied once). F:
-- foreign/stale Scion -> unaffected by the ownership guard, unchanged.
local scionHealFire = CreatureEvent("InvasionScionHealFire")
function scionHealFire.onHealthChange(creature, attacker, primaryDamage, primaryType, secondaryDamage, secondaryType, origin)
	local token = SecretLibraryInvasionRunCurrentToken()
	if not token or not SecretLibraryInvasionRunOwnsWingBoss("scionOfHavoc", creature) then
		return primaryDamage, primaryType, secondaryDamage, secondaryType
	end
	local outPrimary, outSecondary = primaryDamage, secondaryDamage
	local heal = 0
	if primaryType == COMBAT_FIREDAMAGE then
		heal = heal - (primaryDamage or 0)
		outPrimary = 0
	end
	if secondaryType == COMBAT_FIREDAMAGE then
		heal = heal - (secondaryDamage or 0)
		outSecondary = 0
	end
	if heal ~= 0 then
		creature:addHealth(heal)
	end
	return outPrimary, primaryType, outSecondary, secondaryType
end
scionHealFire:register()

-- Brother Chill & Brother Freeze: heal each other periodically, and are healed rather than damaged by
-- ice attacks (this engine clamps elemental resistance at 100% = 0 damage, so the "ice heals them"
-- part reuses the onHealthChange redirect technique this quest's own Mazzinor already used).

-- CORRECTION (final P1 surgical correction, section 2): identical component-wise fix as
-- InvasionScionHealFire above, for the identical mixed-component bug (see that handler's comment for the
-- full CreatureEvent::executeHealthChange sign-semantics evidence). A mixed physical+ice hit no longer
-- erases the physical component.
local brothersHealIce = CreatureEvent("InvasionBrothersHealIce")
function brothersHealIce.onHealthChange(creature, attacker, primaryDamage, primaryType, secondaryDamage, secondaryType, origin)
	local token = SecretLibraryInvasionRunCurrentToken()
	if not token or not SecretLibraryInvasionRunOwnsWingBoss("brothers", creature) then
		return primaryDamage, primaryType, secondaryDamage, secondaryType
	end
	local outPrimary, outSecondary = primaryDamage, secondaryDamage
	local heal = 0
	if primaryType == COMBAT_ICEDAMAGE then
		heal = heal - (primaryDamage or 0)
		outPrimary = 0
	end
	if secondaryType == COMBAT_ICEDAMAGE then
		heal = heal - (secondaryDamage or 0)
		outSecondary = 0
	end
	if heal ~= 0 then
		creature:addHealth(heal)
	end
	return outPrimary, primaryType, outSecondary, secondaryType
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
-- any survivor).
--
-- CORRECTION (final P1 surgical correction, section 3): PROVEN_REFERENCE - "para derrotá-los, você deve
-- mantê-los afastados um do outro" (to defeat them, you must keep them apart) explicitly frames distance
-- as part of the essential mechanic, not flavor text - a heal that fired regardless of distance made
-- "keeping them apart" mechanically meaningless. Each heal attempt now requires the healer and target to
-- be within HEAL_RADIUS (Position:getDistance - this engine's standard Chebyshev/square range metric,
-- confirmed via src/lua/functions/map/position_functions.cpp's luaPositionGetDistance, already used
-- elsewhere in this codebase - data-otservbr-global/lib/quests/soul_war.lua:1250).
-- CUSTOM_GLOBAL_LIKE_PENDING_EXACT_RADIUS: no exact radius is given anywhere in the reference (checked
-- this pass: main quest page and all three dedicated monster pages, Brother Chill/Freeze/Biting Cold) -
-- 5 sqm is a disclosed, conservative choice that makes separation mechanically meaningful (larger than
-- melee range, smaller than this file's own 10-sqm spectator-message radius) without being provably
-- Global-exact. Per the task's own instruction, this pending radius value does not block closure.
local HEAL_RADIUS = 5

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
	local selfPosition = creature:getPosition()
	local candidates = {}
	for _, id in ipairs(brothersHealPoolIds()) do
		if id ~= selfId then
			local other = Creature(id)
			if other and other:getHealth() > 0 and selfPosition:getDistance(other:getPosition()) <= HEAL_RADIUS then
				candidates[#candidates + 1] = id
			end
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
