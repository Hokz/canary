-- Death Echo (15.25.3a4a52). Sorcerer, level 120, 150 mana, 6s cooldown.
--
-- Death damage in a 5x5; one second later the SAME area, at the same resolved
-- destination, is hit again for half. Base power 75 (the July balance value; the
-- release build had 85), in the datapack's level/magic-level form. The echo is
-- bound to the destination, not to the caster or a target: moving or changing floor
-- does not move it. Its damage never triggers charms.
--
-- Mana: the update's Sorcerer section says 155, its spell table says 150; the table
-- is used. Aiming: the update lists three modes (crosshair, cursor position, under
-- the character); this server has no client packet carrying a position for an
-- instant spell, so the spell is self-targeted and the area is centred on the
-- caster - FIDELITY_BLOCKER — TARGETING_PROTOCOL_EVIDENCE_REQUIRED.
function onGetFormulaValues(player, level, maglevel)
	local min = (level / 5) + (maglevel * 3.0)
	local max = (level / 5) + (maglevel * 4.9)
	return -min, -max
end

function onGetEchoFormulaValues(player, level, maglevel)
	local min, max = onGetFormulaValues(player, level, maglevel)
	return min * 0.5, max * 0.5
end

local combat = Combat()
combat:setParameter(COMBAT_PARAM_TYPE, COMBAT_DEATHDAMAGE)
combat:setParameter(COMBAT_PARAM_EFFECT, CONST_ME_MORTAREA)
combat:setArea(createCombatArea(AREA_CIRCLE2X2))
combat:setCallback(CALLBACK_PARAM_LEVELMAGICVALUE, "onGetFormulaValues")

local echo = Combat()
echo:setParameter(COMBAT_PARAM_TYPE, COMBAT_DEATHDAMAGE)
echo:setParameter(COMBAT_PARAM_EFFECT, CONST_ME_MORTAREA)
echo:setArea(createCombatArea(AREA_CIRCLE2X2))
echo:setParameter(COMBAT_PARAM_NOCHARM, true)
echo:setCallback(CALLBACK_PARAM_LEVELMAGICVALUE, "onGetEchoFormulaValues")

-- Where the first impact lands, read from the cast itself rather than assumed to be
-- the caster: a position variant is that position; a creature variant is that
-- creature's position; anything else is the caster's own position (this spell is
-- self-targeted, so today that is always the caster - but the echo is bound to the
-- resolved area, not to the caster, and this is what makes that true whichever
-- aiming mode the client sends).
local function castDestination(creature, var)
	local position = var:getPosition()
	if position and position.x ~= 0 then
		return position
	end
	local target = Creature(var:getNumber())
	if target then
		return target:getPosition()
	end
	return creature:getPosition()
end

local function secondImpact(playerId, position)
	-- If the caster is gone (logged out, dead) there is no echo: the combat needs
	-- a caster for its formula and its messages. Whether the official servers still
	-- deal the echo in that case is not proven; this is what this server does.
	local player = Player(playerId)
	if not player then
		return
	end
	echo:execute(player, Variant(position))
end

local spell = Spell("instant")

function spell.onCastSpell(creature, var)
	local destination = castDestination(creature, var)
	if not combat:execute(creature, Variant(destination)) then
		return false
	end
	-- The echo hits the same 5x5 at the same resolved destination one second later,
	-- wherever the caster or the target have moved to by then.
	addEvent(secondImpact, 1000, creature:getId(), destination)
	return true
end

spell:group("attack")
spell:id(305)
spell:name("Death Echo")
spell:words("exevo mort ora")
spell:level(120)
spell:mana(150)
spell:isPremium(true)
spell:isSelfTarget(true)
spell:cooldown(6 * 1000)
spell:groupCooldown(2 * 1000)
spell:vocation("sorcerer;true", "master sorcerer;true")
spell:register()
