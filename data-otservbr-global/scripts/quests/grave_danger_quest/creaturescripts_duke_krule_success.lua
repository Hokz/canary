-- Releases DukeKruleRun (actions_duke_krule.lua) on a legitimate kill: clears every participant's
-- elemental transform and stops the reassignment/blast/timeout events. Duke Krule's own grave/boss
-- credit is unaffected - handled separately by the pre-existing generic creaturescripts_boss_kill.lua
-- path (duke krule -> Graves.Thais).
local duke_krule_success = CreatureEvent("duke_krule_success")

function duke_krule_success.onDeath(creature)
	local targetMonster = creature:getMonster()
	if not targetMonster or targetMonster:getMaster() then
		return true
	end

	local token = DukeKruleRunCurrentToken()
	if token then
		DukeKruleRunTerminate(token, "success", "Duke Krule defeated")
	end

	return true
end

duke_krule_success:register()
