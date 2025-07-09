# This is free and unencumbered software released into the public domain.
# For more details, see the LICENSE file in the project root.
"""
Download and extract Lua source code and LuaRocks package manager for Windows.

This script uses a version-aware download manager that avoids re-downloading
and maintains a registry of available versions.
"""

import sys
import os

# Ensure we can import from the current directory when run from CLI
if __name__ == "__main__" or "backend" not in sys.path:
    current_dir = os.path.dirname(os.path.abspath(__file__))
    if current_dir not in sys.path:
        sys.path.insert(0, current_dir)

# Import configuration with dual-context support
try:
    from config import (
        get_lua_url, get_lua_tests_url, get_luarocks_url,
        get_lua_dir_name, get_luarocks_dir_name, get_lua_tests_dir_name,
        get_download_filenames, check_version_compatibility,
        validate_current_configuration,
        LUA_VERSION, LUAROCKS_VERSION, LUAROCKS_PLATFORM
    )
except ImportError:
    try:
        from .config import (
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

# Import download manager and utilities with dual-context support
try:
    from download_manager import DownloadManager
    from utils import extract_file, ensure_extracted_folder, clean_extracted_folder, list_extracted_contents
except ImportError:
    try:
        from .download_manager import DownloadManager
        from .utils import extract_file, ensure_extracted_folder, clean_extracted_folder, list_extracted_contents
    except ImportError as e:
        print(f"Error importing utilities: {e}")
        print("Make sure utils.py and download_manager.py are in the same directory as this script.")
        sys.exit(1)

def download():
    """Download Lua and LuaRocks using the version-aware download manager."""
    # Check version compatibility first
    print("Checking version compatibility...")
    is_compatible, warnings = check_version_compatibility()
    if warnings:
        print("Configuration warnings:")
        for warning in warnings:
            print(f"  [WARNING] {warning}")
        if not is_compatible:
            print("[ERROR] Version compatibility check failed.")
            print("[INFO] Please verify the versions in build_config.txt are correct.")
            print("[INFO] Use 'python config.py --discover' to find available versions.")
            print("Download cancelled.")
            sys.exit(1)
        print()

    # Show what we're about to download
    print(f"Preparing to download:")
    print(f"  Lua {LUA_VERSION}")
    print(f"  LuaRocks {LUAROCKS_VERSION} ({LUAROCKS_PLATFORM})")
    print()

    # Initialize download manager
    download_manager = DownloadManager()

    # Check if already downloaded
    if download_manager.is_downloaded(LUA_VERSION, LUAROCKS_VERSION, LUAROCKS_PLATFORM):
        print(f"[OK] Lua {LUA_VERSION} and LuaRocks {LUAROCKS_VERSION} already downloaded")
        print("Skipping download, proceeding to extraction...")
        return download_manager

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

        print("\n[ERROR] Download cannot proceed with inaccessible URLs.")
        print("Download cancelled.")
        sys.exit(1)
    else:
        print("[OK] All URLs are accessible!")

    print()

    # Prepare download URLs and filenames
    urls = {
        'lua': get_lua_url(),
        'luarocks': get_luarocks_url(),
        'lua_tests': get_lua_tests_url()
    }

    filenames = get_download_filenames()

    # Download using the download manager
    success, message = download_manager.download_version(
        LUA_VERSION, LUAROCKS_VERSION, urls, filenames, LUAROCKS_PLATFORM
    )

    if success:
        print(f"[OK] {message}")
        return download_manager
    else:
        print(f"[ERROR] {message}")
        sys.exit(1)


def create_extraction_callback():
    """Create a callback function for file extraction that uses configuration-aware naming."""
    def move_callback(source_path, original_name):
        """Determine target path based on the extracted content."""
        source_str = str(source_path)

        # Ensure extracted folder exists
        extracted_folder = ensure_extracted_folder()

        # Determine the target directory name based on content
        if "lua-" in original_name and "tests" in original_name:
            return extracted_folder / get_lua_tests_dir_name()
        elif "lua-" in original_name:
            return extracted_folder / get_lua_dir_name()
        elif "luarocks" in original_name.lower():
            return extracted_folder / get_luarocks_dir_name()
        else:
            return None  # Don't move, keep original name

    return move_callback


def main():
    """Main entry point for the script."""
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

        elif sys.argv[1] in ['--list', '-l', '--list-downloads']:
            download_manager = DownloadManager()
            versions = download_manager.list_downloaded_versions()

            if not versions:
                print("No versions downloaded yet.")
                sys.exit(0)

            print("Downloaded Version Combinations:")
            print("=" * 60)
            for version in versions:
                print(f"  {version['key']}")
                print(f"    Created: {version['created'][:10]}")
                print(f"    Size: {version['formatted_size']} ({version['file_count']} files)")
                print()

            info = download_manager.get_registry_info()
            print(f"Total: {info['combination_count']} combinations")
            print(f"  Lua versions: {info['lua_versions']}")
            print(f"  LuaRocks versions: {info['luarocks_versions']}")
            print(f"  Storage used: {info['formatted_size']}")
            sys.exit(0)

        elif sys.argv[1] in ['--cleanup', '--clean']:
            download_manager = DownloadManager()
            if len(sys.argv) > 2 and sys.argv[2] == '--all':
                # Clean up all but the latest 1 version
                success, message = download_manager.cleanup_old_versions(keep_latest=1)
            else:
                # Clean up old versions, keep latest 3
                success, message = download_manager.cleanup_old_versions(keep_latest=3)

            print(message)
            sys.exit(0 if success else 1)

        elif sys.argv[1] in ['--registry-info', '--info']:
            download_manager = DownloadManager()
            info = download_manager.get_registry_info()

            print("Download Registry Information:")
            print("=" * 40)
            print(f"Registry file: {info['registry_file']}")
            print(f"Base directory: {info['base_dir']}")
            print(f"Lua downloads: {info['lua_dir']}")
            print(f"LuaRocks downloads: {info['luarocks_dir']}")
            print(f"Version combinations: {info['combination_count']}")
            print(f"Lua versions stored: {info['lua_versions']}")
            print(f"LuaRocks versions stored: {info['luarocks_versions']}")
            print(f"Total storage used: {info['formatted_size']}")
            sys.exit(0)

        elif sys.argv[1] in ['--list-extracted', '--list-ext']:
            print("Listing extracted folder contents:")
            print("=" * 40)
            list_extracted_contents()
            sys.exit(0)

        elif sys.argv[1] in ['--clean-extracted', '--clean-ext']:
            print("Cleaning extracted folder...")
            # Force clean in non-interactive mode
            success = clean_extracted_folder(confirm=False)
            sys.exit(0 if success else 1)

        elif sys.argv[1] in ['--re-extract', '--extract']:
            # Re-extract the current version
            print(f"Re-extracting Lua {LUA_VERSION} and LuaRocks {LUAROCKS_VERSION}...")
            download_manager = DownloadManager()

            if not download_manager.is_downloaded(LUA_VERSION, LUAROCKS_VERSION, LUAROCKS_PLATFORM):
                print(f"[ERROR] Version not downloaded. Run without arguments to download first.")
                sys.exit(1)

            # Clean extracted folder first
            clean_extracted_folder(confirm=False)

            # Extract
            callback = create_extraction_callback()
            success, message = download_manager.extract_version(
                LUA_VERSION, LUAROCKS_VERSION, move_callback=callback, platform=LUAROCKS_PLATFORM
            )

            if success:
                print(f"[OK] {message}")
                print(f"\nRe-extracted to extracted folder:")
                extracted_folder = ensure_extracted_folder()
                print(f"  - Lua source: {extracted_folder / get_lua_dir_name()}")
                print(f"  - Lua tests: {extracted_folder / get_lua_tests_dir_name()}")
                print(f"  - LuaRocks: {extracted_folder / get_luarocks_dir_name()}")
            else:
                print(f"[ERROR] {message}")
                sys.exit(1)
            sys.exit(0)

        elif sys.argv[1] in ['--help', '-h']:
            print("Lua MSVC Build - Download Script")
            print("Usage:")
            print("  python download_lua_luarocks.py               # Download and extract files")
            print("  python download_lua_luarocks.py --config      # Show current configuration")
            print("  python download_lua_luarocks.py --list        # List downloaded versions")
            print("  python download_lua_luarocks.py --cleanup     # Clean up old downloads (keep 3)")
            print("  python download_lua_luarocks.py --cleanup --all  # Clean up all but latest")
            print("  python download_lua_luarocks.py --info        # Show registry information")
            print("  python download_lua_luarocks.py --help        # Show this help")
            print()
            print("Extraction Management:")
            print("  python download_lua_luarocks.py --list-extracted  # List extracted contents")
            print("  python download_lua_luarocks.py --clean-extracted # Clean extracted folder")
            print("  python download_lua_luarocks.py --clean-extracted --force  # Clean without confirmation")
            print("  python download_lua_luarocks.py --re-extract  # Re-extract current version")
            print()
            print("Version Management:")
            print("  Edit build_config.txt to customize versions")
            print("  python config.py --discover     # Find available versions (uses cache)")
            print("  python config.py --check        # Validate current URLs")
            print("  python config.py --cache-info   # Show cache status")
            print()
            print("Download Management:")
            print("  - Downloads are organized by version (lua-X.X.X_luarocks-X.X.X)")
            print("  - Avoids re-downloading existing versions")
            print("  - Maintains a registry of downloaded versions")
            print("  - Supports cleanup of old downloads to save space")
            print("  - Extracts to 'extracted' folder for build isolation")
            sys.exit(0)

    # Normal download and extract process
    download_manager = download()
    callback = create_extraction_callback()

    # Extract the downloaded files
    success, message = download_manager.extract_version(
        LUA_VERSION, LUAROCKS_VERSION, move_callback=callback, platform=LUAROCKS_PLATFORM
    )

    if success:
        print(f"[OK] {message}")
        print(f"\nExtracted to extracted folder:")
        extracted_folder = ensure_extracted_folder()
        print(f"  - Lua source: {extracted_folder / get_lua_dir_name()}")
        print(f"  - Lua tests: {extracted_folder / get_lua_tests_dir_name()}")
        print(f"  - LuaRocks: {extracted_folder / get_luarocks_dir_name()}")
    else:
        print(f"[ERROR] {message}")
        sys.exit(1)


if __name__ == "__main__":
    main()
