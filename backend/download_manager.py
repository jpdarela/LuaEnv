# This is free and unencumbered software released into the public domain.
# For more details, see the LICENSE file in the project root.
"""
Version-aware download manager for Lua MSVC Build System.

This module manages downloads by version, avoiding re-downloads and maintaining
a registry of available versions.
"""

import json
import sys
from datetime import datetime
from pathlib import Path
from typing import Dict, List, Optional, Tuple

# Add current directory to Python path for local imports
current_dir = Path(__file__).parent
sys.path.insert(0, str(current_dir))

# Import utilities with dual-context support
try:
    from .utils import download_file, extract_file, verify_file_exists, get_file_size, format_file_size
except ImportError:
    from utils import download_file, extract_file, verify_file_exists, get_file_size, format_file_size


class DownloadManager:
    """Manages version-aware downloads with caching and registry."""

    def __init__(self, base_downloads_dir="downloads"):
        self.base_dir = Path(base_downloads_dir)
        self.lua_dir = self.base_dir / "lua"
        self.luarocks_dir = self.base_dir / "luarocks"
        self.registry_file = self.base_dir / "download_registry.json"
        self.registry = self._load_registry()

    def _load_registry(self) -> Dict:
        """Load the download registry from disk."""
        if self.registry_file.exists():
            try:
                with open(self.registry_file, 'r') as f:
                    return json.load(f)
            except (json.JSONDecodeError, OSError):
                pass

        return {
            "version": "2.0",  # Updated version for new structure
            "created": datetime.now().isoformat(),
            "lua_downloads": {},      # Lua + Lua tests downloads
            "luarocks_downloads": {}, # LuaRocks downloads
            "combinations": {}        # Version combinations
        }

    def _save_registry(self):
        """Save the download registry to disk."""
        self.base_dir.mkdir(exist_ok=True)
        self.registry["last_updated"] = datetime.now().isoformat()

        with open(self.registry_file, 'w') as f:
            json.dump(self.registry, f, indent=2)

    def get_lua_dir(self, lua_version: str) -> Path:
        """Get the directory for a specific Lua version."""
        return self.lua_dir / f"lua-{lua_version}"

    def get_luarocks_dir(self, luarocks_version: str, platform: str) -> Path:
        """Get the directory for a specific LuaRocks version."""
        return self.luarocks_dir / f"luarocks-{luarocks_version}-{platform}"

    def get_version_key(self, lua_version: str, luarocks_version: str) -> str:
        """Get the registry key for a version combination."""
        return f"lua-{lua_version}_luarocks-{luarocks_version}"

    def is_lua_downloaded(self, lua_version: str) -> bool:
        """Check if a Lua version is already downloaded."""
        if lua_version not in self.registry["lua_downloads"]:
            return False

        lua_info = self.registry["lua_downloads"][lua_version]
        lua_dir = self.get_lua_dir(lua_version)

        # Check if all Lua files exist and are not empty
        for file_type, file_info in lua_info.get("files", {}).items():
            file_path = lua_dir / file_info["filename"]
            if not verify_file_exists(file_path):
                return False

        return True

    def is_luarocks_downloaded(self, luarocks_version: str, platform: str) -> bool:
        """Check if a LuaRocks version is already downloaded."""
        luarocks_key = f"{luarocks_version}-{platform}"
        if luarocks_key not in self.registry["luarocks_downloads"]:
            return False

        luarocks_info = self.registry["luarocks_downloads"][luarocks_key]
        luarocks_dir = self.get_luarocks_dir(luarocks_version, platform)

        # Check if LuaRocks file exists and is not empty
        for file_type, file_info in luarocks_info.get("files", {}).items():
            file_path = luarocks_dir / file_info["filename"]
            if not verify_file_exists(file_path):
                return False

        return True

    def is_downloaded(self, lua_version: str, luarocks_version: str, platform: str = "windows-64") -> bool:
        """Check if a version combination is already downloaded."""
        return (self.is_lua_downloaded(lua_version) and
                self.is_luarocks_downloaded(luarocks_version, platform))

    def download_version(self, lua_version: str, luarocks_version: str,
                        urls: Dict[str, str], filenames: Dict[str, str],
                        platform: str = "windows-64") -> Tuple[bool, str]:
        """
        Download a specific version combination.

        Args:
            lua_version: Lua version to download
            luarocks_version: LuaRocks version to download
            urls: Dictionary of URLs {type: url}
            filenames: Dictionary of filenames {type: filename}
            platform: Platform string for LuaRocks

        Returns:
            Tuple of (success, message)
        """
        version_key = self.get_version_key(lua_version, luarocks_version)
        luarocks_key = f"{luarocks_version}-{platform}"

        # Check what needs to be downloaded
        lua_needs_download = not self.is_lua_downloaded(lua_version)
        luarocks_needs_download = not self.is_luarocks_downloaded(luarocks_version, platform)

        if not lua_needs_download and not luarocks_needs_download:
            # Register the combination if not already registered
            if version_key not in self.registry["combinations"]:
                self.registry["combinations"][version_key] = {
                    "lua_version": lua_version,
                    "luarocks_version": luarocks_version,
                    "platform": platform,
                    "created": datetime.now().isoformat()
                }
                self._save_registry()
            return True, f"Version {version_key} already downloaded"

        try:
            # Download Lua components if needed
            if lua_needs_download:
                lua_dir = self.get_lua_dir(lua_version)
                lua_dir.mkdir(parents=True, exist_ok=True)

                lua_info = {
                    "lua_version": lua_version,
                    "download_date": datetime.now().isoformat(),
                    "files": {}
                }

                print(f"Downloading Lua {lua_version} components...")
                for file_type in ['lua', 'lua_tests']:
                    if file_type in urls and file_type in filenames:
                        filename = filenames[file_type]
                        file_path = lua_dir / filename

                        print(f"  Downloading {file_type}: {filename}")
                        download_file(urls[file_type], str(file_path))

                        lua_info["files"][file_type] = {
                            "filename": filename,
                            "url": urls[file_type],
                            "size": get_file_size(file_path),
                            "downloaded": datetime.now().isoformat()
                        }

                # Update registry
                self.registry["lua_downloads"][lua_version] = lua_info
            else:
                print(f"[OK] Lua {lua_version} already downloaded, skipping...")

            # Download LuaRocks if needed
            if luarocks_needs_download:
                luarocks_dir = self.get_luarocks_dir(luarocks_version, platform)
                luarocks_dir.mkdir(parents=True, exist_ok=True)

                luarocks_info = {
                    "luarocks_version": luarocks_version,
                    "platform": platform,
                    "download_date": datetime.now().isoformat(),
                    "files": {}
                }

                print(f"Downloading LuaRocks {luarocks_version}-{platform}...")
                if 'luarocks' in urls and 'luarocks' in filenames:
                    filename = filenames['luarocks']
                    file_path = luarocks_dir / filename

                    print(f"  Downloading luarocks: {filename}")
                    download_file(urls['luarocks'], str(file_path))

                    luarocks_info["files"]['luarocks'] = {
                        "filename": filename,
                        "url": urls['luarocks'],
                        "size": get_file_size(file_path),
                        "downloaded": datetime.now().isoformat()
                    }

                # Update registry
                self.registry["luarocks_downloads"][luarocks_key] = luarocks_info
            else:
                print(f"[OK] LuaRocks {luarocks_version}-{platform} already downloaded, skipping...")

            # Register the combination
            self.registry["combinations"][version_key] = {
                "lua_version": lua_version,
                "luarocks_version": luarocks_version,
                "platform": platform,
                "created": datetime.now().isoformat()
            }

            self._save_registry()
            return True, f"Successfully downloaded {version_key}"

        except Exception as e:
            return False, f"Failed to download {version_key}: {str(e)}"

    def extract_version(self, lua_version: str, luarocks_version: str,
                       extract_to: Optional[Path] = None,
                       move_callback=None, platform: str = "windows-64") -> Tuple[bool, str]:
        """
        Extract a downloaded version.

        Args:
            lua_version: Lua version
            luarocks_version: LuaRocks version
            extract_to: Directory to extract to (defaults to parent of downloads)
            move_callback: Callback for moving extracted files
            platform: Platform string for LuaRocks

        Returns:
            Tuple of (success, message)
        """
        version_key = self.get_version_key(lua_version, luarocks_version)

        if not self.is_downloaded(lua_version, luarocks_version, platform):
            return False, f"Version {version_key} not downloaded"

        # Default extract location is the backend directory (parent of downloads)
        if extract_to is None:
            extract_to = self.base_dir.parent

        try:
            # Extract Lua components
            if lua_version in self.registry["lua_downloads"]:
                lua_info = self.registry["lua_downloads"][lua_version]
                lua_dir = self.get_lua_dir(lua_version)

                for file_type, file_info in lua_info["files"].items():
                    file_path = lua_dir / file_info["filename"]
                    print(f"Extracting Lua {file_type}: {file_info['filename']}")
                    extract_file(file_path, extract_to, move_callback)

            # Extract LuaRocks
            luarocks_key = f"{luarocks_version}-{platform}"
            if luarocks_key in self.registry["luarocks_downloads"]:
                luarocks_info = self.registry["luarocks_downloads"][luarocks_key]
                luarocks_dir = self.get_luarocks_dir(luarocks_version, platform)

                for file_type, file_info in luarocks_info["files"].items():
                    file_path = luarocks_dir / file_info["filename"]
                    print(f"Extracting LuaRocks {file_type}: {file_info['filename']}")
                    extract_file(file_path, extract_to, move_callback)

            return True, f"Successfully extracted {version_key}"

        except Exception as e:
            return False, f"Failed to extract {version_key}: {str(e)}"

    def list_downloaded_versions(self) -> List[Dict]:
        """List all downloaded version combinations."""
        versions = []

        for version_key, combo_info in self.registry["combinations"].items():
            lua_version = combo_info["lua_version"]
            luarocks_version = combo_info["luarocks_version"]
            platform = combo_info.get("platform", "windows-64")

            # Calculate total size
            total_size = 0
            file_count = 0

            # Add Lua size
            if lua_version in self.registry["lua_downloads"]:
                lua_info = self.registry["lua_downloads"][lua_version]
                total_size += sum(f["size"] for f in lua_info["files"].values())
                file_count += len(lua_info["files"])

            # Add LuaRocks size
            luarocks_key = f"{luarocks_version}-{platform}"
            if luarocks_key in self.registry["luarocks_downloads"]:
                luarocks_info = self.registry["luarocks_downloads"][luarocks_key]
                total_size += sum(f["size"] for f in luarocks_info["files"].values())
                file_count += len(luarocks_info["files"])

            versions.append({
                "key": version_key,
                "lua_version": lua_version,
                "luarocks_version": luarocks_version,
                "platform": platform,
                "created": combo_info["created"],
                "total_size": total_size,
                "formatted_size": format_file_size(total_size),
                "file_count": file_count
            })

        return versions

    def cleanup_version(self, lua_version: str, luarocks_version: str, platform: str = "windows-64") -> Tuple[bool, str]:
        """Remove downloaded files for a specific version combination."""
        version_key = self.get_version_key(lua_version, luarocks_version)

        try:
            # Remove from combinations registry
            if version_key in self.registry["combinations"]:
                del self.registry["combinations"][version_key]

            # Check if this was the last combination using this Lua version
            lua_still_used = any(
                combo["lua_version"] == lua_version
                for combo in self.registry["combinations"].values()
            )

            # If Lua version is no longer used, remove it
            if not lua_still_used and lua_version in self.registry["lua_downloads"]:
                lua_dir = self.get_lua_dir(lua_version)
                if lua_dir.exists():
                    import shutil
                    shutil.rmtree(lua_dir)
                    print(f"  Removed Lua {lua_version} directory")
                del self.registry["lua_downloads"][lua_version]

            # Check if this was the last combination using this LuaRocks version
            luarocks_key = f"{luarocks_version}-{platform}"
            luarocks_still_used = any(
                combo["luarocks_version"] == luarocks_version and combo.get("platform", "windows-64") == platform
                for combo in self.registry["combinations"].values()
            )

            # If LuaRocks version is no longer used, remove it
            if not luarocks_still_used and luarocks_key in self.registry["luarocks_downloads"]:
                luarocks_dir = self.get_luarocks_dir(luarocks_version, platform)
                if luarocks_dir.exists():
                    import shutil
                    shutil.rmtree(luarocks_dir)
                    print(f"  Removed LuaRocks {luarocks_key} directory")
                del self.registry["luarocks_downloads"][luarocks_key]

            self._save_registry()
            return True, f"Cleaned up {version_key}"

        except Exception as e:
            return False, f"Failed to cleanup {version_key}: {str(e)}"

    def cleanup_old_versions(self, keep_latest: int = 3) -> Tuple[bool, str]:
        """Remove old downloaded version combinations, keeping only the latest N."""
        if len(self.registry["combinations"]) <= keep_latest:
            return True, "No cleanup needed"

        # Sort by creation date
        combinations = sorted(
            self.registry["combinations"].items(),
            key=lambda x: x[1]["created"],
            reverse=True
        )

        # Keep the latest N, remove the rest
        to_remove = combinations[keep_latest:]
        removed_count = 0

        for version_key, combo_info in to_remove:
            lua_version = combo_info["lua_version"]
            luarocks_version = combo_info["luarocks_version"]
            platform = combo_info.get("platform", "windows-64")
            success, _ = self.cleanup_version(lua_version, luarocks_version, platform)
            if success:
                removed_count += 1

        return True, f"Removed {removed_count} old version combinations"

    def get_registry_info(self) -> Dict:
        """Get information about the download registry."""
        total_size = 0

        # Calculate total size from all Lua downloads
        for lua_info in self.registry["lua_downloads"].values():
            total_size += sum(f["size"] for f in lua_info["files"].values())

        # Calculate total size from all LuaRocks downloads
        for luarocks_info in self.registry["luarocks_downloads"].values():
            total_size += sum(f["size"] for f in luarocks_info["files"].values())

        return {
            "combination_count": len(self.registry["combinations"]),
            "lua_versions": len(self.registry["lua_downloads"]),
            "luarocks_versions": len(self.registry["luarocks_downloads"]),
            "total_size": total_size,
            "formatted_size": format_file_size(total_size),
            "registry_file": str(self.registry_file),
            "base_dir": str(self.base_dir),
            "lua_dir": str(self.lua_dir),
            "luarocks_dir": str(self.luarocks_dir)
        }
