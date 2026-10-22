-- Gear that changes rituals: the Worn Equipment layout, what goes in each slot, the ritualist's outfit, and what
-- each piece does. Ported from the web app's choose-gear.tsx and equipment.tsx.
-- Pure Lua with no client API, so it can be tested outside the game (see tests/).

local equipment = require("src/data/equipment")
local glyphs = require("src/data/glyphs")

local gear = {}

-- Every slot, positioned on a grid of half-slot columns as in the game's Worn Equipment, with its index in the
-- client's RS3_ICON_WORN_EQUIPMENT_<n> sprites (its empty-slot silhouette).
gear.SLOTS = {
    { id = "head", label = "Head", column = 4, row = 1, icon = 0 },
    { id = "pocket", label = "Pocket", column = 6, row = 1, icon = 12 },
    { id = "back", label = "Back", column = 2, row = 2, icon = 1 },
    { id = "neck", label = "Neck", column = 4, row = 2, icon = 2 },
    { id = "ammo", label = "Ammo", column = 6, row = 2, icon = 10 },
    { id = "mainHand", label = "Main hand", column = 1, row = 3, icon = 3 },
    { id = "torso", label = "Torso", column = 4, row = 3, icon = 5 },
    { id = "offHand", label = "Off-hand", column = 7, row = 3, icon = 6 },
    { id = "legs", label = "Legs", column = 4, row = 4, icon = 7 },
    { id = "hands", label = "Hands", column = 1, row = 5, icon = 8 },
    { id = "feet", label = "Feet", column = 4, row = 5, icon = 9 },
    { id = "ring", label = "Ring", column = 7, row = 5, icon = 4 },
}

-- Slots joined by a rail. The first is above or left of the second.
gear.RAILS = {
    { "head", "neck" },
    { "neck", "torso" },
    { "torso", "legs" },
    { "legs", "feet" },
    { "back", "neck" },
    { "neck", "ammo" },
    { "mainHand", "torso" },
    { "torso", "offHand" },
    { "mainHand", "hands" },
    { "offHand", "ring" },
}

gear.SLOT_BY_ID = {}
for _, slot in ipairs(gear.SLOTS) do
    gear.SLOT_BY_ID[slot.id] = slot
end

-- The ritualist's outfit, by slot, and the modified mask that can replace its mask.
gear.OUTFIT = { head = 57697, torso = 57698, legs = 57699, hands = 57700, feet = 57701 }
gear.MODIFIED_MASK = 57696

-- In a slot's choices, for all of the outfit at once: with the plain mask, or the modified one.
gear.ENTIRE_OUTFIT, gear.ENTIRE_MODIFIED_OUTFIT = -1, -2

-- What's needed to wear gear, by item ID (see src/requirements). Gear not listed needs nothing. From the
-- RuneScape Wiki; the web app's data doesn't have them.
gear.REQUIREMENTS = {
    [55203] = { levels = { necromancy = 99 } }, -- Necromancy cape
    [55208] = { levels = { necromancy = 120 } }, -- Necromancy master cape
}

-- The gear for a slot, by name.
function gear.forSlot(slot)
    local pieces = {}
    for _, piece in pairs(equipment) do
        if piece.slot == slot then
            pieces[#pieces + 1] = piece
        end
    end
    table.sort(pieces, function(a, b)
        return a.name < b.name
    end)
    return pieces
end

-- Whether gear with this id takes an alteration glyph (the Necromancy capes).
function gear.takesGlyph(id)
    local piece = equipment[id]
    return piece ~= nil and piece.effects.glyph ~= nil
end

-- The alteration glyphs, by level.
function gear.alterationGlyphs()
    local names = {}
    for name, glyph in pairs(glyphs) do
        if glyph.alteration then
            names[#names + 1] = name
        end
    end
    table.sort(names, function(a, b)
        return glyphs[a].level < glyphs[b].level
    end)
    return names
end

-- worn (slot -> { id, glyph }) with all of the outfit on, the modified mask or the plain one, over whatever else
-- is in its slots. A new table; worn isn't changed.
function gear.wearOutfit(worn, modified)
    local result = {}
    for slot, piece in pairs(worn) do
        result[slot] = piece
    end
    for slot, id in pairs(gear.OUTFIT) do
        result[slot] = { id = (slot == "head" and modified) and gear.MODIFIED_MASK or id }
    end
    return result
end

-- What a piece of gear does for rituals, a line each, with the glyph chosen for it if it takes one.
function gear.effects(id, glyph)
    local e = equipment[id] and equipment[id].effects or {}
    local lines = {}
    local function add(line)
        lines[#lines + 1] = line
    end
    if e.xp then
        add("+" .. e.xp .. "% Necromancy XP")
    end
    if e.focusSave then
        add(e.focusSave .. "% chance to keep the focus")
    end
    if e.lights then
        add((e.lights == "all" and "Light sources" or "Tier 1 and 2 light sources") .. " don't wear out")
    end
    if e.alterationBoost then
        add("Alteration glyphs " .. e.alterationBoost .. "% stronger")
    end
    if e.necroplasm then
        add("+" .. e.necroplasm .. "% necroplasm")
    end
    if e.disturbanceXp then
        add("+" .. e.disturbanceXp .. "% XP from disturbances")
    end
    if e.soulAttraction then
        add("+" .. e.soulAttraction .. "% soul attraction")
    end
    if e.doubleRewards then
        add(e.doubleRewards .. "% chance to double disturbance rewards")
    end
    if e.glyph then
        add("Free alteration glyph: " .. (glyph or "none"))
    end
    return lines
end

return gear
