-- A Pirate's Tail - shared raid location config, loaded before any quest scripts so every
-- script under scripts/quests/a_pirates_tail/ can safely reference APiratesTailRaidLocations
-- at runtime (never at file load time, since load order between sibling script files is not
-- guaranteed).
--
-- MAP SETUP REQUIRED: the 5 locations named in the reference ("west of Port Hope", "east of
-- Thais", "east side of Krailos island", "east of Darashia", "north Liberty Bay") have no exact
-- coordinates available (source images were not extractable from the PDF). Every zone field
-- below is nil until an owner fills them in - see the Map Setup Contract in the PR body for
-- exactly what each field needs. With zero configured, the raid scheduler still runs (raids
-- start/end on schedule and Eustacio still narrates a location name) but no monster/water-zone/
-- catapult content actually spawns anywhere, since there is nowhere safe to place it.
APiratesTailRaidLocations = {
	{ name = "west of Port Hope", landSpawn = nil, waterZone = nil, shipStonePile = nil, shipCatapult = nil, shipLever = nil },
	{ name = "east of Thais", landSpawn = nil, waterZone = nil, shipStonePile = nil, shipCatapult = nil, shipLever = nil },
	{ name = "east side of Krailos island", landSpawn = nil, waterZone = nil, shipStonePile = nil, shipCatapult = nil, shipLever = nil },
	{ name = "east of Darashia", landSpawn = nil, waterZone = nil, shipStonePile = nil, shipCatapult = nil, shipLever = nil },
	{ name = "north Liberty Bay", landSpawn = nil, waterZone = nil, shipStonePile = nil, shipCatapult = nil, shipLever = nil },
}

APiratesTailLandPirats = { "Pirat Cutthroat", "Pirat Scoundrel", "Pirat Mate", "Pirat Bombardier", "Elite Pirat" }
APiratesTailWaterPirats = { "Pirat Cutthroat", "Pirat Scoundrel", "Pirat Artillerist" }

-- Radius (in tiles) a pirat kill must fall within its raid's configured zone position to count
-- toward raid scoring/clearing. Prevents a wild pirat kill somewhere else in the world (these
-- monster types roam Darashia/Krailos/Liberty Bay/Port Hope/Thais/Pirat Mines normally) from
-- being credited as a raid kill.
APiratesTailRaidKillRadius = 15

function getAPiratesTailActiveLocation()
	local index = Game.getStorageValue(GlobalStorage.APiratesTailRaid.Location)
	return APiratesTailRaidLocations[index]
end

-- The Journey (Rascacoon Trust Points) - Raccoon Supplies crate positions and shared raft state,
-- used by both action_journey_raft.lua (spawns/tracks the attempt) and
-- creaturescripts_journey_raft.lua (a Quarra Saboteur's on-death crate-destroy check).
-- MAP SETUP REQUIRED - supply crate list is empty until an owner configures it.
APiratesTailJourneySupplyCrates = {}
APiratesTailJourneyRaft = {
	active = false,
	health = 100,
}

function damageAPiratesTailRaft(amount)
	APiratesTailJourneyRaft.health = math.max(APiratesTailJourneyRaft.health - amount, 0)
	if APiratesTailJourneyRaft.health <= 0 then
		APiratesTailJourneyRaft.active = false
	end
end
