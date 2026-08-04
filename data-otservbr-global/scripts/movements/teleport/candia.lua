local config = {
	{ position = { x = 33338, y = 32125, z = 7 }, destination = { x = 33574, y = 32224, z = 7 } }, -- Candia > Feyrist
	{ position = { x = 33339, y = 32125, z = 7 }, destination = { x = 33575, y = 32224, z = 7 } }, -- Candia > Feyrist
	{ position = { x = 33574, y = 32222, z = 7 }, destination = { x = 33338, y = 32127, z = 7 } }, -- Feyrist > Candia
	{ position = { x = 33575, y = 32222, z = 7 }, destination = { x = 33339, y = 32127, z = 7 } }, -- Feyrist > Candia
}

local candia = MoveEvent()
function candia.onStepIn(creature, item, position, fromPosition)
	local player = creature:getPlayer()
	if not player then
		return false
	end

	for value in pairs(config) do
		if Position(config[value].position) == player:getPosition() then
			-- Feyrist > Candia direction requires the baked Gingerbread Key (Sweet Dreams);
			-- the reverse Candia > Feyrist direction is always open once inside.
			local enteringCandia = config[value].destination.x == 33338 or config[value].destination.x == 33339
			if enteringCandia and player:getStorageValue(Storage.Quest.U11_40.ThreatenedDreams.Mission06.CandiaAccess) < 1 then
				player:teleportTo(fromPosition)
				player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "The donut leads nowhere you recognize. You feel you need a key of some sort to make sense of this place.")
				return true
			end
			player:teleportTo(Position(config[value].destination), true)
			player:getPosition():sendMagicEffect(CONST_ME_CANDY_FLOSS)
			return true
		end
	end
end

candia:type("stepin")
for value in pairs(config) do
	candia:position(config[value].position)
end
candia:register()
