"""
Smart cleanup script for Lua MSVC Build System

This script safely removes temporary files and directories created during the build process.
It uses the configuration system to work with any Lua/LuaRocks versions and protects
important files when installations are in the project directory.
"""

import os
import shutil
import sys
from pathlib import Path

# Import configuration system
try:
    from config import (
        get_lua_dir_name, get_luarocks_dir_name, get_lua_tests_dir_name,
        LUA_VERSION, LUAROCKS_VERSION, LUAROCKS_PLATFORM
    )
except ImportError as e:
    print(f"Error importing configuration: {e}")
    print("Make sure config.py is in the same directory as this script.")
    sys.exit(1)

def safe_remove_dir(path, description):
    """Safely remove a directory with proper error handling."""
    if path.exists():
        try:
            shutil.rmtree(path)
            print(f"[REMOVED] {description}: {path}")
            return True
        except Exception as e:
            print(f"[ERROR] Failed to remove {description}: {e}")
            return False
    else:
        print(f"[SKIP] {description} not found: {path}")
        return True

def safe_remove_file(path, description):
    """Safely remove a file with proper error handling."""
    if path.exists():
        try:
            path.unlink()
            print(f"[REMOVED] {description}: {path}")
            return True
        except Exception as e:
            print(f"[ERROR] Failed to remove {description}: {e}")
            return False
    else:
        print(f"[SKIP] {description} not found: {path}")
        return True

def is_installation_in_project(install_info_file):
    """Check if Lua is installed within the project directory."""
    if not install_info_file.exists():
        return False

    try:
        script_dir = Path(__file__).parent.resolve()
        with open(install_info_file, 'r') as f:
            for line in f:
                if line.startswith('INSTALL_DIRECTORY='):
                    install_dir = Path(line.split('=', 1)[1].strip()).resolve()
                    # Check if install directory is within or same as project directory
                    try:
                        install_dir.relative_to(script_dir)
                        return True
                    except ValueError:
                        return False
        return False
    except Exception:
        return False

def clean_downloads():
    """Remove downloads directory."""
    downloads_dir = Path("downloads")
    return safe_remove_dir(downloads_dir, "Downloads directory")

def clean_extracted_sources():
    """Remove extracted source directories using configuration."""
    script_dir = Path(__file__).parent
    success = True

    # Remove Lua source directory
    lua_dir = script_dir / get_lua_dir_name()
    success &= safe_remove_dir(lua_dir, f"Lua {LUA_VERSION} source directory")

    # Remove LuaRocks directory
    luarocks_dir = script_dir / get_luarocks_dir_name()
    success &= safe_remove_dir(luarocks_dir, f"LuaRocks {LUAROCKS_VERSION} directory")

    # Remove Lua tests directory
    lua_tests_dir = script_dir / get_lua_tests_dir_name()
    success &= safe_remove_dir(lua_tests_dir, f"Lua {LUA_VERSION} tests directory")

    return success

def clean_cache_and_temp():
    """Remove cache and temporary files."""
    script_dir = Path(__file__).parent
    success = True

    # Remove Python cache directories
    pycache_dir = script_dir / "__pycache__"
    success &= safe_remove_dir(pycache_dir, "Python cache directory")

    tests_pycache_dir = script_dir / "tests" / "__pycache__"
    success &= safe_remove_dir(tests_pycache_dir, "Tests Python cache directory")

    # Remove version cache
    cache_file = script_dir / "version_cache.json"
    success &= safe_remove_file(cache_file, "Version cache file")

    return success

def get_installation_directory(install_info_file):
    """Get the installation directory from the install info file."""
    if not install_info_file.exists():
        return None

    try:
        with open(install_info_file, 'r') as f:
            for line in f:
                if line.startswith('INSTALL_DIRECTORY='):
                    return Path(line.split('=', 1)[1].strip())
        return None
    except Exception:
        return None

def clean_installation_files():
    """Remove installation-related files and directories when using --all."""
    script_dir = Path(__file__).parent
    success = True

    install_info_file = script_dir / ".lua_install_info.txt"
    prefix_file = script_dir / ".lua_prefix.txt"

    # Check if installation is in project directory
    install_in_project = is_installation_in_project(install_info_file)
    install_dir = get_installation_directory(install_info_file)

    if install_in_project and install_dir:
        print(f"[DETECTED] Lua installation in project directory: {install_dir}")

        # Remove the actual installation directory
        if install_dir.exists():
            success &= safe_remove_dir(install_dir, f"Lua installation directory")

        # Remove installation tracking files
        success &= safe_remove_file(install_info_file, "Installation info file")
        success &= safe_remove_file(prefix_file, "Prefix file")

        print("[INFO] Removed installation and tracking files from project directory.")
    else:
        # Only remove tracking files if installation is external
        success &= safe_remove_file(install_info_file, "Installation info file")
        success &= safe_remove_file(prefix_file, "Prefix file")

        if install_dir and not install_in_project:
            print(f"[INFO] External installation at {install_dir} was not removed.")
            print("       Use 'python setup.py --uninstall' to uninstall external installations.")

    return success

def main():
    import argparse

    parser = argparse.ArgumentParser(
        description="Smart cleanup script for Lua MSVC Build System",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  python clean.py                    # Clean downloads, sources, cache (safe mode)
  python clean.py --all              # Clean everything including installation files/directories
  python clean.py --downloads-only   # Only remove downloads directory
  python clean.py --cache-only       # Only remove cache and temp files

Note: This script only cleans the PROJECT DIRECTORY.
      - Standard cleanup removes temporary files, downloads, and extracted sources
      - '--all' also removes installation tracking files and the './lua' directory if installed locally
      - To uninstall external Lua installations, use: python setup.py --uninstall
        """
    )

    parser.add_argument(
        "--all",
        action="store_true",
        help="Clean everything including installation files and directories in the project root"
    )

    parser.add_argument(
        "--downloads-only",
        action="store_true",
        help="Only remove downloads directory"
    )

    parser.add_argument(
        "--cache-only",
        action="store_true",
        help="Only remove cache and temporary files"
    )

    args = parser.parse_args()

    print("Lua MSVC Build System - Smart Cleanup")
    print("=" * 40)
    print(f"Configuration: Lua {LUA_VERSION}, LuaRocks {LUAROCKS_VERSION}")
    print()

    success = True

    if args.downloads_only:
        print("Cleaning downloads only...")
        success = clean_downloads()
    elif args.cache_only:
        print("Cleaning cache and temporary files only...")
        success = clean_cache_and_temp()
    else:
        # Standard cleanup
        print("Cleaning downloaded files...")
        success &= clean_downloads()

        print("\nCleaning extracted source directories...")
        success &= clean_extracted_sources()

        print("\nCleaning cache and temporary files...")
        success &= clean_cache_and_temp()

        if args.all:
            print("\nCleaning installation files and directories...")
            success &= clean_installation_files()

    print()
    if success:
        print("[SUCCESS] Cleanup completed successfully!")
    else:
        print("[WARNING] Cleanup completed with some errors.")

    print()
    print("Directories that were checked:")
    print(f"  - downloads/")
    print(f"  - {get_lua_dir_name()}/")
    print(f"  - {get_luarocks_dir_name()}/")
    print(f"  - {get_lua_tests_dir_name()}/")
    print(f"  - __pycache__/")
    print(f"  - tests/__pycache__/")
    print(f"  - version_cache.json")

    if not args.downloads_only and not args.cache_only:
        if not args.all:
            print()
            print("Use --all to also clean installation files and directories")
            print("Use 'python setup.py --uninstall' to completely uninstall external Lua installations")

if __name__ == "__main__":
    main()
