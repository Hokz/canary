local onBossDeath = CreatureEvent("BossLeverOnDeath")

function onBossDeath.onDeath(creature)
	if not creature then
		return true
	end

	local name = creature:getName()
	local key = "boss." .. toKey(name)
	local zone = Zone(key)

	if not zone then
		return true
	end

	local bossLever = BossLever[name:lower()]
	if not bossLever then
		return true
	end

	-- Guards against double-cleanup: already handled by an empty-room reset, or a duplicate onDeath call.
	if not bossLever.bossAlive then
		return true
	end
	bossLever.bossAlive = false

	if bossLever.emptyRoomEvent then
		stopEvent(bossLever.emptyRoomEvent)
		bossLever.emptyRoomEvent = nil
	end

	if bossLever.timeoutEvent then
		stopEvent(bossLever.timeoutEvent)
		bossLever.timeoutEvent = nil
	end

	if bossLever.timeAfterKill > 0 then
		zone:sendTextMessage(MESSAGE_EVENT_ADVANCE, "The " .. name .. " has been defeated. You have " .. bossLever.timeAfterKill .. " seconds to leave the room.")
		bossLever.timeoutEvent = addEvent(function(zn)
			zn:refresh()
			zn:cleanRoom()
			zn:removePlayers()
		end, bossLever.timeAfterKill * 1000, zone)
	else
		zone:refresh()
		zone:cleanRoom()
	end
	onDeathForDamagingPlayers(creature, function(creature, player)
		player:takeScreenshot(SCREENSHOT_TYPE_BOSSDEFEATED)
	end)
	return true
end

onBossDeath:register()
