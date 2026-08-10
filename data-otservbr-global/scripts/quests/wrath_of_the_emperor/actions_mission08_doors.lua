local doors = Action()
function doors.onUse(player, target)
	if not player then
		return true
	end

	-- MISSION08 ACCESS GATE (fail-closed, added since full pre-Mission08 map topology was not
	-- independently provable): no teleport for anyone who hasn't at least been assigned Mission08.
	-- >= 1 also covers state 2 ("already reached Zizzle"), so a returning player is never locked out.
	if player:getStorageValue(Storage.Quest.U8_6.WrathOfTheEmperor.Mission08) < 1 then
		player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "Nothing happens.")
		return true
	end

	local pos = player:getPosition()
	local tpos = target:getPosition()
	if pos.y == 31112 then
		player:teleportTo(Position(tpos.x, tpos.y - 1, 12))
		pos:sendMagicEffect(CONST_ME_POFF)
	else
		player:teleportTo(Position(tpos.x, tpos.y + 1, 12))
		pos:sendMagicEffect(CONST_ME_POFF)
	end
	return true
end

doors:id(11141)
doors:register()
