local storage = Storage.Quest.U12_00.TheDreamCourts.BurriedCatedralGlobal.FacelessTiles

local function setActionId(itemid, position, aid)
	local item = Tile(position):getItemById(itemid)

	if item and item:getActionId() ~= aid then
		item:setActionId(aid)
	end
end

local facelessRoomPosition = Position(33617, 32563, 13)

-- CONFIRMED BUG (pre-existing): nothing anywhere re-locked the boss after the tile sequence was
-- completed once - the reference (and a forum correction specifically calling this out) both
-- describe a strict 60-second vulnerability window: if the boss isn't killed within it, the very
-- next hit heals it to full and the room re-locks, requiring the tiles to be walked again. Without
-- this, once a group finished the 5 tiles the boss would just stay damageable forever, with none of
-- the described time pressure or the "3 repeats, 10 minutes total" structure.
local function relockIfStillAlive()
	local spectators = Game.getSpectators(facelessRoomPosition, false, false, 10, 10, 10, 10)
	for _, c in pairs(spectators) do
		if c:isMonster() and c:getName():lower() == "faceless bane" then
			c:registerEvent("facelessHealth")
			c:say("HAAAAAAA!", TALKTYPE_MONSTER_SAY)
			break
		end
	end
end

local function isnotImmortal()
	local spectators = Game.getSpectators(facelessRoomPosition, false, false, 10, 10, 10, 10)

	for _, c in pairs(spectators) do
		if c:isMonster() then
			if c:getName():lower() == "faceless bane" then
				c:unregisterEvent("facelessHealth")
				addEvent(relockIfStillAlive, 60 * 1000)
			end
		end
	end
end

local movements_facelessTiles = MoveEvent()

function movements_facelessTiles.onStepIn(creature, item, position, fromPosition)
	local player = creature:getPlayer()

	if not player then
		return true
	end

	local isImmortal = Game.getStorageValue(storage)

	if isImmortal == 5 then
		Game.setStorageValue(storage, 0)
		creature:getPosition():sendMagicEffect(CONST_ME_HOLYAREA)
		isnotImmortal()
	elseif isImmortal < 0 then
		Game.setStorageValue(storage, 0)
	elseif isImmortal >= 0 and isImmortal < 5 then
		Game.setStorageValue(storage, isImmortal + 1)
		creature:getPosition():sendMagicEffect(CONST_ME_YELLOWENERGY)
		item:setActionId(0)
		addEvent(setActionId, (10 * 1000), item.itemid, position, 23108)
	end

	return true
end

movements_facelessTiles:aid(23108)
movements_facelessTiles:register()
