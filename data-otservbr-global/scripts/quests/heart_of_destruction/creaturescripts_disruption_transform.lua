local explodeExhaust = 12 --in seconds
local minionExhaust = {}

local function minionExplode(monster)
	if not monster:isMonster() then
		return false
	end

	local cid = monster:getId()
	local exhaust = minionExhaust[cid]
	if not exhaust then
		minionExhaust[cid] = 1
		return
	end

	if exhaust >= explodeExhaust then
		local monsterPos = monster:getPosition()
		-- CORRECTION (executor contract, section F): registered to the active final run - this is
		-- a new creature id, distinct from the "Disruption" that was already registered at spawn.
		HODFinalRunTrackMonster(Game.createMonster("Charged Disruption", monsterPos, false, true))
		monster:remove()
	else
		minionExhaust[cid] = exhaust + 1
	end
end

local disruptionTransform = CreatureEvent("DisruptionTransform")
function disruptionTransform.onThink(monster)
	minionExplode(monster)
end

disruptionTransform:register()
