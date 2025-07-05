# This is free and unencumbered software released into the public domain.
# For more details, see the LICENSE file in the project root.

"""
LuaEnv Setup Script - UUID-Based Installation System

This script builds and installs Lua/LuaRocks into the LuaEnv system at %USERPROFILE%\\.luaenv\\
Each installation gets a unique UUID and is tracked in the central registry.
"""

import os
import subprocess
import sys
from pathlib import Path
import argparse

# Add current directory to Python path for local imports
current_dir = Path(__file__).parent
sys.path.insert(0, str(current_dir))

# Import configuration system and registry with dual-context support
try:
    from .config import (
        get_lua_tests_dir_name,
        LUA_VERSION, LUAROCKS_VERSION, LUAROCKS_PLATFORM
    )
    from .registry import LuaEnvRegistry
except ImportError:
    from config import (
        get_lua_tests_dir_name,
        LUA_VERSION, LUAROCKS_VERSION, LUAROCKS_PLATFORM
    )
    from registry import LuaEnvRegistry


def setenv(architecture="x64"):
    """Set Visual Studio environment variables by directly calling vcvars batch file.

    Args:
        architecture (str): Target architecture - "x64" (default) or "x86"
    """
    print(f"[INFO] Setting up Visual Studio environment for {architecture}...")

    # Save current working directory
    original_cwd = os.getcwd()

    # Choose the appropriate vcvars batch file based on architecture
    if architecture == "x86":
        vcvars_filename = "vcvars32.bat"
        arch_display = "x86 (32-bit)"
    else:  # Default to x64
        vcvars_filename = "vcvars64.bat"
        arch_display = "x64 (64-bit)"

    # Common paths where Visual Studio might be installed
    vs_paths = [
        rf"C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Auxiliary\Build\{vcvars_filename}",
        rf"C:\Program Files\Microsoft Visual Studio\2019\Community\VC\Auxiliary\Build\{vcvars_filename}",
        rf"C:\Program Files (x86)\Microsoft Visual Studio\2022\Community\VC\Auxiliary\Build\{vcvars_filename}",
        rf"C:\Program Files (x86)\Microsoft Visual Studio\2019\Community\VC\Auxiliary\Build\{vcvars_filename}",
        rf"C:\Program Files\Microsoft Visual Studio\2022\Professional\VC\Auxiliary\Build\{vcvars_filename}",
        rf"C:\Program Files\Microsoft Visual Studio\2019\Professional\VC\Auxiliary\Build\{vcvars_filename}",
        rf"C:\Program Files\Microsoft Visual Studio\2022\Enterprise\VC\Auxiliary\Build\{vcvars_filename}",
        rf"C:\Program Files\Microsoft Visual Studio\2019\Enterprise\VC\Auxiliary\Build\{vcvars_filename}",
    ]

    # Check if there's a saved VS path
    vs_config_file = ".vs_install_path.txt"
    if os.path.exists(vs_config_file):
        try:
            with open(vs_config_file, 'r') as f:
                saved_path = f.read().strip()
                if saved_path:
                    vcvars_path = os.path.join(saved_path, rf"VC\Auxiliary\Build\{vcvars_filename}")
                    if os.path.exists(vcvars_path):
                        vs_paths.insert(0, vcvars_path)  # Use saved path first
                        print(f"[INFO] Using saved Visual Studio path: {saved_path}")
        except Exception as e:
            print(f"[WARNING] Could not read VS config file: {e}")

    # Find the first available vcvars batch file
    vcvars_bat = None
    for path in vs_paths:
        if os.path.exists(path):
            vcvars_bat = path
            print(f"[OK] Found Visual Studio at: {path}")
            print(f"[INFO] Target architecture: {arch_display}")
            break

    if not vcvars_bat:
        print(f"[ERROR] Could not find Visual Studio installation for {arch_display}")
        print("[INFO] Searched the following paths:")
        for path in vs_paths:
            print(f"  - {path}")
        print("")
        print("[SOLUTION] To resolve this issue:")
        print("1. Install Visual Studio 2019 or 2022 with C++ development tools")
        print("2. OR use the setenv.ps1 script to manually configure environment:")
        arch_param = "x86" if architecture == "x86" else "amd64"
        print(f"   %USERPROFILE%\\.luaenv\\bin\\setenv.ps1 -Arch {arch_param} -Current")
        print("3. Then run your installation command with --skip-env-check flag:")
        print("   python setup_lua.py --skip-env-check [--x86 for 32-bit] (add architecture flag to match your environment setup)")
        print("")
        print("[IMPORTANT] Architecture flags must match:")
        if architecture == "x86":
            print("  setenv.ps1 -Arch x86 → setup_lua.py --skip-env-check --x86")
        else:
            print("  setenv.ps1 -Arch amd64 → setup_lua.py --skip-env-check (x64 is default)")
        print("")
        print("[WARNING] Build may fail without Visual Studio environment")
        return False

    try:
        # Create a batch script that calls vcvars64.bat and outputs environment
        import tempfile
        with tempfile.NamedTemporaryFile(mode='w', suffix='.bat', delete=False) as f:
            f.write(f'''@echo off
cd /d "{original_cwd}"
call "{vcvars_bat}" >nul 2>&1
if errorlevel 1 (
    echo VCVARS_FAILED
    exit 1
)
cd /d "{original_cwd}"
set
''')
            temp_file = f.name

        try:
            # Run the batch file and capture environment
            result = subprocess.run([temp_file], capture_output=True, text=True, shell=True, cwd=original_cwd)

            if result.returncode == 0 and "VCVARS_FAILED" not in result.stdout:
                # Apply environment variables to current process
                env_vars_set = 0
                for line in result.stdout.strip().split('\n'):
                    if '=' in line and not line.startswith('VCVARS_FAILED'):
                        key, value = line.split('=', 1)
                        # Skip some problematic variables that might break Python
                        if key.upper() not in ['PSModulePath', 'PYTHONPATH', 'PYTHONHOME', 'PROMPT']:
                            os.environ[key] = value
                            env_vars_set += 1

                print(f"[OK] Applied {env_vars_set} environment variables from Visual Studio")
                return True
            else:
                print("[ERROR] Failed to set up Visual Studio environment")
                if "VCVARS_FAILED" in result.stdout:
                    print("[INFO] The Visual Studio environment setup script reported an error")
                print("")
                print("[SOLUTION] To resolve this issue:")
                print("1. Make sure Visual Studio C++ development tools are properly installed")
                print("2. OR use the setenv.ps1 script to manually configure environment:")
                arch_param = "x86" if architecture == "x86" else "amd64"
                print(f"   %USERPROFILE%\\.luaenv\\bin\\setenv.ps1 -Arch {arch_param} -Current")
                print("3. Then run your installation command with --skip-env-check flag:")
                print("   python setup_lua.py --skip-env-check [--x86 for 32-bit] (add architecture flag to match your environment setup)")
                print("")
                print("[IMPORTANT] Architecture flags must match:")
                if architecture == "x86":
                    print("  setenv.ps1 -Arch x86 → setup_lua.py --skip-env-check --x86")
                else:
                    print("  setenv.ps1 -Arch amd64 → setup_lua.py --skip-env-check (x64 is default)")
                print("")
                return False
        finally:
            # Clean up temp file
            try:
                os.unlink(temp_file)
            except:
                pass

    except Exception as e:
        print(f"[ERROR] Failed to set up Visual Studio environment: {e}")
        print("")
        print("[SOLUTION] To resolve this issue:")
        print("1. Make sure Visual Studio C++ development tools are properly installed")
        print("2. OR use the setenv.ps1 script to manually configure environment:")
        arch_param = "x86" if architecture == "x86" else "amd64"
        print(f"   %USERPROFILE%\\.luaenv\\bin\\setenv.ps1 -Arch {arch_param} -Current")
        print("3. Then run your installation command with --skip-env-check flag:")
        print("   python setup_lua.py --skip-env-check [--x86 for 32-bit] (add architecture flag to match your environment setup)")
        print("")
        print("[IMPORTANT] Architecture flags must match:")
        if architecture == "x86":
            print("  setenv.ps1 -Arch x86 → setup_lua.py --skip-env-check --x86")
        else:
            print("  setenv.ps1 -Arch amd64 → setup_lua.py --skip-env-check (x64 is default)")
        print("")
        return False
    finally:
        # Ensure we're back in the original directory
        try:
            os.chdir(original_cwd)
        except:
            pass


def call_check_env_bat_script():
    """Call the check_env.bat script to verify the environment."""
    current_dir = os.path.dirname(os.path.abspath(__file__))
    check_env_script = os.path.join(current_dir, "check-env.bat")

    if not os.path.exists(check_env_script):
        print("[WARNING] check-env.bat script not found. Skipping environment check.")
        return True

    print("[INFO] Checking Visual Studio environment...")
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
            print("[OK] Visual Studio environment is properly configured.")
            return True
        else:
            print("[ERROR] Visual Studio environment issues detected:")
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

            print("\n[INFO] To fix these issues:")
            print("1. Run this script from a Visual Studio Developer Command Prompt")
            print("2. Or run the Visual Studio environment setup manually:")
            print("   \"C:\\Program Files\\Microsoft Visual Studio\\2022\\Community\\VC\\Auxiliary\\Build\\vcvars64.bat\"")
            print("   (adjust path based on your VS edition)")

            return False

    except Exception as e:
        print(f"[WARNING] Could not run environment check: {e}")
        print("[INFO] Proceeding anyway, but build may fail if environment is not set up correctly.")
        return True


def download_sources():
    """Download and extract Lua and LuaRocks sources."""
    current_dir = os.path.dirname(os.path.abspath(__file__))
    download_script = os.path.join(current_dir, "download_lua_luarocks.py")

    print("[INFO] Downloading sources...")
    subprocess.run([sys.executable, download_script], check=True)


def setup_build_scripts(with_dll=False, with_debug=False):
    """Copy build scripts to extracted directories."""
    current_dir = os.path.dirname(os.path.abspath(__file__))
    setup_build_script = os.path.join(current_dir, "setup_build.py")

    print("[INFO] Setting up build scripts...")
    setup_build_args = [sys.executable, setup_build_script]
    if with_dll:
        setup_build_args.append("--dll")
    if with_debug:
        setup_build_args.append("--debug")
    subprocess.run(setup_build_args, check=True)


def build_lua(installation_path, with_dll=False, with_debug=False):
    """Build and install Lua to the specified path."""
    current_dir = os.path.dirname(os.path.abspath(__file__))
    build_script = os.path.join(current_dir, "build.py")

    print(f"[INFO] Building and installing to {installation_path}...")
    build_args = [sys.executable, build_script, "--prefix", str(installation_path)]
    if with_dll:
        build_args.append("--dll")
    if with_debug:
        build_args.append("--debug")
    subprocess.run(build_args, check=True)


def test_lua_build(installation_path, lua_version, run_tests=True):
    """Test the Lua build by running basic commands and test suite."""
    lua_exe = Path(installation_path) / "bin" / "lua.exe"

    if not lua_exe.exists():
        print(f"[ERROR] lua.exe not found at {lua_exe}")
        return False

    print(f"[TEST] Testing Lua {lua_version} installation...")

    try:
        # Test 1: Check Lua version
        print("[INFO] Checking Lua version...")
        result = subprocess.run([str(lua_exe), "-v"],
                              capture_output=True, text=True, check=True)
        print(f"  {result.stderr.strip()}")  # Lua version goes to stderr

        # Test 2: Basic Lua execution
        print("[INFO] Testing basic Lua execution...")
        result = subprocess.run([str(lua_exe), "-e", "print('Hello from Lua!')"],
                              capture_output=True, text=True, check=True)
        print(f"  Output: {result.stdout.strip()}")

        # Test 3: Run test suite if requested
        if run_tests:
            current_dir = os.path.dirname(os.path.abspath(__file__))
            tests_dir = Path(current_dir) / "extracted" / get_lua_tests_dir_name()
            if tests_dir.exists():
                print(f"[TEST] Running Lua {lua_version} basic test suite...")
                print("[INFO] Running basic tests (_U=true flag) - some warnings are normal.")

                original_cwd = os.getcwd()
                abs_lua_exe = os.path.abspath(lua_exe)

                try:
                    os.chdir(tests_dir)
                    print("[INFO] Running: lua.exe -e \"_U=true\" all.lua (Basic Test Suite)")
                    result = subprocess.run([abs_lua_exe, "-e", "_U=true", "all.lua"],
                                          capture_output=True, text=True, timeout=300)

                    if result.returncode == 0:
                        print("[PASS] Basic test suite completed successfully!")
                        lines = result.stdout.split('\n')
                        for line in lines[-10:]:
                            if line.strip():
                                print(f"  {line}")
                    else:
                        print("[WARN] Basic test suite completed with issues:")
                        print("  STDOUT:")
                        for line in result.stdout.split('\n')[-20:]:
                            if line.strip():
                                print(f"    {line}")
                        print("  STDERR:")
                        for line in result.stderr.split('\n')[-10:]:
                            if line.strip():
                                print(f"    {line}")

                        print(f"\n[TIP] Some test failures are common on Windows for Lua {lua_version}.")
                        print("  These are common for x86 builds and builds with --debug flag.")
                        print("  Your Lua build is likely fine for normal use.")
                        return False

                finally:
                    os.chdir(original_cwd)
            else:
                print(f"[WARN] Tests directory {tests_dir} not found.")
                return False
        else:
            print("[INFO] Skipping test suite (remove --skip-tests flag to enable)")

        print("[PASS] Basic Lua functionality test passed!")
        return True

    except subprocess.CalledProcessError as e:
        print(f"[ERROR] Error testing Lua: {e}")
        return False
    except subprocess.TimeoutExpired:
        print("[WARN] Test suite timed out (took more than 5 minutes)")
        return False
    except Exception as e:
        print(f"[ERROR] Unexpected error testing Lua: {e}")
        return False


def create_installation(lua_version, luarocks_version, build_type, build_config,
                       name=None, alias=None, architecture="x64", skip_env_check=False, skip_tests=False):
    """Create a new Lua installation in the LuaEnv system."""

    # Initialize registry
    registry = LuaEnvRegistry()

    # Check environment unless explicitly skipped
    if not skip_env_check:
        env_set = setenv(architecture)
        if not env_set:
            print("[WARNING] Failed to set environment variables from setenv.ps1.")

        env_ok = call_check_env_bat_script()
        if not env_ok:
            print("\n[ERROR] Environment check failed. Build may not succeed.")
            response = input("Do you want to continue anyway? (y/N): ").strip().lower()
            if response not in ['y', 'yes']:
                print("[INFO] Setup cancelled. Please fix the environment issues and try again.")
                return None
            print("[INFO] Continuing with potentially problematic environment...")

    # Create installation record in registry
    print(f"[INFO] Creating new installation: Lua {lua_version}, LuaRocks {luarocks_version}")
    print(f"[INFO] Build: {build_type} {build_config}")

    installation_id = registry.create_installation(
        lua_version=lua_version,
        luarocks_version=luarocks_version,
        build_type=build_type,
        build_config=build_config,
        architecture=architecture,
        name=name,
        alias=alias
    )

    installation = registry.get_installation(installation_id)
    installation_path = Path(installation["installation_path"])

    try:
        # Step 1: Download sources
        download_sources()

        # Step 2: Setup build scripts
        setup_build_scripts(
            with_dll=(build_type == "dll"),
            with_debug=(build_config == "debug")
        )

        # Step 3: Build and install
        build_lua(
            installation_path,
            with_dll=(build_type == "dll"),
            with_debug=(build_config == "debug")
        )

        # Step 4: Test installation
        if not skip_tests:
            print("\n" + "="*60)
            print("TESTING INSTALLATION")
            print("="*60)
            test_success = test_lua_build(installation_path, lua_version, run_tests=True)
            if not test_success:
                print("\n[WARN] Some tests failed, but installation may still be usable.")
            else:
                print("\n[SUCCESS] All tests passed!")
        else:
            # Run minimal test even when tests are skipped
            test_success = test_lua_build(installation_path, lua_version, run_tests=False)
            if not test_success:
                print("[ERROR] Basic functionality test failed.")
                registry.update_status(installation_id, "broken")
                return installation_id

        # Mark installation as active
        registry.update_status(installation_id, "active")

        print(f"\n[SUCCESS] Installation completed!")
        print(f"[INFO] Installation ID: {installation_id}")
        print(f"[INFO] Installation path: {installation_path}")
        if alias:
            print(f"[INFO] Alias: {alias}")

        return installation_id

    except Exception as e:
        print(f"\n[ERROR] Installation failed: {e}")
        # Mark installation as broken but don't remove it (user can debug)
        registry.update_status(installation_id, "broken")

        # Automatically cleanup broken installations (silent)
        print("[INFO] Running automatic cleanup...")
        try:
            cleaned_count = registry.cleanup_broken(confirm=False)
            if cleaned_count > 0:
                print(f"[INFO] Automatically cleaned up {cleaned_count} broken installations")
            else:
                print("[INFO] No broken installations to clean up")
        except Exception as cleanup_error:
            print(f"[WARN] Cleanup failed: {cleanup_error}")

        return installation_id


def list_installations():
    """List all installations in the registry."""
    registry = LuaEnvRegistry()
    installations = registry.list_installations()

    if not installations:
        print("[INFO] No installations found")
        return

    default = registry.get_default()
    print(f"[INFO] Found {len(installations)} installations:")
    print()

    for installation in installations:
        is_default = default and installation["id"] == default["id"]
        status_mark = "[DEFAULT]" if is_default else f"[{installation['status'].upper()}]"
        alias_info = f" (alias: {installation['alias']})" if installation['alias'] else ""

        print(f"  {status_mark} {installation['name']}{alias_info}")
        print(f"    ID: {installation['id']}")
        print(f"    Lua: {installation['lua_version']}, LuaRocks: {installation['luarocks_version']}")
        # Handle backward compatibility for installations without architecture field
        arch_info = installation.get('architecture', 'x64')
        print(f"    Build: {installation['build_type']} {installation['build_config']} ({arch_info})")
        print(f"    Path: {installation['installation_path']}")
        if installation['last_used']:
            print(f"    Last used: {installation['last_used']}")
        print()


def backup_config():
    """Backup the current config file."""
    config_file = Path(__file__).parent / "build_config.txt"
    backup_file = Path(__file__).parent / "build_config.txt.backup"

    if config_file.exists():
        import shutil
        shutil.copy2(str(config_file), str(backup_file))
        return True
    return False


def restore_config():
    """Restore the backed up config file."""
    config_file = Path(__file__).parent / "build_config.txt"
    backup_file = Path(__file__).parent / "build_config.txt.backup"

    if backup_file.exists():
        import shutil
        shutil.copy2(str(backup_file), str(config_file))
        backup_file.unlink()  # Remove backup file
        return True
    return False


def create_temp_config(lua_version=None, luarocks_version=None, architecture=None):
    """Create a temporary config with specified versions and architecture."""
    config_file = Path(__file__).parent / "build_config.txt"

    # Read current config or use defaults
    current_config = {}
    if config_file.exists():
        try:
            with open(config_file, 'r', encoding='utf-8') as f:
                for line in f:
                    line = line.strip()
                    if line and not line.startswith('#') and '=' in line:
                        key, value = line.split('=', 1)
                        current_config[key.strip()] = value.strip()
        except Exception as e:
            print(f"[WARNING] Failed to read current config: {e}")

    # Set defaults if missing
    if 'LUA_VERSION' not in current_config:
        current_config['LUA_VERSION'] = '5.4.8'
    if 'LUA_MAJOR_MINOR' not in current_config:
        current_config['LUA_MAJOR_MINOR'] = '5.4'
    if 'LUAROCKS_VERSION' not in current_config:
        current_config['LUAROCKS_VERSION'] = '3.12.2'
    if 'LUAROCKS_PLATFORM' not in current_config:
        current_config['LUAROCKS_PLATFORM'] = 'windows-64'

    # Override with provided versions
    if lua_version:
        current_config['LUA_VERSION'] = lua_version
        # Extract major.minor from version (e.g., "5.4.7" -> "5.4")
        try:
            parts = lua_version.split('.')
            if len(parts) >= 2:
                current_config['LUA_MAJOR_MINOR'] = f"{parts[0]}.{parts[1]}"
        except:
            pass

    if luarocks_version:
        current_config['LUAROCKS_VERSION'] = luarocks_version

    # Set LUAROCKS_PLATFORM based on architecture
    if architecture:
        if architecture == "x86":
            current_config['LUAROCKS_PLATFORM'] = 'windows-32'
            print(f"[INFO] Architecture x86 detected: Setting LUAROCKS_PLATFORM to windows-32")
        elif architecture == "x64":
            current_config['LUAROCKS_PLATFORM'] = 'windows-64'
            print(f"[INFO] Architecture x64 detected: Setting LUAROCKS_PLATFORM to windows-64")
        else:
            print(f"[WARNING] Unknown architecture '{architecture}', keeping default LUAROCKS_PLATFORM")

    # Write temporary config
    try:
        with open(config_file, 'w', encoding='utf-8') as f:
            f.write("# Temporary configuration file for per-installation versions\n")
            f.write("# This file was automatically generated - do not edit manually\n")
            f.write("\n")
            for key, value in current_config.items():
                f.write(f"{key}={value}\n")
        return True
    except Exception as e:
        print(f"[ERROR] Failed to create temporary config: {e}")
        return False


def remove_installation(id_or_alias):
    """Remove an installation from the registry and filesystem."""
    registry = LuaEnvRegistry()
    return registry.remove_installation(id_or_alias, confirm=True)


def main():
    """Command line interface."""
    parser = argparse.ArgumentParser(
        description="LuaEnv Setup - UUID-based Lua installation system",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  python setup_lua.py                                    # Create installation with current config
  python setup_lua.py --dll                              # Create DLL build
  python setup_lua.py --debug                            # Create debug build
  python setup_lua.py --x86                              # Create x86 (32-bit) build
  python setup_lua.py --dll --debug                      # Create DLL debug build
  python setup_lua.py --x86 --dll                        # Create x86 DLL build
  python setup_lua.py --name "Development" --alias dev   # Create with custom name and alias
  python setup_lua.py --lua-version 5.4.7 --alias dev   # Use specific Lua version
  python setup_lua.py --luarocks-version 3.11.1          # Use specific LuaRocks version
  python setup_lua.py --list                             # List all installations
  python setup_lua.py --remove dev                       # Remove installation by alias
  python setup_lua.py --remove a1b2c3d4                  # Remove by partial UUID

Manual Environment Setup (if automatic setup fails):
  %USERPROFILE%\\.luaenv\\bin\\setenv.ps1 -Arch amd64 -Current  # Setup x64 environment manually
  python setup_lua.py --skip-env-check [options]               # Then run installation (x64 is default)

  %USERPROFILE%\\.luaenv\\bin\\setenv.ps1 -Arch x86 -Current   # Setup x86 environment manually
  python setup_lua.py --skip-env-check --x86 [options]        # Then run x86 installation (MUST include --x86 flag)

  For first install before .luaenv exists:
  .\\backend\\setenv.ps1 -Arch amd64 -Current                  # Setup x64 environment manually
  .\\backend\\setenv.ps1 -Arch x86 -Current                    # Setup x86 environment manually

  IMPORTANT: When using manual environment setup, ensure the architecture flag matches:
  - If you ran setenv.ps1 with -Arch amd64, omit --x86 flag (x64 is default)
  - If you ran setenv.ps1 with -Arch x86, MUST include --x86 flag for correct registry

Build Types:
  Static Release:  Optimized static library build (default)
  DLL Release:     Optimized DLL build (--dll)
  Static Debug:    Unoptimized static build with debug symbols (--debug)
  DLL Debug:       Unoptimized DLL build with debug symbols (--dll --debug)

Architectures:
  x64:             64-bit build (default) - uses vcvars64.bat
  x86:             32-bit build (--x86) - uses vcvars32.bat

All installations are stored in %USERPROFILE%\\.luaenv\\
Each installation gets a unique UUID for identification.
        """
    )

    # Main commands
    parser.add_argument("--list", action="store_true",
                       help="List all installations")
    parser.add_argument("--remove", metavar="ID_OR_ALIAS",
                       help="Remove installation by ID or alias")

    # Build configuration
    parser.add_argument("--dll", action="store_true",
                       help="Create DLL build instead of static build")
    parser.add_argument("--debug", action="store_true",
                       help="Create debug build with debug symbols")
    parser.add_argument("--x86", action="store_true",
                       help="Create x86 (32-bit) build instead of x64 (64-bit) build (must match setenv.ps1 -Arch x86 if using manual setup)")

    # Version configuration
    parser.add_argument("--lua-version", metavar="VERSION",
                       help="Lua version to use for this installation (e.g., 5.4.7, 5.3.6)")
    parser.add_argument("--luarocks-version", metavar="VERSION",
                       help="LuaRocks version to use for this installation (e.g., 3.11.1, 3.10.0)")

    # Installation metadata
    parser.add_argument("--name", help="Descriptive name for the installation")
    parser.add_argument("--alias", help="Short alias for the installation")

    # Build options
    parser.add_argument("--skip-env-check", action="store_true",
                       help="Skip Visual Studio environment check (use after running %USERPROFILE%\\.luaenv\\bin\\setenv.ps1 - ensure architecture flags match)")
    parser.add_argument("--skip-tests", action="store_true",
                       help="Skip test suite after building")

    args = parser.parse_args()

    # Show current configuration from build_config.txt
    print(f"Current Configuration (from build_config.txt):")
    print(f"  Lua: {LUA_VERSION}")
    print(f"  LuaRocks: {LUAROCKS_VERSION} ({LUAROCKS_PLATFORM})")
    print()

    # Handle list command
    if args.list:
        list_installations()
        return

    # Handle remove command
    if args.remove:
        success = remove_installation(args.remove)
        sys.exit(0 if success else 1)

    # Handle create installation (default action)
    print("LuaEnv Setup - Creating New Installation")
    print("="*50)

    # Handle version parameters
    config_modified = False

    # Determine architecture early for potential config modification
    architecture = "x86" if args.x86 else "x64"

    if args.lua_version or args.luarocks_version or args.x86:
        print("[INFO] Using custom configuration for this installation")
        if args.lua_version:
            print(f"  Lua version: {args.lua_version}")
        if args.luarocks_version:
            print(f"  LuaRocks version: {args.luarocks_version}")
        if args.x86:
            print(f"  Architecture: x86 (32-bit) - will use windows-32 platform")

        # Backup current config and create temporary config
        if backup_config():
            print("[INFO] Current config backed up")

        if create_temp_config(args.lua_version, args.luarocks_version, architecture):
            print("[INFO] Temporary config created")
            config_modified = True

            # Reload config module to pick up new values
            import importlib
            try:
                from . import config
                importlib.reload(config)
            except ImportError:
                import config
                importlib.reload(config)
        else:
            print("[ERROR] Failed to create temporary config")
            sys.exit(1)

    # Use the final versions (either from temp config or original)
    if config_modified:
        # If we reloaded config, get values from the config module
        try:
            from . import config
            final_lua_version = args.lua_version or config.LUA_VERSION
            final_luarocks_version = args.luarocks_version or config.LUAROCKS_VERSION
        except ImportError:
            import config
            final_lua_version = args.lua_version or config.LUA_VERSION
            final_luarocks_version = args.luarocks_version or config.LUAROCKS_VERSION
    else:
        # Use original imported values
        final_lua_version = args.lua_version or LUA_VERSION
        final_luarocks_version = args.luarocks_version or LUAROCKS_VERSION

    print(f"Configuration: Lua {final_lua_version}, LuaRocks {final_luarocks_version}")

    # Determine build type (architecture already determined above)
    build_type = "dll" if args.dll else "static"
    build_config = "debug" if args.debug else "release"

    # Generate default name if not provided
    if not args.name:
        arch_display = "x86" if args.x86 else "x64"
        args.name = f"Lua {final_lua_version} {build_type.upper()} {build_config.title()} ({arch_display})"

    print(f"Build type: {build_type} {build_config}")
    print(f"Architecture: {architecture}")
    print(f"Name: {args.name}")
    if args.alias:
        print(f"Alias: {args.alias}")
    if args.skip_env_check:
        arch_param = "x86" if args.x86 else "amd64"
        print(f"Environment check: Skipped")
        print(f"  Ensure you ran: %USERPROFILE%\\.luaenv\\bin\\setenv.ps1 -Arch {arch_param} -Current")
        print(f"  Architecture match: setenv.ps1 -Arch {arch_param} ↔ setup_lua.py {'--x86' if args.x86 else '(default x64)'}")
    if args.skip_tests:
        print("Test suite: Skipped")
    print()

    try:
        # Create installation
        installation_id = create_installation(
            lua_version=final_lua_version,
            luarocks_version=final_luarocks_version,
            build_type=build_type,
            build_config=build_config,
            architecture=architecture,
            name=args.name,
            alias=args.alias,
            skip_env_check=args.skip_env_check,
            skip_tests=args.skip_tests
        )

        if installation_id:
            print(f"\n[SUCCESS] Installation created with ID: {installation_id}")
            print(f"[INFO] Use 'python use_lua.py {args.alias or installation_id}' to activate this installation")
            exit_code = 0
        else:
            print("[ERROR] Installation failed")
            exit_code = 1

    finally:
        # Final cleanup safety net - ensure no broken installations remain
        try:
            registry = LuaEnvRegistry()
            cleaned_count = registry.cleanup_broken(confirm=False)
            if cleaned_count > 0:
                print(f"[INFO] Final cleanup removed {cleaned_count} broken installations")
            else:
                print("[INFO] No broken installations to clean up in the final cleanup")
        except Exception:
            print("[WARNING] Final cleanup failed, you may need to run cleanup manually")
            pass  # Silent failure - don't let cleanup errors affect the main operation
        # Restore original config if we modified it
        if config_modified:
            if restore_config():
                print("[INFO] Original config restored")
            else:
                print("[WARNING] Failed to restore original config")
    sys.exit(exit_code)

if __name__ == "__main__":
    main()
