local voc_table = {
	[31203] = { voc = 4 },
	[31204] = { voc = 3 },
	[31205] = { voc = 2 },
	[31206] = { voc = 1 },
}

local dark_remains = Action()

function dark_remains.onUse(player, item, fromPosition, target, toPosition, isHotkey)
	local canUse = voc_table[item.itemid]

	if target:isPlayer() or player:getVocation():getBase():getId() ~= canUse.voc then
		return false
	end

	-- CORRECTION (executor contract, section 8): ownership-scoped instead of a bare name lookup - a
	-- remains item can only weaken the shield of the CURRENT run's own Count Vlarkorth, never a stale
	-- reference or an unrelated instance sharing the same name.
	--
	-- CORRECTION (correction pass section D): also requires the item's own metadata (stamped at the
	-- dark summon's death, see count_vlarkorth_remains_tag) to match both the current run token AND
	-- the boss's current shield generation. A remains item saved from an earlier wave/run can no
	-- longer weaken a newer one just because it still resolves to the same-named boss instance.
	if target:isMonster() and target:getName():lower() == "count vlarkorth" and VlarkorthRunOwnsBoss(target) then
		local runToken = VlarkorthRunCurrentToken()
		local currentGeneration = VlarkorthRunCurrentGeneration()
		local itemToken = item:getCustomAttribute("VlarkorthRunToken")
		local itemGeneration = item:getCustomAttribute("VlarkorthGeneration")

		if not runToken or itemToken ~= runToken or not currentGeneration or itemGeneration ~= currentGeneration then
			player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "These remains no longer hold any power here.")
			return true
		end

		item:remove(1)
		-- CORRECTION (section D): never allow the shield-obligation counter to go negative.
		target:setStorageValue(3, math.max(0, target:getStorageValue(3) - 1))
		target:say("The magic shield of protection is weakened!")
		toPosition:sendMagicEffect(CONST_ME_HOLYAREA)
	end

	return true
end

dark_remains:id(31203, 31204, 31205, 31206)
dark_remains:register()
