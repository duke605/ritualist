local gear = require("src/gear")
local requirements = require("src/requirements")

local function playerWith(levels, quests)
    return {
        level = function(skill)
            return levels[skill]
        end,
        hasQuest = function(name)
            return quests[name]
        end,
    }
end

test("requirements list what's unmet", function()
    local req = { levels = { necromancy = 120 }, quests = { "A", "B" } }
    local missing = requirements.unmet(req, playerWith({ necromancy = 99 }, { A = true, B = false }))
    assert(#missing == 2 and missing[1] == "120 Necromancy" and missing[2] == "Quest: B", table.concat(missing, ", "))
end)

test("requirements met, missing and unknown", function()
    local req = { levels = { necromancy = 99 } }
    assert(requirements.met(req, playerWith({ necromancy = 99 }, {})), "99 meets 99")
    assert(not requirements.met(req, playerWith({ necromancy = 98 }, {})), "98 doesn't")
    assert(requirements.met(req, playerWith({}, {})), "an unknown level counts as met")
    assert(requirements.met({ quests = { "Q" } }, playerWith({}, {})), "an unknown quest counts as met")
    assert(requirements.met(nil, playerWith({}, {})), "no requirements are met")
end)

test("requirements for gear refer to real gear", function()
    local equipment = require("src/data/equipment")
    for id in pairs(gear.REQUIREMENTS) do
        assert(equipment[id], "no equipment " .. id)
    end
end)
