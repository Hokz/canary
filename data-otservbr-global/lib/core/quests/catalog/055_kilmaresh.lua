-- Minimal Kilmaresh Quest catalog. No catalog file existed for this quest at all before this pass
-- (confirmed via a repo-wide search of this directory) - the questlog UI has never shown any
-- Kilmaresh progress, for any mission, at any point. This covers the start of the quest and each of
-- its 7 sub-missions' major milestone and completion, keyed to real, already-written storages -
-- it does not attempt full per-substep coverage of every storage this quest uses.
local quest = {
	name = "Kilmaresh Quest",
	startStorageId = Storage.Quest.U12_20.KilmareshQuest.First.Title,
	startStorageValue = 1,
	missions = {
		[1] = {
			name = "Fafnar's Wrath",
			storageId = Storage.Quest.U12_20.KilmareshQuest.Sixth.Favor,
			missionId = 20200,
			startValue = 1,
			endValue = 10,
			states = {
				[1] = "Investigate the Ambassador of Rathleton and prove his treason to Eshaya.",
				[10] = "You proved the Ambassador's treason and received a part of the Regalia of Suon from the Empress.",
			},
		},
		[2] = {
			name = "A Shark in Need",
			storageId = Storage.Quest.U12_20.KilmareshQuest.NinevShark.Questline,
			missionId = 20201,
			startValue = 1,
			endValue = 2,
			states = {
				[1] = "Find a waterproof healing salve for Ninev's injured shark.",
				[2] = "You cured the injured shark and received a part of the Regalia of Suon from Ninev.",
			},
		},
		[3] = {
			name = "Midnight Rituals",
			storageId = Storage.Quest.U12_20.KilmareshQuest.Eleven.Basin,
			missionId = 20202,
			startValue = 1,
			endValue = 2,
			states = {
				[1] = "Help Yonan, Narsai, Tefrit and Shimun gather ritual ingredients, then complete the Midnight Pilgrimage for Kallimae.",
				[2] = "You completed the Midnight Pilgrimage and received a part of the Regalia of Suon from Kallimae.",
			},
		},
		[4] = {
			name = "The Boards that Mean the World",
			storageId = Storage.Quest.U12_20.KilmareshQuest.Fourteen.Remains,
			missionId = 20203,
			startValue = 1,
			endValue = 1,
			states = {
				[1] = "You defeated Xogixath, Bragrumol and Mozradek, recovered the ivory lyre, dealt with the animal present, and received a part of the Regalia of Suon from Alyxo.",
			},
		},
		[5] = {
			name = "The Revenge of the Ogres",
			storageId = Storage.Quest.U12_20.KilmareshQuest.RevengeOfTheOgres.Questline,
			missionId = 20204,
			startValue = 1,
			endValue = 4,
			states = {
				[1] = "Find the grave of the hero Dayyan, protected by ogres and ancient puzzles, for Saideh.",
				[4] = "You searched Dayyan's grave and were rewarded by Saideh.",
			},
		},
		[6] = {
			name = "Aspiring Oracle",
			storageId = Storage.Quest.U12_20.KilmareshQuest.AspiringOracle.Questline,
			missionId = 20205,
			startValue = 1,
			endValue = 7,
			states = {
				[1] = "Find the two parts of the Eye of Suon and offer sacrifices at the Anuma statues for Taya and Narsai.",
				[6] = "The Eye of Suon is blessed. Find and kill Enusat the Onyx Wing.",
				[7] = "You killed Enusat the Onyx Wing and were rewarded by Taya.",
			},
		},
		[7] = {
			name = "Wanted",
			storageId = Storage.Quest.U12_20.KilmareshQuest.Wanted.Questline,
			missionId = 20206,
			startValue = 1,
			endValue = 3,
			states = {
				[1] = "Find the innocent among the four wanted suspects using Kallimae's ritual, then bring the guilty to justice for Eshaya.",
				[3] = "You cleared Petaris and brought Neferi, Sister Hetai and Amenef to justice. Eshaya rewarded you with the Citizen of Issavi outfit.",
			},
		},
	},
}

return quest
