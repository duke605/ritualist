-- What the player has of the items the calculator uses (item ID -> count), per storage container (backpack,
-- bank, focus storage), imported from the client, and when; and the total of them all. Signals, loaded from
-- PersistentDB by load() and saved back whenever they change.

local inventory = require("src/inventory")
local signal = require("src/signal")

local stock = {}

-- The containers kept, by key. Each has its own counts, so importing one leaves the others alone.
stock.KEYS = { "backpack", "bank", "focus" }

stock.items = {} -- key -> signal of counts; replaced, never changed in place, so the change is seen.
stock.importedAt = {} -- key -> signal of os.time() of its last import, or nil.
for _, key in ipairs(stock.KEYS) do
    stock.items[key] = signal.signal({})
    stock.importedAt[key] = signal.signal(nil)
end

-- What's held in all the containers together.
stock.total = signal.computed(function()
    local total = {}
    for _, key in ipairs(stock.KEYS) do
        total = inventory.merge(total, stock.items[key](), "add")
    end
    return total
end)

local KEY = "stock"

local dispose

local function now()
    return os and os.time and os.time() or nil
end

-- Sets the stock to what was saved, and starts saving changes.
function stock.load()
    if dispose then
        dispose()
    end

    local stored = PersistentDB:GetStructuredData(KEY) or {}
    -- Before there were containers, only the bank's items were kept, as stored.items.
    if stored.items and not stored.containers then
        stored.containers = { bank = { items = stored.items, importedAt = stored.importedAt } }
    end
    local containers = stored.containers or {}
    signal.batch(function()
        for _, key in ipairs(stock.KEYS) do
            local saved = containers[key] or {}
            stock.items[key](inventory.deserialize(saved.items))
            stock.importedAt[key](saved.importedAt)
        end
    end)

    local loading = true
    dispose = signal.effect(function()
        local data = { containers = {} }
        for _, key in ipairs(stock.KEYS) do
            data.containers[key] = {
                items = inventory.serialize(stock.items[key]()),
                importedAt = stock.importedAt[key](),
            }
        end
        if loading then
            loading = false
            return
        end
        PersistentDB:SetStructuredData(KEY, data)
    end)
end

-- Merges counts (from inventory.fromSlots) into a container's stock: "sync" replaces it, "add" adds to it.
function stock.import(key, counts, mode)
    signal.batch(function()
        stock.items[key](inventory.merge(stock.items[key]:peek(), counts, mode))
        stock.importedAt[key](now())
    end)
end

-- Forgets every container's stock.
function stock.clear()
    signal.batch(function()
        for _, key in ipairs(stock.KEYS) do
            stock.items[key]({})
            stock.importedAt[key](nil)
        end
    end)
end

return stock
