# This is free and unencumbered software released into the public domain.
# For more details, see the LICENSE file in the project root.

"""
Configuration file for LuaEnv

This file reads configuration from build_config.txt and provides
functions to access version information and URLs for Lua and LuaRocks.

The scripts use the versions specified in build_config.txt
"""

import os
from pathlib import Path
import urllib.request
import urllib.error
import re
import json
import time
from datetime import datetime, timedelta

# Default values (used if config file is missing or has errors)
DEFAULT_LUA_VERSION = "5.4.8"
DEFAULT_LUA_MAJOR_MINOR = "5.4"
DEFAULT_LUAROCKS_VERSION = "3.12.2"
DEFAULT_LUAROCKS_PLATFORM = "windows-64"

def load_config():
    """Load configuration from build_config.txt file."""
    config = {
        'LUA_VERSION': DEFAULT_LUA_VERSION,
        'LUA_MAJOR_MINOR': DEFAULT_LUA_MAJOR_MINOR,
        'LUAROCKS_VERSION': DEFAULT_LUAROCKS_VERSION,
        'LUAROCKS_PLATFORM': DEFAULT_LUAROCKS_PLATFORM
    }

    config_file = Path(__file__).parent / "build_config.txt"

    if not config_file.exists():
        print(f"[WARNING] Configuration file not found: {config_file}")
        print("Using default values. Create build_config.txt to customize versions.")
        return config

    try:
        with open(config_file, 'r', encoding='utf-8') as f:
            for line_num, line in enumerate(f, 1):
                line = line.strip()
                # Skip comments and empty lines
                if not line or line.startswith('#'):
                    continue

                # Parse key=value pairs
                if '=' in line:
                    key, value = line.split('=', 1)
                    key = key.strip()
                    value = value.strip()

                    if key in config:
                        config[key] = value
                    else:
                        print(f"[WARNING] Unknown configuration key '{key}' at line {line_num}")
                else:
                    print(f"[WARNING] Invalid configuration line {line_num}: {line}")

    except Exception as e:
        print(f"[ERROR] Failed to read configuration file: {e}")
        print("Using default values.")

    return config

# Load configuration on module import
_CONFIG = load_config()

# Extract values for easy access
LUA_VERSION = _CONFIG['LUA_VERSION']
LUA_MAJOR_MINOR = _CONFIG['LUA_MAJOR_MINOR']
LUAROCKS_VERSION = _CONFIG['LUAROCKS_VERSION']
LUAROCKS_PLATFORM = _CONFIG['LUAROCKS_PLATFORM']

# Derived URLs (automatically constructed from versions above)
LUA_BASE_URL = "https://www.lua.org/ftp"
LUA_TESTS_BASE_URL = "https://www.lua.org/tests"
LUAROCKS_BASE_URL = "https://luarocks.github.io/luarocks/releases"

def get_lua_url():
    """Get the download URL for Lua source code."""
    return f"{LUA_BASE_URL}/lua-{LUA_VERSION}.tar.gz"

def get_lua_tests_url():
    """Get the download URL for Lua test suite."""
    return f"{LUA_TESTS_BASE_URL}/lua-{LUA_VERSION}-tests.tar.gz"

def get_luarocks_url():
    """Get the download URL for LuaRocks."""
    return f"{LUAROCKS_BASE_URL}/luarocks-{LUAROCKS_VERSION}-{LUAROCKS_PLATFORM}.zip"

def get_lua_dir_name():
    """Get the expected directory name after extracting Lua source."""
    return f"lua-{LUA_VERSION}"

def get_luarocks_dir_name():
    """Get the expected directory name after extracting LuaRocks."""
    return f"luarocks-{LUAROCKS_VERSION}-{LUAROCKS_PLATFORM}"

def get_lua_tests_dir_name():
    """Get the expected directory name after extracting Lua tests."""
    return f"lua-{LUA_VERSION}-tests"

def get_download_filenames():
    """Get the expected download filenames."""
    return {
        'lua': f"lua-{LUA_VERSION}.tar.gz",
        'luarocks': f"luarocks-{LUAROCKS_VERSION}-{LUAROCKS_PLATFORM}.zip",
        'lua_tests': f"lua-{LUA_VERSION}-tests.tar.gz"
    }

# Cache settings
CACHE_FILE = Path(__file__).parent / "version_cache.json"
CACHE_EXPIRY_HOURS = 240  # Cache expires after 240 hours

# Global flag to track if we've already shown the cache message
_cache_message_shown = False

def load_version_cache(show_message=True):
    """Load cached version information."""
    global _cache_message_shown

    if not CACHE_FILE.exists():
        return {}

    try:
        with open(CACHE_FILE, 'r', encoding='utf-8') as f:
            cache = json.load(f)

        # Check if cache is expired
        cache_time = datetime.fromisoformat(cache.get('timestamp', '1970-01-01T00:00:00'))
        expiry_time = cache_time + timedelta(hours=CACHE_EXPIRY_HOURS)

        if datetime.now() > expiry_time:
            if show_message and not _cache_message_shown:
                print(f"[INFO] Version cache expired (older than {CACHE_EXPIRY_HOURS} hours)")
                _cache_message_shown = True
            return {}

        if show_message and not _cache_message_shown:
            print(f"[INFO] Using cached version data from {cache_time.strftime('%Y-%m-%d %H:%M')}")
            _cache_message_shown = True
        return cache

    except Exception as e:
        if show_message and not _cache_message_shown:
            print(f"[WARNING] Failed to load version cache: {e}")
            _cache_message_shown = True
        return {}

def save_version_cache(lua_versions, luarocks_versions):
    """Save version information to cache."""
    try:
        cache_data = {
            'timestamp': datetime.now().isoformat(),
            'lua_versions': lua_versions,
            'luarocks_versions': luarocks_versions,
            'cache_expiry_hours': CACHE_EXPIRY_HOURS
        }

        with open(CACHE_FILE, 'w', encoding='utf-8') as f:
            json.dump(cache_data, f, indent=2)

        print(f"[INFO] Version cache saved to {CACHE_FILE}")

    except Exception as e:
        print(f"[WARNING] Failed to save version cache: {e}")

def clear_version_cache():
    """Clear the version cache file."""
    try:
        if CACHE_FILE.exists():
            CACHE_FILE.unlink()
            print(f"[INFO] Version cache cleared: {CACHE_FILE}")
        else:
            print("[INFO] No cache file to clear")
    except Exception as e:
        print(f"[WARNING] Failed to clear cache: {e}")

def get_cached_versions(show_message=True):
    """Get versions from cache if available."""
    cache = load_version_cache(show_message=show_message)

    if cache and 'lua_versions' in cache and 'luarocks_versions' in cache:
        return (
            cache['lua_versions'],
            cache['luarocks_versions'],
            True  # indicates data is from cache
        )

    return [], {}, False  # no cache available

# Version compatibility checks
def check_version_compatibility():
    """
    Check if the configured versions are likely to be compatible.
    Returns (is_compatible, warnings_list)
    """
    warnings = []

    # Check Lua version format
    try:
        major, minor, patch = LUA_VERSION.split('.')
        major, minor, patch = int(major), int(minor), int(patch)

        if major != 5:
            warnings.append(f"Lua major version {major} may not be compatible with this build system (designed for Lua 5.x)")

        if minor < 4:
            warnings.append(f"Lua {LUA_VERSION} is older than 5.3 - some features may not work as expected")

    except ValueError:
        warnings.append(f"Invalid Lua version format: {LUA_VERSION} (expected format: X.Y.Z)")

    # Check LuaRocks version format
    try:
        parts = LUAROCKS_VERSION.split('.')
        if len(parts) < 2:
            warnings.append(f"Invalid LuaRocks version format: {LUAROCKS_VERSION} (expected format: X.Y or X.Y.Z)")
    except:
        warnings.append(f"Invalid LuaRocks version format: {LUAROCKS_VERSION}")

    # Platform compatibility
    if LUAROCKS_PLATFORM not in ["windows-64", "windows-32"]:
        warnings.append(f"Unknown LuaRocks platform: {LUAROCKS_PLATFORM} (expected: windows-64 or windows-32)")

    return len(warnings) == 0, warnings

def check_url_exists(url, timeout=10):
    """
    Check if a URL exists and is accessible.
    Returns (exists, status_message)
    """
    try:
        request = urllib.request.Request(url, method='HEAD')
        response = urllib.request.urlopen(request, timeout=timeout)
        return True, f"OK ({response.status})"
    except urllib.error.HTTPError as e:
        return False, f"HTTP Error {e.code}: {e.reason}"
    except urllib.error.URLError as e:
        return False, f"URL Error: {e.reason}"
    except Exception as e:
        return False, f"Error: {str(e)}"

def validate_current_configuration():
    """
    Validate that all URLs in the current configuration are accessible.
    Returns (all_valid, results_dict)
    """
    urls_to_check = {
        'Lua Source': get_lua_url(),
        'Lua Tests': get_lua_tests_url(),
        'LuaRocks': get_luarocks_url()
    }

    results = {}
    all_valid = True

    print("Validating download URLs...")
    for name, url in urls_to_check.items():
        print(f"  Checking {name}...", end=' ')
        exists, message = check_url_exists(url)
        results[name] = {'url': url, 'exists': exists, 'message': message}

        if exists:
            print(f"[OK] {message}")
        else:
            print(f"[FAIL] {message}")
            all_valid = False

        # Small delay to be respectful to the server
        time.sleep(0.1)

    return all_valid, results

def get_available_lua_versions(max_versions=9, use_cache=True, force_refresh=False, use_stderr=False):
    """
    Try to discover available Lua versions by checking common version patterns.
    This is a best-effort approach since there's no API.
    """
    print_fn = print if not use_stderr else lambda *args, **kwargs: print(*args, file=sys.stderr, **kwargs)

    if use_cache and not force_refresh:
        cached_lua, cached_luarocks, is_cached = get_cached_versions()
        if is_cached and cached_lua:
            print_fn(f"[CACHE] Found {len(cached_lua)} Lua versions in cache")
            return cached_lua

    print_fn("Discovering available Lua versions (this may take a moment)...")
    print_fn("[INFO] Being respectful to lua.org servers with rate limiting...")

    # Common Lua versions to check (most recent first)
    versions_to_check = [
        "5.4.8", "5.4.7", "5.4.6", "5.4.5", "5.4.4", "5.4.3", "5.4.2", "5.4.1", "5.4.0"]
        # "5.3.6", "5.3.5", "5.3.4", "5.3.3", "5.3.2", "5.3.1", "5.3.0",
        # "5.2.4", "5.2.3", "5.2.2", "5.2.1", "5.2.0",
        # "5.1.5", "5.1.4", "5.1.3", "5.1.2", "5.1.1", "5.1"]

    available_versions = []
    checked_count = 0

    for version in versions_to_check:
        if checked_count >= max_versions:
            break

        url = f"{LUA_BASE_URL}/lua-{version}.tar.gz"
        print_fn(f"  Checking Lua {version}...", end=' ')

        exists, message = check_url_exists(url, timeout=5)
        if exists:
            available_versions.append(version)
            print_fn("[AVAILABLE]")
        else:
            print_fn("[NOT FOUND]")

        checked_count += 1

        # Rate limiting: wait between requests to be respectful
        if checked_count < max_versions:  # Don't wait after the last check
            time.sleep(0.1)  # 500ms delay between requests

    return available_versions

def get_available_luarocks_versions(platform="windows-64", max_versions=9, use_cache=True, force_refresh=False, use_stderr=False):
    """
    Try to discover available LuaRocks versions by checking common version patterns.
    """
    print_fn = print if not use_stderr else lambda *args, **kwargs: print(*args, file=sys.stderr, **kwargs)

    if use_cache and not force_refresh:
        cached_lua, cached_luarocks, is_cached = get_cached_versions()
        if is_cached and cached_luarocks.get(platform):
            print_fn(f"[CACHE] Found {len(cached_luarocks[platform])} LuaRocks versions for {platform} in cache")
            return cached_luarocks[platform]

    print_fn(f"Discovering available LuaRocks versions for {platform}...")
    print_fn("[INFO] Being respectful to luarocks.github.io servers with rate limiting...")

    # Common LuaRocks versions to check (most recent first)
    versions_to_check = [
        "3.12.2", "3.12.1", "3.12.0", "3.11.1", "3.11.0", "3.10.0", "3.9.2", "3.9.1", "3.9.0"]

    available_versions = []
    checked_count = 0

    for version in versions_to_check:
        if checked_count >= max_versions:
            break

        url = f"{LUAROCKS_BASE_URL}/luarocks-{version}-{platform}.zip"
        print_fn(f"  Checking LuaRocks {version}...", end=' ')

        exists, message = check_url_exists(url, timeout=5)
        if exists:
            available_versions.append(version)
            print_fn("[AVAILABLE]")
        else:
            print_fn("[NOT FOUND]")

        checked_count += 1

        # Rate limiting: wait between requests to be respectful
        if checked_count < max_versions:  # Don't wait after the last check
            time.sleep(0.1)  # 500ms delay between requests

    return available_versions

def discover_and_cache_versions(force_refresh=False, quiet=False, use_stderr=False):
    """
    Discover available versions and cache them.
    Returns (lua_versions, luarocks_versions_dict)
    """
    print_fn = print if not use_stderr else lambda *args, **kwargs: print(*args, file=sys.stderr, **kwargs)

    if not force_refresh:
        cached_lua, cached_luarocks, is_cached = get_cached_versions(show_message=not quiet)
        if is_cached:
            return cached_lua, cached_luarocks

    if not quiet:
        print_fn("Discovering available versions (this will take a few moments)...")
        print_fn("[INFO] Results will be cached for future use")

    # Discover Lua versions
    lua_versions = get_available_lua_versions(use_cache=False, use_stderr=use_stderr)

    # Discover LuaRocks versions for both platforms
    luarocks_versions = {
        'windows-64': get_available_luarocks_versions('windows-64', use_cache=False, use_stderr=use_stderr),
        'windows-32': get_available_luarocks_versions('windows-32', use_cache=False, use_stderr=use_stderr)
    }

    # Save to cache
    if use_stderr:
        with open(CACHE_FILE, 'w', encoding='utf-8') as f:
            cache_data = {
                'timestamp': datetime.now().isoformat(),
                'lua_versions': lua_versions,
                'luarocks_versions': luarocks_versions,
                'cache_expiry_hours': CACHE_EXPIRY_HOURS
            }
            json.dump(cache_data, f, indent=2)
        print_fn(f"[INFO] Version cache saved to {CACHE_FILE}")
    else:
        save_version_cache(lua_versions, luarocks_versions)

    return lua_versions, luarocks_versions

if __name__ == "__main__":
    import sys

    # Check for command line arguments
    if len(sys.argv) > 1:
        if sys.argv[1] in ['--check', '-c']:
            print("Lua MSVC Build System - URL Validation")
            print("=" * 50)
            all_valid, results = validate_current_configuration()
            print()
            if all_valid:
                print("[OK] All download URLs are accessible!")
            else:
                print("[WARNING] Some URLs are not accessible:")
                for name, result in results.items():
                    if not result['exists']:
                        print(f"  - {name}: {result['message']}")
                print()
                print("Consider checking build_config.txt for correct versions")
            sys.exit(0)

        elif sys.argv[1] in ['--discover', '-d']:
            force_refresh = '--refresh' in sys.argv or '-r' in sys.argv
            json_output = '--json' in sys.argv

            if json_output:
                # JSON output for programmatic consumption (CLI)
                # Use stderr for all debug output to keep stdout clean for JSON
                lua_versions, luarocks_versions = discover_and_cache_versions(force_refresh, quiet=True, use_stderr=True)

                # Build structured output
                cache_info = {}
                if not force_refresh:
                    cache_data = load_version_cache(show_message=False)
                    if cache_data:
                        cache_time = datetime.fromisoformat(cache_data.get('timestamp', '1970-01-01T00:00:00'))
                        cache_age_hours = (datetime.now() - cache_time).total_seconds() / 3600
                        cache_info = {
                            'used_cache': True,
                            'cache_age_hours': round(cache_age_hours, 1),
                            'cache_file': str(CACHE_FILE)
                        }
                    else:
                        cache_info = {'used_cache': False}
                else:
                    cache_info = {'used_cache': False, 'forced_refresh': True}

                output = {
                    'current_config': {
                        'lua_version': LUA_VERSION,
                        'lua_major_minor': LUA_MAJOR_MINOR,
                        'luarocks_version': LUAROCKS_VERSION,
                        'luarocks_platform': LUAROCKS_PLATFORM
                    },
                    'cache_info': cache_info,
                    'available_versions': {
                        'lua': lua_versions,
                        'luarocks': luarocks_versions
                    },
                    'discovery_timestamp': datetime.now().isoformat(),
                    'urls': {
                        'lua': get_lua_url(),
                        'lua_tests': get_lua_tests_url(),
                        'luarocks': get_luarocks_url()
                    },
                    'config_info': {
                        'config_file': str(Path(__file__).parent / "build_config.txt")
                    }
                }

                print(json.dumps(output, indent=2))
                sys.exit(0)
            else:
                # Human-readable output for direct use
                print("Lua MSVC Build System - Version Discovery")
                print("=" * 50)

                # Check current config first
                print("Current configuration:")
                print(f"  Lua: {LUA_VERSION}")
                print(f"  LuaRocks: {LUAROCKS_VERSION} ({LUAROCKS_PLATFORM})")
                print()

                # Check cache status
                if not force_refresh:
                    cached_lua, cached_luarocks, is_cached = get_cached_versions()
                    if is_cached:
                        cache_age = datetime.now() - datetime.fromisoformat(load_version_cache(show_message=False).get('timestamp', '1970-01-01T00:00:00'))
                        print(f"[INFO] Using cached data (age: {cache_age.total_seconds()/3600:.1f} hours)")
                        print("       Use --discover --refresh flags combined to update cache")
                        print()

                # Discover versions (using cache if available)
                lua_versions, luarocks_versions = discover_and_cache_versions(force_refresh)

                print(f"Found {len(lua_versions)} available Lua versions:")
                for version in lua_versions:
                    marker = " (CURRENT)" if version == LUA_VERSION else ""
                    print(f"  - {version}{marker}")

                print()
                platform_versions = luarocks_versions.get(LUAROCKS_PLATFORM, [])
                print(f"Found {len(platform_versions)} available LuaRocks versions for {LUAROCKS_PLATFORM}:")
                for version in platform_versions:
                    marker = " (CURRENT)" if version == LUAROCKS_VERSION else ""
                    print(f"  - {version}{marker}")

                # Show other platform if available
                other_platform = 'windows-32' if LUAROCKS_PLATFORM == 'windows-64' else 'windows-64'
                if other_platform in luarocks_versions:
                    other_versions = luarocks_versions[other_platform]
                    print(f"\nAlso available for {other_platform}: {len(other_versions)} versions")

                print()
                print("To use a different version, edit build_config.txt")
                if CACHE_FILE.exists():
                    print(f"Cache file: {CACHE_FILE}")
                sys.exit(0)

        elif sys.argv[1] in ['--clear-cache']:
            print("Clearing version cache...")
            clear_version_cache()
            sys.exit(0)

        elif sys.argv[1] in ['--cache-info']:
            cache = load_version_cache()
            if not cache:
                print("No cache file found")
            else:
                cache_time = datetime.fromisoformat(cache.get('timestamp', '1970-01-01T00:00:00'))
                cache_age = datetime.now() - cache_time
                expiry_time = cache_time + timedelta(hours=CACHE_EXPIRY_HOURS)

                print("Version Cache Information")
                print("=" * 30)
                print(f"Cache file: {CACHE_FILE}")
                print(f"Created: {cache_time.strftime('%Y-%m-%d %H:%M:%S')}")
                print(f"Age: {cache_age.total_seconds()/3600:.1f} hours")
                print(f"Expires: {expiry_time.strftime('%Y-%m-%d %H:%M:%S')}")
                print(f"Status: {'EXPIRED' if datetime.now() > expiry_time else 'VALID'}")
                print()
                print(f"Cached Lua versions: {len(cache.get('lua_versions', []))}")
                luarocks = cache.get('luarocks_versions', {})
                for platform, versions in luarocks.items():
                    print(f"Cached LuaRocks ({platform}): {len(versions)}")
            sys.exit(0)

        elif sys.argv[1] in ['--help', '-h']:
            print("Lua MSVC Build System Configuration")
            print("Usage:")
            print("  python config.py                             # Show current configuration")
            print("  python config.py --check                     # Validate current download URLs")
            print("  python config.py --discover                  # Discover available versions (use cache)")
            print("  python config.py --discover --refresh        # Discover versions (refresh cache)")
            print("  python config.py --discover --json           # Output version data as JSON")
            print("  python config.py --discover --json --refresh # JSON output with fresh data")
            print("  python config.py --cache-info                # Show cache information")
            print("  python config.py --clear-cache               # Clear version cache")
            print("  python config.py --help                      # Show this help")
            print()
            print("Cache Management:")
            print(f"  - Cache expires after {CACHE_EXPIRY_HOURS} hours")
            print("  - Use --refresh to force cache update")
            print("  - Cache reduces server load and improves performance")
            print()
            print("JSON Output:")
            print("  - Use --json flag for structured output (for CLI integration)")
            print("  - Includes cache info, URLs, and all available versions")
            print("  - Combine with --refresh for fresh data")
            print()
            print("To change versions, edit build_config.txt")
            sys.exit(0)

    # Default behavior - show current configuration
    print("Lua MSVC Build System Configuration")
    print("=" * 40)
    print(f"Configuration file: build_config.txt")
    print(f"Lua Version: {LUA_VERSION}")
    print(f"Lua Major.Minor: {LUA_MAJOR_MINOR}")
    print(f"LuaRocks Version: {LUAROCKS_VERSION}")
    print(f"Platform: {LUAROCKS_PLATFORM}")
    print()
    print("Download URLs:")
    print(f"  Lua: {get_lua_url()}")
    print(f"  Lua Tests: {get_lua_tests_url()}")
    print(f"  LuaRocks: {get_luarocks_url()}")
    print()
    print("Directory Names:")
    print(f"  Lua: {get_lua_dir_name()}")
    print(f"  Lua Tests: {get_lua_tests_dir_name()}")
    print(f"  LuaRocks: {get_luarocks_dir_name()}")
    print()

    # Check compatibility
    is_compatible, warnings = check_version_compatibility()
    if is_compatible:
        print("[OK] Configuration appears to be valid")
    else:
        print("[WARNING] Configuration warnings:")
        for warning in warnings:
            print(f"  - {warning}")

    print()
    print("To change versions, edit build_config.txt")
    print("Use 'python config.py --help' for more options")
