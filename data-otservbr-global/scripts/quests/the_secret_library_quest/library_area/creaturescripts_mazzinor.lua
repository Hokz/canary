local vortexId = 28673
local actionId = 4951
local ROOM_FROM = Position(32716, 32713, 10)
local ROOM_TO = Position(32732, 32728, 10)

local function isInsideRoom(player)
	local pos = player:getPosition()
	return pos.x >= ROOM_FROM.x and pos.x <= ROOM_TO.x and pos.y >= ROOM_FROM.y and pos.y <= ROOM_TO.y and pos.z == ROOM_FROM.z
end

-- CORRECTION (Secret Library repair v2, section 16): "mazzinorHealth" (a blanket, unconditional
-- damage-zero with no phase check at all) has been removed entirely - the run's own supercharge cycle
-- (actions_mazzinor.lua) now uses the engine's native immune() toggle instead, which is both simpler
-- and correct (Mazzinor is genuinely damageable whenever this flag is off).
local creaturescripts_library_mazzinor = CreatureEvent("mazzinorDeath")

function creaturescripts_library_mazzinor.onDeath(creature, corpse, killer, mostDamageKiller, unjustified, mostDamageUnjustified)
	local cPos = creature:getPosition()
	local token = MazzinorRunCurrentToken()

	if creature:getName():lower() == "wild knowledge" then
		if not token then
			return true
		end
		local vortex = Game.createItem(vortexId, 1, cPos)
		if vortex then
			vortex:setActionId(actionId)
			-- CORRECTION (section 16.2): tagged with this run's own token so the transform trigger
			-- (movements_mazzinor.lua) and this cleanup can both verify it belongs to the current
			-- attempt - a stale vortex from an already-terminated run can no longer protect a newer
			-- one just because it happens to still be sitting on the same tile.
			vortex:setCustomAttribute("MazzinorRunToken", token)
			-- CORRECTION (section 16.2): tracked/run-owned instead of a raw untracked addEvent -
			-- cancelled automatically by MazzinorRunTerminate on any terminal path, and verified
			-- against the current token before removing (a look-up by item id at position could
			-- otherwise delete a newer run's own vortex occupying the same tile).
			MazzinorRunTrackEvent(
				token,
				addEvent(function()
					if not MazzinorRunIsCurrent(token) then
						return
					end
					local item = Tile(cPos):getItemById(vortexId)
					if item and item:getCustomAttribute("MazzinorRunToken") == token then
						item:remove()
					end
				end, 1 * 1000 * 60)
			)
		end
		return true
	end

	if creature:getName():lower() == "mazzinor" then
		if not MazzinorRunOwnsBoss(creature) then
			return true
		end
		-- CORRECTION (section 13/18): persistent per-player completion credit, restricted to this
		-- run's own roster, still physically present at the moment of death.
		for playerId in pairs(MazzinorRun.participants) do
			local player = Player(playerId)
			if player and isInsideRoom(player) then
				if player:getStorageValue(Storage.Quest.U11_80.TheSecretLibrary.Library.MazzinorDefeated) < 1 then
					player:setStorageValue(Storage.Quest.U11_80.TheSecretLibrary.Library.MazzinorDefeated, 1)
				end
			end
		end
		if token then
			MazzinorRunTerminate(token, "success", "Mazzinor defeated")
		end
	end

	return true
end

creaturescripts_library_mazzinor:register()
