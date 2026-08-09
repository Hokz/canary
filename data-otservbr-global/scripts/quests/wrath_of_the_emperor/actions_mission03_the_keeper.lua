local KEEPER_POSITION = Position({ x = 33171, y = 31058, z = 11 })

local function revertKeeperstorage()
	Game.setStorageValue(Storage.Quest.U8_6.WrathOfTheEmperor.Mission03, 0)
end

local wrathEmperorMiss3Keeper = Action()
function wrathEmperorMiss3Keeper.onUse(player, item, fromPosition, target, toPosition, isHotkey)
	if item.itemid == 11364 and target.actionid == 8026 then
		if Game.getStorageValue(Storage.Quest.U8_6.WrathOfTheEmperor.Mission03) < 5 then
			Game.setStorageValue(Storage.Quest.U8_6.WrathOfTheEmperor.Mission03, math.max(0, Game.getStorageValue(Storage.Quest.U8_6.WrathOfTheEmperor.Mission03)) + 1)
			player:say("The plant twines and twiggles even more than before, it almost looks as it would scream great pain.", TALKTYPE_MONSTER_SAY)
		elseif Game.getStorageValue(Storage.Quest.U8_6.WrathOfTheEmperor.Mission03) == 5 then
			-- CONFIRMED BUG (found during the WOTE reconciliation audit): this used to consume the
			-- player's Flask of Plant Poison (sourced solely from npc/zalamon.lua - no other source
			-- anywhere in the data set) and commit the global spawn counter to 6 BEFORE confirming
			-- Game.createMonster actually returned a monster. A failed spawn would permanently
			-- soft-lock Mission 3 for that player, since the counter's only way back to 0 is the 60s
			-- addEvent below, which does not restore the consumed flask. Now transactional, matching
			-- the same fix already applied to Mission 10's crystal encounters - also guard against a
			-- Keeper that's already alive nearby, since the 60s counter reset fires on a timer
			-- regardless of whether the previous Keeper was ever killed.
			local alreadyAlive = false
			for _, spectator in ipairs(Game.getSpectators(KEEPER_POSITION, false, false, 3, 3, 3, 3)) do
				if spectator:isMonster() and spectator:getName():lower() == "the keeper" then
					alreadyAlive = true
					break
				end
			end

			if alreadyAlive then
				player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "The Keeper is already stirring nearby. Try again once it has been dealt with.")
				return true
			end

			local monster = Game.createMonster("the keeper", KEEPER_POSITION)
			if not monster then
				player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "The plant falls still. Try again in a moment.")
				return true
			end

			player:removeItem(11364, 1)
			Game.setStorageValue(Storage.Quest.U8_6.WrathOfTheEmperor.Mission03, 6)
			toPosition:sendMagicEffect(CONST_ME_YELLOW_RINGS)
			KEEPER_POSITION:sendMagicEffect(CONST_ME_TELEPORT)
			addEvent(revertKeeperstorage, 60 * 1000)
		end
	elseif item.itemid == 11360 then
		if player:getStorageValue(Storage.Quest.U8_6.WrathOfTheEmperor.Questline) == 7 then
			player:setStorageValue(Storage.Quest.U8_6.WrathOfTheEmperor.Questline, 8)
			player:setStorageValue(Storage.Quest.U8_6.WrathOfTheEmperor.Mission03, 2) --Questlog, Wrath of the Emperor "Mission 03: The Keeper"
			player:addItem(11367, 1)
		end
	end
	return true
end

wrathEmperorMiss3Keeper:id(11360, 11364)
wrathEmperorMiss3Keeper:register()
