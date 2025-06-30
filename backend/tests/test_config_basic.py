"""
Basic tests for config.py - testing only what actually exists.

This file tests the basic configuration loading and URL functions in config.py.
We start simple and only test real functions with real return values.
"""

import unittest
import sys
from pathlib import Path

# Add parent directory to path so we can import config
sys.path.insert(0, str(Path(__file__).parent.parent))

import config


class TestConfigBasic(unittest.TestCase):
    """Test basic config.py functions that don't require network access."""

    def test_load_config_returns_dict(self):
        """Test that load_config returns a dictionary with expected keys."""
        result = config.load_config()

        # Should return a dictionary
        self.assertIsInstance(result, dict)

        # Should have the expected keys
        expected_keys = ['LUA_VERSION', 'LUA_MAJOR_MINOR', 'LUAROCKS_VERSION', 'LUAROCKS_PLATFORM']
        for key in expected_keys:
            self.assertIn(key, result)

        # Values should be strings
        for key, value in result.items():
            self.assertIsInstance(value, str)
            self.assertGreater(len(value), 0)  # Should not be empty

    def test_get_lua_url_returns_string(self):
        """Test that get_lua_url returns a string that looks like a URL."""
        result = config.get_lua_url()

        self.assertIsInstance(result, str)
        self.assertTrue(result.startswith('http'))
        self.assertIn('lua', result.lower())

    def test_get_luarocks_url_returns_string(self):
        """Test that get_luarocks_url returns a string that looks like a URL."""
        result = config.get_luarocks_url()

        self.assertIsInstance(result, str)
        self.assertTrue(result.startswith('http'))
        self.assertIn('luarocks', result.lower())

    def test_get_lua_dir_name_returns_string(self):
        """Test that get_lua_dir_name returns a reasonable directory name."""
        result = config.get_lua_dir_name()

        self.assertIsInstance(result, str)
        self.assertGreater(len(result), 0)
        self.assertIn('lua', result.lower())

    def test_get_luarocks_dir_name_returns_string(self):
        """Test that get_luarocks_dir_name returns a reasonable directory name."""
        result = config.get_luarocks_dir_name()

        self.assertIsInstance(result, str)
        self.assertGreater(len(result), 0)
        self.assertIn('luarocks', result.lower())

    def test_get_download_filenames_returns_dict(self):
        """Test that get_download_filenames returns a dict with expected structure."""
        result = config.get_download_filenames()

        self.assertIsInstance(result, dict)

        # Should have keys for lua and luarocks
        expected_keys = ['lua', 'luarocks']
        for key in expected_keys:
            self.assertIn(key, result)
            self.assertIsInstance(result[key], str)
            self.assertGreater(len(result[key]), 0)

    def test_get_lua_tests_url_returns_string(self):
        """Test that get_lua_tests_url returns a string that looks like a URL."""
        result = config.get_lua_tests_url()

        self.assertIsInstance(result, str)
        self.assertTrue(result.startswith('http'))
        self.assertIn('lua', result.lower())

    def test_get_lua_tests_dir_name_returns_string(self):
        """Test that get_lua_tests_dir_name returns a reasonable directory name."""
        result = config.get_lua_tests_dir_name()

        self.assertIsInstance(result, str)
        self.assertGreater(len(result), 0)
        self.assertIn('lua', result.lower())

    def test_check_version_compatibility_returns_tuple(self):
        """Test that check_version_compatibility returns a tuple with status info."""
        result = config.check_version_compatibility()

        self.assertIsInstance(result, tuple)
        self.assertEqual(len(result), 2)
        # First element should be a boolean (status)
        self.assertIsInstance(result[0], bool)
        # Second element should be a list (messages/warnings)
        self.assertIsInstance(result[1], list)

    def test_clear_version_cache_runs_without_error(self):
        """Test that clear_version_cache runs without throwing an exception."""
        try:
            config.clear_version_cache()
            # If we get here, it didn't throw an exception
            self.assertTrue(True)
        except Exception as e:
            self.fail(f"clear_version_cache() raised {type(e).__name__}: {e}")


if __name__ == '__main__':
    unittest.main()
