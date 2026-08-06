-- Minimal Kilmaresh Quest catalog. No catalog file existed for this quest at all before this pass
-- (confirmed via a repo-wide search of this directory) - the questlog UI has never shown any
-- Kilmaresh progress, for any mission, at any point. This covers the start of the quest and each of
-- its 7 sub-missions' major milestone and completion, keyed to real, already-written storages -
-- it does not attempt full per-substep coverage of every storage this quest uses.
local quest = {
	name = "Kilmaresh Quest",
	-- CONFIRMED BUG (found in review): this used First.Title, which only npc/eshaya.lua writes when
	-- Fafnar's Wrath is accepted - so a player who legitimately started an independent Kilmaresh
	-- mission (Aspiring Oracle via Taya, or Wanted) had no Kilmaresh questlog at all. Making Taya
	-- write First.Title would have been worse: eshaya.lua offers Fafnar's Wrath only while
	-- First.Title < 1, so it would have silently locked the player out of the main mission. The
	-- previously-unused parent KilmareshQuest.Questline (46895, confirmed written nowhere in the repo)
	-- is now the visibility anchor, set by each legitimate entry point without implying any specific
	-- mission has started.
	startStorageId = Storage.Quest.U12_20.KilmareshQuest.Questline,
	startStorageValue = 1,
	missions = {
		[1] = {
			-- CONFIRMED BUG (found in review): endValue was 10, but the Empress advances Sixth.Favor
			-- 10 -> 11 when she hands over the reward - so 10 is "all statues blessed, go claim your
			-- reward", not "complete", and the questlog showed the mission finished one step early
			-- while also going blank at the real completion (11 was outside the range).
			name = "Fafnar's Wrath",
			storageId = Storage.Quest.U12_20.KilmareshQuest.Sixth.Favor,
			missionId = 20200,
			startValue = 1,
			endValue = 11,
			states = {
				[1] = "Search the catacombs beneath Issavi for the four masks and the five Fafnar statues, then bless them with the Empress's sceptre.",
				[10] = "You blessed all five Fafnar statues. Return to the Empress to claim your reward.",
				[11] = "You proved the Ambassador's treason and received a part of the Regalia of Suon from the Empress.",
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
			-- CONFIRMED BUG (found in review): this was keyed to Fourteen.Remains with
			-- startValue == endValue == 1, i.e. the completed-reward marker only - the mission was
			-- invisible for its entire active duration and appeared only once already finished. Now
			-- keyed to Twelve.Boss, which is Boards' own active progress storage (1 = available,
			-- 2 = three bosses assigned, 3 = bosses done, 4 = three favours assigned), with the
			-- completed state carried by 5.
			name = "The Boards that Mean the World",
			storageId = Storage.Quest.U12_20.KilmareshQuest.Twelve.Boss,
			missionId = 20203,
			startValue = 1,
			endValue = 5,
			states = {
				[1] = "Alyxo at the Seaside Theatre needs help. Ask her about her mission.",
				[2] = "Discreetly hunt down and kill Xogixath, Bragrumol and Mozradek.",
				[3] = "Report back to Alyxo now that the three demons are dead.",
				[4] = "Kill 300 Fafnar cultists, recover the stolen ivory lyre, and find an animal present for Narsai.",
				[5] = "You completed Alyxo's tasks and received a part of the Regalia of Suon.",
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
