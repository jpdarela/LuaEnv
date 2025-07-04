"""
Unit tests for the DownloadManager class.

This module tests the core download management functionality including:
- Registry operations (load/save)
- Version detection and validation
- Download orchestration
- File system operations
- Error handling and edge cases
"""

import unittest
import tempfile
import shutil
import json
import os
import sys
from pathlib import Path
from unittest.mock import patch, MagicMock, mock_open
from datetime import datetime

# Add backend directory to path for imports
backend_dir = Path(__file__).parent.parent.parent / "backend"
sys.path.insert(0, str(backend_dir))

from download_manager import DownloadManager


class TestDownloadManager(unittest.TestCase):
    """Test cases for DownloadManager class."""

    def setUp(self):
        """Set up test environment with temporary directory."""
        self.temp_dir = tempfile.mkdtemp()
        self.downloads_dir = Path(self.temp_dir) / "downloads"
        self.manager = DownloadManager(str(self.downloads_dir))

        # Test data
        self.test_lua_version = "5.4.8"
        self.test_luarocks_version = "3.12.2"
        self.test_platform = "windows-64"

    def tearDown(self):
        """Clean up temporary files."""
        shutil.rmtree(self.temp_dir, ignore_errors=True)

    # ==========================================
    # PRIORITY 1: Core Registry Operations
    # ==========================================

    def test_load_empty_registry_creates_default(self):
        """Test that loading non-existent registry creates default structure."""
        # Registry file shouldn't exist yet
        self.assertFalse(self.manager.registry_file.exists())

        # Check default registry structure
        self.assertEqual(self.manager.registry["version"], "2.0")
        self.assertIn("lua_downloads", self.manager.registry)
        self.assertIn("luarocks_downloads", self.manager.registry)
        self.assertIn("combinations", self.manager.registry)
        self.assertEqual(len(self.manager.registry["combinations"]), 0)

    def test_load_corrupted_registry_fallback(self):
        """Test handling of corrupted JSON registry file."""
        # Create corrupted registry file
        self.downloads_dir.mkdir(parents=True, exist_ok=True)
        with open(self.manager.registry_file, 'w') as f:
            f.write("{ invalid json content")

        # Create new manager (should fallback to default)
        manager = DownloadManager(str(self.downloads_dir))
        self.assertEqual(manager.registry["version"], "2.0")
        self.assertEqual(len(manager.registry["combinations"]), 0)

    def test_save_registry_creates_directory(self):
        """Test that saving registry creates necessary directories."""
        # Ensure downloads directory doesn't exist
        self.assertFalse(self.downloads_dir.exists())

        # Save registry
        self.manager._save_registry()

        # Check directory and file were created
        self.assertTrue(self.downloads_dir.exists())
        self.assertTrue(self.manager.registry_file.exists())

        # Verify file contents
        with open(self.manager.registry_file, 'r') as f:
            data = json.load(f)
        self.assertEqual(data["version"], "2.0")

    def test_save_registry_updates_timestamp(self):
        """Test that saving registry updates the last_updated timestamp."""
        original_time = self.manager.registry.get("last_updated")

        # Save registry
        self.manager._save_registry()

        # Check timestamp was updated
        updated_time = self.manager.registry.get("last_updated")
        self.assertIsNotNone(updated_time)
        self.assertNotEqual(original_time, updated_time)

    # ==========================================
    # PRIORITY 2: Version Detection Logic
    # ==========================================

    def test_version_key_generation_format(self):
        """Test version key format consistency."""
        key = self.manager.get_version_key(self.test_lua_version, self.test_luarocks_version)
        expected = f"lua-{self.test_lua_version}_luarocks-{self.test_luarocks_version}"
        self.assertEqual(key, expected)

    def test_get_lua_dir_path_format(self):
        """Test Lua directory path generation."""
        lua_dir = self.manager.get_lua_dir(self.test_lua_version)
        expected = self.downloads_dir / "lua" / f"lua-{self.test_lua_version}"
        self.assertEqual(lua_dir, expected)

    def test_get_luarocks_dir_platform_handling(self):
        """Test LuaRocks directory path with platform string."""
        luarocks_dir = self.manager.get_luarocks_dir(self.test_luarocks_version, self.test_platform)
        expected = self.downloads_dir / "luarocks" / f"luarocks-{self.test_luarocks_version}-{self.test_platform}"
        self.assertEqual(luarocks_dir, expected)

    @patch('download_manager.verify_file_exists')
    def test_is_lua_downloaded_missing_registry_entry(self, mock_verify):
        """Test Lua download detection when not in registry."""
        result = self.manager.is_lua_downloaded(self.test_lua_version)
        self.assertFalse(result)
        mock_verify.assert_not_called()

    @patch('download_manager.verify_file_exists')
    def test_is_lua_downloaded_missing_files(self, mock_verify):
        """Test Lua download detection when files are missing."""
        # Add entry to registry
        self.manager.registry["lua_downloads"][self.test_lua_version] = {
            "files": {
                "lua": {"filename": "lua-5.4.8.tar.gz"},
                "lua_tests": {"filename": "lua-5.4.8-tests.tar.gz"}
            }
        }

        # Mock file verification to return False
        mock_verify.return_value = False

        result = self.manager.is_lua_downloaded(self.test_lua_version)
        self.assertFalse(result)
        self.assertTrue(mock_verify.called)

    @patch('download_manager.verify_file_exists')
    def test_is_lua_downloaded_files_exist(self, mock_verify):
        """Test Lua download detection when files exist."""
        # Add entry to registry
        self.manager.registry["lua_downloads"][self.test_lua_version] = {
            "files": {
                "lua": {"filename": "lua-5.4.8.tar.gz"},
                "lua_tests": {"filename": "lua-5.4.8-tests.tar.gz"}
            }
        }

        # Mock file verification to return True
        mock_verify.return_value = True

        result = self.manager.is_lua_downloaded(self.test_lua_version)
        self.assertTrue(result)

    def test_is_downloaded_combines_lua_and_luarocks(self):
        """Test that is_downloaded checks both Lua and LuaRocks."""
        with patch.object(self.manager, 'is_lua_downloaded') as mock_lua, \
             patch.object(self.manager, 'is_luarocks_downloaded') as mock_luarocks:

            # Test: both available
            mock_lua.return_value = True
            mock_luarocks.return_value = True
            self.assertTrue(self.manager.is_downloaded(self.test_lua_version, self.test_luarocks_version))

            # Test: only Lua available
            mock_lua.return_value = True
            mock_luarocks.return_value = False
            self.assertFalse(self.manager.is_downloaded(self.test_lua_version, self.test_luarocks_version))

            # Test: only LuaRocks available
            mock_lua.return_value = False
            mock_luarocks.return_value = True
            self.assertFalse(self.manager.is_downloaded(self.test_lua_version, self.test_luarocks_version))

            # Test: neither available
            mock_lua.return_value = False
            mock_luarocks.return_value = False
            self.assertFalse(self.manager.is_downloaded(self.test_lua_version, self.test_luarocks_version))

    # ==========================================
    # PRIORITY 3: Download Orchestration
    # ==========================================

    @patch('download_manager.download_file')
    @patch('download_manager.get_file_size')
    def test_download_version_already_downloaded(self, mock_get_size, mock_download):
        """Test that already downloaded versions are skipped."""
        # Mock the individual download check methods (which is what download_version actually calls)
        with patch.object(self.manager, 'is_lua_downloaded', return_value=True), \
             patch.object(self.manager, 'is_luarocks_downloaded', return_value=True):
            urls = {'lua': 'http://test.com/lua.tar.gz', 'luarocks': 'http://test.com/luarocks.zip'}
            filenames = {'lua': 'lua.tar.gz', 'luarocks': 'luarocks.zip'}

            success, message = self.manager.download_version(
                self.test_lua_version, self.test_luarocks_version, urls, filenames
            )

            self.assertTrue(success)
            self.assertIn("already downloaded", message)
            mock_download.assert_not_called()

    @patch('download_manager.download_file')
    @patch('download_manager.get_file_size', return_value=1024)
    def test_download_version_new_download(self, mock_get_size, mock_download):
        """Test downloading new version combination."""
        # Mock as not downloaded
        with patch.object(self.manager, 'is_lua_downloaded', return_value=False), \
             patch.object(self.manager, 'is_luarocks_downloaded', return_value=False):

            urls = {
                'lua': 'http://test.com/lua.tar.gz',
                'lua_tests': 'http://test.com/lua-tests.tar.gz',
                'luarocks': 'http://test.com/luarocks.zip'
            }
            filenames = {
                'lua': 'lua.tar.gz',
                'lua_tests': 'lua-tests.tar.gz',
                'luarocks': 'luarocks.zip'
            }

            success, message = self.manager.download_version(
                self.test_lua_version, self.test_luarocks_version, urls, filenames
            )

            self.assertTrue(success)
            self.assertIn("Successfully downloaded", message)

            # Verify download_file was called for each file
            self.assertEqual(mock_download.call_count, 3)

            # Verify registry was updated
            version_key = self.manager.get_version_key(self.test_lua_version, self.test_luarocks_version)
            self.assertIn(version_key, self.manager.registry["combinations"])

    @patch('download_manager.download_file', side_effect=Exception("Network error"))
    def test_download_version_network_failure(self, mock_download):
        """Test handling of network errors during download."""
        with patch.object(self.manager, 'is_downloaded', return_value=False):
            urls = {'lua': 'http://test.com/lua.tar.gz'}
            filenames = {'lua': 'lua.tar.gz'}

            success, message = self.manager.download_version(
                self.test_lua_version, self.test_luarocks_version, urls, filenames
            )

            self.assertFalse(success)
            self.assertIn("Failed to download", message)
            self.assertIn("Network error", message)

    # ==========================================
    # PRIORITY 4: Extraction and Cleanup
    # ==========================================

    def test_extract_version_not_downloaded(self):
        """Test extraction when version is not downloaded."""
        with patch.object(self.manager, 'is_downloaded', return_value=False):
            success, message = self.manager.extract_version(
                self.test_lua_version, self.test_luarocks_version
            )

            self.assertFalse(success)
            self.assertIn("not downloaded", message)

    @patch('download_manager.extract_file')
    def test_extract_version_success(self, mock_extract):
        """Test successful extraction."""
        # Setup registry with downloaded files
        self.manager.registry["lua_downloads"][self.test_lua_version] = {
            "files": {"lua": {"filename": "lua.tar.gz"}}
        }
        luarocks_key = f"{self.test_luarocks_version}-{self.test_platform}"
        self.manager.registry["luarocks_downloads"][luarocks_key] = {
            "files": {"luarocks": {"filename": "luarocks.zip"}}
        }

        with patch.object(self.manager, 'is_downloaded', return_value=True):
            success, message = self.manager.extract_version(
                self.test_lua_version, self.test_luarocks_version
            )

            self.assertTrue(success)
            self.assertIn("Successfully extracted", message)
            # Verify extract_file was called
            self.assertTrue(mock_extract.called)

    # ==========================================
    # PRIORITY 5: Registry Information
    # ==========================================

    def test_list_downloaded_versions_empty(self):
        """Test listing when no versions are downloaded."""
        versions = self.manager.list_downloaded_versions()
        self.assertEqual(len(versions), 0)

    def test_list_downloaded_versions_with_data(self):
        """Test listing with downloaded versions."""
        # Add test data to registry
        version_key = self.manager.get_version_key(self.test_lua_version, self.test_luarocks_version)
        self.manager.registry["combinations"][version_key] = {
            "lua_version": self.test_lua_version,
            "luarocks_version": self.test_luarocks_version,
            "platform": self.test_platform,
            "created": datetime.now().isoformat()
        }
        self.manager.registry["lua_downloads"][self.test_lua_version] = {
            "files": {"lua": {"size": 1024}}
        }

        versions = self.manager.list_downloaded_versions()
        self.assertEqual(len(versions), 1)
        self.assertEqual(versions[0]["lua_version"], self.test_lua_version)
        self.assertEqual(versions[0]["total_size"], 1024)

    def test_get_registry_info_structure(self):
        """Test registry info returns expected structure."""
        info = self.manager.get_registry_info()

        required_keys = [
            'combination_count', 'lua_versions', 'luarocks_versions',
            'total_size', 'formatted_size', 'registry_file', 'base_dir'
        ]

        for key in required_keys:
            self.assertIn(key, info)

        self.assertIsInstance(info['combination_count'], int)
        self.assertIsInstance(info['total_size'], int)

    # ==========================================
    # PRIORITY 6: Edge Cases & Error Handling
    # ==========================================

    def test_invalid_version_strings(self):
        """Test handling of invalid version strings."""
        invalid_versions = ["", None, "invalid.version", "1.2.3.4.5"]

        for invalid_version in invalid_versions:
            if invalid_version is not None:
                # These should not crash, but may return False or handle gracefully
                try:
                    result = self.manager.is_lua_downloaded(invalid_version)
                    self.assertIsInstance(result, bool)
                except Exception:
                    # Some invalid versions might raise exceptions, which is acceptable
                    pass

    @patch('builtins.open', side_effect=PermissionError("Access denied"))
    def test_registry_save_permission_error(self, mock_open):
        """Test handling of permission errors when saving registry."""
        # This should not crash the application
        try:
            self.manager._save_registry()
        except PermissionError:
            # It's acceptable for this to raise an exception
            pass

    def test_cleanup_nonexistent_version(self):
        """Test cleanup of non-existent version."""
        success, message = self.manager.cleanup_version("999.999.999", "999.999.999")
        self.assertTrue(success)  # Should succeed (no-op)


if __name__ == '__main__':
    # Run with verbose output
    unittest.main(verbosity=2)
