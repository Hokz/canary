-- Tests for buildBeamMasteryFlankAreas in data/libs/functions/combat.lua, the
-- geometry behind Beam Mastery's post-July adjacent-square damage.
-- Run: luajit tests/lua/test_beam_mastery_flank_geometry.lua
--
-- The helper is pure table arithmetic, so it is loaded directly with no engine stub.
-- What these tests pin is the shape: two one-tile-wide lines beside the central beam,
-- the central line itself untouched, and the caster's tile marked but not damaged.

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
-- Load the helper
---------------------------------------------------------------------------

-- combat.lua's other functions are methods on the engine's Combat class, which does
-- not exist here; a stub table is enough for the file to load.
Combat = {}

local root = arg[0]:match("^(.*)/tests/lua/[^/]+$") or "."
local chunk = assert(loadfile(root .. "/data/libs/functions/combat.lua"))
chunk()

assert(type(buildBeamMasteryFlankAreas) == "function", "buildBeamMasteryFlankAreas did not load")

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------

-- createCombatArea reads 1 as "damage", 2 as "centre", 3 as "centre and damage".
local DAMAGE, CENTRE = 1, 2

local function countValue(matrix, wanted)
	local total = 0
	for _, row in ipairs(matrix) do
		for _, cell in ipairs(row) do
			if cell == wanted then
				total = total + 1
			end
		end
	end
	return total
end

-- The central cardinal beam as register_spells.lua declares it: a one-tile column with
-- the caster in the last row.
local function centralCardinal(length)
	local matrix = {}
	for _ = 1, length - 1 do
		table.insert(matrix, { DAMAGE })
	end
	table.insert(matrix, { 3 })
	return matrix
end

---------------------------------------------------------------------------
-- Cardinal geometry
---------------------------------------------------------------------------

test("cardinal length 7: exactly 12 flank cells", function()
	local cardinal = buildBeamMasteryFlankAreas(7)
	assert_eq(7, #cardinal, "row count")
	assert_eq(12, countValue(cardinal, DAMAGE), "flank cells")
end)

test("cardinal length 10: exactly 18 flank cells", function()
	local cardinal = buildBeamMasteryFlankAreas(10)
	assert_eq(10, #cardinal, "row count")
	assert_eq(18, countValue(cardinal, DAMAGE), "flank cells")
end)

test("Great Death Beam lengths: BEAM6 = 10, BEAM7 = 12, BEAM8 = 14 flank cells", function()
	assert_eq(10, countValue(buildBeamMasteryFlankAreas(6), DAMAGE), "BEAM6")
	assert_eq(12, countValue(buildBeamMasteryFlankAreas(7), DAMAGE), "BEAM7")
	assert_eq(14, countValue(buildBeamMasteryFlankAreas(8), DAMAGE), "BEAM8")
end)

test("cardinal: nothing on the centre line", function()
	-- Column 2 is where the central beam runs. Every cell of it must be empty, or a
	-- creature standing on the beam would be hit twice.
	local cardinal = buildBeamMasteryFlankAreas(7)
	for y = 1, 6 do
		assert_eq(0, cardinal[y][2], "centre column at row " .. y)
	end
end)

test("cardinal: the caster's tile is a marker, not a damage cell", function()
	local cardinal = buildBeamMasteryFlankAreas(7)
	local last = cardinal[#cardinal]
	assert_eq(0, last[1], "left of the caster")
	assert_eq(CENTRE, last[2], "the caster's own tile")
	assert_eq(0, last[3], "right of the caster")
	-- 3 would mean "centre AND damage", which would put a flank hit under the caster.
	assert_eq(1, countValue(cardinal, CENTRE), "exactly one centre marker")
	assert_eq(0, countValue(cardinal, 3), "no cell is both centre and damage")
end)

test("cardinal: left and right flanks are the same length", function()
	local cardinal = buildBeamMasteryFlankAreas(8)
	local left, right = 0, 0
	for y = 1, #cardinal - 1 do
		assert_eq(3, #cardinal[y], "row width at " .. y)
		if cardinal[y][1] == DAMAGE then
			left = left + 1
		end
		if cardinal[y][3] == DAMAGE then
			right = right + 1
		end
	end
	assert_eq(left, right, "flanks are asymmetric")
	assert_eq(7, left, "one flank cell beside every damaging central cell")
end)

---------------------------------------------------------------------------
-- No overlap with the central beam
---------------------------------------------------------------------------

test("cardinal: the flank and the central beam are disjoint", function()
	for _, length in ipairs({ 6, 7, 8, 10 }) do
		local cardinal = buildBeamMasteryFlankAreas(length)
		local central = centralCardinal(length)
		-- The central matrix is one column wide, and in the flank matrix that column is
		-- index 2. Their intersection has to be empty except for the caster marker.
		for y = 1, length do
			local centralCell = central[y][1]
			local flankCell = cardinal[y][2]
			local centralDamages = centralCell == DAMAGE or centralCell == 3
			local flankDamages = flankCell == DAMAGE or flankCell == 3
			assert_eq(false, centralDamages and flankDamages, string.format("length %d overlaps at row %d", length, y))
		end
	end
end)

---------------------------------------------------------------------------
-- Diagonal geometry
---------------------------------------------------------------------------

test("diagonal length 7: exactly 12 flank cells", function()
	local _, diagonal = buildBeamMasteryFlankAreas(7)
	assert_eq(7, #diagonal, "row count")
	for y = 1, 7 do
		assert_eq(7, #diagonal[y], "row width at " .. y)
	end
	assert_eq(12, countValue(diagonal, DAMAGE), "flank cells")
end)

test("diagonal: no damage on the main diagonal", function()
	-- The central diagonal beam runs down (i, i); the flanks must leave it alone.
	local _, diagonal = buildBeamMasteryFlankAreas(7)
	for i = 1, 6 do
		assert_eq(0, diagonal[i][i], "main diagonal at " .. i)
	end
	assert_eq(CENTRE, diagonal[7][7], "the caster's own tile is the marker")
	assert_eq(0, countValue(diagonal, 3), "no cell is both centre and damage")
	assert_eq(1, countValue(diagonal, CENTRE), "exactly one centre marker")
end)

test("diagonal: one flank cell each side of every damaging central cell", function()
	local _, diagonal = buildBeamMasteryFlankAreas(7)
	for i = 1, 6 do
		-- (i, i+1) is edge-adjacent to (i, i) horizontally...
		assert_eq(DAMAGE, diagonal[i][i + 1], "super-diagonal at " .. i)
		-- ...and (i+1, i) is edge-adjacent vertically.
		assert_eq(DAMAGE, diagonal[i + 1][i], "sub-diagonal at " .. i)
	end
end)

test("diagonal: no cell is counted twice", function()
	-- The super- and sub-diagonals cannot collide: (i, i+1) has column > row and
	-- (i+1, i) has row > column, so the two sets are disjoint by construction. This
	-- pins it by counting rather than by argument.
	for _, length in ipairs({ 5, 6, 7, 8, 10 }) do
		local _, diagonal = buildBeamMasteryFlankAreas(length)
		local seen = {}
		local total = 0
		for y, row in ipairs(diagonal) do
			for x, cell in ipairs(row) do
				if cell == DAMAGE then
					local key = y .. ":" .. x
					assert_eq(nil, seen[key], "duplicate cell " .. key)
					seen[key] = true
					total = total + 1
				end
			end
		end
		assert_eq((length - 1) * 2, total, "flank cells at length " .. length)
	end
end)

---------------------------------------------------------------------------
-- Guardrails
---------------------------------------------------------------------------

test("a length below two is refused", function()
	assert_eq(false, pcall(buildBeamMasteryFlankAreas, 1), "length 1 should be refused")
	assert_eq(false, pcall(buildBeamMasteryFlankAreas, 0), "length 0 should be refused")
	assert_eq(false, pcall(buildBeamMasteryFlankAreas, nil), "no length should be refused")
	assert_eq(false, pcall(buildBeamMasteryFlankAreas, "7"), "a string should be refused")
end)

test("every supported beam length builds both matrices", function()
	for _, length in ipairs({ 5, 6, 7, 8, 10 }) do
		local cardinal, diagonal = buildBeamMasteryFlankAreas(length)
		assert_eq("table", type(cardinal), "cardinal at " .. length)
		assert_eq("table", type(diagonal), "diagonal at " .. length)
		assert_eq(length, #cardinal, "cardinal rows at " .. length)
		assert_eq(length, #diagonal, "diagonal rows at " .. length)
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
