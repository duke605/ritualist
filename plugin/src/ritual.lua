-- Ritual maths: inputs, outputs, duration and experience.
-- Pure Lua with no client API, so it can be tested outside the game (see tests/).

local ritual = {}

-- Placeholder until the calculations are ported.
function ritual.calculate(_selection, count)
    return {
        count = count,
        inputs = {},
        outputs = {},
        durationTicks = 0,
        experience = 0,
    }
end

return ritual
