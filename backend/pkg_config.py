#!/usr/bin/env python3

# This is free and unencumbered software released into the public domain.
# For more details, see the LICENSE file in the project root.
"""
LuaEnv Pkg-Config Backend

Provides pkg-config style output for C developers to integrate Lua installations
into their build systems. Supports both static library and DLL configurations.

Usage:
    python pkg_config.py <alias|uuid> [options]

Options:
    --cflag         Show compiler flag with /I prefix
    --lua-include   Show include directory path
    --liblua        Show resolved path to lua54.lib file
    --libdir        Show lib directory path
    --path          Show installation paths
    --json          Output in JSON format
    --help          Show this help message

Examples:
    python pkg_config.py dev                # Show all information
    python pkg_config.py dev --cflag        # Show compiler flag (/I"path")
    python pkg_config.py dev --lua-include  # Show include directory path
    python pkg_config.py dev --liblua       # Show path to lua54.lib file
    python pkg_config.py dev --libdir       # Show lib directory path
    python pkg_config.py 12345678 --path    # Show paths for partial UUID
    python pkg_config.py dev --json         # Output in JSON format
    python pkg_config.py dev --lua-include --path-style unix # Show include path with forward slashes
"""

import argparse
import json
import sys
import os
from pathlib import Path
from typing import Dict, List, Optional

# Ensure we can import from the current directory
current_dir = os.path.dirname(os.path.abspath(__file__))
if current_dir not in sys.path:
    sys.path.insert(0, current_dir)

try:
    from registry import LuaEnvRegistry
    from utils import print_error
except ImportError as e:
    print(f"[ERROR] Failed to import required modules: {e}")
    sys.exit(1)


class LuaPkgConfig:
    """Provides pkg-config style information for Lua installations."""

    def __init__(self):
        """Initialize pkg-config handler."""
        self.registry = LuaEnvRegistry()

    def _normalize_path(self, path: Optional[str], style: str) -> str:
        """Normalize path separators for the given style."""
        if not path:
            return ""
        # Use Path for robust conversion
        p = Path(path)
        if style == 'unix':
            return p.as_posix()

        # Get standard Windows path with single backslashes
        windows_path = str(p)

        # For 'native' style on Windows, return with single backslashes
        if style == 'native':
            return windows_path

        # For 'windows' style, escape the backslashes for JSON or other contexts
        # that require escaped backslashes
        return windows_path.replace('\\', '\\\\')

    def get_installation_info(self, id_or_alias: str) -> Optional[Dict]:
        """Get installation information and validate paths.

        Args:
            id_or_alias: Installation ID or alias

        Returns:
            Installation info with validated paths, or None if not found
        """
        installation = self.registry.get_installation(id_or_alias)
        if not installation:
            return None

        # Validate and analyze installation
        install_path = Path(installation["installation_path"])

        if not install_path.exists():
            print_error(f"[ERROR] Installation directory not found: {install_path}")
            return None

        # Analyze installation structure
        info = {
            "id": installation["id"],
            "name": installation["name"],
            "alias": installation.get("alias"),
            "lua_version": installation["lua_version"],
            "luarocks_version": installation["luarocks_version"],
            "build_type": installation["build_type"],  # "dll" or "static"
            "build_config": installation["build_config"],  # "debug" or "release"
            "architecture": installation["architecture"],  # "x86" or "x64"
            "installation_path": str(install_path),
            "paths": self._analyze_paths(install_path),
            "flags": self._generate_flags(install_path, installation)
        }

        return info

    def _analyze_paths(self, install_path: Path) -> Dict[str, str]:
        """Analyze installation directory structure.

        Args:
            install_path: Installation directory

        Returns:
            Dictionary of important paths
        """
        paths = {
            "prefix": str(install_path),
            "bin": str(install_path / "bin"),
            "include": str(install_path / "include"),
            "lib": str(install_path / "lib"),
            "share": str(install_path / "share"),
            "doc": str(install_path / "doc")
        }

        # Detect actual file locations
        paths["lua_exe"] = self._find_file(install_path, ["bin/lua.exe", "lua.exe"])
        paths["luac_exe"] = self._find_file(install_path, ["bin/luac.exe", "luac.exe"])
        paths["lua_dll"] = self._find_file(install_path, ["bin/lua54.dll", "lib/lua54.dll", "lua54.dll"])
        paths["lua_lib"] = self._find_file(install_path, ["lib/lua54.lib", "lua54.lib"])
        paths["lua_h"] = self._find_file(install_path, ["include/lua.h", "lua.h"])

        return paths

    def _find_file(self, base_path: Path, candidates: List[str]) -> Optional[str]:
        """Find first existing file from candidate paths.

        Args:
            base_path: Base directory to search from
            candidates: List of relative paths to check

        Returns:
            Full path to found file, or None
        """
        for candidate in candidates:
            full_path = base_path / candidate
            if full_path.exists():
                return str(full_path)
        return None

    def _generate_flags(self, install_path: Path, installation: Dict) -> Dict[str, str]:
        """Generate MSVC-specific compiler and linker flags.

        Since LuaEnv builds Lua with MSVC, we default to MSVC-compatible flags.
        Future versions may add support for other toolchains via command-line flags.

        Args:
            install_path: Installation directory
            installation: Installation record

        Returns:
            Dictionary of MSVC-compatible flags
        """
        return self._generate_msvc_flags(install_path, installation)

    def _detect_compiler_type(self) -> str:
        """Detect the compiler type based on the environment.

        Returns:
            Compiler type as a string: "msvc", "gcc", "clang", "mingw", or "unknown"
        """
        if "MSVC" in os.environ.get("CC", ""):
            return "msvc"
        elif "clang" in os.environ.get("CC", ""):
            return "clang"
        elif "gcc" in os.environ.get("CC", ""):
            return "gcc"
        elif "mingw" in os.environ.get("CC", ""):
            return "mingw"
        else:
            return "unknown"

    def _generate_msvc_flags(self, install_path: Path, installation: Dict) -> Dict[str, str]:
        """Generate MSVC (Visual Studio) compatible flags.

        Args:
            install_path: Installation directory
            installation: Installation record

        Returns:
            Dictionary of flags in MSVC format
        """
        flags = {}

        # Include directories (for -I flags)
        include_dir = ""
        if (install_path / "include").exists():
            include_dir = str(install_path / "include")
        elif (install_path / "lua.h").exists():
            include_dir = str(install_path)

        # Library directories (for -L flags)
        lib_dir = ""
        if (install_path / "lib").exists():
            lib_dir = str(install_path / "lib")
        elif (install_path / "lua54.lib").exists():
            lib_dir = str(install_path)

        # Generate flags based on build type
        build_type = installation.get("build_type", "static")

        # Store raw paths for later normalization
        flags["_include_dir"] = include_dir
        flags["_lib_dir"] = lib_dir

        if build_type == "dll":
            # DLL build flags - MSVC syntax
            flags["cflags"] = f'/I"{include_dir}"' if include_dir else ""
            flags["ldflags"] = f'/LIBPATH:"{lib_dir}"' if lib_dir else ""
            flags["libs"] = "lua54.lib"
        else:
            # Static build flags - MSVC syntax
            flags["cflags"] = f'/I"{include_dir}"' if include_dir else ""
            flags["ldflags"] = f'/LIBPATH:"{lib_dir}"' if lib_dir else ""
            flags["libs"] = "lua54.lib"

        return flags

    def _generate_gcc_flags(self, install_path: Path, installation: Dict) -> Dict[str, str]:
        """Generate GCC/Clang/MinGW compatible flags.

        Args:
            install_path: Installation directory
            installation: Installation record

        Returns:
            Dictionary of flags in GCC format
        """
        flags = {}

        # Include directories
        include_dirs = []
        if (install_path / "include").exists():
            include_dirs.append(str(install_path / "include"))
        elif (install_path / "lua.h").exists():
            include_dirs.append(str(install_path))

        # Library directories
        lib_dirs = []
        if (install_path / "lib").exists():
            lib_dirs.append(str(install_path / "lib"))
        elif (install_path / "lua54.lib").exists():
            lib_dirs.append(str(install_path))

        # Generate flags based on build type
        build_type = installation.get("build_type", "static")

        if build_type == "dll":
            # DLL build flags - GCC syntax
            flags["cflags"] = " ".join([f'-I"{dir}"' for dir in include_dirs])
            flags["ldflags"] = " ".join([f'-L"{dir}"' for dir in lib_dirs])
            flags["libs"] = "-llua54"
        else:
            # Static build flags - GCC syntax
            flags["cflags"] = " ".join([f'-I"{dir}"' for dir in include_dirs])
            flags["ldflags"] = " ".join([f'-L"{dir}"' for dir in lib_dirs])
            flags["libs"] = "-llua54"

        return flags

    def show_info(self, id_or_alias: str, show_cflag: bool = False,
                  show_lua_include: bool = False, show_liblua: bool = False,
                  show_paths: bool = False, json_output: bool = False,
                  path_style: str = 'native', show_libdir: bool = False) -> bool:
        """Show pkg-config information for installation.

        Args:
            id_or_alias: Installation ID or alias
            show_cflag: Show compiler flag with /I prefix
            show_lua_include: Show only include directory path
            show_liblua: Show only resolved path to lua54.lib file
            show_paths: Show only paths
            json_output: Output in JSON format
            path_style: Path style for output ('windows', 'unix', 'native')
            show_libdir: Show only lib directory path

        Returns:
            True if successful, False if error
        """
        info = self.get_installation_info(id_or_alias)
        if not info:
            print_error(f"[ERROR] Installation '{id_or_alias}' not found or invalid")
            return False

        # Normalize paths in the info dictionary for JSON output
        if json_output:
            # Create a deep copy to avoid modifying the original info dict
            import copy
            json_info = copy.deepcopy(info)

            # Normalize all path-like strings in 'paths'
            for key, value in json_info["paths"].items():
                if value and isinstance(value, str):
                    json_info["paths"][key] = self._normalize_path(value, path_style)

            # Normalize paths inside flags
            if json_info["flags"].get("_include_dir"):
                normalized_include = self._normalize_path(json_info["flags"]["_include_dir"], path_style)
                json_info["flags"]["cflags"] = f'/I"{normalized_include}"'
            if json_info["flags"].get("_lib_dir"):
                normalized_lib = self._normalize_path(json_info["flags"]["_lib_dir"], path_style)
                json_info["flags"]["ldflags"] = f'/LIBPATH:"{normalized_lib}"'

            print(json.dumps(json_info, indent=2))
            return True

        # Show specific information if requested
        if show_cflag:
            include_dir = info["flags"].get("_include_dir")
            if include_dir:
                print(f'/I"{self._normalize_path(include_dir, path_style)}"')
            return True

        if show_lua_include:
            print(self._normalize_path(info["paths"]["include"], path_style))
            return True

        if show_liblua:
            if info["paths"]["lua_lib"]:
                print(self._normalize_path(info["paths"]["lua_lib"], path_style))
            else:
                print_error("[ERROR] lua54.lib not found in installation")
                return False
            return True

        if show_libdir:
            print(self._normalize_path(info["paths"]["lib"], path_style))
            return True

        if show_paths:
            self._show_paths(info, path_style)
            return True

        # Show all information (default)
        self._show_all_info(info, path_style)
        return True

    def _show_paths(self, info: Dict, path_style: str) -> None:
        """Show installation paths."""
        print(f"INSTALLATION PATHS")
        print(f"Prefix:      {self._normalize_path(info['paths']['prefix'], path_style)}")
        print(f"Binaries:    {self._normalize_path(info['paths']['bin'], path_style)}")
        print(f"Headers:     {self._normalize_path(info['paths']['include'], path_style)}")
        print(f"Libraries:   {self._normalize_path(info['paths']['lib'], path_style)}")
        print(f"Share:       {self._normalize_path(info['paths']['share'], path_style)}")
        print(f"Documentation: {self._normalize_path(info['paths']['doc'], path_style)}")
        print()
        print("IMPORTANT FILES")

        if info['paths']['lua_exe']:
            print(f"lua.exe:     {self._normalize_path(info['paths']['lua_exe'], path_style)}")
        else:
            print("lua.exe:     [NOT FOUND]")

        if info['paths']['luac_exe']:
            print(f"luac.exe:    {self._normalize_path(info['paths']['luac_exe'], path_style)}")
        else:
            print("luac.exe:    [NOT FOUND]")

        if info['paths']['lua_h']:
            print(f"lua.h:       {self._normalize_path(info['paths']['lua_h'], path_style)}")
        else:
            print("lua.h:       [NOT FOUND]")

        if info['build_type'] == 'dll':
            if info['paths']['lua_dll']:
                print(f"lua54.dll:   {self._normalize_path(info['paths']['lua_dll'], path_style)}")
            else:
                print("lua54.dll:   [NOT FOUND]")

        if info['paths']['lua_lib']:
            print(f"lua54.lib:   {self._normalize_path(info['paths']['lua_lib'], path_style)}")
        else:
            print("lua54.lib:   [NOT FOUND]")

    def _show_all_info(self, info: Dict, path_style: str) -> None:
        """Show complete pkg-config information."""
        # Normalize paths for display
        norm_include_dir = self._normalize_path(info["paths"]["include"], path_style)
        norm_lib_dir = self._normalize_path(info["paths"]["lib"], path_style)
        norm_lua_dll = self._normalize_path(info["paths"]["lua_dll"], path_style)

        # Generate flags with normalized paths
        cflags = f'/I"{norm_include_dir}"' if norm_include_dir else ""
        ldflags = f'/LIBPATH:"{norm_lib_dir}"' if norm_lib_dir else ""
        libs = info["flags"]["libs"]

        print(f"PKG-CONFIG INFORMATION")
        print(f"Installation: {info['name']}")
        if info['alias']:
            print(f"Alias:        {info['alias']}")
        print(f"ID:           {info['id']}")
        print(f"Lua Version:  {info['lua_version']}")
        print(f"LuaRocks:     {info['luarocks_version']}")
        print(f"Build Type:   {info['build_type']} {info['build_config']}")
        print(f"Architecture: {info['architecture']}")
        print()

        print("COMPILER FLAGS")
        print(f"CFLAGS:   {cflags}")
        print()

        print("LINKER FLAGS")
        print(f"LIBS:     {libs}")
        print(f"LDFLAGS:  {ldflags}")
        print()

        # DLL-specific information
        if info['build_type'] == 'dll':
            print("DLL RUNTIME REQUIREMENTS")
            if norm_lua_dll:
                print(f"Runtime DLL: {norm_lua_dll}")
                print("IMPORTANT: Ensure lua54.dll is available at runtime by:")
                print("  - Copying lua54.dll to your application directory, or")
                print("  - Adding the DLL directory to your system PATH, or")
                print("  - Using SetDllDirectory() in your application")
            else:
                print("Runtime DLL: [NOT FOUND - Installation may be incomplete]")
            print()

        print("COMPATIBILITY WARNING:")
        print("  These libraries were built with MSVC and are NOT compatible with:")
        print("  - MinGW/GCC")
        print("  - Clang (when using MinGW runtime)")
        print("  - Other non-MSVC toolchains")
        if info['build_type'] == 'dll':
            print("  DLL builds may work with other compilers if they can use MSVC import libraries.")
        else:
            print("  Use DLL builds for better cross-compiler compatibility.")


def main():
    """Main entry point."""
    parser = argparse.ArgumentParser(
        description="Generate pkg-config style information for Lua installations",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  python pkg_config.py dev                # Show all information
  python pkg_config.py dev --cflag        # Show compiler flag (/I"path")
  python pkg_config.py dev --lua-include  # Show include directory path
  python pkg_config.py dev --liblua       # Show path to lua54.lib file
  python pkg_config.py dev --libdir       # Show lib directory path
  python pkg_config.py 12345678 --path    # Show paths for partial UUID
  python pkg_config.py dev --json         # Output in JSON format
  python pkg_config.py dev --lua-include --path-style unix # Show include path with forward slashes
        """
    )

    parser.add_argument(
        "installation",
        help="Installation alias or UUID (full or partial)"
    )

    parser.add_argument(
        "--cflag",
        action="store_true",
        help="Show compiler flag with /I prefix"
    )

    parser.add_argument(
        "--lua-include",
        action="store_true",
        help="Show include directory path only"
    )

    parser.add_argument(
        "--liblua",
        action="store_true",
        help="Show resolved path to lua54.lib file only"
    )

    parser.add_argument(
        "--path",
        action="store_true",
        help="Show installation paths only"
    )

    parser.add_argument(
        "--libdir",
        action="store_true",
        help="Show lib directory path only"
    )

    parser.add_argument(
        "--json",
        action="store_true",
        help="Output in JSON format"
    )

    parser.add_argument(
        "--path-style",
        choices=['windows', 'unix', 'native'],
        default='native',
        help="Output path style ('windows', 'unix', or 'native')"
    )

    args = parser.parse_args()

    # Validate arguments
    flag_count = sum([args.cflag, args.lua_include, args.liblua, args.path, args.libdir])
    if flag_count > 1:
        print_error("[ERROR] Only one of --cflag, --lua-include, --liblua, --path, --libdir can be specified")
        return 1

    try:
        pkg_config = LuaPkgConfig()
        success = pkg_config.show_info(
            args.installation,
            show_cflag=args.cflag,
            show_lua_include=args.lua_include,
            show_liblua=args.liblua,
            show_paths=args.path,
            json_output=args.json,
            path_style=args.path_style,
            show_libdir=args.libdir
        )

        return 0 if success else 1

    except Exception as e:
        print_error(f"[ERROR] Unexpected error: {e}")
        return 1


if __name__ == "__main__":
    sys.exit(main())
