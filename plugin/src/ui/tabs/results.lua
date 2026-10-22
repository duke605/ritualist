-- The Results tab: the rituals to perform, their input and output, and the totals.
-- Placeholder text until the ritual maths is ported.

local widgets = require("src/lib/ui")

local tab = {}

local SECTIONS = {
    { title = "Rituals to perform", lines = { "-" } },
    { title = "Input", lines = { "-" } },
    { title = "Output", lines = { "-" } },
    {
        title = "Totals",
        lines = { "Input: 0 gp", "Output: 0 gp", "P&L: 0 gp", "Duration: -", "Experience: 0", "Disturbances: 0" },
    },
}

-- Builds the tab on page. No effects yet; a tab that creates them returns a function that disposes them.
function tab.build(page, _size)
    for _, section in ipairs(SECTIONS) do
        widgets.title(page, { text = section.title })
        for _, line in ipairs(section.lines) do
            widgets.text(page, { text = line })
        end
    end
end

return tab
