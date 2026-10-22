-- Runs the tests for the plugin's pure-Lua modules: lua5.4 tests/run.lua
-- Modules that touch the client API (ui, PersistentDB, ...) aren't testable here.

package.path = "./plugin/?.lua;" .. package.path

local failures, total = 0, 0

function test(name, fn)
    total = total + 1
    local ok, err = pcall(fn)
    if ok then
        print("ok   " .. name)
    else
        failures = failures + 1
        print("FAIL " .. name .. "\n     " .. tostring(err))
    end
end

-- Every tests/*_test.lua, in name order.
local files = {}
for file in assert(io.popen("ls tests/*_test.lua")):lines() do
    files[#files + 1] = file
end
assert(#files > 0, "no tests found; run from the repository root")
for _, file in ipairs(files) do
    dofile(file)
end

print(string.format("\n%d/%d passed", total - failures, total))
os.exit(failures == 0 and 0 or 1)
