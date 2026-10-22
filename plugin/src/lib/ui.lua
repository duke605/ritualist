-- PrettyUI components whose props can each be a plain value, a signal, or a function deriving the value from
-- signals (disabled = function() return not ironman() end). A signal prop keeps the component up to
-- date as it changes, and a writable signal given as a value prop (selected, checked) also takes the user's
-- changes. Build inside a signal.root (as the tabs do) so the effects are disposed with it.
--
--   local widgets = require("src/lib/ui") -- Not "ui": that's the client's global.
--   widgets.checkbox(page, { text = "Ironman mode", checked = settings.ironman })
--   widgets.text(page, { text = signal.computed(function() return "Golden ratio: " .. ratio() end), inline = true })
--
-- Other props (layout: inline, width, marginBottom, ...) are passed to PrettyUI as they are, and only read once.

local bind = require("src/lib/ui/bind")
local signal = require("src/signal")

-- The client's ui global, as this module's own table is also called ui.
local ui_ = ui

local ui = {}

-- The props PrettyUI takes as they are: the given props, minus the ones a wrapper handles, with signals and
-- functions read once. Callbacks (on...) are passed on untouched.
local function passThrough(props, handled)
    local options = {}
    for k, v in pairs(props) do
        if not handled[k] then
            options[k] = bind.isCallback(k) and v or bind.initial(v)
        end
    end
    return options
end

local function bindCommon(component, props)
    bind.prop(props.tooltip, function(tooltip)
        component:SetTooltip(tooltip)
    end)
end

local TEXT_PROPS = { text = true, colour = true }

-- A line of text (or a title). Props: text, colour (RGBA), and PrettyUI's text options.
local function text(page, props, isTitle)
    local options = passThrough(props, TEXT_PROPS)
    options.text = tostring(bind.initial(props.text) or "")
    options.colour = bind.initial(props.colour)
    local label = isTitle and page:AddTitle(options) or page:AddText(options)
    bind.prop(props.text, function(value)
        label.content = tostring(value or "")
    end)
    bind.prop(props.colour, function(colour)
        if colour then
            label.rgba = colour
        end
    end)
    return label
end

function ui.text(page, props)
    return text(page, props, false)
end

function ui.title(page, props)
    return text(page, props, true)
end

local COMBO_PROPS = { entries = true, selected = true, disabled = true, tooltip = true, onChange = true }

-- A dropdown. Props: entries (labels, or { label, id } tables), selected (an entry ID), disabled, tooltip,
-- onChange(id). Entry IDs must be integers; plain labels get their index.
function ui.combo(page, props)
    local options = passThrough(props, COMBO_PROPS)
    options.entries = bind.initial(props.entries)
    options.selected = bind.initial(props.selected)
    options.disabled = bind.initial(props.disabled)
    options.tooltip = bind.initial(props.tooltip)
    options.onChange = function(combo, entryID)
        -- Also called for the entry being unselected.
        if combo:GetSelectedID() ~= entryID then
            return
        end
        bind.write(props.selected, entryID)
        if props.onChange then
            props.onChange(entryID)
        end
    end

    local combo = page:AddComboBox(options)
    bind.prop(props.entries, function(entries)
        combo:SetEntries(entries or {}, bind.initial(props.selected))
    end)
    bind.prop(props.selected, function(id)
        combo:Select(id, false)
    end)
    bind.prop(props.disabled, function(disabled)
        combo:SetDisabled(disabled)
    end)
    bindCommon(combo, props)
    return combo
end

local CHECK_PROPS = { text = true, checked = true, disabled = true, tooltip = true, onChange = true }

-- One checkbox (a PrettyUI group of one, so it can be disabled on its own). Props: text, checked, disabled,
-- tooltip, onChange(checked).
function ui.checkbox(page, props)
    local options = passThrough(props, CHECK_PROPS)
    options.disabled = bind.initial(props.disabled)
    options.tooltip = bind.initial(props.tooltip)
    options.onChange = function(_, _, _, checked)
        bind.write(props.checked, checked)
        if props.onChange then
            props.onChange(checked)
        end
    end

    local item = { value = 1, text = tostring(bind.initial(props.text) or ""), selected = bind.initial(props.checked) }
    local check = page:AddCheckboxButton({ item }, options)
    bind.prop(props.text, function(value)
        -- PrettyUI has no setter for a label; items[1].label is its ui.Text.
        check.items[1].label.content = tostring(value or "")
    end)
    bind.prop(props.checked, function(checked)
        check:SetSelected(1, checked == true, false)
    end)
    bind.prop(props.disabled, function(disabled)
        check:SetDisabled(disabled)
    end)
    bindCommon(check, props)
    return check
end

local BUTTON_PROPS = { label = true, onPress = true, disabled = true, active = true, tooltip = true }

-- A button. Props: label, onPress(), disabled, active (shown pressed), tooltip.
-- Not < or > in labels: the game reads < as a text tag.
function ui.button(page, props)
    local options = passThrough(props, BUTTON_PROPS)
    options.disabled = bind.initial(props.disabled)
    options.active = bind.initial(props.active)
    options.tooltip = bind.initial(props.tooltip)

    local button = page:AddSimpleButton(tostring(bind.initial(props.label) or ""), function()
        if props.onPress then
            props.onPress()
        end
    end, options)
    bind.prop(props.label, function(label)
        -- PrettyUI has no setter for a label; content is its ui.Text for text buttons.
        if button.content then
            button.content.content = tostring(label or "")
        end
    end)
    bind.prop(props.disabled, function(disabled)
        button:SetDisabled(disabled)
    end)
    bind.prop(props.active, function(active)
        button:SetActive(active)
    end)
    bindCommon(button, props)
    return button
end

local SLOT_PROPS = {
    item = true,
    quantity = true,
    tooltip = true,
    disabled = true,
    selected = true,
    action = true,
    target = true,
    menu = true,
    onClick = true,
}

-- Right-click menu entries for hovered components, as the game's own components have ("Use <item>"). The
-- menu's last entry is its default, shown in the mouseover text. Each: { component, items() -> { label, run } }.
local menuEntries = {}
local MENU_EVENT = "ritualist_menu"
local ITEM_NAME_COLOUR = "ff9040" -- The game's colour for item names in menus.

local function onMenuReady(event)
    for entry in pairs(menuEntries) do
        local component = entry.component
        if component and component.isMouseOver then
            -- In order, so the last (the default action) ends up on top.
            for _, item in ipairs(entry.items()) do
                event.miniMenu:Add(item.label, item.run)
            end
        end
    end
end

-- A menu label as the game writes them: the action, then its target in the item name colour.
local function menuLabel(action, target)
    if target then
        return action .. " <col=" .. ITEM_NAME_COLOUR .. ">" .. target .. "</col>"
    end
    return action
end

-- Adds a menu entry for component while it's hovered, until the returned function removes it.
local function addMenuEntry(entry)
    if next(menuEntries) == nil then
        Event.MiniMenuReady.Subscribe(MENU_EVENT, onMenuReady)
    end
    menuEntries[entry] = true
    return function()
        menuEntries[entry] = nil
        if next(menuEntries) == nil then
            Event.MiniMenuReady.Unsubscribe(MENU_EVENT)
        end
    end
end

local SLOT_SIZE = 40 -- PrettyUI's item slot size.
local FOLLOW_CURSOR = { followCursor = true }
local TOOLTIP_MARGIN = 6 -- PrettyUI's least space between a tooltip and its parent's edges.

-- Puts a cursor-following PrettyUI tooltip centred under the cursor, as the game's mouseover text is. PrettyUI
-- places a "below" tooltip with its left edge at the cursor, so it's moved left by half its width each time it's
-- shown, staying inside its parent.
local function centreUnderCursor(tooltip)
    local show = tooltip.Show
    function tooltip:Show()
        show(self)
        local root = self.root
        if root == nil or root.hidden then
            return
        end
        local parentWidth = self.parent and self.parent.width or 0
        local x = root.x - math.floor(self.width / 2)
        if parentWidth > 0 then
            x = math.min(x, parentWidth - self.width - TOOLTIP_MARGIN)
        end
        root:SetPos(math.max(TOOLTIP_MARGIN, x), root.y)
    end
end
local SELECTED_COLOUR = Vector4.new(0.92, 0.72, 0.36, 1.0) -- The gold of the game's highlights.

-- An item slot (PrettyUI's), placed at x, y on a plain parent component. Props: item (an item ID, or nil for
-- empty), quantity (shown on the slot, as in the bank), tooltip, disabled (greyed out, and onClick isn't called), selected (outlined), onClick(), and action
-- with target: the right-click menu's default entry while hovered, as the game's own slots have
-- ("Choose <target>"); clicking it calls onClick. menu adds more entries below it:
-- { { action, target, onSelect(), hidden() }, ... }.
function ui.itemSlot(parent, props)
    local options = passThrough(props, SLOT_PROPS)
    options.disabled = bind.initial(props.disabled)
    options.quantity = bind.initial(props.quantity)
    if props.onClick then
        options.clickthrough = false
    end
    local item = bind.initial(props.item)
    local slot = prettyui.ItemSlot.new(parent, item and { id = item } or nil, options)

    local tooltip -- Attached below.
    -- Runs onClick with the tooltip hidden first: what it opens (a dialog, say) covers the slot, so the cursor
    -- never leaves it as far as the game's concerned, and the tooltip would stay up.
    local function click()
        if slot.disabled then
            return
        end
        if tooltip then
            tooltip:Hide()
        end
        props.onClick()
    end
    if props.onClick then
        slot.root:Subscribe(ui_.Hook.ONCLICK, click)
    end
    if (props.action and props.onClick) or props.menu then
        local remove = addMenuEntry({
            component = slot.root,
            items = function()
                local items = {}
                if slot.disabled then
                    return items
                end
                for _, extra in ipairs(props.menu or {}) do
                    if not extra.hidden or not extra.hidden() then
                        items[#items + 1] = {
                            label = menuLabel(extra.action, bind.initial(extra.target)),
                            run = function()
                                if tooltip then
                                    tooltip:Hide()
                                end
                                extra.onSelect()
                            end,
                        }
                    end
                end
                if props.action and props.onClick then
                    items[#items + 1] = {
                        label = menuLabel(bind.initial(props.action), bind.initial(props.target)),
                        run = click,
                    }
                end
                return items
            end,
        })
        -- Removed with whatever's being built (a tab's or dialog's root).
        signal.effect(function()
            return remove
        end)
    end
    if props.selected ~= nil then
        local outline = ui_.Rectangle.new(slot.root)
        outline:SetSize(SLOT_SIZE, SLOT_SIZE)
        outline.outlineThickness = 2
        outline.colour = SELECTED_COLOUR
        outline.clickthrough = true
        outline.hidden = not bind.initial(props.selected)
        bind.prop(props.selected, function(selected)
            outline.hidden = not selected
        end)
    end
    bind.prop(props.item, function(id)
        slot:SetObject(id and { id = id } or nil, bind.initial(props.quantity))
    end)
    bind.prop(props.quantity, function(quantity)
        slot:SetQuantity(quantity)
    end)
    bind.prop(props.disabled, function(disabled)
        slot:SetDisabled(disabled)
    end)

    -- The tooltip follows the cursor, as the game's do. PrettyUI's item slots can't, so it's attached here.
    local function setTooltip(value)
        if tooltip then
            tooltip:Destroy()
            tooltip = nil
        end
        if value ~= nil and value ~= "" then
            tooltip = prettyui.Tooltip.attach(slot.root, parent, { text = value, placement = "below" }, FOLLOW_CURSOR)
            centreUnderCursor(tooltip)
        end
    end
    if bind.isReactive(props.tooltip) then
        bind.prop(props.tooltip, setTooltip)
    else
        setTooltip(props.tooltip)
    end
    signal.effect(function()
        return function()
            setTooltip(nil)
        end
    end)
    return slot
end

-- A sprite on a plain parent component. Props: sprite (an ID, or a name in id.Sprite), x, y, width, height,
-- alpha, tiling, hidden.
function ui.sprite(parent, props)
    local sprite = ui_.Sprite.new(parent)
    sprite:SetPos(props.x or 0, props.y or 0)
    sprite:SetSize(props.width or 0, props.height or 0)
    sprite.clickthrough = true
    if props.tiling then
        sprite.isTiling = true
    end
    local function resolve(value)
        return type(value) == "string" and id.Sprite[value] or value
    end
    sprite.spriteID = resolve(bind.initial(props.sprite)) or -1
    sprite.alpha = bind.initial(props.alpha) or 1
    sprite.hidden = bind.initial(props.hidden) == true
    bind.prop(props.sprite, function(value)
        sprite.spriteID = resolve(value) or -1
    end)
    bind.prop(props.alpha, function(alpha)
        sprite.alpha = alpha or 1
    end)
    bind.prop(props.hidden, function(hidden)
        sprite.hidden = hidden == true
    end)
    return sprite
end

-- A PrettyUI dialog. Props: title, width, height, content(window) (built with these wrappers), actions
-- ({ label, variant = "positive" | "neutral" | "negative", onClick } in order; an onClick returning false keeps
-- the dialog open), onDismiss() (closed without an action), onClose() (closed at all). The effects content
-- creates are disposed when it closes, however it closes.
function ui.dialog(parent, props)
    local dispose, closed = nil, false
    local function disposeContent()
        if dispose then
            local d = dispose
            dispose = nil
            d()
        end
        if not closed then
            closed = true
            if props.onClose then
                props.onClose()
            end
        end
    end

    local actions = {}
    for i, action in ipairs(props.actions or {}) do
        actions[i] = {
            label = action.label,
            variant = action.variant,
            tooltip = action.tooltip,
            onClick = function()
                local close = not action.onClick or action.onClick() ~= false
                if close then
                    disposeContent()
                end
                return close
            end,
        }
    end

    local dialog = prettyui.Dialog.new(parent, {
        title = props.title,
        width = props.width or 320,
        height = props.height or 200,
        actions = actions,
        onDismiss = function()
            disposeContent()
            if props.onDismiss then
                props.onDismiss()
            end
        end,
        content = props.content and function(window)
            dispose = signal.root(function()
                props.content(window)
            end)
        end,
    })
    dialog.disposeContent = disposeContent
    return dialog
end

-- Lets the item slots and other components placed on layer, a plain layer of ours on host (a PrettyUI page or
-- window's content), show their tooltips over everything, as PrettyUI's own do, rather than clipped by layer.
-- Returns a function that undoes it.
function ui.tooltipArea(layer, host)
    local hostContext = prettyui.Tooltip.getContext(host)
    local overlay = hostContext and hostContext.parent
    if not overlay then
        return function() end
    end
    prettyui.Tooltip.registerContext(layer, overlay, function(target)
        local at, origin = target.xyGlobal, overlay.xyGlobal
        return at.x - origin.x, at.y - origin.y
    end, hostContext)
    return function()
        prettyui.Tooltip.unregisterContext(layer)
    end
end

return ui
