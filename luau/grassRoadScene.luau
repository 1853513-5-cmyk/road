
--[[
	grassRoadScene.luau
	===================
	Generates a flat piece of green grass with only VERY LITTLE stud-like
	texture, and a WIDE dark gray road running through the middle.

	Drop this ModuleScript into Roblox (ServerScriptService / ReplicatedStorage)
	and call it from a Script:

		local g = require(game:GetService("ServerScriptService").grassRoadScene)
		g.build(workspace)

	The module is also unit-testable headless (see test_grassRoadScene.luau):
	`build(parent, opts)` returns a summary table describing what was created,
	without needing task.wait or PhysicsService.
]]

local TerrainService = game:GetService("Terrain")

local GrassRoadScene = {}

------------------------------------------------------------------
-- Configuration (all sizes in studs; 1 stud ~= 0.2 m in Roblox)
------------------------------------------------------------------
GrassRoadScene.Config = {
	-- Flat grass plate
	PlateSize = Vector3.new(240, 1, 160), -- wide, 1-stud thick => FLAT
	GrassColor = Color3.fromRGB(74, 154, 58),

	-- Wide dark gray road across the middle (runs along X)
	RoadWidthStuds = 60, -- ~12 m wide: a genuinely WIDE road
	RoadThicknessStuds = 1, -- flush-ish, stays flat
	RoadColor = Color3.fromRGB(58, 58, 62), -- dark gray asphalt
	CurbColor = Color3.fromRGB(96, 96, 100),
	CurbWidthStuds = 2,

	-- Road markings
	LineDashColor = Color3.fromRGB(235, 205, 70),
	LineDashLength = 8,
	LineDashGap = 8,
	LineDashWidth = 2,
	LineDashThickness = 0.2,

	-- "Very little" stud-like texture: sparse, small decorative cylinders
	StudCount = 24, -- ONLY a few studs on the whole field
	StudRadius = 0.4,
	StudHeight = 0.12, -- barely raised: keeps the piece looking flat
	StudColor = Color3.fromRGB(96, 178, 78), -- slightly lighter than the grass
	StudSeed = 20260926, -- deterministic placement
}

------------------------------------------------------------------
-- Small utilities
------------------------------------------------------------------
local function makePart(props)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.TopSurface = Enum.TopSurface.Smooth
	p.BottomSurface = Enum.BottomSurface.Smooth
	for k, v in pairs(props) do
		(p)[k] = v
	end
	return p
end

-- Deterministic pseudo-random generator (LCG) so builds are reproducible/testable
local function makeRng(seed: number): () -> number
	local state = seed % 2147483647
	if state <= 0 then
		state = state + 2147483647
	end
	return function(): number
		state = (state * 16807) % 2147483647
		return (state - 1) / 2147483646
	end
end

------------------------------------------------------------------
-- Builders
------------------------------------------------------------------
-- The FLAT GREEN GRASS base plate
local function buildGrassPlate(parent, cfg)
	local plate = makePart({
		Name = "GrassPlate",
		Size = cfg.PlateSize,
		Color = cfg.GrassColor,
		Material = Enum.Material.Grass,
		CFrame = CFrame.new(0, cfg.PlateSize.Y / 2, 0), -- top face at y = 1
		Parent = parent,
	})
	return plate
end

-- The WIDE DARK GRAY ROAD through the middle (spans the full length of the plate)
local function buildRoad(parent, cfg)
	local parts: { BasePart } = {}
	local halfDepth = cfg.PlateSize.Z / 2
	local roadY = cfg.PlateSize.Y + cfg.RoadThicknessStuds / 2 -- sits on top of the plate
	local roadLen = cfg.PlateSize.X + 80 -- extends past the grass so it reads as a through-road

	table.insert(parts, makePart({
		Name = "Road",
		Size = Vector3.new(roadLen, cfg.RoadThicknessStuds, cfg.RoadWidthStuds),
		Color = cfg.RoadColor,
		Material = Enum.Material.Asphalt,
		CFrame = CFrame.new(0, roadY, 0),
		Parent = parent,
	}))

	-- Subtle curbs framing the road
	local curbZ = cfg.RoadWidthStuds / 2 + cfg.CurbWidthStuds / 2
	for _, sign in ipairs({ -1, 1 }) do
		table.insert(parts, makePart({
			Name = sign < 0 and "CurbNorth" or "CurbSouth",
			Size = Vector3.new(roadLen, cfg.RoadThicknessStuds + 0.4, cfg.CurbWidthStuds),
			Color = cfg.CurbColor,
			Material = Enum.Material.Concrete,
			CFrame = CFrame.new(0, roadY + 0.2, sign * curbZ),
			Parent = parent,
		}))
	end

	-- Dashed center line
	local dashSpan = cfg.PlateSize.X - 10
	local step = cfg.LineDashLength + cfg.LineDashGap
	local count = math.floor(dashSpan / step) + 1
	local startX = -(count - 1) * step / 2
	for i = 0, count - 1 do
		table.insert(parts, makePart({
			Name = "CenterDash" .. i,
			Size = Vector3.new(cfg.LineDashLength, cfg.LineDashThickness, cfg.LineDashWidth),
			Color = cfg.LineDashColor,
			Material = Enum.Material.Neon,
			CFrame = CFrame.new(startX + i * step, roadY + cfg.RoadThicknessStuds / 2 + cfg.LineDashThickness / 2, 0),
			Parent = parent,
		}))
	end

	return parts
end

-- VERY LITTLE stud-like texture: a handful of tiny low cylinders scattered on
-- the grass only (never on the road band).
local function buildStuds(parent, cfg)
	local studs: { BasePart } = {}
	local rng = makeRng(cfg.StudSeed)
	local halfX = cfg.PlateSize.X / 2 - 4
	local halfZ = cfg.PlateSize.Z / 2 - 4
	local roadEdge = cfg.RoadWidthStuds / 2 + cfg.CurbWidthStuds + 4 -- keep clear of the road
	local topY = cfg.PlateSize.Y

	local attempts = 0
	while #studs < cfg.StudCount and attempts < cfg.StudCount * 50 do
		attempts = attempts + 1
		local x = (rng() * 2 - 1) * halfX
		local z = (rng() * 2 - 1) * halfZ
		if math.abs(z) > roadEdge then -- grass-only placement
			table.insert(studs, makePart({
				Name = "GrassStud" .. #studs,
				Shape = Enum.PartType.Cylinder,
				Size = Vector3.new(cfg.StudHeight, cfg.StudRadius * 2, cfg.StudRadius * 2),
				Color = cfg.StudColor,
				Material = Enum.Material.Grass,
				CFrame = CFrame.Angles(0, 0, math.rad(90)) * CFrame.new(x, topY + cfg.StudHeight / 2, z),
				Parent = parent,
			}))
		end
	end
	return studs
end

-- Optional: paint a soft green grass patch over the terrain under the plate
local function paintTerrain(cfg)
	local region = Region3.new(
		Vector3.new(-cfg.PlateSize.X / 2, -4, -cfg.PlateSize.Z / 2),
		Vector3.new(cfg.PlateSize.X / 2, 0, cfg.PlateSize.Z / 2)
	)
	TerrainService:WriteVoxels(region:ExpandToGrid(4), 1, {
		material = Enum.Material.Grass,
		color = cfg.GrassColor,
	})
end

------------------------------------------------------------------
-- Public API
------------------------------------------------------------------
--[[
	build(parent?, opts?) -> summary
	Creates the scene under `parent` (default: workspace).
	Returns a summary table (used by tests). opts.skipTerrain avoids WriteVoxels.
]]
function GrassRoadScene.build(parent, opts)
	local cfg = GrassRoadScene.Config
	parent = parent or workspace

	local model = Instance.new("Model")
	model.Name = "GrassRoadScene"
	model.Parent = parent

	local plate = buildGrassPlate(model, cfg)
	local roadParts = buildRoad(model, cfg)
	local studs = buildStuds(model, cfg)

	if not (opts and opts.skipTerrain) then
		pcall(paintTerrain, cfg)
	end

	return {
		model = model,
		plate = plate,
		roadParts = roadParts,
		studs = studs,
		studCount = #studs,
		roadWidth = cfg.RoadWidthStuds,
		plateSize = cfg.PlateSize,
	}
end

return GrassRoadScene
