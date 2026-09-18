function Combat:getPositions(creature, variant)
	local positions = {}
	function onTargetTile(creature, position)
		positions[#positions + 1] = position
	end

	self:setCallback(CALLBACK_PARAM_TARGETTILE, "onTargetTile")
	self:execute(creature, variant)
	return positions
end

function Combat:getTargets(creature, variant)
	local targets = {}
	function onTargetCreature(creature, target)
		targets[#targets + 1] = target
	end

	self:setCallback(CALLBACK_PARAM_TARGETCREATURE, "onTargetCreature")
	self:execute(creature, variant)
	return targets
end

-- Beam Mastery's adjacent-square damage (post-July): the two one-tile-wide lines
-- immediately left and right of the central beam. The central beam itself is NOT part
-- of these areas, so a creature standing on the beam is hit exactly once.
--
-- The caster's tile carries 2, the "centre, no damage" marker, not 3. createCombatArea
-- treats 3 as centre AND damage, which would put a flank hit on the caster's own tile;
-- 2 anchors the rotation without adding a damage cell there.
--
-- Cardinal, length N: rows 1..N-1 are { 1, 0, 1 } and row N is { 0, 2, 0 }.
--
--   X . X
--   X . X      X = flank damage      . = the central beam, its own Combat
--   X . X      0 = nothing           P = caster, no flank damage
--   0 P 0
--
-- Diagonal, length N: the normal diagonal beam runs down the main diagonal with the
-- caster in the last cell, so the flanks are the cells immediately above and below it -
-- the super-diagonal (i, i+1) and the sub-diagonal (i+1, i). Both are edge-adjacent to
-- the central cell (i, i).
function buildBeamMasteryFlankAreas(length)
	assert(type(length) == "number" and length >= 2, "flank areas need a beam length of at least 2")

	local cardinal = {}
	for _ = 1, length - 1 do
		table.insert(cardinal, { 1, 0, 1 })
	end
	table.insert(cardinal, { 0, 2, 0 })

	local diagonal = {}
	for _ = 1, length do
		local row = {}
		for _ = 1, length do
			table.insert(row, 0)
		end
		table.insert(diagonal, row)
	end
	for i = 1, length - 1 do
		diagonal[i][i + 1] = 1
		diagonal[i + 1][i] = 1
	end
	diagonal[length][length] = 2

	return cardinal, diagonal
end
