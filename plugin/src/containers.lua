-- The player's storage containers, from the client: their backpack, their bank, and the focus storage at the
-- ritual sites. For each, whether its contents are available (the server only sends some at times, such as the
-- bank while it's open), reading them, and importing them into the stock whenever they arrive or change, if
-- that's on.

local inventory = require("src/inventory")
local settings = require("src/settings")
local signal = require("src/signal")
local stock = require("src/stock")

local containers = {}

-- In stock.KEYS order. inv is the container's config.Inv name.
containers.LIST = {
    { key = "backpack", inv = "INV", name = "Backpack" },
    { key = "bank", inv = "BANK", name = "Bank" },
    { key = "focus", inv = "NECRO_RITUAL_FOCUS_INV", name = "Focus storage" },
}

containers.BY_KEY = {}
for _, container in ipairs(containers.LIST) do
    container.available = signal.signal(false) -- Whether its contents can be read now.
    containers.BY_KEY[container.key] = container
end

local EVENT = "ritualist_containers"

local function find(container)
    local invType = config.Inv[container.inv]
    if invType == nil then
        return nil
    end
    local inv = Inventory.Find(invType)
    if inv and inv.isValid then
        return inv
    end
    return nil
end

-- The container an inventory event is about, if it's one of these.
local function containerFor(event)
    for _, container in ipairs(containers.LIST) do
        local invType = config.Inv[container.inv]
        if invType ~= nil and event.inv ~= nil and event.inv.id == invType.id then
            return container
        end
    end
    return nil
end

-- The counts of the calculator's items in the container, or nil if it can't be read now.
function containers.read(container)
    local inv = find(container)
    if not inv then
        return nil
    end
    local slots = {}
    for _, slot in ipairs(inv:GetSlots()) do
        if slot.obj then
            slots[#slots + 1] = { id = slot.obj.id, count = slot.count }
        end
    end
    return inventory.fromSlots(slots)
end

-- Imports the container into its stock (mode as stock.import). Returns whether it could be read.
function containers.import(container, mode)
    local counts = containers.read(container)
    if not counts then
        return false
    end
    stock.import(container.key, counts, mode)
    return true
end

local function changed(event)
    local container = containerFor(event)
    if not container then
        return
    end
    container.available(true)
    if settings.autoImport:peek() then
        containers.import(container, "sync")
    end
end

-- Starts following the containers, importing any already available.
function containers.start()
    for _, container in ipairs(containers.LIST) do
        container.available(find(container) ~= nil)
        if container.available:peek() and settings.autoImport:peek() then
            containers.import(container, "sync")
        end
    end
    Event.InventoryAdded.Subscribe(EVENT, changed)
    Event.InventoryUpdated.Subscribe(EVENT, changed)
    Event.InventoryRemoved.Subscribe(EVENT, function(event)
        local container = containerFor(event)
        if container then
            container.available(false)
        end
    end)
end

function containers.stop()
    Event.InventoryAdded.Unsubscribe(EVENT)
    Event.InventoryUpdated.Unsubscribe(EVENT)
    Event.InventoryRemoved.Unsubscribe(EVENT)
end

return containers
