local bind = require("src/lib/ui/bind")
local signal = require("src/signal")

test("bind initial reads plain values and signals without subscribing", function()
    local s = signal.signal("a")
    assert(bind.initial("x") == "x" and bind.initial(nil) == nil, "plain values pass through")
    local runs = 0
    local dispose = signal.effect(function()
        runs = runs + 1
        bind.initial(s)
    end)
    s("b")
    dispose()
    assert(runs == 1, "initial subscribed the effect")
end)

test("bind prop applies a signal now and on change, until its root is disposed", function()
    local s = signal.signal(1)
    local applied = {}
    local dispose = signal.root(function()
        bind.prop(s, function(v)
            applied[#applied + 1] = v
        end)
        bind.prop("static", function()
            error("a plain value shouldn't be bound")
        end)
    end)
    s(2)
    dispose()
    s(3)
    assert(#applied == 2 and applied[1] == 1 and applied[2] == 2, "expected 1 then 2")
end)

test("bind write sets writable signals only", function()
    local s = signal.signal(false)
    local c = signal.computed(function()
        return s()
    end)
    bind.write(s, true)
    bind.write(c, false) -- Ignored: computeds are read-only.
    bind.write("plain", true) -- Ignored.
    assert(s() == true, "expected the signal written")
    assert(signal.is(c) and not signal.isWritable(c), "computed is a signal but not writable")
end)

test("bind function props derive from the signals they read", function()
    local ironman = signal.signal(false)
    local disabled = function()
        return not ironman()
    end
    assert(bind.initial(disabled) == true, "expected the initial derived value")
    local applied = {}
    local dispose = signal.root(function()
        bind.prop(disabled, function(v)
            applied[#applied + 1] = v
        end)
    end)
    ironman(true)
    dispose()
    assert(#applied == 2 and applied[1] == true and applied[2] == false, "expected true then false")
end)

test("bind treats on... props as callbacks", function()
    assert(bind.isCallback("onChange") and bind.isCallback("onPress"), "on... are callbacks")
    assert(not bind.isCallback("disabled") and not bind.isCallback("one"), "others aren't")
end)
