-- Deterministic checks of the 15.25 vocation-balancing damage and healing formulas
-- as the datapack scripts define them. Run: luajit tests/lua/test_vocation_balance_formulas.lua
--
-- Each spell file is loaded against an engine stub and its onGetFormulaValues is
-- called at two representative points: a mid character (level 100, magic level 50)
-- and a high one (level 500, magic level 120). Two things are pinned for each:
--   - the exact values the current coefficients produce, so a coefficient cannot
--     drift silently;
--   - the direction and magnitude of the change against the reference formula
--     (the pre-15.25 datapack formula, or the release-value coefficients where the
--     July balance pass adjusted a new spell): the max coefficient must have moved
--     by the same ratio as the base power, within 2.5%.

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

local function assert_near(expected, actual, tolerance, msg)
	if math.abs(expected - actual) > tolerance then
		error(string.format("%s: expected %s (±%s), got %s", msg or "assert_near", tostring(expected), tostring(tolerance), tostring(actual)), 2)
	end
end

local function assert_ratio(expected, actual, msg)
	assert_near(expected, actual, expected * 0.025, msg)
end

---------------------------------------------------------------------------
-- Engine stub (see test_stance_library.lua)
---------------------------------------------------------------------------

local function recorder()
	local r = { calls = {} }
	return setmetatable(r, {
		__index = function(_, method)
			return function(self, ...)
				r.calls[method] = { ... }
				return self
			end
		end,
	})
end

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

Spell = recorder
Combat = recorder
Condition = recorder
createCombatArea = function(area)
	return area
end
-- data/libs loads before data/scripts (core.lua -> libs/libs.lua -> functions/load.lua),
-- so a spell file may call a library helper at load time. The real one is loaded here
-- rather than faked, so a change to its signature shows up in this suite too.
do
	local root = arg[0]:match("^(.*)/tests/lua/[^/]+$") or "."
	-- combat.lua hangs methods off Combat, which is a recorder factory here, so it is
	-- swapped for a plain table while the library loads and put back afterwards.
	local savedCombat = Combat
	Combat = {}
	assert(loadfile(root .. "/data/libs/functions/combat.lua"))()
	Combat = savedCombat
end
Stance = { sharedConservationTarget = function() end, castSharedConservation = function() end }

-- Loads a spell file and returns its formula callback(s) as globals were left.
local function formulaOf(path, name)
	_G.onGetFormulaValues = nil
	_G.onGetEchoFormulaValues = nil
	_G.onGetSharedFormulaValues = nil
	dofile(path)
	local fn = _G[name or "onGetFormulaValues"]
	assert(type(fn) == "function", path .. " defines no " .. (name or "onGetFormulaValues"))
	return fn
end

local MID = { level = 100, ml = 50 }
local HIGH = { level = 500, ml = 120 }

local function check(path, expectMid, expectHigh, name)
	local f = formulaOf(path, name)
	local min, max = f(nil, MID.level, MID.ml)
	assert_near(expectMid[1], min, 0.01, path .. " mid min")
	assert_near(expectMid[2], max, 0.01, path .. " mid max")
	min, max = f(nil, HIGH.level, HIGH.ml)
	assert_near(expectHigh[1], min, 0.01, path .. " high min")
	assert_near(expectHigh[2], max, 0.01, path .. " high max")
end

local A = "data/scripts/spells/attack/"
local H = "data/scripts/spells/healing/"
local R = "data/scripts/runes/"

---------------------------------------------------------------------------
-- Post-July values on the new spells
---------------------------------------------------------------------------

test("Divine Caldera: base power 150 (level/5 + ml x 4.3 / 6.4)", function()
	check(A .. "divine_caldera.lua", { -235, -340 }, { -616, -868 })
	-- reference: the pre-15.25 datapack, base power 140 <-> 4 / 6
	assert_ratio(150 / 140, 6.4 / 6, "Caldera max coefficient moved as 150/140")
end)

test("Divine Barrage: base power 130 (level/5 + ml x 3.7 / 5.6)", function()
	check(A .. "divine_barrage.lua", { -205, -300 }, { -544, -772 })
	-- reference: Caldera's convention, 140 <-> 6 (max)
	assert_ratio(130 / 140, 5.6 / 6, "Barrage max coefficient is 130/140 of Caldera's release coefficient")
end)

test("Forked Glacier: base power 90 (level/5 + ml x 3.6 / 5.9)", function()
	check(A .. "forked_glacier.lua", { -200, -315 }, { -532, -808 })
	-- reference: the release coefficients at base power 97 were 3.9 / 6.4
	assert_ratio(90 / 97, 5.9 / 6.4, "Glacier max coefficient moved as 90/97")
end)

test("Forked Thorns: base power 97 (level/5 + ml x 3.9 / 6.4)", function()
	check(A .. "forked_thorns.lua", { -215, -340 }, { -568, -868 })
	-- reference: the release coefficients at base power 105 were 4.2 / 6.9
	assert_ratio(97 / 105, 6.4 / 6.9, "Thorns max coefficient moved as 97/105")
end)

test("Death Echo: base power 75, the echo at half", function()
	check(A .. "death_echo.lua", { -170, -265 }, { -460, -688 })
	check(A .. "death_echo.lua", { -85, -132.5 }, { -230, -344 }, "onGetEchoFormulaValues")
end)

---------------------------------------------------------------------------
-- The July balance pass on existing spells (CipSoft note of 7 July)
---------------------------------------------------------------------------

test("Great Death Beam: base power 170 -> 155", function()
	check(A .. "great_death_beam.lua", { -270.5, -430.5 }, { -701.2, -1085.2 })
	-- the datapack's coefficients at base power 170 were 5.5 / 9
	assert_ratio(155 / 170, 8.21 / 9, "Death Beam max coefficient moved as 155/170")
	assert_ratio(155 / 170, 5.01 / 5.5, "Death Beam min coefficient moved as 155/170")
end)

test("Great Energy Beam: base power 170 -> 155", function()
	check(A .. "great_energy_beam.lua", { -202.5, -339 }, { -538, -865.6 })
	-- its own coefficients at base power 170 were 4 / 7
	assert_ratio(155 / 170, 6.38 / 7, "Energy Beam max coefficient moved as 155/170")
	assert_ratio(155 / 170, 3.65 / 4, "Energy Beam min coefficient moved as 155/170")
end)

test("Strong Ice Wave: base damage 150 -> 140, every term scaled", function()
	check(A .. "strong_ice_wave.lua", { -248.67, -419.3 }, { -622.67, -995.6 })
	assert_ratio(140 / 150, 7.09 / 7.6, "Ice Wave max coefficient moved as 140/150")
	assert_ratio(140 / 150, 44.8 / 48, "Ice Wave max constant moved as 140/150")
end)

---------------------------------------------------------------------------
-- Release-value rebalances of existing spells (no later adjustment known)
---------------------------------------------------------------------------

test("Lightning: 70 -> 110", function()
	check(A .. "lightning.lua", { -214, -318 }, { -539, -769 })
	assert_ratio(110 / 70, 5.3 / 3.4, "Lightning max coefficient moved as 110/70")
end)

test("Strong Terra / Ice Strike: 90 -> 115", function()
	for _, f in ipairs({ "strong_terra_strike", "strong_ice_strike" }) do
		check(A .. f .. ".lua", { -220, -336 }, { -552, -808 })
	end
	assert_ratio(115 / 90, 5.6 / 4.4, "Strong Terra/Ice max coefficient moved as 115/90")
end)

test("Strong Energy / Flame Strike: 90 -> 125", function()
	for _, f in ipairs({ "strong_energy_strike", "strong_flame_strike" }) do
		check(A .. f .. ".lua", { -237, -364 }, { -590, -871 })
	end
	assert_ratio(125 / 90, 6.1 / 4.4, "Strong Energy/Flame max coefficient moved as 125/90")
end)

test("Ultimate Terra / Ice Strike: 150 -> 195", function()
	for _, f in ipairs({ "ultimate_terra_strike", "ultimate_ice_strike" }) do
		check(A .. f .. ".lua", { -358, -566.5 }, { -847.5, -1311.5 })
	end
	assert_ratio(195 / 150, 9.5 / 7.3, "Ultimate Terra/Ice max coefficient moved as 195/150")
end)

test("Ultimate Energy / Flame Strike: 150 -> 210", function()
	for _, f in ipairs({ "ultimate_energy_strike", "ultimate_flame_strike" }) do
		check(A .. f .. ".lua", { -384, -607 }, { -905, -1401 })
	end
	assert_ratio(210 / 150, 10.2 / 7.3, "Ultimate Energy/Flame max coefficient moved as 210/150")
end)

test("Wrath of Nature: 150 -> 175", function()
	check(A .. "wrath_of_nature.lua", { -310, -605 }, { -796, -1504 })
	assert_ratio(175 / 150, 11.7 / 10, "Wrath max coefficient moved as 175/150")
end)

test("Salvation: base healing 400 -> 500", function()
	check(H .. "salvation.lua", { 864, 1426 }, { 1994, 3256 })
	assert_ratio(500 / 400, 25 / 20, "Salvation max coefficient moved as 500/400")
end)

test("Nature's Embrace: base healing 650 -> 2000, spread narrowed", function()
	check(H .. "nature's_embrace.lua", { 3540, 3940 }, { 8600, 9560 })
	-- reference: the pre-15.25 datapack, 20 / 28 per magic level (mean 24). The mean
	-- coefficient moves as 2000/650; the spread narrows ("more consistent").
	assert_ratio(2000 / 650, (70 + 78) / (20 + 28), "Nature's Embrace mean coefficient moved as 2000/650")
	if not ((78 - 70) / 74 < (28 - 20) / 24) then
		error("Nature's Embrace spread must be narrower than the pre-15.25 formula's")
	end
end)

test("Heal Friend: unchanged, and the companion heal is 30% of it", function()
	check(H .. "heal_friend.lua", { 523, 725 }, { 1303, 1785 })
	check(H .. "heal_friend.lua", { 523 * 0.3, 725 * 0.3 }, { 1303 * 0.3, 1785 * 0.3 }, "onGetSharedFormulaValues")
end)

test("Stone Shower / Thunderstorm runes: base power 50 (the higher of the two old formulas)", function()
	for _, f in ipairs({ "stone_shower", "thunderstorm" }) do
		local fn = formulaOf(R .. f .. ".lua")
		local min, max = fn(nil, MID.level, MID.ml)
		assert_near(-87, min, 0.01, f .. " mid min")
		assert_near(-177, max, 0.01, f .. " mid max")
	end
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
