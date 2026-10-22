-- Requirements (skill levels and quests) and checking them against a player.
-- Pure Lua with no client API, so it can be tested outside the game (see tests/).
--
--   local req = { levels = { necromancy = 120 }, quests = { "SOME_QUEST" } }
--   requirements.unmet(req, player) --> { "120 Necromancy" } (nothing if they're all met)
--
-- player has level(skill) -> number or nil, and hasQuest(name) -> boolean or nil. nil means unknown (stats not
-- loaded yet, say), which counts as met: don't lock things on a guess.

local requirements = {}

local SKILL_NAMES = { necromancy = "Necromancy" }

-- The quest names as players know them, by their config.Quest name. Unknown ones are shown as they are.
requirements.QUEST_NAMES = {}

local function sorted(t)
    local keys = {}
    for k in pairs(t or {}) do
        keys[#keys + 1] = k
    end
    table.sort(keys)
    return keys
end

-- What of req the player doesn't meet, a line each ("120 Necromancy", "Quest: ..."). Empty if all are met.
function requirements.unmet(req, player)
    local missing = {}
    if not req then
        return missing
    end
    for _, skill in ipairs(sorted(req.levels)) do
        local needed = req.levels[skill]
        local level = player.level(skill)
        if level ~= nil and level < needed then
            missing[#missing + 1] = needed .. " " .. (SKILL_NAMES[skill] or skill)
        end
    end
    for _, quest in ipairs(req.quests or {}) do
        if player.hasQuest(quest) == false then
            missing[#missing + 1] = "Quest: " .. (requirements.QUEST_NAMES[quest] or quest)
        end
    end
    return missing
end

-- Whether the player meets all of req.
function requirements.met(req, player)
    return #requirements.unmet(req, player) == 0
end

return requirements
