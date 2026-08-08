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

-- CORRECTED (re-audited): uid 1040 and 1041 are two DIFFERENT physical levers, not
-- interchangeable copies of the same one. Read-only OTBM connectivity proof (flood-fill
-- from each lever's tile, treating stone-wall items as blocking): uid 1041 (32862,32555,11)
-- is reachable only from north of the wall, connecting directly to the monument tile
-- (32858,32526,11) with zero overlap with the puzzle antechamber; uid 1040 (32862,32557,11)
-- is reachable only from south of the wall, in the antechamber with the six remote levers,
-- and never reaches the monument side. So 1041 is the INSIDE escape lever (for a player who
-- got trapped after the wall re-closed) and 1040 is the OUTSIDE puzzle-gate lever. Because
-- the two sides are physically disjoint except through the single wall tile this action
-- controls, an outside player has no way to reach uid 1041 without already having opened
-- the wall via uid 1040 first - the escape lever cannot be used to bypass the six-lever
-- requirement.
local gate = Action()
function gate.onUse(player, item, fromPosition, target, toPosition, isHotkey)
	if item.uid == 1041 then
		-- Inside escape lever: always reopens the wall so a trapped player can leave, even if
		-- the six remote levers have since reverted - those are unreachable from in here anyway.
		return wallRemove(player, item)
	end

	for i = 1, #config do
		if Tile(config[i].leverpos):getItemById(2772) then
			return player:say("It doesn't move.", TALKTYPE_MONSTER_SAY)
		end
	end
	return wallRemove(player, item)
end

gate:uid(1040, 1041)
gate:register()
