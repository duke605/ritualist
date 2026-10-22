-- The Options tab: settings that change what the results include, each a checkbox bound to its setting.

local settings = require("src/settings")
local signal = require("src/signal")
local widgets = require("src/lib/ui")

local tab = {}

-- PrettyUI's left padding for page content, plus the indent for options that depend on another.
local PADDING, INDENT = 14, 8 -- INDENT: Tailwind 2 (0.5rem)

-- requires is the setting the option needs on to be enabled; such options are indented under it.
local OPTIONS = {
    { text = "Take from inventory", value = settings.fromInventory },
    { text = "Ironman mode", value = settings.ironman },
    -- Its value is kept while disabled, as on the website.
    { text = "No waste (Ironman only)", value = settings.noWaste, requires = settings.ironman },
}

-- Builds the tab on page. Returns a function that disposes its effects.
function tab.build(page, _size)
    return signal.root(function()
        for i, option in ipairs(OPTIONS) do
            widgets.checkbox(page, {
                text = option.text,
                checked = option.value,
                disabled = option.requires and option.requires:negate(),
                x = option.requires and PADDING + INDENT or nil,
                -- No gap between the checkboxes, so they read as one list.
                marginBottom = i < #OPTIONS and 0 or nil,
            })
        end
    end)
end

return tab
