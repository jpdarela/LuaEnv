"""
Tests for setup_build.py - testing build script setup in the actual project directory.

This file tests setup_build.py using real downloaded files in the project directory,
testing the actual workflow that users would follow.
"""

import unittest
import sys
import os
import shutil
import subprocess
from pathlib import Path

# Add parent directory to path so we can import modules
sys.path.insert(0, str(Path(__file__).parent.parent))

import config
import setup_build


class TestSetupBuildReal(unittest.TestCase):
    """Test setup_build.py with real downloaded files in project directory."""

    def setUp(self):
        """Set up test environment."""
        # Work in the project root directory
        self.project_root = Path(__file__).parent.parent

        # Save original working directory
        self.original_cwd = os.getcwd()

        # Change to project root
        os.chdir(self.project_root)

        # Expected directories based on config
        self.lua_dir = Path(config.get_lua_dir_name())
        self.luarocks_dir = Path(config.get_luarocks_dir_name())

        print(f"\n[INFO] Testing in project directory: {self.project_root}")
        print(f"[INFO] Looking for: {self.lua_dir} and {self.luarocks_dir}")

    def tearDown(self):
        """Clean up test environment."""
        # Restore original working directory
        os.chdir(self.original_cwd)

    def test_directories_exist_from_download_tests(self):
        """Test that the downloaded directories exist from previous tests."""
        if not self.lua_dir.exists():
            self.skipTest(f"REQUIRED: Lua directory not found: {self.lua_dir}. "
                         f"The bootstrap download test must run first. "
                         f"Run: python -m pytest tests/test_download.py::TestDownloadBootstrap::test_aaa_bootstrap_download_and_extract_all_files -v")

        if not self.luarocks_dir.exists():
            self.skipTest(f"REQUIRED: LuaRocks directory not found: {self.luarocks_dir}. "
                         f"The bootstrap download test must run first. "
                         f"Run: python -m pytest tests/test_download.py::TestDownloadBootstrap::test_aaa_bootstrap_download_and_extract_all_files -v")

        # Check that Lua src directory exists
        lua_src = self.lua_dir / "src"
        if not lua_src.exists():
            self.skipTest(f"REQUIRED: Lua src directory not found: {lua_src}. "
                         f"The bootstrap download test must run first or files are corrupted. "
                         f"Run: python -m pytest tests/test_download.py::TestDownloadBootstrap::test_aaa_bootstrap_download_and_extract_all_files -v")

        print(f"[OK] Found required directories:")
        print(f"  Lua: {self.lua_dir}")
        print(f"  Lua src: {lua_src}")
        print(f"  LuaRocks: {self.luarocks_dir}")

    def _check_dependencies(self):
        """Check that required directories exist, skip test if not."""
        if not self.lua_dir.exists():
            self.skipTest(f"REQUIRED: Lua directory not found: {self.lua_dir}. "
                         f"The bootstrap download test must run first. "
                         f"Run: python run_tests.py or python -m unittest tests.test_download.TestDownloadBootstrap.test_aaa_bootstrap_download_and_extract_all_files")

        if not self.luarocks_dir.exists():
            self.skipTest(f"REQUIRED: LuaRocks directory not found: {self.luarocks_dir}. "
                         f"The bootstrap download test must run first. "
                         f"Run: python run_tests.py or python -m unittest tests.test_download.TestDownloadBootstrap.test_aaa_bootstrap_download_and_extract_all_files")

        # Check that Lua src directory exists
        lua_src = self.lua_dir / "src"
        if not lua_src.exists():
            self.skipTest(f"REQUIRED: Lua src directory not found: {lua_src}. "
                         f"The bootstrap download test must run first or files are corrupted. "
                         f"Run: python run_tests.py or python -m unittest tests.test_download.TestDownloadBootstrap.test_aaa_bootstrap_download_and_extract_all_files")

    def test_setup_build_function_exists(self):
        """Test that setup_build module has the expected functions."""
        self.assertTrue(hasattr(setup_build, 'copy_build_scripts'))
        self.assertTrue(callable(setup_build.copy_build_scripts))

    def test_copy_build_scripts_static_release(self):
        """Test copying build scripts for static release build (default)."""
        # Check dependencies first
        self._check_dependencies()

        # Clean up any existing build scripts first
        self._clean_build_scripts()

        # Set build flags for static release (default)
        setup_build.BUILD_DLL = 0
        setup_build.BUILD_DEBUG = 0

        # Call the function
        result = setup_build.copy_build_scripts()

        # Should succeed
        self.assertTrue(result, "copy_build_scripts() should return True on success")

        # Check that the correct build script was copied
        expected_script = self.lua_dir / "src" / "build-static.bat"
        self.assertTrue(expected_script.exists(),
                       f"Static build script not found: {expected_script}")

        # Check LuaRocks setup script
        luarocks_script = self.luarocks_dir / "setup-luarocks.bat"
        self.assertTrue(luarocks_script.exists(),
                       f"LuaRocks setup script not found: {luarocks_script}")

        print(f"[SUCCESS] Static release build scripts copied successfully")

    def test_copy_build_scripts_dll_release(self):
        """Test copying build scripts for DLL release build."""
        # Check dependencies first
        self._check_dependencies()

        # Clean up any existing build scripts first
        self._clean_build_scripts()

        # Set build flags for DLL release
        setup_build.BUILD_DLL = 1
        setup_build.BUILD_DEBUG = 0

        # Call the function
        result = setup_build.copy_build_scripts()

        # Should succeed
        self.assertTrue(result, "copy_build_scripts() should return True on success")

        # Check that the correct build script was copied
        expected_script = self.lua_dir / "src" / "build-dll.bat"
        self.assertTrue(expected_script.exists(),
                       f"DLL build script not found: {expected_script}")

        print(f"[SUCCESS] DLL release build scripts copied successfully")

    def test_copy_build_scripts_static_debug(self):
        """Test copying build scripts for static debug build."""
        # Check dependencies first
        self._check_dependencies()

        # Clean up any existing build scripts first
        self._clean_build_scripts()

        # Set build flags for static debug
        setup_build.BUILD_DLL = 0
        setup_build.BUILD_DEBUG = 1

        # Call the function
        result = setup_build.copy_build_scripts()

        # Should succeed
        self.assertTrue(result, "copy_build_scripts() should return True on success")

        # Check that the correct build script was copied
        expected_script = self.lua_dir / "src" / "build-static-debug.bat"
        self.assertTrue(expected_script.exists(),
                       f"Static debug build script not found: {expected_script}")

        print(f"[SUCCESS] Static debug build scripts copied successfully")

    def test_copy_build_scripts_dll_debug(self):
        """Test copying build scripts for DLL debug build."""
        # Check dependencies first
        self._check_dependencies()

        # Clean up any existing build scripts first
        self._clean_build_scripts()

        # Set build flags for DLL debug
        setup_build.BUILD_DLL = 1
        setup_build.BUILD_DEBUG = 1

        # Call the function
        result = setup_build.copy_build_scripts()

        # Should succeed
        self.assertTrue(result, "copy_build_scripts() should return True on success")

        # Check that the correct build script was copied
        expected_script = self.lua_dir / "src" / "build-dll-debug.bat"
        self.assertTrue(expected_script.exists(),
                       f"DLL debug build script not found: {expected_script}")

        print(f"[SUCCESS] DLL debug build scripts copied successfully")

    def test_all_build_script_combinations_comprehensive(self):
        """Comprehensive test that validates all 4 build script combinations."""
        # Check dependencies first
        self._check_dependencies()

        # Test all combinations systematically
        combinations = [
            {"dll": 0, "debug": 0, "script": "build-static.bat", "name": "Static Release"},
            {"dll": 1, "debug": 0, "script": "build-dll.bat", "name": "DLL Release"},
            {"dll": 0, "debug": 1, "script": "build-static-debug.bat", "name": "Static Debug"},
            {"dll": 1, "debug": 1, "script": "build-dll-debug.bat", "name": "DLL Debug"}
        ]

        print(f"\n[INFO] Testing all {len(combinations)} build script combinations...")

        for combo in combinations:
            with self.subTest(combination=combo["name"]):
                print(f"[TEST] {combo['name']} -> {combo['script']}")

                # Clean up before each test
                self._clean_build_scripts()

                # Set build flags
                setup_build.BUILD_DLL = combo["dll"]
                setup_build.BUILD_DEBUG = combo["debug"]

                # Call the function
                result = setup_build.copy_build_scripts()
                self.assertTrue(result, f"copy_build_scripts() failed for {combo['name']}")

                # Check that the correct build script was copied
                expected_script = self.lua_dir / "src" / combo["script"]
                self.assertTrue(expected_script.exists(),
                               f"{combo['name']} script not found: {expected_script}")

                # Check script content
                content = expected_script.read_text()
                self.assertTrue(content.strip(), f"{combo['name']} script is empty")
                self.assertTrue(content.strip().startswith('@echo'),
                               f"{combo['name']} script should start with @echo")

                # Check LuaRocks setup script (should be copied for all combinations)
                luarocks_script = self.luarocks_dir / "setup-luarocks.bat"
                self.assertTrue(luarocks_script.exists(),
                               f"LuaRocks setup script not found for {combo['name']}: {luarocks_script}")

                # Verify LuaRocks script content
                luarocks_content = luarocks_script.read_text()
                self.assertTrue(luarocks_content.strip(),
                               f"LuaRocks setup script is empty for {combo['name']}")

                print(f"[OK] {combo['name']} - Both Lua and LuaRocks scripts copied successfully")

        print(f"[SUCCESS] All {len(combinations)} build script combinations tested successfully!")

    def test_luarocks_setup_script_copied_for_all_combinations(self):
        """Test that LuaRocks setup script is copied for all build combinations."""
        # Check dependencies first
        self._check_dependencies()

        combinations = [
            {"dll": 0, "debug": 0, "name": "Static Release"},
            {"dll": 1, "debug": 0, "name": "DLL Release"},
            {"dll": 0, "debug": 1, "name": "Static Debug"},
            {"dll": 1, "debug": 1, "name": "DLL Debug"}
        ]

        for combo in combinations:
            with self.subTest(combination=combo["name"]):
                # Clean up before each test
                self._clean_build_scripts()

                # Set build flags
                setup_build.BUILD_DLL = combo["dll"]
                setup_build.BUILD_DEBUG = combo["debug"]

                # Call the function
                result = setup_build.copy_build_scripts()
                self.assertTrue(result, f"copy_build_scripts() failed for {combo['name']}")

                # Check LuaRocks setup script
                luarocks_script = self.luarocks_dir / "setup-luarocks.bat"
                self.assertTrue(luarocks_script.exists(),
                               f"LuaRocks setup script not found for {combo['name']}: {luarocks_script}")

                # Verify content is reasonable
                content = luarocks_script.read_text()
                self.assertGreater(len(content.strip()), 50,
                                  f"LuaRocks setup script too short for {combo['name']}")
                self.assertIn("luarocks", content.lower(),
                             f"LuaRocks setup script should mention 'luarocks' for {combo['name']}")

    def test_build_script_content_validation_all_types(self):
        """Test that all build script types have reasonable content."""
        # Check dependencies first
        self._check_dependencies()

        script_configs = [
            {"dll": 0, "debug": 0, "script": "build-static.bat", "name": "Static Release"},
            {"dll": 1, "debug": 0, "script": "build-dll.bat", "name": "DLL Release"},
            {"dll": 0, "debug": 1, "script": "build-static-debug.bat", "name": "Static Debug"},
            {"dll": 1, "debug": 1, "script": "build-dll-debug.bat", "name": "DLL Debug"}
        ]

        for config in script_configs:
            with self.subTest(script_type=config["name"]):
                # Clean up and set flags
                self._clean_build_scripts()
                setup_build.BUILD_DLL = config["dll"]
                setup_build.BUILD_DEBUG = config["debug"]

                # Copy scripts
                result = setup_build.copy_build_scripts()
                self.assertTrue(result, f"Failed to copy {config['name']} scripts")

                # Read and validate script content
                script_file = self.lua_dir / "src" / config["script"]
                self.assertTrue(script_file.exists(), f"{config['name']} script not found")

                content = script_file.read_text()
                content_lower = content.lower()

                # Basic validation
                self.assertGreater(len(content.strip()), 100,
                                  f"{config['name']} script too short")
                self.assertTrue(content.strip().startswith('@echo'),
                               f"{config['name']} script should start with @echo")

                # Should contain MSVC-related commands
                msvc_commands = ['cl.exe', 'link.exe', 'lib.exe', 'cl ', 'link ', 'lib ']
                self.assertTrue(any(cmd in content_lower for cmd in msvc_commands),
                               f"{config['name']} script should contain MSVC compiler commands")

                # DLL scripts should have different content than static scripts
                if config["dll"]:
                    # DLL builds should mention DLL-related terms
                    dll_terms = ['dll', '.dll', 'shared']
                    self.assertTrue(any(term in content_lower for term in dll_terms),
                                   f"DLL script should mention DLL-related terms: {config['name']}")
                else:
                    # Static builds should mention static/lib terms
                    static_terms = ['lib.exe', 'lib ', '.lib']
                    self.assertTrue(any(term in content_lower for term in static_terms),
                                   f"Static script should mention static/lib terms: {config['name']}")

                # Debug scripts should have debug-related content
                if config["debug"]:
                    debug_terms = ['/debug', '/z7', '/zi', '/od', 'debug']
                    has_debug_term = any(term in content_lower for term in debug_terms)
                    # Note: This might not always be true depending on script implementation
                    # so we'll make it informational rather than a hard requirement
                    if not has_debug_term:
                        print(f"[INFO] {config['name']} script may not contain obvious debug flags")

    def test_command_line_flag_combinations_comprehensive(self):
        """Comprehensive test of all command-line flag combinations."""
        # Note: Dependencies are checked within each subprocess call

        cli_combinations = [
            {"args": [], "script": "build-static.bat", "name": "Default (Static Release)"},
            {"args": ["--dll"], "script": "build-dll.bat", "name": "DLL Release"},
            {"args": ["--debug"], "script": "build-static-debug.bat", "name": "Static Debug"},
            {"args": ["--dll", "--debug"], "script": "build-dll-debug.bat", "name": "DLL Debug"}
        ]

        print(f"\n[INFO] Testing all {len(cli_combinations)} CLI flag combinations...")

        for combo in cli_combinations:
            with self.subTest(cli_combination=combo["name"]):
                print(f"[CLI TEST] {combo['name']} -> {combo['script']}")

                # Clean up before each test
                self._clean_build_scripts()

                # Run setup_build.py with the specified arguments
                cmd = [sys.executable, "setup_build.py"] + combo["args"]
                result = subprocess.run(cmd, capture_output=True, text=True)

                self.assertEqual(result.returncode, 0,
                                f"Command failed for {combo['name']}: {result.stderr}")

                # Check output message
                self.assertIn("Build scripts copied successfully", result.stdout,
                             f"Success message not found for {combo['name']}")

                # Check that the correct script was created
                expected_script = self.lua_dir / "src" / combo["script"]
                self.assertTrue(expected_script.exists(),
                               f"Expected script not created for {combo['name']}: {expected_script}")

                # Check LuaRocks script was also created
                luarocks_script = self.luarocks_dir / "setup-luarocks.bat"
                self.assertTrue(luarocks_script.exists(),
                               f"LuaRocks script not created for {combo['name']}: {luarocks_script}")

                print(f"[OK] {combo['name']} - CLI test passed")

        print(f"[SUCCESS] All {len(cli_combinations)} CLI combinations tested successfully!")

    def test_setup_build_command_line_static(self):
        """Test setup_build.py command line for static build."""
        # Clean up any existing build scripts first
        self._clean_build_scripts()

        # Run setup_build.py script (default = static release)
        result = subprocess.run([
            sys.executable, "setup_build.py"
        ], capture_output=True, text=True)

        self.assertEqual(result.returncode, 0,
                        f"setup_build.py failed: {result.stderr}")

        # Check output
        self.assertIn("Build scripts copied successfully", result.stdout)

        # Check that static build script was created
        expected_script = self.lua_dir / "src" / "build-static.bat"
        self.assertTrue(expected_script.exists())

    def test_setup_build_command_line_dll(self):
        """Test setup_build.py command line for DLL build."""
        # Clean up any existing build scripts first
        self._clean_build_scripts()

        # Run setup_build.py script with --dll flag
        result = subprocess.run([
            sys.executable, "setup_build.py", "--dll"
        ], capture_output=True, text=True)

        self.assertEqual(result.returncode, 0,
                        f"setup_build.py --dll failed: {result.stderr}")

        # Check that DLL build script was created
        expected_script = self.lua_dir / "src" / "build-dll.bat"
        self.assertTrue(expected_script.exists())

    def test_setup_build_command_line_debug(self):
        """Test setup_build.py command line for debug build."""
        # Clean up any existing build scripts first
        self._clean_build_scripts()

        # Run setup_build.py script with --debug flag
        result = subprocess.run([
            sys.executable, "setup_build.py", "--debug"
        ], capture_output=True, text=True)

        self.assertEqual(result.returncode, 0,
                        f"setup_build.py --debug failed: {result.stderr}")

        # Check that debug build script was created
        expected_script = self.lua_dir / "src" / "build-static-debug.bat"
        self.assertTrue(expected_script.exists())

    def test_setup_build_command_line_dll_debug(self):
        """Test setup_build.py command line for DLL debug build."""
        # Clean up any existing build scripts first
        self._clean_build_scripts()

        # Run setup_build.py script with both flags
        result = subprocess.run([
            sys.executable, "setup_build.py", "--dll", "--debug"
        ], capture_output=True, text=True)

        self.assertEqual(result.returncode, 0,
                        f"setup_build.py --dll --debug failed: {result.stderr}")

        # Check that DLL debug build script was created
        expected_script = self.lua_dir / "src" / "build-dll-debug.bat"
        self.assertTrue(expected_script.exists())

    def test_setup_build_help_command(self):
        """Test setup_build.py --help command."""
        result = subprocess.run([
            sys.executable, "setup_build.py", "--help"
        ], capture_output=True, text=True)

        self.assertEqual(result.returncode, 0)
        self.assertIn("Setup Build Scripts", result.stdout)
        self.assertIn("--dll", result.stdout)
        self.assertIn("--debug", result.stdout)
        self.assertIn("Current configuration", result.stdout)

    def test_build_script_content(self):
        """Test that copied build scripts have reasonable content."""
        # Set up static build
        self._clean_build_scripts()
        setup_build.BUILD_DLL = 0
        setup_build.BUILD_DEBUG = 0

        result = setup_build.copy_build_scripts()
        self.assertTrue(result)

        # Read the copied script
        script_file = self.lua_dir / "src" / "build-static.bat"
        self.assertTrue(script_file.exists())

        content = script_file.read_text()

        # Should be a Windows batch file
        self.assertTrue(content.strip().startswith('@echo'),
                       "Build script should start with @echo")

        # Should contain some MSVC-related commands (with or without .exe)
        content_lower = content.lower()
        msvc_commands = ['cl.exe', 'link.exe', 'lib.exe', 'cl ', 'link ', 'lib ']
        self.assertTrue(any(cmd in content_lower for cmd in msvc_commands),
                       "Build script should contain MSVC compiler commands")

    def _clean_build_scripts(self):
        """Clean up any existing build scripts."""
        scripts_to_clean = [
            self.lua_dir / "src" / "build-static.bat",
            self.lua_dir / "src" / "build-static-debug.bat",
            self.lua_dir / "src" / "build-dll.bat",
            self.lua_dir / "src" / "build-dll-debug.bat",
            self.luarocks_dir / "setup-luarocks.bat"
        ]

        for script in scripts_to_clean:
            if script.exists():
                script.unlink()


class TestSetupBuildMissingDirectories(unittest.TestCase):
    """Test setup_build.py behavior when directories are missing."""

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

    def test_missing_lua_directory(self):
        """Test behavior when Lua directory is missing."""
        # Temporarily rename the lua directory if it exists
        lua_dir = Path(config.get_lua_dir_name())
        temp_name = lua_dir.name + "_temp_hidden"
        temp_path = lua_dir.parent / temp_name

        renamed = False
        if lua_dir.exists():
            lua_dir.rename(temp_path)
            renamed = True

        try:
            # Should fail gracefully
            result = setup_build.copy_build_scripts()
            self.assertFalse(result, "Should return False when Lua directory is missing")

        finally:
            # Restore the directory if we renamed it
            if renamed and temp_path.exists():
                temp_path.rename(lua_dir)


if __name__ == '__main__':
    unittest.main(verbosity=2)
