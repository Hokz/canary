-- Heart of Destruction: outer vortex entrances (Ankrahmun/Svargrond/Zao).
-- MAP SETUP REQUIRED — see docs/ai-dev/quests/packages/heart-of-destruction/04_HOD_PORTAL_ACCESS_CONTRACT.md
-- for the exact action ids, required positions, and destination positions. These action ids are
-- not yet placed on any map tile/item; this script is the supporting logic, ready for that placement.

local HOD = Storage.Quest.U10_94.HeartOfDestruction

local routes = {
	[14361] = { -- Ankrahmun vortex -> Anomaly route
		permanentStorage = HOD.AnkrahmunPermanent,
		activeVortexId = 1,
		destination = Position(32093, 31327, 12), -- adjacent to the existing Charges lever room entrance
		routeName = "Ankrahmun",
	},
	[14362] = { -- Zao vortex -> Rupture route
		permanentStorage = HOD.ZaoPermanent,
		activeVortexId = 3,
		destination = Position(32081, 31313, 13), -- adjacent to the existing Cracklers lever room entrance
		routeName = "Zao",
	},
	[14363] = { -- Svargrond vortex -> Realityquake route
		permanentStorage = HOD.SvargrondPermanent,
		activeVortexId = 2,
		destination = Position(32229, 31343, 11), -- adjacent to the existing Sparks lever room entrance
		routeName = "Svargrond",
	},
}

local vortexEntrance = MoveEvent()

function vortexEntrance.onStepIn(creature, item, position, fromPosition)
	local player = creature:getPlayer()
	if not player then
		return true
	end

	local route = routes[item.actionid]
	if not route then
		return true
	end

	if player:getStorageValue(HOD.CaveAccess) < 1 then
		player:teleportTo(fromPosition)
		player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "The vortex does not react to you. Perhaps someone could tell you more about it.")
		return true
	end

	local hasPermanentAccess = player:getStorageValue(route.permanentStorage) >= 1
	local isActiveVortex = Game.getStorageValue(GlobalStorage.HeartOfDestruction.ActiveVortex) == route.activeVortexId

	if not hasPermanentAccess and not isActiveVortex then
		player:teleportTo(fromPosition)
		player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "The vortex to " .. route.routeName .. " is dormant right now. Try again later, or prove your worth here first.")
		return true
	end

	player:teleportTo(route.destination)
	player:getPosition():sendMagicEffect(CONST_ME_TELEPORT)
	return true
end

vortexEntrance:type("stepin")
for actionId in pairs(routes) do
	vortexEntrance:aid(actionId)
end
vortexEntrance:register()
