-- Measuring Tibia - reset/re-roll command.
--
-- OWNER_DECISION_RESET_UI_OR_CLIENT_REQUIRED: the real Cyclopedia World Map's reset button is a
-- client-side control this repo's Cyclopedia protocol support doesn't implement (parseCyclopediaMapAction
-- is an inert stub server-side, confirmed by direct source read - see the PR body). This talkaction is
-- a real, repo-supported substitute interface for the same effect (re-roll this subarea's
-- not-yet-discovered active POIs from its full candidate pool), not a fake UI.
local feature = TalkAction("!discovery")

function feature.onSay(player, words, param)
	local subareaName = param and param:match("^reset%s+(.+)$")
	if not subareaName then
		player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "Usage: !discovery reset <subarea name>")
		return true
	end

	local subarea = MeasuringTibia.subareaByNameLower[subareaName:lower()]
	if not subarea then
		player:sendTextMessage(MESSAGE_EVENT_ADVANCE, ('Unknown subarea "%s".'):format(subareaName))
		return true
	end

	local success, reason = MeasuringTibia.resetSubarea(player, subarea)
	if not success then
		player:sendTextMessage(MESSAGE_EVENT_ADVANCE, reason)
		return true
	end

	player:sendTextMessage(MESSAGE_EVENT_ADVANCE, ("Your undiscovered points of interest in %s have been reset."):format(subarea.name))
	return true
end

feature:separator(" ")
feature:groupType("normal")
feature:register()
