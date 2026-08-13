local config = {
	["gaffir"] = {
		stor = Storage.Quest.U12_20.GraveDanger.GaffirKilled,
	},
	["custodian"] = {
		stor = Storage.Quest.U12_20.GraveDanger.CustodianKilled,
		-- CORRECTION (correction pass section L): every eligible attacker on a legitimate Custodian
		-- kill mints a fresh FireWall pass, independent of whether CustodianKilled (permanent) was
		-- already set - see movements_cobra_mini_bosses.lua for the consuming side.
		mintsFireWall = true,
	},
	["guard captain quaid"] = {
		stor = Storage.Quest.U12_20.GraveDanger.QuaidKilled,
	},
	["scarlett etzel"] = {
		stor = Storage.Quest.U12_20.GraveDanger.ScarlettKilled,
		cobraFinalBoss = true,
	},
	-- CORRECTION (correction pass section B): each Lich boss entry now also carries the exact
	-- run-ownership/participant/room-presence checks needed to require actual current-run membership
	-- and physical presence at the moment of death, not merely a damage-map entry. tokenFn/ownsBossFn/
	-- isParticipantFn are the NAMES (not direct references) of the global functions defined in each
	-- boss's own actions_*.lua run object, resolved via _G[...] only when onDeath actually runs -
	-- storing a direct function reference in this table would freeze whatever that global happened to
	-- resolve to at THIS file's own load time, which is not guaranteed to be after every actions_*.lua
	-- file in this quest has already run and defined its globals. room mirrors that boss's own lever
	-- specPos bounds.
	["earl osam"] = {
		stor = Storage.Quest.U12_20.GraveDanger.Bosses.EarlOsam.Killed,
		lichLine = true,
		extra = {
			stor = Storage.Quest.U12_20.GraveDanger.Graves.Cormaya,
			value = 1,
		},
		tokenFn = "EarlOsamRunCurrentToken",
		ownsBossFn = "EarlOsamRunOwnsBoss",
		isParticipantFn = "EarlOsamRunIsParticipant",
		room = { from = Position(33479, 31429, 13), to = Position(33497, 31446, 13) },
	},
	["count vlarkorth"] = {
		stor = Storage.Quest.U12_20.GraveDanger.Bosses.CountVlarkorth.Killed,
		lichLine = true,
		extra = {
			stor = Storage.Quest.U12_20.GraveDanger.Graves.Edron,
			value = 1,
		},
		tokenFn = "VlarkorthRunCurrentToken",
		ownsBossFn = "VlarkorthRunOwnsBoss",
		isParticipantFn = "VlarkorthRunIsParticipant",
		room = { from = Position(33448, 31428, 13), to = Position(33464, 31446, 13) },
	},
	["sir baeloc"] = {
		stor = Storage.Quest.U12_20.GraveDanger.Bosses.BaelocNictros.Killed,
		lichLine = true,
		extra = {
			stor = Storage.Quest.U12_20.GraveDanger.Graves.Darashia,
			value = 1,
		},
		tokenFn = "NictrosBaelocRunCurrentToken",
		ownsBossFn = "NictrosBaelocRunOwnsBaeloc",
		isParticipantFn = "NictrosBaelocRunIsParticipant",
		room = { from = Position(33414, 31426, 13), to = Position(33433, 31449, 13) },
	},
	["duke krule"] = {
		stor = Storage.Quest.U12_20.GraveDanger.Bosses.DukeKrule.Killed,
		lichLine = true,
		extra = {
			stor = Storage.Quest.U12_20.GraveDanger.Graves.Thais,
			value = 1,
		},
		tokenFn = "DukeKruleRunCurrentToken",
		ownsBossFn = "DukeKruleRunOwnsBoss",
		isParticipantFn = "DukeKruleRunIsParticipant",
		room = { from = Position(33447, 31464, 13), to = Position(33464, 31481, 13) },
	},
	["lord azaram"] = {
		stor = Storage.Quest.U12_20.GraveDanger.Bosses.LordAzaram.Killed,
		lichLine = true,
		extra = {
			stor = Storage.Quest.U12_20.GraveDanger.Graves.Ghostlands,
			value = 1,
		},
		tokenFn = "AzaramRunCurrentToken",
		ownsBossFn = "AzaramRunOwnsBoss",
		isParticipantFn = "AzaramRunIsParticipant",
		room = { from = Position(33416, 31463, 13), to = Position(33432, 31481, 13) },
	},
	-- King Zelos is deliberately absent from this table (executor contract, section 24): credit for
	-- him must belong only to the current King Zelos run's participants who are still physically
	-- present at the legitimate kill, not to every entry in a generic damage map. That check needs
	-- the run/token state built in creaturescripts_king_zelos.lua, so his completion storage is
	-- granted there instead of through this generic handler.
}

local function isInsideRoom(player, room)
	if not room then
		return true
	end
	local pos = player:getPosition()
	return pos.x >= room.from.x and pos.x <= room.to.x and pos.y >= room.from.y and pos.y <= room.to.y and pos.z == room.from.z
end

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
			-- CORRECTION (correction pass section B): the boss itself must be the exact instance the
			-- current run owns, the attacker must be a legitimate roster participant of that same run,
			-- and they must still be physically present in the legitimate encounter room at the moment
			-- of death - a damage-map entry from someone who tagged the boss and then left (or was
			-- never on the roster at all) earns nothing.
			if eligible and bossConfig.ownsBossFn then
				local tokenFn, ownsBossFn, isParticipantFn = _G[bossConfig.tokenFn], _G[bossConfig.ownsBossFn], _G[bossConfig.isParticipantFn]
				local token = tokenFn()
				eligible = ownsBossFn(creature) and isParticipantFn(token, attackerId) and isInsideRoom(player, bossConfig.room)
			end
		end
		-- CORRECTION (executor contract, section 34; correction pass section M3): Scarlett's
		-- completion/achievement/Cobra-line credit belongs only to the current attempt's own
		-- participants, present at the death of the exact boss instance that attempt owns - a
		-- bystander who tags her with damage from outside the legitimate encounter roster, or a stale/
		-- unrelated Scarlett Etzel death, earns nothing.
		if eligible and bossConfig.cobraFinalBoss then
			eligible = ScarlettRunOwnsBoss(creature) and ScarlettRunIsParticipant(ScarlettRunCurrentToken(), attackerId)
		end
		if eligible and bossConfig.mintsFireWall then
			-- CORRECTION (correction pass section L): minted on EVERY legitimate kill, independent of
			-- the `< 1` one-time progress guard below (which only ever fires once per player, the
			-- first time CustodianKilled is set) - a player who fights the Custodian again after
			-- already having killed him once before must still receive a fresh pass.
			player:setStorageValue(Storage.Quest.U12_20.GraveDanger.FireWall, 1)
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
