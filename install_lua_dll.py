
"""
Lua DLL Build Installer
=======================

This script installs the products of the Lua DLL build (build-dll.bat)
to a directory structure suitable for development and distribution.

Usage:
    python install_lua_dll.py [install_directory]

If no directory is specified, it will install to './lua' by default.
"""

import sys
import shutil
import argparse
from pathlib import Path


class LuaDLLInstaller:
    def __init__(self, source_dir=None, install_dir=None):
        self.source_dir = Path(source_dir) if source_dir else Path.cwd()
        self.release_dir = self.source_dir / "Release"
        self.install_dir = Path(install_dir) if install_dir else Path("lua")

        # Define the files to install
        self.binaries = [
            "lua.exe",      # Lua interpreter (uses DLL)
            "luac.exe",     # Lua compiler (static)
            "lua54.dll",    # Lua dynamic library
        ]

        self.libraries = [
            "lua54.lib",    # Import library for linking
            "lua54.exp",    # Export file for the DLL
        ]

        self.headers = [
            "lua.h",        # Main Lua header
            "luaconf.h",    # Lua configuration
            "lualib.h",     # Lua standard libraries
            "lauxlib.h",    # Lua auxiliary library
            "lua.hpp",      # C++ wrapper header
        ]

        self.doc_patterns = [
            "../README",
            "../doc/*.html",
            "../doc/*.css",
            "../doc/*.gif",
            "../doc/*.png",
        ]

    def check_build_products(self):
        """Check if all required build products exist."""
        print("Checking build products...")

        missing_files = []

        # Check binaries
        for binary in self.binaries:
            binary_path = self.release_dir / binary
            if binary_path.exists():
                print(f"  ✓ {binary}")
            else:
                print(f"  ✗ {binary} (missing)")
                missing_files.append(str(binary_path))

        # Check libraries
        for library in self.libraries:
            library_path = self.release_dir / library
            if library_path.exists():
                print(f"  ✓ {library}")
            else:
                print(f"  ✗ {library} (missing)")
                missing_files.append(str(library_path))

        # Check headers
        for header in self.headers:
            header_path = self.source_dir / header
            if header_path.exists():
                print(f"  ✓ {header}")
            else:
                print(f"  ✗ {header} (missing)")
                missing_files.append(str(header_path))

        if missing_files:
            print(f"\nError: Missing required files:")
            for file in missing_files:
                print(f"  {file}")
            print("\nPlease run build-dll.bat first to build Lua.")
            return False

        print("All required files found!")
        return True

    def create_directories(self):
        """Create the installation directory structure."""
        print(f"\nCreating directory structure in: {self.install_dir.absolute()}")

        directories = [
            self.install_dir / "bin",
            self.install_dir / "lib",
            self.install_dir / "include",
            self.install_dir / "doc",
        ]

        for directory in directories:
            directory.mkdir(parents=True, exist_ok=True)
            print(f"  Created: {directory.relative_to(self.install_dir)}/")

    def install_binaries(self):
        """Install binary files to bin/ directory."""
        print(f"\nInstalling binaries...")

        bin_dir = self.install_dir / "bin"

        for binary in self.binaries:
            source = self.release_dir / binary
            dest = bin_dir / binary

            shutil.copy2(source, dest)
            print(f"  {binary} -> bin/")

    def install_libraries(self):
        """Install library files to lib/ directory."""
        print(f"\nInstalling libraries...")

        lib_dir = self.install_dir / "lib"

        for library in self.libraries:
            source = self.release_dir / library
            dest = lib_dir / library

            shutil.copy2(source, dest)
            print(f"  {library} -> lib/")

    def install_headers(self):
        """Install header files to include/ directory."""
        print(f"\nInstalling headers...")

        include_dir = self.install_dir / "include"

        for header in self.headers:
            source = self.source_dir / header
            dest = include_dir / header

            shutil.copy2(source, dest)
            print(f"  {header} -> include/")

    def install_documentation(self):
        """Install documentation files to doc/ directory."""
        print(f"\nInstalling documentation...")

        doc_dir = self.install_dir / "doc"
        installed_count = 0

        for pattern in self.doc_patterns:
            pattern_path = self.source_dir / pattern

            if pattern.endswith("README"):
                # Handle README file specifically
                readme_path = self.source_dir.parent / "README"
                if readme_path.exists():
                    dest = doc_dir / "README"
                    shutil.copy2(readme_path, dest)
                    print(f"  README -> doc/")
                    installed_count += 1
            else:
                # Handle wildcard patterns
                from glob import glob
                pattern_str = str(pattern_path)
                for file_path in glob(pattern_str):
                    file_path = Path(file_path)
                    if file_path.is_file():
                        dest = doc_dir / file_path.name
                        shutil.copy2(file_path, dest)
                        print(f"  {file_path.name} -> doc/")
                        installed_count += 1

        if installed_count == 0:
            print("  No documentation files found")

#     def create_usage_info(self):
#         """Create a usage information file."""
#         usage_file = self.install_dir / "USAGE.txt"

#         usage_content = f"""Lua 5.4.8 DLL Installation
# ============================

# Installation Directory: {self.install_dir.absolute()}

# Directory Structure:
#   bin/        - Executable files (lua.exe, luac.exe, lua54.dll)
#   lib/        - Library files for linking (lua54.lib)
#   include/    - Header files for development
#   doc/        - Documentation files

# Usage:
# ------

# 1. Running Lua:
#    {self.install_dir.absolute() / 'bin' / 'lua.exe'}

#    Or add {self.install_dir.absolute() / 'bin'} to your PATH environment variable

# 2. Compiling Lua scripts:
#    {self.install_dir.absolute() / 'bin' / 'luac.exe'} script.lua

# 3. Linking with Lua (C/C++ development):
#    - Include directory: {self.install_dir.absolute() / 'include'}
#    - Library directory: {self.install_dir.absolute() / 'lib'}
#    - Link with: lua54.lib
#    - Runtime dependency: lua54.dll (must be in PATH or same directory as executable)

# Important Notes:
# ---------------
# - lua.exe requires lua54.dll to run
# - Both lua54.dll and lua.exe should be in the same directory or lua54.dll should be in your PATH
# - For distribution, include lua54.dll with your application
# - luac.exe is statically linked and doesn't require the DLL

# Environment Setup:
# -----------------
# To use Lua from anywhere, use the use-lua.ps1 script provided in the installation directory.
# You can run it in PowerShell to set up the environment variables for the current session.
# For permanent setup, add the bin and the luarocks directories to your PATH environment variable.

# """

#         with open(usage_file, 'w', encoding='utf-8') as f:
#             f.write(usage_content)

#         print(f"\nCreated usage information: {usage_file.name}")

    def install(self):
        """Perform the complete installation."""
        print("=" * 60)
        print("Lua 5.4.8 DLL Build Installer")
        print("=" * 60)

        # Check if build products exist
        if not self.check_build_products():
            return False

        # Create directories
        self.create_directories()

        # Install files
        self.install_binaries()
        self.install_libraries()
        self.install_headers()
        self.install_documentation()

        # Create usage info
        # self.create_usage_info()

        # Summary
        print("\n" + "=" * 60)
        print("INSTALLATION COMPLETED SUCCESSFULLY!")
        print("=" * 60)
        print(f"Installation directory: {self.install_dir.absolute()}")
        print(f"Binaries: {self.install_dir.absolute() / 'bin'}")
        print(f"Headers:  {self.install_dir.absolute() / 'include'}")
        print(f"Library:  {self.install_dir.absolute() / 'lib'}")
        print(f"Docs:     {self.install_dir.absolute() / 'doc'}")
        print()
        print("To use Lua, add the bin directory to your PATH environment variable:")
        print(f"set PATH={self.install_dir.absolute() / 'bin'};%PATH%")
        print()
        print("The DLL (lua54.dll) is installed in the bin directory with the executables.")
        print(f"See {self.install_dir / 'USAGE.txt'} for detailed usage instructions.")

        return True


def main():
    parser = argparse.ArgumentParser(
        description="Install Lua DLL build products",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  python install_lua_dll.py                    # Install to ./lua
  python install_lua_dll.py myapp/lua          # Install to ./myapp/lua
  python install_lua_dll.py C:/Tools/Lua       # Install to C:/Tools/Lua
        """
    )

    parser.add_argument(
        'install_dir',
        nargs='?',
        default='lua',
        help='Installation directory (default: lua)'
    )

    parser.add_argument(
        '--source-dir',
        help='Source directory containing the build (default: current directory)'
    )

    args = parser.parse_args()

    try:
        installer = LuaDLLInstaller(
            source_dir=args.source_dir,
            install_dir=args.install_dir
        )

        success = installer.install()
        sys.exit(0 if success else 1)

    except KeyboardInterrupt:
        print("\nInstallation cancelled by user.")
        sys.exit(1)
    except Exception as e:
        print(f"\nError during installation: {e}")
        sys.exit(1)


if __name__ == "__main__":
    main()
