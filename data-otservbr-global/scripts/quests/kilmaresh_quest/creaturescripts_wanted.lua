-- "Wanted" (added 12.70) - did not exist before this pass. Neferi, Sister Hetai and Amenef the
-- Burning were bare, unconnected monsters with no quest hook at all.
local suspects = {
	["neferi the spy"] = Storage.Quest.U12_20.KilmareshQuest.Wanted.NeferiJustice,
	["sister hetai"] = Storage.Quest.U12_20.KilmareshQuest.Wanted.HetaiJustice,
	["amenef the burning"] = Storage.Quest.U12_20.KilmareshQuest.Wanted.AmenefJustice,
}

local wantedJustice = CreatureEvent("WantedJustice")

function wantedJustice.onDeath(creature, corpse, killer, mostDamageKiller)
	local storage = suspects[creature:getName():lower()]
	if not storage then
		return true
	end

	local attackers = creature:getDamageMap()
	for attackerId, _ in pairs(attackers) do
		local player = Player(attackerId)
		if player and player:getStorageValue(Storage.Quest.U12_20.KilmareshQuest.Wanted.Questline) >= 2 and player:getStorageValue(storage) < 1 then
			player:setStorageValue(storage, 1)
		end
	end

	return true
end

wantedJustice:register()
