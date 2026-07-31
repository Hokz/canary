local positions = {
	[1] = { pos = Position(31975, 32856, 15), nextPos = Position(31975, 32839, 15) },
	[2] = { pos = Position(31975, 32839, 15), nextPos = Position(31995, 32839, 15) },
	[3] = { pos = Position(31995, 32839, 15), nextPos = Position(31995, 32856, 15) },
	[4] = { pos = Position(31995, 32856, 15), nextPos = Position(31975, 32856, 15) },
}

local astralPower = CreatureEvent("BoundAstralPowerDeath")
function astralPower.onDeath(creature, _corpse, _lastHitKiller, mostDamageKiller)
	Game.setStorageValue(Storage.Quest.U11_02.ForgottenKnowledge.AstralPowerCounter, Game.getStorageValue(Storage.Quest.U11_02.ForgottenKnowledge.AstralPowerCounter) + 1)
	if Game.getStorageValue(Storage.Quest.U11_02.ForgottenKnowledge.AstralPowerCounter) >= 4 then
		Game.setStorageValue(Storage.Quest.U11_02.ForgottenKnowledge.AstralPowerCounter, 1)
	end

	local msg = "The destruction of the power source gained you more time until the glyph is powered up!"
	local player = Player(mostDamageKiller)
	if not player then
		return true
	end
	for i = 1, #positions do
		if player:getPosition():getDistance(positions[i].pos) < 7 then
			creature:say(msg, TALKTYPE_MONSTER_SAY, false, nil, positions[i].pos)
			Game.createMonster("bound astral power", positions[i].nextPos, true, true)
			Game.setStorageValue(Storage.Quest.U11_02.ForgottenKnowledge.AstralGlyph, 1)
			addEvent(Game.setStorageValue, 1 * 60 * 1000, Storage.Quest.U11_02.ForgottenKnowledge.AstralGlyph, 0)

			-- Give the room's failsafe timer real teeth behind the "gained you more time" message:
			-- each power kill refreshes the room's timeout instead of leaving it purely cosmetic.
			local bossLever = BossLever["the last lore keeper"]
			if bossLever then
				if bossLever.timeoutEvent then
					stopEvent(bossLever.timeoutEvent)
				end
				local zone = bossLever:getZone()
				bossLever.timeoutEvent = addEvent(function(zn)
					zn:refresh()
					zn:removePlayers()
				end, bossLever.timeToDefeat * 1000, zone)
			end
		end
	end
	return true
end

astralPower:register()
