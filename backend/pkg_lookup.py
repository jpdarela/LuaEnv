#!/usr/bin/env python3
"""
Version Checker and Updater for LuaEnv

This script checks and updates the .versions.json file with new Lua and LuaRocks versions.
It verifies that the URLs in the JSON file are accessible and discovers new versions.

Usage:
    python pkg_lookup.py help [command] # Show help for all commands or a specific command
    python pkg_lookup.py check          # Check if all versions in JSON are accessible
    python pkg_lookup.py discover       # Discover new versions and suggest updates
    python pkg_lookup.py update         # Discover and automatically update the JSON file
    python pkg_lookup.py status         # Show current JSON status and statistics
    python pkg_lookup.py compatibility  # Check and update test suite compatibility

Author: LuaEnv Team
Date: July 2025
"""

import os
import sys
import json
import re
import time
import urllib.request
import urllib.error
from datetime import datetime
from typing import Dict, List, Set, Tuple, Optional, Union, Any
from urllib.parse import urljoin


# Constants
JSON_FILE = os.path.join(os.path.dirname(os.path.abspath(__file__)), ".versions.json")
USER_AGENT = "LuaEnv-Version-Checker/1.0"
TIMEOUT = 10  # seconds
MAX_RETRIES = 3

# Lua version test compatibility map
# Format: lua_version_pattern -> test_pattern_to_use
LUA_TEST_PATTERNS = [
    (r"^5\.5\.\d+", "5.5.0-tests"),  # 5.5.x -> 5.5.0-tests
    (r"^5\.4\.\d+", None),           # 5.4.x -> use exact match (5.4.x-tests)
    (r"^5\.3\.\d+", None),           # 5.3.x -> use exact or closest match
    (r"^5\.2\.\d+", None),           # 5.2.x -> use exact or closest match
    (r"^5\.1\.\d+", "5.1-tests"),    # 5.1.x -> 5.1-tests
    (r"^5\.0\.\d+", None)            # 5.0.x -> no tests available
]


class VersionChecker:
    def __init__(self, json_file: str):
        """Initialize the version checker with the path to the JSON file."""
        self.json_file = json_file
        self.json_data = self._load_json()
        self.sources = self.json_data.get("sources", {})
        self.compatibility = self.json_data.get("compatibility", {})
        self._initialize_json_structure()

    def _initialize_json_structure(self):
        """Ensure the JSON data has the expected structure."""
        # Initialize metadata if missing
        if "metadata" not in self.json_data:
            self.json_data["metadata"] = {
                "description": "This file lists the versions of Lua, LuaRocks, and Lua tests that are available for download.",
                "last_updated": datetime.now().strftime("%Y-%m-%d")
            }

        # Initialize sources if missing
        if "sources" not in self.json_data:
            self.json_data["sources"] = {}
            self.sources = self.json_data["sources"]

        # Initialize compatibility if missing
        if "compatibility" not in self.json_data:
            self.json_data["compatibility"] = {
                "lua_test_mappings": {},
                "notes": "Compatibility mappings between Lua versions and test suites."
            }
            self.compatibility = self.json_data["compatibility"]

        # Ensure LuaRocks has all required arrays if it exists
        if "luarocks" in self.sources:
            if "win32" not in self.sources["luarocks"]:
                self.sources["luarocks"]["win32"] = []

            if "win64" not in self.sources["luarocks"]:
                self.sources["luarocks"]["win64"] = []

    def _load_json(self) -> Dict[str, Any]:
        """Load the JSON file."""
        try:
            with open(self.json_file, "r", encoding="utf-8") as f:
                return json.load(f)
        except (json.JSONDecodeError, FileNotFoundError) as e:
            print(f"Error loading JSON file: {e}")
            sys.exit(1)

    def _save_json(self) -> None:
        """Save the JSON data back to the file."""
        try:
            with open(self.json_file, "w", encoding="utf-8") as f:
                json.dump(self.json_data, f, indent=2)
            print(f"Successfully updated {self.json_file}")
        except Exception as e:
            print(f"Error saving JSON file: {e}")
            sys.exit(1)

    def _fetch_url(self, url: str) -> Optional[str]:
        """Fetch URL content with retries."""
        headers = {"User-Agent": USER_AGENT}
        request = urllib.request.Request(url, headers=headers)

        for attempt in range(MAX_RETRIES):
            try:
                with urllib.request.urlopen(request, timeout=TIMEOUT) as response:
                    return response.read().decode('utf-8')
            except urllib.error.URLError as e:
                print(f"Attempt {attempt + 1}/{MAX_RETRIES} failed: {e}")
                if attempt < MAX_RETRIES - 1:
                    delay = (attempt + 1) * 2
                    print(f"Retrying in {delay} seconds...")
                    time.sleep(delay)
                else:
                    print(f"Failed to fetch {url} after {MAX_RETRIES} attempts")
                    return None
            except Exception as e:
                print(f"Unexpected error: {e}")
                return None

    def _check_url_exists(self, url: str) -> bool:
        """Check if a URL exists without downloading the full content."""
        headers = {"User-Agent": USER_AGENT}
        request = urllib.request.Request(url, headers=headers, method="HEAD")

        try:
            with urllib.request.urlopen(request, timeout=TIMEOUT) as response:
                return response.status == 200
        except:
            # Try GET if HEAD is not supported
            try:
                request = urllib.request.Request(url, headers=headers)
                with urllib.request.urlopen(request, timeout=TIMEOUT) as response:
                    return response.status == 200
            except:
                return False

    def _parse_versions(self, html: str, pattern: str) -> List[str]:
        """Parse versions from HTML content using regex pattern."""
        matches = re.findall(pattern, html)

        # Handle cases where regex returns tuples (for grouped captures)
        versions = []
        for match in matches:
            if isinstance(match, tuple):
                # For our patterns, we always want the first capture group
                versions.append(match[0])
            else:
                versions.append(match)

        return sorted(set(versions), key=self._version_key, reverse=True)

    def _version_key(self, version: str) -> List[Union[int, str]]:
        """Create a key for sorting versions in natural order."""
        # Split version string into parts (numeric and non-numeric)
        parts = []
        for part in re.split(r'([0-9]+)', version):
            if part.isdigit():
                parts.append(int(part))
            elif part:
                parts.append(part)
        return parts

    def _get_filename_for_version(self, source_name: str, version: str, platform: str = None) -> str:
        """Get the correct filename for a version based on source type and platform."""
        if source_name == "lua":
            return f"lua-{version}.tar.gz"
        elif source_name == "lua_work":
            return f"lua-{version}.tar.gz"
        elif source_name == "luarocks":
            if platform == "win32":
                return f"luarocks-{version}-windows-32.zip"
            elif platform == "win64":
                return f"luarocks-{version}-windows-64.zip"
            else:
                # This should not happen with current logic since we only use win32/win64
                print(f"Warning: Unsupported platform '{platform}' for LuaRocks, defaulting to win64")
                return f"luarocks-{version}-windows-64.zip"
        elif source_name == "lua_tests":
            # Special case for Lua 5.1 tests
            if version == "5.1-tests":
                return f"lua{version}.tar.gz"
            else:
                return f"lua-{version}.tar.gz"
        else:
            return f"{version}.tar.gz"

    def check_versions(self, source_name: str) -> Tuple[int, int]:
        """Check if all versions for a given source are accessible."""
        if source_name not in self.sources:
            print(f"Source '{source_name}' not found in JSON file")
            return 0, 0

        source = self.sources[source_name]
        base_url = source.get("url", "")
        versions = source.get("versions", [])

        available = 0
        unavailable = 0

        # For LuaRocks, we only care about Windows binary packages
        if source_name == "luarocks":
            # Check Windows 32-bit binary packages
            win32_versions = source.get("win32", [])
            if win32_versions:
                print(f"Checking {len(win32_versions)} Windows 32-bit binary packages for {source_name}...")
                for version in win32_versions:
                    filename = self._get_filename_for_version(source_name, version, "win32")
                    url = urljoin(base_url, filename)
                    exists = self._check_url_exists(url)

                    status = "✓" if exists else "✗"
                    print(f"  [{status}] {url}")

                    if exists:
                        available += 1
                    else:
                        unavailable += 1

            # Check Windows 64-bit binary packages
            win64_versions = source.get("win64", [])
            if win64_versions:
                print(f"Checking {len(win64_versions)} Windows 64-bit binary packages for {source_name}...")
                for version in win64_versions:
                    filename = self._get_filename_for_version(source_name, version, "win64")
                    url = urljoin(base_url, filename)
                    exists = self._check_url_exists(url)

                    status = "✓" if exists else "✗"
                    print(f"  [{status}] {url}")

                    if exists:
                        available += 1
                    else:
                        unavailable += 1
        else:
            # For other sources, check all versions
            print(f"Checking {len(versions)} versions for {source_name} at {base_url}...")
            for version in versions:
                filename = self._get_filename_for_version(source_name, version)
                url = urljoin(base_url, filename)
                exists = self._check_url_exists(url)

                status = "✓" if exists else "✗"
                print(f"  [{status}] {url}")

                if exists:
                    available += 1
                else:
                    unavailable += 1

        print(f"Results for {source_name}: {available} available, {unavailable} unavailable")
        return available, unavailable

    def discover_new_versions(self, source_name: str) -> List[str]:
        """Discover new versions for a given source."""
        if source_name not in self.sources:
            print(f"Source '{source_name}' not found in JSON file")
            return []

        source = self.sources[source_name]
        base_url = source.get("url", "")
        known_versions = set(source.get("versions", []))

        print(f"Discovering new versions for {source_name} at {base_url}...")

        html = self._fetch_url(base_url)
        if not html:
            return []

        all_versions = []

        # Define regex patterns for different sources
        if source_name == "lua":
            pattern = r'lua-([0-9]+\.[0-9]+(?:\.[0-9]+)?)\.tar\.gz'
            all_versions = self._parse_versions(html, pattern)

        elif source_name == "lua_work":
            # Pattern for development versions (beta, alpha, rc, etc.) but not test suites
            pattern_dev = r'lua-([0-9]+\.[0-9]+\.[0-9]+-(beta|alpha|rc|work)\w*)\.tar\.gz'
            # Pattern for test suites in the work directory
            pattern_tests = r'lua-([0-9]+\.[0-9]+\.[0-9]+-tests)\.tar\.gz'

            # Get development versions first (excluding test suites)
            dev_matches = re.findall(pattern_dev, html)
            if dev_matches:
                # Extract just the version string from tuple matches if needed
                dev_versions = []
                for match in dev_matches:
                    if isinstance(match, tuple):
                        dev_versions.append(match[0])  # Take the full version match
                    else:
                        dev_versions.append(match)
                all_versions = sorted(set(dev_versions), key=self._version_key, reverse=True)
            else:
                all_versions = []

            # Get test suites and add them to the tests list in the JSON
            test_matches = re.findall(pattern_tests, html)
            if test_matches:
                # If we found test suites, handle them separately
                known_tests = set(source.get("tests", []))
                new_tests = [t for t in test_matches if t not in known_tests]

                if new_tests:
                    print(f"Found {len(new_tests)} new test suites for {source_name}:")
                    for version in new_tests:
                        print(f"  + {version}")

                    # Update the JSON with new test suites
                    if "tests" not in self.sources[source_name]:
                        self.sources[source_name]["tests"] = []

                    # Add new test suites
                    current_tests = self.sources[source_name].get("tests", [])
                    updated_tests = sorted(
                        set(current_tests + new_tests),
                        key=self._version_key,
                        reverse=True
                    )
                    self.sources[source_name]["tests"] = updated_tests

        elif source_name == "luarocks":
            # Pattern for Windows 32-bit binary packages (not installers)
            pattern_win32_bin = r'luarocks-([0-9]+\.[0-9]+\.[0-9]+(?:-(?:rc|beta|alpha)\d*)?)-windows-32\.zip'

            # Pattern for Windows 64-bit binary packages (not installers)
            pattern_win64_bin = r'luarocks-([0-9]+\.[0-9]+\.[0-9]+(?:-(?:rc|beta|alpha)\d*)?)-windows-64\.zip'

            # Get Windows binary package versions
            win32_bin_versions = self._parse_versions(html, pattern_win32_bin)
            win64_bin_versions = self._parse_versions(html, pattern_win64_bin)

            # Initialize platform-specific containers if needed
            if "win32" not in self.sources[source_name]:
                self.sources[source_name]["win32"] = []

            if "win64" not in self.sources[source_name]:
                self.sources[source_name]["win64"] = []

            # We don't track "versions" for LuaRocks anymore, only win32 and win64 binaries
            all_versions = []

            # Handle Windows 32-bit binary packages
            known_win32 = set(self.sources[source_name].get("win32", []))
            new_win32 = [v for v in win32_bin_versions if v not in known_win32]

            if new_win32:
                print(f"Found {len(new_win32)} new LuaRocks Windows 32-bit packages:")
                for version in new_win32:
                    print(f"  + {version} (win32)")

                # Update the JSON with new Win32 versions
                current_win32 = self.sources[source_name].get("win32", [])
                updated_win32 = sorted(
                    set(current_win32 + new_win32),
                    key=self._version_key,
                    reverse=True
                )
                self.sources[source_name]["win32"] = updated_win32

            # Handle Windows 64-bit binary packages
            known_win64 = set(self.sources[source_name].get("win64", []))
            new_win64 = [v for v in win64_bin_versions if v not in known_win64]

            if new_win64:
                print(f"Found {len(new_win64)} new LuaRocks Windows 64-bit packages:")
                for version in new_win64:
                    print(f"  + {version} (win64)")

                # Update the JSON with new Win64 versions
                current_win64 = self.sources[source_name].get("win64", [])
                updated_win64 = sorted(
                    set(current_win64 + new_win64),
                    key=self._version_key,
                    reverse=True
                )
                self.sources[source_name]["win64"] = updated_win64

        elif source_name == "lua_tests":
            # Handle both naming formats for Lua tests
            pattern1 = r'lua-([0-9]+\.[0-9]+\.[0-9]+-tests)\.tar\.gz'  # Modern format: lua-5.4.8-tests
            pattern2 = r'lua([0-9]+\.[0-9]+-tests)\.tar\.gz'           # Legacy format: lua5.1-tests

            all_versions = []
            all_versions.extend(self._parse_versions(html, pattern1))
            all_versions.extend(self._parse_versions(html, pattern2))

            # Sort and deduplicate
            all_versions = sorted(set(all_versions), key=self._version_key, reverse=True)

        else:
            pattern = r'([0-9]+\.[0-9]+\.[0-9]+)\.tar\.gz'
            all_versions = self._parse_versions(html, pattern)

        # Filter out known versions
        new_versions = [v for v in all_versions if v not in known_versions]

        if new_versions:
            print(f"Found {len(new_versions)} new versions for {source_name}:")
            for version in new_versions:
                print(f"  + {version}")
        else:
            print(f"No new versions found for {source_name}")

        return new_versions

    def update_json(self, source_name: str, new_versions: List[str]) -> None:
        """Update the JSON file with new versions for a given source."""
        # For LuaRocks, we don't track regular versions anymore, so skip if there are no platform-specific updates
        if source_name == "luarocks":
            # Platform-specific updates are handled directly in discover_new_versions
            # Just update the metadata timestamp
            self.json_data["metadata"]["last_updated"] = datetime.now().strftime("%Y-%m-%d")
            return

        if not new_versions:
            return

        if source_name not in self.sources:
            print(f"Source '{source_name}' not found in JSON file")
            return

        # For regular non-platform-specific versions
        if new_versions:
            # Add new versions and keep them sorted
            current_versions = self.sources[source_name].get("versions", [])
            updated_versions = sorted(
                set(current_versions + new_versions),
                key=self._version_key,
                reverse=True
            )

            # Update the JSON data
            self.sources[source_name]["versions"] = updated_versions
            print(f"Updated {source_name} with {len(new_versions)} new versions")

        # Update the metadata
        self.json_data["metadata"]["last_updated"] = datetime.now().strftime("%Y-%m-%d")

        # If we're adding Lua or test versions, update compatibility
        if source_name == "lua" or source_name == "lua_tests":
            self.update_compatibility()

    def update_compatibility(self) -> None:
        """Update the test compatibility mappings."""
        print("Updating test compatibility mappings...")

        # Get all Lua versions and test versions
        lua_versions = self.sources.get("lua", {}).get("versions", [])
        lua_work_versions = self.sources.get("lua_work", {}).get("versions", [])
        test_versions = self.sources.get("lua_tests", {}).get("versions", [])

        # Also include test versions from the work directory
        work_test_versions = self.sources.get("lua_work", {}).get("tests", [])
        test_versions = test_versions + work_test_versions

        all_lua_versions = sorted(set(lua_versions + lua_work_versions),
                                key=self._version_key, reverse=True)

        # Create or update lua_test_mappings
        mappings = {}

        for lua_version in all_lua_versions:
            # Find the most appropriate test version
            test_version = self._find_compatible_test(lua_version, test_versions)
            mappings[lua_version] = test_version

        # Update the JSON data
        self.compatibility["lua_test_mappings"] = mappings
        self.compatibility["notes"] = (
            "Test suites should be used with the exact Lua release they're designed for, "
            "or the closest release of the same version. Test suites do not work across "
            "different major or minor versions."
        )

        print(f"Updated compatibility mappings for {len(mappings)} Lua versions")

    def _find_compatible_test(self, lua_version: str, test_versions: List[str]) -> Optional[str]:
        """Find the most compatible test version for a Lua version."""
        # First, check for exact match
        exact_match = f"{lua_version}-tests"
        if exact_match in test_versions:
            return exact_match

        # Also check in the work directory tests
        work_tests = self.sources.get("lua_work", {}).get("tests", [])
        if exact_match in work_tests:
            return exact_match

        # Check for special cases based on version patterns
        for pattern, default_test in LUA_TEST_PATTERNS:
            if re.match(pattern, lua_version):
                if default_test:
                    return default_test

                # If no default test, find closest match in same minor version
                major, minor, _ = lua_version.split(".", 2)
                version_prefix = f"{major}.{minor}"

                compatible_tests = [v for v in test_versions
                                  if v.startswith(version_prefix)]

                if compatible_tests:
                    # Return the newest test version for this minor version
                    return sorted(compatible_tests, key=self._version_key, reverse=True)[0]

        # No compatible test found
        return None

    def show_status(self) -> None:
        """Show the current status of the JSON file."""
        print("=== JSON Version File Status ===")
        print(f"File: {self.json_file}")

        metadata = self.json_data.get("metadata", {})
        print(f"Description: {metadata.get('description', 'N/A')}")
        print(f"Last updated: {metadata.get('last_updated', 'N/A')}")
        print("\nSources:")

        for name, source in self.sources.items():
            versions = source.get("versions", [])
            url = source.get("url", "N/A")
            print(f"  {name}:")
            print(f"    URL: {url}")

            # For LuaRocks, we focus on Windows binaries only
            if name == "luarocks":
                win32_versions = source.get("win32", [])
                if win32_versions:
                    print(f"    Windows 32-bit Binary: {len(win32_versions)} ({win32_versions[0]} ... {win32_versions[-1]})")

                win64_versions = source.get("win64", [])
                if win64_versions:
                    print(f"    Windows 64-bit Binary: {len(win64_versions)} ({win64_versions[0]} ... {win64_versions[-1]})")
            else:
                # For other sources, show version counts
                if versions:
                    print(f"    Versions: {len(versions)} ({versions[0]} ... {versions[-1]})")
                else:
                    print(f"    Versions: 0")

            # If the source has test suites, show them too
            tests = source.get("tests", [])
            if tests:
                print(f"    Test Suites: {len(tests)} ({tests[0]} ... {tests[-1]})")

        print("\nCompatibility:")
        mappings = self.compatibility.get("lua_test_mappings", {})
        print(f"  Test mappings: {len(mappings)} entries")
        print(f"  Notes: {self.compatibility.get('notes', 'N/A')}")

    def check_compatibility(self) -> None:
        """Check the compatibility mappings and suggest improvements."""
        print("Checking test suite compatibility mappings...")

        lua_versions = self.sources.get("lua", {}).get("versions", [])
        lua_work_versions = self.sources.get("lua_work", {}).get("versions", [])
        test_versions = self.sources.get("lua_tests", {}).get("versions", [])

        # Also include test versions from the work directory
        work_test_versions = self.sources.get("lua_work", {}).get("tests", [])
        all_test_versions = sorted(set(test_versions + work_test_versions),
                                 key=self._version_key, reverse=True)

        all_lua_versions = sorted(set(lua_versions + lua_work_versions),
                                key=self._version_key, reverse=True)

        mappings = self.compatibility.get("lua_test_mappings", {})

        # Check for Lua versions without mappings
        unmapped = [v for v in all_lua_versions if v not in mappings]
        if unmapped:
            print(f"Found {len(unmapped)} Lua versions without test mappings:")
            for version in unmapped:
                test = self._find_compatible_test(version, all_test_versions)
                test_str = test if test else "None"
                print(f"  {version} -> {test_str}")

        # Check for test versions not used in mappings
        used_tests = set(test for test in mappings.values() if test)
        unused_tests = [t for t in all_test_versions if t not in used_tests]
        if unused_tests:
            print(f"Found {len(unused_tests)} test versions not used in mappings:")
            for test in unused_tests:
                print(f"  {test}")

        # Check for inconsistencies in mappings
        print("\nChecking for consistency issues:")
        issues = 0

        for lua_version, test in mappings.items():
            if not test:
                continue  # Skip null mappings (no tests available)

            expected_test = self._find_compatible_test(lua_version, all_test_versions)
            if test != expected_test:
                print(f"  Inconsistency: {lua_version} -> {test} (expected {expected_test})")
                issues += 1

        if issues == 0:
            print("  No consistency issues found")
        else:
            print(f"  Found {issues} consistency issues")

    def show_help(self, command: Optional[str] = None) -> None:
        """Show detailed help information for commands."""
        if command:
            self._show_command_help(command)
        else:
            self._show_general_help()

    def _show_general_help(self) -> None:
        """Show general help information for all commands."""
        print("LuaEnv Version Management Tool")
        print("==============================")
        print("\nThis tool helps manage Lua, LuaRocks, and Lua test suite versions for LuaEnv.")
        print("\nAvailable Commands:")
        print("  help [command]     Show this help message or detailed help for a specific command")
        print("  check              Check if all versions in JSON are accessible")
        print("  discover           Discover new versions and suggest updates")
        print("  update             Discover and automatically update the JSON file")
        print("  status             Show current JSON status and statistics")
        print("  compatibility      Check and update test suite compatibility")
        print("  cleanup            Clean up the JSON file structure")
        print("\nUse 'help <command>' for detailed information about a specific command.")

    def _show_command_help(self, command: str) -> None:
        """Show detailed help for a specific command."""
        command = command.lower()

        if command == "help":
            print("Command: help [command]")
            print("  Display detailed help information about available commands.")
            print("\nOptions:")
            print("  [command]    Optional command name to get detailed help for")
            print("\nExamples:")
            print("  python pkg_lookup.py help           # Show general help information")
            print("  python pkg_lookup.py help update    # Show detailed help for the 'update' command")

        elif command == "check":
            print("Command: check")
            print("  Check if all versions listed in the JSON file are accessible online.")
            print("  Verifies that each version can be downloaded from the respective URLs.")
            print("\nUsage:")
            print("  python pkg_lookup.py check")
            print("\nThis command will:")
            print("  1. For each source (lua, lua_work, luarocks, lua_tests), check all listed versions")
            print("  2. Show which versions are available (✓) and which are unavailable (✗)")
            print("  3. Display a summary with the count of available and unavailable versions")
            print("  4. Exit with status code 1 if any versions are unavailable")

        elif command == "discover":
            print("Command: discover")
            print("  Discover new versions available from the source URLs.")
            print("  Scans the source URLs for new versions that are not in the JSON file.")
            print("\nUsage:")
            print("  python pkg_lookup.py discover")
            print("\nThis command will:")
            print("  1. For each source, fetch the directory listing from its URL")
            print("  2. Parse the HTML to find all available versions")
            print("  3. Compare with versions in the JSON file to find new ones")
            print("  4. Display any new versions found without updating the JSON file")

        elif command == "update":
            print("Command: update")
            print("  Discover new versions and automatically update the JSON file.")
            print("  This combines the 'discover' command with automatic JSON updating.")
            print("\nUsage:")
            print("  python pkg_lookup.py update")
            print("\nThis command will:")
            print("  1. Run the discover process to find new versions")
            print("  2. Add any new versions to the JSON file")
            print("  3. Update the 'last_updated' date in the JSON metadata")
            print("  4. Update compatibility mappings for any new Lua or test versions")
            print("  5. Save the updated JSON file")

        elif command == "status":
            print("Command: status")
            print("  Show the current status of the JSON file.")
            print("  Displays a summary of the JSON file content and structure.")
            print("\nUsage:")
            print("  python pkg_lookup.py status")
            print("\nThis command will show:")
            print("  1. Basic metadata about the JSON file (description, last update)")
            print("  2. List of sources with their URLs and version counts")
            print("  3. For LuaRocks, displays separate counts for Windows 32-bit and 64-bit binary packages")
            print("  4. Summary of compatibility mappings")

        elif command == "compatibility":
            print("Command: compatibility [update]")
            print("  Check the compatibility mappings and suggest improvements.")
            print("  Analyzes the test suite compatibility mappings for consistency.")
            print("\nOptions:")
            print("  update    If provided, automatically updates the compatibility mappings")
            print("\nUsage:")
            print("  python pkg_lookup.py compatibility         # Check mappings only")
            print("  python pkg_lookup.py compatibility update  # Update mappings and save JSON")
            print("\nThis command will:")
            print("  1. Check for Lua versions without test mappings")
            print("  2. Check for test versions not used in any mappings")
            print("  3. Check for inconsistencies in the mappings")
            print("  4. If 'update' is specified, update all mappings based on compatibility rules")

        elif command == "cleanup":
            print("Command: cleanup")
            print("  Clean up the JSON file structure.")
            print("  Removes unnecessary elements and ensures proper structure.")
            print("\nUsage:")
            print("  python pkg_lookup.py cleanup")
            print("\nThis command will:")
            print("  1. Remove the 'versions' array from LuaRocks (since we only care about win32/win64)")
            print("  2. Update the timestamp in the metadata")
            print("  3. Save the cleaned up JSON file")

        else:
            print(f"Unknown command: {command}")
            print("Available commands: help, check, discover, update, status, compatibility")
            print("Use 'help' without arguments to see general help information.")

    def cleanup_json(self) -> None:
        """Clean up the JSON file, removing unnecessary elements."""
        print("Cleaning up JSON structure...")

        # Remove the "versions" array from luarocks since we only care about win32 and win64
        if "luarocks" in self.sources and "versions" in self.sources["luarocks"]:
            del self.sources["luarocks"]["versions"]
            print("Removed unnecessary 'versions' array from luarocks")

        # Update the metadata timestamp
        self.json_data["metadata"]["last_updated"] = datetime.now().strftime("%Y-%m-%d")

        # Save the changes
        self._save_json()


def main() -> None:
    """Main function to parse arguments and execute commands."""
    checker = VersionChecker(JSON_FILE)

    if len(sys.argv) < 2:
        print("Error: No command specified")
        checker.show_help()
        sys.exit(1)

    command = sys.argv[1].lower()

    if command == "check":
        total_available = 0
        total_unavailable = 0

        for source_name in checker.sources:
            available, unavailable = checker.check_versions(source_name)
            total_available += available
            total_unavailable += unavailable

        print(f"\nOverall results: {total_available} available, {total_unavailable} unavailable")
        if total_unavailable > 0:
            sys.exit(1)

    elif command == "discover":
        for source_name in checker.sources:
            checker.discover_new_versions(source_name)

    elif command == "update":
        updated = False

        for source_name in checker.sources:
            new_versions = checker.discover_new_versions(source_name)
            if new_versions:
                checker.update_json(source_name, new_versions)
                updated = True

            # Handle updating tests from lua_work specifically
            if source_name == "lua_work" and "tests" in checker.sources[source_name]:
                # We already handled the test updates within discover_new_versions for lua_work
                if checker.sources[source_name]["tests"]:
                    updated = True

        if updated:
            checker._save_json()
        else:
            print("No updates needed, all versions are current")

    elif command == "status":
        checker.show_status()

    elif command == "compatibility":
        checker.check_compatibility()

        if len(sys.argv) > 2 and sys.argv[2].lower() == "update":
            checker.update_compatibility()
            checker._save_json()

    elif command == "help":
        if len(sys.argv) > 2:
            checker.show_help(sys.argv[2])
        else:
            checker.show_help()

    elif command == "cleanup":
        checker.cleanup_json()

    else:
        print(f"Unknown command: {command}")
        print("Use 'help', 'check', 'discover', 'update', 'status', 'compatibility', or 'cleanup'")
        sys.exit(1)


if __name__ == "__main__":
    main()