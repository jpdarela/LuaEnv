"""
Download and extracts Lua source code and LuaRocks package manager for windows.

"""

import urllib.request
import shutil
from pathlib import Path
import sys
import os

# Import configuration
try:
    from config import (
        get_lua_url, get_lua_tests_url, get_luarocks_url,
        get_lua_dir_name, get_luarocks_dir_name, get_lua_tests_dir_name,
        get_download_filenames, check_version_compatibility,
        validate_current_configuration,
        LUA_VERSION, LUAROCKS_VERSION, LUAROCKS_PLATFORM
    )
except ImportError as e:
    print(f"Error importing configuration: {e}")
    print("Make sure config.py is in the same directory as this script.")
    sys.exit(1)


def download_file(url, dest):
    """Download a file from a URL to a specified destination."""
    print(f"Downloading {url} to {dest}...")
    urllib.request.urlretrieve(url, dest)
    print(f"Downloaded {dest}")

def download():
    # Check version compatibility first
    print("Checking version compatibility...")
    is_compatible, warnings = check_version_compatibility()
    if warnings:
        print("Configuration warnings:")
        for warning in warnings:
            print(f"  [WARNING] {warning}")
        if not is_compatible:
            response = input("Continue anyway? (y/N): ").strip().lower()
            if response not in ['y', 'yes']:
                print("Download cancelled.")
                sys.exit(1)
        print()

    # Show what we're about to download
    print(f"Preparing to download:")
    print(f"  Lua {LUA_VERSION}")
    print(f"  LuaRocks {LUAROCKS_VERSION} ({LUAROCKS_PLATFORM})")
    print()

    # Validate URLs before proceeding
    print("Validating download URLs...")
    all_valid, results = validate_current_configuration()

    if not all_valid:
        print("\n[ERROR] Some download URLs are not accessible:")
        for name, result in results.items():
            if not result['exists']:
                print(f"  - {name}: {result['message']}")

        print("\nPossible solutions:")
        print("  1. Check your internet connection")
        print("  2. Verify the versions in build_config.txt are correct")
        print("  3. Use 'python config.py --discover' to find available versions")
        print("  4. Check if the version exists at the official websites:")
        print("     - Lua: https://www.lua.org/ftp/")
        print("     - LuaRocks: https://luarocks.github.io/luarocks/releases/")

        response = input("\nContinue download anyway? (y/N): ").strip().lower()
        if response not in ['y', 'yes']:
            print("Download cancelled.")
            sys.exit(1)
    else:
        print("[OK] All URLs are accessible!")

    print()

    # Create directories if they do not exist
    downloads_dir = Path("downloads")
    downloads_dir.mkdir(exist_ok=True)

    # Get filenames from configuration
    filenames = get_download_filenames()

    # Define file paths
    lua_file = downloads_dir / filenames['lua']
    luarocks_file = downloads_dir / filenames['luarocks']
    lua_tests_file = downloads_dir / filenames['lua_tests']

    # Download Lua and LuaRocks using configuration URLs
    download_file(get_lua_url(), str(lua_file))
    download_file(get_luarocks_url(), str(luarocks_file))
    download_file(get_lua_tests_url(), str(lua_tests_file))

    return str(lua_file), str(luarocks_file), str(lua_tests_file)

## Extract files and move extracted folders to parent directory
def extract_file(file_path):
    """Extract a file and move the extracted contents to the parent directory."""
    file_path = Path(file_path)

    if file_path.suffix == ".gz" and file_path.stem.endswith(".tar"):
        import tarfile
        with tarfile.open(file_path, "r:gz") as tar:
            # Extract to downloads directory first
            tar.extractall(path=file_path.parent)
            print(f"Extracted {file_path} to {file_path.parent}")

            # Get all top-level directories from tar archive
            top_level_dirs = set()
            for member in tar.getnames():
                # Get the first component of the path (top-level directory)
                top_dir = member.split('/')[0]
                if top_dir:  # Make sure it's not empty
                    top_level_dirs.add(top_dir)

            # Move extracted folders to parent directory using configuration-aware names
            for dir_name in top_level_dirs:
                source = file_path.parent / dir_name
                # Determine the target directory name based on the file being extracted
                if "lua-" in str(file_path) and "tests" in str(file_path):
                    dest = Path(get_lua_tests_dir_name())
                elif "lua-" in str(file_path):
                    dest = Path(get_lua_dir_name())
                else:
                    dest = Path(dir_name)  # fallback to original name

                if source.exists() and source.is_dir():
                    if dest.exists():
                        shutil.rmtree(dest)
                    shutil.move(str(source), str(dest))
                    print(f"Moved {source} to {dest}")

    elif file_path.suffix == ".zip":
        import zipfile
        with zipfile.ZipFile(file_path, 'r') as zip_ref:
            # Extract to downloads directory first
            zip_ref.extractall(path=file_path.parent)
            print(f"Extracted {file_path} to {file_path.parent}")

            # Move extracted folders to parent directory
            extracted_items = set()
            for name in zip_ref.namelist():
                if '/' in name:
                    top_dir = name.split('/')[0]
                    extracted_items.add(top_dir)
                else:
                    extracted_items.add(name)

            for item in extracted_items:
                source = file_path.parent / item
                # Use configuration-aware name for LuaRocks
                if "luarocks" in str(file_path).lower():
                    dest = Path(get_luarocks_dir_name())
                else:
                    dest = Path(item)  # fallback to original name

                if source.exists():
                    if dest.exists():
                        if dest.is_dir():
                            shutil.rmtree(dest)
                        else:
                            dest.unlink()
                    shutil.move(str(source), str(dest))
                    print(f"Moved {source} to {dest}")
    else:
        print(f"Unsupported file format: {file_path}")


if __name__ == "__main__":
    # Check for command line arguments
    if len(sys.argv) > 1:
        if sys.argv[1] in ['--config', '-c', '--show-config']:
            print("Current Lua MSVC Build Configuration:")
            print("=" * 40)
            print(f"Lua Version: {LUA_VERSION}")
            print(f"LuaRocks Version: {LUAROCKS_VERSION}")
            print(f"Platform: {LUAROCKS_PLATFORM}")
            print()
            print("Download URLs:")
            print(f"  Lua: {get_lua_url()}")
            print(f"  Lua Tests: {get_lua_tests_url()}")
            print(f"  LuaRocks: {get_luarocks_url()}")
            print()
            print("Expected Directory Names:")
            print(f"  Lua: {get_lua_dir_name()}")
            print(f"  Lua Tests: {get_lua_tests_dir_name()}")
            print(f"  LuaRocks: {get_luarocks_dir_name()}")
            print()
            is_compatible, warnings = check_version_compatibility()
            if is_compatible:
                print("[OK] Configuration is valid")
            else:
                print("[WARNING] Configuration warnings:")
                for warning in warnings:
                    print(f"  - {warning}")
            print()
            print("To change versions, edit build_config.txt and modify:")
            print("  LUA_VERSION, LUAROCKS_VERSION, or LUAROCKS_PLATFORM")
            sys.exit(0)
        elif sys.argv[1] in ['--help', '-h']:
            print("Lua MSVC Build - Download Script")
            print("Usage:")
            print("  python download_lua_luarocks.py           # Download and extract files")
            print("  python download_lua_luarocks.py --config  # Show current configuration")
            print("  python download_lua_luarocks.py --help    # Show this help")
            print()
            print("Version Management:")
            print("  Edit build_config.txt to customize versions")
            print("  python config.py --discover     # Find available versions (uses cache)")
            print("  python config.py --check        # Validate current URLs")
            print("  python config.py --cache-info   # Show cache status")
            print()
            print("Performance:")
            print("  - Version discovery results are cached for 24 hours")
            print("  - URL validation includes rate limiting to be server-friendly")
            sys.exit(0)

    # Normal download and extract process
    dlds = download()
    for file in dlds:
        extract_file(file)
