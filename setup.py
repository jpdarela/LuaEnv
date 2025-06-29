"""
Master Setup Script for Lua MSVC Build System

This script orchestrates the entire build process using the configuration system.
It works with any Lua/LuaRocks versions specified in build_config.txt.
"""

import os
import shutil
import subprocess
import sys
from pathlib import Path

# Import configuration system
try:
    from config import (
        get_lua_dir_name, get_luarocks_dir_name, get_lua_tests_dir_name,
        LUA_VERSION, LUAROCKS_VERSION, LUAROCKS_PLATFORM
    )
except ImportError as e:
    print(f"Error importing configuration: {e}")
    print("Make sure config.py is in the same directory as this script.")
    sys.exit(1)

# Default installation directory
default_install_dir = Path("./lua").resolve()

install_dir = str(default_install_dir)

def call_check_env_bat_script():
    """Call the check_env.bat script to verify the environment."""
    current_dir = os.path.dirname(os.path.abspath(__file__))
    check_env_script = os.path.join(current_dir, "check-env.bat")

    if os.path.exists(check_env_script):
        print("Checking Visual Studio environment...")
        try:
            # Run in quiet mode to get parseable output
            result = subprocess.run([check_env_script, "--quiet"],
                                  capture_output=True, text=True, check=False)

            # Parse the output
            env_ok = False
            issues = []

            for line in result.stdout.strip().split('\n'):
                if line.startswith('ENV_CHECK_RESULT='):
                    env_ok = line.split('=')[1] == 'SUCCESS'
                elif line.startswith('ENV_CHECK_ISSUES='):
                    issues_str = line.split('=')[1]
                    issues = [issue for issue in issues_str.split(';') if issue]

            if env_ok:
                print("? Visual Studio environment is properly configured.")
                return True
            else:
                print("? Visual Studio environment issues detected:")
                issue_descriptions = {
                    'VCINSTALLDIR_MISSING': 'Visual Studio installation directory not found',
                    'TARGET_ARCH_MISSING': 'Target architecture not set',
                    'WINDOWS_SDK_MISSING': 'Windows SDK directory not found',
                    'WINDOWS_SDK_VERSION_MISSING': 'Windows SDK version not set',
                    'CL_EXE_MISSING': 'C compiler (cl.exe) not found in PATH',
                    'LINK_EXE_MISSING': 'Linker (link.exe) not found in PATH',
                    'LIB_EXE_MISSING': 'Librarian (lib.exe) not found in PATH',
                    'NMAKE_EXE_MISSING': 'NMake (nmake.exe) not found in PATH',
                    'MSVCRT_LIB_MISSING': 'MSVCRT.lib not found',
                    'UCRT_LIB_MISSING': 'UCRT.lib not found',
                    'KERNEL32_LIB_MISSING': 'kernel32.lib not found',
                    'MSVCRT_LOWER_LIB_MISSING': 'msvcrt.lib not found',
                    'LIB_ENV_VAR_MISSING': 'LIB environment variable not set'
                }

                for issue in issues:
                    description = issue_descriptions.get(issue, f"Unknown issue: {issue}")
                    print(f"  - {description}")

                print("\nTo fix these issues:")
                print("1. Run this script from a Visual Studio Developer Command Prompt")
                print("2. Or run the Visual Studio environment setup manually:")
                print("   \"C:\\Program Files\\Microsoft Visual Studio\\2022\\Community\\VC\\Auxiliary\\Build\\vcvars64.bat\"")
                print("   (adjust path based on your VS edition)")

                return False

        except Exception as e:
            print(f"Warning: Could not run environment check: {e}")
            print("Proceeding anyway, but build may fail if environment is not set up correctly.")
            return True
    else:
        print("check-env.bat script not found. Skipping environment check.")
        return True


def run_setup(with_dll=False, with_debug=False, prefix=install_dir, skip_env_check=False):
    """Run the download setup build and build python scripts."""
    current_dir = os.path.dirname(os.path.abspath(__file__))

    # Convert prefix to absolute path to avoid issues with relative paths
    prefix = os.path.abspath(prefix)

    print(f"Lua MSVC Build System - Master Setup")
    print("=" * 50)
    print(f"Configuration: Lua {LUA_VERSION}, LuaRocks {LUAROCKS_VERSION}")

    # Determine build type for display
    if with_dll and with_debug:
        build_type = "DLL Debug"
    elif with_dll:
        build_type = "DLL Release"
    elif with_debug:
        build_type = "Static Debug"
    else:
        build_type = "Static Release"

    print(f"Build type: {build_type}")
    print(f"Install directory: {prefix}")
    print()

    # Check environment unless explicitly skipped
    if not skip_env_check:
        env_ok = call_check_env_bat_script()
        if not env_ok:
            print("\nEnvironment check failed. Build may not succeed.")
            response = input("Do you want to continue anyway? (y/N): ").strip().lower()
            if response not in ['y', 'yes']:
                print("Setup cancelled. Please fix the environment issues and try again.")
                return False
            print("Continuing with potentially problematic environment...")

    print("Step 1: Downloading sources...")
    # Run download script
    download_script = os.path.join(current_dir, "download_lua_luarocks.py")
    subprocess.run([sys.executable, download_script], check=True)

    print(f"\nStep 2: Setting up build scripts...")
    # Run setup build scripts with appropriate flags
    setup_build_script = os.path.join(current_dir, "setup_build.py")
    setup_build_args = [sys.executable, setup_build_script]
    if with_dll:
        setup_build_args.append("--dll")
    if with_debug:
        setup_build_args.append("--debug")
    subprocess.run(setup_build_args, check=True)

    print(f"\nStep 3: Building and installing...")
    # Run build script with appropriate flags and prefix
    build_script = os.path.join(current_dir, "build.py")
    build_args = [sys.executable, build_script, "--prefix", prefix]
    if with_dll:
        build_args.append("--dll")
    if with_debug:
        build_args.append("--debug")
    subprocess.run(build_args, check=True)

    print(f"\nStep 4: Finalizing installation...")
    # Copy the use-lua.ps1 script to the installation directory, pass if the path is the same
    use_lua_script = Path(current_dir) / "use-lua.ps1"
    dest_use_lua_script = Path(prefix).parent / "use-lua.ps1"
    use_lua_script_copied = False

    if use_lua_script.resolve() != dest_use_lua_script.resolve():
        shutil.copy(use_lua_script, dest_use_lua_script)
        print(f"  Copied use-lua.ps1 to {dest_use_lua_script}")
        use_lua_script_copied = True
    else:
        print(f"  use-lua.ps1 already in correct location (project folder installation)")
        use_lua_script_copied = False

    # Save the lua_prefix.txt file in the parent directory of the prefix
    dest_prefix_fir_file = Path(prefix).parent / ".lua_prefix.txt"
    with open(dest_prefix_fir_file, 'w') as f:
        f.write(prefix)
    print(f"  Created prefix file: {dest_prefix_fir_file}")

    # Save installation information for uninstall
    save_installation_info(prefix, with_dll, with_debug, use_lua_script_copied)

    return True

def test_lua_build(lua_install_dir, run_tests=True):
    """Test the Lua build by running basic commands and the basic test suite."""
    lua_exe = Path(lua_install_dir) / "bin" / "lua.exe"

    if not lua_exe.exists():
        print(f"[ERROR] lua.exe not found at {lua_exe}")
        return False

    print(f"[TEST] Testing Lua {LUA_VERSION} installation at {lua_install_dir}...")

    try:
        # Test 1: Check Lua version
        print("  [OK] Checking Lua version...")
        result = subprocess.run([str(lua_exe), "-v"],
                              capture_output=True, text=True, check=True)
        print(f"    {result.stderr.strip()}")  # Lua version goes to stderr

        # Test 2: Basic Lua execution
        print("  [OK] Testing basic Lua execution...")
        result = subprocess.run([str(lua_exe), "-e", "print('Hello from Lua!')"],
                              capture_output=True, text=True, check=True)
        print(f"    Output: {result.stdout.strip()}")

        # Test 3: Check if tests directory exists and run tests if requested
        if run_tests:
            # Use configuration system to get correct test directory name
            tests_dir = Path(get_lua_tests_dir_name())
            if tests_dir.exists():
                print(f"  [TEST] Running Lua {LUA_VERSION} basic test suite from {tests_dir}...")
                print("     Note: Running basic tests (_U=true flag) - some warnings are normal.")

                # Change to tests directory and run tests
                original_cwd = os.getcwd()
                # Calculate absolute path to lua.exe BEFORE changing directories
                abs_lua_exe = os.path.abspath(lua_exe)

                try:
                    os.chdir(tests_dir)

                    # Run basic tests with _U=true flag (for UTF-8 support and basic test mode)
                    # Use absolute path to lua.exe since we changed directories
                    print("     Running: lua.exe -e \"_U=true\" all.lua (Basic Test Suite)")
                    result = subprocess.run([abs_lua_exe, "-e", "_U=true", "all.lua"],
                                          capture_output=True, text=True, timeout=300)

                    if result.returncode == 0:
                        print("  [PASS] Basic test suite completed successfully!")
                        # Show only the final summary
                        lines = result.stdout.split('\n')
                        for line in lines[-10:]:
                            if line.strip():
                                print(f"     {line}")
                    else:
                        print("  [WARN] Basic test suite completed with issues:")
                        print("     STDOUT:")
                        for line in result.stdout.split('\n')[-20:]:
                            if line.strip():
                                print(f"       {line}")
                        print("     STDERR:")
                        for line in result.stderr.split('\n')[-10:]:
                            if line.strip():
                                print(f"       {line}")

                        # Common issues and solutions
                        if "attempt to index a nil value" in result.stdout:
                            print(f"\n  [TIP] Some test failures are common on Windows for Lua {LUA_VERSION}.")
                            print("     This usually relates to file permissions or temp directory access.")
                            print("     Your Lua build is likely fine for normal use.")

                        return False

                finally:
                    os.chdir(original_cwd)
            else:
                print(f"  [WARN] Tests directory {tests_dir} not found. Download may have failed.")
                return False
        else:
            print("  [INFO] Skipping basic test suite (remove --skip-tests flag to enable)")

        print("  [PASS] Basic Lua functionality test passed!")
        return True

    except subprocess.CalledProcessError as e:
        print(f"  [ERROR] Error testing Lua: {e}")
        print(f"     Command: {' '.join(e.cmd)}")
        if e.stdout:
            print(f"     STDOUT: {e.stdout}")
        if e.stderr:
            print(f"     STDERR: {e.stderr}")
        return False
    except subprocess.TimeoutExpired:
        print("  [WARN] Test suite timed out (took more than 5 minutes)")
        print("     This might indicate an issue, but basic Lua functionality may still work.")
        return False
    except Exception as e:
        print(f"  [ERROR] Unexpected error testing Lua: {e}")
        return False

def save_installation_info(prefix, with_dll, with_debug=False, use_lua_script_copied=False):
    """Save installation information for later uninstall."""
    current_dir = os.path.dirname(os.path.abspath(__file__))
    install_info_file = Path(current_dir) / ".lua_install_info.txt"

    # Determine build type
    if with_dll and with_debug:
        build_type = "dll_debug"
    elif with_dll:
        build_type = "dll"
    elif with_debug:
        build_type = "static_debug"
    else:
        build_type = "static"

    # Only save use-lua.ps1 path if it was actually copied (not project folder installation)
    use_lua_script_path = str(Path(prefix).parent / "use-lua.ps1") if use_lua_script_copied else ""

    # Collect installation information
    install_info = {
        'install_directory': prefix,
        'build_type': build_type,
        'lua_version': LUA_VERSION,
        'luarocks_version': LUAROCKS_VERSION,
        'luarocks_platform': LUAROCKS_PLATFORM,
        'use_lua_script': use_lua_script_path,
        'prefix_file': str(Path(prefix).parent / ".lua_prefix.txt"),
        'timestamp': subprocess.run(['date', '/t'], capture_output=True, text=True, shell=True).stdout.strip()
    }

    # Write installation info
    with open(install_info_file, 'w') as f:
        f.write("# Lua MSVC Build Installation Information\n")
        f.write("# This file is used by the uninstall process\n")
        f.write(f"INSTALL_DIRECTORY={install_info['install_directory']}\n")
        f.write(f"BUILD_TYPE={install_info['build_type']}\n")
        f.write(f"LUA_VERSION={install_info['lua_version']}\n")
        f.write(f"LUAROCKS_VERSION={install_info['luarocks_version']}\n")
        f.write(f"LUAROCKS_PLATFORM={install_info['luarocks_platform']}\n")
        f.write(f"USE_LUA_SCRIPT={install_info['use_lua_script']}\n")
        f.write(f"PREFIX_FILE={install_info['prefix_file']}\n")
        f.write(f"INSTALL_DATE={install_info['timestamp']}\n")

    print(f"[INFO] Installation information saved to {install_info_file}")
    print(f"       Lua {LUA_VERSION} ({install_info['build_type']}) -> {prefix}")


def uninstall_lua():
    """Uninstall Lua and related files based on saved installation info."""
    current_dir = os.path.dirname(os.path.abspath(__file__))
    install_info_file = Path(current_dir) / ".lua_install_info.txt"

    if not install_info_file.exists():
        print("[ERROR] No installation information found.")
        print("        Cannot proceed with uninstall. File missing: .lua_install_info.txt")
        return False

    # Read installation information
    install_info = {}
    try:
        with open(install_info_file, 'r') as f:
            for line in f:
                line = line.strip()
                if line and not line.startswith('#') and '=' in line:
                    key, value = line.split('=', 1)
                    install_info[key] = value
    except Exception as e:
        print(f"[ERROR] Failed to read installation info: {e}")
        return False

    if 'INSTALL_DIRECTORY' not in install_info:
        print("[ERROR] Invalid installation information file.")
        return False

    install_dir = Path(install_info['INSTALL_DIRECTORY'])
    build_type = install_info.get('BUILD_TYPE', 'unknown')
    lua_version = install_info.get('LUA_VERSION', 'unknown')
    luarocks_version = install_info.get('LUAROCKS_VERSION', 'unknown')
    luarocks_platform = install_info.get('LUAROCKS_PLATFORM', 'unknown')
    use_lua_script = install_info.get('USE_LUA_SCRIPT')
    prefix_file = install_info.get('PREFIX_FILE')
    install_date = install_info.get('INSTALL_DATE', 'unknown')

    print(f"[UNINSTALL] Lua MSVC Build Uninstaller")
    print(f"============================================")
    print(f"Installation directory: {install_dir}")
    print(f"Lua version: {lua_version}")
    print(f"LuaRocks: {luarocks_version} ({luarocks_platform})")
    print(f"Build type: {build_type}")
    print(f"Installation date: {install_date}")
    print()

    # Confirm uninstall
    response = input("Are you sure you want to uninstall Lua and remove all files? (y/N): ").strip().lower()
    if response not in ['y', 'yes']:
        print("[INFO] Uninstall cancelled.")
        return False

    print("\n[UNINSTALL] Starting uninstall process...")

    # Remove main installation directory
    if install_dir.exists():
        print(f"  [REMOVE] Removing installation directory: {install_dir}")
        try:
            shutil.rmtree(install_dir)
            print(f"  [OK] Successfully removed {install_dir}")
        except Exception as e:
            print(f"  [ERROR] Failed to remove {install_dir}: {e}")
            return False
    else:
        print(f"  [SKIP] Installation directory not found: {install_dir}")

    # Remove use-lua.ps1 script (only if it was copied during installation)
    if use_lua_script and use_lua_script.strip() and Path(use_lua_script).exists():
        print(f"  [REMOVE] Removing use-lua.ps1 script: {use_lua_script}")
        try:
            Path(use_lua_script).unlink()
            print(f"  [OK] Successfully removed {use_lua_script}")
        except Exception as e:
            print(f"  [ERROR] Failed to remove {use_lua_script}: {e}")
    elif use_lua_script and use_lua_script.strip():
        print(f"  [SKIP] use-lua.ps1 script not found: {use_lua_script}")
    else:
        print(f"  [SKIP] use-lua.ps1 was not copied during installation (project folder installation)")

    # Remove prefix file
    if prefix_file and Path(prefix_file).exists():
        print(f"  [REMOVE] Removing prefix file: {prefix_file}")
        try:
            Path(prefix_file).unlink()
            print(f"  [OK] Successfully removed {prefix_file}")
        except Exception as e:
            print(f"  [ERROR] Failed to remove {prefix_file}: {e}")

    # Remove installation info file
    print(f"  [REMOVE] Removing installation info: {install_info_file}")
    try:
        install_info_file.unlink()
        print(f"  [OK] Successfully removed {install_info_file}")
    except Exception as e:
        print(f"  [ERROR] Failed to remove {install_info_file}: {e}")

    print("\n[SUCCESS] Uninstall completed!")

    # Warning about LuaRocks directories
    print("\n" + "="*60)
    print("IMPORTANT: MANUAL CLEANUP REQUIRED")
    print("="*60)
    print("[WARNING] The following directories may contain LuaRocks packages")
    print("          and must be removed manually if no longer needed:")
    print()
    print("  * User LuaRocks packages:")
    print(f"    {Path.home() / 'AppData' / 'Roaming' / 'luarocks'}")
    print()
    print("  * Project-specific LuaRocks trees (if you used custom --tree paths)")
    print("    Check your project directories for 'lua_modules' or similar folders")
    print()
    print("  * Temporary LuaRocks configuration files:")
    print(f"    {Path.home() / 'AppData' / 'Local' / 'Temp' / 'luarocks-config'}")
    print()
    print("[INFO] These directories are NOT automatically removed to prevent")
    print("       accidental deletion of packages used by other Lua installations.")
    print("="*60)

    return True

if __name__ == "__main__":
    import argparse

    parser = argparse.ArgumentParser(
        description="Master setup script for Lua and LuaRocks using the configuration system.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=f"""
Current Configuration (from build_config.txt):
  Lua: {LUA_VERSION}
  LuaRocks: {LUAROCKS_VERSION} ({LUAROCKS_PLATFORM})

Examples:
  python setup.py                                      # Static release build to ./lua (with basic tests)
  python setup.py --dll                                # DLL release build to ./lua (with basic tests)
  python setup.py --debug                              # Static debug build to ./lua (with basic tests)
  python setup.py --dll --debug                        # DLL debug build to ./lua (with basic tests)
  python setup.py --prefix C:\\lua                      # Static release build to C:\\lua (with basic tests)
  python setup.py --dll --debug --prefix C:\\Dev\\Lua    # DLL debug build to C:\\Dev\\Lua (with basic tests)
  python setup.py --skip-tests                         # Build without running basic test suite
  python setup.py --skip-env-check                     # Build without Visual Studio environment check
  python setup.py --dll --debug --skip-tests --skip-env-check  # DLL debug build skipping both tests and env check
  python setup.py --uninstall                          # Uninstall Lua and remove all files

Build Types:
  Static Release:  Optimized static library build (default)
  DLL Release:     Optimized DLL build
  Static Debug:    Unoptimized static build with debug symbols
  DLL Debug:       Unoptimized DLL build with debug symbols

Prerequisites:
  1. Visual Studio 2022 with C++ build tools
  2. Run from a Visual Studio Developer Command Prompt (unless --skip-env-check)
  3. Internet connection for downloading sources

To use different versions, edit build_config.txt and re-run this script.
        """
    )

    parser.add_argument(
        "--dll",
        action="store_true",
        help="Set up for DLL build instead of static build"
    )

    parser.add_argument(
        "--debug",
        action="store_true",
        help="Set up for debug build with debug symbols and unoptimized code"
    )

    parser.add_argument(
        "--prefix",
        default=install_dir,
        help=f"Installation directory for Lua (default: {install_dir})"
    )

    parser.add_argument(
        "--skip-env-check",
        action="store_true",
        help="Skip Visual Studio environment check and proceed with build"
    )

    parser.add_argument(
        "--skip-tests",
        action="store_true",
        help="Skip the Lua basic test suite after building"
    )

    parser.add_argument(
        "--uninstall",
        action="store_true",
        help="Uninstall Lua and remove all related files"
    )

    args = parser.parse_args()

    # Handle uninstall mode
    if args.uninstall:
        print("Lua MSVC Build - Uninstall Mode")
        print("="*40)
        success = uninstall_lua()
        exit(0 if success else 1)

    print(f"Lua MSVC Build System - Master Setup")
    print("="*50)
    print(f"Configuration: Lua {LUA_VERSION}, LuaRocks {LUAROCKS_VERSION}")

    # Determine build type for display
    if args.dll and args.debug:
        build_type = "DLL Debug"
    elif args.dll:
        build_type = "DLL Release"
    elif args.debug:
        build_type = "Static Debug"
    else:
        build_type = "Static Release"

    print(f"Build type: {build_type}")
    print(f"Install directory: {args.prefix}")
    if args.skip_env_check:
        print(f"Environment check: Skipped")
    if args.skip_tests:
        print(f"Test suite: Skipped")
    else:
        print(f"Test suite: Will run basic tests after build")
    print()

    success = run_setup(with_dll=args.dll, with_debug=args.debug, prefix=args.prefix, skip_env_check=args.skip_env_check)
    if not success:
        exit(1)

    # Run tests unless explicitly skipped
    if not args.skip_tests:
        print("\n" + "="*60)
        print("TESTING INSTALLATION")
        print("="*60)
        test_success = test_lua_build(args.prefix, run_tests=True)
        if not test_success:
            print("\n[WARN] Some basic tests failed, but your Lua installation may still be usable.")
            print("   Try running: lua -e \"print('Hello, Lua!')\" to verify basic functionality.")
        else:
            print("\n[SUCCESS] All basic tests passed! Your Lua installation is ready to use.")
        print(f"\nLua {LUA_VERSION} is now installed and ready to use!")
        print(f"Installation directory: {args.prefix}")
        print(f"To use Lua, add {args.prefix}\\bin to your PATH environment variable.")
    else:
        # Run only minimal functionality test when tests are skipped
        print("\n" + "="*60)
        print("BASIC FUNCTIONALITY TEST")
        print("="*60)
        test_success = test_lua_build(args.prefix, run_tests=False)
        if test_success:
            print("\n[PASS] Basic functionality test passed!")
            print("   Remove --skip-tests flag to run the basic test suite.")
            print(f"\nLua {LUA_VERSION} is now installed and ready to use!")
            print(f"Installation directory: {args.prefix}")
            print(f"To use Lua, add {args.prefix}\\bin to your PATH environment variable.")
        else:
            print("\n[FAIL] Basic test failed. Check the installation.")
            exit(1)
