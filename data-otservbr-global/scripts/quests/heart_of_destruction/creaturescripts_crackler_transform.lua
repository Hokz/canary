-- CONFIRMED BUG (found during the HOD repair audit): this file used to declare its
-- CreatureEvent registration object as "local cracklerTransform", which shadowed the shared
-- GLOBAL boolean of the exact same name (set in movements_vortex_crackler.lua/
-- actions_cracklers_lever.lua) for the rest of this file. Every reference to "cracklerTransform"
-- below then resolved to the local CreatureEvent table, never the shared boolean - a Lua table is
-- never "== true", so the transform branch was dead code, unreachable, always false. Cracklers
-- could never legitimately become Depolarized Cracklers, making the Rupture pre-mission
-- uncompletable. Renamed the local registration handle so it no longer collides with the shared
-- global state it needs to read.
local cracklerTransformEvent = CreatureEvent("CracklerTransform")
function cracklerTransformEvent.onThink(creature)
	if not creature or not creature:isMonster() then
		return true
	end

	if cracklerTransform == true then
		local monster = Game.createMonster("depolarized crackler", creature:getPosition(), false, true)
		if not monster then
			return true
		end
		monster:addHealth(-monster:getHealth() + creature:getHealth(), COMBAT_PHYSICALDAMAGE)
		creature:remove()
	end

	return true
end

cracklerTransformEvent:register()
