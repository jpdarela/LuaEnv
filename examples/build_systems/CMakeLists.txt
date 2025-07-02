# CMakeLists.txt for LuaEnv Integration
#
# This file demonstrates how to integrate a C project with a Lua environment
# managed by luaenv on Windows using CMake.
#
# Key integration points:
# 1. `execute_process`: This command is used to run `luaenv.cmd pkg-config`
#    to retrieve the necessary compiler and linker flags.
# 2. `luaenv.cmd`: On Windows, the command is `luaenv.cmd`. This script must
#    be in the system's PATH for CMake to find it.
# 3. `--path-style windows`: This argument ensures that the paths returned by
#    pkg-config use double backslashes (`\\`).
# 4. `get_filename_component` & `find_library`: Instead of hardcoding the full
#    path to the .lib file, the script extracts the library directory and uses
#    CMake's standard `find_library` to locate `lua54.lib`. This is a more
#    robust and portable approach within the CMake ecosystem.

cmake_minimum_required(VERSION 3.10)
project(main C)

set(CMAKE_C_STANDARD 99)

# Add your source files here
add_executable(main main.c)

# LuaEnv pkg-config integration
if(WIN32)
    # Get Lua include directory from luaenv, requesting Windows-style paths
    execute_process(
        COMMAND luaenv.cmd pkg-config dev --lua-include --path-style windows
        OUTPUT_VARIABLE LUA_INCLUDE_DIR
        ERROR_VARIABLE LUA_INCLUDE_ERROR
        OUTPUT_STRIP_TRAILING_WHITESPACE
        RESULT_VARIABLE LUA_INCLUDE_RESULT
    )

    # Get Lua library path from luaenv, requesting Windows-style paths
    execute_process(
        COMMAND luaenv.cmd pkg-config dev --liblua --path-style windows
        OUTPUT_VARIABLE LUA_LIBRARY_PATH
        ERROR_VARIABLE LUA_LIB_ERROR
        OUTPUT_STRIP_TRAILING_WHITESPACE
        RESULT_VARIABLE LUA_LIB_RESULT
    )

    if(LUA_INCLUDE_RESULT EQUAL 0 AND LUA_LIB_RESULT EQUAL 0)
        message(STATUS "Found Lua via luaenv:")
        message(STATUS "  Include dir: ${LUA_INCLUDE_DIR}")
        message(STATUS "  Library path: ${LUA_LIBRARY_PATH}")

        # Extract the directory from the full library path
        get_filename_component(LUA_LIB_DIR ${LUA_LIBRARY_PATH} DIRECTORY)
        message(STATUS "  Library dir: ${LUA_LIB_DIR}")

        # Add the include directory
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
        message(WARNING "luaenv pkg-config failed. Debug info:")
        message(WARNING "  Include Result: ${LUA_INCLUDE_RESULT}")
        message(WARNING "  Include Output: ${LUA_INCLUDE_DIR}")
        message(WARNING "  Include Error: ${LUA_INCLUDE_ERROR}")
        message(WARNING "  Lib Result: ${LUA_LIB_RESULT}")
        message(WARNING "  Lib Output: ${LUA_LIBRARY_PATH}")
        message(WARNING "  Lib Error: ${LUA_LIB_ERROR}")
    endif()
else()
    # For non-Windows systems, use traditional find_package
    find_package(Lua REQUIRED)
    target_include_directories(main PRIVATE ${LUA_INCLUDE_DIR})
    target_link_libraries(main ${LUA_LIBRARIES})
endif()

# Set compiler-specific warnings
if(MSVC)
    target_compile_options(main PRIVATE /W4)
    target_compile_definitions(main PRIVATE _CRT_SECURE_NO_WARNINGS)
elseif(CMAKE_C_COMPILER_ID STREQUAL "GNU")
    target_compile_options(main PRIVATE -Wall -Wextra -pedantic)
endif()
