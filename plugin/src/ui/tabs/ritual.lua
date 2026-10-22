-- The Ritual tab: the ritual, focus item, site, number of rituals and alteration glyphs.
-- Placeholder entries until the ritual data is ported.

local settings = require("src/settings")
local signal = require("src/signal")
local widgets = require("src/lib/ui")

local tab = {}

local SITES = { { key = "underworld", label = "The Underworld" }, { key = "ungael", label = "Ungael" } }
local GLYPHS = { "Multiply", "Speed", "Protection", "Attraction" }

local LABEL_W, FIELD_W = 90, 300

-- A label and a dropdown beside it.
local function field(page, label, props)
    widgets.text(page, { text = label, width = LABEL_W })
    props.inline, props.width = true, FIELD_W
    return widgets.combo(page, props)
end

-- A label, - and + buttons, and the count between them.
local function counter(page, label, count)
    widgets.text(page, { text = label, width = LABEL_W })
    widgets.button(page, { label = "-", inline = true, width = 28 })
    widgets.text(page, { text = count, inline = true, width = 40, alignHorizontal = ui.AlignMode.CENTRE })
    widgets.button(page, { label = "+", inline = true, width = 28 })
end

-- Builds the tab on page. Returns a function that disposes its effects.
function tab.build(page, _size)
    return signal.root(function()
        field(page, "Ritual", { entries = { "(no rituals yet)" }, selected = 1 })
        field(page, "Focus", { entries = { "(no focus items yet)" }, selected = 1 })

        -- Dropdown entry IDs must be integers, so each site's is its index.
        local site = settings.site
        local siteLabels = {}
        for i, s in ipairs(SITES) do
            siteLabels[i] = s.label
        end
        field(page, "Site", {
            entries = siteLabels,
            selected = signal.computed(function()
                for i, s in ipairs(SITES) do
                    if s.key == site() then
                        return i
                    end
                end
            end),
            onChange = function(i)
                site(SITES[i].key)
            end,
        })

        -- The buttons will step through multiples of the golden ratio.
        counter(page, "Rituals", "0")
        widgets.text(page, { text = "Golden ratio: -", inline = true })

        widgets.title(page, { text = "Alteration glyphs (0 free spots)" })
        for _, glyph in ipairs(GLYPHS) do
            counter(page, glyph, "0")
        end

        widgets.button(page, { label = "Reset all" })
    end)
end

return tab
