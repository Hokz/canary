-- Eating the seven Forbidden Fruit samples. Owner reference requires eating all seven during the
-- active run, at Chartan, before reporting "collect" - collecting them is not enough by itself.
-- Consumption is tracked per-cycle (ForbiddenFruit.markEaten) so an old/stashed sample from a
-- previous run can never silently count toward a new one.
local eatFruit = Action()

function eatFruit.onUse(player, item, fromPosition, target, toPosition, isHotkey)
	if not ForbiddenFruit.isActive(player) then
		player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "You have no reason to eat this right now.")
		return true
	end

	if not ForbiddenFruit.hasCollected(player, item.itemid) then
		-- Collected THIS cycle is required, not merely possessed, so a bought/traded sample from
		-- outside this run cannot be eaten in place of the real collection interaction.
		player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "This isn't from your current task run.")
		return true
	end

	if ForbiddenFruit.hasEaten(player, item.itemid) then
		player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "You already ate one of these this run.")
		return true
	end

	if not item:remove(1) then
		return true
	end

	ForbiddenFruit.markEaten(player, item.itemid)
	player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "You eat the sample.")
	return true
end

for _, itemId in ipairs(ForbiddenFruit.SAMPLES) do
	eatFruit:id(itemId)
end
eatFruit:register()
