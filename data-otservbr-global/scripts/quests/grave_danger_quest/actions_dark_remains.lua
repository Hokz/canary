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
	if target:isMonster() and target:getName():lower() == "count vlarkorth" and VlarkorthRunOwnsMonster(target) then
		item:remove(1)
		target:setStorageValue(3, target:getStorageValue(3) - 1)
		target:say("The magic shield of protection is weakened!")
		toPosition:sendMagicEffect(CONST_ME_HOLYAREA)
	end

	return true
end

dark_remains:id(31203, 31204, 31205, 31206)
dark_remains:register()
