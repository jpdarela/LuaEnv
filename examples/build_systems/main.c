#include <stdio.h>
#include <lua.h>
#include <lauxlib.h>
#include <lualib.h>

int main(void) {
    lua_State *L = luaL_newstate();      // Create new Lua state
    luaL_openlibs(L);                    // Open standard libraries

    // Run a simple Lua script
    if (luaL_dostring(L, "x = 42; print('Hello from Lua!')")) {
        fprintf(stderr, "Lua error: %s\n", lua_tostring(L, -1));
        lua_close(L);
        return 1;
    }

    // Get the value of x from Lua
    lua_getglobal(L, "x");
    if (lua_isnumber(L, -1)) {
        printf("x from Lua: %g\n", lua_tonumber(L, -1));
    } else {
        printf("x is not a number\n");
    }

    lua_close(L); // Clean up
    return 0;
}