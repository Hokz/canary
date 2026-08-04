local oberonOthersMessages = {
	[1] = "Are you ever going to fight or do you prefer talking! Then let me show you the concept of mortality before it! Dare strike up a Minnesang and you will receive your last accolade!",
	[2] = "Even before they smell your breath? Too bad you barely exist at all! SEHWO ASIMO, TOLIDO ESD Excuse me but I still do not get the message! Then why are we fighting alone right now? How appropriate, you look like something worms already got the better of!",
}

GrandMasterOberonAsking = {
	[1] = { msg = "You appear like a worm among men!" },
	[2] = { msg = "The world will suffer for its idle laziness!" },
	[3] = { msg = "People fall at my feet when they see me coming!" },
	[4] = { msg = "This will be the end of mortal men!" },
	[5] = { msg = "I will remove you from this plane of existence!" },
	[6] = { msg = "Dragons will soon rule this world, I am their herald!" },
	[7] = { msg = "The true virtues of chivalry are my belief!" },
	[8] = { msg = "I lead the most honourable and formidable following of knights!" },
	[9] = { msg = "ULTAH SALID'AR, ESDO LO!" },
}

GrandMasterOberonResponses = {
	[1] = { msg = "How appropriate, you look like something worms already got the better of!", msg2 = oberonOthersMessages[2] },
	[2] = { msg = "Are you ever going to fight or do you prefer talking!", msg2 = oberonOthersMessages[1] },
	[3] = { msg = "Even before they smell your breath?", msg2 = oberonOthersMessages[2] },
	[4] = { msg = "Then let me show you the concept of mortality before it!", msg2 = oberonOthersMessages[1] },
	[5] = { msg = "Too bad you barely exist at all!", msg2 = oberonOthersMessages[2] },
	[6] = { msg = "Excuse me but I still do not get the message!", msg2 = oberonOthersMessages[2] },
	[7] = { msg = "Dare strike up a Minnesang and you will receive your last accolade!", msg2 = oberonOthersMessages[1] },
	[8] = { msg = "Then why are we fighting alone right now?", msg2 = oberonOthersMessages[2] },
	[9] = { msg = "SEHWO ASIMO, TOLIDO ESD", msg2 = oberonOthersMessages[2] },
}

GrandMasterOberonConfig = {
	Storage = {
		Asking = 1,
		Life = 2,
		Exhaust = 3,
	},
	Monster = {
		"Falcon Knight",
		"Falcon Paladin",
	},
	-- Was 3, off by one against the reference's exact "after fourth correct answer, boss becomes
	-- fully mortal": with the immunity-blocking fix in grand_master_oberon_immunity.lua, this value
	-- now directly determines how many correct answers are required (traced precisely: with
	-- AmountLife=N, questions are asked on health dips while Life<=N, and Life increments by 1 per
	-- correct answer starting at 1 - so N correct answers are required before the (N+1)th dip is
	-- unconditionally lethal). N=3 required only 3 correct answers; N=4 requires exactly 4.
	AmountLife = 4,
}

local function healOberon(monster)
	local storage = monster:getStorageValue(GrandMasterOberonConfig.Storage.Life)
	monster:setStorageValue(GrandMasterOberonConfig.Storage.Life, storage + 1)
	monster:addHealth(monster:getMaxHealth())
end

function SendOberonAsking(monster)
	monster:registerEvent("OberonImmunity")
	local random = math.random(#GrandMasterOberonAsking)
	monster:say(GrandMasterOberonAsking[random].msg, TALKTYPE_MONSTER_SAY)
	monster:setStorageValue(GrandMasterOberonConfig.Storage.Asking, random)

	healOberon(monster)

	Game.createMonster(GrandMasterOberonConfig.Monster[math.random(#GrandMasterOberonConfig.Monster)], monster:getPosition(), true, true)
end
