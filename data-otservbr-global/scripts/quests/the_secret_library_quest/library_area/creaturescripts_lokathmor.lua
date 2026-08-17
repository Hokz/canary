local paper = 28488
local ROOM_FROM = Position(32742, 32681, 10)
local ROOM_TO = Position(32758, 32696, 10)

local function isInsideRoom(player)
	local pos = player:getPosition()
	return pos.x >= ROOM_FROM.x and pos.x <= ROOM_TO.x and pos.y >= ROOM_FROM.y and pos.y <= ROOM_TO.y and pos.z == ROOM_FROM.z
end

local creaturescripts_library_lokathmor = CreatureEvent("lokathmorDeath")

function creaturescripts_library_lokathmor.onDeath(creature, corpse, killer, mostDamageKiller, unjustified, mostDamageUnjustified)
	local cPos = creature:getPosition()

	if creature:getName():lower() == "dark knowledge" then
		-- CORRECTION (Secret Library repair v2, section 14): ownership-scoped - only THIS run's own
		-- current-generation Dark Knowledge can produce a legitimate parchment, and that parchment is
		-- tagged (item custom attribute) with the exact run token + trap generation it belongs to, so
		-- actions_parchment.lua can reject a stale item from an earlier generation/run.
		if not LokathmorRunOwnsDarkKnowledge(creature) then
			return true
		end
		local token = LokathmorRunCurrentToken()
		if not token then
			return true
		end
		local generation = creature:getStorageValue(1)
		local item = Game.createItem(paper, 1, cPos)
		if item then
			item:setCustomAttribute("LokathmorRunToken", token)
			item:setCustomAttribute("LokathmorGeneration", generation)
		end
		return true
	end

	if creature:getName():lower() == "lokathmor" then
		-- CORRECTION (Secret Library repair v2, section 13/18): sets the persistent per-player
		-- completion flag the final invasion lever checks, restricted to this run's own roster,
		-- still physically present in the room at the moment of death - a bystander's damage-map
		-- entry alone must not unlock final access.
		if not LokathmorRunOwnsBoss(creature) then
			return true
		end
		local token = LokathmorRunCurrentToken()
		for playerId in pairs(LokathmorRun.participants) do
			local player = Player(playerId)
			if player and isInsideRoom(player) then
				if player:getStorageValue(Storage.Quest.U11_80.TheSecretLibrary.Library.LokathmorDefeated) < 1 then
					player:setStorageValue(Storage.Quest.U11_80.TheSecretLibrary.Library.LokathmorDefeated, 1)
				end
			end
		end
		if token then
			LokathmorRunTerminate(token, "success", "Lokathmor defeated")
		end
	end

	return true
end

creaturescripts_library_lokathmor:register()
