-- The Storage tab: the items the calculator uses that the player has in their backpack, bank and focus storage,
-- imported automatically whenever the game sends them (or with the buttons), as a grid of item slots with the
-- totals.

local containers = require("src/containers")
local items = require("src/data/items")
local inventory = require("src/inventory")
local settings = require("src/settings")
local signal = require("src/signal")
local stock = require("src/stock")
local widgets = require("src/lib/ui")

local tab = {}

local SLOT, GAP = 40, 4 -- PrettyUI's item slot size, and the space between slots.
local PADDING = 14
local ROW = 30 -- A row of controls.

local function status(container)
    return function()
        local at = stock.importedAt[container.key]()
        local when = at and os and os.date and os.date("%d %b %H:%M", at)
        local imported = at and ("imported " .. (when or "earlier")) or "nothing imported"
        local now = container.available() and "available now" or "not available now"
        return container.name .. ": " .. now .. ", " .. imported .. "."
    end
end

-- An item's hover text: its name, then how many are in each container.
local function describe(id)
    local lines = { items[id].name }
    for _, container in ipairs(containers.LIST) do
        local count = stock.items[container.key]:peek()[id]
        if count then
            lines[#lines + 1] = container.name .. ": " .. count
        end
    end
    return table.concat(lines, "<br>")
end

-- Places counts' items as a grid of item slots fitting columns, from y. Adds what it creates to made, and
-- returns the y below it.
local function placeGrid(page, counts, columns, y, made)
    local ids = inventory.sorted(counts)
    for i, id in ipairs(ids) do
        local column, row = (i - 1) % columns, (i - 1) // columns
        made[#made + 1] = widgets.itemSlot(page.content, {
            x = PADDING + column * (SLOT + GAP),
            y = y + row * (SLOT + GAP),
            item = id,
            quantity = counts[id],
            tooltip = describe(id),
        })
    end
    return y + math.ceil(#ids / columns) * (SLOT + GAP)
end

-- What's held from y: all together, or a section per container (with a heading, empty ones left out), as the
-- setting says. Rebuilt whenever what's held, the setting or the size change.
local function held(page, size, y)
    signal.effect(function()
        local columns = math.max(1, math.floor((size().width - PADDING * 2 + GAP) / (SLOT + GAP)))
        local made = {}
        local bottom = y
        if settings.storageTogether() then
            bottom = placeGrid(page, stock.total(), columns, bottom, made)
        else
            for _, container in ipairs(containers.LIST) do
                local counts = stock.items[container.key]()
                if next(counts) ~= nil then
                    made[#made + 1] = widgets.title(page, { y = bottom, text = container.name })
                    bottom = placeGrid(page, counts, columns, bottom + 32, made) + 8
                end
            end
        end
        -- Also lays the page out again at its current width.
        page:SetContentHeight(bottom + PADDING)
        -- What made's components created goes with this run; they're destroyed with it.
        return function()
            for _, component in ipairs(made) do
                component:Destroy()
            end
        end
    end)
end

-- Builds the tab on page. Returns a function that disposes its effects.
function tab.build(page, size)
    return signal.root(function()
        local y = 12
        for _, container in ipairs(containers.LIST) do
            widgets.text(page, { y = y, text = status(container) })
            local unavailable = container.available:negate()
            widgets.button(page, {
                y = y + 24,
                x = PADDING,
                label = "Import",
                tooltip = "Replace what's kept from the " .. container.name:lower() .. " with what's in it",
                disabled = unavailable,
                onPress = function()
                    containers.import(container, "sync")
                end,
            })
            widgets.button(page, {
                y = y + 24,
                x = PADDING + 90,
                label = "Add",
                tooltip = "Add what's in the " .. container.name:lower() .. " to what's kept",
                disabled = unavailable,
                onPress = function()
                    containers.import(container, "add")
                end,
            })
            y = y + 24 + ROW + 4
        end

        widgets.checkbox(page, {
            y = y,
            text = "Import automatically whenever the game sends them",
            checked = settings.autoImport,
        })
        widgets.checkbox(page, {
            y = y + ROW,
            text = "Show all together",
            checked = settings.storageTogether,
        })
        widgets.button(page, { y = y + ROW * 2, x = PADDING, label = "Clear all", onPress = stock.clear })

        held(page, size, y + ROW * 3 + 8)
    end)
end

return tab
