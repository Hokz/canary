function Party:onJoin(player)
	local playerUid = player:getGuid()
	addEvent(function(playerFuncUid)
		local playerEvent = Player(playerFuncUid)
		if not playerEvent then
			return
		end
		local party = playerEvent:getParty()
		if not party then
			return
		end
		party:refreshHazard()
	end, 100, playerUid)
	return true
end

function Party:onLeave(player)
	local playerUid = player:getGuid()
	local members = self:getMembers()
	table.insert(members, self:getLeader())
	local memberUids = {}
	for _, member in ipairs(members) do
		if member:getGuid() ~= playerUid then
			table.insert(memberUids, member:getGuid())
		end
	end

	addEvent(function(playerFuncUid, memberUidsTableEvent)
		local playerEvent = Player(playerFuncUid)
		if playerEvent then
			playerEvent:updateHazard()
		end

		for _, memberUid in ipairs(memberUidsTableEvent) do
			local member = Player(memberUid)
			if member then
				local party = member:getParty()
				if party then
					party:refreshHazard()
					return -- Only one player needs to refresh the hazard for the party
				end
			end
		end
	end, 100, playerUid, memberUids)
	return true
end

function Party:onDisband()
	local members = self:getMembers()
	table.insert(members, self:getLeader())
	local memberIds = {}
	for _, member in ipairs(members) do
		if member:getId() ~= playerId then
			table.insert(memberIds, member:getId())
		end
	end
	addEvent(function()
		for _, memberId in ipairs(memberIds) do
			local member = Player(memberId)
			if member then
				member:updateHazard()
			end
		end
	end, 100)
	return true
end

-- GLOBAL 2026: diversity-bonus multiplier per unique vocation count in the party, updated to the
-- current-live published values (2 unique vocations = +35%, 3 = +70%). The 1- and 4-vocation results
-- are unchanged from the prior formula's own output (1.2 / 2.0 respectively) - only the 2 and 3 cases
-- were adjusted, per the current-live foundation contract. getUniqueVocationsCount() (party.cpp) is
-- capped at 4 and already deduplicates same-vocation members, so this table is exhaustive for every
-- reachable input.
local sharedExperienceMultiplierByVocationCount = {
	[1] = 1.2,
	[2] = 1.35,
	[3] = 1.70,
	[4] = 2.0,
}

function Party:onShareExperience(exp)
	local uniqueVocationsCount = self:getUniqueVocationsCount()
	local partySize = self:getMemberCount() + 1

	local sharedExperienceMultiplier = sharedExperienceMultiplierByVocationCount[uniqueVocationsCount] or 1.2

	return math.ceil((exp * sharedExperienceMultiplier) / partySize)
end
