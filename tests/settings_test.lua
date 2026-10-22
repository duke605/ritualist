-- settings only touches PersistentDB when called, so a stub stands in for the client's.
local settings = require("src/settings")

local saved

local function stubDB(stored)
    saved = nil
    PersistentDB = {
        GetStructuredData = function()
            return stored
        end,
        SetStructuredData = function(_, _, value)
            saved = value
            return true
        end,
    }
end

test("settings load false defaults as false, not nil", function()
    stubDB(nil)
    settings.load()
    local s = settings
    assert(s.ironman() == false, "expected ironman false, got " .. tostring(s.ironman()))
    assert(s.noWaste() == false, "expected noWaste false, got " .. tostring(s.noWaste()))
end)

test("settings load stored values over defaults", function()
    stubDB({ ironman = true, site = "ungael" })
    settings.load()
    local s = settings
    assert(s.ironman() == true, "expected ironman true")
    assert(s.site() == "ungael", "expected site ungael")
    assert(s.fromInventory() == false, "expected fromInventory false")
end)

test("settings are saved when they change, not on load", function()
    stubDB(nil)
    settings.load()
    local s = settings
    assert(saved == nil, "saved on load")
    s.ironman(true)
    assert(saved and saved.ironman == true and saved.site == "underworld", "expected all settings saved")
end)

test("settings signals stay the same across loads", function()
    local ironman = settings.ironman
    stubDB({ ironman = true })
    settings.load()
    assert(settings.ironman == ironman, "expected the same signal")
    assert(ironman() == true, "expected the loaded value")
end)
