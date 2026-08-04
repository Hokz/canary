-- Measuring Tibia - Zone registration.
--
-- Creates one Zone per subarea (discovery-tracking trigger) and one combined Zone per parent area
-- (movement-speed-bonus trigger, union of that area's subareas' rectangles), but ONLY for
-- subareas that already have real fromPos/toPos coordinates in measuring_tibia_areas.lua. With zero
-- coordinates filled in (the current state - see the PR's Map/POI Setup Contract), this loop creates
-- ZERO Zone objects and registers ZERO ZoneEvents: fully inert, no server startup/memory cost, same
-- "nil position = inert code" convention used for every other position-dependent quest this session.
--
-- Scale note for whoever fills in real coordinates: Zone:addArea enumerates every individual tile
-- position into a global position->zone map (confirmed via src/game/zones/zone.cpp). The biggest
-- existing Zone in this repo (the Primal Ordeal hazard region) covers roughly 225k tile-positions
-- across 3 floors; 171 subareas covering the entire game world would be far beyond anything this
-- engine's Zone system has been exercised at. Recommend filling in and testing coordinates
-- incrementally (a few areas at a time) rather than all 171 subareas + 20 area-unions at once, and
-- watching server startup time/memory as they're added.
for _, area in ipairs(MeasuringTibiaAreas) do
	local areaZone = nil -- created lazily, only once this area has at least one real subarea rectangle

	for _, subarea in ipairs(area.subareas) do
		if subarea.fromPos and subarea.toPos then
			local zone = Zone(subarea.name)
			zone:addArea(subarea.fromPos, subarea.toPos)

			local event = ZoneEvent(zone)
			function event.afterEnter(_zone, creature)
				local player = creature:getPlayer()
				if not player then
					return
				end
				MeasuringTibia.ensureActivePois(player, subarea)
			end
			function event.afterLeave(_zone, creature)
				local player = creature:getPlayer()
				if not player then
					return
				end
				MeasuringTibia.onLeaveSubarea(player, subarea)
			end
			event:register()

			if not areaZone then
				areaZone = Zone(area.name .. " (Measuring Tibia)")
				MeasuringTibia.areaZoneByName[area.name] = areaZone
			end
			areaZone:addArea(subarea.fromPos, subarea.toPos)
		end
	end

	if areaZone then
		local event = ZoneEvent(areaZone)
		function event.afterEnter(_zone, creature)
			local player = creature:getPlayer()
			if not player then
				return
			end
			if MeasuringTibia.isAreaCompleted(player, area) then
				MeasuringTibia.applySpeedBonus(player, true)
			end
		end
		function event.afterLeave(_zone, creature)
			local player = creature:getPlayer()
			if not player then
				return
			end
			-- A player standing in overlapping completed areas simultaneously is not possible
			-- (parent areas don't overlap), so unconditionally clearing the bonus on leaving any
			-- one of them is correct - there's no other completed-area zone left to still be inside.
			MeasuringTibia.applySpeedBonus(player, false)
		end
		event:register()
	end
end
