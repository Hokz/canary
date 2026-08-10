local items = {
	{ itemid = 23512, count = 1 },
	{ itemid = 23538, count = 1 },
	{ itemid = 23536, count = 1 },
	{ itemid = 23509, count = 1 },
	{ itemid = 3043, count = 20 },
	{ itemid = 22721, count = 5 },
}

local heartDestructionReward = Action()
function heartDestructionReward.onUse(player, item, fromPosition, target, toPosition, isHotkey)
	if item.uid == 1038 then
		if player:getStorageValue(Storage.HeartOfDestructionFinalBattle.RewardClaimed) >= 1 then
			player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "The chest is empty.")
			return true
		end

		-- CONFIRMED BUG (found during the HOD repair audit): player:addItem(23525) and every
		-- container:addItem call after it were unchecked - a full inventory either crashed on a nil
		-- container or silently dropped items, while RewardClaimed was still set, permanently losing
		-- part of the reward with no way to reclaim it. Following the established pattern from
		-- ferumbras_ascension/actions_reward.lua: build the backpack unbound first (always succeeds,
		-- not subject to the player's own capacity), then hand the whole thing over in one checked
		-- operation - RewardClaimed is only set once that succeeds.
		local backpack = Game.createItem(23525)
		for i = 1, #items do
			backpack:addItem(items[i].itemid, items[i].count)
		end

		if player:addItemEx(backpack) ~= RETURNVALUE_NOERROR then
			local weight = backpack:getWeight()
			if player:getFreeCapacity() < weight then
				player:sendTextMessage(MESSAGE_EVENT_ADVANCE, string.format("You have found %s weighing %.2f oz. You have no capacity.", backpack:getName(), (weight / 100)))
			else
				player:sendCancelMessage("You have found a bag, but you have no room to take it.")
			end
			return true
		end

		-- CORRECTION (executor contract, section J): "Ender of the End" is granted on the actual
		-- World Devourer kill (creaturescripts_heart_boss_death.lua), not here - a player who
		-- legitimately defeats World Devourer must not lose the achievement just because their
		-- inventory couldn't accept the reward backpack. Reward delivery stays transactional on its
		-- own terms (RewardClaimed only after the backpack is actually delivered), independently of
		-- the achievement.
		player:setStorageValue(Storage.HeartOfDestructionFinalBattle.RewardClaimed, 1)
		player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "You have found an energetic backpack.")
	end

	return true
end

heartDestructionReward:uid(1038)
heartDestructionReward:register()
