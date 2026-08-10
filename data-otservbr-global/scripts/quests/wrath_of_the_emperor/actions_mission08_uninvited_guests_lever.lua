local config = {
	[3184] = Position(33082, 31110, 2),
	[3185] = Position(33078, 31080, 13),
}

local Mission08 = Storage.Quest.U8_6.WrathOfTheEmperor.Mission08

local wrathEmperorMiss8Uninvited = Action()
function wrathEmperorMiss8Uninvited.onUse(player, item, fromPosition, target, toPosition, isHotkey)
	local targetPosition = config[item.uid]
	if not targetPosition then
		return true
	end

	-- MISSION08 ACCESS GATE (fail-closed, added since full pre-Mission08 map topology was not
	-- independently provable): no transform (lever progression) and no teleport for anyone who
	-- hasn't at least been assigned Mission08. >= 1 also covers state 2 ("already reached Zizzle"),
	-- so a returning player is never locked out.
	if player:getStorageValue(Mission08) < 1 then
		player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "Nothing happens.")
		return true
	end

	item:transform(item.itemid == 2772 and 2773 or 2772)

	toPosition.y = toPosition.y + 1
	local creature = Tile(toPosition):getTopCreature()
	if not creature or not creature:isPlayer() then
		return true
	end

	if item.itemid ~= 2772 then
		return true
	end

	-- The lever can move a DIFFERENT creature than the one who pulled it (whoever is standing on
	-- the platform at toPosition) - gate that creature's own eligibility too, so a bystander
	-- standing there cannot be teleported even if the puller is legitimate.
	if creature:getStorageValue(Mission08) < 1 then
		return true
	end

	creature:getPosition():sendMagicEffect(CONST_ME_TELEPORT)
	creature:teleportTo(targetPosition)
	targetPosition:sendMagicEffect(CONST_ME_TELEPORT)
	return true
end

wrathEmperorMiss8Uninvited:uid(3184, 3185)
wrathEmperorMiss8Uninvited:register()
