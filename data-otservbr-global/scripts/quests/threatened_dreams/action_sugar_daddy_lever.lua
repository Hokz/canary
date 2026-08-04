-- Sweet Dreams / Chocolate Mines - Sugar Daddy boss lever, and the Taffy Bunny (Cherry) chase in
-- the Dessert Dungeons. Simplification note: the reference's "candy fae spawn / hex debuff if not
-- killed" mechanic on Sugar Daddy is not implemented this pass (Sugar Daddy's existing, already
-- balanced stats/attacks were deliberately left untouched rather than risking an unbalanced new
-- debuff system with no reference numbers) - the fight itself is real and fully functional.
-- Map Setup Contract: aid 45741 = Sugar Daddy's portal lever; aid 45746 = the spot in the Dessert
-- Dungeons where the "tuft of spun pink sugar" clue is found; the Taffy Bunny monster itself
-- needs a spawn point in the same area (see PR report).
local ThreatenedDreams = Storage.Quest.U11_40.ThreatenedDreams

local sugarDaddyLever = Action()
function sugarDaddyLever.onUse(player, item, fromPosition, target, toPosition, isHotkey)
	if player:getStorageValue(ThreatenedDreams.Mission06[1]) ~= 11 then
		player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "Nothing happens.")
		return true
	end
	if not player:canFightBoss("Sugar Daddy") then
		player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "You have to wait to fight Sugar Daddy again.")
		return true
	end
	player:setBossCooldown("Sugar Daddy", os.time() + 20 * 3600)
	Game.createMonster("Sugar Daddy", toPosition, true, true)
	player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "Sugar Daddy appears from behind the portal!")
	toPosition:sendMagicEffect(CONST_ME_CANDY_FLOSS)
	return true
end

sugarDaddyLever:aid(45741)
sugarDaddyLever:register()

local sugarDaddyKill = CreatureEvent("SweetDreamsSugarDaddyKill")
function sugarDaddyKill.onDeath(creature)
	onDeathForDamagingPlayers(creature, function(creature, player)
		if player:getStorageValue(ThreatenedDreams.Mission06[1]) == 11 then
			player:setStorageValue(ThreatenedDreams.Mission06.SugarDaddyDefeated, 1)
			player:setStorageValue(ThreatenedDreams.Mission06[1], 12)
		end
	end)
	return true
end

sugarDaddyKill:register()

-- Cherry / Put the Cherry in the Cage.
local cherryClue = Action()
function cherryClue.onUse(player, item, fromPosition, target, toPosition, isHotkey)
	if player:getStorageValue(ThreatenedDreams.Mission06[1]) ~= 19 then
		player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "You find nothing of interest here.")
		return true
	end
	player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "You discover a tuft of spun pink sugar on the floor. Could the missing taffy bunny Cherry be down here?")
	return true
end

cherryClue:aid(45746)
cherryClue:register()

-- A Taffy Bunny cannot be caught (matches the reference's "too fast to catch" flavor) - any
-- player-sourced damage is blocked and instead marks Cherry as found.
local cherryFound = CreatureEvent("SweetDreamsCherryFound")
function cherryFound.onHealthChange(creature, attacker, primaryDamage, primaryType, secondaryDamage, secondaryType, origin)
	if attacker and attacker:isPlayer() then
		if attacker:getStorageValue(ThreatenedDreams.Mission06[1]) == 19 and attacker:getStorageValue(ThreatenedDreams.Mission06.CherryFound) < 1 then
			attacker:setStorageValue(ThreatenedDreams.Mission06.CherryFound, 1)
			attacker:sendTextMessage(MESSAGE_EVENT_ADVANCE, "Cherry hops away in a blur of spun sugar, far too quick for you to catch. At least you know she's safe down here!")
		end
		return 0, primaryType, 0, secondaryType
	end
	return primaryDamage, primaryType, secondaryDamage, secondaryType
end
cherryFound:register()
