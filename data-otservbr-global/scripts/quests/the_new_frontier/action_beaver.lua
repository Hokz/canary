local config = {
	treesBeaver = {
		Position(32515, 31927, 7), -- Tree 01
		Position(32474, 31947, 7), -- Tree 02
		Position(32458, 31997, 7), -- Tree 03
	},
}
local TheNewFrontier = Storage.Quest.U8_54.TheNewFrontier

local beaverTrees = Action()

function beaverTrees.onUse(player, item, fromPosition, target, toPosition, isHotkey)
	-- CONFIRMED BUG (found in review): `and` binds tighter than `or` in Lua, so this previously read as
	-- "tree1 OR tree2 OR (tree3 AND Questline==5)" - the Questline gate silently applied to tree3 only.
	-- Parenthesized so all three trees require Questline==5, matching Mission 02's actual active window.
	if (toPosition == config.treesBeaver[1] or toPosition == config.treesBeaver[2] or toPosition == config.treesBeaver[3]) and player:getStorageValue(TheNewFrontier.Questline) == 5 then
		if toPosition == config.treesBeaver[1] and player:getStorageValue(TheNewFrontier.Mission02.Beaver1) < 1 then
			-- CONFIRMED BUG (found in review): reference confirms 4 Enraged Squirrels at this tree
			-- (32515, 31927, 7), not 3.
			for i = 1, 4 do
				position = toPosition
				Game.createMonster("enraged squirrel", position)
				toPosition:sendMagicEffect(CONST_ME_TELEPORT)
			end
			player:setStorageValue(TheNewFrontier.Mission02.Beaver1, 1)
			player:say("You have marked the tree, but you also angered the aquirrel family who lived on it!", TALKTYPE_MONSTER_SAY)
		elseif toPosition == config.treesBeaver[2] and player:getStorageValue(TheNewFrontier.Mission02.Beaver2) < 1 then
			-- CONFIRMED BUG (found in review): reference confirms 4 Wolves + 1 War Wolf at this tree
			-- (32474, 31947, 7), not 5 Wolves + 1 War Wolf.
			for i = 1, 4 do
				position = toPosition
				Game.createMonster("wolf", position)
				toPosition:sendMagicEffect(CONST_ME_TELEPORT)
			end
			Game.createMonster("war wolf", toPosition)
			toPosition:sendMagicEffect(CONST_ME_TELEPORT)
			player:setStorageValue(TheNewFrontier.Mission02.Beaver2, 1)
			player:say("You have marked the tree but it seems someone marked it already! He is not happy with your actions and he brought friends!", TALKTYPE_MONSTER_SAY)
		elseif toPosition == config.treesBeaver[3] and player:getStorageValue(TheNewFrontier.Mission02.Beaver3) < 1 then
			Game.createMonster("thieving squirrel", toPosition)
			toPosition:sendMagicEffect(CONST_ME_TELEPORT)
			player:setStorageValue(TheNewFrontier.Mission02.Beaver3, 1)
			player:say("You've marked the tree, but its former inhabitant has stolen your bait! Get it before it runs away!", TALKTYPE_MONSTER_SAY)
			item:remove()
		end
	end
	return true
end

beaverTrees:id(9843)
beaverTrees:register()
