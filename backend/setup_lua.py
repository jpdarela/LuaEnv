# -*- coding: utf-8 -*-

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
        LUA_VERSION, LUAROCKS_VERSION
    )
    from .registry import LuaEnvRegistry
    from .utils import info, warning, error, debug, log_with_location

except ImportError:
    from config import (
        get_lua_tests_dir_name,
        LUA_VERSION, LUAROCKS_VERSION
    )
    from registry import LuaEnvRegistry
    from utils import info, warning, error, debug, log_with_location
    from utils import info, warning, error, debug, log_with_location


def try_powershell_setenv(architecture="x64"):
    """Try to set Visual Studio environment using PowerShell setenv.ps1."""
    # Map Python architecture to PowerShell architecture parameter
    ps_arch = "x86" if architecture == "x86" else "amd64"

    # Find setenv.ps1 script
    script_paths = [
        os.path.join(os.environ.get('USERPROFILE', ''), '.luaenv', 'bin', 'setenv.ps1'),
        os.path.join(os.path.dirname(__file__), 'setenv.ps1'),
        os.path.join(os.path.dirname(__file__), '..', 'setenv.ps1'),
        'setenv.ps1'
    ]

    setenv_script = None
    for path in script_paths:
        if os.path.exists(path):
            setenv_script = os.path.abspath(path)
            break

    if not setenv_script:
        return False

    try:
        # Create a temporary PowerShell script
        import tempfile
        script_dir = os.path.dirname(setenv_script)
        with tempfile.NamedTemporaryFile(mode='w', suffix='.ps1', delete=False) as f:
            f.write(f'''
Set-Location "{script_dir}"
& "{setenv_script}" -Arch {ps_arch} -Current
Get-ChildItem env: | ForEach-Object {{
    Write-Output "$($_.Name)=$($_.Value)"
}}
''')
            temp_ps_script = f.name

        # Execute PowerShell script
        result = subprocess.run(
            ['powershell', '-ExecutionPolicy', 'Bypass', '-File', temp_ps_script],
            capture_output=True,
            text=True,
            cwd=script_dir
        )

        info(f"PowerShell setenv exit code: {result.returncode}")
        if result.stderr:
            debug(f"PowerShell setenv stderr: {result.stderr}")

        # Debug: Show first few lines of stdout to see what PowerShell is outputting
        stdout_lines = result.stdout.strip().split('\n')[:10]
        debug(f"PowerShell setenv stdout (first 10 lines): {stdout_lines}")

        if result.returncode == 0:
            # Apply environment variables
            vs_vars_found = []
            env_vars_set = 0
            for line in result.stdout.strip().split('\n'):
                if '=' in line:
                    key, value = line.split('=', 1)
                    if key.upper() not in ['PSModulePath', 'PYTHONPATH', 'PYTHONHOME', 'PROMPT']:
                        os.environ[key] = value
                        env_vars_set += 1
                        # Track VS-specific variables
                        if key.upper() in ['VCINSTALLDIR', 'INCLUDE', 'LIB', 'LIBPATH', 'WINDOWSSDKDIR']:
                            vs_vars_found.append(f"{key}={value[:50]}...")

            debug(f"PowerShell setenv applied {env_vars_set} environment variables")
            if vs_vars_found:
                debug(f"VS variables found: {vs_vars_found}")
            else:
                debug(f"No VS-specific variables found in PowerShell output")

            return True

        return False

    except:
        return False
    finally:
        try:
            os.unlink(temp_ps_script)
        except:
            pass


def python_setenv_enhanced(architecture="x64"):
    """Enhanced Python implementation with multiple detection methods."""
    # Save current working directory
    original_cwd = os.getcwd()

    # Choose the appropriate vcvars batch file
    if architecture == "x86":
        vcvars_filename = "vcvars32.bat"
        arch_display = "x86 (32-bit)"
    else:
        vcvars_filename = "vcvars64.bat"
        arch_display = "x64 (64-bit)"

    # Helper function to run vcvars and capture environment
    def run_vcvars_and_capture_env(vcvars_path, original_cwd, arch_display):
        try:
            import tempfile
            with tempfile.NamedTemporaryFile(mode='w', suffix='.bat', delete=False) as f:
                f.write(f'''@echo off
cd /d "{original_cwd}"
call "{vcvars_path}" >nul 2>&1
if errorlevel 1 (
    echo VCVARS_FAILED
    exit 1
)
cd /d "{original_cwd}"
set
''')
                temp_file = f.name

            try:
                result = subprocess.run([temp_file], capture_output=True, text=True, shell=True, cwd=original_cwd)

                if result.returncode == 0 and "VCVARS_FAILED" not in result.stdout:
                    # Apply environment variables
                    env_vars_set = 0
                    for line in result.stdout.strip().split('\n'):
                        if '=' in line and not line.startswith('VCVARS_FAILED'):
                            key, value = line.split('=', 1)
                            if key.upper() not in ['PSModulePath', 'PYTHONPATH', 'PYTHONHOME', 'PROMPT']:
                                os.environ[key] = value
                                env_vars_set += 1

                    log_with_location(f"Applied {env_vars_set} environment variables from Visual Studio", "OK")
                    info(f"Target architecture: {arch_display}")
                    return True
            finally:
                try:
                    os.unlink(temp_file)
                except:
                    pass
        except:
            pass

        return False

    # Method 1: Try vswhere.exe first
    vswhere_paths = [
        # Standard installer locations
        r"C:\Program Files (x86)\Microsoft Visual Studio\Installer\vswhere.exe",
        r"C:\Program Files\Microsoft Visual Studio\Installer\vswhere.exe",
        os.path.join(os.environ.get('ProgramData', ''), 'Microsoft', 'VisualStudio', 'Packages', '_Instances', 'vswhere.exe'),

        # Chocolatey installation
        os.path.join(os.environ.get('ChocolateyInstall', ''), 'lib', 'vswhere', 'tools', 'vswhere.exe'),
        os.path.join(os.environ.get('ProgramData', ''), 'chocolatey', 'lib', 'vswhere', 'tools', 'vswhere.exe'),
        r"C:\ProgramData\chocolatey\lib\vswhere\tools\vswhere.exe",

        # Scoop installation
        os.path.join(os.environ.get('SCOOP', ''), 'apps', 'vswhere', 'current', 'vswhere.exe'),
        os.path.join(os.environ.get('USERPROFILE', ''), 'scoop', 'apps', 'vswhere', 'current', 'vswhere.exe'),
        os.path.join(os.environ.get('SCOOP_GLOBAL', ''), 'apps', 'vswhere', 'current', 'vswhere.exe'),
        os.path.join(os.environ.get('ProgramData', ''), 'scoop', 'apps', 'vswhere', 'current', 'vswhere.exe'),

        # NuGet tools location - removed wildcard path
        # os.path.join(os.environ.get('USERPROFILE', ''), '.nuget', 'packages', 'vswhere', '*', 'tools', 'vswhere.exe'),
        os.path.join(os.environ.get('ProgramFiles(x86)', ''), 'Microsoft Visual Studio', 'Shared', 'vswhere', 'vswhere.exe'),

        # Build tools specific locations
        os.path.join(os.environ.get('ProgramFiles(x86)', ''), 'Microsoft Visual Studio', '2022', 'BuildTools', 'Installer', 'vswhere.exe'),
        os.path.join(os.environ.get('ProgramFiles(x86)', ''), 'Microsoft Visual Studio', '2019', 'BuildTools', 'Installer', 'vswhere.exe'),
        os.path.join(os.environ.get('ProgramFiles(x86)', ''), 'Microsoft Visual Studio', '2017', 'BuildTools', 'Installer', 'vswhere.exe'),

        # Alternative VS installer locations
        os.path.join(os.environ.get('ProgramFiles', ''), 'Microsoft Visual Studio', 'Shared', 'Installer', 'vswhere.exe'),
        os.path.join(os.environ.get('ProgramFiles(x86)', ''), 'Microsoft Visual Studio', 'Shared', 'Installer', 'vswhere.exe'),

        # Custom tools directories
        r"C:\Tools\vswhere\vswhere.exe",
        r"D:\Tools\vswhere\vswhere.exe",

        # Developer command prompt tools
        os.path.join(os.environ.get('VSINSTALLDIR', ''), 'Installer', 'vswhere.exe'),
        os.path.join(os.environ.get('VS170COMNTOOLS', ''), '..', '..', 'Installer', 'vswhere.exe'),
        os.path.join(os.environ.get('VS160COMNTOOLS', ''), '..', '..', 'Installer', 'vswhere.exe'),

        # Portable/standalone locations
        os.path.join(os.environ.get('USERPROFILE', ''), 'Downloads', 'vswhere.exe'),
        os.path.join(os.environ.get('USERPROFILE', ''), 'vswhere', 'vswhere.exe'),
        os.path.join(os.environ.get('LOCALAPPDATA', ''), 'vswhere', 'vswhere.exe'),

        # CI/CD common locations
        r"C:\vswhere\vswhere.exe",
        r"C:\BuildTools\vswhere.exe"
    ]

    for vswhere_path in vswhere_paths:
        if os.path.exists(vswhere_path):
            try:
                result = subprocess.run(
                    [vswhere_path, '-all', '-prerelease', '-products', '*', '-property', 'installationPath'],
                    capture_output=True,
                    text=True
                )

                if result.returncode == 0 and result.stdout.strip():
                    for install_path in result.stdout.strip().split('\n'):
                        if os.path.exists(install_path):
                            vcvars_path = os.path.join(install_path, "VC", "Auxiliary", "Build", vcvars_filename)
                            if os.path.exists(vcvars_path):
                                log_with_location(f"Found Visual Studio via vswhere: {install_path}", "OK")
                                return run_vcvars_and_capture_env(vcvars_path, original_cwd, arch_display)
            except:
                pass

    # Method 2: Check saved VS path
    vs_config_file = ".vs_install_path.txt"
    if os.path.exists(vs_config_file):
        try:
            with open(vs_config_file, 'r') as f:
                saved_path = f.read().strip()
                if saved_path:
                    vcvars_path = os.path.join(saved_path, rf"VC\Auxiliary\Build\{vcvars_filename}")
                    if os.path.exists(vcvars_path):
                        info(f"Using saved Visual Studio path: {saved_path}")
                        return run_vcvars_and_capture_env(vcvars_path, original_cwd, arch_display)
        except:
            pass

    # Method 3: Common paths
    vs_paths = [
        rf"C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Auxiliary\Build\{vcvars_filename}",
        rf"C:\Program Files\Microsoft Visual Studio\2022\Professional\VC\Auxiliary\Build\{vcvars_filename}",
        rf"C:\Program Files\Microsoft Visual Studio\2022\Enterprise\VC\Auxiliary\Build\{vcvars_filename}",
        rf"C:\Program Files\Microsoft Visual Studio\2022\BuildTools\VC\Auxiliary\Build\{vcvars_filename}",
        rf"C:\Program Files\Microsoft Visual Studio\2019\Community\VC\Auxiliary\Build\{vcvars_filename}",
        rf"C:\Program Files\Microsoft Visual Studio\2019\Professional\VC\Auxiliary\Build\{vcvars_filename}",
        rf"C:\Program Files\Microsoft Visual Studio\2019\Enterprise\VC\Auxiliary\Build\{vcvars_filename}",
        rf"C:\Program Files\Microsoft Visual Studio\2019\BuildTools\VC\Auxiliary\Build\{vcvars_filename}",
        rf"C:\Program Files (x86)\Microsoft Visual Studio\2022\Community\VC\Auxiliary\Build\{vcvars_filename}",
        rf"C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\VC\Auxiliary\Build\{vcvars_filename}",
        rf"C:\Program Files (x86)\Microsoft Visual Studio\2019\Community\VC\Auxiliary\Build\{vcvars_filename}",
        rf"C:\Program Files (x86)\Microsoft Visual Studio\2019\BuildTools\VC\Auxiliary\Build\{vcvars_filename}",
        rf"C:\Program Files (x86)\Microsoft Visual Studio\2019\Professional\VC\Auxiliary\Build\{vcvars_filename}",
        rf"C:\Program Files (x86)\Microsoft Visual Studio\2019\Enterprise\VC\Auxiliary\Build\{vcvars_filename}",
    ]

    for vcvars_path in vs_paths:
        if os.path.exists(vcvars_path):
            log_with_location(f"Found Visual Studio at: {vcvars_path}", "OK")
            return run_vcvars_and_capture_env(vcvars_path, original_cwd, arch_display)

    return False


def setenv(architecture="x64"):
    """Set Visual Studio environment with PowerShell fallback to Python methods."""
    info(f"Setting up Visual Studio environment for {architecture}...")

    # Try PowerShell method first
    info("Attempting to use PowerShell setenv.ps1 script...")
    if try_powershell_setenv(architecture):
        log_with_location("Successfully configured environment using PowerShell method", "OK")
        arch_display = "x86 (32-bit)" if architecture == "x86" else "x64 (64-bit)"
        info(f"Target architecture: {arch_display}")

        # Verify critical environment variables
        if os.environ.get('VCINSTALLDIR'):
            log_with_location(f"Visual Studio found at: {os.environ.get('VCINSTALLDIR')}", "OK")

        return True

    warning("PowerShell method failed, trying Python detection methods...")

    # Fall back to enhanced Python implementation
    if python_setenv_enhanced(architecture):
        return True

    # If all methods fail, provide detailed instructions
    error(f"Could not find Visual Studio installation for {architecture}")
    print("")
    print("[SOLUTION] To resolve this issue:")
    print("1. Install Visual Studio 2019 or 2022 with C++ development tools")
    print("2. OR use the setenv.ps1 script to manually configure environment:")
    arch_param = "x86" if architecture == "x86" else "amd64"
    print(f"   %USERPROFILE%\\.luaenv\\bin\\setenv.ps1 -Arch {arch_param} -Current")
    print("3. Then run your installation command with --skip-env-check flag:")
    print("   python setup_lua.py --skip-env-check [--x86 for 32-bit]")
    print("")
    print("[IMPORTANT] Architecture flags must match:")
    if architecture == "x86":
        print("  setenv.ps1 -Arch x86 → setup_lua.py --skip-env-check --x86")
    else:
        print("  setenv.ps1 -Arch amd64 → setup_lua.py --skip-env-check (x64 is default)")
    print("")
    warning("Build may fail without Visual Studio environment")

    return False

# Deprecated function TODO exclude in future versions
def call_check_env_bat_script():
    """Call the check_env.bat script to verify the environment."""
    current_dir = os.path.dirname(os.path.abspath(__file__))
    check_env_script = os.path.join(current_dir, "check-env.bat")

    if not os.path.exists(check_env_script):
        warning("check-env.bat script not found. Skipping environment check.")
        return True

    info("Checking Visual Studio environment...")
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
            log_with_location("Visual Studio environment is properly configured.", "OK")
            return True
        else:
            error("Visual Studio environment issues detected:")
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
        warning(f"Could not run environment check: {e}")
        info("Proceeding anyway, but build may fail if environment is not set up correctly.")
        return True


def download_sources():
    """Download and extract Lua and LuaRocks sources."""
    current_dir = os.path.dirname(os.path.abspath(__file__))
    download_script = os.path.join(current_dir, "download_lua_luarocks.py")

    print("[PROGRESS] Starting download process...")
    info("Downloading sources...")
    subprocess.run([sys.executable, download_script], check=True, env=os.environ.copy())
    print("[PROGRESS] Download completed successfully")


def setup_build_scripts(with_dll=False, with_debug=False):
    """Copy build scripts to extracted directories."""
    current_dir = os.path.dirname(os.path.abspath(__file__))
    setup_build_script = os.path.join(current_dir, "setup_build.py")

    print("[PROGRESS] Copying build scripts...")
    info("Setting up build scripts...")
    setup_build_args = [sys.executable, setup_build_script]
    if with_dll:
        setup_build_args.append("--dll")
    if with_debug:
        setup_build_args.append("--debug")
    subprocess.run(setup_build_args, check=True, env=os.environ.copy())
    print("[PROGRESS] Build scripts setup completed")


def build_lua(installation_path, with_dll=False, with_debug=False):
    """Build and install Lua to the specified path."""
    current_dir = os.path.dirname(os.path.abspath(__file__))
    build_script = os.path.join(current_dir, "build.py")

    print("[PROGRESS] Starting compilation process...")
    info(f"Building and installing to {installation_path}...")

    # Debug: Check if VS environment variables are still present before calling build.py
    debug("Key VS environment variables in setup_lua.py before calling build.py:")
    vs_vars = ['VCINSTALLDIR', 'INCLUDE', 'LIB', 'PATH', 'LIBPATH', 'WindowsSdkDir']
    for var in vs_vars:
        value = os.environ.get(var, 'NOT SET')
        if var == 'PATH':
            # Only show first few entries for PATH
            path_entries = value.split(';')[:5] if value != 'NOT SET' else []
            print(f"  {var}: {';'.join(path_entries)}... ({len(path_entries)} entries shown)")
        else:
            print(f"  {var}: {value}")
    print()

    build_args = [sys.executable, build_script, "--prefix", str(installation_path)]
    if with_dll:
        build_args.append("--dll")
    if with_debug:
        build_args.append("--debug")
    subprocess.run(build_args, check=True, env=os.environ.copy())
    print("[PROGRESS] Lua build completed successfully")


def test_lua_build(installation_path, lua_version, run_tests=True):
    """Test the Lua build by running basic commands and test suite."""
    lua_exe = Path(installation_path) / "bin" / "lua.exe"

    if not lua_exe.exists():
        error(f"lua.exe not found at {lua_exe}")
        return False

    log_with_location(f"Testing Lua {lua_version} installation...", "INFO")

    try:
        # Test 1: Check Lua version
        info("Checking Lua version...")
        result = subprocess.run([str(lua_exe), "-v"],
                              capture_output=True, text=True, check=True)
        print(f"  {result.stderr.strip()}")  # Lua version goes to stderr

        # Test 2: Basic Lua execution
        info("Testing basic Lua execution...")
        result = subprocess.run([str(lua_exe), "-e", "print('Hello from Lua!')"],
                              capture_output=True, text=True, check=True)
        print(f"  Output: {result.stdout.strip()}")

        # Test 3: Run test suite if requested
        if run_tests:
            print("[PROGRESS] Running comprehensive test suite...")
            current_dir = os.path.dirname(os.path.abspath(__file__))
            tests_dir = Path(current_dir) / "extracted" / get_lua_tests_dir_name()
            if tests_dir.exists():
                log_with_location(f"Running Lua {lua_version} basic test suite...", "INFO")
                info("Running basic tests (_U=true flag) - some warnings are normal.")

                original_cwd = os.getcwd()
                abs_lua_exe = os.path.abspath(lua_exe)

                try:
                    os.chdir(tests_dir)
                    info("Running: lua.exe -e \"_U=true\" all.lua (Basic Test Suite)")
                    result = subprocess.run([abs_lua_exe, "-e", "_U=true", "all.lua"],
                                          capture_output=True, text=True, timeout=300)

                    if result.returncode == 0:
                        log_with_location("Basic test suite completed successfully!", "OK")
                        lines = result.stdout.split('\n')
                        for line in lines[-10:]:
                            if line.strip():
                                print(f"  {line}")
                    else:
                        warning("Basic test suite completed with issues:")
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
                    print("[PROGRESS] Test suite completed")
            else:
                warning(f"Tests directory {tests_dir} not found.")
                return False
        else:
            print("[PROGRESS] Running basic functionality test...")
            info("Skipping test suite (remove --skip-tests flag to enable)")
            print("[PROGRESS] Basic test completed")

        log_with_location("Basic Lua functionality test passed!", "OK")
        return True

    except subprocess.CalledProcessError as e:
        error(f"Error testing Lua: {e}")
        return False
    except subprocess.TimeoutExpired:
        warning("Test suite timed out (took more than 5 minutes)")
        return False
    except Exception as e:
        error(f"Unexpected error testing Lua: {e}")
        return False


def create_installation(lua_version, luarocks_version, build_type, build_config,
                       name=None, alias=None, architecture="x64", skip_env_check=False, skip_tests=False):
    """Create a new Lua installation in the LuaEnv system."""

    # Initialize registry
    registry = LuaEnvRegistry()

    # Check environment unless explicitly skipped
    if not skip_env_check:
        print("[PROGRESS] Setting up Visual Studio environment...")
        env_set = setenv(architecture)
        if not env_set:
            error("Environment setup failed. Build cannot proceed.")
            print("[INFO] To fix this issue:")
            print("1. Install Visual Studio with C++ development tools")
            print("2. OR run the environment setup manually:")
            arch_param = "x86" if architecture == "x86" else "amd64"
            print(f"   luaenv.ps1 -SetupVS -Arch {arch_param}")
            print("3. Then retry the installation with --skip-env-check flag:")
            print(f"   luaenv install --skip-env-check {('--x86' if architecture == 'x86' else '')}")
            error("Installation cancelled due to environment setup failure.")
            return None

    # Create installation record in registry
    info(f"Creating new installation: Lua {lua_version}, LuaRocks {luarocks_version}")
    info(f"Build: {build_type} {build_config}")

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
        print("[PROGRESS] Downloading Lua sources...")
        download_sources()

        # Step 2: Setup build scripts
        print("[PROGRESS] Setting up build scripts...")
        setup_build_scripts(
            with_dll=(build_type == "dll"),
            with_debug=(build_config == "debug")
        )

        # Step 3: Build and install
        print("[PROGRESS] Building Lua with MSVC...")
        build_lua(
            installation_path,
            with_dll=(build_type == "dll"),
            with_debug=(build_config == "debug")
        )

        # Step 4: Test installation
        if not skip_tests:
            print("[PROGRESS] Testing installation...")
            print("\n" + "="*60)
            print("TESTING INSTALLATION")
            print("="*60)
            test_success = test_lua_build(installation_path, lua_version, run_tests=True)
            if not test_success:
                print("\n[WARN] Some tests failed, but installation may still be usable.")
            else:
                log_with_location("All tests passed!", "OK")
        else:
            # Run minimal test even when tests are skipped
            print("[PROGRESS] Running basic validation...")
            test_success = test_lua_build(installation_path, lua_version, run_tests=False)
            if not test_success:
                error("Basic functionality test failed.")
                registry.update_status(installation_id, "broken")
                return installation_id

        # Mark installation as active
        registry.update_status(installation_id, "active")

        print("[PROGRESS] Installation completed successfully!")
        log_with_location("Installation completed!", "OK")
        info(f"Installation ID: {installation_id}")
        info(f"Installation path: {installation_path}")
        if alias:
            info(f"Alias: {alias}")

        return installation_id

    except Exception as e:
        print(f"[PROGRESS] Installation failed: {e}")
        error(f"Installation failed: {e}")
        # Mark installation as broken but don't remove it (user can debug)
        registry.update_status(installation_id, "broken")

        # Automatically cleanup broken installations (silent)
        info("Running automatic cleanup...")
        try:
            cleaned_count = registry.cleanup_broken(confirm=False)
            if cleaned_count > 0:
                info(f"Automatically cleaned up {cleaned_count} broken installations")
            else:
                info("No broken installations to clean up")
        except Exception as cleanup_error:
            warning(f"Cleanup failed: {cleanup_error}")

        return installation_id


def list_installations():
    """List all installations in the registry."""
    registry = LuaEnvRegistry()
    installations = registry.list_installations()

    if not installations:
        info("No installations found")
        return

    default = registry.get_default()
    info(f"Found {len(installations)} installations:")
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
                       help="Create x86 (32-bit) build")

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
                       help="Skip Visual Studio environment check")
    parser.add_argument("--skip-tests", action="store_true",
                       help="Skip test suite after building")

    args = parser.parse_args()

    # # Show current configuration from build_config.txt
    # print(f"Current Configuration (from build_config.txt):")
    # print(f"  Lua: {LUA_VERSION}")
    # print(f"  LuaRocks: {LUAROCKS_VERSION} ({LUAROCKS_PLATFORM})")
    # print()

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
        # # print("[INFO] Using custom configuration for this installation")
        # if args.lua_version:
        #     print(f"  Lua version: {args.lua_version}")
        # if args.luarocks_version:
        #     print(f"  LuaRocks version: {args.luarocks_version}")
        # if args.x86:
        #     print(f"  Architecture: x86 (32-bit) - will use windows-32 platform")

        # Backup current config and create temporary config
        if backup_config():
            # print("[INFO] Current config backed up")
            pass

        if create_temp_config(args.lua_version, args.luarocks_version, architecture):
            # print("[INFO] Temporary config created")
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
        print(f"  Ensure you ran: setenv.ps1 -Arch {arch_param} -Current")
        print(f"  Architecture match: setenv.ps1 -Arch {arch_param} setup_lua.py {'--x86' if args.x86 else '(default x64)'}")
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
            log_with_location(f"Installation created with ID: {installation_id}", "OK")
            info(f"Installation path: {Path.home() / '.luaenv' / 'installations' / installation_id}")
            if args.alias:
                info(f"Alias: {args.alias}")
            print("[INFO] You can now activate this installation using:")
            print("[INFO] luaenv activate <installation_id> or luaenv activate <alias>")
            print("[INFO] Example: luaenv activate " + (args.alias or installation_id[:8]))
            if not args.alias:
                warning(f"Use 'luaenv set-alias {installation_id[:8]} <new_alias>' to give an alias for this installation")
            exit_code = 0
        else:
            error("Installation failed")
            exit_code = 1

    finally:
        # Final cleanup safety net - ensure no broken installations remain
        try:
            registry = LuaEnvRegistry()
            cleaned_count = registry.cleanup_broken(confirm=False)
            if cleaned_count > 0:
                info(f"Final cleanup removed {cleaned_count} broken installations")
            else:
                pass
                # print("[INFO] No broken installations to clean up in the final cleanup")
        except Exception:
            warning("Final cleanup failed, you may need to run cleanup manually")
            pass  # Silent failure - don't let cleanup errors affect the main operation
        # Restore original config if we modified it
        if config_modified:
            if restore_config():
                pass
                # print("[INFO] Original config restored")
            else:
                warning("Failed to restore original config")
    sys.exit(exit_code)

if __name__ == "__main__":
    main()
