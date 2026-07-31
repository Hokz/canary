local quest = {
	name = "Forgotten Knowledge",
	startStorageId = Storage.Quest.U11_02.ForgottenKnowledge.Tomes,
	startStorageValue = 1,
	missions = {
		[1] = {
			name = "Temple Restoration",
			storageId = Storage.Quest.U11_02.ForgottenKnowledge.Tomes,
			missionId = 10360,
			startValue = 0,
			endValue = 1,
			states = {
				[0] = "The Halls of Hope north of Thais lie unfinished. Seek out Albinius there and ask him about the {temple} - he will need Heavy Old Tomes to restore it.",
				[1] = "You gave Albinius enough Heavy Old Tomes to restore the temple. The first Imbuing Shrines are now open to you, and six sealed portals within the temple await deeper knowledge.",
			},
		},
		[2] = {
			name = "Bane of the Cosmic Force - Portal Access",
			storageId = Storage.Quest.U11_02.ForgottenKnowledge.AccessViolet,
			missionId = 10361,
			startValue = 0,
			endValue = 1,
			states = {
				[0] = "Ask Albinius about the {energy portal}. He asks for 50 Marsh Stalker Feathers before he will open it.",
				[1] = "Albinius opened the Energy Portal for you.",
			},
		},
		[3] = {
			name = "Bane of the Cosmic Force - Lloyd",
			storageId = Storage.Quest.U11_02.ForgottenKnowledge.LloydKilled,
			missionId = 10362,
			startValue = 0,
			endValue = 1522018605,
			states = {
				[0] = "Beyond the Energy Portal, servant replicas guard a dormant cosmic chamber. Enough of them must be defeated to awaken it and open a way to Lloyd.",
				[1] = "You calmed poor, misguided Lloyd. All he wanted was protection from the outside world. \z
				Luckily he seems to have learned his lesson... or has he?",
			},
		},
		[4] = {
			name = "Circle of the Black Sphinx - Portal Access",
			storageId = Storage.Quest.U11_02.ForgottenKnowledge.AccessDeath,
			missionId = 10363,
			startValue = 0,
			endValue = 1,
			states = {
				[0] = "Ask Albinius about the {death portal}. He asks for 50 Pelvis Bones before he will open it.",
				[1] = "Albinius opened the Death Portal for you.",
			},
		},
		[5] = {
			name = "Circle of the Black Sphinx - The Ghostsilver Trail",
			storageId = Storage.Quest.U11_02.ForgottenKnowledge.SilverKey,
			missionId = 10364,
			startValue = 0,
			endValue = 1,
			states = {
				[0] = "Somewhere in the Old Masonry beyond the Death Portal, an old desk hides a secret drawer - it seems to want something to open fully.",
				[1] = "An old silver key rests in your hands now. In the light of a lit ghostsilver lantern, it should open a door that isn't normally there.",
			},
		},
		[6] = {
			name = "Circle of the Black Sphinx - Lady Tenebris",
			storageId = Storage.Quest.U11_02.ForgottenKnowledge.LadyTenebrisKilled,
			missionId = 10365,
			startValue = 0,
			endValue = 1522018605,
			states = {
				[0] = "With the silver key and a lit ghostsilver lantern, an invisible door has opened. Beyond it, Lady Tenebris and her shadow tentacles await.",
				[1] = "You defeated the rogue Lady Tenebris.",
			},
		},
		[7] = {
			name = "Dragon in Distress - Portal Access",
			storageId = Storage.Quest.U11_02.ForgottenKnowledge.AccessIce,
			missionId = 10366,
			startValue = 0,
			endValue = 1,
			states = {
				[0] = "Ask Albinius about the {ice portal}. He asks for 50 Fish before he will open it.",
				[1] = "Albinius opened the Ice Portal for you.",
			},
		},
		[8] = {
			name = "Dragon in Distress - The Stolen Egg",
			storageId = Storage.Quest.U11_02.ForgottenKnowledge.BabyDragon,
			missionId = 10367,
			startValue = 0,
			endValue = 1,
			states = {
				[0] = "Beyond the Ice Portal, a desperate Dragon Mother has lost her egg to creatures of ice and needs your help.",
				[1] = "You agreed to venture into the lower tunnels, save the Dragon Mother's egg, and bring it back to life.",
			},
		},
		[9] = {
			name = "Dragon in Distress - Melting Frozen Horror",
			storageId = Storage.Quest.U11_02.ForgottenKnowledge.HorrorKilled,
			missionId = 10368,
			startValue = 0,
			endValue = 1522018605,
			states = {
				[0] = "The Dragon Egg lies guarded by a Solid Frozen Horror and its frozen minions. Warm the egg with fire, keep the ice at bay, and weaken the horror until it melts.",
				[1] = "You saved the Dragon Mother's egg and she melted the ice wall that blocked your way.",
			},
		},
		[10] = {
			name = "The Desecrated Glade - Portal Access",
			storageId = Storage.Quest.U11_02.ForgottenKnowledge.AccessEarth,
			missionId = 10369,
			startValue = 0,
			endValue = 1,
			states = {
				[0] = "Ask Albinius about the {earth portal}. He asks for 50 Acorns before he will open it.",
				[1] = "Albinius opened the Earth Portal for you.",
			},
		},
		[11] = {
			name = "The Desecrated Glade - Guardian's Task",
			storageId = Storage.Quest.U11_02.ForgottenKnowledge.BirdCage,
			missionId = 10370,
			startValue = 0,
			endValue = 1,
			states = {
				[0] = "Beyond the Earth Portal, a Weakened Forest Fury guards a desecrated glade and asks for a guardian to restore it.",
				[1] = "You took up an empty birdcage and swore to free the captured parrots, plant new seeds, and heal the glade's Giant Tree.",
			},
		},
		[12] = {
			name = "The Desecrated Glade - The Enraged Thorn Knight",
			storageId = Storage.Quest.U11_02.ForgottenKnowledge.ThornKnightKilled,
			missionId = 10371,
			startValue = 0,
			endValue = 1522018605,
			states = {
				[0] = "Free the caged parrots, grow the withered birches with water from the sacred pond, and heal the Giant Tree to open the way to the Thorn Knight.",
				[1] = "You defeated the Thorn Knight and shattered the root of evil with all your might. \z
				The honor of being a guardian of the glade indeed comes with pride as well as responsibility.",
			},
		},
		[13] = {
			name = "The Unwary Mage - Ivalisse's Plea",
			storageId = Storage.Quest.U11_02.ForgottenKnowledge.Ivalisse,
			missionId = 10372,
			startValue = 0,
			endValue = 1,
			states = {
				[0] = "A worried priestess named Ivalisse tends the temple of the Astral Shapers in Thais. She has not heard from her father in some time.",
				[1] = "You agreed to help Ivalisse find her father Silus, last known to be searching for Draken ruins somewhere in Zao.",
			},
		},
		[14] = {
			name = "The Unwary Mage - A Strange Chalice",
			storageId = Storage.Quest.U11_02.ForgottenKnowledge.Chalice,
			missionId = 10373,
			startValue = 0,
			endValue = 1,
			states = {
				[0] = "Somewhere in the Temple Complex of northern Zao, Silus is said to be hiding among the Draken in a most unusual disguise.",
				[1] = "You found Silus, disguised as a chalice, and learned the password that opens the way to the fiery portal deeper in the complex.",
			},
		},
		[15] = {
			name = "The Unwary Mage - Soul of Dragonking Zyrtarch",
			storageId = Storage.Quest.U11_02.ForgottenKnowledge.DragonkingKilled,
			missionId = 10374,
			startValue = 0,
			endValue = 1522018605,
			states = {
				[0] = "With the password learned from Silus, descend beyond the fiery portal and put an end to the Soul of Dragonking Zyrtarch.",
				[1] = "With help of Ivalisse from the temple of the Astral Shapers in Thais and her father, \z
				you averted the Dragon King's menace deep in the Zao Muggy Plains.",
			},
		},
		[16] = {
			name = "Time is a Window - Portal Access",
			storageId = Storage.Quest.U11_02.ForgottenKnowledge.AccessGolden,
			missionId = 10375,
			startValue = 0,
			endValue = 1,
			states = {
				[0] = "Ask Albinius about the {holy portal}. He asks for 50 Incantation Notes before he will open it.",
				[1] = "Albinius opened the Holy Portal for you.",
			},
		},
		[17] = {
			name = "Time is a Window - The Time Guardian",
			storageId = Storage.Quest.U11_02.ForgottenKnowledge.TimeGuardianKilled,
			missionId = 10376,
			startValue = 0,
			endValue = 1522018605,
			states = {
				[0] = "Beyond the Holy Portal, a Time Machine waits deep in the Astral Shaper dungeon. Step through it and overcome the Time Guardian in every form it takes.",
				[1] = "You defeated the Time Guardian and are free to return to your own time. \z
				For some creatures in this world, it seems neither past nor future are an obstacle.",
			},
		},
		[18] = {
			name = "Final Fight - The Energy Gate",
			storageId = Storage.Quest.U11_02.ForgottenKnowledge.AccessLast,
			missionId = 10377,
			startValue = 0,
			endValue = 1,
			states = {
				[0] = "All six elemental guardians - Lloyd, Lady Tenebris, the Frozen Horror, the Thorn Knight, Dragonking Zyrtarch, and the Time Guardian - must fall before the Energy Gate in the Halls of Hope will open.",
				[1] = "The Energy Gate has opened. Somewhere beyond it, the Last Lore Keeper stands vigil over what remains of the forgotten knowledge.",
			},
		},
		[19] = {
			name = "Final Fight - The Last Lore Keeper",
			storageId = Storage.Quest.U11_02.ForgottenKnowledge.LastLoreKilled,
			missionId = 10378,
			startValue = 0,
			endValue = 1522018605,
			states = {
				[0] = "Brave the Astral Shaper dungeon beyond the Energy Gate - bound astral powers, an astral source, and a shielded astral glyph all guard the Last Lore Keeper.",
				[1] = "You silenced the Last Lore Keeper. The forgotten knowledge of imbuing is fully restored to the world, and its most powerful secrets are yours to master.",
			},
		},
	},
}

return quest
