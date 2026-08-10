local depolarizedTransform = CreatureEvent("DepolarizedTransform")
function depolarizedTransform.onThink(creature)
	if not creature or not creature:isMonster() then
		return false
	end

	if cracklerTransform == false then
		local monster = Game.createMonster("Crackler", creature:getPosition(), false, true)
		if not monster then
			return true
		end
		monster:addHealth(-monster:getHealth() + creature:getHealth(), COMBAT_PHYSICALDAMAGE)
		creature:remove()
	end
	return true
end

depolarizedTransform:register()
