# lua-CodeGen : <http://fperrad.github.com/lua-CodeGen/>

project ( lua-codegen NONE )
cmake_minimum_required ( VERSION 2.6 )
include ( dist.cmake )

install_lua_module ( CodeGen                    src/CodeGen.lua )
install_lua_module ( CodeGen.Graph              src/CodeGen/Graph.lua )
install_lua_module ( CodeGen.lpeg               src/CodeGen/lpeg.lua )

install_data ( CHANGES COPYRIGHT README.md )
install_test ( test/ )
