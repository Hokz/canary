-- Rascacoon Trust Points / Supply Mission - striking a Disguised Rat only reveals it (into a
-- killable "Smelly Cheese" at the same position) if the attacker currently holds the shaman's
-- staff effect; otherwise the disguise holds and the hit does nothing.
local reveal = CreatureEvent("SupplyMissionRatRevealed")

function reveal.onHealthChange(creature, attacker, primaryDamage, primaryType, secondaryDamage, secondaryType, origin)
	if not attacker or not attacker:isPlayer() then
		return 0, primaryType, 0, secondaryType
	end
	local expiry = attacker:getStorageValue(Storage.Quest.U12_60.APiratesTail.Mission03.SupplyStaffExpiry)
	if expiry < os.time() then
		attacker:sendTextMessage(MESSAGE_EVENT_ADVANCE, "The rat scurries away from your attack - you need the shaman's staff to reveal it.")
		return 0, primaryType, 0, secondaryType
	end

	local position = creature:getPosition()
	creature:remove()
	Game.createMonster("Smelly Cheese", position, true, true)
	position:sendMagicEffect(CONST_ME_POFF)
	return 0, primaryType, 0, secondaryType
end

reveal:register()
