-- TODO_EXACT_TEXT: mission names/descriptions below are functional placeholders, not verbatim
-- TibiaWiki text (not available at implementation time). Replace with exact wording when the
-- owner supplies it — do not remove this notice until every state below has been reviewed.
-- The one piece of exact owner-provided text for this quest (the destructive-charges re-entry
-- message) is used verbatim as the World Devourer portal's denial message instead of here — see
-- movements_teleport_heart.lua's worldDevourerEnter branch.
local quest = {
	name = "Heart of Destruction",
	startStorageId = Storage.Quest.U10_94.HeartOfDestruction.CaveAccess,
	startStorageValue = 1,
	missions = {
		[1] = {
			name = "Mission 1: The Messenger's Warning",
			storageId = Storage.Quest.U10_94.HeartOfDestruction.CaveAccess,
			missionId = 20001,
			startValue = 0,
			endValue = 1,
			states = {
				[0] = "Seek out the Messenger of Heaven and learn of the threat to the world.",
				[1] = "The Messenger of Heaven has warned you of the Heart of Destruction. A vortex to the incursion awaits near Ankrahmun, Svargrond, and Zao.",
			},
		},
		[2] = {
			name = "Mission 2: The Anomaly",
			storageId = 14326, -- Anomaly-defeated flag (legacy, see 03_HOD_STORAGE_CONTRACT.md)
			missionId = 20002,
			startValue = 0,
			endValue = 1,
			states = {
				[0] = "Enter the vortex to Ankrahmun's incursion and defeat the Anomaly.",
				[1] = "You have defeated the Anomaly.",
			},
		},
		[3] = {
			name = "Mission 3: The Realityquake",
			storageId = 14328, -- Realityquake-defeated flag (legacy, see 03_HOD_STORAGE_CONTRACT.md)
			missionId = 20003,
			startValue = 0,
			endValue = 1,
			states = {
				[0] = "Enter the vortex to Svargrond's incursion and defeat the Realityquake.",
				[1] = "You have defeated the Realityquake.",
			},
		},
		[4] = {
			name = "Mission 4: The Rupture",
			storageId = 14327, -- Rupture-defeated flag (legacy, see 03_HOD_STORAGE_CONTRACT.md)
			missionId = 20004,
			startValue = 0,
			endValue = 1,
			states = {
				[0] = "Enter the vortex to Zao's incursion and defeat the Rupture.",
				[1] = "You have defeated the Rupture.",
			},
		},
		[5] = {
			name = "Mission 5: The Eradicator",
			storageId = 14330, -- Eradicator-defeated flag (legacy, see 03_HOD_STORAGE_CONTRACT.md)
			missionId = 20005,
			startValue = 0,
			endValue = 1,
			states = {
				[0] = "With Anomaly, Realityquake, and Rupture defeated, the central hub grants passage to the Eradicator.",
				[1] = "You have defeated the Eradicator.",
			},
		},
		[6] = {
			name = "Mission 6: The Outburst",
			storageId = 14332, -- Outburst-defeated flag (legacy, see 03_HOD_STORAGE_CONTRACT.md)
			missionId = 20006,
			startValue = 0,
			endValue = 1,
			states = {
				[0] = "With Anomaly, Realityquake, and Rupture defeated, the central hub grants passage to the Outburst.",
				[1] = "You have defeated the Outburst.",
			},
		},
		[7] = {
			name = "Mission 7: The World Devourer",
			storageId = Storage.HeartOfDestructionFinalBattle.RewardClaimed,
			missionId = 20007,
			startValue = 0,
			endValue = 1,
			-- CUSTOM_GLOBAL_LIKE_PENDING_EXACT_REFERENCE: dynamic charge count added during the HOD
			-- repair audit (owner reference confirms the re-entry cost is charge-based, but not this
			-- exact questlog wording) - follows the same description-function pattern already used by
			-- 034_wrath_of_the_emperor.lua's missions 6/7 for a live counter instead of a static state.
			-- CORRECTION: the charge progression is no longer gated behind RewardClaimed >= 1 - since
			-- the owner reference now requires 5 charges on every committed entry including the first
			-- (see actions_final_lever.lua), the player must be able to see that requirement/progress
			-- BEFORE ever defeating World Devourer once, not only on repeat visits.
			description = function(player)
				local charges = math.max(player:getStorageValue(Storage.Quest.U10_94.HeartOfDestruction.DestructiveCharges), 0)
				if player:getStorageValue(Storage.HeartOfDestructionFinalBattle.RewardClaimed) < 1 then
					return "With the Eradicator and Outburst defeated, the way to the World Devourer itself lies open. Entering its lair costs 5 destructive charges, gathered by defeating the masters of the incursions - you have gathered " .. charges .. " of 5. Gather your allies — this battle needs many hands."
				end
				return "You have disrupted the Heart of Destruction and defeated the World Devourer. To face it again, you will need to gather destructive charges and wait for its power to wane. You have gathered " .. charges .. " of 5 charges."
			end,
		},
	},
}

return quest
