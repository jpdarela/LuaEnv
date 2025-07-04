"""
Integration tests for download_lua_luarocks.py script.

These tests focus on the orchestration logic, CLI argument parsing,
and integration between components without testing low-value areas
like print statements or user input prompts.
"""

import unittest
import tempfile
import shutil
import sys
from pathlib import Path
from unittest.mock import patch, MagicMock
from io import StringIO

# Add backend to path for imports
sys.path.insert(0, str(Path(__file__).parent.parent.parent / "backend"))

# Import the module to test
import download_lua_luarocks
from download_manager import DownloadManager


class TestDownloadScript(unittest.TestCase):
    """Integration tests for download_lua_luarocks.py script."""

    def setUp(self):
        """Set up test environment."""
        self.temp_dir = tempfile.mkdtemp()
        self.original_argv = sys.argv.copy()

    def tearDown(self):
        """Clean up test environment."""
        shutil.rmtree(self.temp_dir, ignore_errors=True)
        sys.argv = self.original_argv

    # ==========================================
    # CLI Argument Parsing Tests
    # ==========================================

    @patch('download_lua_luarocks.DownloadManager')
    @patch('builtins.print')
    def test_help_argument(self, mock_print, mock_dm_class):
        """Test --help argument displays help and exits."""
        sys.argv = ['download_lua_luarocks.py', '--help']

        with self.assertRaises(SystemExit) as cm:
            download_lua_luarocks.main()

        self.assertEqual(cm.exception.code, 0)
        # Verify help content was printed
        mock_print.assert_called()
        help_calls = [call for call in mock_print.call_args_list if 'Usage:' in str(call)]
        self.assertTrue(len(help_calls) > 0, "Help usage information should be displayed")

    @patch('download_lua_luarocks.DownloadManager')
    @patch('builtins.print')
    def test_config_argument(self, mock_print, mock_dm_class):
        """Test --config argument shows configuration and exits."""
        sys.argv = ['download_lua_luarocks.py', '--config']

        with self.assertRaises(SystemExit) as cm:
            download_lua_luarocks.main()

        self.assertEqual(cm.exception.code, 0)
        # Verify configuration was printed
        mock_print.assert_called()
        config_calls = [call for call in mock_print.call_args_list if 'Configuration:' in str(call)]
        self.assertTrue(len(config_calls) > 0, "Configuration information should be displayed")

    @patch('download_lua_luarocks.DownloadManager')
    def test_list_argument_no_downloads(self, mock_dm_class):
        """Test --list argument when no downloads exist."""
        # Mock DownloadManager instance
        mock_dm = MagicMock()
        mock_dm.list_downloaded_versions.return_value = []
        mock_dm_class.return_value = mock_dm

        sys.argv = ['download_lua_luarocks.py', '--list']

        with patch('builtins.print') as mock_print:
            with self.assertRaises(SystemExit) as cm:
                download_lua_luarocks.main()

        self.assertEqual(cm.exception.code, 0)
        mock_dm.list_downloaded_versions.assert_called_once()

    @patch('download_lua_luarocks.DownloadManager')
    def test_list_argument_with_downloads(self, mock_dm_class):
        """Test --list argument when downloads exist."""
        # Mock DownloadManager instance with sample data
        mock_dm = MagicMock()
        mock_dm.list_downloaded_versions.return_value = [
            {
                'key': 'lua-5.4.8_luarocks-3.12.2',
                'created': '2025-01-01T00:00:00',
                'formatted_size': '10.5 MB',
                'file_count': 3
            }
        ]
        mock_dm.get_registry_info.return_value = {
            'combination_count': 1,
            'lua_versions': 1,
            'luarocks_versions': 1,
            'formatted_size': '10.5 MB'
        }
        mock_dm_class.return_value = mock_dm

        sys.argv = ['download_lua_luarocks.py', '--list']

        with patch('builtins.print') as mock_print:
            with self.assertRaises(SystemExit) as cm:
                download_lua_luarocks.main()

        self.assertEqual(cm.exception.code, 0)
        mock_dm.list_downloaded_versions.assert_called_once()
        mock_dm.get_registry_info.assert_called_once()

    # ==========================================
    # Download Orchestration Tests
    # ==========================================

    @patch('download_lua_luarocks.DownloadManager')
    @patch('download_lua_luarocks.validate_current_configuration')
    @patch('download_lua_luarocks.check_version_compatibility')
    def test_download_function_already_downloaded(self, mock_check_compat, mock_validate, mock_dm_class):
        """Test download() function when version is already downloaded."""
        # Mock version compatibility check
        mock_check_compat.return_value = (True, [])

        # Mock URL validation
        mock_validate.return_value = (True, {})

        # Mock DownloadManager
        mock_dm = MagicMock()
        mock_dm.is_downloaded.return_value = True
        mock_dm_class.return_value = mock_dm

        with patch('builtins.print'):
            result = download_lua_luarocks.download()

        # Verify the download manager was returned
        self.assertEqual(result, mock_dm)

        # Verify checks were called
        mock_check_compat.assert_called_once()
        mock_dm.is_downloaded.assert_called_once()

        # Verify download_version was NOT called (already downloaded)
        mock_dm.download_version.assert_not_called()

    @patch('download_lua_luarocks.DownloadManager')
    @patch('download_lua_luarocks.validate_current_configuration')
    @patch('download_lua_luarocks.check_version_compatibility')
    @patch('download_lua_luarocks.get_lua_url', return_value='http://test.com/lua.tar.gz')
    @patch('download_lua_luarocks.get_luarocks_url', return_value='http://test.com/luarocks.zip')
    @patch('download_lua_luarocks.get_lua_tests_url', return_value='http://test.com/tests.tar.gz')
    @patch('download_lua_luarocks.get_download_filenames', return_value={'lua': 'lua.tar.gz', 'luarocks': 'luarocks.zip', 'lua_tests': 'tests.tar.gz'})
    def test_download_function_new_download_success(self, mock_filenames, mock_tests_url,
                                                    mock_luarocks_url, mock_lua_url,
                                                    mock_check_compat, mock_validate, mock_dm_class):
        """Test download() function for new successful download."""
        # Mock version compatibility check
        mock_check_compat.return_value = (True, [])

        # Mock URL validation
        mock_validate.return_value = (True, {})

        # Mock DownloadManager
        mock_dm = MagicMock()
        mock_dm.is_downloaded.return_value = False
        mock_dm.download_version.return_value = (True, "Download successful")
        mock_dm_class.return_value = mock_dm

        with patch('builtins.print'):
            result = download_lua_luarocks.download()

        # Verify the download manager was returned
        self.assertEqual(result, mock_dm)

        # Verify download was attempted
        mock_dm.download_version.assert_called_once()

        # Verify URLs were gathered
        mock_lua_url.assert_called_once()
        mock_luarocks_url.assert_called_once()
        mock_tests_url.assert_called_once()
        mock_filenames.assert_called_once()

    @patch('download_lua_luarocks.DownloadManager')
    @patch('download_lua_luarocks.validate_current_configuration')
    @patch('download_lua_luarocks.check_version_compatibility')
    def test_download_function_version_compatibility_error(self, mock_check_compat, mock_validate, mock_dm_class):
        """Test download() function when version compatibility fails."""
        # Mock version compatibility failure
        mock_check_compat.return_value = (False, ["Version incompatible"])

        # Mock user input to cancel
        with patch('builtins.input', return_value='n'):
            with patch('builtins.print'):
                with self.assertRaises(SystemExit) as cm:
                    download_lua_luarocks.download()

        self.assertEqual(cm.exception.code, 1)
        mock_check_compat.assert_called_once()

    @patch('download_lua_luarocks.DownloadManager')
    @patch('download_lua_luarocks.validate_current_configuration')
    @patch('download_lua_luarocks.check_version_compatibility')
    def test_download_function_url_validation_error(self, mock_check_compat, mock_validate, mock_dm_class):
        """Test download() function when URL validation fails."""
        # Mock version compatibility success
        mock_check_compat.return_value = (True, [])

        # Mock DownloadManager
        mock_dm = MagicMock()
        mock_dm.is_downloaded.return_value = False
        mock_dm_class.return_value = mock_dm

        # Mock URL validation failure
        mock_validate.return_value = (False, {
            'lua': {'exists': False, 'message': 'URL not found'}
        })

        # Mock user input to cancel
        with patch('builtins.input', return_value='n'):
            with patch('builtins.print'):
                with self.assertRaises(SystemExit) as cm:
                    download_lua_luarocks.download()

        self.assertEqual(cm.exception.code, 1)
        mock_validate.assert_called_once()

    # ==========================================
    # Extraction Callback Tests
    # ==========================================

    @patch('download_lua_luarocks.ensure_extracted_folder')
    @patch('download_lua_luarocks.get_lua_dir_name', return_value='lua-5.4.8')
    @patch('download_lua_luarocks.get_lua_tests_dir_name', return_value='lua-5.4.8-tests')
    @patch('download_lua_luarocks.get_luarocks_dir_name', return_value='luarocks-3.12.2')
    def test_create_extraction_callback_lua_detection(self, mock_luarocks_name, mock_tests_name,
                                                      mock_lua_name, mock_ensure_folder):
        """Test extraction callback correctly identifies file types."""
        mock_extracted_folder = Path('/tmp/extracted')
        mock_ensure_folder.return_value = mock_extracted_folder

        callback = download_lua_luarocks.create_extraction_callback()

        # Test Lua source detection
        result = callback(Path('/tmp/source'), 'lua-5.4.8.tar.gz')
        expected = mock_extracted_folder / 'lua-5.4.8'
        self.assertEqual(result, expected)

        # Test Lua tests detection
        result = callback(Path('/tmp/source'), 'lua-5.4.8-tests.tar.gz')
        expected = mock_extracted_folder / 'lua-5.4.8-tests'
        self.assertEqual(result, expected)

        # Test LuaRocks detection
        result = callback(Path('/tmp/source'), 'luarocks-3.12.2-win64.zip')
        expected = mock_extracted_folder / 'luarocks-3.12.2'
        self.assertEqual(result, expected)

        # Test unknown file type
        result = callback(Path('/tmp/source'), 'unknown-file.txt')
        self.assertIsNone(result)

    # ==========================================
    # Error Handling Tests
    # ==========================================

    @patch('download_lua_luarocks.DownloadManager')
    @patch('download_lua_luarocks.validate_current_configuration')
    @patch('download_lua_luarocks.check_version_compatibility')
    @patch('download_lua_luarocks.get_lua_url', return_value='http://test.com/lua.tar.gz')
    @patch('download_lua_luarocks.get_luarocks_url', return_value='http://test.com/luarocks.zip')
    @patch('download_lua_luarocks.get_lua_tests_url', return_value='http://test.com/tests.tar.gz')
    @patch('download_lua_luarocks.get_download_filenames', return_value={'lua': 'lua.tar.gz'})
    def test_download_function_download_failure(self, mock_filenames, mock_tests_url,
                                                mock_luarocks_url, mock_lua_url,
                                                mock_check_compat, mock_validate, mock_dm_class):
        """Test download() function when download fails."""
        # Mock version compatibility success
        mock_check_compat.return_value = (True, [])

        # Mock URL validation success
        mock_validate.return_value = (True, {})

        # Mock DownloadManager with download failure
        mock_dm = MagicMock()
        mock_dm.is_downloaded.return_value = False
        mock_dm.download_version.return_value = (False, "Network error")
        mock_dm_class.return_value = mock_dm

        with patch('builtins.print'):
            with self.assertRaises(SystemExit) as cm:
                download_lua_luarocks.download()

        self.assertEqual(cm.exception.code, 1)
        mock_dm.download_version.assert_called_once()

    # ==========================================
    # Additional CLI Options Tests
    # ==========================================

    @patch('download_lua_luarocks.DownloadManager')
    @patch('builtins.print')
    def test_cleanup_argument_default(self, mock_print, mock_dm_class):
        """Test --cleanup argument with default behavior (keep 3)."""
        mock_dm = MagicMock()
        mock_dm.cleanup_old_versions.return_value = (True, "Cleaned up 2 old versions")
        mock_dm_class.return_value = mock_dm

        sys.argv = ['download_lua_luarocks.py', '--cleanup']

        with self.assertRaises(SystemExit) as cm:
            download_lua_luarocks.main()

        self.assertEqual(cm.exception.code, 0)
        mock_dm.cleanup_old_versions.assert_called_once_with(keep_latest=3)

    @patch('download_lua_luarocks.DownloadManager')
    @patch('builtins.print')
    def test_cleanup_argument_all(self, mock_print, mock_dm_class):
        """Test --cleanup --all argument (keep 1)."""
        mock_dm = MagicMock()
        mock_dm.cleanup_old_versions.return_value = (True, "Cleaned up 5 old versions")
        mock_dm_class.return_value = mock_dm

        sys.argv = ['download_lua_luarocks.py', '--cleanup', '--all']

        with self.assertRaises(SystemExit) as cm:
            download_lua_luarocks.main()

        self.assertEqual(cm.exception.code, 0)
        mock_dm.cleanup_old_versions.assert_called_once_with(keep_latest=1)

    @patch('download_lua_luarocks.DownloadManager')
    @patch('builtins.print')
    def test_cleanup_argument_failure(self, mock_print, mock_dm_class):
        """Test --cleanup argument when cleanup fails."""
        mock_dm = MagicMock()
        mock_dm.cleanup_old_versions.return_value = (False, "Failed to clean up")
        mock_dm_class.return_value = mock_dm

        sys.argv = ['download_lua_luarocks.py', '--cleanup']

        with self.assertRaises(SystemExit) as cm:
            download_lua_luarocks.main()

        self.assertEqual(cm.exception.code, 1)

    @patch('download_lua_luarocks.DownloadManager')
    @patch('builtins.print')
    def test_registry_info_argument(self, mock_print, mock_dm_class):
        """Test --registry-info argument."""
        mock_dm = MagicMock()
        mock_dm.get_registry_info.return_value = {
            'registry_file': '/path/to/registry.json',
            'base_dir': '/downloads',
            'lua_dir': '/downloads/lua',
            'luarocks_dir': '/downloads/luarocks',
            'combination_count': 2,
            'lua_versions': 1,
            'luarocks_versions': 2,
            'formatted_size': '15.2 MB'
        }
        mock_dm_class.return_value = mock_dm

        sys.argv = ['download_lua_luarocks.py', '--registry-info']

        with self.assertRaises(SystemExit) as cm:
            download_lua_luarocks.main()

        self.assertEqual(cm.exception.code, 0)
        mock_dm.get_registry_info.assert_called_once()

    @patch('download_lua_luarocks.list_extracted_contents')
    @patch('builtins.print')
    def test_list_extracted_argument(self, mock_print, mock_list):
        """Test --list-extracted argument."""
        sys.argv = ['download_lua_luarocks.py', '--list-extracted']

        with self.assertRaises(SystemExit) as cm:
            download_lua_luarocks.main()

        self.assertEqual(cm.exception.code, 0)
        mock_list.assert_called_once()

    @patch('download_lua_luarocks.clean_extracted_folder')
    @patch('builtins.print')
    def test_clean_extracted_argument(self, mock_print, mock_clean):
        """Test --clean-extracted argument with confirmation."""
        mock_clean.return_value = True
        sys.argv = ['download_lua_luarocks.py', '--clean-extracted']

        with self.assertRaises(SystemExit) as cm:
            download_lua_luarocks.main()

        self.assertEqual(cm.exception.code, 0)
        mock_clean.assert_called_once_with(confirm=True)

    @patch('download_lua_luarocks.clean_extracted_folder')
    @patch('builtins.print')
    def test_clean_extracted_force_argument(self, mock_print, mock_clean):
        """Test --clean-extracted --force argument without confirmation."""
        mock_clean.return_value = True
        sys.argv = ['download_lua_luarocks.py', '--clean-extracted', '--force']

        with self.assertRaises(SystemExit) as cm:
            download_lua_luarocks.main()

        self.assertEqual(cm.exception.code, 0)
        mock_clean.assert_called_once_with(confirm=False)

    @patch('download_lua_luarocks.clean_extracted_folder')
    @patch('builtins.print')
    def test_clean_extracted_failure(self, mock_print, mock_clean):
        """Test --clean-extracted when cleaning fails."""
        mock_clean.return_value = False
        sys.argv = ['download_lua_luarocks.py', '--clean-extracted', '--force']

        with self.assertRaises(SystemExit) as cm:
            download_lua_luarocks.main()

        self.assertEqual(cm.exception.code, 1)

    # ==========================================
    # Re-extraction Tests
    # ==========================================

    @patch('download_lua_luarocks.DownloadManager')
    @patch('download_lua_luarocks.clean_extracted_folder')
    @patch('download_lua_luarocks.ensure_extracted_folder')
    @patch('download_lua_luarocks.get_lua_dir_name', return_value='lua-5.4.8')
    @patch('download_lua_luarocks.get_lua_tests_dir_name', return_value='lua-5.4.8-tests')
    @patch('download_lua_luarocks.get_luarocks_dir_name', return_value='luarocks-3.12.2')
    @patch('builtins.print')
    def test_re_extract_success(self, mock_print, mock_luarocks_name, mock_tests_name,
                               mock_lua_name, mock_ensure, mock_clean, mock_dm_class):
        """Test --re-extract argument with successful re-extraction."""
        mock_dm = MagicMock()
        mock_dm.is_downloaded.return_value = True
        mock_dm.extract_version.return_value = (True, "Extraction successful")
        mock_dm_class.return_value = mock_dm

        mock_ensure.return_value = Path('/extracted')
        mock_clean.return_value = True

        sys.argv = ['download_lua_luarocks.py', '--re-extract']

        with self.assertRaises(SystemExit) as cm:
            download_lua_luarocks.main()

        self.assertEqual(cm.exception.code, 0)
        mock_dm.is_downloaded.assert_called_once()
        mock_clean.assert_called_once_with(confirm=False)
        mock_dm.extract_version.assert_called_once()

    @patch('download_lua_luarocks.DownloadManager')
    @patch('builtins.print')
    def test_re_extract_not_downloaded(self, mock_print, mock_dm_class):
        """Test --re-extract when version is not downloaded."""
        mock_dm = MagicMock()
        mock_dm.is_downloaded.return_value = False
        mock_dm_class.return_value = mock_dm

        sys.argv = ['download_lua_luarocks.py', '--re-extract']

        with self.assertRaises(SystemExit) as cm:
            download_lua_luarocks.main()

        self.assertEqual(cm.exception.code, 1)
        mock_dm.is_downloaded.assert_called_once()
        mock_dm.extract_version.assert_not_called()

    @patch('download_lua_luarocks.DownloadManager')
    @patch('download_lua_luarocks.clean_extracted_folder')
    @patch('builtins.print')
    def test_re_extract_failure(self, mock_print, mock_clean, mock_dm_class):
        """Test --re-extract when extraction fails."""
        mock_dm = MagicMock()
        mock_dm.is_downloaded.return_value = True
        mock_dm.extract_version.return_value = (False, "Extraction failed")
        mock_dm_class.return_value = mock_dm

        mock_clean.return_value = True

        sys.argv = ['download_lua_luarocks.py', '--re-extract']

        with self.assertRaises(SystemExit) as cm:
            download_lua_luarocks.main()

        self.assertEqual(cm.exception.code, 1)
        mock_dm.extract_version.assert_called_once()

    # ==========================================
    # Main Function Flow Tests
    # ==========================================

    @patch('download_lua_luarocks.download')
    @patch('download_lua_luarocks.create_extraction_callback')
    @patch('download_lua_luarocks.ensure_extracted_folder')
    @patch('download_lua_luarocks.get_lua_dir_name', return_value='lua-5.4.8')
    @patch('download_lua_luarocks.get_lua_tests_dir_name', return_value='lua-5.4.8-tests')
    @patch('download_lua_luarocks.get_luarocks_dir_name', return_value='luarocks-3.12.2')
    @patch('builtins.print')
    def test_main_function_success(self, mock_print, mock_luarocks_name, mock_tests_name,
                                  mock_lua_name, mock_ensure, mock_callback_func, mock_download):
        """Test main function execution with successful download and extraction."""
        # Mock successful download
        mock_dm = MagicMock()
        mock_dm.extract_version.return_value = (True, "Extraction successful")
        mock_download.return_value = mock_dm

        # Mock callback creation
        mock_callback = MagicMock()
        mock_callback_func.return_value = mock_callback

        # Mock extracted folder
        mock_ensure.return_value = Path('/extracted')

        # Set empty argv to trigger main function
        sys.argv = ['download_lua_luarocks.py']

        # This should not raise SystemExit in the main flow
        download_lua_luarocks.main()

        # Verify the flow
        mock_download.assert_called_once()
        mock_callback_func.assert_called_once()
        mock_dm.extract_version.assert_called_once()

    @patch('download_lua_luarocks.download')
    @patch('download_lua_luarocks.create_extraction_callback')
    @patch('builtins.print')
    def test_main_function_extraction_failure(self, mock_print, mock_callback_func, mock_download):
        """Test main function execution when extraction fails."""
        # Mock successful download but failed extraction
        mock_dm = MagicMock()
        mock_dm.extract_version.return_value = (False, "Extraction failed")
        mock_download.return_value = mock_dm

        # Mock callback creation
        mock_callback = MagicMock()
        mock_callback_func.return_value = mock_callback

        # Set empty argv to trigger main function
        sys.argv = ['download_lua_luarocks.py']

        with self.assertRaises(SystemExit) as cm:
            download_lua_luarocks.main()

        self.assertEqual(cm.exception.code, 1)
        mock_dm.extract_version.assert_called_once()

    # ==========================================
    # User Input Tests
    # ==========================================

    @patch('download_lua_luarocks.DownloadManager')
    @patch('download_lua_luarocks.validate_current_configuration')
    @patch('download_lua_luarocks.check_version_compatibility')
    def test_download_function_compatibility_warning_proceed(self, mock_check_compat, mock_validate, mock_dm_class):
        """Test download() function when user chooses to proceed despite warnings."""
        # Mock version compatibility with warnings but still compatible
        mock_check_compat.return_value = (True, ["Minor version mismatch"])

        # Mock URL validation success
        mock_validate.return_value = (True, {})

        # Mock DownloadManager
        mock_dm = MagicMock()
        mock_dm.is_downloaded.return_value = True
        mock_dm_class.return_value = mock_dm

        with patch('builtins.input', return_value='y'):
            with patch('builtins.print'):
                result = download_lua_luarocks.download()

        # Should complete successfully
        self.assertEqual(result, mock_dm)
        mock_check_compat.assert_called_once()

    @patch('download_lua_luarocks.DownloadManager')
    @patch('download_lua_luarocks.validate_current_configuration')
    @patch('download_lua_luarocks.check_version_compatibility')
    def test_download_function_url_validation_proceed(self, mock_check_compat, mock_validate, mock_dm_class):
        """Test download() function when user chooses to proceed despite URL validation errors."""
        # Mock version compatibility success
        mock_check_compat.return_value = (True, [])

        # Mock URL validation failure
        mock_validate.return_value = (False, {
            'lua': {'exists': False, 'message': 'URL not found'}
        })

        # Mock DownloadManager
        mock_dm = MagicMock()
        mock_dm.is_downloaded.return_value = False  # Not downloaded, so validation will be called
        mock_dm.download_version.return_value = (True, "Download successful")  # Mock the download
        mock_dm_class.return_value = mock_dm

        with patch('builtins.input', return_value='y'):
            with patch('builtins.print'):
                result = download_lua_luarocks.download()

        # Should complete successfully despite URL issues
        self.assertEqual(result, mock_dm)
        mock_validate.assert_called_once()


if __name__ == '__main__':
    unittest.main(verbosity=2)
