local actions_isles_telescope = Action()

function actions_isles_telescope.onUse(player, item, fromPosition, itemEx, toPosition)
	if player:getStorageValue(Storage.Quest.U11_80.TheSecretLibrary.SmallIslands.BoatStages) == 2 then
		player:setStorageValue(Storage.Quest.U11_80.TheSecretLibrary.SmallIslands.BoatStages, 3)
		-- Corrected to the exact PDF/reference message (was a paraphrase before). Also grants the
		-- High and Dry achievement here - per the reference's own walkthrough sequence ("...pull the
		-- hawser from the trash pile, then use the telescope standing nearby. Info! We receive the
		-- achievement High and Dry."), this is a one-time achievement earned on first telescope use
		-- after being shipwrecked, not a repeated-shortcut-usage counter - previously never granted
		-- anywhere in the repo despite being fully registered.
		player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "By using the telescope you observe the fleeing vessel leaving you behind half way to mainland.")
		if not player:hasAchievement("High and Dry") then
			player:addAchievement("High and Dry")
		end
	end

	return true
end

actions_isles_telescope:aid(4935)
actions_isles_telescope:register()
