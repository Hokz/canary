local quest = {
	name = "Grave Danger",
	startStorageId = Storage.Quest.U12_20.GraveDanger.Questline,
	startStorageValue = 1,
	missions = {
		[1] = {
			name = "* Grave Danger - The Lich Knights",
			storageId = Storage.Quest.U12_20.GraveDanger.Questline,
			missionId = 10437,
			startValue = 1,
			endValue = 2,
			states = {
				-- CONFIRMED BUG (pre-existing): this used to sum the twelve grave storages and subtract
				-- 12. An unset storage reads -1 (not 0) and a cleansed grave is set to 1 (not 2), so a
				-- fresh player saw "-24/12" and a fully finished one saw "0/12" - the counter could
				-- never display a correct value at any point. Counting cleansed graves explicitly
				-- (value >= 1) is both correct and independent of the unset sentinel.
				[1] = function(player)
					local graves = {
						Storage.Quest.U12_20.GraveDanger.Graves.Edron,
						Storage.Quest.U12_20.GraveDanger.Graves.DarkCathedral,
						Storage.Quest.U12_20.GraveDanger.Graves.Ghostlands,
						Storage.Quest.U12_20.GraveDanger.Graves.Cormaya,
						Storage.Quest.U12_20.GraveDanger.Graves.FemorHills,
						Storage.Quest.U12_20.GraveDanger.Graves.Ankrahmun,
						Storage.Quest.U12_20.GraveDanger.Graves.Kilmaresh,
						Storage.Quest.U12_20.GraveDanger.Graves.Vengoth,
						Storage.Quest.U12_20.GraveDanger.Graves.Darashia,
						Storage.Quest.U12_20.GraveDanger.Graves.Thais,
						Storage.Quest.U12_20.GraveDanger.Graves.Orclands,
						Storage.Quest.U12_20.GraveDanger.Graves.IceIslands,
					}

					local cleansed = 0
					for _, storage in ipairs(graves) do
						if player:getStorageValue(storage) >= 1 then
							cleansed = cleansed + 1
						end
					end

					return string.format(
						"Prevent the raising of twelve lich knights. Sanctify the graves yet untouched and destroy any lich knights that might have been raised. Graves explored: %d/12",
						cleansed
					)
				end,
			},
		},
		[2] = {
			name = "01 The grave in Edron",
			storageId = Storage.Quest.U12_20.GraveDanger.Graves.Edron,
			missionId = 10438,
			startValue = 1,
			endValue = 1,
			states = {
				[1] = "The Edron grave was visited.",
			},
		},
		[3] = {
			name = "02 The grave in the dark cathedral",
			storageId = Storage.Quest.U12_20.GraveDanger.Graves.DarkCathedral,
			missionId = 10439,
			startValue = 1,
			endValue = 1,
			states = {
				[1] = "The grave in the dark cathedral was visited.",
			},
		},
		[4] = {
			name = "03 The grave in Ghostlands",
			storageId = Storage.Quest.U12_20.GraveDanger.Graves.Ghostlands,
			missionId = 10440,
			startValue = 1,
			endValue = 1,
			states = {
				[1] = "The grave in the Ghostlands was visited.",
			},
		},
		[5] = {
			name = "04 The grave in Cormaya",
			storageId = Storage.Quest.U12_20.GraveDanger.Graves.Cormaya,
			missionId = 10441,
			startValue = 1,
			endValue = 1,
			states = {
				[1] = "The grave in Cormaya was visited.",
			},
		},
		[6] = {
			name = "05 The grave in the Femor Hills",
			storageId = Storage.Quest.U12_20.GraveDanger.Graves.FemorHills,
			missionId = 10442,
			startValue = 1,
			endValue = 1,
			states = {
				[1] = "The grave in the Femor Hills was visited.",
			},
		},
		[7] = {
			name = "06 The grave on an isle NE of Ankrahmun",
			storageId = Storage.Quest.U12_20.GraveDanger.Graves.Ankrahmun,
			missionId = 10443,
			startValue = 1,
			endValue = 1,
			states = {
				[1] = "The grave on an isle north-east of Ankrahmun was visited.",
			},
		},
		[8] = {
			name = "07 The grave in Kilmaresh",
			storageId = Storage.Quest.U12_20.GraveDanger.Graves.Kilmaresh,
			missionId = 10444,
			startValue = 1,
			endValue = 1,
			states = {
				[1] = "The grave in Kilmaresh was visited.",
			},
		},
		[9] = {
			name = "08 The grave in Vengoth",
			storageId = Storage.Quest.U12_20.GraveDanger.Graves.Vengoth,
			missionId = 10445,
			startValue = 1,
			endValue = 1,
			states = {
				[1] = "The grave in Vengoth was visited.",
			},
		},
		[10] = {
			name = "09 The grave in Darashia",
			storageId = Storage.Quest.U12_20.GraveDanger.Graves.Darashia,
			missionId = 10446,
			startValue = 1,
			endValue = 1,
			states = {
				[1] = "The grave in Darashia was visited.",
			},
		},
		[11] = {
			name = "10 The grave in the old Thais temple",
			storageId = Storage.Quest.U12_20.GraveDanger.Graves.Thais,
			missionId = 10447,
			startValue = 1,
			endValue = 1,
			states = {
				[1] = "The grave in the old temple of Thais has been visited.",
			},
		},
		[12] = {
			name = "11 The grave at the orclands entrance",
			storageId = Storage.Quest.U12_20.GraveDanger.Graves.Orclands,
			missionId = 10448,
			startValue = 1,
			endValue = 1,
			states = {
				[1] = "The grave at the orcland entrance was visited.",
			},
		},
		[13] = {
			name = "12 The grave on the southern ice islands",
			storageId = Storage.Quest.U12_20.GraveDanger.Graves.IceIslands,
			missionId = 10449,
			startValue = 1,
			endValue = 1,
			states = {
				[1] = "The grave on the southern ice islands was visited.",
			},
		},
		[14] = {
			name = "The Order of the Cobra",
			storageId = Storage.Quest.U12_20.GraveDanger.Cobra,
			missionId = 10450,
			startValue = 1,
			endValue = 1,
			states = {
				[1] = "Scarlett Etzel once stood proud and righteous. The assassins she rallied around her under the Order of the Cobra, however, were of ill repute and had to be vanquished. And so did she, you prevailed.",
			},
		},
	},
}

return quest
