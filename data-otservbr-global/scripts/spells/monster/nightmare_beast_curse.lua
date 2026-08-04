local spell = Spell("instant")

function spell.onCastSpell(creature, var)
	local hasCasted = Game.getStorageValue(Storage.Quest.U12_00.TheDreamCourts.DreamScarGlobal.LastBossCurse)

	-- CONFIRMED BLOCKER (found post-merge): this gate was "== 0", but Game.getStorageValue returns -1
	-- for a key that was never set (data/libs/functions/game.lua), and this global is only ever set to
	-- 0 from inside the curse-resolution paths themselves (creaturescripts_nightmareCurse.lua and
	-- actions_dreamcatcher_curse.lua) - both of which require a curse to already be active. That made
	-- it a chicken-and-egg deadlock: on any fresh server the value is -1 forever and the curse could
	-- never fire even once, so wiring the spell into monster.attacks (PR #25) was necessary but not
	-- sufficient. 1 = a curse is currently active (don't lay another); anything else = free to cast.
	if hasCasted <= 0 then
		local players = Game.getSpectators(creature:getPosition(), false, true, 14, 14, 14, 14)

		-- CONFIRMED BLOCKER (found post-merge): math.random(1, 0) raises "interval is empty" in Lua.
		-- This spell is cast on a timer, so it fires whenever the boss is alive - including after a
		-- party wipe, when no players remain in range - which would have thrown on every cast.
		if #players == 0 then
			return false
		end

		local randomNumber = math.random(1, #players)

		for _, k in pairs(players) do
			local player = Player(k)
			if player then
				player:setStorageValue(Storage.Quest.U12_00.TheDreamCourts.DreamScar.LastBossCurse, -1)
			end
		end

		local newPlayer = Player(players[randomNumber]:getId())

		newPlayer:registerEvent("nightmareCurse")
		newPlayer:setStorageValue(Storage.Quest.U12_00.TheDreamCourts.NightmareCurse, 1)
		newPlayer:setStorageValue(Storage.Quest.U12_00.TheDreamCourts.DreamScar.LastBossCurse, 1)
		newPlayer:sendTextMessage(MESSAGE_EVENT_ADVANCE, "The beast laid a terrible curse on you!")

		Game.setStorageValue(Storage.Quest.U12_00.TheDreamCourts.DreamScarGlobal.LastBossCurse, 1)
	end
end

spell:name("nightmare beast curse")
spell:words("###560")
spell:isAggressive(false)
spell:blockWalls(true)
spell:needTarget(true)
spell:needLearn(true)
spell:register()
