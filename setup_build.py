"""
Move build scripts to the lua directory and the setup-luarocks.bat to the luarocks directory.
This script now uses the configuration system to work with any Lua/LuaRocks versions.

"""

import os
import shutil
import sys

# Import configuration system
try:
    from config import (
        get_lua_dir_name, get_luarocks_dir_name,
        LUA_VERSION, LUAROCKS_VERSION, LUAROCKS_PLATFORM
    )
except ImportError as e:
    print(f"Error importing configuration: {e}")
    print("Make sure config.py is in the same directory as this script.")
    sys.exit(1)

BUILD_DLL = 0
BUILD_DEBUG = 0

def copy_build_scripts():
    """Copy build scripts to the lua and luarocks directories."""
    current_dir = os.path.dirname(os.path.abspath(__file__))
    build_scripts_dir = os.path.join(current_dir, "build_scripts")

    # Use configuration to get correct directory names
    lua_dir_name = get_lua_dir_name()
    luarocks_dir_name = get_luarocks_dir_name()

    lua_dir = os.path.join(current_dir, lua_dir_name, "src")
    luarocks_dir = os.path.join(current_dir, luarocks_dir_name)

    print(f"Setting up build scripts for:")
    print(f"  Lua {LUA_VERSION} (directory: {lua_dir_name})")
    print(f"  LuaRocks {LUAROCKS_VERSION} {LUAROCKS_PLATFORM} (directory: {luarocks_dir_name})")

    # Show selected build type
    if BUILD_DLL and BUILD_DEBUG:
        build_type = "DLL Debug"
    elif BUILD_DLL:
        build_type = "DLL Release"
    elif BUILD_DEBUG:
        build_type = "Static Debug"
    else:
        build_type = "Static Release"
    print(f"  Build type: {build_type}")
    print()

    # Ensure the build scripts directory exists
    if not os.path.exists(build_scripts_dir):
        print(f"[ERROR] Build scripts directory does not exist: {build_scripts_dir}")
        print("        Make sure the build_scripts folder exists in the project root.")
        return False

    # Ensure the target directories exist
    if not os.path.exists(lua_dir):
        print(f"[ERROR] Lua source directory does not exist: {lua_dir}")
        print(f"        Expected directory: {lua_dir_name}")
        print("        Make sure you have run the download script first:")
        print("        python download_lua_luarocks.py")
        return False

    if not os.path.exists(luarocks_dir):
        print(f"[ERROR] LuaRocks directory does not exist: {luarocks_dir}")
        print(f"        Expected directory: {luarocks_dir_name}")
        print("        Make sure you have run the download script first:")
        print("        python download_lua_luarocks.py")
        return False

    # Copy build scripts
    try:
        if BUILD_DLL and BUILD_DEBUG:
            print("Copying DLL debug build scripts...")
            shutil.copy(os.path.join(build_scripts_dir, "build-dll-debug.bat"), lua_dir)
            shutil.copy(os.path.join(build_scripts_dir, "install_lua_dll.py"), lua_dir)
            print(f"  build-dll-debug.bat -> {lua_dir}")
            print(f"  install_lua_dll.py -> {lua_dir}")
        elif BUILD_DLL:
            print("Copying DLL build scripts...")
            shutil.copy(os.path.join(build_scripts_dir, "build-dll.bat"), lua_dir)
            shutil.copy(os.path.join(build_scripts_dir, "install_lua_dll.py"), lua_dir)
            print(f"  build-dll.bat -> {lua_dir}")
            print(f"  install_lua_dll.py -> {lua_dir}")
        elif BUILD_DEBUG:
            print("Copying static debug build scripts...")
            shutil.copy(os.path.join(build_scripts_dir, "build-static-debug.bat"), lua_dir)
            print(f"  build-static-debug.bat -> {lua_dir}")
        else:
            print("Copying static build scripts...")
            shutil.copy(os.path.join(build_scripts_dir, "build-static.bat"), lua_dir)
            print(f"  build-static.bat -> {lua_dir}")

        print("Copying LuaRocks setup script...")
        shutil.copy(os.path.join(build_scripts_dir, "setup-luarocks.bat"), luarocks_dir)
        print(f"  setup-luarocks.bat -> {luarocks_dir}")

        print("Build scripts copied successfully.")
        return True

    except Exception as e:
        print(f"[ERROR] Failed to copy build scripts: {e}")
        return False

if __name__ == "__main__":
    # Parse command line arguments
    if len(sys.argv) > 1:
        for arg in sys.argv[1:]:
            if arg == "--dll":
                BUILD_DLL = 1
            elif arg == "--debug":
                BUILD_DEBUG = 1
            elif arg in ['--help', '-h']:
                print("Setup Build Scripts")
                print("Usage:")
                print("  python setup_build.py                    # Setup for static release build")
                print("  python setup_build.py --dll              # Setup for DLL release build")
                print("  python setup_build.py --debug            # Setup for static debug build")
                print("  python setup_build.py --dll --debug      # Setup for DLL debug build")
                print("  python setup_build.py --help             # Show this help")
                print()
                print("Build Types:")
                print("  Static Release:  Optimized static library build (default)")
                print("  DLL Release:     Optimized DLL build")
                print("  Static Debug:    Unoptimized static build with debug symbols")
                print("  DLL Debug:       Unoptimized DLL build with debug symbols")
                print()
                print("This script copies build scripts to the appropriate directories")
                print("based on the versions configured in build_config.txt")
                print()
                print(f"Current configuration:")
                print(f"  Lua: {LUA_VERSION}")
                print(f"  LuaRocks: {LUAROCKS_VERSION} ({LUAROCKS_PLATFORM})")
                print()
                print("Expected directories:")
                print(f"  {get_lua_dir_name()}/src")
                print(f"  {get_luarocks_dir_name()}")
                print()
                print("Make sure to run 'python download_lua_luarocks.py' first!")
                sys.exit(0)

    # Run the setup
    success = copy_build_scripts()
    if not success:
        sys.exit(1)
