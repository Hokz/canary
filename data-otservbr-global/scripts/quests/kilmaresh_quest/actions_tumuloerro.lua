-- CONFIRMED BLOCKER (pre-existing): this is the RIGHT/wrong side of Dayyan's grave (uid 57544; the
-- correct left side is actions_tumulo.lua, uid 57543) - per the source it is a trap dealing ~50% of
-- the player's max HP as fire damage, and does NOT advance the mission. It was an identical
-- copy-pasted stub with no damage and no working storage check.
local tumuloerro = Action()

function tumuloerro.onUse(player, item, frompos, item2, topos)
	-- Uses RevengeOfTheOgres.Questline (stage 2+ = inside the dungeon past the cage key) instead of
	-- the old Fourteen.Remains - see the comment in npc/saideh.lua.
	if player:getStorageValue(Storage.Quest.U12_20.KilmareshQuest.RevengeOfTheOgres.Questline) >= 2 then
		local damage = math.floor(player:getMaxHealth() * 0.5)
		doTargetCombatHealth(0, player, COMBAT_FIREDAMAGE, -damage, -damage, CONST_ME_HITBYFIRE)
		player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "Flames burst from the right side of the grave, searing you badly! You should have searched the other side.")
	else
		player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "Empty.")
	end

	return true
end

tumuloerro:uid(57544)
tumuloerro:register()
