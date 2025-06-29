"""
Tests for download_lua_luarocks.py - testing download and extraction functions.

This file tests the download and extraction functions in the project directory,
using the same approach that users would follow.
"""

import unittest
import sys
import os
from pathlib import Path
from unittest.mock import patch

# Add parent directory to path so we can import the download module
sys.path.insert(0, str(Path(__file__).parent.parent))

import download_lua_luarocks
import config


class TestDownloadBootstrap(unittest.TestCase):
    """Bootstrap test that ensures all required files are downloaded for subsequent tests."""

    def setUp(self):
        """Set up test environment."""
        # Work in the project root directory
        self.project_root = Path(__file__).parent.parent

        # Save original working directory
        self.original_cwd = os.getcwd()

        # Change to project root
        os.chdir(self.project_root)

        print(f"\n[BOOTSTRAP] Starting bootstrap test in project directory: {self.project_root}")

    def tearDown(self):
        """Clean up test environment."""
        # Restore original working directory
        os.chdir(self.original_cwd)

    def test_aaa_bootstrap_download_and_extract_all_files(self):
        """
        BOOTSTRAP TEST: Download and extract all required files for subsequent tests.

        This test MUST run first (hence the 'aaa_' prefix) and ensures that:
        1. All required files are downloaded (Lua, LuaRocks, Lua tests)
        2. All files are extracted to the correct directories
        3. Directories have the expected content

        If this test fails, subsequent tests will be skipped with clear error messages.
        """
        print("\n[BOOTSTRAP] Ensuring all required files are downloaded and extracted...")

        # Step 1: Check if files already exist and are valid
        downloads_dir = Path("downloads")
        filenames = config.get_download_filenames()

        lua_file = downloads_dir / filenames['lua']
        luarocks_file = downloads_dir / filenames['luarocks']
        lua_tests_file = downloads_dir / filenames['lua_tests']

        lua_dir = Path(config.get_lua_dir_name())
        luarocks_dir = Path(config.get_luarocks_dir_name())
        lua_tests_dir = Path(config.get_lua_tests_dir_name())

        # Check if everything already exists and looks good
        files_exist = all(f.exists() and f.stat().st_size > 100*1024 for f in [lua_file, luarocks_file, lua_tests_file])
        dirs_exist = all(d.exists() and len(list(d.iterdir())) > 0 for d in [lua_dir, luarocks_dir, lua_tests_dir])

        if files_exist and dirs_exist:
            print("[BOOTSTRAP] Files and directories already exist and appear valid")
            # Quick verification
            lua_src = lua_dir / "src"
            if not (lua_src.exists() and len(list(lua_src.iterdir())) > 5):
                print("[WARNING] Lua src directory looks incomplete, will re-extract")
                dirs_exist = False
            else:
                print(f"[BOOTSTRAP] [+] All required files are ready:")
                print(f"  Downloads: {downloads_dir} (3 files)")
                print(f"  Lua: {lua_dir} ({len(list(lua_dir.iterdir()))} items)")
                print(f"  Lua src: {lua_src} ({len(list(lua_src.iterdir()))} files)")
                print(f"  LuaRocks: {luarocks_dir} ({len(list(luarocks_dir.iterdir()))} items)")
                print(f"  Lua Tests: {lua_tests_dir} ({len(list(lua_tests_dir.iterdir()))} items)")
                print("[BOOTSTRAP] [+] Bootstrap complete - subsequent tests can run safely")
                return        # Step 2: Download all files if needed
        if not files_exist:
            try:
                print("[BOOTSTRAP] [*] Downloading Lua and LuaRocks files...")
                download_lua_luarocks.download()
                print("[BOOTSTRAP] [+] Download completed successfully")
            except Exception as e:
                print(f"[BOOTSTRAP] [X] CRITICAL FAILURE: Download failed: {e}")
                print("[BOOTSTRAP] [X] This means either:")
                print("[BOOTSTRAP] [X]   1. No internet connection")
                print("[BOOTSTRAP] [X]   2. Download URLs are invalid")
                print("[BOOTSTRAP] [X]   3. Server is unavailable")
                print("[BOOTSTRAP] [X] Subsequent tests WILL FAIL!")
                self.fail(f"BOOTSTRAP FAILURE: Failed to download required files: {e}")

            # Verify downloaded files exist and have reasonable sizes
            self.assertTrue(lua_file.exists(), f"BOOTSTRAP FAILURE: Lua file not found after download: {lua_file}")
            self.assertTrue(luarocks_file.exists(), f"BOOTSTRAP FAILURE: LuaRocks file not found after download: {luarocks_file}")
            self.assertTrue(lua_tests_file.exists(), f"BOOTSTRAP FAILURE: Lua tests file not found after download: {lua_tests_file}")

            # Verify reasonable file sizes
            lua_size = lua_file.stat().st_size
            luarocks_size = luarocks_file.stat().st_size
            lua_tests_size = lua_tests_file.stat().st_size

            self.assertGreater(lua_size, 300 * 1024, f"BOOTSTRAP FAILURE: Lua file too small: {lua_size} bytes")
            self.assertGreater(luarocks_size, 1024 * 1024, f"BOOTSTRAP FAILURE: LuaRocks file too small: {luarocks_size} bytes")
            self.assertGreater(lua_tests_size, 100 * 1024, f"BOOTSTRAP FAILURE: Lua tests file too small: {lua_tests_size} bytes")

            print(f"[BOOTSTRAP] [+] Downloaded files verified:")
            print(f"  Lua: {lua_file} ({lua_size:,} bytes)")
            print(f"  LuaRocks: {luarocks_file} ({luarocks_size:,} bytes)")
            print(f"  Lua Tests: {lua_tests_file} ({lua_tests_size:,} bytes)")

        # Step 3: Extract all files if needed
        if not dirs_exist:
            try:
                print("[BOOTSTRAP] [*] Extracting downloaded files...")

                if not lua_dir.exists() or len(list(lua_dir.iterdir())) == 0:
                    print(f"  [*] Extracting {lua_file}...")
                    download_lua_luarocks.extract_file(str(lua_file))

                if not luarocks_dir.exists() or len(list(luarocks_dir.iterdir())) == 0:
                    print(f"  [*] Extracting {luarocks_file}...")
                    download_lua_luarocks.extract_file(str(luarocks_file))

                if not lua_tests_dir.exists() or len(list(lua_tests_dir.iterdir())) == 0:
                    print(f"  [*] Extracting {lua_tests_file}...")
                    download_lua_luarocks.extract_file(str(lua_tests_file))

                print("[BOOTSTRAP] [+] Extraction completed successfully")

            except Exception as e:
                print(f"[BOOTSTRAP] [X] CRITICAL FAILURE: Extraction failed: {e}")
                print("[BOOTSTRAP] [X] This means either:")
                print("[BOOTSTRAP] [X]   1. Downloaded files are corrupted")
                print("[BOOTSTRAP] [X]   2. File extraction libraries not available")
                print("[BOOTSTRAP] [X]   3. Disk space or permission issues")
                print("[BOOTSTRAP] [X] Subsequent tests WILL FAIL!")
                self.fail(f"BOOTSTRAP FAILURE: Failed to extract downloaded files: {e}")

        # Step 4: Verify extracted directories exist and have content
        self.assertTrue(lua_dir.exists(), f"BOOTSTRAP FAILURE: Lua directory not found after extraction: {lua_dir}")
        self.assertTrue(luarocks_dir.exists(), f"BOOTSTRAP FAILURE: LuaRocks directory not found after extraction: {luarocks_dir}")
        self.assertTrue(lua_tests_dir.exists(), f"BOOTSTRAP FAILURE: Lua tests directory not found after extraction: {lua_tests_dir}")

        # Check directories have content
        self.assertGreater(len(list(lua_dir.iterdir())), 0, "BOOTSTRAP FAILURE: Lua directory is empty after extraction")
        self.assertGreater(len(list(luarocks_dir.iterdir())), 0, "BOOTSTRAP FAILURE: LuaRocks directory is empty after extraction")
        self.assertGreater(len(list(lua_tests_dir.iterdir())), 0, "BOOTSTRAP FAILURE: Lua tests directory is empty after extraction")

        # Check that the critical Lua src directory exists
        lua_src = lua_dir / "src"
        self.assertTrue(lua_src.exists(), f"BOOTSTRAP FAILURE: Lua src directory not found: {lua_src}")
        self.assertGreater(len(list(lua_src.iterdir())), 5, "BOOTSTRAP FAILURE: Lua src directory has too few files")

        print(f"[BOOTSTRAP] [+] Extracted directories verified with content:")
        print(f"  Lua: {lua_dir} ({len(list(lua_dir.iterdir()))} items)")
        print(f"  Lua src: {lua_src} ({len(list(lua_src.iterdir()))} files)")
        print(f"  LuaRocks: {luarocks_dir} ({len(list(luarocks_dir.iterdir()))} items)")
        print(f"  Lua Tests: {lua_tests_dir} ({len(list(lua_tests_dir.iterdir()))} items)")

        print("\n[BOOTSTRAP] [+] SUCCESS! All required files downloaded and extracted successfully!")
        print("[BOOTSTRAP] [+] Subsequent tests can now run safely.")


class TestDownloadFunctions(unittest.TestCase):
    """Test download-related functions without actually downloading large files."""

    def setUp(self):
        """Set up test environment."""
        # Work in the project root directory
        self.project_root = Path(__file__).parent.parent

        # Save original working directory
        self.original_cwd = os.getcwd()

        # Change to project root
        os.chdir(self.project_root)

    def tearDown(self):
        """Clean up test environment."""
        # Restore original working directory
        os.chdir(self.original_cwd)

    def test_download_file_function_exists(self):
        """Test that download_file function exists and is callable."""
        self.assertTrue(hasattr(download_lua_luarocks, 'download_file'))
        self.assertTrue(callable(download_lua_luarocks.download_file))

    def test_download_function_exists(self):
        """Test that download function exists and is callable."""
        self.assertTrue(hasattr(download_lua_luarocks, 'download'))
        self.assertTrue(callable(download_lua_luarocks.download))

    def test_extract_file_function_exists(self):
        """Test that extract_file function exists and is callable."""
        self.assertTrue(hasattr(download_lua_luarocks, 'extract_file'))
        self.assertTrue(callable(download_lua_luarocks.extract_file))

    @patch('download_lua_luarocks.urllib.request.urlretrieve')
    def test_download_file_basic(self, mock_urlretrieve):
        """Test download_file function with mocked download."""
        test_url = "https://example.com/test.tar.gz"
        test_dest = "test_file.tar.gz"

        # Call the function
        download_lua_luarocks.download_file(test_url, test_dest)

        # Verify urlretrieve was called with correct arguments
        mock_urlretrieve.assert_called_once_with(test_url, test_dest)

    def test_config_integration(self):
        """Test that we can get URLs from config for download testing."""
        # These tests verify our config integration works
        lua_url = config.get_lua_url()
        luarocks_url = config.get_luarocks_url()
        lua_tests_url = config.get_lua_tests_url()

        self.assertIsInstance(lua_url, str)
        self.assertIsInstance(luarocks_url, str)
        self.assertIsInstance(lua_tests_url, str)

        self.assertTrue(lua_url.startswith('http'))
        self.assertTrue(luarocks_url.startswith('http'))
        self.assertTrue(lua_tests_url.startswith('http'))


class TestDownloadIntegration(unittest.TestCase):
    """Integration tests that actually download small test files."""

    def setUp(self):
        """Set up test environment."""
        # Work in the project root directory
        self.project_root = Path(__file__).parent.parent

        # Save original working directory
        self.original_cwd = os.getcwd()

        # Change to project root
        os.chdir(self.project_root)

    def tearDown(self):
        """Clean up test environment."""
        # Restore original working directory
        os.chdir(self.original_cwd)

    def test_download_file_small_real_file(self):
        """Test downloading a small real file (GitHub raw file)."""
        # Use a small text file from a public repository
        test_url = "https://raw.githubusercontent.com/github/gitignore/main/Python.gitignore"
        test_dest = "test_python.gitignore"

        try:
            download_lua_luarocks.download_file(test_url, test_dest)

            # Verify file was downloaded
            downloaded_file = Path(test_dest)
            self.assertTrue(downloaded_file.exists())
            self.assertGreater(downloaded_file.stat().st_size, 0)

            # Clean up
            downloaded_file.unlink()

        except Exception as e:
            self.skipTest(f"Network not available or URL changed: {e}")


class TestDownloadReal(unittest.TestCase):
    """Real download tests that work in the project directory."""

    def setUp(self):
        """Set up test environment."""
        # Work in the project root directory
        self.project_root = Path(__file__).parent.parent

        # Save original working directory
        self.original_cwd = os.getcwd()

        # Change to project root
        os.chdir(self.project_root)

        print(f"\n[INFO] Testing in project directory: {self.project_root}")

    def tearDown(self):
        """Clean up test environment."""
        # Restore original working directory
        os.chdir(self.original_cwd)

    def test_download_lua_and_luarocks_real(self):
        """Download real Lua and LuaRocks files to the project directory.

        This test downloads actual files that will be used by subsequent tests.
        It's designed to be run once and then the files are reused.
        """
        print("\n[INFO] Starting real download test in project directory...")

        # Check if files already exist
        downloads_dir = Path("downloads")
        filenames = config.get_download_filenames()

        lua_file = downloads_dir / filenames['lua']
        luarocks_file = downloads_dir / filenames['luarocks']
        lua_tests_file = downloads_dir / filenames['lua_tests']

        files_exist = all(f.exists() for f in [lua_file, luarocks_file, lua_tests_file])

        if files_exist:
            print("[INFO] Files already exist, skipping download")
            # Just verify the files are reasonable sizes
            lua_size = lua_file.stat().st_size
            luarocks_size = luarocks_file.stat().st_size
            lua_tests_size = lua_tests_file.stat().st_size

            print(f"[INFO] Existing files:")
            print(f"  Lua: {lua_file} ({lua_size:,} bytes)")
            print(f"  LuaRocks: {luarocks_file} ({luarocks_size:,} bytes)")
            print(f"  Lua Tests: {lua_tests_file} ({lua_tests_size:,} bytes)")

            # Basic size checks
            self.assertGreater(lua_size, 300 * 1024, f"Lua file too small: {lua_size} bytes")
            self.assertGreater(luarocks_size, 1024 * 1024, f"LuaRocks file too small: {luarocks_size} bytes")
            self.assertGreater(lua_tests_size, 100 * 1024, f"Lua tests file too small: {lua_tests_size} bytes")

            return

        try:
            # Download files using the real download function
            print("[INFO] Downloading Lua and LuaRocks files...")
            download_lua_luarocks.download()

            # Verify files were downloaded
            self.assertTrue(lua_file.exists(), f"Lua file not downloaded: {lua_file}")
            self.assertTrue(luarocks_file.exists(), f"LuaRocks file not downloaded: {luarocks_file}")
            self.assertTrue(lua_tests_file.exists(), f"Lua tests file not downloaded: {lua_tests_file}")

            # Verify reasonable file sizes
            lua_size = lua_file.stat().st_size
            luarocks_size = luarocks_file.stat().st_size
            lua_tests_size = lua_tests_file.stat().st_size

            self.assertGreater(lua_size, 300 * 1024, f"Lua file too small: {lua_size} bytes")
            self.assertGreater(luarocks_size, 1024 * 1024, f"LuaRocks file too small: {luarocks_size} bytes")
            self.assertGreater(lua_tests_size, 100 * 1024, f"Lua tests file too small: {lua_tests_size} bytes")

            print(f"[SUCCESS] Downloaded files:")
            print(f"  Lua: {lua_file} ({lua_size:,} bytes)")
            print(f"  LuaRocks: {luarocks_file} ({luarocks_size:,} bytes)")
            print(f"  Lua Tests: {lua_tests_file} ({lua_tests_size:,} bytes)")

        except Exception as e:
            self.fail(f"Real download failed: {e}")

    def test_extract_downloaded_files_real(self):
        """Extract the downloaded files in the project directory.

        This test extracts the real downloaded files. It depends on
        test_download_lua_and_luarocks_real having been run first.
        """
        print("\n[INFO] Starting real extraction test in project directory...")

        # Check if download files exist
        downloads_dir = Path("downloads")
        if not downloads_dir.exists():
            self.skipTest("Downloads directory not found. Run download test first.")

        filenames = config.get_download_filenames()
        lua_file = downloads_dir / filenames['lua']
        luarocks_file = downloads_dir / filenames['luarocks']
        lua_tests_file = downloads_dir / filenames['lua_tests']

        # Check if files exist
        if not all(f.exists() for f in [lua_file, luarocks_file, lua_tests_file]):
            self.skipTest("Download files not found. Run download test first.")

        # Check if directories already exist
        lua_dir = Path(config.get_lua_dir_name())
        luarocks_dir = Path(config.get_luarocks_dir_name())
        lua_tests_dir = Path(config.get_lua_tests_dir_name())

        dirs_exist = all(d.exists() for d in [lua_dir, luarocks_dir, lua_tests_dir])

        if dirs_exist:
            print("[INFO] Directories already exist, verifying content...")

            # Verify directories have content
            self.assertTrue(lua_dir.exists(), f"Lua directory not found: {lua_dir}")
            self.assertTrue(luarocks_dir.exists(), f"LuaRocks directory not found: {luarocks_dir}")
            self.assertTrue(lua_tests_dir.exists(), f"Lua tests directory not found: {lua_tests_dir}")

            self.assertGreater(len(list(lua_dir.iterdir())), 0, "Lua directory is empty")
            self.assertGreater(len(list(luarocks_dir.iterdir())), 0, "LuaRocks directory is empty")
            self.assertGreater(len(list(lua_tests_dir.iterdir())), 0, "Lua tests directory is empty")

            print(f"[INFO] Verified existing directories:")
            print(f"  Lua: {lua_dir.absolute()}")
            print(f"  LuaRocks: {luarocks_dir.absolute()}")
            print(f"  Lua Tests: {lua_tests_dir.absolute()}")

            return

        try:
            # Extract each file
            print(f"[INFO] Extracting {lua_file}...")
            download_lua_luarocks.extract_file(str(lua_file))

            print(f"[INFO] Extracting {luarocks_file}...")
            download_lua_luarocks.extract_file(str(luarocks_file))

            print(f"[INFO] Extracting {lua_tests_file}...")
            download_lua_luarocks.extract_file(str(lua_tests_file))

            # Verify extracted directories exist
            self.assertTrue(lua_dir.exists(), f"Lua directory not found: {lua_dir}")
            self.assertTrue(luarocks_dir.exists(), f"LuaRocks directory not found: {luarocks_dir}")
            self.assertTrue(lua_tests_dir.exists(), f"Lua tests directory not found: {lua_tests_dir}")

            # Verify directories have content
            self.assertGreater(len(list(lua_dir.iterdir())), 0, "Lua directory is empty")
            self.assertGreater(len(list(luarocks_dir.iterdir())), 0, "LuaRocks directory is empty")
            self.assertGreater(len(list(lua_tests_dir.iterdir())), 0, "Lua tests directory is empty")

            print(f"[SUCCESS] Extracted directories:")
            print(f"  Lua: {lua_dir.absolute()}")
            print(f"  LuaRocks: {luarocks_dir.absolute()}")
            print(f"  Lua Tests: {lua_tests_dir.absolute()}")

        except Exception as e:
            self.fail(f"Real extraction failed: {e}")


if __name__ == '__main__':
    unittest.main(verbosity=2)
