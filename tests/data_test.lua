-- The generated data loads, and what it refers to exists.
local equipment = require("src/data/equipment")
local glyphs = require("src/data/glyphs")
local inks = require("src/data/inks")
local items = require("src/data/items")
local rituals = require("src/data/rituals")

local function count(t)
    local n = 0
    for _ in pairs(t) do
        n = n + 1
    end
    return n
end

test("data modules aren't empty", function()
    for name, t in pairs({ equipment = equipment, glyphs = glyphs, inks = inks, items = items, rituals = rituals }) do
        assert(count(t) > 0, name .. " is empty")
    end
end)

test("rituals use glyphs and items that exist", function()
    for name, ritual in pairs(rituals) do
        for _, glyph in ipairs(ritual.glyphs) do
            assert(glyphs[glyph.name], name .. ": unknown glyph " .. glyph.name)
        end
        for _, focus in ipairs(ritual.focuses) do
            assert(items[focus.input.id], name .. ": unknown focus item " .. focus.input.id)
            for _, output in ipairs(focus.outputs) do
                assert(items[output.id], name .. ": unknown output " .. output.id)
            end
        end
    end
end)

test("glyph inks and equipment exist", function()
    for name, glyph in pairs(glyphs) do
        for ink in pairs(glyph.inks or {}) do
            assert(inks[ink], name .. ": unknown ink " .. ink)
        end
    end
    for id, piece in pairs(equipment) do
        assert(piece.id == id, "equipment " .. id .. " has id " .. tostring(piece.id))
    end
end)
