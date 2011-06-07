#!/usr/bin/env lua

require 'Test.More'

plan(5)

require_ok 'CodeGen.Graph'

local m = require 'CodeGen.Graph'
type_ok( m, 'table' )
is( m._NAME, 'CodeGen.Graph', "_NAME" )

type_ok( m.template, 'table', "CodeGen.Graph.template" )

is( m.to_dot(m.template), [[
digraph {
    node [ shape = none ];

    _node;
    TOP;
    _edge;

    TOP -> _node;
    TOP -> _edge;
}
]], "CodeGen.Graph.to_dot" )

