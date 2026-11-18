const { lua, lauxlib, lualib, to_luastring } = require('fengari');
const L = lauxlib.luaL_newstate(); lualib.luaL_openlibs(L);
lua.lua_pushstring(L, to_luastring(process.argv[3])); lua.lua_setglobal(L, to_luastring('ROOT'));
const st = lauxlib.luaL_dofile(L, to_luastring(process.argv[2]));
if (st !== 0) { console.error(lua.lua_tojsstring(L, -1)); process.exit(1); }
