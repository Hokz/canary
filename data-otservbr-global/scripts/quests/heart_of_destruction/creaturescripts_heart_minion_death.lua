-- PROJECT_ARCHITECTURE_DECISION (HOD repair audit): destructive charges are sourced from the 5
-- master bosses only (Anomaly/Rupture/Realityquake/Eradicator/Outburst — see
-- creaturescripts_heart_boss_death.lua), not from any final-battle minion. The previous
-- grantDestructiveCharge() calls on Frenzy/Charged Disruption/Overcharged Disruption death were
-- removed from here per the owner reference correction; the function itself moved to
-- creaturescripts_heart_boss_death.lua, the new single source of charge grants.

-- The Hunger/Destruction/Rage rotate through 3 rooms via changeArea() (actions_final_lever.lua):
-- every 30 seconds players are moved Hunger->Rage->Destruction->Hunger, and whichever of these
-- three is currently marked killed gets a fresh copy respawned in its room for the newly-rotated-in
-- team. A boss can therefore die and respawn several times before all three are simultaneously
-- dead (devourerBossesKilled reaching 3) and the fight moves on to World Devourer.
--
-- CORRECTION (executor contract, section C): the previous per-death "clean this room 60 seconds
-- later if it's still marked dead" callback used a bare boolean guard (isStillDead), which is
-- generation-blind: boss generation A dying schedules the cleanup; generation B can then respawn
-- (for a rotated-in team) and itself die before the 60s elapse; A's stale callback fires, sees the
-- shared killed flag true again (now meaning B, not A), and wipes B's legitimate room. Removed
-- entirely per the preferred fix - the single run-owned miniboss-phase timeout
-- (areaDevourerMinibossTimeout, 45 minutes, terminates the whole run through
-- HODFinalRunTerminate - see actions_final_lever.lua) remains the safety net for a room abandoned
-- for good; the owner reference does not require a 60-second cleanup on top of that.
--
-- CORRECTION (executor contract, section F): every mutation below that touches final-run state now
-- only fires for a monster this run actually owns (HODFinalRunOwnsMonster, from
-- actions_final_lever.lua) - a stale monster from an aborted or already-finished run can no longer
-- corrupt a newer run's counters. This now covers Frenzy/Disruption/Charged Disruption/Overcharged
-- Disruption (rageSummon/destructionSummon/devourerSummon) as well as The Hunger/Destruction/Rage,
-- since all of these are registered to the active run at creation (rage_summon.lua,
-- destruction_summon.lua, the Disruption escalation transforms). "Damage Resonance" is
-- deliberately NOT gated - it belongs to the unrelated Rupture master-boss encounter, not the
-- final run.
local heartMinionDeath = CreatureEvent("HeartMinionDeath")
function heartMinionDeath.onDeath(creature, corpse, killer, mostDamageKiller, unjustified, mostDamageUnjustified)
	if not creature or not creature:isMonster() then -- éMonstro!
		return true
	end
	local monster = creature:getName():lower()
	if monster == "frenzy" then
		if HODFinalRunOwnsMonster(creature) then
			rageSummon = rageSummon - 1
			devourerSummon = devourerSummon - 1
		end
	elseif monster == "damage resonance" then
		Game.setStorageValue(GlobalStorage.HeartOfDestruction.RuptureResonanceActive, 0)
	elseif monster == "disruption" then
		if HODFinalRunOwnsMonster(creature) then
			destructionSummon = destructionSummon - 1
			devourerSummon = devourerSummon - 1
		end
	elseif monster == "charged disruption" or monster == "overcharged disruption" then
		if HODFinalRunOwnsMonster(creature) then
			destructionSummon = destructionSummon - 1
			devourerSummon = devourerSummon - 1
		end
	elseif monster == "the hunger" then
		if HODFinalRunOwnsMonster(creature) then
			devourerBossesKilled = devourerBossesKilled + 1
			theHungerKilled = true
		end
	elseif monster == "the destruction" then
		if HODFinalRunOwnsMonster(creature) then
			devourerBossesKilled = devourerBossesKilled + 1
			theDestructionKilled = true
		end
	elseif monster == "the rage" then
		if HODFinalRunOwnsMonster(creature) then
			devourerBossesKilled = devourerBossesKilled + 1
			theRageKilled = true
		end
	end
	return true
end

heartMinionDeath:register()
