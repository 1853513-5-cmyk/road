-- headless test runner (LuaUnit-style, works with stub or real LuaUnit)
package.path = "./?.lua;/tmp/?.lua;" .. package.path
local T = require("test_grassRoadScene")
local passed, failed = 0, 0
for _, name in ipairs({"testPlateIsFlatGreen","testRoadWideDarkGrayCentered","testStudsAreVeryFewAndOffRoad","testDeterministic"}) do
local ok, err = pcall(function()
local self = setmetatable({}, {__index = T})
self:setUp(); local status, e = pcall(T[name], self); self:tearDown()
if not status then error(e) end
end)
if ok then passed = passed + 1; print("PASS", name)
else failed = failed + 1; print("FAIL", name, err) end
end
print(string.format("%d passed, %d failed", passed, failed))
os.exit(failed == 0 and 0 or 1)
