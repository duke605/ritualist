local equipment = require("src/data/equipment")
local gear = require("src/gear")

test("gear slots: every piece of equipment has one, and rails join known slots", function()
    for id, piece in pairs(equipment) do
        assert(gear.SLOT_BY_ID[piece.slot], "equipment " .. id .. " has unknown slot " .. piece.slot)
    end
    for _, rail in ipairs(gear.RAILS) do
        assert(gear.SLOT_BY_ID[rail[1]] and gear.SLOT_BY_ID[rail[2]], "rail joins an unknown slot")
    end
end)

test("gear outfit pieces exist, with xp", function()
    for slot, id in pairs(gear.OUTFIT) do
        assert(equipment[id] and equipment[id].slot == slot, "outfit " .. slot .. " isn't " .. id)
        assert(equipment[id].effects.xp, "outfit " .. slot .. " has no xp")
    end
    assert(equipment[gear.MODIFIED_MASK].slot == "head", "modified mask isn't a head piece")
end)

test("gear wearOutfit keeps other slots and doesn't change worn", function()
    local worn = { ring = { id = 1 }, head = { id = 2 } }
    local result = gear.wearOutfit(worn, true)
    assert(result.ring.id == 1, "kept the ring")
    assert(result.head.id == gear.MODIFIED_MASK, "modified mask on")
    assert(result.feet.id == gear.OUTFIT.feet, "boots on")
    assert(worn.head.id == 2 and worn.feet == nil, "worn unchanged")
    assert(gear.wearOutfit({}, false).head.id == gear.OUTFIT.head, "plain mask")
end)

test("gear effects and glyphs", function()
    local cape = gear.forSlot("back")[1]
    assert(gear.takesGlyph(cape.id), "capes take a glyph")
    assert(gear.effects(cape.id, "Speed I")[1] == "Free alteration glyph: Speed I", "cape effect")
    assert(gear.effects(gear.OUTFIT.head)[1] == "+1% Necromancy XP", "mask effect")
    local alterations = gear.alterationGlyphs()
    assert(#alterations == 12 and alterations[1] == "Multiply I", "12 alteration glyphs, lowest level first")
end)
