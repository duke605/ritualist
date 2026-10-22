-- The Gear tab: Worn Equipment as the game lays it out, as on the website. Clicking a slot with gear that changes
-- rituals opens a dialog to choose what's worn there.

local gear = require("src/gear")
local equipment = require("src/data/equipment")
local player = require("src/player")
local requirements = require("src/requirements")
local settings = require("src/settings")
local signal = require("src/signal")
local widgets = require("src/lib/ui")

local tab = {}

local SLOT = 40 -- PrettyUI's item slot size.
local HALF = 24 -- A half-slot column: half of a slot and the gap after it.
local ROW = 48
local RAIL = 6 -- Rail thickness.
local ICON_INSET = 4
local PADDING = 14 -- The least space beside the doll, when the window's too small to centre it.

-- The slots there's gear for.
local CHOOSABLE = {}
for _, piece in pairs(equipment) do
    CHOOSABLE[piece.slot] = true
end

local function position(slot)
    return (slot.column - 1) * HALF, (slot.row - 1) * ROW
end

-- The rails between slots, edge to edge: slot backgrounds are see-through, so a rail under one would show.
local function drawRails(doll)
    for _, rail in ipairs(gear.RAILS) do
        local a, b = gear.SLOT_BY_ID[rail[1]], gear.SLOT_BY_ID[rail[2]]
        local ax, ay = position(a)
        local bx, by = position(b)
        if a.row == b.row then
            widgets.sprite(doll, {
                sprite = "AIF_WORN_CONCT_HORZ_LINE_2_1",
                tiling = true,
                x = ax + SLOT,
                y = ay + (SLOT - RAIL) / 2,
                width = bx - ax - SLOT,
                height = RAIL,
            })
        else
            widgets.sprite(doll, {
                sprite = "AIF_WORN_CONCT_VERT_LINE_2_1",
                tiling = true,
                x = ax + (SLOT - RAIL) / 2,
                y = ay + SLOT,
                width = RAIL,
                height = by - ay - SLOT,
            })
        end
    end
end

local NUMBER_COLOUR = "6fcf6f" -- Bonuses, in green.
local NEEDS_COLOUR = "ff5050" -- What's missing, in red.

local function colour(text, hex)
    return "<col=" .. hex .. ">" .. text .. "</col>"
end

-- Hover text for gear (by item ID, with a cape's glyph): its name, what it does with the numbers coloured, and
-- what's missing to wear it. Lines are broken with <br>: the game shows a newline as a box.
local function describe(name, id, glyph, missing)
    local lines = { name }
    for _, line in ipairs(id and gear.effects(id, glyph) or {}) do
        lines[#lines + 1] = line:gsub("[+%-]?%d+%%?", function(number)
            return colour(number, NUMBER_COLOUR)
        end)
    end
    if missing and #missing > 0 then
        lines[#lines + 1] = colour("Needs " .. table.concat(missing, ", "), NEEDS_COLOUR)
    end
    return table.concat(lines, "<br>")
end

-- The hover text for what's worn in a slot.
local function tooltip(piece)
    if not piece then
        return nil
    end
    local name = equipment[piece.id] and equipment[piece.id].name or tostring(piece.id)
    return describe(name, piece.id, piece.glyph)
end

-- What's needed to wear choice (an item ID, or one of the whole-outfit choices), a line each; empty if it can be
-- worn. Tracks the player's levels, so it updates as they change.
local function unmet(choice)
    return requirements.unmet(gear.REQUIREMENTS[choice], player)
end

-- The choices for slot, in order: nothing, its gear, and in the outfit's slots the whole outfit. Each has an id,
-- a name, and the item shown for it.
local function choicesFor(slot)
    local choices = { { id = 0, name = "Nothing" } }
    for _, piece in ipairs(gear.forSlot(slot.id)) do
        choices[#choices + 1] = { id = piece.id, name = piece.name, item = piece.id }
    end
    if gear.OUTFIT[slot.id] then
        choices[#choices + 1] =
            { id = gear.ENTIRE_OUTFIT, name = "Entire Ritualist's Outfit", item = gear.OUTFIT.torso }
        choices[#choices + 1] = {
            id = gear.ENTIRE_MODIFIED_OUTFIT,
            name = "Entire Ritualist's Outfit (modified)",
            item = gear.MODIFIED_MASK,
        }
    end
    return choices
end

local PICK_GAP = 8

-- The dialog for choosing what's worn in slot: its gear as item slots to pick from (gear that can't be worn
-- greyed out, with why), and for a cape its alteration glyph. Nothing changes until Choose.
local function choose(parent, slot, onClose)
    local worn = settings.worn
    local current = worn:peek()[slot.id]
    local choices = choicesFor(slot)

    -- Only slots with gear that takes a glyph (the capes) ask for one.
    local asksGlyph = false
    for _, piece in ipairs(gear.forSlot(slot.id)) do
        asksGlyph = asksGlyph or gear.takesGlyph(piece.id)
    end

    local glyphNames = gear.alterationGlyphs()
    local glyphEntries = { { label = "None", id = 0 } }
    local currentGlyph = 0
    for i, name in ipairs(glyphNames) do
        glyphEntries[#glyphEntries + 1] = { label = name, id = i }
        if current and current.glyph == name then
            currentGlyph = i
        end
    end

    local choice = signal.signal(current and current.id or 0)
    local glyph = signal.signal(currentGlyph)

    local function copyWorn()
        local next = {}
        for k, v in pairs(worn:peek()) do
            next[k] = v
        end
        return next
    end

    local function save()
        local id = choice:peek()
        if id == gear.ENTIRE_OUTFIT or id == gear.ENTIRE_MODIFIED_OUTFIT then
            worn(gear.wearOutfit(worn:peek(), id == gear.ENTIRE_MODIFIED_OUTFIT))
            return
        end
        local next = copyWorn()
        if id == 0 then
            next[slot.id] = nil
        else
            next[slot.id] = { id = id, glyph = gear.takesGlyph(id) and glyphNames[glyph:peek()] or nil }
        end
        worn(next)
    end

    local actions = {}
    actions[#actions + 1] = { label = "Cancel" }
    actions[#actions + 1] = {
        label = "Choose",
        variant = "positive",
        onClick = function()
            -- Gear that can't be worn can't be picked, but what was worn might be.
            if #unmet(choice:peek()) > 0 then
                return false
            end
            save()
        end,
    }

    local width = math.max(360, #choices * (SLOT + PICK_GAP) + 40)
    return widgets.dialog(parent, {
        title = "Choose " .. slot.label:lower(),
        width = width,
        height = asksGlyph and 230 or 170,
        actions = actions,
        onClose = onClose,
        content = function(window)
            -- Straight on the dialog's content, which PrettyUI shows tooltips over everything for.
            for i, c in ipairs(choices) do
                widgets.itemSlot(window.content, {
                    x = 14 + (i - 1) * (SLOT + PICK_GAP),
                    y = 12,
                    item = c.item,
                    selected = function()
                        return choice() == c.id
                    end,
                    disabled = function()
                        return #unmet(c.id) > 0
                    end,
                    tooltip = function()
                        return describe(c.name, c.item and equipment[c.id] and c.id, nil, unmet(c.id))
                    end,
                    action = "Choose",
                    target = c.name,
                    onClick = function()
                        choice(c.id)
                    end,
                })
            end

            -- The choice's name, under the row.
            widgets.text(window, {
                y = 12 + SLOT + 8,
                text = function()
                    for _, c in ipairs(choices) do
                        if c.id == choice() then
                            return c.name
                        end
                    end
                    return ""
                end,
            })

            if asksGlyph then
                widgets.text(window, { y = 12 + SLOT + 40, text = "Alteration glyph" })
                widgets.combo(window, {
                    y = 12 + SLOT + 66,
                    entries = glyphEntries,
                    selected = glyph,
                    disabled = function()
                        return not gear.takesGlyph(choice())
                    end,
                })
            end
        end,
    })
end

-- Builds the tab on page, centred in size (a signal of the page's { width, height }). Returns a function that
-- disposes its effects.
function tab.build(page, size)
    return signal.root(function()
        local width = 6 * HALF + SLOT
        local height = 4 * ROW + SLOT
        -- On the page's root, which is always the page's size. Its scrolling content area only resizes when
        -- PrettyUI lays it out again, so the doll would be clipped there when the window grows.
        local doll = ui.Layer.new(page.root)
        doll:SetSize(width, height)
        -- Centred by hand, keeping clear of the edges when the window's too small to centre it.
        signal.effect(function()
            local area = size()
            doll:SetPos(
                math.max(PADDING, math.floor((area.width - width) / 2)),
                math.max(PADDING, math.floor((area.height - height) / 2))
            )
        end)

        drawRails(doll)
        local untooltip = widgets.tooltipArea(doll, page.content)

        local open -- The dialog open for a slot, if one is.
        for _, slot in ipairs(gear.SLOTS) do
            local x, y = position(slot)
            local piece = function()
                return settings.worn()[slot.id]
            end
            widgets.itemSlot(doll, {
                x = x,
                y = y,
                item = function()
                    local p = piece()
                    return p and p.id
                end,
                tooltip = function()
                    return tooltip(piece())
                end,
                action = CHOOSABLE[slot.id] and "Change" or nil,
                menu = {
                    {
                        action = "Unequip",
                        target = function()
                            local p = piece()
                            return p and equipment[p.id] and equipment[p.id].name
                        end,
                        hidden = function()
                            return piece() == nil
                        end,
                        onSelect = function()
                            local next = {}
                            for k, v in pairs(settings.worn:peek()) do
                                next[k] = v
                            end
                            next[slot.id] = nil
                            settings.worn(next)
                        end,
                    },
                },
                target = function()
                    local p = piece()
                    return p and equipment[p.id] and equipment[p.id].name or slot.label
                end,
                onClick = CHOOSABLE[slot.id] and function()
                    local previous = open
                    if previous then
                        previous.disposeContent()
                        previous:Destroy()
                    end
                    local parent = ui.Interfaces:GetComponent(id.Component.TOPLEVEL_V2__GAME_AREA)
                    open = choose(parent, slot, function()
                        open = nil
                    end)
                end,
            })
            -- The empty slot's silhouette, as in the game.
            widgets.sprite(doll, {
                sprite = "RS3_ICON_WORN_EQUIPMENT_" .. slot.icon,
                x = x + ICON_INSET,
                y = y + ICON_INSET,
                width = SLOT - ICON_INSET * 2,
                height = SLOT - ICON_INSET * 2,
                alpha = CHOOSABLE[slot.id] and 0.6 or 0.3,
                hidden = function()
                    return piece() ~= nil
                end,
            })
        end

        -- A dialog still open when the tab goes is closed with it.
        signal.effect(function()
            return function()
                untooltip()
                local dialog = open
                if dialog then
                    dialog.disposeContent() -- Destroy may not count as a dismiss.
                    dialog:Destroy()
                end
            end
        end)
    end)
end

return tab
