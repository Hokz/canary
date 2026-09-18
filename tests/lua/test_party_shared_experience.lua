-- The shared-experience bonus, as data/events/scripts/party.lua defines it.
-- Run: luajit tests/lua/test_party_shared_experience.lua
--
-- This bonus is a DELIBERATE PROJECT DEVIATION from Global 15.25, taken in fe96cb1 and
-- reaffirmed as a product decision during the Stage 1 audit. Global keys the bonus on
-- how many different vocations the party holds (2 -> 35%, 3 -> 70%); this server keys
-- it on party size and ignores composition entirely.
--
-- It is pinned here precisely because it is a deviation: a later fidelity pass that
-- "corrects" it back to the vocation table has to fail this file first and go and ask,
-- rather than silently undoing a decision with an owner.

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

local function assert_equal(expected, actual, msg)
	if expected ~= actual then
		error(string.format("%s: expected %s, got %s", msg or "assert_equal", tostring(expected), tostring(actual)), 2)
	end
end

---------------------------------------------------------------------------
-- Engine stub: just enough Party for the callback to be loaded and called.
---------------------------------------------------------------------------

local memberCount = 0

Party = {}
Party.__index = Party
function Party:getMemberCount()
	return memberCount
end

-- The file registers other party callbacks and touches globals the real engine owns;
-- resolve whatever it asks for to a harmless table/function rather than erroring.
local function permissive(name)
	return setmetatable({}, {
		__index = function()
			return function() end
		end,
		__call = function()
			return nil
		end,
	})
end

setmetatable(_G, {
	__index = function(_, key)
		if key == "Party" then
			return Party
		end
		return permissive(key)
	end,
})

dofile("data/events/scripts/party.lua")
setmetatable(_G, nil)

-- The callback under test, as the datapack installed it.
local onShareExperience = Party.onShareExperience
assert(type(onShareExperience) == "function", "party.lua did not install Party:onShareExperience")

local function share(members, exp)
	memberCount = members - 1 -- getMemberCount() excludes the leader
	return onShareExperience(Party, exp)
end

---------------------------------------------------------------------------
-- The multipliers
---------------------------------------------------------------------------

-- The bonus is applied to the pool and then divided by the party size, so the value
-- returned is ceil(exp * multiplier / size). Working back from that is how each
-- multiplier below is pinned.

test("a solo party receives no bonus", function()
	-- 1000 * 1.0 / 1 = 1000
	assert_equal(1000, share(1, 1000), "solo")
end)

test("two members grant twenty-five percent", function()
	-- 1000 * 1.25 / 2 = 625
	assert_equal(625, share(2, 1000), "two members")
end)

test("three members grant twenty-five percent", function()
	-- 1000 * 1.25 / 3 = 416.67 -> 417
	assert_equal(417, share(3, 1000), "three members")
end)

test("four members grant fifty percent", function()
	-- 1000 * 1.50 / 4 = 375
	assert_equal(375, share(4, 1000), "four members")
end)

test("five members still grant fifty percent", function()
	-- 1000 * 1.50 / 5 = 300
	assert_equal(300, share(5, 1000), "five members")
end)

test("the threshold is at four, not three", function()
	local three = share(3, 1000) * 3
	local four = share(4, 1000) * 4
	if not (four > three) then
		error("the four-member pool must exceed the three-member pool")
	end
end)

test("the result is rounded up", function()
	-- 1 * 1.25 / 2 = 0.625 -> 1, never 0
	assert_equal(1, share(2, 1), "a single experience point is not lost")
end)

test("vocation composition is not consulted", function()
	-- The decisive property of the deviation: nothing about who is in the party
	-- reaches the callback at all. getUniqueVocationsCount is never called, so two
	-- parties of the same size return the same value whatever they are made of.
	local first = share(4, 5000)
	local second = share(4, 5000)
	assert_equal(first, second, "same size, same bonus")
	assert_equal(1875, first, "four members, 5000 experience")
end)

test("zero experience stays zero", function()
	assert_equal(0, share(4, 0), "no experience to share")
end)

---------------------------------------------------------------------------

print(string.format("%d passed, %d failed", passed, failed))
for _, e in ipairs(errors) do
	print(string.format("  FAIL %s: %s", e.name, e.err))
end
os.exit(failed == 0 and 0 or 1)
