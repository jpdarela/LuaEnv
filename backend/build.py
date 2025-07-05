# This is free and unencumbered software released into the public domain.
# For more details, see the LICENSE file in the project root.

"""
Build script for Lua MSVC Build System

This script compiles Lua and sets up LuaRocks using the configuration system.
It now works with the extracted folder structure and any Lua/LuaRocks versions
specified in build_config.txt.

1 - Enter extracted lua directory and run the build script to compile lua
2 - Enter extracted luarocks directory and run the setup-luarocks.bat script
"""

import os
import shutil
import subprocess
import argparse
import sys
from pathlib import Path

# Ensure we can import from the current directory when run from CLI
if __name__ == "__main__" or "backend" not in sys.path:
    current_dir = os.path.dirname(os.path.abspath(__file__))
    if current_dir not in sys.path:
        sys.path.insert(0, current_dir)

# Import configuration system and utilities with dual-context support
try:
    from config import (
        get_lua_dir_name, get_luarocks_dir_name,
        LUA_VERSION, LUAROCKS_VERSION, LUAROCKS_PLATFORM
    )
    from utils import ensure_extracted_folder
except ImportError:
    try:
        from .config import (
            get_lua_dir_name, get_luarocks_dir_name,
            LUA_VERSION, LUAROCKS_VERSION, LUAROCKS_PLATFORM
        )
        from .utils import ensure_extracted_folder
    except ImportError as e:
        print(f"Error importing configuration: {e}")
        print("Make sure config.py and utils.py are in the same directory as this script.")
        sys.exit(1)

INSTALL_DIR = Path("./lua").resolve()

def run_build_scripts(build_dll=False, build_debug=False, install_dir=INSTALL_DIR):
    """Run the build scripts for Lua and LuaRocks from the extracted folder."""
    current_dir = os.path.dirname(os.path.abspath(__file__))

    # Ensure extracted folder exists
    extracted_folder = ensure_extracted_folder(current_dir)

    # Use configuration system to get correct directory names
    lua_dir_name = get_lua_dir_name()
    luarocks_dir_name = get_luarocks_dir_name()

    # Build paths using extracted folder
    lua_dir = extracted_folder / lua_dir_name / "src"
    luarocks_dir = extracted_folder / luarocks_dir_name

    print(f"Building with configuration:")
    print(f"  Lua {LUA_VERSION} (directory: {lua_dir_name})")
    print(f"  LuaRocks {LUAROCKS_VERSION} {LUAROCKS_PLATFORM} (directory: {luarocks_dir_name})")
    print(f"  Extracted folder: {extracted_folder}")

    # Determine build type
    if build_dll and build_debug:
        build_type = "DLL Debug"
    elif build_dll:
        build_type = "DLL Release"
    elif build_debug:
        build_type = "Static Debug"
    else:
        build_type = "Static Release"

    print(f"  Build type: {build_type}")
    print(f"  Install directory: {install_dir}")
    print()

    # Convert install_dir to absolute path to avoid issues when changing directories
    install_dir = os.path.abspath(install_dir)

    # Ensure the directories exist
    if not lua_dir.exists():
        print(f"[ERROR] Lua directory does not exist: {lua_dir}")
        print(f"        Expected: extracted/{lua_dir_name}/src")
        print("        Make sure you have:")
        print("        1. Run 'python download_lua_luarocks.py' to download sources")
        print("        2. Run 'python setup_build.py' to copy build scripts")
        return False
    if not luarocks_dir.exists():
        print(f"[ERROR] LuaRocks directory does not exist: {luarocks_dir}")
        print(f"        Expected: extracted/{luarocks_dir_name}")
        print("        Make sure you have:")
        print("        1. Run 'python download_lua_luarocks.py' to download sources")
        print("        2. Run 'python setup_build.py' to copy build scripts")
        return False

    print("Starting Lua build...")
    # Change to Lua directory and run the build script
    os.chdir(str(lua_dir))
    try:
        if build_dll and build_debug:
            subprocess.run(["build-dll-debug.bat", install_dir], check=True, shell=True)
        elif build_dll:
            subprocess.run(["build-dll.bat"], check=True, shell=True)
            subprocess.run([sys.executable, "install_lua_dll.py", install_dir], check=True)
        elif build_debug:
            subprocess.run(["build-static-debug.bat", install_dir], check=True, shell=True)
        else:
            subprocess.run(["build-static.bat", install_dir], check=True, shell=True)
        print("[OK] Lua build completed successfully.")
    except subprocess.CalledProcessError as e:
        print(f"[ERROR] Lua build failed: {e}")
        return False

    print("\nSetting up LuaRocks...")
    # Change to Luarocks directory and run the setup script

    ## TODO move luarocks to the same directory as lua
    ## Move luarocks_dir to the installation directory
    luarocks_dest = Path(install_dir) / 'luarocks'
    if not luarocks_dest.exists():
        luarocks_dest.mkdir(parents=True, exist_ok=True)

    try:
        shutil.copytree(str(luarocks_dir), luarocks_dest, dirs_exist_ok=True)

        os.chdir(luarocks_dest)
        subprocess.run(["setup-luarocks.bat", install_dir], check=True, shell=True)
        print("[OK] LuaRocks setup completed successfully.")
        return True
    except Exception as e:
        print(f"[ERROR] LuaRocks setup failed: {e}")
        return False

if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description="Build Lua and configure LuaRocks using the configuration system",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=f"""
Current Configuration (from build_config.txt):
  Lua: {LUA_VERSION}
  LuaRocks: {LUAROCKS_VERSION} ({LUAROCKS_PLATFORM})

Examples:
  python build.py                                    # Static release build to ./lua
  python build.py --dll                             # DLL release build to ./lua
  python build.py --debug                           # Static debug build to ./lua
  python build.py --dll --debug                     # DLL debug build to ./lua
  python build.py --prefix C:\\lua                   # Static release build to C:\\lua
  python build.py --dll --debug --prefix C:\\Dev\\Lua # DLL debug build to C:\\Dev\\Lua

Build Types:
  Static Release:  Optimized static library build (default)
  DLL Release:     Optimized DLL build
  Static Debug:    Unoptimized static build with debug symbols
  DLL Debug:       Unoptimized DLL build with debug symbols

Prerequisites:
  1. Run 'python download_lua_luarocks.py' to download sources
  2. Run 'python setup_build.py' to copy build scripts
  3. (Optional) Edit build_config.txt to change versions

To use different versions, edit build_config.txt and re-run the prerequisite steps.
        """
    )

    parser.add_argument(
        "--dll",
        action="store_true",
        help="Build Lua as a DLL instead of static library"
    )

    parser.add_argument(
        "--debug",
        action="store_true",
        help="Build Lua with debug symbols and unoptimized code"
    )

    parser.add_argument(
        "--prefix",
        default=str(INSTALL_DIR),
        help="Installation directory for Lua (default: ./lua)"
    )

    args = parser.parse_args()

    print(f"Lua MSVC Build System")
    print("=" * 40)
    print(f"Configuration: Lua {LUA_VERSION}, LuaRocks {LUAROCKS_VERSION}")

    # Determine build type for display
    if args.dll and args.debug:
        build_type = "DLL Debug"
    elif args.dll:
        build_type = "DLL Release"
    elif args.debug:
        build_type = "Static Debug"
    else:
        build_type = "Static Release"

    print(f"Build type: {build_type}")
    print(f"Install directory: {args.prefix}")
    print()

    success = run_build_scripts(build_dll=args.dll, build_debug=args.debug, install_dir=args.prefix)

    if success:
        print("\n[SUCCESS] Build completed successfully!")
        print(f"Lua and LuaRocks are now installed in: {args.prefix}")
    else:
        print("\n[ERROR] Build failed. Check the error messages above.")
        sys.exit(1)
