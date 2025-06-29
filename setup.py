"""
SETUP script

"""

import os
import shutil
import subprocess
import sys
from pathlib import Path

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


def run_setup(with_dll=False, prefix=install_dir, skip_env_check=False):
    """Run the download setup build and build python scripts."""
    current_dir = os.path.dirname(os.path.abspath(__file__))

    # Convert prefix to absolute path to avoid issues with relative paths
    prefix = os.path.abspath(prefix)

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

    # Run download script
    download_script = os.path.join(current_dir, "download_lua_luarocks.py")
    subprocess.run([sys.executable, download_script], check=True)

    if not with_dll:
        print(f"Setting up for static build to {prefix}...")

        # Run setup build scrips
        setup_build_script = os.path.join(current_dir, "setup_build.py")
        subprocess.run([sys.executable, setup_build_script], check=True)

        # Run build script with prefix
        build_script = os.path.join(current_dir, "build.py")
        subprocess.run([sys.executable, build_script, "--prefix", prefix], check=True)
    else:
        print(f"Setting up for DLL build to {prefix}...")

        # Run setup build scrips with DLL option
        setup_build_script = os.path.join(current_dir, "setup_build.py")
        subprocess.run([sys.executable, setup_build_script, "--dll"], check=True)

        # Run build script with DLL option and prefix
        build_script = os.path.join(current_dir, "build.py")
        subprocess.run([sys.executable, build_script, "--dll", "--prefix", prefix], check=True)

    # Copy the use-lua.ps1 script to the installation directory, pass if the path is the same
    use_lua_script = Path(current_dir) / "use-lua.ps1"
    dest_use_lua_script = Path(prefix).parent / "use-lua.ps1"
    if use_lua_script != dest_use_lua_script:
        shutil.copy(use_lua_script, dest_use_lua_script)
    else:
        pass
    # Save the lua_prefix.txt file in the parent directory of the prefix
    dest_prefix_fir_file = Path(prefix).parent / ".lua_prefix.txt"
    with open(dest_prefix_fir_file, 'w') as f:
        f.write(prefix)

    # Save installation information for uninstall
    save_installation_info(prefix, with_dll)

    return True

def test_lua_build(lua_install_dir, run_tests=True):
    """Test the Lua build by running basic commands and the basic test suite."""
    lua_exe = Path(lua_install_dir) / "bin" / "lua.exe"

    if not lua_exe.exists():
        print(f"[ERROR] lua.exe not found at {lua_exe}")
        return False

    print(f"[TEST] Testing Lua installation at {lua_install_dir}...")

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
            tests_dir = Path("lua-5.4.8-tests")
            if tests_dir.exists():
                print(f"  [TEST] Running Lua basic test suite from {tests_dir}...")
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
                                          capture_output=True, text=True, timeout=3000)

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
                            print("\n  [TIP] The 'main.lua' test failure is common on Windows.")
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

def save_installation_info(prefix, with_dll):
    """Save installation information for later uninstall."""
    current_dir = os.path.dirname(os.path.abspath(__file__))
    install_info_file = Path(current_dir) / ".lua_install_info.txt"

    # Collect installation information
    install_info = {
        'install_directory': prefix,
        'build_type': 'dll' if with_dll else 'static',
        'use_lua_script': str(Path(prefix).parent / "use-lua.ps1"),
        'prefix_file': str(Path(prefix).parent / ".lua_prefix.txt"),
        'timestamp': subprocess.run(['date', '/t'], capture_output=True, text=True, shell=True).stdout.strip()
    }

    # Write installation info
    with open(install_info_file, 'w') as f:
        f.write("# Lua MSVC Build Installation Information\n")
        f.write("# This file is used by the uninstall process\n")
        f.write(f"INSTALL_DIRECTORY={install_info['install_directory']}\n")
        f.write(f"BUILD_TYPE={install_info['build_type']}\n")
        f.write(f"USE_LUA_SCRIPT={install_info['use_lua_script']}\n")
        f.write(f"PREFIX_FILE={install_info['prefix_file']}\n")
        f.write(f"INSTALL_DATE={install_info['timestamp']}\n")

    print(f"[INFO] Installation information saved to {install_info_file}")


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
    use_lua_script = install_info.get('USE_LUA_SCRIPT')
    prefix_file = install_info.get('PREFIX_FILE')
    install_date = install_info.get('INSTALL_DATE', 'unknown')

    print(f"[UNINSTALL] Lua MSVC Build Uninstaller")
    print(f"============================================")
    print(f"Installation directory: {install_dir}")
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

    # Remove use-lua.ps1 script
    if use_lua_script and Path(use_lua_script).exists():
        print(f"  [REMOVE] Removing use-lua.ps1 script: {use_lua_script}")
        try:
            Path(use_lua_script).unlink()
            print(f"  [OK] Successfully removed {use_lua_script}")
        except Exception as e:
            print(f"  [ERROR] Failed to remove {use_lua_script}: {e}")

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
    print("  • User LuaRocks packages:")
    print(f"    {Path.home() / 'AppData' / 'Roaming' / 'luarocks'}")
    print()
    print("  • Project-specific LuaRocks trees (if you used custom --tree paths)")
    print("    Check your project directories for 'lua_modules' or similar folders")
    print()
    print("  • Temporary LuaRocks configuration files:")
    print(f"    {Path.home() / 'AppData' / 'Local' / 'Temp' / 'luarocks-config'}")
    print()
    print("[INFO] These directories are NOT automatically removed to prevent")
    print("       accidental deletion of packages used by other Lua installations.")
    print("="*60)

    return True

if __name__ == "__main__":
    import argparse

    parser = argparse.ArgumentParser(
        description="Master setup script for Lua and LuaRocks.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  python setup.py                                      # Static build to ./lua (with basic tests)
  python setup.py --dll                                # DLL build to ./lua (with basic tests)
  python setup.py --prefix C:\lua                      # Static build to C:\\lua (with basic tests)
  python setup.py --dll --prefix C:\Development\Lua    # DLL build to C:\\Development\\Lua (with basic tests)
  python setup.py --skip-tests                         # Build without running basic test suite
  python setup.py --skip-env-check                     # Build without Visual Studio environment check
  python setup.py --dll --skip-tests --skip-env-check  # DLL build skipping both tests and env check
  python setup.py --uninstall                          # Uninstall Lua and remove all files
        """
    )

    parser.add_argument(
        "--dll",
        action="store_true",
        help="Set up for DLL build instead of static build"
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

    print(f"Master setup with the following options:")
    print(f"  Build type: {'DLL' if args.dll else 'Static'}")
    print(f"  Install directory: {args.prefix}")
    if args.skip_env_check:
        print(f"  Environment check: Skipped")
    if args.skip_tests:
        print(f"  Test suite: Skipped")
    else:
        print(f"  Test suite: Will run basic tests after build")
    print()

    success = run_setup(with_dll=args.dll, prefix=args.prefix, skip_env_check=args.skip_env_check)
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
    else:
        # Run only minimal functionality test when tests are skipped
        print("\n" + "="*60)
        print("BASIC FUNCTIONALITY TEST")
        print("="*60)
        test_success = test_lua_build(args.prefix, run_tests=False)
        if test_success:
            print("\n[PASS] Basic functionality test passed!")
            print("   Remove --skip-tests flag to run the basic test suite.")
        else:
            print("\n[FAIL] Basic test failed. Check the installation.")
            exit(1)
