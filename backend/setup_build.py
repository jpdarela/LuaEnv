# This is free and unencumbered software released into the public domain.
# For more details, see the LICENSE file in the project root.

"""
Move build scripts to the lua and luarocks directories in the extracted folder.
This script now uses the configuration system and extracted folder structure
to work with any Lua/LuaRocks versions in an isolated build environment.

"""

import os
import shutil
import sys
from pathlib import Path

# Add current directory to Python path for local imports
current_dir = Path(__file__).parent
sys.path.insert(0, str(current_dir))

# Import configuration system and utilities with dual-context support
try:
    from .config import (
        get_lua_dir_name, get_luarocks_dir_name,
        LUA_VERSION, LUAROCKS_VERSION, LUAROCKS_PLATFORM
    )
    from .utils import ensure_extracted_folder
except ImportError:
    from config import (
        get_lua_dir_name, get_luarocks_dir_name,
        LUA_VERSION, LUAROCKS_VERSION, LUAROCKS_PLATFORM
    )
    from utils import ensure_extracted_folder

BUILD_DLL = 0
BUILD_DEBUG = 0

def copy_build_scripts():
    """Copy build scripts to the lua and luarocks directories in the extracted folder."""
    current_dir = os.path.dirname(os.path.abspath(__file__))
    build_scripts_dir = os.path.join(current_dir, "build_scripts")

    # Ensure extracted folder exists
    extracted_folder = ensure_extracted_folder(current_dir)

    # Use configuration to get correct directory names
    lua_dir_name = get_lua_dir_name()
    luarocks_dir_name = get_luarocks_dir_name()

    # Build paths using extracted folder
    lua_dir = extracted_folder / lua_dir_name / "src"
    luarocks_dir = extracted_folder / luarocks_dir_name

    print(f"Setting up build scripts for:")
    print(f"  Lua {LUA_VERSION} (directory: {lua_dir_name})")
    print(f"  LuaRocks {LUAROCKS_VERSION} {LUAROCKS_PLATFORM} (directory: {luarocks_dir_name})")
    print(f"  Extracted folder: {extracted_folder}")

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
    if not lua_dir.exists():
        print(f"[ERROR] Lua source directory does not exist: {lua_dir}")
        print(f"        Expected directory: extracted/{lua_dir_name}/src")
        print("        Make sure you have run the download script first:")
        print("        python download_lua_luarocks.py")
        return False

    if not luarocks_dir.exists():
        print(f"[ERROR] LuaRocks directory does not exist: {luarocks_dir}")
        print(f"        Expected directory: extracted/{luarocks_dir_name}")
        print("        Make sure you have run the download script first:")
        print("        python download_lua_luarocks.py")
        return False

    # Copy build scripts
    try:
        if BUILD_DLL and BUILD_DEBUG:
            print("Copying DLL debug build scripts...")
            shutil.copy(os.path.join(build_scripts_dir, "build-dll-debug.bat"), str(lua_dir))
            shutil.copy(os.path.join(build_scripts_dir, "install_lua_dll.py"), str(lua_dir))
            print(f"  build-dll-debug.bat -> {lua_dir}")
            print(f"  install_lua_dll.py -> {lua_dir}")
        elif BUILD_DLL:
            print("Copying DLL build scripts...")
            shutil.copy(os.path.join(build_scripts_dir, "build-dll.bat"), str(lua_dir))
            shutil.copy(os.path.join(build_scripts_dir, "install_lua_dll.py"), str(lua_dir))
            print(f"  build-dll.bat -> {lua_dir}")
            print(f"  install_lua_dll.py -> {lua_dir}")
        elif BUILD_DEBUG:
            print("Copying static debug build scripts...")
            shutil.copy(os.path.join(build_scripts_dir, "build-static-debug.bat"), str(lua_dir))
            print(f"  build-static-debug.bat -> {lua_dir}")
        else:
            print("Copying static build scripts...")
            shutil.copy(os.path.join(build_scripts_dir, "build-static.bat"), str(lua_dir))
            print(f"  build-static.bat -> {lua_dir}")

        print("Copying LuaRocks setup script...")
        shutil.copy(os.path.join(build_scripts_dir, "setup-luarocks.bat"), str(luarocks_dir))
        print(f"  setup-luarocks.bat -> {luarocks_dir}")

        print("[OK] Build scripts copied successfully.")
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
                print("Expected directories (in extracted folder):")
                print(f"  extracted/{get_lua_dir_name()}/src")
                print(f"  extracted/{get_luarocks_dir_name()}")
                print()
                print("Make sure to run 'python download_lua_luarocks.py' first!")
                sys.exit(0)

    # Run the setup
    success = copy_build_scripts()
    if not success:
        sys.exit(1)
