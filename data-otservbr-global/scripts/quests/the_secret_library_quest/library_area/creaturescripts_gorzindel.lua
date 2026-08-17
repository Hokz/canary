local ROOM_FROM = Position(32680, 32711, 10)
local ROOM_TO = Position(32695, 32726, 10)

local function isInsideRoom(player)
	local pos = player:getPosition()
	return pos.x >= ROOM_FROM.x and pos.x <= ROOM_TO.x and pos.y >= ROOM_FROM.y and pos.y <= ROOM_TO.y and pos.z == ROOM_FROM.z
end

local creaturescripts_gorzindel = CreatureEvent("gorzindelDeath")

function creaturescripts_gorzindel.onDeath(creature, corpse, killer, mostDamageKiller, unjustified, mostDamageUnjustified)
	local cPos = creature:getPosition()
	local token = GorzindelRunCurrentToken()

	-- CORRECTION (Secret Library repair v2, section 15): ownership-scoped and exact-count based,
	-- replacing the previous 1-second-delayed Game.getSpectators re-scan that ran once per knowledge
	-- death with no single completion guard.
	if GorzindelRunOwnsKnowledge(creature) then
		local allDefeated = GorzindelRunKnowledgeDied(creature:getId())
		if allDefeated and token then
			local boss = Creature(GorzindelRun.bossId)
			if boss then
				boss:unregisterEvent("gorzindelHealth")
			end
			local spectators = Game.getSpectators(Position(32687, 32719, 10), false, false, 12, 12, 12, 12)
			for _, c in pairs(spectators) do
				if c and c:isMonster() and c:getName():lower() == "mean minion" then
					c:getPosition():sendMagicEffect(CONST_ME_POFF)
					c:remove()
				end
			end
		end
		return true
	end

	if creature:getName():lower() == "stolen tome of portals" and GorzindelRunOwnsTome(creature) and token then
		local portal = Game.createItem(1949, 1, cPos)
		if portal then
			portal:setActionId(4952)
			portal:setCustomAttribute("GorzindelRunToken", token)
			GorzindelRunTrackEvent(
				token,
				addEvent(function()
					if not GorzindelRunIsCurrent(token) then
						return
					end
					local sqm = Tile(cPos):getItemById(1949)
					-- CORRECTION (section 15): verified against this run's own token before removal -
					-- a portal belonging to a different/newer run occupying the same tile is left alone.
					if sqm and sqm:getCustomAttribute("GorzindelRunToken") == token then
						sqm:remove(1)
					end
					local newTome = Game.createMonster("stolen tome of portals", cPos, true, true)
					if newTome then
						GorzindelRunSetTome(token, newTome)
					end
				end, 10 * 1000)
			)
		end
		return true
	end

	return true
end

creaturescripts_gorzindel:register()

local creaturescripts_gorzindel_health = CreatureEvent("gorzindelHealth")

-- CORRECTION (section 15): gorzindelHealth previously zeroed ALL incoming damage unconditionally,
-- with no check against the 5-book count at all. True invulnerability while any current-run owned
-- Stolen Knowledge remains, using the engine's native immune() toggle instead of a manual health-zero
-- hack.
function creaturescripts_gorzindel_health.onHealthChange(creature, attacker, primaryDamage, primaryType, secondaryDamage, secondaryType, origin)
	if not GorzindelRunOwnsBoss(creature) then
		return primaryDamage, primaryType, secondaryDamage, secondaryType
	end
	if GorzindelRun.knowledgeRemaining > 0 then
		creature:getPosition():sendMagicEffect(CONST_ME_BLOCKHIT)
		return 0, primaryType, 0, secondaryType
	end
	return primaryDamage, primaryType, secondaryDamage, secondaryType
end

creaturescripts_gorzindel_health:register()

-- ================================================================
-- GORZINDEL SUCCESS (Secret Library repair v2, section 13/18)
-- ================================================================
local gorzindelSuccess = CreatureEvent("gorzindelSuccess")

function gorzindelSuccess.onDeath(creature)
	local targetMonster = creature:getMonster()
	if not targetMonster or targetMonster:getMaster() then
		return true
	end
	if not GorzindelRunOwnsBoss(creature) then
		return true
	end

	for playerId in pairs(GorzindelRun.participants) do
		local player = Player(playerId)
		if player and isInsideRoom(player) then
			if player:getStorageValue(Storage.Quest.U11_80.TheSecretLibrary.Library.GorzindelDefeated) < 1 then
				player:setStorageValue(Storage.Quest.U11_80.TheSecretLibrary.Library.GorzindelDefeated, 1)
			end
		end
	end

	GorzindelRunTerminate(GorzindelRunCurrentToken(), "success", "Gorzindel defeated")
	return true
end

gorzindelSuccess:register()
