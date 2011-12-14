
--
-- lua-CodeGen : <http://fperrad.github.com/lua-CodeGen>
--

local setmetatable = setmetatable
local tonumber = tonumber
local tostring = tostring
local type = type
local char = require 'string'.char
local tconcat = require 'table'.concat
local _G = _G
local pc = require 'pc'
local any = pc.any
local capture = pc.capture
local choice = pc.choice
local complement = pc.complement
local eof = pc.eof
local except = pc.except
local grammar = pc.grammar
local literal = pc.literal
local many = pc.many
local optional = pc.optional
local position = pc.position
local range = pc.range
local replace = pc.replace
local sequence = pc.sequence
local set = pc.set
local some = pc.some
local subst = pc.subst
local variable = pc.variable

_ENV = nil
local m = {}

local function gsub (s, patt, repl)
    local p = subst(many(choice(replace(patt, repl), any())))
    return p:match(s)
end

local function split (s, sep, func)
    local elem = replace(capture(many(except(any(), sep))), func)
    local p = sequence(elem, many(sequence(sep, elem)))
    p:match(s)
end

local function render (val, sep, formatter)
    formatter = formatter or tostring
    if val == nil then
        return ''
    end
    if type(val) == 'table' then
        local t = {}
        for i = 1, #val do
            t[i] = formatter(val[i])
        end
        return tconcat(t, sep)
    else
        return formatter(val)
    end
end

local special = {
    ['a']  = "\a",
    ['b']  = "\b",
    ['f']  = "\f",
    ['n']  = "\n",
    ['r']  = "\r",
    ['t']  = "\t",
    ['v']  = "\v",
    ['\\'] = '\\',
    ['"']  = '"',
    ["'"]  = "'",
}

local digit = range'09'
local escape_digit = sequence(literal[[\]], capture(sequence(digit, optional(digit), optional(digit))))
local escape_special = sequence(literal[[\]], capture(set[[abfnrtv\"']]))

local function unescape(str)
    str = gsub(str, escape_digit, function (s)
                                      return char(tonumber(s) % 256)
                                  end)
    return gsub(str, escape_special, special)
end

local dot = literal'.'
local space = set" \t"
local newline = literal"\n"
local newline_anywhere = grammar{ choice(newline, sequence(any(), variable(1))) }
local only_space = sequence(many(space), eof())
local newline_end = sequence(newline, eof())
local indent_needed = sequence(newline, complement(newline))

local vname_capture = sequence(literal'${', capture(sequence(range('AZ', 'az', '__'), many(range('09', 'AZ', 'az', '__', '..')))), position())
local separator_simple_quote_capture = sequence(literal"'", capture(many(except(any(), literal"'"))), literal"'")
local separator_double_quote_capture = sequence(literal'"', capture(many(except(any(), literal'"'))), literal'"')
local separator_capture = sequence(literal';', some(space), literal'separator', many(space), literal'=', many(space),
    choice(separator_simple_quote_capture, separator_double_quote_capture), many(space), position())
local identifier_capture = capture(sequence(range('AZ', 'az', '__'), many(range('09', 'AZ', 'az', '__'))))
local format_capture = sequence(literal';', some(space), literal'format', many(space), literal'=', many(space),
    identifier_capture, many(space), position())
local data_end = literal'}'
local include_end = literal'()}'
local if_capture = sequence(literal'?', identifier_capture, literal'()}')
local if_else_capture = sequence(literal'?', identifier_capture, literal'()!', identifier_capture, literal'()}')
local map_capture = sequence(literal'/', identifier_capture, literal'()', position())
local map_end = literal'}'

local subst = sequence(literal'$', grammar{ sequence(literal'{', many(choice(except(any(), set'{}'), variable(1))), literal'}') })
local indent_capture = sequence(capture(many(space)), subst, eof())

local new
local function eval (self, name)
    local cyclic = {}
    local msg = {}

    local function interpolate (self, template, tname)
        if type(template) ~= 'string' then
            return nil
        end
        local lineno = 1

        local function add_message (...)
            msg[#msg+1] = tname .. ':' .. lineno .. ': ' .. tconcat{...}
        end  -- add_message

        local function get_value (vname)
            local t = self
            split(vname, dot, function (w)
                if type(t) == 'table' then
                    t = t[w]
                else
                    add_message(vname, " is invalid")
                    t = nil
                end
            end)
            return t
        end  -- get_value

        local function interpolate_line (line)
            local function get_repl (capt)
                local function apply (self, tmpl)
                    if cyclic[tmpl] then
                        add_message("cyclic call of ", tmpl)
                        return capt
                    end
                    cyclic[tmpl] = true
                    local result = interpolate(self, self[tmpl], tmpl)
                    cyclic[tmpl] = nil
                    if result == nil then
                        add_message(tmpl, " is not a template")
                        return capt
                    end
                    return result
                end  -- apply

                local capt1, pos = vname_capture:match(capt, 1)
                if not capt1 then
                    add_message(capt, " does not match")
                    return capt
                end
                local sep, pos_sep = separator_capture:match(capt, pos)
                if sep then
                    sep = unescape(sep)
                end
                local fmt, pos_fmt = format_capture:match(capt, pos_sep or pos)
                if data_end:match(capt, pos_fmt or pos_sep or pos) then
                    if fmt then
                        local formatter = self[fmt]
                        if type(formatter) ~= 'function' then
                            add_message(fmt, " is not a formatter")
                            return capt
                        end
                        return render(get_value(capt1), sep, formatter)
                    else
                        return render(get_value(capt1), sep)
                    end
                end
                if include_end:match(capt, pos) then
                    return apply(self, capt1)
                end
                local capt2 = if_capture:match(capt, pos)
                if capt2 then
                    if get_value(capt1) then
                        return apply(self, capt2)
                    else
                        return ''
                    end
                end
                local capt2, capt3 = if_else_capture:match(capt, pos)
                if capt2 and capt3 then
                    if get_value(capt1) then
                        return apply(self, capt2)
                    else
                        return apply(self, capt3)
                    end
                end
                local capt2, pos = map_capture:match(capt, pos)
                if capt2 then
                    local sep, pos_sep = separator_capture:match(capt, pos)
                    if sep then
                        sep = unescape(sep)
                    end
                    if map_end:match(capt, pos_sep or pos) then
                        local array = get_value(capt1)
                        if array == nil then
                            return ''
                        end
                        if type(array) ~= 'table' then
                            add_message(capt1, " is not a table")
                            return capt
                        end
                        local results = {}
                        for i = 1, #array do
                            local item = array[i]
                            if type(item) ~= 'table' then
                                item = { it = item }
                            end
                            local result = apply(new(item, self), capt2)
                            results[#results+1] = result
                            if result == capt then
                                break
                            end
                        end
                        return tconcat(results, sep)
                    end
                end
                add_message(capt, " does not match")
                return capt
            end  -- get_repl

            local indent = indent_capture:match(line)
            local result = gsub(line, subst, get_repl)
            if indent then
                result = gsub(result, newline_end, '')
                if indent ~= '' then
                    result = gsub(result, indent_needed, "\n" .. indent)
                end
            end
            return result
        end -- interpolate_line

        if newline_anywhere:match(template) then
            local results = {}
            split(template, newline, function (line)
                local result = interpolate_line(line)
                if result == line or not only_space:match(result) then
                    results[#results+1] = result
                end
                lineno = lineno + 1
            end)
            return tconcat(results, "\n")
        else
            return interpolate_line(template)
        end
    end  -- interpolate

    local val = self[name]
    if type(val) == 'string' then
        return interpolate(self, val, name),
               (#msg > 0 and tconcat(msg, "\n")) or nil
    else
        return render(val)
    end
end

function new (env, ...)
    local obj = { env or {}, ... }
    setmetatable(obj, {
        __tostring = function () return m._NAME end,
        __call  = function (...) return eval(...) end,
        __index = function (t, k)
                      for i = 1, #t do
                          local v = t[i][k]
                          if v ~= nil then
                              return v
                          end
                      end
                  end,
    })
    return obj
end
m.new = new

setmetatable(m, {
    __call = function (func, ...) return new(...) end
})
_G.CodeGen = _G.CodeGen or {}
_G.CodeGen.lpeg = m

_G.package.loaded['CodeGen'] = m

m._NAME = 'CodeGen'
m._VERSION = "0.2.3"
m._DESCRIPTION = "lua-CodeGen : a template engine"
m._COPYRIGHT = "Copyright (c) 2010-2011 Francois Perrad"
return m
--
-- This library is licensed under the terms of the MIT/X11 license,
-- like Lua itself.
--
