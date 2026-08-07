local monster = {
	["burning gladiator"] = Storage.Quest.U12_20.KilmareshQuest.Thirteen.Fafnar,
	["priestess of the wild sun"] = Storage.Quest.U12_20.KilmareshQuest.Thirteen.Fafnar,
}

local fafnar = CreatureEvent("FafnarMissionsDeath")

function fafnar.onDeath(creature, _corpse, _lastHitKiller, mostDamageKiller)
	local storage = monster[creature:getName():lower()]
	if not storage then
		return false
	end

	-- CONFIRMED BUG (pre-existing): the old cap check was "kills == 300 and kills == 1" - impossible
	-- for a single value to satisfy both, so it could never be true and the increment below ran
	-- unconditionally on every kill. Since Alyxo's turn-in check (npc/alyxo.lua) is a strict
	-- "== 300", any player who kept fighting past the 300th cultist would overshoot the storage past
	-- 300 and permanently lose the ability to report - there was no way back except a GM storage
	-- edit. Capping the increment at 300 (paired with the accept-time baseline fix to 0, see
	-- alyxo.lua) makes the counter land on exactly 300 and stay there.
	onDeathForParty(creature, mostDamageKiller, function(creature, player)
		local kills = player:getStorageValue(storage)
		if kills < 0 then
			kills = 0
		end

		if kills >= 300 then
			player:say("You slayed " .. creature:getName() .. ".", TALKTYPE_MONSTER_SAY)
		else
			kills = kills + 1
			player:say("You have slayed " .. creature:getName() .. " " .. kills .. " times!", TALKTYPE_MONSTER_SAY)
			player:setStorageValue(storage, kills)
		end
	end)

	return true
end

fafnar:register()
