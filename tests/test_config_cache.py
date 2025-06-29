"""
Tests for config.py cache functions - testing cache operations without network access.

This file tests the cache-related functions in config.py that work with local files.
"""

import unittest
import sys
import os
import tempfile
import json
from pathlib import Path

# Add parent directory to path so we can import config
sys.path.insert(0, str(Path(__file__).parent.parent))

import config


class TestConfigCache(unittest.TestCase):
    """Test cache-related functions in config.py."""

    def test_load_version_cache_returns_dict(self):
        """Test that load_version_cache returns a dict (or empty dict if no cache)."""
        result = config.load_version_cache()

        self.assertIsInstance(result, dict)

        # If cache exists, it should have certain keys
        if result:  # If not empty
            expected_keys = ['timestamp', 'lua_versions', 'luarocks_versions']
            for key in expected_keys:
                self.assertIn(key, result)

            self.assertIsInstance(result['lua_versions'], list)
            self.assertIsInstance(result['luarocks_versions'], list)
            self.assertIsInstance(result['timestamp'], str)

    def test_get_cached_versions_returns_tuple(self):
        """Test that get_cached_versions returns a tuple with version info."""
        result = config.get_cached_versions()

        self.assertIsInstance(result, tuple)
        self.assertEqual(len(result), 3)

        lua_versions, luarocks_versions, is_cached = result

        # First element should be a list (lua versions)
        self.assertIsInstance(lua_versions, list)
        # Second element should be a list or dict (luarocks versions)
        self.assertIsInstance(luarocks_versions, (list, dict))
        # Third element should be a boolean (cache status)
        self.assertIsInstance(is_cached, bool)

    def test_save_and_load_version_cache(self):
        """Test that we can save and load version cache data."""
        # Test data
        test_lua_versions = ["5.4.8", "5.4.7", "5.4.6"]
        test_luarocks_versions = ["3.12.2", "3.11.1", "3.10.0"]

        # Save the cache
        config.save_version_cache(test_lua_versions, test_luarocks_versions)

        # Load it back
        cache_data = config.load_version_cache()

        # Should be a dict with our saved data
        self.assertIsInstance(cache_data, dict)
        self.assertEqual(cache_data['lua_versions'], test_lua_versions)
        self.assertEqual(cache_data['luarocks_versions'], test_luarocks_versions)

        # Clean up - clear the cache when done
        config.clear_version_cache()

    def test_clear_version_cache_removes_file(self):
        """Test that clear_version_cache removes the cache file."""
        # First create some cache data
        test_lua_versions = ["5.4.8"]
        test_luarocks_versions = ["3.12.2"]
        config.save_version_cache(test_lua_versions, test_luarocks_versions)

        # Verify it exists by loading it
        cache_data = config.load_version_cache()
        self.assertEqual(cache_data['lua_versions'], test_lua_versions)

        # Clear the cache
        config.clear_version_cache()

        # Now loading should return empty dict (no cache)
        cache_data = config.load_version_cache()
        self.assertEqual(cache_data, {})


if __name__ == '__main__':
    unittest.main()
