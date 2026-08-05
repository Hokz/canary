-- CONFIRMED BUG (pre-existing): this file referenced `config.soulPos`, `config.centerRoom` and
-- `removeTainted()` as if they were globals, but all three are file-locals inside
-- creaturescripts_lord_azaram.lua and are invisible here. Stepping on item 31160 therefore raised
-- "attempt to index a nil value (global 'config')" every single time. The positions are restated
-- locally and the tainted-splinter cleanup is done inline, so this script is now self-contained.
-- Values mirrored verbatim from creaturescripts_lord_azaram.lua's own config table (same room).
local config = {
	centerRoom = Position(33424, 31472, 13),
	soulPos = Position(33426, 31471, 13),
	x = 10,
	y = 10,
}

local function removeTaintedSplinters()
	local spectators = Game.getSpectators(config.centerRoom, false, false, config.x, config.x, config.y, config.y)
	for _, spectator in pairs(spectators) do
		if spectator:isMonster() and spectator:getName():lower() == "tainted soul splinter" then
			spectator:remove()
		end
	end
end

local soul_cleanse = MoveEvent()

function soul_cleanse.onStepIn(creature, item, position, fromPosition)
	if creature:isPlayer() then
		return true
	end

	if creature:getName():lower() == "azaram's soul" then
		local health = (creature:getHealth() / creature:getMaxHealth()) * 100

		if health == 100 then
			creature:say("The broken Soul absorbs the power of the soul splinter and gains strength!")
			creature:teleportTo(config.soulPos)
			item:remove()
			removeTaintedSplinters()

			local boss = Creature("Lord Azaram")

			if boss then
				boss:teleportTo(config.centerRoom)
			end
		end
	end

	return true
end

soul_cleanse:id(31160)
soul_cleanse:register()
