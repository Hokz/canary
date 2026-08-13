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
		cobraFinalBoss = true,
	},
	["earl osam"] = {
		stor = Storage.Quest.U12_20.GraveDanger.Bosses.EarlOsam.Killed,
		lichLine = true,
		extra = {
			stor = Storage.Quest.U12_20.GraveDanger.Graves.Cormaya,
			value = 1,
		},
	},
	["count vlarkorth"] = {
		stor = Storage.Quest.U12_20.GraveDanger.Bosses.CountVlarkorth.Killed,
		lichLine = true,
		extra = {
			stor = Storage.Quest.U12_20.GraveDanger.Graves.Edron,
			value = 1,
		},
	},
	["sir baeloc"] = {
		stor = Storage.Quest.U12_20.GraveDanger.Bosses.BaelocNictros.Killed,
		lichLine = true,
		extra = {
			stor = Storage.Quest.U12_20.GraveDanger.Graves.Darashia,
			value = 1,
		},
	},
	["duke krule"] = {
		stor = Storage.Quest.U12_20.GraveDanger.Bosses.DukeKrule.Killed,
		lichLine = true,
		extra = {
			stor = Storage.Quest.U12_20.GraveDanger.Graves.Thais,
			value = 1,
		},
	},
	["lord azaram"] = {
		stor = Storage.Quest.U12_20.GraveDanger.Bosses.LordAzaram.Killed,
		lichLine = true,
		extra = {
			stor = Storage.Quest.U12_20.GraveDanger.Graves.Ghostlands,
			value = 1,
		},
	},
	-- King Zelos is deliberately absent from this table (executor contract, section 24): credit for
	-- him must belong only to the current King Zelos run's participants who are still physically
	-- present at the legitimate kill, not to every entry in a generic damage map. That check needs
	-- the run/token state built in creaturescripts_king_zelos.lua, so his completion storage is
	-- granted there instead of through this generic handler.
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
		-- CORRECTION (executor contract, section 4): a damage-map entry alone is not a legitimate
		-- Lich-line participant. Require level >= 250, Premium, and the Lich line actually started
		-- before granting any Lich-line boss/grave credit, so a low-level or non-quest bystander who
		-- merely tags a boss with damage cannot earn progress. Cobra-line entries (gaffir/custodian/
		-- quaid/scarlett) are unaffected - out of this section's scope.
		local eligible = player ~= nil
		if eligible and bossConfig.lichLine then
			eligible = player:getLevel() >= 250 and player:isPremium() and player:getStorageValue(Storage.Quest.U12_20.GraveDanger.Questline) >= 1
		end
		-- CORRECTION (executor contract, section 34): Scarlett's completion/achievement/Cobra-line
		-- credit belongs only to the current attempt's own participants - a bystander who tags her
		-- with damage from outside the legitimate encounter roster earns nothing.
		if eligible and bossConfig.cobraFinalBoss then
			eligible = ScarlettRunIsParticipant(ScarlettRunCurrentToken(), attackerId)
		end
		if eligible and player:getStorageValue(bossConfig.stor) < 1 then
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

	if bossConfig.cobraFinalBoss then
		local token = ScarlettRunCurrentToken()
		if token then
			ScarlettRunTerminate(token, "success", "Scarlett Etzel defeated")
		end
	end

	return true
end

grave_danger_death:register()
