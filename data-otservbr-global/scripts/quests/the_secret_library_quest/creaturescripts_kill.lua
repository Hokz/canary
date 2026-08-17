local defaultTime = 20

local creaturescripts_library_bosses = CreatureEvent("killingLibrary")

-- CORRECTION (Secret Library repair v2, section 7): sequential = true marks the six Order of the
-- Falcon bosses, which must advance FalconBastion.KillingBosses one legitimate stage at a time -
-- previously any of these six granted credit to `value` directly as long as the player's current
-- stage was merely LOWER than `value` (a monotonic "only raise" clamp, not a "+1 from current stage"
-- check), letting a player who somehow reached a later boss's damage map (area boss hitting multiple
-- people, a teleport, etc.) leap over unfought earlier stages. brokul/the flaming orchid are
-- unrelated single-value gates on different quest branches and are intentionally excluded from this
-- sequential requirement.
local monsterStorages = {
	["grand commander soeren"] = { stg = Storage.Quest.U11_80.TheSecretLibrary.FalconBastion.KillingBosses, value = 1, sequential = true },
	["preceptor lazare"] = { stg = Storage.Quest.U11_80.TheSecretLibrary.FalconBastion.KillingBosses, value = 2, sequential = true },
	["grand chaplain gaunder"] = { stg = Storage.Quest.U11_80.TheSecretLibrary.FalconBastion.KillingBosses, value = 3, sequential = true },
	["grand canon dominus"] = { stg = Storage.Quest.U11_80.TheSecretLibrary.FalconBastion.KillingBosses, value = 4, sequential = true },
	["dazed leaf golem"] = { stg = Storage.Quest.U11_80.TheSecretLibrary.FalconBastion.KillingBosses, value = 5, sequential = true },
	-- CORRECTION (section 8): "Master Debater" removed from the unconditional achievement grant.
	-- Mechanically searched the whole repository for any Grand-Master-Oberon debate-document/book
	-- collection mechanic (item, storage, or NPC) - none exists anywhere. The achievement itself is
	-- defined (data/scripts/lib/register_achievements.lua, id 445) but nothing in this codebase ever
	-- tracked the "nine debate documents" prerequisite the owner reference describes. Per this
	-- section's explicit instruction, that unresolved portion is classified NOT_PROVEN and the
	-- achievement is no longer falsely awarded on every damaging player - inventing a document/
	-- storage system to back it would mean guessing item ids, which is explicitly prohibited.
	-- Millennial Falcon remains tied to legitimate Oberon completion as originally intended.
	["grand master oberon"] = { stg = Storage.Quest.U11_80.TheSecretLibrary.FalconBastion.KillingBosses, value = 6, sequential = true, achievements = { "Millennial Falcon" }, lastBoss = true },
	["brokul"] = { stg = Storage.Quest.U11_80.TheSecretLibrary.LiquidDeath.Questline, value = 7 },
	["the flaming orchid"] = { stg = Storage.Quest.U11_80.TheSecretLibrary.Asuras.FlammingOrchid, value = 1 },
}

function creaturescripts_library_bosses.onDeath(creature, corpse, killer, mostDamageKiller, lastHitUnjustified)
	if not creature:isMonster() or creature:getMaster() then
		return true
	end

	local monsterName = creature:getName():lower()
	local monsterStorage = monsterStorages[monsterName]

	if monsterStorage then
		for playerid, damage in pairs(creature:getDamageMap()) do
			local p = Player(playerid)
			-- CORRECTION (section 7): for the six sequential Falcon bosses, credit is restricted to
			-- legitimate encounter participants - level 250 and Premium, matching this project's
			-- established Lich/Falcon-tier boss eligibility convention (see Grave Danger's equivalent
			-- Lich-line credit gate). brokul/the flaming orchid are unrelated, already-working branches
			-- out of this section's scope and keep their original bystander-inclusive check unchanged.
			local eligible = p ~= nil
			if eligible and monsterStorage.sequential then
				eligible = p:getLevel() >= 250 and p:isPremium()
			end
			if eligible then
				if monsterStorage.sequential then
					-- CORRECTION (section 7): reject a leap over unfought earlier stages - only the
					-- exact immediately-previous stage may advance to this one.
					if p:getStorageValue(monsterStorage.stg) == monsterStorage.value - 1 then
						p:setStorageValue(monsterStorage.stg, monsterStorage.value)
					end
				else
					if p:getStorageValue(monsterStorage.stg) < monsterStorage.value then
						p:setStorageValue(monsterStorage.stg, monsterStorage.value)
					end
				end
				-- Achievements/lastBoss progression only apply to a player who actually reached the
				-- correct current stage this kill (either just advanced above, or already at it from
				-- a previous legitimate kill in the same encounter's damage map).
				if p:getStorageValue(monsterStorage.stg) >= monsterStorage.value then
					if monsterStorage.achievements then
						for i = 1, #monsterStorage.achievements do
							p:addAchievement(monsterStorage.achievements[i])
						end
					end
					if monsterStorage.lastBoss then
						if p:getStorageValue(Storage.Quest.U11_80.TheSecretLibrary.FalconBastion.Questline) < 2 then
							p:setStorageValue(Storage.Quest.U11_80.TheSecretLibrary.FalconBastion.Questline, 2)
						end
						-- CORRECTION (corrective repair pass, section 4.3): evaluate Master Debater here
						-- too (not only from actions_master_debater_documents.lua's own document-discovery
						-- path) so the achievement grants order-independently - a player who already
						-- collected every discoverable document before this kill gets it the moment Oberon
						-- legitimately dies, not only on their next document Use.
						MasterDebaterCheckAchievement(p)
					end
				end
			end
		end
	end
	return true
end

creaturescripts_library_bosses:register()
