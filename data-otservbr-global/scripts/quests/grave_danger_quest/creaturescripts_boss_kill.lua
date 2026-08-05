local config = {
	["gaffir"] = {
		stor = Storage.Quest.U12_20.GraveDanger.GaffirKilled,
	},
	["custodian"] = {
		stor = Storage.Quest.U12_20.GraveDanger.CustodianKilled,
	},
	["guard captain quaid"] = {
		stor = Storage.Quest.U12_20.GraveDanger.QuaidKilled,
	},
	["scarlett etzel"] = {
		stor = Storage.Quest.U12_20.GraveDanger.ScarlettKilled,
	},
	["earl osam"] = {
		stor = Storage.Quest.U12_20.GraveDanger.Bosses.EarlOsam.Killed,
		extra = {
			stor = Storage.Quest.U12_20.GraveDanger.Graves.Cormaya,
			value = 1,
		},
	},
	["count vlarkorth"] = {
		stor = Storage.Quest.U12_20.GraveDanger.Bosses.CountVlarkorth.Killed,
		extra = {
			stor = Storage.Quest.U12_20.GraveDanger.Graves.Edron,
			value = 1,
		},
	},
	["sir baeloc"] = {
		stor = Storage.Quest.U12_20.GraveDanger.Bosses.BaelocNictros.Killed,
		extra = {
			stor = Storage.Quest.U12_20.GraveDanger.Graves.Darashia,
			value = 1,
		},
	},
	["duke krule"] = {
		stor = Storage.Quest.U12_20.GraveDanger.Bosses.DukeKrule.Killed,
		extra = {
			stor = Storage.Quest.U12_20.GraveDanger.Graves.Thais,
			value = 1,
		},
	},
	["lord azaram"] = {
		stor = Storage.Quest.U12_20.GraveDanger.Bosses.LordAzaram.Killed,
		extra = {
			stor = Storage.Quest.U12_20.GraveDanger.Graves.Ghostlands,
			value = 1,
		},
	},
	["king zelos"] = {
		stor = Storage.Quest.U12_20.GraveDanger.Bosses.KingZelos.Killed,
	},
}

local grave_danger_death = CreatureEvent("grave_danger_death")

function grave_danger_death.onDeath(creature, corpse, killer, mostDamageKiller)
	local bossConfig = config[creature:getName():lower()]

	if not bossConfig then
		return true
	end

	local attackers = creature:getDamageMap()
	for attackerId, _ in pairs(attackers) do
		local player = Player(attackerId)
		if player and player:getStorageValue(bossConfig.stor) < 1 then
			player:setStorageValue(bossConfig.stor, 1)

			if creature:getName():lower() == "scarlett etzel" then
				if not player:hasAchievement("A Study in Scarlett") then
					player:addAchievement("A Study in Scarlett")
				end
				-- CONFIRMED BUG (pre-existing): Storage...GraveDanger.Cobra backs the "The Order of the
				-- Cobra" questlog mission (catalog/047_grave_danger.lua) but was never written by any
				-- script in the repo, so that entire questlog line could never appear. Scarlett's death
				-- is the completion trigger for the Cobra line, so it is set here.
				player:setStorageValue(Storage.Quest.U12_20.GraveDanger.Cobra, 1)
			end

			if bossConfig.extra then
				player:setStorageValue(bossConfig.extra.stor, bossConfig.extra.value)
				-- CONFIRMED BLOCKER (pre-existing): unset storage reads -1, so twelve increments only
				-- reached 11 and Jack Springer's ">= 12" gate never opened. See the matching comment in
				-- actions_grave_sanctify.lua.
				local graves = math.max(player:getStorageValue(Storage.Quest.U12_20.GraveDanger.Graves.Progress), 0)
				player:setStorageValue(Storage.Quest.U12_20.GraveDanger.Graves.Progress, graves + 1)
			end
		end
	end

	return true
end

grave_danger_death:register()
