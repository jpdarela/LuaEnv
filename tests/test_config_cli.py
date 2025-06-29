"""
Tests for config.py command-line interface and caching functionality.

This file tests the --discover and --refresh command-line options,
and verifies that the cache file is created and updated correctly.
"""

import unittest
import sys
import os
import subprocess
import tempfile
import json
from pathlib import Path
from datetime import datetime, timedelta

# Add parent directory to path so we can import config
sys.path.insert(0, str(Path(__file__).parent.parent))

import config


class TestConfigCommandLine(unittest.TestCase):
    """Test command-line interface of config.py."""

    def setUp(self):
        """Set up test environment."""
        # Save original working directory
        self.original_cwd = os.getcwd()

        # Change to project root (where config.py is)
        project_root = Path(__file__).parent.parent
        os.chdir(project_root)

        # Save path to cache file
        self.cache_file = Path("version_cache.json")

        # Remove cache file if it exists (clean slate)
        if self.cache_file.exists():
            self.cache_file.unlink()

    def tearDown(self):
        """Clean up test environment."""
        # Restore original working directory
        os.chdir(self.original_cwd)

    def test_config_help_command(self):
        """Test that config.py --help works."""
        result = subprocess.run([
            sys.executable, "config.py", "--help"
        ], capture_output=True, text=True)

        self.assertEqual(result.returncode, 0)
        self.assertIn("Lua MSVC Build System", result.stdout)
        self.assertIn("--discover", result.stdout)
        self.assertIn("--check", result.stdout)

    def test_config_check_command(self):
        """Test that config.py --check works."""
        result = subprocess.run([
            sys.executable, "config.py", "--check"
        ], capture_output=True, text=True)

        self.assertEqual(result.returncode, 0)
        self.assertIn("URL Validation", result.stdout)
        # Should either say "OK" or "WARNING"
        self.assertTrue("[OK]" in result.stdout or "[WARNING]" in result.stdout)

    def test_config_discover_creates_cache(self):
        """Test that config.py --discover creates a cache file."""
        # Ensure no cache file exists initially
        self.assertFalse(self.cache_file.exists(), "Cache file should not exist initially")

        # Run discover command
        result = subprocess.run([
            sys.executable, "config.py", "--discover"
        ], capture_output=True, text=True)

        # Should succeed
        self.assertEqual(result.returncode, 0, f"Discover failed: {result.stderr}")

        # Output should contain version discovery info
        self.assertIn("Version Discovery", result.stdout)
        self.assertIn("available Lua versions", result.stdout)
        self.assertIn("available LuaRocks versions", result.stdout)

        # Cache file should now exist
        self.assertTrue(self.cache_file.exists(), "Cache file should be created")

        # Cache file should be valid JSON
        with open(self.cache_file, 'r') as f:
            cache_data = json.load(f)

        # Should have expected structure
        self.assertIn('timestamp', cache_data)
        self.assertIn('lua_versions', cache_data)
        self.assertIn('luarocks_versions', cache_data)

        # Versions should be lists/dicts
        self.assertIsInstance(cache_data['lua_versions'], list)
        self.assertIsInstance(cache_data['luarocks_versions'], dict)

        print(f"[SUCCESS] Cache created with {len(cache_data['lua_versions'])} Lua versions")

    def test_config_discover_uses_existing_cache(self):
        """Test that config.py --discover uses existing cache without --refresh."""
        # First, create a cache by running discover
        result1 = subprocess.run([
            sys.executable, "config.py", "--discover"
        ], capture_output=True, text=True)

        self.assertEqual(result1.returncode, 0)
        self.assertTrue(self.cache_file.exists())

        # Get timestamp of first cache
        first_cache_time = self.cache_file.stat().st_mtime

        # Wait a tiny bit to ensure timestamps would be different
        import time
        time.sleep(0.1)

        # Run discover again (should use cache)
        result2 = subprocess.run([
            sys.executable, "config.py", "--discover"
        ], capture_output=True, text=True)

        self.assertEqual(result2.returncode, 0)

        # Cache file timestamp should be the same (not recreated)
        second_cache_time = self.cache_file.stat().st_mtime
        self.assertEqual(first_cache_time, second_cache_time, "Cache should not be recreated")

        # Output should mention using cached data
        self.assertIn("Using cached data", result2.stdout)

    def test_config_discover_refresh_updates_cache(self):
        """Test that config.py --discover --refresh updates the cache."""
        # First, create a cache by running discover
        result1 = subprocess.run([
            sys.executable, "config.py", "--discover"
        ], capture_output=True, text=True)

        self.assertEqual(result1.returncode, 0)
        self.assertTrue(self.cache_file.exists())

        # Get timestamp of first cache
        first_cache_time = self.cache_file.stat().st_mtime

        # Wait a bit to ensure timestamps will be different
        import time
        time.sleep(0.2)

        # Run discover with refresh (should update cache)
        result2 = subprocess.run([
            sys.executable, "config.py", "--discover", "--refresh"
        ], capture_output=True, text=True)

        self.assertEqual(result2.returncode, 0)

        # Cache file timestamp should be different (recreated)
        second_cache_time = self.cache_file.stat().st_mtime
        self.assertNotEqual(first_cache_time, second_cache_time, "Cache should be recreated with --refresh")

        # Output should NOT mention using cached data (since we refreshed)
        self.assertNotIn("Using cached data", result2.stdout)

        print("[SUCCESS] Cache was refreshed with --refresh flag")

    def test_cache_file_structure(self):
        """Test that the cache file has the correct structure."""
        # Create cache
        result = subprocess.run([
            sys.executable, "config.py", "--discover"
        ], capture_output=True, text=True)

        self.assertEqual(result.returncode, 0)

        # Read and validate cache structure
        with open(self.cache_file, 'r') as f:
            cache_data = json.load(f)

        # Check required keys
        required_keys = ['timestamp', 'lua_versions', 'luarocks_versions', 'cache_expiry_hours']
        for key in required_keys:
            self.assertIn(key, cache_data, f"Cache missing required key: {key}")

        # Check data types
        self.assertIsInstance(cache_data['timestamp'], str)
        self.assertIsInstance(cache_data['lua_versions'], list)
        self.assertIsInstance(cache_data['luarocks_versions'], dict)
        self.assertIsInstance(cache_data['cache_expiry_hours'], (int, float))

        # Timestamp should be parseable
        timestamp = datetime.fromisoformat(cache_data['timestamp'])
        self.assertIsInstance(timestamp, datetime)

        # Should have some versions
        self.assertGreater(len(cache_data['lua_versions']), 0, "Should have at least one Lua version")
        self.assertGreater(len(cache_data['luarocks_versions']), 0, "Should have at least one platform")

        print(f"[SUCCESS] Cache structure validated:")
        print(f"  Timestamp: {cache_data['timestamp']}")
        print(f"  Lua versions: {len(cache_data['lua_versions'])}")
        print(f"  LuaRocks platforms: {len(cache_data['luarocks_versions'])}")
        print(f"  Cache expiry: {cache_data['cache_expiry_hours']} hours")


class TestConfigCacheIntegration(unittest.TestCase):
    """Test cache integration with config functions."""

    def setUp(self):
        """Set up test environment."""
        # Save original working directory
        self.original_cwd = os.getcwd()

        # Change to project root
        project_root = Path(__file__).parent.parent
        os.chdir(project_root)

        # Clear any existing cache
        config.clear_version_cache()

    def tearDown(self):
        """Clean up test environment."""
        # Restore original working directory
        os.chdir(self.original_cwd)

    def test_get_cached_versions_no_cache(self):
        """Test get_cached_versions when no cache exists."""
        result = config.get_cached_versions()

        self.assertIsInstance(result, tuple)
        self.assertEqual(len(result), 3)

        lua_versions, luarocks_versions, is_cached = result

        # Should return empty/default values
        self.assertEqual(lua_versions, [])
        self.assertEqual(luarocks_versions, {})
        self.assertFalse(is_cached)

    def test_discover_and_cache_versions_creates_cache(self):
        """Test that discover_and_cache_versions creates cache."""
        # Should not be cached initially
        lua_versions1, luarocks_versions1, is_cached1 = config.get_cached_versions()
        self.assertFalse(is_cached1)

        # Discover and cache versions
        lua_versions2, luarocks_versions2 = config.discover_and_cache_versions(force_refresh=True)

        # Should have found some versions
        self.assertIsInstance(lua_versions2, list)
        self.assertIsInstance(luarocks_versions2, dict)
        self.assertGreater(len(lua_versions2), 0)
        self.assertGreater(len(luarocks_versions2), 0)

        # Now should be cached
        lua_versions3, luarocks_versions3, is_cached3 = config.get_cached_versions()
        self.assertTrue(is_cached3)
        self.assertEqual(lua_versions3, lua_versions2)
        self.assertEqual(luarocks_versions3, luarocks_versions2)

    def test_cache_expiry_behavior(self):
        """Test cache expiry behavior (without waiting 240 hours)."""
        # Create a cache
        config.discover_and_cache_versions(force_refresh=True)

        # Verify cache exists and is valid
        lua_versions1, luarocks_versions1, is_cached1 = config.get_cached_versions()
        self.assertTrue(is_cached1)

        # Manually modify cache timestamp to make it appear expired
        cache_file = Path("version_cache.json")
        if cache_file.exists():
            with open(cache_file, 'r') as f:
                cache_data = json.load(f)

            # Set timestamp to 250 hours ago (more than 240 hour expiry)
            expired_time = datetime.now() - timedelta(hours=250)
            cache_data['timestamp'] = expired_time.isoformat()

            with open(cache_file, 'w') as f:
                json.dump(cache_data, f, indent=2)

        # Now load_version_cache should return empty dict (expired)
        cache_result = config.load_version_cache()
        self.assertEqual(cache_result, {}, "Expired cache should return empty dict")


if __name__ == '__main__':
    unittest.main(verbosity=2)
