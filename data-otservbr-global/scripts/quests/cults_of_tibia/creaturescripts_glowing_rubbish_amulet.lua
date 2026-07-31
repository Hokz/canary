local glowingRubbishAmulet = CreatureEvent("GlowingRubbishAmuletDeath")

-- Storage.Quest.U11_40.CultsOfTibia.Misguided.Time was reserved but never written anywhere -
-- the reference's 5-minute charge window and "amulet fell off" failure never existed in code.
local function expireGlowingAmulet(playerId)
	local player = Player(playerId)
	if not player then
		return
	end
	if player:getStorageValue(Storage.Quest.U11_40.CultsOfTibia.Misguided.Time) < 1 then
		return
	end
	local deadline = player:getStorageValue(Storage.Quest.U11_40.CultsOfTibia.Misguided.Time)
	if os.time() < deadline then
		return
	end
	player:setStorageValue(Storage.Quest.U11_40.CultsOfTibia.Misguided.Time, 0)
	local amulet = player:getSlotItem(CONST_SLOT_NECKLACE)
	if amulet and amulet:getId() == 25297 then
		amulet:remove()
		player:addItem(25296, 1)
		player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "The amulet fell off. You took too long to recharge it. Whatever power it accumulated is now lost.")
		return
	end
	local backpackAmulet = player:getItemById(25297, true)
	if backpackAmulet then
		backpackAmulet:remove()
		player:addItem(25296, 1)
		player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "The amulet fell off. You took too long to recharge it. Whatever power it accumulated is now lost.")
	end
end

function glowingRubbishAmulet.onDeath(creature, _corpse, _lastHitKiller, mostDamageKiller)
	onDeathForParty(creature, mostDamageKiller, function(creature, player)
		local amulet = player:getSlotItem(CONST_SLOT_NECKLACE)

		if player:getStorageValue(Storage.Quest.U11_40.CultsOfTibia.Misguided.Mission) ~= 3 then
			return true
		end

		local mStg = math.max(player:getStorageValue(Storage.Quest.U11_40.CultsOfTibia.Misguided.Monsters), 0)
		local eStg = math.max(player:getStorageValue(Storage.Quest.U11_40.CultsOfTibia.Misguided.Exorcisms), 0)

		if creature:getName():lower():trim() == "misguided shadow" then
			if eStg < 5 then
				player:setStorageValue(Storage.Quest.U11_40.CultsOfTibia.Misguided.Exorcisms, eStg + 1)
			end
			return true
		end

		if not amulet or amulet:getId() ~= 25296 then
			return true
		end

		if creature:getName():lower():trim() == "misguided bully" or creature:getName():lower():trim() == "misguided thief" then
			player:setStorageValue(Storage.Quest.U11_40.CultsOfTibia.Misguided.Monsters, mStg + 1)

			if player:getStorageValue(Storage.Quest.U11_40.CultsOfTibia.Misguided.Monsters) >= 10 then
				amulet:remove()
				local it = player:addItem(25297, 1)
				if it then
					it:decay()
				end
				player:setStorageValue(Storage.Quest.U11_40.CultsOfTibia.Misguided.Time, os.time() + 300)
				addEvent(expireGlowingAmulet, 300 * 1000, player:getId())
			end
		end
	end)
	return true
end

glowingRubbishAmulet:register()
