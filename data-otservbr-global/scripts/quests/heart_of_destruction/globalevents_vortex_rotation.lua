-- Heart of Destruction: rotating outer vortex access.
-- ActiveVortex: 1 = Ankrahmun (Anomaly route), 2 = Svargrond (Realityquake route), 3 = Zao (Rupture route).
-- Rotates randomly on a fixed interval. Players with permanent route access (10 kills, see
-- creaturescripts_vortex_route_kills.lua) can use any route's vortex regardless of which is
-- currently active; players without permanent access can only use the currently active one.

local VORTEX_ROTATION_INTERVAL = 2 * 60 * 60 * 1000 -- 2 hours

local vortexRotationStartup = GlobalEvent("HeartOfDestructionVortexStartup")
function vortexRotationStartup.onStartup()
	if Game.getStorageValue(GlobalStorage.HeartOfDestruction.ActiveVortex) <= 0 then
		Game.setStorageValue(GlobalStorage.HeartOfDestruction.ActiveVortex, math.random(1, 3))
	end
	return true
end
vortexRotationStartup:register()

local vortexRotation = GlobalEvent("HeartOfDestructionVortexRotation")
function vortexRotation.onThink(interval)
	Game.setStorageValue(GlobalStorage.HeartOfDestruction.ActiveVortex, math.random(1, 3))
	return true
end
vortexRotation:interval(VORTEX_ROTATION_INTERVAL)
vortexRotation:register()
