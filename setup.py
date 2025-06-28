"""
SETUP script

"""

import os
import shutil
import subprocess
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
                print("✓ Visual Studio environment is properly configured.")
                return True
            else:
                print("✗ Visual Studio environment issues detected:")
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
    subprocess.run(["python", download_script], check=True)

    if not with_dll:
        print(f"Setting up for static build to {prefix}...")

        # Run setup build scrips
        setup_build_script = os.path.join(current_dir, "setup_build.py")
        subprocess.run(["python", setup_build_script], check=True)

        # Run build script with prefix
        build_script = os.path.join(current_dir, "build.py")
        subprocess.run(["python", build_script, "--prefix", prefix], check=True)
    else:
        print(f"Setting up for DLL build to {prefix}...")

        # Run setup build scrips with DLL option
        setup_build_script = os.path.join(current_dir, "setup_build.py")
        subprocess.run(["python", setup_build_script, "--dll"], check=True)

        # Run build script with DLL option and prefix
        build_script = os.path.join(current_dir, "build.py")
        subprocess.run(["python", build_script, "--dll", "--prefix", prefix], check=True)

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

    return True


if __name__ == "__main__":
    import argparse

    parser = argparse.ArgumentParser(
        description="Master setup script for Lua and LuaRocks.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  python setup.py                                      # Static build to ./inst/lua
  python setup.py --dll                                # DLL build to ./inst/lua
  python setup.py --prefix C:\\lua                     # Static build to C:\\lua
  python setup.py --dll --prefix C:\\Development\\Lua  # DLL build to C:\\Development\\Lua
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

    args = parser.parse_args()

    print(f"Master setup with the following options:")
    print(f"  Build type: {'DLL' if args.dll else 'Static'}")
    print(f"  Install directory: {args.prefix}")
    if args.skip_env_check:
        print(f"  Environment check: Skipped")
    print()

    success = run_setup(with_dll=args.dll, prefix=args.prefix, skip_env_check=args.skip_env_check)
    if not success:
        exit(1)