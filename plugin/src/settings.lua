-- User settings: a signal per setting (settings.ironman(), ...), filled from PersistentDB by load() and saved
-- back whenever one changes. The signals exist from the start and never change, so they can be referenced
-- anywhere, even before load().

local signal = require("src/signal")

local KEY = "settings"

local defaults = {
    fromInventory = false,
    ironman = false,
    noWaste = false,
    -- Import the storage containers (bank, focus storage) into the stock whenever the game sends them.
    autoImport = true,
    -- The Storage tab shows what's held all together, rather than a section per container.
    storageTogether = true,
    site = "underworld",
    -- What's worn, by slot: { id = item ID, glyph = alteration glyph name, for capes }. Replaced, never changed
    -- in place, so the change is seen.
    worn = {},
}

local settings = {}
for k, v in pairs(defaults) do
    settings[k] = signal.signal(v)
end

local dispose

-- Sets the settings to their saved values (the defaults for any not saved), and starts saving changes.
function settings.load()
    if dispose then
        dispose()
    end

    local stored = PersistentDB:GetStructuredData(KEY) or {}
    signal.batch(function()
        for k, v in pairs(defaults) do
            if stored[k] == nil then
                settings[k](v)
            else
                settings[k](stored[k])
            end
        end
    end)

    -- Reads every setting, so it reruns when any changes. The first run is the load itself, so isn't saved.
    local loading = true
    dispose = signal.effect(function()
        local values = {}
        for k in pairs(defaults) do
            values[k] = settings[k]()
        end
        if loading then
            loading = false
            return
        end
        PersistentDB:SetStructuredData(KEY, values)
    end)
end

return settings
