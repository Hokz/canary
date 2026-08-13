-- CORRECTION (Secret Library repair v2, section 16.2): duration corrected from 30 to the owner-
-- contract 8 seconds (must be timed to still be active when Mazzinor's Supercharged explosion lands).
local outfit = createConditionObject(CONDITION_OUTFIT)
setConditionParam(outfit, CONDITION_PARAM_TICKS, 8 * 1000)
addOutfitCondition(outfit, { lookType = 1065 })

local movements_library_mazzinor = MoveEvent()

function movements_library_mazzinor.onStepIn(creature, item, position, fromPosition)
	if not creature:isPlayer() then
		return false
	end

	-- CORRECTION (section 16.2): a vortex must belong to the CURRENT Mazzinor run to grant the
	-- protective transform - a stale vortex left over from an already-terminated run (its own 60-
	-- second cleanup notwithstanding) can no longer protect a newer attempt.
	local token = MazzinorRunCurrentToken()
	if not token or item:getCustomAttribute("MazzinorRunToken") ~= token then
		return true
	end

	creature:addCondition(outfit)
	creature:sendTextMessage(MESSAGE_EVENT_ADVANCE, "The remains deporalize you temporaly.")
	creature:getPosition():sendMagicEffect(CONST_ME_ENERGYHIT)
	item:remove(1)

	return true
end

movements_library_mazzinor:aid(4951)
movements_library_mazzinor:register()
