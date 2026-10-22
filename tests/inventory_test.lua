local inventory = require("src/inventory")
local items = require("src/data/items")

-- Two items the calculator knows.
local VIAL = 227
local ECTOPLASM = 55336
assert(items[VIAL] and items[ECTOPLASM], "test items missing from the data")

test("inventory fromSlots keeps known items, adding stacks together", function()
    local counts = inventory.fromSlots({
        { id = VIAL, count = 10 },
        { id = VIAL, count = 5 },
        { id = ECTOPLASM, count = 0 }, -- A placeholder.
        { id = 999999999, count = 3 }, -- Not an item the calculator uses.
        {}, -- An empty slot.
    })
    assert(counts[VIAL] == 15, "expected 15 vials, got " .. tostring(counts[VIAL]))
    assert(counts[ECTOPLASM] == nil and counts[999999999] == nil, "expected only vials")
end)

test("inventory merge syncs or adds", function()
    local held = { [VIAL] = 10, [ECTOPLASM] = 4 }
    local synced = inventory.merge(held, { [VIAL] = 3 }, "sync")
    assert(synced[VIAL] == 3 and synced[ECTOPLASM] == nil, "sync replaces")
    local added = inventory.merge(held, { [VIAL] = 3 }, "add")
    assert(added[VIAL] == 13 and added[ECTOPLASM] == 4, "add adds")
    assert(held[VIAL] == 10, "held unchanged")
end)

test("inventory serialize round trips, dropping bad entries", function()
    local stored = inventory.serialize({ [VIAL] = 7 })
    assert(stored[tostring(VIAL)] == 7, "string keys")
    stored["999999999"] = 1
    stored["junk"] = 2
    local counts = inventory.deserialize(stored)
    assert(counts[VIAL] == 7, "vials back")
    assert(counts[999999999] == nil and counts.junk == nil, "bad entries dropped")
end)

test("inventory sorted orders by name", function()
    local ids = inventory.sorted({ [VIAL] = 1, [ECTOPLASM] = 1 })
    assert(items[ids[1]].name < items[ids[2]].name, "expected name order")
end)

test("stock keeps containers apart, totals them, and saves on change", function()
    local stock = require("src/stock")
    local saved
    PersistentDB = {
        GetStructuredData = function()
            return { containers = { bank = { items = { [tostring(VIAL)] = 2 } } } }
        end,
        SetStructuredData = function(_, _, value)
            saved = value
            return true
        end,
    }
    stock.load()
    assert(stock.items.bank()[VIAL] == 2 and saved == nil, "loaded, not saved")
    stock.import("focus", { [VIAL] = 3, [ECTOPLASM] = 5 }, "sync")
    assert(stock.items.bank()[VIAL] == 2, "the bank's left alone")
    assert(stock.total()[VIAL] == 5 and stock.total()[ECTOPLASM] == 5, "totals add up")
    assert(saved and saved.containers.focus.items[tostring(ECTOPLASM)] == 5, "saved with string keys")
end)

test("stock moves the old bank-only save into the bank", function()
    local stock = require("src/stock")
    PersistentDB = {
        GetStructuredData = function()
            return { items = { [tostring(VIAL)] = 4 } }
        end,
        SetStructuredData = function()
            return true
        end,
    }
    stock.load()
    assert(stock.items.bank()[VIAL] == 4 and stock.items.focus()[VIAL] == nil, "old items are the bank's")
end)
