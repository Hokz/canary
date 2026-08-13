local deskPosition = Position(32743, 32689, 10)

-- CORRECTION (Secret Library repair v2, section 14.1): rebuilt against LokathmorRun instead of the
-- previous name/speed-based "isStuck()" lookup, which replaced Lokathmor with a fresh instance
-- unconditionally (c:remove() ran even if the new Game.createMonster call failed) and swept every
-- monster in the world named "force field" rather than only this run's own current-generation ones.
-- Also fixes a real registration bug: this file previously declared a bare global `function onUse(...)`
-- instead of `function actions_library_parchment.onUse(...)`, so the Action object's own onUse
-- callback was never actually set - this handler could never have fired at all.
local actions_library_parchment = Action()

function actions_library_parchment.onUse(player, item, fromPosition, target, toPosition, isHotkey)
	if toPosition ~= deskPosition then
		return true
	end

	local token = LokathmorRunCurrentToken()
	if not token or not LokathmorRunIsParticipant(token, player:getId()) then
		player:sendCancelMessage("This is not your attempt.")
		return true
	end
	if not LokathmorRunIsTrapped(token) then
		return true
	end

	local itemToken = item:getCustomAttribute("LokathmorRunToken")
	local itemGeneration = item:getCustomAttribute("LokathmorGeneration")
	local currentGeneration = LokathmorRunCurrentGeneration()
	if itemToken ~= token or not currentGeneration or itemGeneration ~= currentGeneration then
		player:sendCancelMessage("This parchment's power has already faded.")
		return true
	end

	local boss = Creature(LokathmorRun.bossId)
	if not boss or not LokathmorRunOwnsBoss(boss) then
		return true
	end

	player:say("THE DARK KNOWLEDGE FILLS THE BOOK WITH RAW POWER. READY TO BE UNLEASHED!", TALKTYPE_MONSTER_SAY)
	boss:say("THE DISCHARGE OF THE BOOK BREAKS LOKATHMOR'S STANCE!", TALKTYPE_MONSTER_SAY)

	-- CORRECTION (section 14.1): removes only this run's own current-generation Force Fields (never a
	-- global name sweep), restores the boss's mobility/vulnerability in place (no replacement-monster
	-- swap needed - true invulnerability/immobility are both native, reversible states here, so there
	-- is no HP-transfer/creation-failure risk to guard against).
	for creatureId in pairs(LokathmorRun.forceFieldIds) do
		local field = Creature(creatureId)
		if field then
			field:remove()
		end
	end
	LokathmorRun.forceFieldIds = {}
	LokathmorRun.darkKnowledgeIds = {}
	LokathmorRun.trapped = false
	boss:immune(false)
	boss:setSpeed(boss:getBaseSpeed())

	item:remove(1)

	return true
end

actions_library_parchment:id(28488)
actions_library_parchment:register()
