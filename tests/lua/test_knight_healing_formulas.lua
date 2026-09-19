-- Knight healing, 15.25. Run: luajit tests/lua/test_knight_healing_formulas.lua
--
-- The four Wound Cleansing spells take a per-spell Base Power, the level contribution,
-- Shielding and Magic Level. KnightHealing.values is where every coefficient lives, so
-- it is what is pinned here.
--
-- The expected numbers below are hand-computed from the documented shape rather than
-- recomputed from the table - a test that re-derives the formula it is checking proves
-- only that Lua multiplies.
--
--   common = B(level) * levels + Shielding * shield + basePower
--   min    = common + MagicLevel * mlMin
--   max    = common + MagicLevel * mlMax, or min + flatSpread
--
-- CONFIDENCE: Base Powers are official; the Wound Cleansing and Fair Wound Cleansing
-- Magic Level pairs are corroborated by what this datapack already carried; the
-- SHIELDING COEFFICIENTS ARE COMMUNITY_DERIVED_TUNABLE and not published by CipSoft.
-- If they are retuned, these expectations move with them, and that is the point: the
-- numbers are asserted in exactly one place.

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
-- Engine stub
---------------------------------------------------------------------------

SKILL_SHIELD = 6

local function stubPlayer(levelContribution, shielding)
	return {
		calculateFlatDamageHealing = function()
			return levelContribution
		end,
		getEffectiveSkillLevel = function(_self, skill)
			assert_equal(SKILL_SHIELD, skill, "Knight healing must read Shielding")
			return shielding
		end,
	}
end

dofile("data/libs/functions/knight_healing.lua")

---------------------------------------------------------------------------

local cases = {
	-- levelContribution, shielding, magicLevel, spell, expected min, expected max
	{ 100, 100, 50, "Bruise Bane", 190, 195 },
	{ 100, 100, 50, "Wound Cleansing", 470, 667.5 },
	{ 100, 100, 50, "Fair Wound Cleansing", 1075, 1470 },
	{ 100, 100, 50, "Intense Wound Cleansing", 2200, 3200 },

	{ 20, 0, 0, "Bruise Bane", 35, 40 },
	{ 20, 0, 0, "Wound Cleansing", 90, 90 },
	{ 20, 0, 0, "Fair Wound Cleansing", 265, 265 },
	{ 20, 0, 0, "Intense Wound Cleansing", 540, 540 },

	{ 300, 250, 120, "Bruise Bane", 498, 503 },
	{ 300, 250, 120, "Wound Cleansing", 1100, 1574 },
	{ 300, 250, 120, "Fair Wound Cleansing", 2410, 3358 },
	{ 300, 250, 120, "Intense Wound Cleansing", 4750, 7150 },
}

for _, case in ipairs(cases) do
	local levelContribution, shielding, magicLevel, spellName, expectedMin, expectedMax = case[1], case[2], case[3], case[4], case[5], case[6]
	local label = string.format("%s at B=%d shielding=%d ML=%d", spellName, levelContribution, shielding, magicLevel)
	test(label, function()
		local min, max = KnightHealing.values(spellName, stubPlayer(levelContribution, shielding), magicLevel)
		assert_equal(expectedMin, min, label .. " min")
		assert_equal(expectedMax, max, label .. " max")
	end)
end

test("all four spells have coefficients", function()
	for _, name in ipairs({ "Bruise Bane", "Wound Cleansing", "Fair Wound Cleansing", "Intense Wound Cleansing" }) do
		if not KnightHealing.spells[name] then
			error("no coefficients for " .. name)
		end
	end
end)

test("the official Base Powers are 15 / 70 / 225 / 500", function()
	assert_equal(15, KnightHealing.spells["Bruise Bane"].basePower, "Bruise Bane")
	assert_equal(70, KnightHealing.spells["Wound Cleansing"].basePower, "Wound Cleansing")
	assert_equal(225, KnightHealing.spells["Fair Wound Cleansing"].basePower, "Fair Wound Cleansing")
	assert_equal(500, KnightHealing.spells["Intense Wound Cleansing"].basePower, "Intense Wound Cleansing")
end)

test("the two corroborated Magic Level pairs are unchanged from before 15.25", function()
	-- This datapack already carried 4.0 / 7.95 and 8.0 / 15.9 before the update, and the
	-- reference implementation agrees with both. That agreement is the reason these two
	-- are trusted more than the other two.
	assert_equal(4.0, KnightHealing.spells["Wound Cleansing"].mlMin, "Wound Cleansing min")
	assert_equal(7.95, KnightHealing.spells["Wound Cleansing"].mlMax, "Wound Cleansing max")
	assert_equal(8.0, KnightHealing.spells["Fair Wound Cleansing"].mlMin, "Fair min")
	assert_equal(15.9, KnightHealing.spells["Fair Wound Cleansing"].mlMax, "Fair max")
end)

test("shielding raises the heal, and only through its own coefficient", function()
	local withoutShield = select(1, KnightHealing.values("Wound Cleansing", stubPlayer(100, 0), 10))
	local withShield = select(1, KnightHealing.values("Wound Cleansing", stubPlayer(100, 40), 10))
	assert_equal(40, withShield - withoutShield, "40 Shielding at coefficient 1.0")
end)

test("the bigger two spells count the level contribution twice", function()
	local single = select(1, KnightHealing.values("Wound Cleansing", stubPlayer(0, 0), 0))
	local singleRaised = select(1, KnightHealing.values("Wound Cleansing", stubPlayer(50, 0), 0))
	assert_equal(50, singleRaised - single, "Wound Cleansing counts it once")

	local double = select(1, KnightHealing.values("Intense Wound Cleansing", stubPlayer(0, 0), 0))
	local doubleRaised = select(1, KnightHealing.values("Intense Wound Cleansing", stubPlayer(50, 0), 0))
	assert_equal(100, doubleRaised - double, "Intense Wound Cleansing counts it twice")
end)

test("an unknown spell is refused rather than silently healing nothing", function()
	local ok = pcall(KnightHealing.values, "Exura Vita", stubPlayer(100, 100), 50)
	if ok then
		error("KnightHealing.values accepted a spell it has no coefficients for")
	end
end)

test("the Base Power is added exactly once", function()
	-- Isolate it: no level contribution, no Shielding, no Magic Level. What is left must
	-- be the Base Power itself and not a multiple of it.
	for name, spell in pairs(KnightHealing.spells) do
		local min = select(1, KnightHealing.values(name, stubPlayer(0, 0), 0))
		assert_equal(spell.basePower, min, name .. " must contribute its Base Power once")
	end
end)

test("the level contribution is not applied twice", function()
	-- Raising only the level contribution must move the heal by exactly levels x delta.
	-- A second, hidden application would double the step.
	for name, spell in pairs(KnightHealing.spells) do
		local low = select(1, KnightHealing.values(name, stubPlayer(0, 0), 0))
		local high = select(1, KnightHealing.values(name, stubPlayer(37, 0), 0))
		assert_equal(37 * spell.levels, high - low, name .. " level contribution applied " .. tostring(spell.levels) .. "x")
	end
end)

test("the Shielding term is not applied twice", function()
	for name, spell in pairs(KnightHealing.spells) do
		local low = select(1, KnightHealing.values(name, stubPlayer(0, 0), 0))
		local high = select(1, KnightHealing.values(name, stubPlayer(0, 100), 0))
		assert_equal(100 * spell.shield, high - low, name .. " Shielding applied once")
	end
end)

test("the Magic Level coefficient is the only thing separating min from max", function()
	-- With no Magic Level the two ends collapse onto the common term, except for the one
	-- spell whose spread is a flat constant. That is the shape, stated as an invariant.
	for name, spell in pairs(KnightHealing.spells) do
		local min, max = KnightHealing.values(name, stubPlayer(100, 100), 0)
		if spell.flatSpread then
			assert_equal(spell.flatSpread, max - min, name .. " flat spread")
		else
			assert_equal(0, max - min, name .. " collapses at ML 0")
		end
	end
end)

test("B(L) is what feeds the formula, not level divided by five", function()
	-- The distinction the migration is about. At level 8000 the modern contribution is
	-- 892; level/5 would be 1600. The helper is given the contribution directly here, so
	-- what this pins is that the spell adds whatever the engine's helper returned and
	-- does no level arithmetic of its own.
	local modern = 892
	local legacy = 8000 / 5
	local withModern = select(1, KnightHealing.values("Wound Cleansing", stubPlayer(modern, 0), 0))
	local withLegacy = select(1, KnightHealing.values("Wound Cleansing", stubPlayer(legacy, 0), 0))
	assert_equal(70 + modern, withModern, "modern contribution passes straight through")
	if withModern == withLegacy then
		error("the spell is not reading the contribution it was given")
	end
end)

test("the maximum is never below the minimum", function()
	for name in pairs(KnightHealing.spells) do
		for _, ml in ipairs({ 0, 1, 50, 200 }) do
			local min, max = KnightHealing.values(name, stubPlayer(100, 100), ml)
			if max < min then
				error(string.format("%s at ML %d: max %s below min %s", name, ml, tostring(max), tostring(min)))
			end
		end
	end
end)

---------------------------------------------------------------------------

print(string.format("%d passed, %d failed", passed, failed))
for _, e in ipairs(errors) do
	print(string.format("  FAIL %s: %s", e.name, e.err))
end
os.exit(failed == 0 and 0 or 1)
