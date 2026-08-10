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
	-- CORRECTION (owner reference: the active portal changes every 2 hours): math.random(1, 3) could
	-- reselect the already-active route, meaning a rotation tick could produce no visible change at
	-- all. Every tick now picks one of the OTHER two routes - no deterministic sequence is assumed,
	-- since the owner reference doesn't prove one, only that it "changes."
	local current = Game.getStorageValue(GlobalStorage.HeartOfDestruction.ActiveVortex)
	local candidates = {}
	for routeId = 1, 3 do
		if routeId ~= current then
			candidates[#candidates + 1] = routeId
		end
	end
	Game.setStorageValue(GlobalStorage.HeartOfDestruction.ActiveVortex, candidates[math.random(1, #candidates)])
	return true
end
vortexRotation:interval(VORTEX_ROTATION_INTERVAL)
vortexRotation:register()
