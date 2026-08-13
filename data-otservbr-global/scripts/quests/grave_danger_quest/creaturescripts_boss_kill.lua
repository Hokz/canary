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
		-- CORRECTION (lifecycle closure pass section E1): lets the shared `ownsBoss` computation below
		-- cover Scarlett too, so a stale/unrelated Scarlett Etzel death can never terminate or credit a
		-- different currently active ScarlettRun.
		ownsBossFn = "ScarlettRunOwnsBoss",
		-- CORRECTION (lifecycle closure pass section E2): the established Scarlett specPos bounds - a
		-- participant who tagged Scarlett and already left the fight room must not receive credit.
		room = { from = Position(33385, 32638, 6), to = Position(33406, 32660, 6) },
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
	-- CORRECTION (lifecycle closure pass section B): terminateFn/successReason move each of these four
	-- single-boss encounters' custom-run SUCCESS termination into THIS handler, after their credit is
	-- processed, instead of a separate standalone *_success CreatureEvent registered independently on
	-- the same monster. Canary does not guarantee which of two independently-registered onDeath
	-- handlers for the same monster runs first - if the standalone *_success handler happened to run
	-- BEFORE grave_danger_death, it would set the run inactive first, and *RunOwnsBoss's own
	-- `X.active` check would then make grave_danger_death's eligibility check fail and silently grant
	-- NO credit at all for a legitimate kill. Doing both in one synchronous handler, in a fixed order,
	-- removes the race entirely. Sir Baeloc is intentionally NOT given a terminateFn here - the
	-- Nictros/Baeloc pair's completion is a two-boss "both dead" condition, handled entirely inside
	-- actions_baeloc_nictros.lua (lifecycle closure pass section C), not a single-boss-death signal.
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
		terminateFn = "EarlOsamRunTerminate",
		successReason = "Earl Osam defeated",
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
		terminateFn = "VlarkorthRunTerminate",
		successReason = "Count Vlarkorth defeated",
	},
	-- CORRECTION (lifecycle closure pass section C1): "sir baeloc" is deliberately absent from this
	-- table now, matching the King Zelos precedent below - Sir Baeloc dying first (while Nictros is
	-- still alive) must not grant Darashia. Credit (Bosses.BaelocNictros.Killed / Graves.Darashia /
	-- Graves.Progress) and run termination both now live entirely in actions_baeloc_nictros.lua's own
	-- both-dead completion handler (nictros_baeloc_success / completePairSuccess), which needs the
	-- pair's own nictrosDead/baelocDead state this generic per-boss handler cannot see.
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
		terminateFn = "DukeKruleRunTerminate",
		successReason = "Duke Krule defeated",
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
		terminateFn = "AzaramRunTerminate",
		successReason = "Lord Azaram defeated",
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

	-- CORRECTION (correction pass section B): the boss itself must be the exact instance the current
	-- run owns before ANYTHING below (credit or termination) considers this death legitimate. Computed
	-- once here (not per-attacker) since it cannot change during this single synchronous handler.
	local ownsBoss = true
	if bossConfig.ownsBossFn then
		ownsBoss = _G[bossConfig.ownsBossFn](creature)
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
			-- CORRECTION (correction pass section B): the attacker must be a legitimate roster
			-- participant of the run that owns this exact boss, and must still be physically present
			-- in the legitimate encounter room at the moment of death - a damage-map entry from
			-- someone who tagged the boss and then left (or was never on the roster at all) earns
			-- nothing.
			if eligible and bossConfig.ownsBossFn then
				local tokenFn, isParticipantFn = _G[bossConfig.tokenFn], _G[bossConfig.isParticipantFn]
				local token = tokenFn()
				eligible = ownsBoss and isParticipantFn(token, attackerId) and isInsideRoom(player, bossConfig.room)
			end
		end
		-- CORRECTION (executor contract, section 34; correction pass section M3; lifecycle closure
		-- pass section E2): Scarlett's completion/achievement/Cobra-line credit belongs only to the
		-- current attempt's own participants, present at the death of the exact boss instance that
		-- attempt owns, AND still physically inside the legitimate fight room at that moment - a
		-- bystander who tags her with damage and leaves, or a stale/unrelated Scarlett Etzel death,
		-- earns nothing.
		if eligible and bossConfig.cobraFinalBoss then
			eligible = ownsBoss and ScarlettRunIsParticipant(ScarlettRunCurrentToken(), attackerId) and isInsideRoom(player, bossConfig.room)
		end
		if eligible and bossConfig.mintsFireWall then
			-- CORRECTION (correction pass section L): minted on EVERY legitimate kill, independent of
			-- the `< 1` one-time progress guard below (which only ever fires once per player, the
			-- first time CustodianKilled is set) - a player who fights the Custodian again after
			-- already having killed him once before must still receive a fresh pass.
			player:setStorageValue(Storage.Quest.U12_20.GraveDanger.FireWall, 1)
		end
		-- CORRECTION (lifecycle closure pass section C1): Sir Baeloc's own credit (Bosses.
		-- BaelocNictros.Killed / Graves.Darashia / Graves.Progress) is granted entirely by
		-- actions_baeloc_nictros.lua's own both-dead completion handler now, never here - Baeloc dying
		-- first while Nictros still lives must not grant Darashia.
		if eligible and not bossConfig.creditGrantedElsewhere and player:getStorageValue(bossConfig.stor) < 1 then
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

	-- CORRECTION (lifecycle closure pass section B): custom-run SUCCESS termination for the four
	-- single-boss encounters now happens HERE, after their credit is processed above, in the same
	-- synchronous handler - removing the cross-CreatureEvent ordering race described on the config
	-- table above. Guarded on `ownsBoss` (computed once above) so an unrelated/stale same-named death
	-- can never terminate a different currently active run.
	if bossConfig.terminateFn and ownsBoss then
		local tokenFn, terminateFn = _G[bossConfig.tokenFn], _G[bossConfig.terminateFn]
		local token = tokenFn()
		if token then
			terminateFn(token, "success", bossConfig.successReason)
		end
	end

	-- CORRECTION (lifecycle closure pass section E1): guarded on ownsBoss - an unrelated/stale
	-- Scarlett Etzel death must do absolutely nothing to a different currently active ScarlettRun.
	if bossConfig.cobraFinalBoss and ownsBoss then
		local token = ScarlettRunCurrentToken()
		if token then
			ScarlettRunTerminate(token, "success", "Scarlett Etzel defeated")
		end
	end

	return true
end

grave_danger_death:register()
