-- imbuementStorage values match the storage="..." attributes in data/XML/imbuements.xml's
-- "Powerful" (base 3) tier for each portal's imbuement group - these were never written by
-- any script, so no boss kill unlocked the imbuements the quest exists to unlock. Wiring them
-- here bridges the quest's own kill-storages to the already-defined imbuement gate.
local bosses = {
	-- bosses
	["lady tenebris"] = { storage = Storage.Quest.U11_02.ForgottenKnowledge.LadyTenebrisKilled, imbuementStorage = 50488 },
	["the enraged thorn knight"] = { storage = Storage.Quest.U11_02.ForgottenKnowledge.ThornKnightKilled, imbuementStorage = 50492 },
	["lloyd"] = { storage = Storage.Quest.U11_02.ForgottenKnowledge.LloydKilled, imbuementStorage = 50490 },
	["soul of dragonking zyrtarch"] = { storage = Storage.Quest.U11_02.ForgottenKnowledge.DragonkingKilled, imbuementStorage = 50494 },
	["melting frozen horror"] = { storage = Storage.Quest.U11_02.ForgottenKnowledge.HorrorKilled, imbuementStorage = 50496 },
	["the blazing time guardian"] = { storage = Storage.Quest.U11_02.ForgottenKnowledge.TimeGuardianKilled, imbuementStorage = 50498 },
	["the last lore keeper"] = { storage = Storage.Quest.U11_02.ForgottenKnowledge.LastLoreKilled, imbuementStorage = 50501 },
	-- IA interactions
	["an astral glyph"] = {},
}

local bossesForgottenKill = CreatureEvent("ForgottenKnowledgeBossDeath")

function bossesForgottenKill.onDeath(creature)
	local bossConfig = bosses[creature:getName():lower()]
	if not bossConfig then
		return true
	end

	onDeathForDamagingPlayers(creature, function(creature, player)
		if bossConfig.storage then
			if creature:getName():lower() == "the last lore keeper" then
				player:setStorageValue(bossConfig.storage, os.time() + (13 * 24 * 3600) + (20 * 3600))
			else
				player:setStorageValue(bossConfig.storage, os.time() + 20 * 3600)
			end
			if bossConfig.imbuementStorage then
				player:setStorageValue(bossConfig.imbuementStorage, 1)
			end
			-- Melting Frozen Horror is a plain Action, not a BossLever, so nothing else ever
			-- calls setBossCooldown for it - movements_challenger.lua's canFightBoss() check
			-- was a permanent no-op without this.
			if creature:getName():lower() == "melting frozen horror" then
				player:setBossCooldown("Melting Frozen Horror", os.time() + 20 * 3600)
			end
		elseif creature:getName():lower() == "the enraged thorn knight" then
			player:setStorageValue(Storage.Quest.U11_02.ForgottenKnowledge.PlantCounter, 0)
			player:setStorageValue(Storage.Quest.U11_02.ForgottenKnowledge.BirdCounter, 0)
		end
	end)

	if creature:getName():lower() == "melting frozen horror" then
		local egg = Tile(Position(32269, 31084, 14)):getTopCreature()
		if egg then
			local pos = egg:getPosition()
			egg:remove()
			Game.createMonster("baby dragon", pos, true, true)
		end
		local horror = Tile(Position(32267, 31071, 14)):getTopCreature()
		if horror then
			horror:remove()
		end
	end
	return true
end

bossesForgottenKill:register()
