-- Measuring Tibia (World Discovery / Discoverer outfit) - core logic.
--
-- Modern (11.80+) behavior per owner clarification: every character is eligible automatically, no
-- NPC/keyword start is required. Discovery tracking activates the moment a player enters a subarea
-- that isn't fully discovered yet (see scripts/systems/measuring_tibia_zones.lua's ZoneEvent hooks,
-- and measuring_tibia_pois.lua's per-POI MoveEvents, both of which call into this file).
--
-- Persistence: per-subarea/per-POI state is stored in the player KV store
-- (player:kv():scoped("measuring-tibia")), NOT flat numeric storages - this repo's own achievement
-- system (PlayerAchievement::getUnlockedKV) and quest tracker (Player.saveTrackedMissions) already
-- use exactly this pattern for equally-granular per-player state, and it's DB-backed (survives
-- relog/restart, confirmed via src/kv/kv_sql.cpp), unlike a plain Lua table. A handful of cheap,
-- frequently-read summary flags (Charos reward gates, completed-area counter, applied speed delta)
-- live in real numeric storages (Storage.Quest.U11_80.DiscovererOutfits / MeasuringTibia).
MeasuringTibia = {}

MeasuringTibia.REQUIRED_ACTIVE_POIS = 10
MeasuringTibia.REQUIRED_DISCOVERED_POIS = 7
MeasuringTibia.OUTFIT_LOOKTYPE_MALE = 1095
MeasuringTibia.OUTFIT_LOOKTYPE_FEMALE = 1094

-- Movement Speed Bonus Contract: the PDF states the bonus "grows from 100 to 195 speed points" as
-- more areas are fully discovered, with no exact per-area curve given (no table, no formula - just
-- the two endpoints). Modeled as a disclosed, linear interpolation between 1 completed area (100)
-- and all 20 (195), 0 completed areas = no bonus. This is an ACCEPTABLE_GLOBAL_LIKE interpolation
-- of the two confirmed endpoints, not a fabricated mechanic - flagged in the PR's Speed Bonus
-- Contract table for owner validation against the real per-area curve if that's ever sourced.
MeasuringTibia.SPEED_BONUS_MIN = 100
MeasuringTibia.SPEED_BONUS_MAX = 195
MeasuringTibia.TOTAL_AREAS = #MeasuringTibiaAreas

local function kv(player)
	return player:kv():scoped("measuring-tibia")
end

local function subareaKV(player, subareaName)
	return kv(player):scoped("subareas"):scoped(subareaName)
end

local function areaKV(player, areaName)
	return kv(player):scoped("areas"):scoped(areaName)
end

-- Lookup tables built once at load time from MeasuringTibiaAreas (lib/quests/measuring_tibia_areas.lua)

MeasuringTibia.subareaToArea = {} -- subarea name -> parent area table
MeasuringTibia.subareaByName = {} -- subarea name -> subarea table
MeasuringTibia.subareaByNameLower = {} -- lowercased subarea name -> subarea table (for !discovery reset)
MeasuringTibia.areaByName = {} -- parent area name -> parent area table
for _, area in ipairs(MeasuringTibiaAreas) do
	MeasuringTibia.areaByName[area.name] = area
	for _, subarea in ipairs(area.subareas) do
		MeasuringTibia.subareaToArea[subarea.name] = area
		MeasuringTibia.subareaByName[subarea.name] = subarea
		MeasuringTibia.subareaByNameLower[subarea.name:lower()] = subarea
	end
end

-- Returns the list of POI indices (1-based, into subarea.pois) currently active for this player,
-- generating and persisting a fresh random selection the first time this subarea is encountered.
-- Does nothing (returns an empty list) if the subarea has no candidate POI positions yet - see the
-- Map/POI Setup Contract, this keeps the whole system a safe no-op until real coordinates exist.
function MeasuringTibia.ensureActivePois(player, subarea)
	if #subarea.pois == 0 then
		return {}
	end
	local scope = subareaKV(player, subarea.name)
	if scope:get("completed") then
		return {}
	end
	local active = scope:get("active")
	if active and #active > 0 then
		return active
	end
	active = MeasuringTibia.rollActivePois(subarea)
	scope:set("active", active)
	if not scope:get("discovered") then
		scope:set("discovered", {})
	end
	return active
end

-- Random selection is per-subarea/per-player (fresh math.random draw against that subarea's own
-- candidate pool only) - no shared/global RNG state, so no cross-player contamination is possible.
function MeasuringTibia.rollActivePois(subarea)
	local pool = {}
	for i = 1, #subarea.pois do
		pool[i] = i
	end
	local picked = {}
	local count = math.min(MeasuringTibia.REQUIRED_ACTIVE_POIS, #pool)
	for _ = 1, count do
		local index = math.random(1, #pool)
		picked[#picked + 1] = pool[index]
		table.remove(pool, index)
	end
	return picked
end

function MeasuringTibia.isSubareaCompleted(player, subarea)
	return subareaKV(player, subarea.name):get("completed") == true
end

function MeasuringTibia.isAreaCompleted(player, area)
	return areaKV(player, area.name):get("completed") == true
end

-- Called on stepping onto/near an active, undiscovered POI. Safe to call repeatedly (idempotent) -
-- a POI already marked discovered, or one not currently active for this player, is a no-op so
-- stepping on the same spot twice (or a POI another player already discovered, which does not
-- affect this player's own state) never double-counts or duplicates completion.
function MeasuringTibia.discoverPoi(player, subarea, poiIndex)
	if MeasuringTibia.isSubareaCompleted(player, subarea) then
		return
	end
	local scope = subareaKV(player, subarea.name)
	local active = scope:get("active") or {}
	local isActive = false
	for _, index in ipairs(active) do
		if index == poiIndex then
			isActive = true
			break
		end
	end
	if not isActive then
		return
	end
	local discovered = scope:get("discovered") or {}
	for _, index in ipairs(discovered) do
		if index == poiIndex then
			return -- already discovered, no-op
		end
	end
	discovered[#discovered + 1] = poiIndex
	scope:set("discovered", discovered)

	local required = subarea.requiredDiscovered or MeasuringTibia.REQUIRED_DISCOVERED_POIS
	if #discovered >= required then
		MeasuringTibia.completeSubarea(player, subarea)
		return
	end
	-- CUSTOM_GLOBAL_LIKE_QUESTLOG_PENDING_EXACT_REFERENCE: real Tibia shows per-POI progress
	-- visually (a marker turning gold on the Cyclopedia World Map), not as a text message - the PDF
	-- gives no exact wording for an equivalent text notification. Since that client-side map isn't
	-- implemented here (see the PR's Client UI Gap note), this text line substitutes for it so a
	-- player isn't left with zero feedback between individual POI finds and the subarea-complete
	-- message.
	player:sendTextMessage(MESSAGE_EVENT_ADVANCE, ("You have discovered a new landmark in %s! (%d/%d)"):format(subarea.name, #discovered, required))
end

function MeasuringTibia.completeSubarea(player, subarea)
	local scope = subareaKV(player, subarea.name)
	if scope:get("completed") then
		return
	end
	scope:set("completed", true)
	scope:remove("active")
	player:sendTextMessage(MESSAGE_EVENT_ADVANCE, ("Congratulations! You discovered subarea %s completely!"):format(subarea.name))

	local area = MeasuringTibia.subareaToArea[subarea.name]
	if not area then
		return
	end
	MeasuringTibia.checkAreaCompletion(player, area)
end

function MeasuringTibia.checkAreaCompletion(player, area)
	if MeasuringTibia.isAreaCompleted(player, area) then
		return
	end
	for _, subarea in ipairs(area.subareas) do
		if not MeasuringTibia.isSubareaCompleted(player, subarea) then
			return
		end
	end
	areaKV(player, area.name):set("completed", true)
	if area.achievement and not player:hasAchievement(area.achievement) then
		player:addAchievement(area.achievement)
	end

	local completedCount = player:getStorageValue(Storage.Quest.U11_80.MeasuringTibia.CompletedAreaCount)
	if completedCount < 0 then
		completedCount = 0
	end
	completedCount = completedCount + 1
	player:setStorageValue(Storage.Quest.U11_80.MeasuringTibia.CompletedAreaCount, completedCount)
	player:sendTextMessage(MESSAGE_EVENT_ADVANCE, ("Awesome! You have already discovered %d areas completely!"):format(completedCount))
	if completedCount == 10 then
		player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "Go and find Charos. He might have a little reward for such an ambitious discoverer as you.")
	end

	-- The player is necessarily standing inside this area right now (they just discovered one of
	-- its subareas' last POI) - apply the (now recalculated, possibly higher-cap) bonus directly
	-- rather than waiting for the next zone-enter, matching "recalculates on ... area completion".
	MeasuringTibia.applySpeedBonus(player, true)
end

-- Server Log message on leaving an incomplete subarea, per the PDF's exact described behavior
-- ("Jeśli wychodzimy z podobszaru, który nie został odkryty w pełni ... zobaczymy odpowiedni komunikat
-- ... o wyjściu ze strefy" - if we leave a subarea that hasn't been fully discovered, we see an
-- appropriate message about leaving the zone). Completed subareas leave silently - matches "no stale
-- objectives", there's nothing left to report once a subarea is already done.
--
-- CUSTOM_GLOBAL_LIKE_QUESTLOG_PENDING_EXACT_REFERENCE: the PDF confirms this message exists and
-- describes its purpose, but gives no exact wording (unlike the subarea-complete message, which is
-- directly forum-confirmed verbatim) - the line below is a disclosed, Global-like approximation.
function MeasuringTibia.onLeaveSubarea(player, subarea)
	if MeasuringTibia.isSubareaCompleted(player, subarea) then
		return
	end
	local scope = subareaKV(player, subarea.name)
	local discovered = scope:get("discovered") or {}
	local required = subarea.requiredDiscovered or MeasuringTibia.REQUIRED_DISCOVERED_POIS
	player:sendTextMessage(MESSAGE_EVENT_ADVANCE, ("You leave the discovery zone of %s. Discovered points of interest: %d/%d."):format(subarea.name, #discovered, required))
end

-- Movement Speed Bonus Contract: linear interpolation between the PDF's two confirmed endpoints
-- (see the module-level comment above). changeSpeed(delta) is relative, so the previously-applied
-- delta is tracked in a storage and diffed against the new target, avoiding stacking on repeated
-- calls (recalculation is idempotent no matter how many times it's triggered).
function MeasuringTibia.calculateSpeedBonus(completedAreaCount)
	if completedAreaCount <= 0 then
		return 0
	end
	if completedAreaCount >= MeasuringTibia.TOTAL_AREAS then
		return MeasuringTibia.SPEED_BONUS_MAX
	end
	local progress = (completedAreaCount - 1) / (MeasuringTibia.TOTAL_AREAS - 1)
	local bonus = MeasuringTibia.SPEED_BONUS_MIN + progress * (MeasuringTibia.SPEED_BONUS_MAX - MeasuringTibia.SPEED_BONUS_MIN)
	return math.floor(bonus + 0.5)
end

-- OWNER_DECISION_ENGINE_SUPPORT_REQUIRED note (see PR body): real Measuring Tibia only grants this
-- bonus while standing on already-discovered terrain, not globally. That precise area-gating is
-- implemented here via the same completed-parent-area Zones used for discovery detection
-- (scripts/systems/measuring_tibia_zones.lua's afterEnter/afterLeave on each area's combined Zone,
-- toggling the delta on/off) - this function only computes and applies/removes the CURRENT delta,
-- it does not decide when the player is inside a completed area.
function MeasuringTibia.applySpeedBonus(player, active)
	local target = active and MeasuringTibia.calculateSpeedBonus(player:getStorageValue(Storage.Quest.U11_80.MeasuringTibia.CompletedAreaCount)) or 0
	local applied = player:getStorageValue(Storage.Quest.U11_80.MeasuringTibia.SpeedBonusApplied)
	if applied < 0 then
		applied = 0
	end
	if target == applied then
		return
	end
	player:changeSpeed(target - applied)
	player:setStorageValue(Storage.Quest.U11_80.MeasuringTibia.SpeedBonusApplied, target)
end

-- Populated by scripts/systems/measuring_tibia_zones.lua as it creates each parent area's combined
-- Zone (only for areas that have at least one subarea with real fromPos/toPos) - lets onLogin (and
-- anything else outside a zone-enter/leave callback) determine "is the player currently standing in
-- a completed area" from their actual live position, instead of trusting stale session state.
MeasuringTibia.areaZoneByName = {}

-- Re-derives "active" from the player's REAL current zone membership (not the previous session's
-- flag) and applies/removes the bonus accordingly. Safe to call from onLogin: a fresh login always
-- starts at appliedDelta effectively unknown-to-this-session, so this recomputes the correct target
-- from scratch (calculateSpeedBonus is a pure function of CompletedAreaCount) and diffs against
-- whatever SpeedBonusApplied says was left over, correcting any stale value from before a
-- crash/restart rather than assuming it's still accurate.
function MeasuringTibia.recalculateSpeedBonus(player)
	local playerZones = player:getZones()
	local active = false
	if playerZones then
		for areaName, areaZone in pairs(MeasuringTibia.areaZoneByName) do
			for _, zone in ipairs(playerZones) do
				if zone == areaZone then
					local area = MeasuringTibia.areaByName[areaName]
					if area and MeasuringTibia.isAreaCompleted(player, area) then
						active = true
					end
					break
				end
			end
			if active then
				break
			end
		end
	end
	MeasuringTibia.applySpeedBonus(player, active)
end

-- Reset/re-roll: OWNER_DECISION_RESET_UI_OR_CLIENT_REQUIRED for the real Cyclopedia World Map's
-- reset button specifically - that client screen isn't implemented at the protocol level in this
-- repo (parseCyclopediaMapAction is an inert stub, confirmed by direct C++ source read; no
-- DiscoveryData/SetDiscoveryArea outbound message exists to draw the map overlay in the first
-- place). Implemented instead as a talkaction-driven equivalent
-- (scripts/talkactions/measuring_tibia_reset.lua) - a real, repo-supported player-facing interface,
-- not a fake UI - that re-rolls this subarea's active POIs from its full candidate pool. Only the
-- not-yet-discovered slots are re-randomized; already-discovered progress within the subarea is
-- untouched (matches "no progress loss").
function MeasuringTibia.resetSubarea(player, subarea)
	if MeasuringTibia.isSubareaCompleted(player, subarea) then
		return false, "That subarea is already fully discovered."
	end
	if #subarea.pois == 0 then
		return false, "That subarea has no discovery data yet."
	end
	local scope = subareaKV(player, subarea.name)
	local discovered = scope:get("discovered") or {}
	local discoveredSet = {}
	for _, index in ipairs(discovered) do
		discoveredSet[index] = true
	end
	local pool = {}
	for i = 1, #subarea.pois do
		if not discoveredSet[i] then
			pool[#pool + 1] = i
		end
	end
	local active = {}
	for _, index in ipairs(discovered) do
		active[#active + 1] = index
	end
	local needed = math.min(MeasuringTibia.REQUIRED_ACTIVE_POIS - #active, #pool)
	for _ = 1, needed do
		local pick = math.random(1, #pool)
		active[#active + 1] = pool[pick]
		table.remove(pool, pick)
	end
	scope:set("active", active)
	return true
end
