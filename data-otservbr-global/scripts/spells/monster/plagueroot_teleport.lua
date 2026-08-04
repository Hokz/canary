local combat = Combat()
combat:setParameter(COMBAT_PARAM_TYPE, COMBAT_EARTHDAMAGE)
combat:setParameter(COMBAT_PARAM_EFFECT, CONST_ME_SMALLPLANTS)

combat:setArea(createCombatArea({
	{ 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0 },
	{ 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0 },
	{ 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0 },
	{ 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0 },
	{ 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0 },
	{ 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0 },
	{ 1, 1, 1, 1, 1, 1, 3, 1, 1, 1, 1, 1, 1 },
	{ 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0 },
	{ 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0 },
	{ 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0 },
	{ 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0 },
	{ 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0 },
	{ 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0 },
}))

function spellCallbackPlaguerootTeleport(param) end

function onTargetTilePlaguerootTeleport(cid, pos)
	local param = {}

	param.cid = cid
	param.pos = pos
	param.count = 0
	spellCallbackPlaguerootTeleport(param)
end

setCombatCallback(combat, CALLBACK_PARAM_TARGETTILE, "onTargetTilePlaguerootTeleport")

-- CONFIRMED BUG (found post-merge): the search loop below was completely unbounded - it kept
-- re-rolling until it happened to find a valid tile, with no iteration cap, so if no valid
-- destination existed in range it would spin forever and hang the server thread. It also could fall
-- out of the loop holding an invalid tile and still teleport onto it, since the old post-loop check
-- only tested "if tile then" (non-nil) rather than re-testing validity. Latent until PR #25 wired
-- this spell into monster.attacks - it had never once been cast before that.
local function isInvalidDestination(tile)
	return not tile or tile:getItemByType(ITEM_TYPE_TELEPORT) or not tile:getGround() or tile:hasFlag(TILESTATE_BLOCKPATH) or tile:hasFlag(TILESTATE_PROTECTIONZONE) or tile:hasFlag(TILESTATE_BLOCKSOLID)
end

local function teleportMonster(creature, centerPos, fromPos, toPos)
	local position = Position(math.random(fromPos.x, toPos.x), math.random(fromPos.y, toPos.y), centerPos.z)
	local tile = Tile(position)
	local count = 1

	while (isInvalidDestination(tile) or count < 5) and count < 100 do
		position = Position(math.random(fromPos.x, toPos.x), math.random(fromPos.y, toPos.y), centerPos.z)
		tile = Tile(position)
		count = count + 1
	end

	if not isInvalidDestination(tile) and position:isInRange(Position(32199, 32039, 14), Position(32216, 32057, 14)) then
		creature:getPosition():sendMagicEffect(CONST_ME_POFF)
		creature:teleportTo(position)
		Position(position):sendMagicEffect(CONST_ME_TELEPORT)
	end
end

local spell = Spell("instant")

function spell.onCastSpell(creature, var)
	if not creature:isMonster() then
		return false
	end

	local centerPos = creature:getPosition()
	local fromPos = { x = centerPos.x - 7, y = centerPos.y - 5, z = centerPos.z }
	local toPos = { x = centerPos.x + 7, y = centerPos.y + 5, z = centerPos.z }

	creature:say("PLAGUEROOT TUNNELS TO ANOTHER PLACE!", TALKTYPE_MONSTER_SAY)
	teleportMonster(creature, centerPos, fromPos, toPos)

	var = { type = 2, pos = { x = creature:getPosition().x, y = creature:getPosition().y, z = creature:getPosition().z } }

	combat:execute(creature, var)

	addEvent(function()
		if creature then
			var = { type = 2, pos = { x = creature:getPosition().x, y = creature:getPosition().y, z = creature:getPosition().z } }
			combat:execute(creature, var)
		end
	end, 2 * 1000)

	return true
end

spell:name("plagueroot teleport")
spell:words("###558")
spell:isAggressive(false)
spell:blockWalls(true)
spell:needTarget(false)
spell:needLearn(true)
spell:register()
