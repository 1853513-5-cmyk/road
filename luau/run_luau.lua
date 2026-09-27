-- Runner: executes the Luau scene script headless on a Lua 5.4 VM using the shim.
package.path = "./?.lua;./?.luau;/tmp/?.lua;" .. package.path
local shim = require("rbx_shim")
shim.install()
local scene = require("grassRoadScene")

local summary = scene.build(shim.workspace, { skipTerrain = true })

print("=== GrassRoadScene build summary ===")
print("model name      :", summary.model.Name)
print("plate size      :", summary.plateSize)
print("plate color RGB :", string.format("%.0f, %.0f, %.0f",
    summary.plate._attrs.Color.R*255, summary.plate._attrs.Color.G*255, summary.plate._attrs.Color.B*255))
print("road width      :", summary.roadWidth, "studs (plate Z =", summary.plateSize.Z, "->",
    string.format("%.0f%%", summary.roadWidth/summary.plateSize.Z*100), "of field)")
print("road color RGB  :", string.format("%.0f, %.0f, %.0f",
    summary.roadParts[1]._attrs.Color.R*255, summary.roadParts[1]._attrs.Color.G*255, summary.roadParts[1]._attrs.Color.B*255))
print("stud count      :", summary.studCount, "(very little)")
local ok = true
assert(summary.plate._attrs.Size.Y == 1, "plate must be flat (1 stud thick)")
assert(summary.studCount <= 30, "studs must be very few")
for _, s in ipairs(summary.studs) do
    local z = s._attrs.CFrame.Position.Z
    assert(math.abs(z) > scene.Config.RoadWidthStuds/2, "stud found on road!")
end
print("ALL RUNTIME CHECKS PASSED")
