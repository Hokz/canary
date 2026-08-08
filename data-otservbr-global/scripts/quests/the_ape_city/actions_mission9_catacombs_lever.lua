local config = {
	{ leverpos = Position(32891, 32590, 11) },
	{ leverpos = Position(32843, 32649, 11) },
	{ leverpos = Position(32808, 32613, 11) },
	{ leverpos = Position(32775, 32583, 11) },
	{ leverpos = Position(32756, 32494, 11) },
	{ leverpos = Position(32799, 32556, 11) },
}

local function revertLever(position)
	local leverItem = Tile(position):getItemById(2773)
	if leverItem then
		leverItem:transform(2772)
	end
end

local function revertWall(position)
	local wallItem = Tile(Position(32864, 32556, 11)):getItemById(1563)
	if not wallItem then
		Game.createItem(1563, 1, Position(32864, 32556, 11))
	end
end

local lever = Action()
function lever.onUse(player, item, fromPosition, target, toPosition, isHotkey)
	if item.itemid == 2773 then
		player:say("It doesn't move.", TALKTYPE_MONSTER_SAY)
		return true
	end
	addEvent(revertLever, 10 * 60 * 1000, toPosition)
	return item:transform(2773)
end

lever:aid(12129)
lever:register()

local function wallRemove(player, item)
	local wall = Tile(Position(32864, 32556, 11)):getItemById(1563)
	if wall then
		wall:remove()
		Position(32864, 32556, 11):sendMagicEffect(CONST_ME_MAGIC_RED)
		addEvent(revertWall, 10 * 1000, toPosition)
		return item:transform(item.itemid == 2772 and 2773 or 2772)
	else
		player:say("The lever won't budge", TALKTYPE_MONSTER_SAY)
		return true
	end
end

local gate = Action()
function gate.onUse(player, item, fromPosition, target, toPosition, isHotkey)
	-- CONFIRMED BUG (found in review): the loop returned on the FIRST unpulled lever it found,
	-- and if the item used was the uid=1041 lever, it called wallRemove right there regardless
	-- of the other 6 levers - letting a player skip the whole puzzle by using this lever first.
	-- Both physical lever#2 objects (uid 1040 and 1041) must require all 6 other levers pulled.
	for i = 1, #config do
		if Tile(config[i].leverpos):getItemById(2772) then
			return player:say("It doesn't move.", TALKTYPE_MONSTER_SAY)
		end
	end
	wallRemove(player, item)
	return true
end

gate:uid(1040, 1041)
gate:register()
