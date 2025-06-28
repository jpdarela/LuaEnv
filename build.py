"""
1 - Enter lua directory and run the build script to compile lua
2 - Enter luarocks directory and run the setup-luarocks.bat script

"""

import os
import shutil
import subprocess
import argparse
from pathlib import Path


BUILD_DLL = 0
INSTALL_DIR = Path("./lua").resolve()

def run_build_scripts(build_dll=False, install_dir=INSTALL_DIR):
    """Run the build scripts for Lua and LuaRocks."""
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

    # Change to Lua directory and run the build script
    os.chdir(lua_dir)
    if build_dll:
        subprocess.run(["build-dll.bat"], check=True, shell=True)
        os.system(f"python install_lua_dll.py {install_dir}")
    else:
        subprocess.run(["build-static.bat", install_dir], check=True, shell=True)

    # Change to Luarocks directory and run the setup script

    ## TODO move luarocks to the same directory as lua
    ## Move luarocks_dir to the installation directory
    luarocks_dest = Path(install_dir) / 'luarocks'
    if not luarocks_dest.exists():
        luarocks_dest.mkdir(parents=True, exist_ok=True)
    shutil.copytree(luarocks_dir, luarocks_dest, dirs_exist_ok=True)

    os.chdir(luarocks_dest)
    subprocess.run(["setup-luarocks.bat", install_dir], check=True, shell=True)

if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description="Build Lua and configure LuaRocks",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  python build.py                                    # Static build to ./inst/lua
  python build.py --dll                             # DLL build to ./inst/lua
  python build.py --prefix C:\\lua                   # Static build to C:\\lua
  python build.py --dll --prefix C:\\Development\\Lua # DLL build to C:\\Development\\Lua
        """
    )

    parser.add_argument(
        "--dll",
        action="store_true",
        help="Build Lua as a DLL instead of static library"
    )

    parser.add_argument(
        "--prefix",
        default=str(INSTALL_DIR),
        help="Installation directory for Lua (default: ./lua)"
    )

    args = parser.parse_args()

    print(f"Building Lua with the following options:")
    print(f"  Build type: {'DLL' if args.dll else 'Static'}")
    print(f"  Install directory: {args.prefix}")
    print()

    run_build_scripts(build_dll=args.dll, install_dir=args.prefix)
