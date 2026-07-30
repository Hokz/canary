-- "Higher minions of destruction" for the destructive-charges system (see movements_teleport_heart.lua
-- worldDevourerEnter and 05_HOD_BOSS_MECHANICS_CONTRACT.md): Frenzy, Charged Disruption, and Overcharged
-- Disruption. This is an inferred classification, not exact wiki text — reasoning: these are the escalated/
-- empowered forms that appear during the final battle and World Devourer fight (as opposed to the base
-- "Disruption" or common "Spark of Destruction" spawns), and they die via normal combat (unlike Greed,
-- which is despawned via the vortex mechanic and never actually "killed").
local function grantDestructiveCharge(killer, mostDamageKiller)
	local player = mostDamageKiller and mostDamageKiller:getPlayer() or (killer and killer:getPlayer())
	if not player then
		return
	end
	local charges = math.min(math.max(player:getStorageValue(Storage.Quest.U10_94.HeartOfDestruction.DestructiveCharges), 0) + 1, 5)
	player:setStorageValue(Storage.Quest.U10_94.HeartOfDestruction.DestructiveCharges, charges)
end

local heartMinionDeath = CreatureEvent("HeartMinionDeath")
function heartMinionDeath.onDeath(creature, corpse, killer, mostDamageKiller, unjustified, mostDamageUnjustified)
	if not creature or not creature:isMonster() then -- éMonstro!
		return true
	end
	local monster = creature:getName():lower()
	if monster == "frenzy" then
		rageSummon = rageSummon - 1
		devourerSummon = devourerSummon - 1
		grantDestructiveCharge(killer, mostDamageKiller)
	elseif monster == "damage resonance" then
		Game.setStorageValue(GlobalStorage.HeartOfDestruction.RuptureResonanceActive, 0)
	elseif monster == "disruption" then
		destructionSummon = destructionSummon - 1
		devourerSummon = devourerSummon - 1
	elseif monster == "charged disruption" or monster == "overcharged disruption" then
		destructionSummon = destructionSummon - 1
		devourerSummon = devourerSummon - 1
		grantDestructiveCharge(killer, mostDamageKiller)
	elseif monster == "the hunger" then
		devourerBossesKilled = devourerBossesKilled + 1
		theHungerKilled = true
	elseif monster == "the destruction" then
		devourerBossesKilled = devourerBossesKilled + 1
		theDestructionKilled = true
	elseif monster == "the rage" then
		devourerBossesKilled = devourerBossesKilled + 1
		theRageKilled = true
	end
	return true
end

heartMinionDeath:register()
