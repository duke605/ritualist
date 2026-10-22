-- Item counts (item ID -> count) for the items the calculator uses: reading them from inventory slots, merging
-- an import into what's held, and storing them. Pure Lua with no client API, so it can be tested outside the
-- game (see tests/).

local items = require("src/data/items")

local inventory = {}

-- The counts in slots ({ { id, count }, ... }, as read from an inventory) of the items the calculator knows,
-- with stacks of the same item added together. Empty slots and other items are left out.
function inventory.fromSlots(slots)
    local counts = {}
    for _, slot in ipairs(slots) do
        local id, count = slot.id, slot.count or 0
        if id and items[id] and count > 0 then
            counts[id] = (counts[id] or 0) + count
        end
    end
    return counts
end

-- held with incoming merged in: "sync" makes held's counts incoming's (items not in incoming are dropped, as
-- they're no longer there), "add" adds them. A new table; neither is changed.
function inventory.merge(held, incoming, mode)
    local result = {}
    if mode == "add" then
        for id, count in pairs(held) do
            result[id] = count
        end
    end
    for id, count in pairs(incoming) do
        result[id] = (result[id] or 0) + count
    end
    return result
end

-- counts with string keys, for storing (PersistentDB keeps tables, but integer keys may not survive).
function inventory.serialize(counts)
    local stored = {}
    for id, count in pairs(counts) do
        stored[tostring(id)] = count
    end
    return stored
end

-- The counts serialize stored, back with integer keys. Unknown items and bad counts are dropped.
function inventory.deserialize(stored)
    local counts = {}
    for key, count in pairs(stored or {}) do
        local id = math.tointeger(tonumber(key))
        if id and items[id] and type(count) == "number" and count > 0 then
            counts[id] = count
        end
    end
    return counts
end

-- The item IDs in counts, by item name.
function inventory.sorted(counts)
    local ids = {}
    for id in pairs(counts) do
        ids[#ids + 1] = id
    end
    table.sort(ids, function(a, b)
        return items[a].name < items[b].name
    end)
    return ids
end

return inventory
