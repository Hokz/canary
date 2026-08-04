local quest = {
	name = "A Pirate's Tail",
	startStorageId = Storage.Quest.U12_60.APiratesTail.QuestLine,
	startStorageValue = 1,
	missions = {
		[1] = {
			name = "A Pirate's Tail",
			storageId = Storage.Quest.U12_60.APiratesTail.Mission01[1],
			missionId = 10510,
			startValue = 1,
			endValue = 2,
			states = {
				[1] = function(player)
					return string.format(
						"Eustacio in Venore asked you to help defend the cities and coasts against pirat raids. Kill raiding \z
						pirats and destroy their ship to prove your worth. Ask him about the location of ongoing raids or your \z
						status. - Raid points: %d/1500.",
						(math.max(player:getStorageValue(Storage.Quest.U12_60.APiratesTail.Mission01.RaidPoints), 0))
					)
				end,
				[2] = "You reached a score of 1500 raid points. Eustacio told you of a secret passage below Kilmaresh - \z
				use a certain shell lying in the sand on the coast next to the temple in Issavi to find it.",
			},
		},
		[2] = {
			name = "Rascacoon",
			storageId = Storage.Quest.U12_60.APiratesTail.Mission02[1],
			missionId = 10511,
			startValue = 1,
			endValue = 2,
			states = {
				[1] = "You followed the secret passage from Issavi and reached the island of Rascacoon, home to a colony \z
				of raccoon-like people also besieged by pirats. Find Tik'hi Tak'he and offer your help.",
				[2] = "Tik'hi Tak'he welcomed your help and told you about earning 'trust points' through different tasks. \z
				A shortcut back to the mainland has opened up - ask Eustacio about it to return to the island later.",
			},
		},
		[3] = {
			name = "Rascacoon Trust Points",
			storageId = Storage.Quest.U12_60.APiratesTail.Mission03[1],
			missionId = 10512,
			startValue = 1,
			endValue = 2,
			states = {
				[1] = function(player)
					return string.format(
						"Earn the Rascoohan people's trust by completing tasks around the island: the Supply Mission, the \z
						Memory Test, Stealth, and (once Hidden Treasure's Queso mission is done) The Journey. Reach 1200 \z
						trust points to earn full trust. - Trust points: %d/1200.",
						(math.max(player:getStorageValue(Storage.Quest.U12_60.APiratesTail.Mission03.TrustPoints), 0))
					)
				end,
				[2] = "You earned the Rascoohan people's full trust. Tik'hi Tak'he permanently enchanted you to transform \z
				into a pirat for fifteen minutes every time you step through the teleporter east of the island - use it to \z
				reach the pirats' ship, The Wreckoning. You may keep earning trust points to trade for Rascoohan wares.",
			},
		},
		[4] = {
			name = "The Wreckoning",
			storageId = Storage.Quest.U12_60.APiratesTail.Mission04[1],
			missionId = 10513,
			startValue = 1,
			endValue = 2,
			states = {
				[1] = "You boarded the pirat ship Flying Bat in disguise. Captain Jack Rat offered to set sail - gather a \z
				crew of up to five and pull the lever to face whatever awaits on board.",
				[2] = "You defeated Tentugly's Head. Captain Jack Rat has unlocked a safe route to the pirats' hideout - a \z
				dangerous route past a seemonster is also available, once per day, for those seeking a fight.",
			},
		},
		[5] = {
			name = "Ratmiral Blackwhiskers",
			storageId = Storage.Quest.U12_60.APiratesTail.Mission05[1],
			missionId = 10514,
			startValue = 1,
			endValue = 3,
			states = {
				[1] = "You took the safe route to the pirats' hideout. Somewhere within, Ratmiral Blackwhiskers awaits - \z
				gather a crew of up to five and pull the lever when ready.",
				[2] = "You defeated Ratmiral Blackwhiskers. Return to Tik'hi Tak'he to claim your reward.",
				[3] = "Tik'hi Tak'he named you an honorary Rascoohan and granted you the Rascoohan Outfit. A Pirate's \z
				Tail is complete.",
			},
		},
		-- CUSTOM_GLOBAL_LIKE_QUESTLOG_PENDING_EXACT_REFERENCE
		[6] = {
			name = "Hidden Treasure",
			storageId = Storage.Quest.U12_60.APiratesTail.Mission06[1],
			missionId = 10515,
			startValue = 1,
			endValue = 8,
			states = {
				[1] = "You met Larry in the Corym Black Market beneath Liberty Bay. He gave you the first line of a rhyme \z
				and mentioned Rita's siblings, Sniff and Ra'Clette, might know more.",
				[2] = "Sniff, a corym merchant in Venore, agreed to share his part of the rhyme if you recover his goods - \z
				lost in a shark-infested bay on the southern coast of the Plains of Havoc.",
				[3] = "You recovered Sniff's goods and returned them. He gave you the second line of the rhyme and \z
				pointed you toward Ra'Clette.",
				[4] = "Ra'Clette, in the marshes, wants something personal belonging to the merchant Eustacio before she \z
				shares her part of the rhyme.",
				[5] = "Eustacio granted you access to his house in southern Venore after hearing of your efforts against \z
				the pirats. You searched it and found a garment of his.",
				[6] = "You returned Eustacio's garment to Ra'Clette. She gave you the third line of the rhyme and \z
				mentioned her little brother Queso knows the rest.",
				[7] = "You visited Queso in the Thais prison and read the rhyme carved into his cell wall. You now know \z
				the complete rhyme and may attempt The Journey on Rascacoon.",
				[8] = "You completed The Journey while carrying the key dropped by Tentugly's Head, and claimed the \z
				hidden treasure - a vocation-specific reward.",
			},
		},
	},
}

return quest
