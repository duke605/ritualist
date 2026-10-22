---@meta
-- Editor stubs for the RuneScape client plugin API, for lua-language-server.
-- Not loaded by the game. Add to these as more of the API is used.
-- Reference: https://developer.runescape.com/rs/

---@type table
ui = {}

---@type table
id = {}

-- Game config types (config.Cursor, config.Font, ...).
---@type table
config = {}

-- PrettyUI (https://prettyui.j3.gg/), a required dependency the client exposes under this alias.
---@type table
prettyui = {}

---@class PersistentDB
PersistentDB = {}
---@param key string
---@return table?
function PersistentDB:GetStructuredData(key) end
---@param key string
---@param value table
---@return boolean
function PersistentDB:SetStructuredData(key, value) end

---@class Plugin
---@field urls table<string, string>
---@field resources table
Plugin = {}
---@param permission any
---@return boolean
function Plugin.HasPermission(permission) end

---@enum PluginPermissions
PluginPermissions = { httpAccess = 0, chatAccess = 1, trackingAccess = 2 }

---@type table
Vector4 = {}

---@param ... any
function log(...) end

---@class PlayerAPI
Player = {}
---@return boolean
function Player.IsAvailable() end
---@param skill integer
---@return integer
function Player.GetLevelUncapped(skill) end

---@type table<string, integer>
SkillType = {}

---@type table
Event = {}

---@type table
Inventory = {}
