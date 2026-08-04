-- Ratmiral Blackwhiskers - real 3-stage encounter, not spawn-and-kill.
--
-- ACCEPTABLE_GLOBAL_LIKE simplifications, disclosed:
-- - Stage 1: the reference has enemies damage a pushed Rum Barrel until it explodes on the gate.
--   Monster-vs-item combat isn't a mechanic this engine's Lua API exposes safely, so the barrel
--   is used directly on the gate instead (still consumed, still needs 2 to fully destroy it,
--   still requires standing back) - respawning pirats provide the same combat pressure the
--   reference describes ("killing them isn't the solution, they just respawn").
-- - Stage 3: the reference has Ratmiral and 1st Mate Ratticus literally swap places/turns at the
--   fight's midpoint. Both bosses are simply present and attackable simultaneously here instead -
--   the tub-charge fire mitigation, keep-bosses-away-from-the-tub tension, and the unkillable
--   life-draining parrot are otherwise unchanged.
--
-- Stage-scoped state (gate health, monster spawns) is boss-room-scoped (GlobalStorage), matching
-- how BossLever rooms already only host one attempt at a time. Tub charges are per-player.
--
-- MAP SETUP REQUIRED: the 3 stage anchor positions below need real coordinates - see the Map
-- Setup Contract. Without them the mechanics are inert (guarded no-ops), same pattern as every
-- other position-dependent script in this quest.
local GATE_AID = 45960
local BARREL_ID = 2519
-- The gate room reuses the lever's existing, already-real teleport destination
-- (actions_ratmiral_blackwhiskers.lua's playerPositions all teleport here) - no new position
-- needed for stage 1.
local STAGE1_POSITION = Position(33904, 31356, 14)
local STAGE1_PIRATS = { "Pirat Cutthroat", "Pirat Scoundrel", "Pirat Bombardier" }
local RESPAWN_INTERVAL = 20 * 1000

local STAGE2_POSITION = nil -- Position: lower deck, where players arrive once the gate breaks
local STAGE2_HELPERS = { "Elite Pirat", "Elite Pirat" }

local STAGE3_POSITION = nil -- Position: upper deck, arrival point once Ratmiral retreats
local TUB_AID = 45961
local TUB_CHARGES = 6
local PARROT_TICK_INTERVAL = 15 * 1000
local PARROT_DRAIN = 500

local APiratesTail = Storage.Quest.U12_60.APiratesTail

local function playersNear(position, radius)
	if not position then
		return {}
	end
	local players = {}
	for _, spectator in ipairs(Game.getSpectators(position, false, true, radius, radius, radius, radius)) do
		if spectator:isPlayer() then
			table.insert(players, spectator)
		end
	end
	return players
end

-- Stage 1: gate + barrel + respawning pirats

local gateAction = Action()
function gateAction.onUse(player, item, fromPosition, target, toPosition, isHotkey)
	if not target or target:getActionId() ~= GATE_AID then
		return false
	end
	if Game.getStorageValue(GlobalStorage.APiratesTailBosses.RatmiralStage) ~= 1 then
		return true
	end
	item:remove(1)
	local remaining = math.max(Game.getStorageValue(GlobalStorage.APiratesTailBosses.RatmiralGateHealth) - 1, 0)
	Game.setStorageValue(GlobalStorage.APiratesTailBosses.RatmiralGateHealth, remaining)
	toPosition:sendMagicEffect(CONST_ME_FIREATTACK)
	if remaining <= 0 then
		Game.setStorageValue(GlobalStorage.APiratesTailBosses.RatmiralStage, 2)
		for _, spectator in ipairs(playersNear(STAGE1_POSITION, 20)) do
			spectator:sendTextMessage(MESSAGE_EVENT_ADVANCE, "The gate is destroyed! A passage to the ship opens.")
			if STAGE2_POSITION then
				spectator:teleportTo(STAGE2_POSITION)
			end
		end
	else
		for _, spectator in ipairs(playersNear(STAGE1_POSITION, 20)) do
			spectator:sendTextMessage(MESSAGE_EVENT_ADVANCE, "The barrel explodes! The gate is damaged, but still standing.")
		end
	end
	return true
end
gateAction:id(BARREL_ID)
gateAction:register()

local stage1Spawner = GlobalEvent("APiratesTailRatmiralGateSpawner")
function stage1Spawner.onThink(interval)
	if Game.getStorageValue(GlobalStorage.APiratesTailBosses.RatmiralStage) ~= 1 or not STAGE1_POSITION then
		return true
	end
	-- respawns in the gate room; matches "killing them isn't the solution, they just respawn"
	Game.createMonster(STAGE1_PIRATS[math.random(1, #STAGE1_PIRATS)], STAGE1_POSITION, true, true)
	return true
end
stage1Spawner:interval(RESPAWN_INTERVAL)
stage1Spawner:register()

-- Stage 2: lower deck, retreat at half health

local stage2Retreat = CreatureEvent("RatmiralLowerDeckRetreat")
function stage2Retreat.onHealthChange(creature, attacker, primaryDamage, primaryType, secondaryDamage, secondaryType, origin)
	if Game.getStorageValue(GlobalStorage.APiratesTailBosses.RatmiralStage) ~= 2 then
		return primaryDamage, primaryType, secondaryDamage, secondaryType
	end
	local incoming = math.abs(primaryDamage) + math.abs(secondaryDamage)
	if creature:getHealth() - incoming > creature:getMaxHealth() / 2 then
		return primaryDamage, primaryType, secondaryDamage, secondaryType
	end

	Game.setStorageValue(GlobalStorage.APiratesTailBosses.RatmiralStage, 3)
	local position = creature:getPosition()
	creature:remove()
	for _, name in ipairs(STAGE2_HELPERS) do
		for _, monster in ipairs(Game.getSpectators(position, false, true, 10, 10, 10, 10)) do
			if monster:isMonster() and monster:getName():lower() == name:lower() then
				monster:remove()
			end
		end
	end
	for _, spectator in ipairs(playersNear(STAGE2_POSITION, 20)) do
		spectator:sendTextMessage(MESSAGE_EVENT_ADVANCE, "Ratmiral retreats with his helpers! A ladder to the upper deck appears.")
		spectator:registerEvent("RatmiralTubProtection")
		if STAGE3_POSITION then
			spectator:teleportTo(STAGE3_POSITION)
		end
	end
	if STAGE3_POSITION then
		Game.createMonster("Ratmiral Blackwhiskers", STAGE3_POSITION, true, true)
		Game.createMonster("1st Mate Ratticus", STAGE3_POSITION, true, true)
		Game.createMonster("Ratmiral's Parrot", STAGE3_POSITION, true, true)
	end
	return 0, primaryType, 0, secondaryType
end
stage2Retreat:register()

-- Stage 3: upper deck, tub + parrot + both bosses

local tubAction = Action()
function tubAction.onUse(player, item, fromPosition, target, toPosition, isHotkey)
	player:setStorageValue(APiratesTail.Mission05.TubCharges, TUB_CHARGES)
	player:setIcon("ratmiral-tub", CreatureIconCategory_Quests, CreatureIconQuests_BlueShield, TUB_CHARGES)
	player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "You step into the water tub, protected against " .. TUB_CHARGES .. " more hits of fire damage.")
	return true
end
tubAction:aid(TUB_AID)
tubAction:register()

local tubProtection = CreatureEvent("RatmiralTubProtection")
function tubProtection.onHealthChange(creature, attacker, primaryDamage, primaryType, secondaryDamage, secondaryType, origin)
	if not creature:isPlayer() or not attacker or not attacker:isMonster() then
		return primaryDamage, primaryType, secondaryDamage, secondaryType
	end
	local attackerName = attacker:getName():lower()
	if attackerName ~= "ratmiral blackwhiskers" and attackerName ~= "1st mate ratticus" then
		return primaryDamage, primaryType, secondaryDamage, secondaryType
	end
	if primaryType ~= COMBAT_FIREDAMAGE and secondaryType ~= COMBAT_FIREDAMAGE then
		return primaryDamage, primaryType, secondaryDamage, secondaryType
	end
	local charges = creature:getStorageValue(APiratesTail.Mission05.TubCharges)
	if charges <= 0 then
		return primaryDamage, primaryType, secondaryDamage, secondaryType
	end
	creature:setStorageValue(APiratesTail.Mission05.TubCharges, charges - 1)
	creature:setIcon("ratmiral-tub", CreatureIconCategory_Quests, CreatureIconQuests_BlueShield, charges - 1)
	local reducedPrimary = primaryType == COMBAT_FIREDAMAGE and 0 or primaryDamage
	local reducedSecondary = secondaryType == COMBAT_FIREDAMAGE and 0 or secondaryDamage
	return reducedPrimary, primaryType, reducedSecondary, secondaryType
end
tubProtection:register()

local upperDeckDeath = CreatureEvent("RatmiralUpperDeckDeath")
function upperDeckDeath.onDeath(creature, corpse, lasthitkiller, mostdamagekiller)
	if Game.getStorageValue(GlobalStorage.APiratesTailBosses.RatmiralStage) ~= 3 then
		return true
	end
	-- both bosses share this handler name via monster.events; check if the other is still alive
	local otherName = creature:getName():lower() == "ratmiral blackwhiskers" and "1st mate ratticus" or "ratmiral blackwhiskers"
	local otherAlive = false
	for _, spectator in ipairs(Game.getSpectators(creature:getPosition(), false, true, 20, 20, 20, 20)) do
		if spectator:isMonster() and spectator:getName():lower() == otherName then
			otherAlive = true
		end
	end
	if otherAlive then
		return true -- wait for the second boss form
	end

	onDeathForDamagingPlayers(creature, function(_creature, player)
		player:setStorageValue(APiratesTail.Mission05.RatmiralKilled, 1)
		player:setStorageValue(APiratesTail.Mission05[1], 2)
		player:removeIcon("ratmiral-tub")
	end)
	return true
end
upperDeckDeath:register()

local parrotTick = GlobalEvent("APiratesTailRatmiralParrotTick")
function parrotTick.onThink(interval)
	if Game.getStorageValue(GlobalStorage.APiratesTailBosses.RatmiralStage) ~= 3 then
		return true
	end
	for _, spectator in ipairs(playersNear(STAGE3_POSITION, 20)) do
		for _, creature in ipairs(Game.getSpectators(spectator:getPosition(), false, true, 3, 3, 3, 3)) do
			if creature:isMonster() and creature:getName():lower() == "ratmiral's parrot" then
				spectator:addHealth(-PARROT_DRAIN)
				spectator:sendTextMessage(MESSAGE_EVENT_ADVANCE, "You take " .. PARROT_DRAIN .. " life drain damage from above!")
			end
		end
	end
	return true
end
parrotTick:interval(PARROT_TICK_INTERVAL)
parrotTick:register()
