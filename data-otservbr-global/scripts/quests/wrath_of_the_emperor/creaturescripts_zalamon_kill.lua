local bossForms = {
	["snake god essence"] = {
		text = "IT'S NOT THAT EASY MORTALS! FEEL THE POWER OF THE GOD!",
		newForm = "snake thing",
	},
	["snake thing"] = {
		text = "NOOO! NOW YOU HERETICS WILL FACE MY GODLY WRATH!",
		newForm = "lizard abomination",
	},
	["lizard abomination"] = {
		text = "YOU ... WILL ... PAY WITH ETERNITY ... OF AGONY!",
		newForm = "mutated zalamon",
	},
}

local zalamonKill = CreatureEvent("ZalamonDeath")
function zalamonKill.onDeath(creature)
	if creature:getName():lower() == "mutated zalamon" then
		Game.setStorageValue(Storage.Quest.U8_6.WrathOfTheEmperor.Mission11, -1)
		return true
	end

	local name = creature:getName():lower()
	local bossConfig = bossForms[name]
	if not bossConfig then
		return true
	end

	local found = false
	for k, v in ipairs(Game.getSpectators(creature:getPosition())) do
		if v:getName():lower() == bossConfig.newForm then
			found = true
			break
		end
	end

	if found then
		return true
	end

	-- CONFIRMED BUG (found during the WOTE reconciliation audit): a failed Game.createMonster used
	-- to just skip the taunt line and silently drop the rest of the mandatory Snake God Essence ->
	-- Snake Thing -> Lizard Abomination -> Mutated Zalamon chain, leaving nothing left to fight and
	-- no way for the run to ever complete. Routed through the shared Mission11 helper
	-- (lib/quests/wote_mission11.lua) so a hard failure aborts and releases the run instead of
	-- silently stalling it.
	local runToken = Game.getStorageValue(Storage.Quest.U8_6.WrathOfTheEmperor.Mission11)
	WoteMission11.spawnNextForm(name, bossConfig.newForm, creature:getPosition(), runToken, bossConfig.text)
	return true
end

zalamonKill:register()
