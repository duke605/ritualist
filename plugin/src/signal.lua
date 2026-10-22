-- Signals: reactive values that effects depend on just by reading them.
-- Pure Lua with no client API, so it can be tested outside the game (see tests/).
--
--   local ironman = signal.signal(false)
--   signal.effect(function() check:SetDisabled(not ironman()) end) -- runs now, and again when ironman changes
--   ironman(true) -- x() reads, x(v) sets (x(nil) sets nil); x:set(v) and x:peek() also work
--
--   local double = signal.computed(function() return count() * 2 end)
--   local double = count:computed(function(n) return n * 2 end) -- the same, derived from one signal
--
-- Reading a signal (calling it) inside an effect or computed subscribes to it; peek() reads without that.
-- An effect can return a cleanup, which runs before it reruns and when it's disposed. Effects created inside
-- another effect or a root belong to it, and are disposed with it. Values are compared with ==, so setting a
-- new table always counts as a change.

local M = {}

local running -- The effect being run, which reads are tracked for.
local owner -- The effect or root that effects being created belong to.
local queue, queued = {}, {}
local batchDepth, flushing = 0, false
local active = 0 -- Effects created and not yet disposed, for spotting leaks.

local MAX_RUNS = 10000 -- Per flush; more means effects are setting each other in a loop.

local Signal = {}
Signal.__index = Signal

local function removeFrom(list, item)
    for i, v in ipairs(list) do
        if v == item then
            table.remove(list, i)
            return
        end
    end
end

local function flush()
    if flushing or batchDepth > 0 or running then
        return
    end
    flushing = true
    local ok, err = pcall(function()
        local i = 1
        while i <= #queue do
            if i > MAX_RUNS then
                error("signal: effects kept triggering each other")
            end
            local e = queue[i]
            queued[e] = nil
            if not e.disposed then
                M._run(e)
            end
            i = i + 1
        end
    end)
    queue, queued, flushing = {}, {}, false
    if not ok then
        error(err, 0)
    end
end

function Signal:get()
    if running and not self.subscribed[running] then
        self.subscribed[running] = true
        self.subscribers[#self.subscribers + 1] = running
        running.deps[#running.deps + 1] = self
    end
    return self.value
end

-- x() reads (and tracks); x(v) sets. Counts arguments, so x(nil) sets nil rather than reading.
function Signal:__call(...)
    if select("#", ...) == 0 then
        return self:get()
    end
    self:set((...))
end

-- The value, without subscribing the running effect to it.
function Signal:peek()
    return self.value
end

-- Sets the value, rerunning the effects that read it if it changed.
function Signal:set(value)
    if value == self.value then
        return
    end
    self.value = value
    for _, e in ipairs(self.subscribers) do
        if not queued[e] then
            queued[e] = true
            queue[#queue + 1] = e
        end
    end
    flush()
end

-- A computed of fn(this signal's value): x:computed(function(v) return not v end).
function Signal:computed(fn)
    return M.computed(function()
        return fn(self())
    end)
end

local function negate(v)
    return not v
end

-- A computed of not this signal's value.
function Signal:negate()
    return self:computed(negate)
end

function M.signal(value)
    return setmetatable({ value = value, subscribers = {}, subscribed = {} }, Signal)
end

local dispose

-- Undoes an effect's last run: its subscriptions, the effects it created, and its cleanup.
local function reset(e)
    for _, s in ipairs(e.deps) do
        s.subscribed[e] = nil
        removeFrom(s.subscribers, e)
    end
    e.deps = {}
    for i = #e.children, 1, -1 do
        dispose(e.children[i])
    end
    e.children = {}
    if e.cleanup then
        local cleanup = e.cleanup
        e.cleanup = nil
        cleanup()
    end
end

function dispose(e)
    if e.disposed then
        return
    end
    reset(e)
    e.disposed = true
    if e.fn then
        active = active - 1
    end
    if e.parent then
        removeFrom(e.parent.children, e)
    end
end

function M._run(e)
    reset(e)
    local previousRunning, previousOwner = running, owner
    running, owner = e, e
    local ok, result = pcall(e.fn)
    running, owner = previousRunning, previousOwner
    if not ok then
        error(result, 0)
    end
    if type(result) == "function" then
        e.cleanup = result
    end
end

-- Runs fn now, and again whenever a signal it read changes. fn may return a cleanup. Returns a function that
-- disposes the effect.
function M.effect(fn)
    local e = { fn = fn, deps = {}, children = {}, parent = owner }
    if owner then
        owner.children[#owner.children + 1] = e
    end
    active = active + 1
    M._run(e)
    flush()
    return function()
        dispose(e)
    end
end

-- A read-only signal holding fn's result, recomputed when what fn read changes.
function M.computed(fn)
    local s = M.signal(nil)
    M.effect(function()
        s:set(fn())
    end)
    local c
    c = setmetatable({}, {
        __index = {
            get = function()
                return s:get()
            end,
            peek = function()
                return s:peek()
            end,
            computed = function(_, map)
                return M.computed(function()
                    return map(c())
                end)
            end,
            negate = function()
                return c:computed(negate)
            end,
        },
        __computed = true,
        __call = function(_, ...)
            if select("#", ...) > 0 then
                error("signal: a computed is read-only", 2)
            end
            return s:get()
        end,
    })
    return c
end

-- Runs fn(dispose), owning the effects it creates. Returns dispose, which disposes them all.
function M.root(fn)
    local r = { deps = {}, children = {} }
    local function disposeRoot()
        dispose(r)
    end
    local previousOwner = owner
    owner = r
    local ok, err = pcall(fn, disposeRoot)
    owner = previousOwner
    if not ok then
        error(err, 0)
    end
    return disposeRoot
end

-- Runs fn, then the effects its changes triggered, once each.
function M.batch(fn)
    batchDepth = batchDepth + 1
    local ok, err = pcall(fn)
    batchDepth = batchDepth - 1
    if not ok then
        error(err, 0)
    end
    flush()
end

-- Runs fn without subscribing the running effect to what it reads.
function M.untrack(fn)
    local previous = running
    running = nil
    local ok, result = pcall(fn)
    running = previous
    if not ok then
        error(result, 0)
    end
    return result
end

-- Whether v is a signal or computed.
function M.is(v)
    local mt = getmetatable(v)
    return mt == Signal or (mt ~= nil and mt.__computed == true)
end

-- Whether v is a signal that can be set (not a computed).
function M.isWritable(v)
    return getmetatable(v) == Signal
end

-- How many effects (including computeds) are alive, for spotting ones never disposed.
function M.activeEffects()
    return active
end

return M
