# This is free and unencumbered software released into the public domain.
# For more details, see the LICENSE file in the project root.

"""
LuaEnv Installation and Management Script

This script automates the setup and management of the LuaEnv system:
- Uses embedded Python (downloaded via setup.ps1)
- Installs PowerShell scripts via registry.py
- Manages installation directory structure
- Provides verification and status reporting

Usage:
    python install.py                    # Full installation (scripts + CLI)
    python install.py --reset            # Clean reset only (removes .luaenv directory)
    python install.py --status           # Show installation status
    python install.py --scripts          # Install scripts only
    python install.py --cli              # Install CLI binaries only
    python install.py --scripts --force  # Force install scripts, overwriting existing files
    python install.py --cli --force      # Force install CLI binaries, overwriting existing files
    python install.py --force            # Force overwrite existing files (full installation)
    python install.py --help             # Show detailed help and usage information
"""

import sys
import shutil
import subprocess
from pathlib import Path
from typing import Dict
import argparse

# Add the project root to the system path for imports
# This is necessary for the embedded Python to find the backend modules
PROJECT_ROOT = Path(__file__).parent.absolute()
if str(PROJECT_ROOT) not in sys.path:
    sys.path.insert(0, str(PROJECT_ROOT))

# Import backend functionality
from backend.utils import print_message, print_success, print_error, print_warning
from backend.registry import LuaEnvRegistry

# Project structure constants
PROJECT_ROOT = Path(__file__).parent.absolute() # Root directory of the project
BACKEND_DIR = PROJECT_ROOT / "backend" # Directory containing backend modules
CLI_DIR = PROJECT_ROOT / "cli" # Directory containing CLI-related files

# LuaEnv directory structure MATCHES THE DEFAULT IN THE backend.registry.py
LUAENV_DIR = Path.home() / ".luaenv" # Default installation directory
BIN_DIR = LUAENV_DIR / "bin" # Destination for installed scripts and binaries
REGISTRY_FILE = LUAENV_DIR / 'registry.json' # Explicitly set registry file path (this is the default in backend.registry.py)

# Embedded Python paths
PYTHON_DIR = PROJECT_ROOT / "python"
PYTHON_EXE = PYTHON_DIR / "python.exe"

# Default CLI architecture is win64
DEFAULT_CLI_ARCH = 'win64'

# Function to get CLI binaries directory based on architecture
def get_cli_bin_dir(arch: str = DEFAULT_CLI_ARCH) -> Path:
    """Get the CLI binaries directory based on architecture."""
    return PROJECT_ROOT / arch

# Create an instance of LuaEnvRegistry
REGISTRY = LuaEnvRegistry(REGISTRY_FILE)

def get_python_executable() -> str:
    """Get the Python executable to use (embedded first, then system)."""
    if PYTHON_EXE.exists():
        return str(PYTHON_EXE)
    return "python"  # Fallback to system Python

def check_prerequisites() -> bool:
    """Check if all prerequisites are available."""
    print_message("Checking prerequisites...")

    # Check for embedded Python first
    python_exe = get_python_executable()
    if python_exe == str(PYTHON_EXE):
        if not PYTHON_EXE.exists():
            print_error("Embedded Python not found. Run setup.ps1 first to download embedded Python")
            return False
        print_success(f"Using embedded Python: {python_exe}")
    else:
        # Test system Python
        try:
            result = subprocess.run([python_exe, "--version"], capture_output=True, text=True)
            if result.returncode == 0:
                print_warning(f"Using system Python: {result.stdout.strip()}")
                print_message("Consider running setup.ps1 to use embedded Python")
            else:
                print_error("Python not working properly")
                return False
        except FileNotFoundError:
            print_error("No Python found. Run setup.ps1 to download embedded Python")
            return False

    # Check backend directory
    if not BACKEND_DIR.exists():
        print_error(f"Backend directory not found: {BACKEND_DIR}")
        return False

    print_success("All prerequisites available")
    return True

def reset_installation() -> bool:
    """Reset the installation by removing the .luaenv directory."""
    print_message("Resetting installation...")

    if LUAENV_DIR.exists():
        try:
            shutil.rmtree(LUAENV_DIR)
            print_success(f"Removed installation directory: {LUAENV_DIR}")
        except Exception as e:
            print_error(f"Failed to remove installation directory: {e}")
            return False
    else:
        print_message("Installation directory does not exist, nothing to reset")

    return True

def install_scripts(force: bool = False) -> bool:
    """Install PowerShell scripts using the registry directly."""
    print_message("Installing PowerShell scripts...")

    try:
        # Use the registry instance method to install scripts
        scripts_path = REGISTRY.install_scripts(force=force)

        if scripts_path:
            print_success("PowerShell scripts installed successfully")
            print_success(f"Scripts installed to: {scripts_path}")

            # Verify backend.config was created in bin directory only
            backend_config = scripts_path / "backend.config"
            if backend_config.exists():
                print_success(f"Backend configuration created: {backend_config}")
            else:
                print_warning("Backend configuration file not found")

            return True
        else:
            print_error("Failed to install scripts")
            return False

    except Exception as e:
        print_error(f"Failed to install scripts: {e}")
        return False

def install_cli_binaries(force: bool = False, arch: str = "win64") -> bool:
    """Install CLI binaries."""
    print_message(f"Installing CLI binaries for architecture: {arch}...")

    publish_path = get_cli_bin_dir(arch)
    if not publish_path.exists():
        print_error(f"CLI binaries directory does not exist: {publish_path}")
        print_message(f"Run build_cli.ps1 -Target {arch} to generate CLI binaries first")
        return False

    print_success(f"CLI binaries found at: {publish_path}")
    return REGISTRY.install_fsharp_cli_with_deps(publish_dir_path=publish_path, force=force)

def install_all() -> bool:
    """Install all components including scripts and CLI binaries."""
    print_message("Installing all components...")

    # Install PowerShell scripts
    if not install_scripts(force=True):
        print_error("Failed to install PowerShell scripts")
        return False

    # Install CLI binaries
    if not install_cli_binaries(force=True):
        print_error("Failed to install CLI binaries")
        return False

    print_success("All components installed successfully")
    return True

def verify_installation() -> Dict[str, bool]:
    """Verify the installation by checking key components."""
    print_message("Verifying installation...")

    results = {}

    # Check directories
    dirs_to_check = [
        ("Installation directory", LUAENV_DIR),
        ("Bin directory", BIN_DIR),
    ]

    for name, path in dirs_to_check:
        exists = path.exists()
        results[name] = exists
        if exists:
            print_success(f"{name}: {path}")
        else:
            print_error(f"{name} missing: {path}")

    # Check scripts
    scripts_to_check = [
        ("setenv.ps1", BIN_DIR / "setenv.ps1"),
        ("luaenv.ps1", BIN_DIR / "luaenv.ps1")
    ]
    for name, path in scripts_to_check:
        exists = path.exists()
        results[name] = exists
        if exists:
            print_success(f"{name}: {path}")
        else:
            print_error(f"{name} missing: {path}")

    # Check backend configuration (only one in bin directory)
    backend_config = BIN_DIR / "backend.config"
    config_exists = backend_config.exists()
    results["Backend config"] = config_exists
    if config_exists:
        print_success(f"Backend config: {backend_config}")
    else:
        print_error("Backend configuration missing")

    # Verify the cli folder exists
    cli_bin_exists = BIN_DIR / "cli" / "LuaEnv.CLI.exe"
    cli_exists = cli_bin_exists.exists()

    # Overall status
    all_good = all(results.values())
    if all_good:
        print_success("Installation verification completed - all components found")
    else:
        missing_count = sum(1 for result in results.values() if not result)
        print_warning(f"Installation verification found {missing_count} missing components")

    return results

def show_status() -> None:
    """Show detailed installation status."""
    print_message("LuaEnv Installation Status")
    print_message("=" * 50)

    # Python status
    python_exe = get_python_executable()
    if python_exe == str(PYTHON_EXE):
        if PYTHON_EXE.exists():
            try:
                result = subprocess.run([python_exe, "--version"], capture_output=True, text=True)
                if result.returncode == 0:
                    print_success(f"Embedded Python: {result.stdout.strip()}")
                else:
                    print_error("Embedded Python not working")
            except:
                print_error("Embedded Python error")
        else:
            print_error("Embedded Python missing")
    else:
        print_warning(f"Using system Python: {python_exe}")

    # Installation directory status
    if LUAENV_DIR.exists():
        print_success(f"Installation directory: {LUAENV_DIR}")

        # Count files and directories
        try:
            total_files = sum(1 for _ in LUAENV_DIR.rglob('*') if _.is_file())
            total_dirs = sum(1 for _ in LUAENV_DIR.rglob('*') if _.is_dir())
            print_message(f"  Files: {total_files}, Directories: {total_dirs}")
        except:
            pass
    else:
        print_error(f"Installation directory not found: {LUAENV_DIR}")

    # Verify components
    verify_installation()

def main():
    """Main installation function."""
    parser = argparse.ArgumentParser(
        description="LuaEnv Installation Script",
        epilog="Use --help for detailed usage information"
    )
    parser.add_argument("--reset", action="store_true", help="Clean reset only (removes .luaenv directory)")
    parser.add_argument("--status", action="store_true", help="Show installation status only")
    parser.add_argument("--scripts", action="store_true", help="Install PowerShell scripts only")
    parser.add_argument("--cli", action="store_true", help="Install CLI binaries only")
    parser.add_argument("--force", action="store_true", help="Force overwrite existing files")
    parser.add_argument("--arch", choices=["win64", "win-arm64", "win-x86"], default="win64",
                        help="Architecture for CLI binaries (default: win64)")

    args = parser.parse_args()

    print_message("LuaEnv Installation Script")
    print_message("=" * 50)

    # Show status only
    if args.status:
        show_status()
        return

    # Check prerequisites
    if not check_prerequisites():
        print_error("Prerequisites check failed")
        sys.exit(1)

    # Reset if requested
    # We dont want to continue with installation if reset is requested
    # We only delete the .luaenv directory and exit. THe registry does the installation
    if args.reset:
        if not reset_installation():
            print_error("Reset failed")
            sys.exit(1)
        print_success("Reset completed successfully")
        return  # Exit after reset, don't continue with installation


    # Install CLI binaries if requested
    if args.cli:
        if install_cli_binaries(force=args.force):
            print_success("CLI binaries installation completed")
            return
        else:
            print_error("CLI binaries installation failed")
            sys.exit(1)

    # Install scripts only if requested
    if args.scripts:
        if install_scripts(force=args.force):
            print_success("Scripts installation completed")
            return
        else:
            print_error("Scripts installation failed")
            sys.exit(1)

    # Default behavior: install both scripts and CLI binaries
    if install_scripts(force=args.force) and install_cli_binaries(force=args.force):
        print_success("Scripts and binaries installation completed")

        # Verify installation
        results = verify_installation()
        if all(results.values()):
            print_success("Installation completed successfully!")
            print_message("")
            print_message("LuaEnv scripts are now installed.")
            print_message("Try: luaenv.ps1 status  (or luaenv status if in PATH)")
        else:
            print_warning("Installation completed with some missing components")
    else:
        print_error("Scripts installation failed")
        sys.exit(1)



if __name__ == "__main__":
    main()