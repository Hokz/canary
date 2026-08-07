-- "Aspiring Oracle" (added 12.70) - the sun-symbol door in the Ruins of Nuur.
--
-- SOURCE (npc/narsai.lua, the "eye of suon" briefing at AspiringOracle.Questline == 1, quoted from the
-- owner's reference package):
--   "You can find it in the former part of Kilmaresh, now known as Krailos. You can take a ship to get
--    there, but there is also a secret tunnel in the Ruins of Nuur. ... It still connects the ruins to
--    the lost part of the Old Empire. A seeled door prevents the ogres from coming through. ... But you
--    can open it by drawing a sun symbol on the door with your finger, right above the door knob."
--
-- So this door is the shortcut to the red gem (actions_eye_of_suon.lua, gemSpot uid 57553, "Buried in
-- the ruins of the Old Empire"). It therefore belongs INSIDE the part-collection stage, not between the
-- eye combination and the Anuma statues: Narsai explains the sun symbol in the same breath as where
-- both parts are, and the gem cannot be reached before the door is passed. Nothing in the repo or the
-- source supports a separate Questline value for it, so none was invented - the door writes its own
-- passage marker (AspiringOracle.NuurDoor) and leaves Questline alone.
--
-- The ship to Krailos remains the alternative route the source describes, so this door is a shortcut
-- rather than a hard gate; it is deliberately not the only way to reach the gem.
--
-- CODE_READY_POSITION_UNKNOWN: the real door object id and position in the Ruins of Nuur are not
-- provable from this repository (no OTBM parsing, and no Kilmaresh position constant exists for Nuur).
-- Registered on unique id 57563 - the next free value in the Kilmaresh allocation (57505-57562 in use,
-- 57563 unused anywhere in the repo). See the PR's Map Setup Contract for the required placement.
local nuurSunDoor = Action()

-- The repo convention "open door = closed door + 1" is NOT universally true: 14 of the 67 rows in
-- KeyDoorTable (data/libs/tables/doors.lua) break it, e.g. {lockedDoor 4912, closedDoor 5007,
-- openDoor 4911}. Two existing scripts hardcode +1 and would transform those doors into the wrong
-- object. This resolves the real counterpart from the table first and only falls back to +1.
local function openDoorIdFor(itemId)
	for _, door in ipairs(KeyDoorTable or {}) do
		if door.closedDoor == itemId or door.lockedDoor == itemId then
			return door.openDoor
		end
	end

	return itemId + 1
end

function nuurSunDoor.onUse(player, item, fromPosition, target, toPosition, isHotkey)
	-- Registered by unique id, so `item` is the door itself. Guarded anyway: a malformed map entry
	-- (uid on a tile rather than on the door object) would otherwise index a metatable-less table.
	if not item or type(item) ~= "userdata" or not item.itemid then
		return false
	end

	local questline = player:getStorageValue(Storage.Quest.U12_20.KilmareshQuest.AspiringOracle.Questline)

	-- Unset storage is -1 (data/libs/functions/game.lua:117-119), so a player who never spoke to Taya
	-- or Narsai is rejected by the same comparison as one who is merely too early.
	if questline < 2 then
		player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "The door is sealed. Faint sun-shaped grooves are worn into the stone above the door knob, but you do not know what to trace.")
		return true
	end

	-- Monotonic: only ever raised, never lowered, so a player who has long finished Aspiring Oracle
	-- cannot have this marker reset by walking back through the tunnel.
	if player:getStorageValue(Storage.Quest.U12_20.KilmareshQuest.AspiringOracle.NuurDoor) < 1 then
		player:setStorageValue(Storage.Quest.U12_20.KilmareshQuest.AspiringOracle.NuurDoor, 1)
		player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "You trace a sun symbol above the door knob with your finger. The seal flares once and the ancient door swings open.")
	else
		player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "You trace the sun symbol again and the door opens.")
	end

	-- Idempotent: transforming an already-open door to its own open id is a no-op, and the teleport
	-- simply moves the player through again. Nothing here consumes an item or advances Questline.
	local openId = openDoorIdFor(item.itemid)
	if openId and item.itemid ~= openId then
		item:transform(openId)
	end

	player:teleportTo(toPosition, true)
	player:getPosition():sendMagicEffect(CONST_ME_YELLOWENERGY)

	return true
end

nuurSunDoor:uid(57563)
nuurSunDoor:register()
