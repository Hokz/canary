-- Rascacoon Trust Points / The Journey - a Quarra Saboteur killed near a Raccoon Supplies crate
-- destroys it in an area burst (-5 raft health), matching the reference's warning not to fight
-- them next to the crates. Crate positions are configured in
-- lib/quests/a_pirates_tail.lua's APiratesTailJourneySupplyCrates.
local CRATE_ID = 116
local CRATE_BLAST_RADIUS = 2

local quarraDeath = CreatureEvent("JourneyQuarraDeath")

function quarraDeath.onDeath(creature, corpse, lasthitkiller, mostdamagekiller)
	local deathPosition = creature:getPosition()
	for _, cratePosition in pairs(APiratesTailJourneySupplyCrates) do
		if deathPosition:isInRange(cratePosition, CRATE_BLAST_RADIUS, CRATE_BLAST_RADIUS) then
			local tile = Tile(cratePosition)
			local crate = tile and tile:getItemById(CRATE_ID)
			if crate then
				crate:remove()
				damageAPiratesTailRaft(5)
				deathPosition:sendMagicEffect(CONST_ME_EXPLOSIONAREA)
			end
		end
	end
	return true
end

quarraDeath:register()
