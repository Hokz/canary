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
local function summonDarks(boss, token)
	local spectators = Game.getSpectators(boss:getPosition(), false, true, config.x, config.x, config.y, config.y)
	if #spectators == 0 then
		return true
	end

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
	if not VlarkorthRunOwnsMonster(creature) then
		return true
	end
	VlarkorthRunTerminate(VlarkorthRunCurrentToken(), "success", "Count Vlarkorth defeated")
	return true
end

count_vlarkorth_success:register()
