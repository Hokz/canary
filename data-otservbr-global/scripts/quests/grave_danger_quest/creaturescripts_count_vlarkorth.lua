local config = {
	centerRoom = Position(33456, 31437, 13),
	newPosition = Position(33457, 31442, 13),
	exitPos = Position(33195, 31696, 8),
	x = 10,
	y = 10,
	-- Sorcerer(1)/Druid(2)/Paladin(3)/Knight(4) confirmed wired (each dark summon's monster.corpse
	-- already resolves straight to the matching "good remains of a X" item, see actions_dark_remains.lua).
	-- Monk (vocation base id 9, NOT 5 - vocations.xml confirms Monk's id is 9) is deliberately absent:
	-- ASSET_REQUIRED (executor contract, section 8). Repo-wide search found no canonical "Dark Merudri"
	-- monster and no "good remains of a monk"-style item anywhere (only unrelated Way of the Monk quest
	-- assets and an unrelated pre-existing lore monster literally named "Dark Monk", humans/dark_monk.lua,
	-- with no corpse/event tie to this fight). Rather than inventing a monster/item id, a Monk
	-- participant simply generates no summon and no obligation for their own vocation - this already
	-- fails closed (the shield is never blocked waiting on an obligation that could never be created or
	-- resolved); it does not fully implement their intended mechanic.
	summons = {
		[4] = { summon = "Dark Knight" },
		[1] = { summon = "Dark Sorcerer" },
		[2] = { summon = "Dark Druid" },
		[3] = { summon = "Dark Paladin" },
	},
	timer = Storage.Quest.U12_20.GraveDanger.Bosses.CountVlarkorth.Timer,
	room = Storage.Quest.U12_20.GraveDanger.Bosses.CountVlarkorth.Room,
}

-- CORRECTION (executor contract, section 8): takes the actual boss instance (already available to
-- its only caller, onHealthChange) instead of a bare `Creature("Count Vlarkorth")` name lookup, so a
-- stale reference from a previous attempt can never resolve to - or summon darks for - a different
-- Count Vlarkorth instance. Each dark summon is verified with bounded retry; a mandatory summon that
-- ultimately fails to spawn technical-aborts the run rather than silently lowering the obligation
-- count (a vocation actually present in the fight must not be able to slip past its own obligation).
--
-- CORRECTION (section D): every wave gets its own shield generation, stamped on the boss (storage 5)
-- and on each dark summon spawned this wave (storage 1). This is what lets each dark's own corpse
-- (tagged on death, see count_vlarkorth_remains_tag below) be verified against the CURRENT generation
-- before a remains item is allowed to weaken the shield - remains saved from an earlier wave can never
-- weaken a newer one.
local function summonDarks(boss, token)
	local spectators = Game.getSpectators(boss:getPosition(), false, true, config.x, config.x, config.y, config.y)
	if #spectators == 0 then
		return true
	end

	local generation = math.max(boss:getStorageValue(5), 0) + 1
	boss:setStorageValue(5, generation)
	VlarkorthRun.generation = generation

	local anySpoke = false
	for _, player in pairs(spectators) do
		if player:isPlayer() then
			local vocationId = player:getVocation():getBase():getId()
			local toSummon = config.summons[vocationId]
			if toSummon then
				local dark = nil
				for attempt = 1, 3 do
					local newPosition = boss:getClosestFreePosition(boss:getPosition(), true) or boss:getPosition()
					dark = Game.createMonster(toSummon.summon, newPosition, false, true)
					if dark then
						break
					end
					logger.error("GraveDanger/CountVlarkorth: failed to create {} (attempt {}/3)", toSummon.summon, attempt)
				end
				if dark then
					local summonCount = boss:getStorageValue(3)
					boss:setStorageValue(3, math.max(0, summonCount) + 1)
					dark:setStorageValue(1, generation)
					VlarkorthRunTrackMonster(dark)
					anySpoke = true
				else
					logger.error("GraveDanger/CountVlarkorth: {} failed to spawn after bounded retries for {}", toSummon.summon, player:getName())
					VlarkorthRunTerminate(token, "technical_abort", toSummon.summon .. " failed to spawn after bounded retries")
					return false
				end
			end
		end
	end

	if anySpoke then
		boss:say("Face your own darkness!")
	end

	return true
end

local count_vlarkorth_transform = CreatureEvent("count_vlarkorth_transform")

function count_vlarkorth_transform.onHealthChange(creature, attacker, primaryDamage, primaryType, secondaryDamage, secondaryType)
	if not creature or not VlarkorthRunOwnsMonster(creature) then
		return primaryDamage, primaryType, secondaryDamage, secondaryType
	end
	local token = VlarkorthRunCurrentToken()

	local players = Game.getSpectators(config.centerRoom, false, true, config.x, config.x, config.y, config.y)
	for _, player in pairs(players) do
		if player:isPlayer() then
			if player:getStorageValue(config.timer) < os.time() then
				player:setStorageValue(config.timer, os.time() + 20 * 3600)
				-- CORRECTION (section O): remembers that THIS attempt wrote the legacy Timer lockout
				-- for this player, so a later technical_abort knows it is safe to roll back.
				VlarkorthRunMarkTimerWritten(token, player:getId())
			end
			if player:getStorageValue(config.room) < os.time() then
				player:setStorageValue(config.room, os.time() + 30 * 60)
			end
		end
	end

	if primaryType == COMBAT_HEALING then
		return primaryDamage, primaryType, -secondaryDamage, secondaryType
	end

	local health = creature:getMaxHealth() * 0.15
	local damageStorage = creature:getStorageValue(1)
	if damageStorage < 0 then
		creature:setStorageValue(1, 0)
		damageStorage = 0
	end

	if creature:getStorageValue(3) > 0 then
		-- CORRECTION (executor contract, section 8): actually invulnerable while shield obligations
		-- are unresolved - previously showed BLOCKHIT but still returned the incoming damage
		-- unmodified, so Vlarkorth kept taking full damage during what looked like a shielded phase.
		creature:getPosition():sendMagicEffect(CONST_ME_BLOCKHIT)
		return 0, primaryType, 0, secondaryType
	end

	creature:setStorageValue(1, damageStorage + primaryDamage + secondaryDamage)

	if creature:getStorageValue(1) >= health then
		creature:setStorageValue(1, 0)
		creature:setStorageValue(3, 0)
		summonDarks(creature, token)
	end

	return primaryDamage, primaryType, -secondaryDamage, secondaryType
end

count_vlarkorth_transform:register()

-- Success credit/cleanup: Count Vlarkorth's own kill credit is handled by the pre-existing generic
-- creaturescripts_boss_kill.lua path (unchanged, out of this section's scope beyond the lichLine
-- eligibility gate added there) - this just releases the run's own bookkeeping once he actually dies.
local count_vlarkorth_success = CreatureEvent("count_vlarkorth_success")

function count_vlarkorth_success.onDeath(creature)
	local targetMonster = creature:getMonster()
	if not targetMonster or targetMonster:getMaster() then
		return true
	end
	-- CORRECTION (section I precedent applied here too): must be the exact boss this run owns, not
	-- merely any monster tracked in VlarkorthRun.monsters (which also includes the dark summons).
	if not VlarkorthRunOwnsBoss(creature) then
		return true
	end
	VlarkorthRunTerminate(VlarkorthRunCurrentToken(), "success", "Count Vlarkorth defeated")
	return true
end

count_vlarkorth_success:register()

-- ================================================================
-- REMAINS GENERATION TAGGING (correction pass section D)
-- ================================================================
-- Registered on each of the 4 dark summon monster types (see monster.events additions in
-- dark_sorcerer.lua/dark_druid.lua/dark_paladin.lua/dark_knight.lua). Tags this dark's own corpse with
-- the current run token and the shield generation it was summoned for (stamped on itself at creation
-- by summonDarks above), so actions_dark_remains.lua can reject a remains item that outlived its own
-- generation or run.
local count_vlarkorth_remains_tag = CreatureEvent("count_vlarkorth_remains_tag")

function count_vlarkorth_remains_tag.onDeath(creature, corpse)
	if not corpse or not VlarkorthRunOwnsMonster(creature) then
		return true
	end
	local token = VlarkorthRunCurrentToken()
	if not token then
		return true
	end
	corpse:setCustomAttribute("VlarkorthRunToken", token)
	corpse:setCustomAttribute("VlarkorthGeneration", creature:getStorageValue(1))
	return true
end

count_vlarkorth_remains_tag:register()
