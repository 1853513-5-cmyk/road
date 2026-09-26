--[[
	test_grassRoadScene.luau
	========================
	LuaUnit-style unit tests for grassRoadScene.

	In Roblox Studio: paste into a Script in ServerScriptService together with
	a vendored LuaUnit (https://github.com/bluebird75/luaunit) and the
	grassRoadScene ModuleScript, then require & run this module's tests.

	Headless (this repo):  lua5.4 test_grassRoadScene.lua
	(the .lua file is generated from this .luau by strip_luau.py; a small
	LuaUnit-compatible stub at /tmp/luaunit.lua is used when the real
	LuaUnit isn't installed).
]]
local shim = require("rbx_shim")
shim.install()
local lu = require("luaunit") -- real LuaUnit or minimal stub
local GrassRoadScene = require("grassRoadScene")

local TestGrassRoadScene = {}

function TestGrassRoadScene:setUp()
	self.fixture = Instance.new("Folder")
	self.fixture.Name = "TestFixture"
	self.summary = GrassRoadScene.build(self.fixture, { skipTerrain = true })
end

function TestGrassRoadScene:tearDown()
	self.fixture:Destroy()
end

-- the base plate must be FLAT and GREEN
function TestGrassRoadScene:testPlateIsFlatGreen()
	local plate = self.summary.plate
	lu.assertEquals(plate.Name, "GrassPlate")
	lu.assertEquals(plate._attrs.Size.Y, 1, "plate should be 1 stud thick (flat)")
	local c = plate._attrs.Color
	lu.assertGE(c.G * 255, 100, "green channel dominant")
	lu.assertLE(c.R, c.G, "more green than red")
	lu.assertLE(c.B, c.G, "more green than blue")
end

-- the road must be WIDE, DARK GRAY, and centered
function TestGrassRoadScene:testRoadWideDarkGrayCentered()
	local cfg = GrassRoadScene.Config
	local road = self.summary.roadParts[1]
	lu.assertEquals(road.Name, "Road")
	-- wide: at least 30% of the field depth
	lu.assertGE(cfg.RoadWidthStuds / cfg.PlateSize.Z, 0.3, "road should be wide")
	-- dark gray: channels nearly equal, low intensity
	local c = road._attrs.Color
	lu.assertEquals(math.floor(c.R * 255), 58)
	lu.assertEquals(math.floor(c.G * 255), 58)
	lu.assertEquals(math.floor(c.B * 255), 62)
	-- centered on Z = 0
	lu.assertEquals(road._attrs.CFrame.Position.Z, 0)
end

-- only VERY LITTLE studs, tiny, and never on the road
function TestGrassRoadScene:testStudsAreVeryFewAndOffRoad()
	local cfg = GrassRoadScene.Config
	lu.assertLE(self.summary.studCount, 30, "studs must be very few")
	for _, s in ipairs(self.summary.studCount and self.summary.studs or {}) do
		lu.assertLE(s._attrs.Size.X, 0.5, "stud height must be tiny (flat look)")
		lu.assertGE(math.abs(s._attrs.CFrame.Position.Z),
			cfg.RoadWidthStuds / 2, "no studs on the road")
	end
end

-- deterministic placement (same seed -> same scene)
function TestGrassRoadScene:testDeterministic()
	local fixture2 = Instance.new("Folder")
	local s2 = GrassRoadScene.build(fixture2, { skipTerrain = true })
	lu.assertEquals(#s2.studs, self.summary.studCount)
	lu.assertEquals(s2.studs[1]._attrs.CFrame.Position.X,
		self.summary.studs[1]._attrs.CFrame.Position.X)
	fixture2:Destroy()
end

return TestGrassRoadScene
