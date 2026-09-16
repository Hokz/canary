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

-- Shared-experience bonus, keyed purely on party size. Vocation composition no longer affects it:
-- a party of the same vocation and a party of four different vocations receive the same bonus.
-- Two or three members grant +25%, four or more grant +50%.
--
-- The multiplier applies to the shared pool, which onShareExperience then divides by the party size,
-- so a larger party still dilutes the per-member share. That division is pre-existing behaviour and
-- is deliberately left unchanged here.
--
-- A single-member party receives no bonus. Party::getSharedExperienceStatus (party.cpp) enforces no
-- minimum member count, so a lone leader with shared experience active does reach this path.
local SHARED_EXPERIENCE_MULTIPLIER_SOLO = 1.0
local SHARED_EXPERIENCE_MULTIPLIER_SMALL_PARTY = 1.25
local SHARED_EXPERIENCE_MULTIPLIER_LARGE_PARTY = 1.50
local LARGE_PARTY_MEMBER_THRESHOLD = 4

function Party:onShareExperience(exp)
	local partySize = self:getMemberCount() + 1

	local sharedExperienceMultiplier = SHARED_EXPERIENCE_MULTIPLIER_SOLO
	if partySize >= LARGE_PARTY_MEMBER_THRESHOLD then
		sharedExperienceMultiplier = SHARED_EXPERIENCE_MULTIPLIER_LARGE_PARTY
	elseif partySize >= 2 then
		sharedExperienceMultiplier = SHARED_EXPERIENCE_MULTIPLIER_SMALL_PARTY
	end

	return math.ceil((exp * sharedExperienceMultiplier) / partySize)
end
