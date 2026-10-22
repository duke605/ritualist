-- The calculator window: a PrettyUI window (frame, title bar, close button, dragging) with a tab for each part
-- of the calculator.

local signal = require("src/signal")
local ritualTab = require("src/ui/tabs/ritual")
local gearTab = require("src/ui/tabs/gear")
local resultsTab = require("src/ui/tabs/results")
local storageTab = require("src/ui/tabs/storage")
local optionsTab = require("src/ui/tabs/options")

local window = {}

local WINDOW_BORDER = 8 -- PrettyUI's window border, each side.
local TAB_STRIP = 42 -- The height of PrettyUI's tab strip, above the pages.

local TABS = {
    { label = "Ritual", icon = "SKILL_ICON_NECROMANCY_25PX_0", build = ritualTab.build },
    { label = "Gear", icon = "RS3_MENU_ICON_WORN_EQUIPMENT_NORMAL", build = gearTab.build },
    { label = "Storage", icon = "RS3_ICON_SEND_TO_BANK", build = storageTab.build },
    { label = "Results", icon = "RS3_MENU_ICON_NOTES_NORMAL", build = resultsTab.build },
    { label = "Options", icon = "AIF_SETTINGS_ICON_0", build = optionsTab.build },
}

-- PrettyUI's resize handles have no cursor, so give each edge and corner the game's own. The names come from
-- the cache (index 67); which diagonal is which is a guess.
local RESIZE_CURSORS = {
    n = "TOPLEVEL_V2_SCALE_VERT",
    s = "TOPLEVEL_V2_SCALE_VERT",
    e = "TOPLEVEL_V2_SCALE_HORZ",
    w = "TOPLEVEL_V2_SCALE_HORZ",
    nw = "TOPLEVEL_V2_SCALE_DIAG_1",
    se = "TOPLEVEL_V2_SCALE_DIAG_1",
    ne = "TOPLEVEL_V2_SCALE_DIAG_2",
    sw = "TOPLEVEL_V2_SCALE_DIAG_2",
}

local function setResizeCursors(view)
    local handles = view.resize and view.resize.handles or {}
    for key, name in pairs(RESIZE_CURSORS) do
        local cursor = config.Cursor[name]
        if handles[key] and cursor then
            handles[key].cursorConfig.mouseOverCursor = cursor.id or cursor
        end
    end
end

function window.open()
    if window.view then
        window.view:Show()
        return
    end

    local gameArea = ui.Interfaces:GetComponent(id.Component.TOPLEVEL_V2__GAME_AREA)
    local view = prettyui.Window.new(gameArea, {
        title = "Ritualist",
        width = 460,
        height = 440,
        minWidth = 440,
        minHeight = 240,
        resizable = true,
        scrollable = false,
    })

    -- Icon tabs (the game's own sprites), named in their tooltips; a text tab if an icon's missing.
    local specs = {}
    for i, tab in ipairs(TABS) do
        local icon = id.Sprite[tab.icon]
        specs[i] = icon and { kind = "icon", icon = icon, tooltip = tab.label, value = tab.label } or tab.label
    end
    local tabs = view:AddTabs(specs, { height = 380 })

    -- A tab page's size, for tabs that lay out to it. Worked out from the window's, which is reliable, unlike
    -- the pages' own while they're built.
    local function tabSize()
        return { width = view.root.width - WINDOW_BORDER * 2, height = tabs.root.height - TAB_STRIP }
    end
    local size = signal.signal(tabSize())

    -- Each tab disposes its own effects, through the function its build returns. The count from before they're
    -- built is checked on close, to catch any a tab forgot.
    window.effects = signal.activeEffects()
    window.cleanups = {}
    for i, tab in ipairs(TABS) do
        window.cleanups[tab.label] = tab.build(tabs:GetPage(i), size)
    end

    -- PrettyUI's tabs keep their height, so stretch them with the window (each page scrolls what doesn't fit).
    local margin = view.root.height - tabs.root.height
    local setSize = view.SetSize
    function view:SetSize(width, height)
        setSize(self, width, height)
        tabs.root:SetHeight(self.root.height - margin)
        size(tabSize())
    end
    setResizeCursors(view)

    view:Show()
    window.view = view
end

function window.close()
    for _, cleanup in pairs(window.cleanups or {}) do
        cleanup()
    end
    window.cleanups = nil
    if window.effects then
        local leaked = signal.activeEffects() - window.effects
        if leaked > 0 then
            print(string.format("[Ritualist] %d effect(s) left after closing the window: a leak", leaked))
        end
        window.effects = nil
    end
    if window.view then
        window.view:Destroy()
        window.view = nil
    end
end

return window
