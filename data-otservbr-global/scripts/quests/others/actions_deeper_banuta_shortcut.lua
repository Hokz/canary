local othersDeeper = Action()
function othersDeeper.onUse(player, item, fromPosition, target, toPosition, isHotkey)
	if target.actionid ~= 62378 then
		return false
	end

	if player:getStorageValue(Storage.BanutaSecretTunnel.DeeperBanutaShortcut) ~= 1 then
		-- CONFIRMED BUG (found in review): player:removeItem(9606, 1) searches only the
		-- player's own inventory/backpacks (Player::removeItemOfType), never the ground, and
		-- its return value was ignored. An egg used directly from the ground (a normal,
		-- engine-supported "use item on target" invocation) would grant the shortcut for free
		-- without consuming anything. item:remove(1) consumes the exact egg instance that was
		-- actually used, wherever it is, and its success is required before granting access.
		if not item:remove(1) then
			return false
		end
		player:setStorageValue(Storage.BanutaSecretTunnel.DeeperBanutaShortcut, 1)
		player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "You discovered a secret tunnel.")
		Position(32887, 32633, 11):sendMagicEffect(CONST_ME_WATERSPLASH)
	else
		player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "You have already discovered this secret.")
	end
	return true
end

othersDeeper:id(9606)
othersDeeper:register()
