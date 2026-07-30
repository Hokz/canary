-- Heart of Destruction: permanent vortex route access.
-- Killing 10 of a route's themed creature grants permanent access to that route's vortex,
-- independent of whether that route's vortex is currently the "active" one (see
-- globalevents_vortex_rotation.lua).

local HOD = Storage.Quest.U10_94.HeartOfDestruction

local routeByMonster = {
	["dread intruder"] = { killStorage = HOD.AnkrahmunKills, permanentStorage = HOD.AnkrahmunPermanent, routeName = "Ankrahmun" },
	["breach brood"] = { killStorage = HOD.SvargrondKills, permanentStorage = HOD.SvargrondPermanent, routeName = "Svargrond" },
	["reality reaver"] = { killStorage = HOD.ZaoKills, permanentStorage = HOD.ZaoPermanent, routeName = "Zao" },
}

local vortexRouteKills = CreatureEvent("HeartOfDestructionVortexKills")
function vortexRouteKills.onDeath(creature, corpse, killer, mostDamageKiller, unjustified, mostDamageUnjustified)
	if not creature or not creature:isMonster() then
		return true
	end

	local route = routeByMonster[creature:getName():lower()]
	if not route then
		return true
	end

	local player = mostDamageKiller and mostDamageKiller:getPlayer() or (killer and killer:getPlayer())
	if not player then
		return true
	end

	if player:getStorageValue(route.permanentStorage) >= 1 then
		return true
	end

	local kills = math.max(player:getStorageValue(route.killStorage), 0) + 1
	player:setStorageValue(route.killStorage, kills)

	if kills >= 10 then
		player:setStorageValue(route.permanentStorage, 1)
		player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "You have proven yourself against the forces of " .. route.routeName .. "'s incursion. You now have permanent access to this vortex.")
	end

	return true
end

vortexRouteKills:register()
