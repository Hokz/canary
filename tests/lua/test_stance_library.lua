-- Tests for data/libs/systems/stance.lua and the stance spells' declared contracts
-- (15.25 vocation balancing). Run: luajit tests/lua/test_stance_library.lua
--
-- The library and the spell files are loaded against a stub of the engine's Lua
-- surface: unknown globals resolve to unique placeholder values (the constants),
-- and Spell / Combat / Condition return recorders that remember what was declared.

local passed, failed, errors = 0, 0, {}

local function test(name, fn)
	local ok, err = pcall(fn)
	if ok then
		passed = passed + 1
	else
		failed = failed + 1
		table.insert(errors, { name = name, err = err })
	end
end

local function assert_eq(expected, actual, msg)
	if expected ~= actual then
		error(string.format("%s: expected %s, got %s", msg or "assert_eq", tostring(expected), tostring(actual)), 2)
	end
end

---------------------------------------------------------------------------
-- Engine stub
---------------------------------------------------------------------------

-- A recorder: any method call is remembered as recorder.calls[name] = { args }.
local function recorder(kind)
	local r = { calls = {}, kind = kind }
	return setmetatable(r, {
		__index = function(_, method)
			return function(self, ...)
				r.calls[method] = { ... }
				return self
			end
		end,
	})
end

-- Every unknown global (CONDITION_*, CONST_ME_*, AttrSubId_*, SKILL_*...) becomes
-- a unique placeholder, so tables keyed or compared by them behave.
local placeholders = {}
setmetatable(_G, {
	__index = function(_, name)
		local value = placeholders[name]
		if value == nil then
			value = setmetatable({}, {
				__tostring = function()
					return "<" .. name .. ">"
				end,
			})
			placeholders[name] = value
		end
		return value
	end,
})

Spell = function(kind)
	return recorder("spell:" .. tostring(kind))
end
Combat = function()
	return recorder("combat")
end
Condition = function()
	return recorder("condition")
end
createCombatArea = function(area)
	return area
end

dofile("data/libs/systems/stance.lua")

---------------------------------------------------------------------------
-- Shared Conservation: secondary target selection
---------------------------------------------------------------------------

local function fakePlayer(id, health, maxHealth)
	local p = { id = id, health = health, maxHealth = maxHealth or health }
	function p:getId()
		return self.id
	end
	function p:getHealth()
		return self.health
	end
	function p:getMaxHealth()
		return self.maxHealth
	end
	function p:getPosition()
		return { x = 100 + self.id, y = 100, z = 7 }
	end
	return p
end

-- caster: holds the stance (or not), is in a party of `members` with `leader`,
-- sees every position except those in `offScreen`, sees every creature except
-- those in `invisible`.
local function fakeCaster(opts)
	local c = fakePlayer(opts.id or 1, opts.health or 1000)
	function c:getCondition()
		return opts.stance ~= false and {} or nil
	end
	function c:getParty()
		if not opts.party then
			return nil
		end
		return {
			getMembers = function()
				return opts.party.members
			end,
			getLeader = function()
				return opts.party.leader
			end,
		}
	end
	function c:canSee(position)
		for _, p in ipairs(opts.offScreen or {}) do
			if p:getPosition().x == position.x then
				return false
			end
		end
		return true
	end
	function c:canSeeCreature(creature)
		for _, p in ipairs(opts.invisible or {}) do
			if p == creature then
				return false
			end
		end
		return true
	end
	return c
end

test("target: lowest ABSOLUTE health wins, not lowest fraction", function()
	local knight = fakePlayer(2, 2000, 10000) -- 20%
	local sorcerer = fakePlayer(3, 1000, 2000) -- 50%
	local primary = fakePlayer(9, 50)
	local caster = fakeCaster({ party = { members = { knight, sorcerer }, leader = fakePlayer(4, 5000) } })
	assert_eq(sorcerer, Stance.sharedConservationTarget(caster, primary), "lowest current health")
end)

test("target: the primary heal target is never chosen", function()
	local lowest = fakePlayer(2, 10)
	local other = fakePlayer(3, 500)
	local caster = fakeCaster({ party = { members = { lowest, other }, leader = fakePlayer(4, 5000) } })
	assert_eq(other, Stance.sharedConservationTarget(caster, lowest), "primary excluded")
end)

test("target: a lower-health member off screen is skipped for the next valid one", function()
	local offScreen = fakePlayer(2, 10)
	local visible = fakePlayer(3, 500)
	local caster = fakeCaster({ party = { members = { offScreen, visible }, leader = fakePlayer(4, 5000) }, offScreen = { offScreen } })
	assert_eq(visible, Stance.sharedConservationTarget(caster, fakePlayer(9, 1)), "off-screen skipped")
end)

test("target: an invisible member is skipped", function()
	local invisible = fakePlayer(2, 10)
	local visible = fakePlayer(3, 500)
	local caster = fakeCaster({ party = { members = { invisible, visible }, leader = fakePlayer(4, 5000) }, invisible = { invisible } })
	assert_eq(visible, Stance.sharedConservationTarget(caster, fakePlayer(9, 1)), "invisible skipped")
end)

test("target: the leader counts, once, even when the member list already has them", function()
	local leader = fakePlayer(2, 5)
	local member = fakePlayer(3, 500)
	local caster = fakeCaster({ party = { members = { member, leader }, leader = leader } })
	assert_eq(leader, Stance.sharedConservationTarget(caster, fakePlayer(9, 1)), "leader considered")
	local casterOnly = fakeCaster({ party = { members = { member }, leader = leader } })
	assert_eq(leader, Stance.sharedConservationTarget(casterOnly, fakePlayer(9, 1)), "leader added when not listed")
end)

test("target: the caster themselves can be the second member", function()
	local caster = fakeCaster({ id = 1, health = 5, party = { members = { fakePlayer(3, 500) }, leader = nil } })
	caster.getParty = function()
		return {
			getMembers = function()
				return { caster, fakePlayer(3, 500) }
			end,
			getLeader = function()
				return nil
			end,
		}
	end
	assert_eq(caster, Stance.sharedConservationTarget(caster, fakePlayer(9, 1)), "caster is a party member too")
end)

test("target: no stance, no party, or nobody valid -> nil (the heal is unchanged)", function()
	local member = fakePlayer(2, 10)
	assert_eq(nil, Stance.sharedConservationTarget(fakeCaster({ stance = false, party = { members = { member } } }), fakePlayer(9, 1)), "no stance")
	assert_eq(nil, Stance.sharedConservationTarget(fakeCaster({ party = nil }), fakePlayer(9, 1)), "no party")
	assert_eq(nil, Stance.sharedConservationTarget(fakeCaster({ party = { members = { member } } }), member), "only candidate is the primary")
	local dead = fakePlayer(3, 0)
	assert_eq(nil, Stance.sharedConservationTarget(fakeCaster({ party = { members = { dead } } }), fakePlayer(9, 1)), "a dead member is not a target")
end)

---------------------------------------------------------------------------
-- Stance spells: declared cooldown contracts and families
---------------------------------------------------------------------------

local function loadSpell(path)
	local declared
	local original = Spell
	Spell = function(kind)
		declared = original(kind)
		return declared
	end
	dofile(path)
	Spell = original
	return declared
end

local function expectContract(file, own, primary, secondary, group, secondaryGroup)
	local spell = loadSpell("data/scripts/spells/support/" .. file .. ".lua")
	assert_eq(own * 1000, spell.calls.cooldown[1], file .. " individual cooldown")
	assert_eq(primary * 1000, spell.calls.groupCooldown[1], file .. " primary group cooldown")
	assert_eq(secondary * 1000, spell.calls.groupCooldown[2], file .. " secondary group cooldown")
	assert_eq(group, spell.calls.group[1], file .. " primary group")
	assert_eq(secondaryGroup, spell.calls.group[2], file .. " secondary group")
end

test("Elemental stances: 30s own, 2s Support, 30s Focus (the Elemental family)", function()
	expectContract("master_of_flames", 30, 2, 30, "support", "focus")
	expectContract("master_of_thunder", 30, 2, 30, "support", "focus")
	expectContract("master_of_decay", 30, 2, 30, "support", "focus")
end)

test("Crippling stances: 30s own, 2s Support, 30s Crippling (their own family)", function()
	expectContract("aura_of_sapped_strength", 30, 2, 30, "support", "crippling")
	expectContract("aura_of_exposed_weakness", 30, 2, 30, "support", "crippling")
end)

test("Divine Defiance, Shared Conservation, Sharpshooter: 10s own, 2s Support, 10s Focus", function()
	expectContract("divine_defiance", 10, 2, 10, "support", "focus")
	expectContract("shared_conservation", 10, 2, 10, "support", "focus")
	expectContract("sharpshooter", 10, 2, 10, "support", "focus")
end)

test("Elemental Synthesis: 10s placeholder (UNVERIFIED, stated in the file)", function()
	expectContract("elemental_synthesis", 10, 2, 10, "support", "focus")
end)

test("Blood Rage and Protector keep their own pre-15.25 contract: 2s / 2s / 2s Focus", function()
	expectContract("blood_rage", 2, 2, 2, "support", "focus")
	expectContract("protector", 2, 2, 2, "support", "focus")
end)

test("the Elemental and Crippling families never share a secondary group", function()
	local elemental = loadSpell("data/scripts/spells/support/master_of_thunder.lua").calls.group[2]
	local crippling = loadSpell("data/scripts/spells/support/aura_of_exposed_weakness.lua").calls.group[2]
	assert_eq(true, elemental ~= crippling, "Master of Thunder must not lock Aura of Exposed Weakness")
end)

test("Shared Conservation's condition carries no healing-received buff", function()
	-- The +10% self-heal is the engine's (Player::applySharedConservationSelfHeal);
	-- the condition must not also raise generic healing received.
	local built
	local original = Condition
	Condition = function()
		built = original()
		return built
	end
	loadSpell("data/scripts/spells/support/shared_conservation.lua")
	-- The build function only runs on cast; run it through Stance.condition's shape
	-- by casting on a fake creature that holds nothing.
	local creature = {
		getCondition = function()
			return nil
		end,
		removeCondition = function() end,
		addCondition = function() end,
		getPosition = function()
			return { sendMagicEffect = function() end }
		end,
	}
	Stance.cast(creature, AttrSubId_StanceSharedConservation, Stance.Family.General, function()
		return Stance.condition(AttrSubId_StanceSharedConservation, function() end)
	end)
	Condition = original
	assert_eq(true, built ~= nil, "a condition was built")
	assert_eq(nil, built.calls.setParameter and built.calls.setParameter[1] == CONDITION_PARAM_BUFF_HEALINGRECEIVED and built or nil, "no BUFF_HEALINGRECEIVED on the stance")
end)

test("Stance.cast: recasting the held stance turns it off; another in the family replaces it", function()
	local held = {}
	local removed, added = {}, {}
	local creature = {
		getCondition = function(_, _, _, subId)
			return held[subId]
		end,
		removeCondition = function(_, _, _, subId)
			held[subId] = nil
			table.insert(removed, subId)
		end,
		addCondition = function(_, condition)
			held[condition.subId] = condition
			table.insert(added, condition.subId)
		end,
		getPosition = function()
			return { sendMagicEffect = function() end }
		end,
	}
	local function build(subId)
		return function()
			return { subId = subId }
		end
	end
	local flames, thunder = AttrSubId_StanceMasterOfFlames, AttrSubId_StanceMasterOfThunder
	assert_eq(true, Stance.cast(creature, flames, Stance.Family.Elemental, build(flames)), "first cast")
	assert_eq(true, Stance.active(creature, flames), "Flames on")
	assert_eq(true, Stance.cast(creature, thunder, Stance.Family.Elemental, build(thunder)), "switch")
	assert_eq(false, Stance.active(creature, flames), "Flames replaced")
	assert_eq(true, Stance.active(creature, thunder), "Thunder on")
	assert_eq(true, Stance.cast(creature, thunder, Stance.Family.Elemental, build(thunder)), "recast")
	assert_eq(false, Stance.active(creature, thunder), "recast toggles off")
	-- A Crippling stance does not touch the Elemental one.
	assert_eq(true, Stance.cast(creature, flames, Stance.Family.Elemental, build(flames)), "Flames again")
	assert_eq(true, Stance.cast(creature, AttrSubId_StanceExposedWeakness, Stance.Family.Crippling, build(AttrSubId_StanceExposedWeakness)), "Exposed")
	assert_eq(true, Stance.active(creature, flames), "Flames survives a Crippling cast")
end)

---------------------------------------------------------------------------
-- Results
---------------------------------------------------------------------------
print(string.format("\n%d passed, %d failed", passed, failed))
if #errors > 0 then
	print("\nFailed tests:")
	for _, e in ipairs(errors) do
		print(string.format("  FAIL: %s\n        %s", e.name, e.err))
	end
	os.exit(1)
end
