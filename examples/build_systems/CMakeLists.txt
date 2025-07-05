# CMakeLists.txt for LuaEnv Integration
#
# This file demonstrates how to integrate a C project with a Lua environment
# managed by luaenv (luaconfig) on Windows using CMake.

cmake_minimum_required(VERSION 3.10)
project(main C)

set(CMAKE_C_STANDARD 99)

# Set a string vatiable to hold the alias for the lue installation from luaenv
set(LUAENV_ALIAS "dev")

# Add your source files here
add_executable(main main.c)

# Function to get Lua configuration using luaenv
function(get_lua_config  output_var flag)
    execute_process(
        COMMAND luaconfig ${LUAENV_ALIAS} ${flag} --path-style unix
        OUTPUT_VARIABLE result
        ERROR_QUIET
        OUTPUT_STRIP_TRAILING_WHITESPACE
        RESULT_VARIABLE result_code
    )
    if(result_code EQUAL 0)
        set(${output_var} "${result}" PARENT_SCOPE)
        # Don't use return with arguments, just set a status variable
        set(LUA_CONFIG_SUCCESS TRUE PARENT_SCOPE)
    else()
        set(${output_var} "" PARENT_SCOPE)
        set(LUA_CONFIG_SUCCESS FALSE PARENT_SCOPE)
    endif()
endfunction()


if(WIN32)
    set(LUA_COFIG_SUCCESS TRUE)
    get_lua_config(LUA_INCLUDE_DIR --lua-include)
    get_lua_config(LUA_LIBRARY_PATH --liblua)
    get_lua_config(LUA_LIB_DIR --libdir)
   # Check if all paths were retrieved successfully
    if(LUA_CONFIG_SUCCESS AND LUA_INCLUDE_DIR AND LUA_LIBRARY_PATH)
        message(STATUS "Found Lua via luaenv:")
        message(STATUS "  Include dir: ${LUA_INCLUDE_DIR}")
        message(STATUS "  Library path: ${LUA_LIBRARY_PATH}")
        message(STATUS "  Library dir: ${LUA_LIB_DIR}")

        target_include_directories(main PRIVATE ${LUA_INCLUDE_DIR})

        # Find the library in the specified directory and link it
        find_library(LUA_LIBRARY_FOUND NAMES lua54 PATHS ${LUA_LIB_DIR})
        if(LUA_LIBRARY_FOUND)
            message(STATUS "  Found library: ${LUA_LIBRARY_FOUND}")
            target_link_libraries(main PRIVATE ${LUA_LIBRARY_FOUND})
        else()
            message(WARNING "Could not find lua54.lib in ${LUA_LIB_DIR}, falling back to full path.")
            target_link_libraries(main PRIVATE ${LUA_LIBRARY_PATH}) # Fallback to full path
        endif()
    else()
        message(WARNING "luaconfig failed. Could not get all required Lua paths.")
    endif()
else()
    # For non-Windows systems, use traditional find_package
    find_package(Lua REQUIRED)
    target_include_directories(main PRIVATE ${LUA_INCLUDE_DIR})
    target_link_libraries(main ${LUA_LIBRARIES})
endif()

# Set compiler-specific options

if(MSVC)
    set(CMAKE_EXE_LINKER_FLAGS "${CMAKE_EXE_LINKER_FLAGS}")
    target_compile_options(main PRIVATE /W4)
    target_compile_definitions(main PRIVATE _CRT_SECURE_NO_WARNINGS)
elseif(CMAKE_C_COMPILER_ID STREQUAL "GNU")
    target_compile_options(main PRIVATE -Wall -Wextra -pedantic)
endif()
