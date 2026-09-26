
--[[
	rbx_shim.luau
	=============
	A tiny Roblox-API shim so Luau scene scripts can be executed and verified
	headless with a plain Lua/Luau VM (no Roblox engine needed).

	Implements just enough of: Instance.new, game:GetService, workspace,
	Enum, Vector3, CFrame, Color3, Region3, task.wait, os.clock.

	Usage:
		local shim = require("rbx_shim")        -- or dofile / pcall(require,...)
		shim.install()                          -- injects globals
		local scene = require("grassRoadScene")
		local summary = scene.build(shim.workspace, { skipTerrain = true })
]]

local RBXShim = {}

------------------------------------------------------------------ data types
local Vector3 = {}
Vector3.__index = Vector3
local function vec3(x, y, z)
	return setmetatable({ X = x, Y = y, Z = z }, Vector3)
end
Vector3.new = vec3
function Vector3.__add(a, b) return vec3(a.X + b.X, a.Y + b.Y, a.Z + b.Z) end
function Vector3.__sub(a, b) return vec3(a.X - b.X, a.Y - b.Y, a.Z - b.Z) end
function Vector3.__mul(a, b)
	if type(b) == "number" then return vec3(a.X * b, a.Y * b, a.Z * b) end
	if type(a) == "number" then return vec3(b.X * a, b.Y * a, b.Z * a) end
	return vec3(a.X * b.X, a.Y * b.Y, a.Z * b.Z) -- component-wise (good enough here)
end
function Vector3.__tostring(v) return string.format("(%.2f, %.2f, %.2f)", v.X, v.Y, v.Z) end
function Vector3.Magnitude(v) return math.sqrt(v.X ^ 2 + v.Y ^ 2 + v.Z ^ 2) end

local Color3 = {}
Color3.__index = Color3
local function color3(r, g, b) return setmetatable({ R = r, G = g, B = b }, Color3) end
Color3.new = color3
Color3.fromRGB = function(r, g, b) return color3(r / 255, g / 255, b / 255) end
Color3.fromValue = color3

local CFrame = {}
CFrame.__index = CFrame
local function cframeFromPos(pos)
	return setmetatable({ Position = pos, _rot = nil }, CFrame)
end
CFrame.new = function(x, y, z)
	if typeof0(x) == "Vector3" then return cframeFromPos(x) end
	return cframeFromPos(vec3(x or 0, y or 0, z or 0))
end
CFrame.Angles = function(rx, ry, rz)
	local c = cframeFromPos(vec3(0, 0, 0))
	c._rot = vec3(rx, ry, rz)
	return c
end
CFrame.lookAt = function(from, to) return cframeFromPos(from) end
function CFrame.__mul(a, b)
	if getmetatable(b) == CFrame then
		return cframeFromPos(a.Position + b.Position)
	end
	return cframeFromPos(a.Position + b) -- CFrame * Vector3
end

-- minimal typeof helper used above/below (works for shim types)
function typeof0(v)
	local mt = getmetatable(v)
	if mt == Vector3 then return "Vector3" end
	if mt == CFrame then return "CFrame" end
	if mt == Color3 then return "Color3" end
	return type(v)
end

local Region3 = {}
Region3.__index = Region3
Region3.new = function(c1, c2) return setmetatable({ c1 = c1, c2 = c2 }, Region3) end
function Region3.ExpandToGrid(r, grid) return r end

------------------------------------------------------------------ instances
local InstanceMt = {}

local function newInstance(className)
	local self = {
	getClassName = function(s) return s._class end,
		_class = className,
		_children = {},
		_attrs = {},
		Name = className,
	}
	function self.Destroy(s)
		if s._parent then
			local kids = s._parent._children
			for i, k in ipairs(kids) do
				if k == s then
					table.remove(kids, i)
					break
				end
			end
			s._parent = nil
		end
	end
	function self.FindFirstChild(s, name)
		for _, c in ipairs(s._children) do
			if c.Name == name then return c end
		end
		return nil
	end
	function self.GetChildren(s) return s._children end
	setmetatable(self, InstanceMt)
	return self
end

function InstanceMt.__index(t, k)
	if rawget(t, k) ~= nil then return rawget(t, k) end
	local attrs = rawget(t, "_attrs")
	if attrs then return attrs[k] end
	return nil
end

function InstanceMt.__newindex(t, k, v)
	if k == "Parent" then
		rawset(t, "Parent", v)
		rawset(t, "_parent", v)
		if v then table.insert(v._children, t) end
	else
		local attrs = rawget(t, "_attrs")
		if not attrs then
			attrs = {}
			rawset(t, "_attrs", attrs)
		end
		attrs[k] = v
	end
end

RBXShim.Instance = { new = newInstance }

------------------------------------------------------------------ enums
local function makeEnum(names)
	local e = {}
	for _, n in ipairs(names) do
		e[n] = { Name = n, Value = n }
	end
	return setmetatable(e, {
		__index = function(_, k)
			error("attempted to use Enum value '" .. tostring(k) .. "' which does not exist")
		end,
	})
end

RBXShim.Enum = {
	TopSurface = makeEnum({ "Smooth", "Stud", "Inlet", "Weld", "Glue", "Universal" }),
	BottomSurface = makeEnum({ "Smooth", "Stud", "Inlet", "Weld", "Glue", "Universal" }),
	PartType = makeEnum({ "Block", "Cylinder", "Sphere" }),
	Material = makeEnum({
		"Plastic", "Grass", "Asphalt", "Concrete", "Neon", "Slate",
		"Pavement", "Sand", "Water", "Fabric", "Ground",
	}),
	SortOrder = makeEnum({ "Layout", "Name", "Custom" }),
	EasingStyle = makeEnum({ "Quad", "Linear", "Sine" }),
}

------------------------------------------------------------------ services / dataModel
local Terrain = newInstance("Terrain")
function Terrain.WriteVoxels(t, region, scale, mask)
	t._lastWrite = { region = region, mask = mask }
end

local ServerScriptService = newInstance("ServerScriptService")
local ReplicatedStorage = newInstance("ReplicatedStorage")
local Lighting = newInstance("Lighting")
local RunService = newInstance("RunService")
local CollectionService = newInstance("CollectionService")

local workspace = newInstance("Workspace")
workspace.CurrentCamera = nil

local services = {
	Terrain = Terrain,
	ServerScriptService = ServerScriptService,
	ReplicatedStorage = ReplicatedStorage,
	Lighting = Lighting,
	RunService = RunService,
	CollectionService = CollectionService,
	Workspace = workspace,
	Players = newInstance("Players"),
	HttpService = newInstance("HttpService"),
}

local game = newInstance("DataModel")
game.Parent = nil
function game.GetService(g, name)
	local s = services[name]
	if not s then error("unknown service: " .. tostring(name)) end
	return s
end
game.Workspace = workspace

------------------------------------------------------------------ misc globals
RBXShim.task = { wait = function(_) end }
RBXShim.osClock = os.clock

------------------------------------------------------------------ install
function RBXShim.install()
	_G.Instance = RBXShim.Instance
	_G.Enum = RBXShim.Enum
	_G.Vector3 = Vector3
	_G.CFrame = CFrame
	_G.Color3 = Color3
	_G.Region3 = Region3
	_G.game = game
	_G.workspace = workspace
	_G.task = RBXShim.task
	_G.warn = warn or print
	_G.tick = os.clock
	_G.delay = function(_, f) f() end
	_G.spawn = function(f, ...) f(...) end
	_G.wait = function(_) end
	-- Luau's typeof() isn't available in stock Lua; provide it globally
	_G.typeof = typeof0
end

RBXShim.workspace = workspace
RBXShim.Vector3 = Vector3
RBXShim.CFrame = CFrame
RBXShim.Color3 = Color3
RBXShim.newInstanceOf = newInstance

return RBXShim
