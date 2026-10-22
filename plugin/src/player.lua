-- The local player's skill levels (as signals, kept up to date as they change) and quests, from the client.
-- Fits requirements.unmet's player: player.level(skill), player.hasQuest(name).

local signal = require("src/signal")

local player = {}

local EVENT = "ritualist"

-- The skills tracked, by the names requirements use, with their SkillType names.
local SKILLS = { necromancy = "NECROMANCY" }

-- Each skill's real level (not boosted), or nil while unknown.
player.levels = {}
for skill in pairs(SKILLS) do
    player.levels[skill] = signal.signal(nil)
end

local function read()
    if not Player.IsAvailable() then
        return
    end
    signal.batch(function()
        for skill, name in pairs(SKILLS) do
            player.levels[skill](Player.GetLevelUncapped(SkillType[name]))
        end
    end)
end

-- The skill's level, tracked (in an effect, it reruns when the level changes). nil while unknown.
function player.level(skill)
    local level = player.levels[skill]
    return level and level()
end

-- Whether the quest (its config.Quest name) is finished. nil if the client doesn't know it.
function player.hasQuest(name)
    local quest = config.Quest[name]
    if quest == nil then
        return nil
    end
    return quest.hasFinishedQuest
end

-- Reads the levels now, and again whenever a skill changes.
function player.start()
    read()
    Event.SkillTransmit.Subscribe(EVENT, function()
        read()
    end)
end

function player.stop()
    Event.SkillTransmit.Unsubscribe(EVENT)
end

return player
