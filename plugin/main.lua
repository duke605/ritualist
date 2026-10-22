-- Ritualist: a Necromancy ritual calculator.
-- Entry point; runs each time the plugin is enabled (pon / prl ritualist).

local containers = require("src/containers")
local player = require("src/player")
local settings = require("src/settings")
local stock = require("src/stock")
local window = require("src/ui/window")

settings.load()
stock.load()
player.start()
containers.start()
window.open()

-- Called by the client when the plugin is disabled or reloaded.
function PluginShutdown()
    window.close()
    containers.stop()
    player.stop()
end

print("Ritualist loaded")
