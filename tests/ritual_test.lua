local ritual = require("src/ritual")

test("calculate returns the requested count", function()
    local result = ritual.calculate({}, 10)
    assert(result.count == 10, "expected count 10, got " .. tostring(result.count))
end)
