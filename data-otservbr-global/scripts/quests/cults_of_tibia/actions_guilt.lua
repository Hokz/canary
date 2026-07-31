-- Using Guilt (looted from Dark Souls in the side rooms) on The Remorseless Corruptor accumulates
-- toward transforming it into the vulnerable The Corruptor of Souls; continuing to use Guilt on it
-- afterwards keeps postponing creaturescripts_check_tile.lua's revert-to-invulnerable timer.
local guiltThreshold = 5
local guiltRevertWindow = 30

local remorselessCorruptorGuilt = Action()

function remorselessCorruptorGuilt.onUse(player, item, fromPosition, target, toPosition, isHotkey)
	if not target or not target:isMonster() then
		return false
	end

	local name = target:getName():lower()
	if name ~= "the remorseless corruptor" and name ~= "the corruptor of souls" then
		return false
	end

	item:remove(1)
	player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "You have raised the guilt of the corruptor.")

	if name == "the remorseless corruptor" then
		local count = math.max(Game.getStorageValue("CultsOfTibiaGuilt"), 0) + 1
		Game.setStorageValue("CultsOfTibiaGuilt", count)
		if count >= guiltThreshold then
			local pos = target:getPosition()
			target:remove()
			Game.createMonster("The Corruptor of Souls", pos, true, true)
			Game.setStorageValue("CultsOfTibiaGuilt", 0)
			Game.setStorageValue("CheckTile", os.time() + guiltRevertWindow)
		end
	else
		Game.setStorageValue("CheckTile", os.time() + guiltRevertWindow)
	end
	return true
end

remorselessCorruptorGuilt:id(25774)
remorselessCorruptorGuilt:register()
