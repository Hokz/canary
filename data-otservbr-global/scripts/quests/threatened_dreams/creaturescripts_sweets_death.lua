-- Sweet Dreams / Stolen Sweets - Kroazur, Katex Blood Tongue, The Flaming Orchid and Gorga each
-- drop one of Sugar Plum Fairy's stolen sweets on death. No exact "Matcha Turtle"/"Rainbow
-- Waffles"/"Rose Milk Cake"/"Nightsky Cupcake" item exists anywhere in this repo, so collection
-- is tracked with storage flags rather than a fabricated new item.
local ThreatenedDreams = Storage.Quest.U11_40.ThreatenedDreams

local sweets = {
	["kroazur"] = { storage = ThreatenedDreams.Mission06.SweetKroazur, name = "Matcha Turtle" },
	["katex blood tongue"] = { storage = ThreatenedDreams.Mission06.SweetKatex, name = "Rainbow Waffles" },
	["the flaming orchid"] = { storage = ThreatenedDreams.Mission06.SweetOrchid, name = "Rose Milk Cake" },
	["gorga"] = { storage = ThreatenedDreams.Mission06.SweetGorga, name = "Nightsky Cupcake" },
}

local sweetsDeath = CreatureEvent("SweetDreamsSweetsDeath")

function sweetsDeath.onDeath(creature, corpse, lasthitkiller, mostdamagekiller)
	local sweet = sweets[creature:getName():lower()]
	if not sweet then
		return true
	end

	onDeathForDamagingPlayers(creature, function(creature, player)
		if player:getStorageValue(ThreatenedDreams.Mission06[1]) < 9 then
			return
		end
		if player:getStorageValue(sweet.storage) >= 1 then
			return
		end
		player:setStorageValue(sweet.storage, 1)
		player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "You find " .. sweet.name .. " among the remains - one of Sugar Plum Fairy's stolen sweets!")
	end)
	return true
end

sweetsDeath:register()
