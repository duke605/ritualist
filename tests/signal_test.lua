local signal = require("src/signal")

test("signal effect runs now and when what it read changes", function()
    local ironman = signal.signal(false)
    local seen = {}
    local dispose = signal.effect(function()
        seen[#seen + 1] = ironman()
    end)
    ironman(true)
    ironman(true)
    dispose()
    assert(#seen == 2 and seen[1] == false and seen[2] == true, "expected false then true")
end)

test("signal effect ignores signals it didn't read, and peeks", function()
    local a, b = signal.signal(1), signal.signal(1)
    local runs = 0
    local dispose = signal.effect(function()
        runs = runs + 1
        local _ = a() + b:peek()
    end)
    b(2)
    a(2)
    dispose()
    assert(runs == 2, "expected 2 runs, got " .. runs)
end)

test("signal dependencies follow branches", function()
    local useA, a, b = signal.signal(true), signal.signal("a"), signal.signal("b")
    local got
    local dispose = signal.effect(function()
        got = useA() and a() or b()
    end)
    useA(false)
    a("A") -- No longer read, so no rerun.
    assert(got == "b", "expected b, got " .. tostring(got))
    b("B")
    dispose()
    assert(got == "B", "expected B, got " .. tostring(got))
end)

test("signal computed updates, and a diamond runs its effect once", function()
    local count = signal.signal(1)
    local double = signal.computed(function()
        return count() * 2
    end)
    local triple = signal.computed(function()
        return count() * 3
    end)
    local runs, sum = 0, nil
    local dispose = signal.root(function()
        signal.effect(function()
            runs = runs + 1
            sum = double() + triple()
        end)
    end)
    count(2)
    dispose()
    assert(sum == 10, "expected 10, got " .. tostring(sum))
    assert(runs == 2, "expected 2 runs, got " .. runs)
end)

test("signal cleanup runs before each rerun and on dispose", function()
    local v = signal.signal(1)
    local events = {}
    local dispose = signal.effect(function()
        local value = v()
        events[#events + 1] = "setup " .. value
        return function()
            events[#events + 1] = "cleanup " .. value
        end
    end)
    v(2)
    dispose()
    v(3)
    local got = table.concat(events, ", ")
    assert(got == "setup 1, cleanup 1, setup 2, cleanup 2", "got " .. got)
end)

test("signal root disposes the effects created in it", function()
    local before = signal.activeEffects()
    local v = signal.signal(1)
    local runs = 0
    local dispose = signal.root(function()
        signal.effect(function()
            runs = runs + 1
            local _ = v()
        end)
        signal.computed(function()
            return v()
        end)
    end)
    assert(signal.activeEffects() == before + 2, "expected 2 more effects")
    dispose()
    v(2)
    assert(runs == 1, "expected no rerun after dispose")
    assert(signal.activeEffects() == before, "expected effects back to " .. before)
end)

test("signal batch runs each effect once", function()
    local a, b = signal.signal(1), signal.signal(1)
    local runs = 0
    local dispose = signal.effect(function()
        runs = runs + 1
        local _ = a() + b()
    end)
    signal.batch(function()
        a(2)
        b(2)
    end)
    dispose()
    assert(runs == 2, "expected 2 runs, got " .. runs)
end)

test("signal x(nil) sets nil, and a computed can't be set", function()
    local v = signal.signal(1)
    v(nil)
    assert(v() == nil, "expected nil")
    local c = signal.computed(function()
        return 1
    end)
    assert(not pcall(function()
        c(2)
    end), "expected setting a computed to fail")
end)

test("signal :computed derives from a signal or computed, and peek reads computeds", function()
    local v = signal.signal(2)
    local double = v:computed(function(n)
        return n * 2
    end)
    local plusOne = double:computed(function(n)
        return n + 1
    end)
    assert(double:peek() == 4 and double:get() == 4, "expected peek and get to read the computed")
    v(5)
    assert(double() == 10 and plusOne() == 11, "expected 10 and 11")
end)

test("signal :negate follows a signal or computed", function()
    local on = signal.signal(false)
    local off = on:negate()
    local onAgain = off:negate()
    assert(off() == true and onAgain() == false, "expected true and false")
    on(true)
    assert(off() == false and onAgain() == true, "expected false and true")
end)
