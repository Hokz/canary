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
			-- CONFIRMED BUG (found in review): this previously claimed to cover "Fafnar's Wrath - The
			-- Ambassador" with endValue 6. Player.missionIsCompleted (quests.lua:1117) is
			-- `value >= endValue`, so it reported COMPLETED at Investigating 6 - which is only the point
			-- where Eshaya tells the player to go find the Ring of Secret Thoughts, with the Urmahlullu
			-- fight, the Moe theft, the Librarian, Faloriel and the whole memory realm still ahead.
			-- ignoreendvalue does NOT prevent that; it only affects visibility and state clamping once a
			-- value exceeds endValue.
			--
			-- Second.Investigating has no value beyond 6 anywhere in the repo (traced every writer), so
			-- rather than inventing a completion state it does not have, this entry is narrowed to
			-- exactly what that storage genuinely tracks - the residence search - and the later phases
			-- get their own entries keyed to their own storages, each ending on that storage's real
			-- terminal value. No entry now claims completion for work that is still outstanding.
			name = "Fafnar's Wrath - The Ambassador's Residence",
			storageId = Storage.Quest.U12_20.KilmareshQuest.Second.Investigating,
			missionId = 20207,
			startValue = 1,
			endValue = 6,
			states = {
				[1] = "Eshaya asked you to search the Ambassador of Rathleton's residence in eastern Issavi for evidence of his treason.",
				[5] = "You searched the residence and found nothing incriminating. Report back to Eshaya.",
				[6] = "You searched the residence. Eshaya believes only the Ambassador's own memories can prove his treason.",
			},
		},
		[2] = {
			name = "Fafnar's Wrath - The Ring of Secret Thoughts",
			storageId = Storage.Quest.U12_20.KilmareshQuest.Third.Recovering,
			missionId = 20209,
			startValue = 2,
			endValue = 3,
			states = {
				[2] = "You recovered the Ring of Secret Thoughts from Urmahlullu. Give it to the Ambassador of Rathleton as a present.",
				[3] = "The Ambassador is wearing the ring. His memories are being stored inside it.",
			},
		},
		[3] = {
			name = "Fafnar's Wrath - The Theft",
			storageId = Storage.Quest.U12_20.KilmareshQuest.Fourth.Moe,
			missionId = 20210,
			startValue = 1,
			endValue = 6,
			states = {
				[1] = "Eshaya hinted that only a thief can recover the ring. Find someone in Issavi willing to steal it.",
				[2] = "Moe will steal the ring in exchange for ten sphinx feathers.",
				[3] = "Moe has your feathers and is waiting for the right moment. Return to him later.",
				[4] = "Moe recovered the ring. Bring it back to Eshaya.",
				[5] = "Ask the Librarian in the palace how to read the memories stored in the ring.",
				[6] = "The Librarian explained the ritual. Buy the hallucinogen from Faloriel.",
			},
		},
		[4] = {
			name = "Fafnar's Wrath - The Memories",
			storageId = Storage.Quest.U12_20.KilmareshQuest.Fifth.Memories,
			missionId = 20211,
			startValue = 1,
			endValue = 6,
			states = {
				[1] = "Drink the hallucinogen while wearing the ring in the Temple of Bastesh, then gather one memory shard of each colour.",
				[4] = "You gathered the memories. Report the proof to Eshaya.",
				[5] = "Eshaya has the proof. The Empress will grant you an audience.",
				[6] = "The Empress gave you her sceptre and asked you to cleanse the Fafnar statues.",
			},
		},
		[5] = {
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
		[6] = {
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
		[7] = {
			-- CONFIRMED BUG (found in review): keyed to Eleven.Basin, which is only written once the
			-- player has already helped all four members AND found three omens - so the mission was
			-- invisible for almost its entire duration. Set.Ritual is written by npc/kallimae.lua at the
			-- moment the mission is accepted (1), then by the scissors pickup (2) and the peeler pickup
			-- (3), making it the correct active key. Eleven.Basin's pilgrimage/completion phase is
			-- carried by the separate entry below. ignoreendvalue keeps this visible once Set.Ritual
			-- passes 3.
			-- CONFIRMED BUG (found in review): endValue was 3, but Set.Ritual 3 only means the bark
			-- peeler was picked up - the tool-preparation stage. missionIsCompleted is
			-- `value >= endValue` (quests.lua:1117), so the mission read as COMPLETED while all four
			-- ingredient turn-ins were still outstanding. Set.Ritual 4 is a real completion marker,
			-- written by npc/kallimae.lua only at the point all four Eighth.* are proven to be 3 and the
			-- pilgrimage is unlocked. No ignoreendvalue here - 4 is the genuine terminal, so nothing
			-- needs to be papered over.
			name = "Midnight Rituals",
			storageId = Storage.Quest.U12_20.KilmareshQuest.Set.Ritual,
			missionId = 20202,
			startValue = 1,
			endValue = 4,
			states = {
				[1] = "Kallimae asked you to help Yonan, Narsai, Tefrit and Shimun gather the ingredients for their rituals.",
				[2] = "You found the ritual scissors. Keep gathering the ingredients the four members need.",
				[3] = "You found the bark peeler. Deliver every member's ingredients, then return to Kallimae.",
				[4] = "You helped all four members of the Midnight Flame complete their rituals.",
			},
		},
		[8] = {
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
		[9] = {
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
		[10] = {
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
		[11] = {
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
		[12] = {
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
