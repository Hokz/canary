local darkSoulDeath = CreatureEvent("DarkSoulDeath")

function darkSoulDeath.onDeath(creature, corpse, lasthitkiller, mostdamagekiller, lasthitunjustified, mostdamageunjustified)
	local killer = mostdamagekiller and mostdamagekiller:getPlayer() or (lasthitkiller and lasthitkiller:getPlayer())
	if killer then
		killer:addItem(25774, 1)
		killer:sendTextMessage(MESSAGE_EVENT_ADVANCE, "The dark soul dissipates, leaving behind its guilt.")
	end
	return true
end

darkSoulDeath:register()
