# This is free and unencumbered software released into the public domain.
# For more details, see the LICENSE file in the project root.

"""
Utility functions for the Lua MSVC Build System.

This module contains general-purpose utility functions that don't depend on
specific configurations and can be reused across different scripts.
"""

import urllib.request
import shutil
import tarfile
import subprocess
import os
import zipfile
import json
import inspect
from pathlib import Path
from typing import Tuple, Optional, Dict, Any

def log_with_location(message: str, level: str = "INFO", include_file: bool = True, include_line: bool = True) -> None:
    """
    Log a message with caller location information.

    Args:
        message: The message to log
        level: Log level ("INFO", "OK", "ERROR", "WARNING", "DEBUG")
        include_file: Whether to include the filename in the output
        include_line: Whether to include the line number in the output
    """
    levels = {
        "INFO": "[INFO]",
        "OK": "[OK]",
        "ERROR": "[ERROR]",
        "WARNING": "[WARNING]",
        "DEBUG": "[DEBUG]"
    }
    prefix = levels.get(level.upper(), "[INFO]")

    # Get caller information by walking up the call stack
    # Skip frames that are within utils.py to find the true external caller
    frame = inspect.currentframe()
    utils_filename = os.path.basename(__file__)

    while frame:
        frame = frame.f_back
        if frame is None:
            break

        caller_filename = os.path.basename(frame.f_code.co_filename)
        # Stop when we find a frame that's not from utils.py
        if caller_filename != utils_filename:
            break

    # If we couldn't find an external caller, use the immediate caller
    if frame is None:
        frame = inspect.currentframe().f_back

    location_parts = []
    if include_file:
        filename = os.path.basename(frame.f_code.co_filename)
        location_parts.append(filename)

    if include_line:
        line_number = frame.f_lineno
        location_parts.append(f"line {line_number}")

    if location_parts:
        location_str = f"({':'.join(location_parts)})"
    else:
        location_str = ""

    print(f"{location_str} {prefix} {message}")

def print_message(message: str, prefix: str = "[INFO]") -> None:
    """Print a message with ASCII prefix and caller location."""
    log_with_location(message, "INFO", include_file=True, include_line=True)

def print_success(message: str) -> None:
    """Print a success message with caller location."""
    log_with_location(message, "OK", include_file=True, include_line=True)

def print_error(message: str) -> None:
    """Print an error message with caller location."""
    log_with_location(message, "ERROR", include_file=True, include_line=True)

def print_warning(message: str) -> None:
    """Print a warning message with caller location."""
    log_with_location(message, "WARNING", include_file=True, include_line=True)

def print_debug(message: str) -> None:
    """Print a debug message with full caller location."""
    log_with_location(message, "DEBUG", include_file=True, include_line=True)

def log(message, level: str = "INFO", location: str = ".") -> None:
    """
    Legacy log function for backward compatibility.
    Use log_with_location for enhanced logging with caller info.
    """
    levels = {
        "INFO": "[INFO]",
        "OK": "[OK]",
        "ERROR": "[ERROR]",
        "WARNING": "[WARNING]",
        "DEBUG": "[DEBUG]"
    }
    prefix = levels.get(level, "[INFO]")
    print(f"{location}: {prefix} {message}")

def get_backend_dir() -> Path:
    """Get the backend directory path."""
    # Assuming the backend directory is in the same location as this script
    return Path(__file__).resolve().parent

def download_file(url, dest):
    """Download a file from a URL to a specified destination."""
    print(f"Downloading {url} to {dest}...")
    urllib.request.urlretrieve(url, dest)
    print(f"Downloaded {dest}")

def extract_file(file_path, extract_to=None, move_callback=None):
    """
    Extract a file and optionally move the extracted contents.

    Args:
        file_path: Path to the file to extract
        extract_to: Directory to extract to (defaults to parent of file_path)
        move_callback: Optional callback function to determine target names for extracted items.
                      Should accept (source_path, original_name) and return target_path or None.
    """
    file_path = Path(file_path)
    extract_to = extract_to or file_path.parent

    if file_path.suffix == ".gz" and file_path.stem.endswith(".tar"):
        _extract_tar_gz(file_path, extract_to, move_callback)
    elif file_path.suffix == ".zip":
        _extract_zip(file_path, extract_to, move_callback)
    else:
        print(f"Unsupported file format: {file_path}")

def _extract_tar_gz(file_path, extract_to, move_callback=None):
    """Extract a .tar.gz file."""
    with tarfile.open(file_path, "r:gz") as tar:
        # Extract to specified directory first
        tar.extractall(path=extract_to)
        print(f"Extracted {file_path} to {extract_to}")

        # Get all top-level directories from tar archive
        top_level_dirs = set()
        for member in tar.getnames():
            # Get the first component of the path (top-level directory)
            top_dir = member.split('/')[0]
            if top_dir:  # Make sure it's not empty
                top_level_dirs.add(top_dir)

        # Move extracted folders if callback is provided
        if move_callback:
            for dir_name in top_level_dirs:
                source = extract_to / dir_name
                if source.exists() and source.is_dir():
                    dest = move_callback(source, dir_name)
                    if dest and dest != source:
                        _safe_move(source, dest)

def _extract_zip(file_path, extract_to, move_callback=None):
    """Extract a .zip file."""
    with zipfile.ZipFile(file_path, 'r') as zip_ref:
        # Extract to specified directory first
        zip_ref.extractall(path=extract_to)
        print(f"Extracted {file_path} to {extract_to}")

        # Get top-level items
        extracted_items = set()
        for name in zip_ref.namelist():
            if '/' in name:
                top_dir = name.split('/')[0]
                extracted_items.add(top_dir)
            else:
                extracted_items.add(name)

        # Move extracted items if callback is provided
        if move_callback:
            for item in extracted_items:
                source = extract_to / item
                if source.exists():
                    dest = move_callback(source, item)
                    if dest and dest != source:
                        _safe_move(source, dest)

def _safe_move(source, dest):
    """Safely move a file or directory, removing destination if it exists."""
    dest = Path(dest)
    if dest.exists():
        if dest.is_dir():
            shutil.rmtree(dest)
        else:
            dest.unlink()
    shutil.move(str(source), str(dest))
    print(f"Moved {source} to {dest}")

def create_directory_structure(base_path, structure):
    """
    Create a directory structure from a dictionary.

    Args:
        base_path: Base directory path
        structure: Dictionary describing the structure
                  e.g., {'downloads': {'lua': {}, 'luarocks': {}}}
    """
    base = Path(base_path)
    base.mkdir(exist_ok=True)

    for name, subdirs in structure.items():
        dir_path = base / name
        dir_path.mkdir(exist_ok=True)
        if isinstance(subdirs, dict) and subdirs:
            create_directory_structure(dir_path, subdirs)

def get_file_size(file_path):
    """Get file size in bytes, or 0 if file doesn't exist."""
    try:
        return Path(file_path).stat().st_size
    except (OSError, FileNotFoundError):
        return 0

def format_file_size(size_bytes):
    """Format file size in human-readable format."""
    if size_bytes == 0:
        return "0 B"

    for unit in ['B', 'KB', 'MB', 'GB']:
        if size_bytes < 1024.0:
            return f"{size_bytes:.1f} {unit}"
        size_bytes /= 1024.0
    return f"{size_bytes:.1f} TB"

def verify_file_exists(file_path):
    """Verify that a file exists and is not empty."""
    path = Path(file_path)
    return path.exists() and path.is_file() and path.stat().st_size > 0

def update_build_config(lua_version, luarocks_version, luarocks_platform, config_file="build_config.txt"):
    """
    Update the build_config.txt file with new version settings.

    Args:
        lua_version: Lua version (e.g., "5.4.8")
        luarocks_version: LuaRocks version (e.g., "3.12.2")
        luarocks_platform: LuaRocks platform (e.g., "windows-64")
        config_file: Path to the config file (defaults to "build_config.txt")

    Returns:
        bool: True if successful, False otherwise
    """
    import re

    config_path = Path(config_file)

    if not config_path.exists():
        print(f"Error: Config file {config_path} not found")
        return False

    try:
        # Read the current config file
        with open(config_path, 'r', encoding='utf-8') as f:
            content = f.read()

        # Calculate LUA_MAJOR_MINOR from lua_version
        version_parts = lua_version.split('.')
        if len(version_parts) >= 2:
            lua_major_minor = f"{version_parts[0]}.{version_parts[1]}"
        else:
            lua_major_minor = lua_version

        # Define patterns and replacements
        replacements = [
            (r'^LUA_VERSION=.*$', f'LUA_VERSION={lua_version}'),
            (r'^LUA_MAJOR_MINOR=.*$', f'LUA_MAJOR_MINOR={lua_major_minor}'),
            (r'^LUAROCKS_VERSION=.*$', f'LUAROCKS_VERSION={luarocks_version}'),
            (r'^LUAROCKS_PLATFORM=.*$', f'LUAROCKS_PLATFORM={luarocks_platform}')
        ]

        # Apply replacements
        updated_content = content
        for pattern, replacement in replacements:
            updated_content = re.sub(pattern, replacement, updated_content, flags=re.MULTILINE)

        # Check if any changes were made
        if updated_content == content:
            print("Warning: No configuration values were updated. Check if the config file has the expected format.")
            return False

        # Write the updated content back to the file
        with open(config_path, 'w', encoding='utf-8') as f:
            f.write(updated_content)

        print(f"[OK] Updated {config_path}:")
        print(f"  LUA_VERSION={lua_version}")
        print(f"  LUA_MAJOR_MINOR={lua_major_minor}")
        print(f"  LUAROCKS_VERSION={luarocks_version}")
        print(f"  LUAROCKS_PLATFORM={luarocks_platform}")

        return True

    except Exception as e:
        print(f"Error updating config file: {e}")
        return False

def read_build_config(config_file="build_config.txt"):
    """
    Read the current build configuration from build_config.txt.

    Args:
        config_file: Path to the config file (defaults to "build_config.txt")

    Returns:
        dict: Configuration values or empty dict if error
    """
    import re

    config_path = Path(config_file)

    if not config_path.exists():
        print(f"Error: Config file {config_path} not found")
        return {}

    try:
        config = {}
        with open(config_path, 'r', encoding='utf-8') as f:
            for line in f:
                line = line.strip()
                # Skip comments and empty lines
                if line.startswith('#') or not line or '=' not in line:
                    continue

                # Parse key=value pairs
                key, value = line.split('=', 1)
                config[key.strip()] = value.strip()

        return config

    except Exception as e:
        print(f"Error reading config file: {e}")
        return {}

def ensure_extracted_folder(base_path="."):
    """
    Ensure the extracted folder exists.

    Args:
        base_path: Base directory path (defaults to current directory)

    Returns:
        Path: Path to the extracted folder
    """
    extracted_path = Path(base_path) / "extracted"
    extracted_path.mkdir(exist_ok=True)
    return extracted_path

def clean_extracted_folder(base_path=".", confirm=True):
    """
    Clean the extracted folder by removing all contents.

    Args:
        base_path: Base directory path (defaults to current directory)
        confirm: Whether to ask for confirmation before cleaning

    Returns:
        bool: True if successful, False otherwise
    """
    extracted_path = Path(base_path) / "extracted"

    if not extracted_path.exists():
        print("Extracted folder doesn't exist - nothing to clean")
        return True

    if confirm:
        items = list(extracted_path.iterdir())
        if not items:
            print("Extracted folder is already empty")
            return True

        print(f"Found {len(items)} items in extracted folder:")
        for item in items:
            print(f"  - {item.name}")

        response = input("Remove all items? (y/N): ").strip().lower()
        if response not in ['y', 'yes']:
            print("Cancelled")
            return False

    try:
        for item in extracted_path.iterdir():
            if item.is_dir():
                shutil.rmtree(item)
            else:
                item.unlink()
        print(f"[OK] Cleaned extracted folder: {extracted_path}")
        return True
    except Exception as e:
        print(f"Error cleaning extracted folder: {e}")
        return False

def list_extracted_contents(base_path="."):
    """
    List contents of the extracted folder.

    Args:
        base_path: Base directory path (defaults to current directory)

    Returns:
        list: List of paths in the extracted folder
    """
    extracted_path = Path(base_path) / "extracted"

    if not extracted_path.exists():
        print("Extracted folder doesn't exist")
        return []

    try:
        items = list(extracted_path.iterdir())
        if not items:
            print("Extracted folder is empty")
            return []

        print(f"Contents of extracted folder ({len(items)} items):")
        for item in sorted(items):
            if item.is_dir():
                # Count subdirectories and files
                try:
                    sub_items = list(item.iterdir())
                    print(f"  [DIR] {item.name}/ ({len(sub_items)} items)")
                except PermissionError:
                    print(f"  [DIR] {item.name}/ (access denied)")
            else:
                size = get_file_size(item)
                print(f"  [FILE] {item.name} ({format_file_size(size)})")

        return items
    except Exception as e:
        print(f"Error listing extracted contents: {e}")
        return []

def get_extracted_path(item_name, base_path="."):
    """
    Get the path to a specific item in the extracted folder.

    Args:
        item_name: Name of the item to find
        base_path: Base directory path (defaults to current directory)

    Returns:
        Path or None: Path to the item if it exists, None otherwise
    """
    extracted_path = Path(base_path) / "extracted" / item_name
    return extracted_path if extracted_path.exists() else None

def get_luarocks_package_count() -> Optional[int]:
    """
    Get the count of installed LuaRocks packages.

    Returns:
        Optional[int]: Number of installed packages, or None if unable to determine
    """
    try:
        # Run the luarocks command to list installed packages
        result = subprocess.run(
            ["luarocks", "list", "--porcelain"],
            capture_output=True,
            text=True,
            check=True
        )

        # Split the output into lines and count non-empty lines
        package_count = len([line for line in result.stdout.splitlines() if line.strip()])

        return package_count

    except subprocess.CalledProcessError as e:
        print(f"Error calling luarocks: {e}")
    except Exception as e:
        print(f"Unexpected error: {e}")

    return None

def get_luarocks_package_count(luarocks_path: str) -> int:
    """Count the number of packages installed via LuaRocks.

    Args:
        luarocks_path: Path to the luarocks executable

    Returns:
        Number of installed packages
    """
    try:
        # Run 'luarocks list' and capture output
        result = subprocess.run(
            [luarocks_path, "list"],
            capture_output=True,
            text=True,
            check=True
        )

        # Parse output to count packages
        output_lines = result.stdout.strip().split('\n')
        # Filter out header lines and count actual package entries
        packages = [line for line in output_lines if line and not line.startswith('Installed rocks:')]

        return len(packages)
    except subprocess.SubprocessError as e:
        print(f"[WARNING] Failed to get package count: {e}")
        return 0
    except Exception as e:
        print(f"[WARNING] Unexpected error counting packages: {e}")
        return 0

def get_backend_config() -> Dict[str, Any]:
    """Load the backend configuration file.

    Returns:
        Dictionary containing backend configuration
    """
    try:
        # Try to find the backend config in the standard location
        luaenv_dir = Path.home() / ".luaenv"
        bin_dir = luaenv_dir / "bin"
        config_path = bin_dir / "backend.config"

        if not config_path.exists():
            print("[WARNING] Backend configuration not found at default location")
            # Try a fallback to find the config relative to the current script
            script_dir = Path(os.path.dirname(os.path.abspath(__file__)))
            parent_dir = script_dir.parent
            bin_dir = parent_dir / "bin"
            config_path = bin_dir / "backend.config"

            if not config_path.exists():
                print(f"[ERROR] Backend configuration not found at {config_path}")
                return {}

        with open(config_path, 'r', encoding='utf-8') as f:
            config = json.load(f)

        return config
    except Exception as e:
        print(f"[ERROR] Failed to load backend configuration: {e}")
        return {}

def get_embedded_python_path() -> Optional[str]:
    """Get the path to the embedded Python executable.

    Returns:
        Path to the embedded Python executable or None if not found
    """
    config = get_backend_config()

    if not config or "embedded_python" not in config:
        print("[ERROR] Invalid backend configuration (embedded_python section missing)")
        return None

    embedded_python = config.get("embedded_python", {})
    python_exe = embedded_python.get("python_exe")

    if not python_exe or not os.path.exists(python_exe):
        print(f"[WARNING] Embedded Python not found at {python_exe}")
        return None

    return python_exe

# Quick logging convenience functions
def info(message: str) -> None:
    """Quick info log with line number."""
    log_with_location(message, "INFO", include_file=False, include_line=True)

def error(message: str) -> None:
    """Quick error log with file and line number."""
    log_with_location(message, "ERROR", include_file=True, include_line=True)

def warning(message: str) -> None:
    """Quick warning log with line number."""
    log_with_location(message, "WARNING", include_file=False, include_line=True)

def debug(message: str) -> None:
    """Quick debug log with full location info."""
    log_with_location(message, "DEBUG", include_file=True, include_line=True)

def test_logging():
    """Test function to demonstrate the enhanced logging."""
    print("=== Testing Enhanced Logging ===")
    info("This is an info message")
    warning("This is a warning message")
    error("This is an error message")
    debug("This is a debug message")
    log_with_location("Custom log with full location", "INFO", True, True)
    log_with_location("Custom log with line only", "WARNING", False, True)
    print("=== End Test ===")
