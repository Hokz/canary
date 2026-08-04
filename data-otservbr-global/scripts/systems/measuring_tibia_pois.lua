-- Measuring Tibia - Point of Interest registration.
--
-- Registers one MoveEvent per candidate POI position (subarea.pois[i] in measuring_tibia_areas.lua).
-- A single global position trigger works correctly per-player because MeasuringTibia.discoverPoi
-- checks that specific player's own KV-stored "active" POI list before counting anything - stepping
-- on a POI that isn't currently active for you (or is already discovered by you) is a safe no-op, and
-- another player discovering the same physical spot doesn't affect your own progress.
--
-- With zero candidate POI positions filled in yet (every subarea.pois is currently {} - see the PR's
-- Map/POI Setup Contract), this loop registers ZERO MoveEvents: fully inert until real coordinates
-- exist, matching the same convention as measuring_tibia_zones.lua.
for _, area in ipairs(MeasuringTibiaAreas) do
	for _, subarea in ipairs(area.subareas) do
		for poiIndex, position in ipairs(subarea.pois) do
			local poi = MoveEvent()
			function poi.onStepIn(creature, item, position, fromPosition)
				local player = creature:getPlayer()
				if not player then
					return true
				end
				MeasuringTibia.discoverPoi(player, subarea, poiIndex)
				return true
			end
			poi:position(position)
			poi:register()
		end
	end
end
