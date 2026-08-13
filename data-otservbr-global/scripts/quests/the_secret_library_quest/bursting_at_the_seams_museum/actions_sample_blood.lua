local skullPosition = Position(33348, 32117, 10)

local actions_museum_sample_blood = Action()

function actions_museum_sample_blood.onUse(player, item, fromPosition, target, toPosition, isHotkey)
	if target:getPosition() == skullPosition and player:getStorageValue(Storage.Quest.U11_80.TheSecretLibrary.MoTA.SkullSample) ~= 1 then
		item:remove(1)
		player:setStorageValue(Storage.Quest.U11_80.TheSecretLibrary.MoTA.SkullSample, 1)
		-- CONFIRMED BLOCKER (Secret Library repair v2, section 10): see the matching comment in
		-- actions_bony_rod.lua - MoTA.Questline never advanced past 6 anywhere in this branch.
		if player:getStorageValue(Storage.Quest.U11_80.TheSecretLibrary.MoTA.FinalBasin) >= 1 and player:getStorageValue(Storage.Quest.U11_80.TheSecretLibrary.MoTA.Questline) < 7 then
			player:setStorageValue(Storage.Quest.U11_80.TheSecretLibrary.MoTA.Questline, 7)
		end
	end

	return true
end

actions_museum_sample_blood:id(27874)
actions_museum_sample_blood:register()
