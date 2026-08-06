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
		-- CONFIRMED BUG (found in review): the questlog previously had no entry that became visible when
		-- Fafnar's Wrath is actually accepted. Sixth.Favor is only first written by the Empress, near
		-- the END of the mission, so a player who accepted the quest from Eshaya and was mid-way through
		-- the Ambassador investigation, the Urmahlullu fight, the Moe theft and the memory realm saw
		-- nothing at all. Second.Investigating is written by npc/eshaya.lua at acceptance (1) and
		-- advances through the investigation (up to 6), so it is the correct "mission is active" key for
		-- that whole first half.
		[1] = {
			name = "Fafnar's Wrath - The Ambassador",
			storageId = Storage.Quest.U12_20.KilmareshQuest.Second.Investigating,
			missionId = 20207,
			ignoreendvalue = true,
			startValue = 1,
			endValue = 6,
			states = {
				[1] = "Eshaya asked you to search the Ambassador of Rathleton's residence in eastern Issavi for evidence of his treason.",
				[5] = "You found nothing incriminating. Report back to Eshaya.",
				[6] = "Find the Ring of Secret Thoughts, said to be held by Urmahlullu in a tomb south of Issavi, then use it to expose the Ambassador's memories.",
			},
		},
		[2] = {
			-- CONFIRMED BUG (found in review): endValue was 10, but the Empress advances Sixth.Favor
			-- 10 -> 11 when she hands over the reward - so 10 is "all statues blessed, go claim your
			-- reward", not "complete", and the questlog showed the mission finished one step early
			-- while also going blank at the real completion (11 was outside the range).
			-- CONFIRMED BLOCKER (found in review, verified against the engine rather than assumed):
			-- Player.missionIsStarted (data/libs/functions/quests.lua:1035) returns false when
			-- `value > endValue` unless `ignoreendvalue` is set - so once npc/kallimae.lua advances
			-- Sixth.Favor to 12 on accepting Midnight Rituals, this mission would DISAPPEAR from the
			-- questlog entirely. `ignoreendvalue` is a real supported field: quests.lua:1035 honours it
			-- for visibility and :1150 clamps the displayed state to the highest defined one, and
			-- Game.getMission returns the catalog table unmodified (quests.lua:758), so setting it here
			-- takes effect. missionIsCompleted (:1117) is `value >= endValue`, so 11 and 12 both read
			-- as completed.
			name = "Fafnar's Wrath - The Catacombs",
			storageId = Storage.Quest.U12_20.KilmareshQuest.Sixth.Favor,
			missionId = 20200,
			ignoreendvalue = true,
			startValue = 1,
			endValue = 11,
			states = {
				[1] = "Search the catacombs beneath Issavi for the four masks and the five Fafnar statues, then bless them with the Empress's sceptre.",
				[10] = "You blessed all five Fafnar statues. Return to the Empress to claim your reward.",
				[11] = "You proved the Ambassador's treason and received a part of the Regalia of Suon from the Empress.",
			},
		},
		[3] = {
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
		[4] = {
			-- CONFIRMED BUG (found in review): keyed to Eleven.Basin, which is only written once the
			-- player has already helped all four members AND found three omens - so the mission was
			-- invisible for almost its entire duration. Set.Ritual is written by npc/kallimae.lua at the
			-- moment the mission is accepted (1), then by the scissors pickup (2) and the peeler pickup
			-- (3), making it the correct active key. Eleven.Basin's pilgrimage/completion phase is
			-- carried by the separate entry below. ignoreendvalue keeps this visible once Set.Ritual
			-- passes 3.
			name = "Midnight Rituals",
			storageId = Storage.Quest.U12_20.KilmareshQuest.Set.Ritual,
			missionId = 20202,
			ignoreendvalue = true,
			startValue = 1,
			endValue = 3,
			states = {
				[1] = "Kallimae asked you to help Yonan, Narsai, Tefrit and Shimun gather the ingredients for their rituals.",
				[2] = "You found the ritual scissors. Keep gathering the ingredients the four members need.",
				[3] = "You have the tools you need. Deliver every member's ingredients, then return to Kallimae.",
			},
		},
		[5] = {
			name = "Midnight Rituals - The Pilgrimage",
			storageId = Storage.Quest.U12_20.KilmareshQuest.Eleven.Basin,
			missionId = 20208,
			startValue = 1,
			endValue = 2,
			states = {
				[1] = "You found the sign of sun and sea. Bring it and the goanna's hide to Kallimae to complete the Midnight Pilgrimage.",
				[2] = "You completed the Midnight Pilgrimage and received a part of the Regalia of Suon from Kallimae.",
			},
		},
		[6] = {
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
		[7] = {
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
		[8] = {
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
		[9] = {
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
