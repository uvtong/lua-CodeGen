
local lpeg = require 'lpeg'
local assert = assert
local type = type

local m = {
    arg = lpeg.Carg,
    backref = lpeg.Cb,
    capture = lpeg.C,
    constant = lpeg.Cc,
    fold = lpeg.Cf,
    group = lpeg.Cg,
    matchtime = lpeg.Cmt,
    position = lpeg.Cp,
    range = lpeg.R,
    subst = lpeg.Cs,
    set = lpeg.S,
    table = lpeg.Ct,
    variable = lpeg.V,
}
_ENV = nil

function m.any (n)
    n = n or 1
    assert(type(n) == 'number' and n > 0, "number expected")
    return lpeg.P(n)
end

function m.choice (p, ...)
    assert(lpeg.type(p) == 'pattern', "pattern expected")
    local t = {...}
    for i=1, #t do
        p = p + t[i]
    end
    return p
end

function m.empty ()
    return lpeg.P(0)
end

function m.except (p, ...)
    assert(lpeg.type(p) == 'pattern', "pattern expected")
    local t = {...}
    for i=1, #t do
        p = p - t[i]
    end
    return p
end

function m.not_followed_by (p)
    assert(lpeg.type(p) == 'pattern', "pattern expected")
    return -p
end

function m.eos ()
    return lpeg.P(-1)
end

function m.fail ()
    return lpeg.P(false)
end

function m.grammar (t)
    assert(type(t) == 'table', "table expected")
    return lpeg.P(t)
end

function m.literal (s)
    assert(type(s) == 'string', "string expected")
    return lpeg.P(s)
end

function m.followed_by (p)
    assert(lpeg.type(p) == 'pattern', "pattern expected")
    return #p
end

function m.many (p)
    assert(lpeg.type(p) == 'pattern', "pattern expected")
    return p^0
end

function m.optional (p)
    assert(lpeg.type(p) == 'pattern', "pattern expected")
    return p^-1
end

function m.sequence (p, ...)
    assert(lpeg.type(p) == 'pattern', "pattern expected")
    local t = {...}
    for i=1, #t do
        p = p * t[i]
    end
    return p
end

function m.some (p)
    assert(lpeg.type(p) == 'pattern', "pattern expected")
    return p^1
end

function m.replace (p, s)
    assert(lpeg.type(p) == 'pattern', "pattern expected")
    return p / s
end

function m.succeed ()
    return lpeg.P(true)
end

return m
