-- TODO_EXACT_TEXT: mission names/descriptions below are functional placeholders, not verbatim
-- in-game questlog text (not available at implementation time). Replace with exact wording when
-- the owner supplies it -- do not remove this notice until every state below has been reviewed.
local quest = {
	name = "Ferumbras' Ascension",
	startStorageId = Storage.Quest.U10_90.FerumbrasAscension.Access,
	startStorageValue = 1,
	missions = {
		[1] = {
			name = "Mission 1: Opening the Gates of Hell",
			storageId = Storage.Quest.U10_90.FerumbrasAscension.Access,
			missionId = 20101,
			startValue = 0,
			endValue = 1,
			states = {
				[0] = "Seek out Mazarius in Darashia. He fears Ferumbras is close to a godlike ascension and needs 30 demonic essences to open a way to stop him.",
				[1] = "You delivered 30 demonic essences to Mazarius. He opened the gates of hell and gave you a teleportation rod to retrieve the seven parts of the Godbreaker.",
			},
		},
		[2] = {
			name = "Mission 2: Grounds of Plague",
			storageId = Storage.Quest.U10_90.FerumbrasAscension.Plagirath,
			missionId = 20102,
			startValue = 0,
			endValue = 1,
			states = {
				[0] = "Defeat Plagirath in the Grounds of Plague and teleport its Godbreaker part to Mazarius with the teleportation rod.",
				[1] = "You retrieved the Godbreaker part from the Grounds of Plague.",
			},
		},
		[3] = {
			name = "Mission 3: Grounds of Deceit",
			storageId = Storage.Quest.U10_90.FerumbrasAscension.Zamulosh,
			missionId = 20103,
			startValue = 0,
			endValue = 1,
			states = {
				[0] = "Defeat Zamulosh in the Grounds of Deceit and teleport its Godbreaker part to Mazarius with the teleportation rod.",
				[1] = "You retrieved the Godbreaker part from the Grounds of Deceit.",
			},
		},
		[4] = {
			name = "Mission 4: Grounds of Fire",
			storageId = Storage.Quest.U10_90.FerumbrasAscension.Mazoran,
			missionId = 20104,
			startValue = 0,
			endValue = 1,
			states = {
				[0] = "Defeat Mazoran in the Grounds of Fire and teleport its Godbreaker part to Mazarius with the teleportation rod.",
				[1] = "You retrieved the Godbreaker part from the Grounds of Fire.",
			},
		},
		[5] = {
			name = "Mission 5: Grounds of Destruction",
			storageId = Storage.Quest.U10_90.FerumbrasAscension.Razzagorn,
			missionId = 20105,
			startValue = 0,
			endValue = 1,
			states = {
				[0] = "Defeat Razzagorn in the Grounds of Destruction and teleport its Godbreaker part to Mazarius with the teleportation rod.",
				[1] = "You retrieved the Godbreaker part from the Grounds of Destruction.",
			},
		},
		[6] = {
			name = "Mission 6: Grounds of Undeath",
			storageId = Storage.Quest.U10_90.FerumbrasAscension.Ragiaz,
			missionId = 20106,
			startValue = 0,
			endValue = 1,
			states = {
				[0] = "Defeat Ragiaz in the Grounds of Undeath and teleport its Godbreaker part to Mazarius with the teleportation rod.",
				[1] = "You retrieved the Godbreaker part from the Grounds of Undeath.",
			},
		},
		[7] = {
			name = "Mission 7: Grounds of Despair",
			storageId = Storage.Quest.U10_90.FerumbrasAscension.Tarbaz,
			missionId = 20107,
			startValue = 0,
			endValue = 1,
			states = {
				[0] = "Defeat Tarbaz in the Grounds of Despair and teleport its Godbreaker part to Mazarius with the teleportation rod.",
				[1] = "You retrieved the Godbreaker part from the Grounds of Despair.",
			},
		},
		[8] = {
			name = "Mission 8: Grounds of Damnation",
			storageId = Storage.Quest.U10_90.FerumbrasAscension.Shulgrax,
			missionId = 20108,
			startValue = 0,
			endValue = 1,
			states = {
				[0] = "Defeat Shulgrax in the Grounds of Damnation and teleport its Godbreaker part to Mazarius with the teleportation rod.",
				[1] = "You retrieved the Godbreaker part from the Grounds of Damnation.",
			},
		},
		[9] = {
			name = "Mission 9: The Ascension",
			storageId = Storage.Quest.U10_90.FerumbrasAscension.Reward,
			missionId = 20109,
			startValue = 0,
			endValue = 1,
			states = {
				[0] = "With all seven Godbreaker parts delivered, Mazarius has vanished - betrayed you, and served Variphor all along. Follow the new portal into the Halls of Ascension and stop Ferumbras before he becomes a god.",
				[1] = "You stopped the ascension of Ferumbras and claimed your reward.",
			},
		},
	},
}

return quest
