-- CONFIRMED BLOCKER (pre-existing): this is "The Revenge of the Ogres" mission's actual objective -
-- searching Dayyan's grave (the left/correct side, uid 57543; the trap side is actions_tumuloerro.lua,
-- uid 57544) - and it was a stub: it checked Thirteen.Presente (an entirely unrelated storage
-- belonging to Alyxo's "Boards that Mean the World" tortoise favor, evidently copy-pasted), never
-- granted anything, never advanced Fourteen.Remains past the value cagekey.lua already leaves it at
-- (3), and never let the mission's own report step (added to npc/saideh.lua) become reachable. The
-- mission's actual reward (20000 XP - see saideh.lua) is granted there, not here; this action's job is
-- only to correctly mark the grave as found.
local tumulo = Action()

function tumulo.onUse(player, item, frompos, item2, topos)
	if player:getStorageValue(Storage.Quest.U12_20.KilmareshQuest.Fourteen.Remains) == 3 then
		player:setStorageValue(Storage.Quest.U12_20.KilmareshQuest.Fourteen.Remains, 4)
		player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "You carefully search the left side of the grave and find the scattered remains of the hero Dayyan. This is what Saideh sent you to find.")
	elseif player:getStorageValue(Storage.Quest.U12_20.KilmareshQuest.Fourteen.Remains) > 3 then
		player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "You have already found what you were looking for here.")
	else
		player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "Empty.")
	end

	return true
end

tumulo:uid(57543)
tumulo:register()
