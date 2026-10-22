-- Lets a component prop be a plain value, a signal, or a function deriving it from signals. Pure Lua (it only
-- needs src/signal), so it can be tested outside the game (see tests/).
--
-- A function prop works like a computed: disabled = function() return not ironman() end. Props named on...
-- (onChange, onPress, ...) are callbacks, never derived values.

local signal = require("src/signal")

local bind = {}

-- Whether a prop named name is a callback rather than a value.
function bind.isCallback(name)
    return type(name) == "string" and name:match("^on%u") ~= nil
end

local function reactive(prop)
    return signal.is(prop) or type(prop) == "function"
end

-- Whether prop is a signal or function (so it can change), rather than a plain value.
bind.isReactive = reactive

-- The prop's current value, for creating the component, without subscribing to it.
function bind.initial(prop)
    if signal.is(prop) then
        return prop:peek()
    end
    if type(prop) == "function" then
        return signal.untrack(prop)
    end
    return prop
end

-- If prop is a signal or function, calls apply(value) now and whenever it changes, in an effect owned by whatever
-- is being built (a tab's root), so it's disposed with it. A plain value was already used to create the component.
function bind.prop(prop, apply)
    if reactive(prop) then
        signal.effect(function()
            apply(prop())
        end)
    end
end

-- For a component's value prop: writes the user's change back if the prop is a writable signal.
function bind.write(prop, value)
    if signal.isWritable(prop) then
        prop(value)
    end
end

return bind
