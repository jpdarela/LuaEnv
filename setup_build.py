"""
Move build scripts to the lua directory and the setup-luarocks.bat to the luarocks directory.

"""

import os
import shutil
import sys

BUILD_DLL = 0

def copy_build_scripts():
    """Copy build scripts to the lua and luarocks directories."""
    current_dir = os.path.dirname(os.path.abspath(__file__))
    lua_dir = os.path.join(current_dir, "lua-5.4.8/src")
    luarocks_dir = os.path.join(current_dir, "luarocks-3.12.2-windows-64")

    # Ensure the directories exist
    if not os.path.exists(lua_dir):
        print(f"Lua directory does not exist: {lua_dir}")
        return
    if not os.path.exists(luarocks_dir):
        print(f"Luarocks directory does not exist: {luarocks_dir}")
        return

    # Copy build scripts
    if BUILD_DLL:
        shutil.copy(os.path.join(current_dir, "build-dll.bat"), lua_dir)
        shutil.copy(os.path.join(current_dir, "install_lua_dll.py"), lua_dir)
    else:
        shutil.copy(os.path.join(current_dir, "build-static.bat"), lua_dir)
    shutil.copy(os.path.join(current_dir, "setup-luarocks.bat"), luarocks_dir)
    print("Build scripts copied successfully.")

if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] == "--dll":
        BUILD_DLL = 1
    copy_build_scripts()