#!/usr/bin/env python3
"""
LuaEnv Registry Management System

Manages UUID-based Lua installations in %USERPROFILE%\\.luaenv
Provides centralized tracking of installations, environments, and aliases.
"""

import json
import uuid
import shutil
import sys
import os
from pathlib import Path
from datetime import datetime, timezone
from typing import Dict, List, Optional

# Ensure we can import from the current directory when run from CLI
if __name__ == "__main__" or "backend" not in sys.path:
    current_dir = os.path.dirname(os.path.abspath(__file__))
    if current_dir not in sys.path:
        sys.path.insert(0, current_dir)

# Import utilities with dual-context support
try:
    from utils import get_backend_dir, print_error
except ImportError:
    try:
        from .utils import get_backend_dir
    except ImportError as e:
        print(f"Error importing utilities: {e}")
        print("Make sure utils.py is in the same directory as this script.")
        sys.exit(1)


class LuaEnvRegistry:
    """Manages the LuaEnv installation registry."""

    REGISTRY_VERSION = "1.0"

    def __init__(self, registry_path: Optional[Path] = None):
        """Initialize registry manager.

        Args:
            registry_path: Custom registry path, defaults to %USERPROFILE%\\.luaenv\\registry.json
        """
        if registry_path:
            self.registry_path = Path(registry_path)
        else:
            self.registry_path = Path.home() / ".luaenv" / "registry.json"

        self.luaenv_root = self.registry_path.parent
        self.installations_root = self.luaenv_root / "installations"
        self.environments_root = self.luaenv_root / "environments"
        self.cache_root = self.luaenv_root / "cache"

        # Ensure directories exist
        self._ensure_directories()

        # Load or create registry
        self.registry = self._load_registry()

    def _ensure_directories(self) -> None:
        """Create LuaEnv directory structure if it doesn't exist."""
        for directory in [self.luaenv_root, self.installations_root,
                         self.environments_root, self.cache_root]:
            directory.mkdir(parents=True, exist_ok=True)

    def _load_registry(self) -> Dict:
        """Load registry from file or create new one."""
        if self.registry_path.exists():
            try:
                with open(self.registry_path, 'r', encoding='utf-8') as f:
                    registry = json.load(f)

                # Validate registry version
                if registry.get("registry_version") != self.REGISTRY_VERSION:
                    print(f"[WARNING] Registry version mismatch. Expected {self.REGISTRY_VERSION}, "
                          f"found {registry.get('registry_version', 'unknown')}")

                return registry
            except (json.JSONDecodeError, FileNotFoundError) as e:
                print(f"[WARNING] Could not load registry: {e}")
                print("[INFO] Creating new registry")

        # Create new registry
        return {
            "registry_version": self.REGISTRY_VERSION,
            "created": datetime.now(timezone.utc).isoformat(),
            "updated": datetime.now(timezone.utc).isoformat(),
            "default_installation": None,
            "installations": {},
            "aliases": {}
        }

    def _save_registry(self) -> None:
        """Save registry to file with backup."""
        # Create backup if registry exists
        if self.registry_path.exists():
            backup_path = self.registry_path.with_suffix('.json.backup')
            shutil.copy2(self.registry_path, backup_path)

        # Update timestamp
        self.registry["updated"] = datetime.now(timezone.utc).isoformat()

        # Save registry
        with open(self.registry_path, 'w', encoding='utf-8') as f:
            json.dump(self.registry, f, indent=2, ensure_ascii=False)

    def generate_installation_id(self) -> str:
        """Generate new UUID4 for installation."""
        return str(uuid.uuid4())

    def create_installation(self, lua_version: str, luarocks_version: str,
                          build_type: str, build_config: str = "release",
                          name: Optional[str] = None, alias: Optional[str] = None,
                          architecture: str = "x64") -> str:
        """Create new installation record.

        Args:
            lua_version: Lua version (e.g., "5.4.8")
            luarocks_version: LuaRocks version (e.g., "3.12.2")
            build_type: "dll" or "static"
            build_config: "release" or "debug"
            name: Optional descriptive name
            alias: Optional alias for the installation
            architecture: Target architecture - "x64" (default) or "x86"

        Returns:
            Installation UUID
        """
        installation_id = self.generate_installation_id()

        # Generate default name if not provided
        if not name:
            arch_display = "x86" if architecture == "x86" else "x64"
            name = f"Lua {lua_version} {build_type.upper()} {build_config.title()} ({arch_display})"

        # VALIDATE ALIAS BEFORE CREATING ANYTHING
        if alias and alias in self.registry["aliases"]:
            print_error(f"[ERROR] Alias '{alias}' already exists")
            raise ValueError(f"Alias '{alias}' already exists")

        # Create installation directories
        install_path = self.installations_root / installation_id
        env_path = self.environments_root / installation_id

        try:
            install_path.mkdir(parents=True, exist_ok=True)
            env_path.mkdir(parents=True, exist_ok=True)

            # Create installation record
            installation = {
                "id": installation_id,
                "name": name,
                "alias": alias,
                "lua_version": lua_version,
                "luarocks_version": luarocks_version,
                "build_type": build_type,
                "build_config": build_config,
                "architecture": architecture,
                "created": datetime.now(timezone.utc).isoformat(),
                "last_used": None,
                "status": "building",
                "installation_path": str(install_path),
                "environment_path": str(env_path),
                "packages": {
                    "count": 0,
                    "last_updated": None
                },
                "tags": []
            }

            # Add to registry
            self.registry["installations"][installation_id] = installation

            # Set alias if provided (already validated above)
            if alias:
                self.registry["aliases"][alias] = installation_id

            # Set as default if this is the first installation
            if not self.registry["default_installation"]:
                self.registry["default_installation"] = installation_id

            self._save_registry()

            print(f"[OK] Created installation '{name}' with ID: {installation_id}")
            if alias:
                print(f"[OK] Set alias: {alias} -> {installation_id}")

            return installation_id

        except Exception as e:
            # CLEANUP ON ERROR: Remove directories and registry entries
            print(f"[ERROR] Installation failed, cleaning up...")

            # Remove directories if they were created
            if install_path.exists():
                shutil.rmtree(install_path, ignore_errors=True)
                print(f"[CLEANUP] Removed installation directory: {install_path}")

            if env_path.exists():
                shutil.rmtree(env_path, ignore_errors=True)
                print(f"[CLEANUP] Removed environment directory: {env_path}")

            # Remove from registry if added
            if installation_id in self.registry["installations"]:
                del self.registry["installations"][installation_id]
                print(f"[CLEANUP] Removed installation from registry")

            if alias and alias in self.registry["aliases"]:
                del self.registry["aliases"][alias]
                print(f"[CLEANUP] Removed alias from registry")

            # Save cleaned registry
            self._save_registry()

            # Re-raise the original error
            raise

    def get_installation(self, id_or_alias: str) -> Optional[Dict]:
        """Get installation by ID or alias.

        Args:
            id_or_alias: Full UUID, partial UUID (first 8+ chars), or alias

        Returns:
            Installation record or None if not found
        """
        # Try exact match first (alias or full UUID)
        if id_or_alias in self.registry["aliases"]:
            installation_id = self.registry["aliases"][id_or_alias]
            return self.registry["installations"].get(installation_id)

        if id_or_alias in self.registry["installations"]:
            return self.registry["installations"][id_or_alias]

        # Try partial UUID match (minimum 8 characters)
        if len(id_or_alias) >= 8:
            matches = []
            for installation_id in self.registry["installations"]:
                if installation_id.startswith(id_or_alias):
                    matches.append(installation_id)

            if len(matches) == 1:
                return self.registry["installations"][matches[0]]
            elif len(matches) > 1:
                print(f"[ERROR] Ambiguous partial ID '{id_or_alias}'. Matches: {matches}")
                return None

        return None

    def resolve_id(self, id_or_alias: str) -> Optional[str]:
        """Resolve alias or partial ID to full UUID.

        Args:
            id_or_alias: Full UUID, partial UUID, or alias

        Returns:
            Full UUID or None if not found
        """
        installation = self.get_installation(id_or_alias)
        return installation["id"] if installation else None

    def list_installations(self) -> List[Dict]:
        """Get list of all installations."""
        installations = list(self.registry["installations"].values())

        # Sort by creation date (newest first)
        installations.sort(key=lambda x: x["created"], reverse=True)

        return installations

    def remove_installation(self, id_or_alias: str, confirm: bool = True) -> bool:
        """Remove installation completely.

        Args:
            id_or_alias: Installation ID or alias
            confirm: Whether to prompt for confirmation

        Returns:
            True if removed, False if cancelled or not found
        """
        installation = self.get_installation(id_or_alias)
        if not installation:
            print(f"[ERROR] Installation '{id_or_alias}' not found")
            return False

        installation_id = installation["id"]

        if confirm:
            response = input(f"Remove installation '{installation['name']}' ({installation_id})? [y/N]: ")
            if response.lower() != 'y':
                print("[INFO] Removal cancelled")
                return False

        # Remove directories
        install_path = Path(installation["installation_path"])
        env_path = Path(installation["environment_path"])

        if install_path.exists():
            shutil.rmtree(install_path)
            print(f"[OK] Removed installation directory: {install_path}")

        if env_path.exists():
            shutil.rmtree(env_path)
            print(f"[OK] Removed environment directory: {env_path}")

        # Remove from registry
        del self.registry["installations"][installation_id]

        # Remove aliases pointing to this installation
        aliases_to_remove = []
        for alias, target_id in self.registry["aliases"].items():
            if target_id == installation_id:
                aliases_to_remove.append(alias)

        for alias in aliases_to_remove:
            del self.registry["aliases"][alias]
            print(f"[OK] Removed alias: {alias}")

        # Update default if needed
        if self.registry["default_installation"] == installation_id:
            remaining = list(self.registry["installations"].keys())
            self.registry["default_installation"] = remaining[0] if remaining else None
            if remaining:
                print(f"[INFO] Set new default installation: {remaining[0]}")

        self._save_registry()
        print(f"[OK] Removed installation: {installation['name']}")

        return True

    def set_alias(self, installation_id: str, alias: str) -> bool:
        """Set alias for installation.

        Args:
            installation_id: Full UUID of installation
            alias: Alias name

        Returns:
            True if set successfully
        """
        if installation_id not in self.registry["installations"]:
            print(f"[ERROR] Installation {installation_id} not found")
            return False

        if alias in self.registry["aliases"]:
            existing_id = self.registry["aliases"][alias]
            if existing_id != installation_id:
                print(f"[ERROR] Alias '{alias}' already points to {existing_id}")
                return False

        self.registry["aliases"][alias] = installation_id
        self.registry["installations"][installation_id]["alias"] = alias

        self._save_registry()
        print(f"[OK] Set alias: {alias} -> {installation_id}")

        return True

    def remove_alias(self, alias: str) -> bool:
        """Remove alias.

        Args:
            alias: Alias to remove

        Returns:
            True if removed
        """
        if alias not in self.registry["aliases"]:
            print(f"[ERROR] Alias '{alias}' not found")
            return False

        installation_id = self.registry["aliases"][alias]
        del self.registry["aliases"][alias]

        # Clear alias from installation record
        if installation_id in self.registry["installations"]:
            self.registry["installations"][installation_id]["alias"] = None

        self._save_registry()
        print(f"[OK] Removed alias: {alias}")

        return True

    def set_default(self, id_or_alias: str) -> bool:
        """Set default installation.

        Args:
            id_or_alias: Installation ID or alias

        Returns:
            True if set successfully
        """
        installation_id = self.resolve_id(id_or_alias)
        if not installation_id:
            print(f"[ERROR] Installation '{id_or_alias}' not found")
            return False

        self.registry["default_installation"] = installation_id
        self._save_registry()

        installation = self.registry["installations"][installation_id]
        print(f"[OK] Set default installation: {installation['name']} ({installation_id})")

        return True

    def get_default(self) -> Optional[Dict]:
        """Get default installation."""
        default_id = self.registry.get("default_installation")
        if default_id and default_id in self.registry["installations"]:
            return self.registry["installations"][default_id]
        return None

    def update_last_used(self, installation_id: str) -> None:
        """Update last used timestamp for installation."""
        if installation_id in self.registry["installations"]:
            self.registry["installations"][installation_id]["last_used"] = \
                datetime.now(timezone.utc).isoformat()
            self._save_registry()

    def update_status(self, installation_id: str, status: str) -> None:
        """Update installation status.

        Args:
            installation_id: Installation UUID
            status: New status (building, active, inactive, broken)
        """
        if installation_id in self.registry["installations"]:
            self.registry["installations"][installation_id]["status"] = status
            self._save_registry()

    def validate_installations(self) -> Dict[str, List[str]]:
        """Validate all installations and return issues.

        Returns:
            Dict with 'valid', 'broken', and 'missing' lists
        """
        valid = []
        broken = []
        missing = []

        for installation_id, installation in self.registry["installations"].items():
            install_path = Path(installation["installation_path"])
            env_path = Path(installation["environment_path"])

            # Check if directories exist
            if not install_path.exists() or not env_path.exists():
                missing.append(installation_id)
                continue

            # Check for required executables
            lua_exe = install_path / "bin" / "lua.exe"
            luac_exe = install_path / "bin" / "luac.exe"

            if not lua_exe.exists() or not luac_exe.exists():
                broken.append(installation_id)
                continue

            valid.append(installation_id)

        return {
            "valid": valid,
            "broken": broken,
            "missing": missing
        }

    def cleanup_broken(self, confirm: bool = True) -> int:
        """Remove broken and missing installations from registry.

        Args:
            confirm: Whether to prompt for confirmation

        Returns:
            Number of installations cleaned up
        """
        validation = self.validate_installations()
        to_remove = validation["broken"] + validation["missing"]

        if not to_remove:
            print("[INFO] No broken installations found")
            return 0

        print(f"[INFO] Found {len(to_remove)} broken installations:")
        for installation_id in to_remove:
            installation = self.registry["installations"][installation_id]
            print(f"  - {installation['name']} ({installation_id})")

        if confirm:
            response = input(f"Remove {len(to_remove)} broken installations? [y/N]: ")
            if response.lower() != 'y':
                print("[INFO] Cleanup cancelled")
                return 0

        count = 0
        for installation_id in to_remove:
            if self.remove_installation(installation_id, confirm=False):
                count += 1

        print(f"[OK] Cleaned up {count} broken installations")
        return count

    def cleanup_zombie_installations(self, confirm: bool = True) -> int:
        """Detect and clean up zombie installations (directories without registry entries).

        Args:
            confirm: Whether to prompt for confirmation

        Returns:
            Number of zombie installations cleaned up
        """
        zombies = []

        # Check for installation directories not in registry
        if self.installations_root.exists():
            for install_dir in self.installations_root.iterdir():
                if install_dir.is_dir() and install_dir.name not in self.registry["installations"]:
                    zombies.append(("installation", install_dir))

        # Check for environment directories not in registry
        if self.environments_root.exists():
            for env_dir in self.environments_root.iterdir():
                if env_dir.is_dir() and env_dir.name not in self.registry["installations"]:
                    zombies.append(("environment", env_dir))

        if not zombies:
            print("[INFO] No zombie installations found")
            return 0

        print(f"[INFO] Found {len(zombies)} zombie directories:")
        for zombie_type, zombie_path in zombies:
            print(f"  - {zombie_type}: {zombie_path}")

        if confirm:
            response = input(f"Remove all {len(zombies)} zombie directories? [y/N]: ")
            if response.lower() != 'y':
                print("[INFO] Cleanup cancelled")
                return 0

        cleaned = 0
        for zombie_type, zombie_path in zombies:
            try:
                shutil.rmtree(zombie_path)
                print(f"[OK] Removed zombie {zombie_type}: {zombie_path}")
                cleaned += 1
            except Exception as e:
                print(f"[ERROR] Failed to remove {zombie_path}: {e}")

        print(f"[OK] Cleaned up {cleaned} zombie installations")
        return cleaned

    def get_cache_path(self) -> Path:
        """Get cache directory path."""
        return self.cache_root

    def get_scripts_path(self) -> Path:
        """Get the path where LuaEnv scripts are installed."""
        scripts_path = self.luaenv_root / "bin"
        scripts_path.mkdir(parents=True, exist_ok=True)
        return scripts_path

    def _update_backend_config(self, scripts_path: Path) -> None:
        """Update backend configuration file for F# CLI and embedded Python access."""
        backend_config_path = scripts_path / "backend.config"

        try:
            # Get backend directory
            backend_dir = get_backend_dir()

            # Find embedded Python
            project_root = backend_dir.parent  # backend is inside project root
            embedded_python_dir = project_root / "python"
            embedded_python_exe = embedded_python_dir / "python.exe"

            # Create configuration object
            config = {
                "backend_dir": str(backend_dir),
                "embedded_python": {
                    "python_dir": str(embedded_python_dir),
                    "python_exe": str(embedded_python_exe),
                    "available": embedded_python_exe.exists()
                },
                "project_root": str(project_root),
                "config_version": "1.0",
                "created": datetime.now(timezone.utc).isoformat()
            }

            # Write JSON configuration
            with open(backend_config_path, 'w', encoding='utf-8') as f:
                json.dump(config, f, indent=2, ensure_ascii=False)

            print(f"[OK] Updated backend config (JSON): {backend_config_path}")

            if config["embedded_python"]["available"]:
                print(f"[OK] Embedded Python detected: {embedded_python_exe}")
            else:
                print(f"[WARNING] Embedded Python not found: {embedded_python_exe}")

        except Exception as e:
            print(f"[ERROR] Failed to update backend config: {e}")


    def install_scripts(self, force: bool = False) -> Path:
        """Install LuaEnv scripts to the global bin directory.

        Args:
            force: Overwrite existing scripts if they exist

        Returns:
            Path to the scripts directory
        """
        scripts_path = self.get_scripts_path()

        # Find the backend directory (where this script is located)
        backend_dir = get_backend_dir()

        # Scripts to install
        scripts_to_install = [
            ("setenv.ps1", "Visual Studio environment setup script"),
            ("use-lua.ps1", "Registry-aware Lua environment activation script"),
            ("luaenv.ps1", "LuaEnv CLI wrapper and environment activator"),
            ("backend.config", "Backend configuration for LuaEnv"),
        ]

        installed_scripts = []
        updated_scripts = []

        for script_name, description in scripts_to_install:

            if script_name == "backend.config":
                # Write backend.config directly to scripts_path
                self._update_backend_config(scripts_path)
                continue
            else:
                source_path = backend_dir / script_name
                target_path = scripts_path / script_name

            if not source_path.exists():
                print(f"[WARNING] Source script not found: {source_path}")
                continue

            # Check if target exists and handle accordingly
            if target_path.exists():
                if not force:
                    # Check if update is needed by comparing modification times
                    if source_path.stat().st_mtime <= target_path.stat().st_mtime:
                        print(f"[INFO] Script up to date: {script_name}")
                        continue
                    else:
                        print(f"[INFO] Updating script: {script_name}")
                        updated_scripts.append(script_name)
                else:
                    print(f"[INFO] Force installing script: {script_name}")
            else:
                print(f"[INFO] Installing script: {script_name}")
                installed_scripts.append(script_name)

            # Copy the script
            try:
                import shutil
                shutil.copy2(source_path, target_path)
                print(f"[OK] Installed {script_name} - {description}")
            except Exception as e:
                print(f"[ERROR] Failed to install {script_name}: {e}")
                continue

        # Create/update backend configuration for F# CLI
        self._update_backend_config(scripts_path)

        # Summary
        print(f"\n[SUCCESS] Script installation completed!")
        print(f"[INFO] Scripts directory: {scripts_path}")

        if installed_scripts:
            print(f"[INFO] Installed scripts: {', '.join(installed_scripts)}")
        if updated_scripts:
            print(f"[INFO] Updated scripts: {', '.join(updated_scripts)}")

        print(f"\n[IMPORTANT] Add to PATH: {scripts_path}")
        print(f"[INFO] After adding to PATH, you can use:")
        print(f"  use-lua.ps1 -List")
        print(f"  use-lua.ps1 -Alias <name>")
        print(f"  setenv.ps1")
        print(f"  luaenv.ps1 status")
        print(f"[INFO] For registry/install commands, use: luaenv.ps1 help")

        return scripts_path

    def get_path_instructions(self) -> str:
        """Get instructions for adding scripts to PATH."""
        scripts_path = self.get_scripts_path()

        instructions = f"""
[INFO] LuaEnv Scripts PATH Setup Instructions

1. TEMPORARY (Current Session Only):
   $env:PATH += ";{scripts_path}"

2. PERMANENT (User Profile):
   Add the following to your PowerShell profile:
   $env:PATH += ";{scripts_path}"

   To edit your profile:
   notepad $PROFILE

3. PERMANENT (System Environment):
   - Open System Properties > Environment Variables
   - Edit user PATH variable
   - Add: {scripts_path}

4. VERIFY INSTALLATION:
   Get-Command use-lua.ps1
   Get-Command setenv.ps1
   Get-Command luaenv.ps1

5. USAGE:
   use-lua.ps1 -List
   use-lua.ps1 -Alias <name>
   setenv.ps1
   luaenv.ps1 status  (CLI commands)
"""
        return instructions

    def check_scripts_in_path(self) -> dict:
        """Check if LuaEnv scripts are accessible via PATH."""
        scripts_path = self.get_scripts_path()

        result = {
            "scripts_path": str(scripts_path),
            "path_accessible": False,
            "scripts_status": {}
        }

        scripts_to_check = ["use-lua.ps1", "setenv.ps1", "luaenv.ps1"]

        for script_name in scripts_to_check:
            script_path = scripts_path / script_name
            script_exists = script_path.exists()

            # Try to find script in PATH (simplified check)
            try:
                import subprocess
                check_result = subprocess.run(
                    ["powershell", "-Command", f"Get-Command {script_name} -ErrorAction SilentlyContinue"],
                    capture_output=True, text=True, timeout=5
                )
                in_path = check_result.returncode == 0 and script_name in check_result.stdout
            except:
                in_path = False

            result["scripts_status"][script_name] = {
                "exists": script_exists,
                "in_path": in_path
            }

            if script_exists and in_path:
                result["path_accessible"] = True

        return result

    def print_status(self) -> None:
        """Print registry status information."""
        installations = self.list_installations()
        default = self.get_default()

        print(f"[INFO] LuaEnv Registry Status")
        print(f"[INFO] Registry Path: {self.registry_path}")
        print(f"[INFO] LuaEnv Root: {self.luaenv_root}")
        print(f"[INFO] Total Installations: {len(installations)}")

        if default:
            print(f"[INFO] Default Installation: {default['name']} ({default['id']})")
        else:
            print("[INFO] No default installation set")

        if self.registry["aliases"]:
            print("[INFO] Aliases:")
            for alias, installation_id in self.registry["aliases"].items():
                installation = self.registry["installations"][installation_id]
                print(f"  {alias} -> {installation['name']} ({installation_id})")

        if installations:
            print("[INFO] Installations:")
            for installation in installations:
                status_mark = "[ACTIVE]" if installation["status"] == "active" else f"[{installation['status'].upper()}]"
                alias_info = f" (alias: {installation['alias']})" if installation['alias'] else ""
                print(f"  {status_mark} {installation['name']}{alias_info}")
                print(f"    ID: {installation['id']}")
                print(f"    Lua: {installation['lua_version']}, LuaRocks: {installation['luarocks_version']}")
                print(f"    Build: {installation['build_type']} {installation['build_config']}")
                if installation['last_used']:
                    print(f"    Last used: {installation['last_used']}")

    def install_fsharp_cli_with_deps(self, publish_dir_path: Path, force: bool = False) -> bool:
        """Install F# CLI with all dependencies from publish directory.

        Args:
            publish_dir_path: Path to the publish directory containing all files
            force: Whether to overwrite existing installation

        Returns:
            bool: True if successful, False otherwise
        """
        scripts_path = self.get_scripts_path()
        cli_dir = scripts_path / "cli"

        if not publish_dir_path.exists():
            print(f"[ERROR] Publish directory not found: {publish_dir_path}")
            return False

        exe_file = publish_dir_path / "LuaEnv.CLI.exe"
        if not exe_file.exists():
            print(f"[ERROR] Main executable not found: {exe_file}")
            return False

        if cli_dir.exists() and not force:
            print(f"[INFO] F# CLI already installed at: {cli_dir}")
            print("[INFO] Use --force to overwrite")
            return True

        try:
            # Remove existing CLI directory if it exists
            if cli_dir.exists():
                shutil.rmtree(cli_dir)

            # Copy entire publish directory
            shutil.copytree(publish_dir_path, cli_dir)
            print(f"[OK] Installed F# CLI with dependencies: {cli_dir}")

            return True

        except Exception as e:
            print(f"[ERROR] Failed to install F# CLI: {e}")
            return False


def main():
    """Command line interface for registry management."""
    import argparse

    parser = argparse.ArgumentParser(description="LuaEnv Registry Management")
    subparsers = parser.add_subparsers(dest='command', help='Available commands')

    # Registry command
    parser.add_argument('-r', '--register',
                       type=str,
                       help='Path to a custom registry file.')
    # List command
    list_parser = subparsers.add_parser('list', help='List all installations')

    # Status command
    status_parser = subparsers.add_parser('status', help='Show registry status')

    # Remove command
    remove_parser = subparsers.add_parser('remove', help='Remove installation')
    remove_parser.add_argument('id_or_alias', help='Installation ID or alias')
    remove_parser.add_argument('--yes', action='store_true', help='Skip confirmation')

    # Alias commands
    alias_parser = subparsers.add_parser('alias', help='Manage aliases')
    alias_subparsers = alias_parser.add_subparsers(dest='alias_command')

    set_alias_parser = alias_subparsers.add_parser('set', help='Set alias')
    set_alias_parser.add_argument('installation_id', help='Installation ID')
    set_alias_parser.add_argument('alias', help='Alias name')

    remove_alias_parser = alias_subparsers.add_parser('remove', help='Remove alias')
    remove_alias_parser.add_argument('alias', help='Alias name')

    # Default command
    default_parser = subparsers.add_parser('default', help='Set default installation')
    default_parser.add_argument('id_or_alias', help='Installation ID or alias')

    # Validate command
    validate_parser = subparsers.add_parser('validate', help='Validate installations')

    # Cleanup command
    cleanup_parser = subparsers.add_parser('cleanup', help='Clean up broken installations')
    cleanup_parser.add_argument('--yes', action='store_true', help='Skip confirmation')

    # Install scripts command
    install_scripts_parser = subparsers.add_parser('install-scripts', help='Install LuaEnv scripts')
    install_scripts_parser.add_argument('--force', action='store_true', help='Force install/overwrite scripts')

    # Scripts path command
    scripts_path_parser = subparsers.add_parser('scripts-path', help='Show LuaEnv scripts directory')

    # Check scripts command
    check_scripts_parser = subparsers.add_parser('check-scripts', help='Check LuaEnv scripts installation status')

    # Install F# CLI command
    install_cli_parser = subparsers.add_parser('install-cli', help='Install F# CLI executable')
    install_cli_parser.add_argument('exe_path', help='Path to the compiled F# CLI executable')
    install_cli_parser.add_argument('--force', action='store_true', help='Force install/overwrite existing executable')

    # Install F# CLI with dependencies command
    install_cli_deps_parser = subparsers.add_parser('install-cli-deps', help='Install F# CLI with all dependencies')
    install_cli_deps_parser.add_argument('publish_dir', help='Path to the publish directory containing all files')
    install_cli_deps_parser.add_argument('--force', action='store_true', help='Force install/overwrite existing installation')

    args = parser.parse_args()

    # Initialize registry
    # If a custom registry file is specified, use it; otherwise, use the default (%USERPROFILE%\.luaenv\registry.json)
    if args.register:
        registry = LuaEnvRegistry(registry_path=args.register)
    else:
        registry = LuaEnvRegistry()

    if not args.command:
        parser.print_help()
        return

    if args.command == 'list':
        installations = registry.list_installations()
        if not installations:
            print("[INFO] No installations found")
        else:
            print(f"[INFO] Found {len(installations)} installations:")
            for installation in installations:
                status_mark = "[DEFAULT]" if registry.get_default() and installation["id"] == registry.get_default()["id"] else f"[{installation['status'].upper()}]"
                alias_info = f" (alias: {installation['alias']})" if installation['alias'] else ""
                print(f"  {status_mark} {installation['name']}{alias_info}")
                print(f"    ID: {installation['id']}")
                print(f"    Lua: {installation['lua_version']}, LuaRocks: {installation['luarocks_version']}")
                print(f"    Build: {installation['build_type']} {installation['build_config']}")

    elif args.command == 'status':
        registry.print_status()

    elif args.command == 'remove':
        registry.remove_installation(args.id_or_alias, confirm=not args.yes)

    elif args.command == 'alias':
        if args.alias_command == 'set':
            registry.set_alias(args.installation_id, args.alias)
        elif args.alias_command == 'remove':
            registry.remove_alias(args.alias)
        else:
            alias_parser.print_help()

    elif args.command == 'default':
        registry.set_default(args.id_or_alias)

    elif args.command == 'validate':
        validation = registry.validate_installations()
        print(f"[INFO] Validation Results:")
        print(f"  Valid: {len(validation['valid'])}")
        print(f"  Broken: {len(validation['broken'])}")
        print(f"  Missing: {len(validation['missing'])}")

        if validation['broken']:
            print("[WARNING] Broken installations:")
            for installation_id in validation['broken']:
                installation = registry.registry["installations"][installation_id]
                print(f"  - {installation['name']} ({installation_id})")

        if validation['missing']:
            print("[WARNING] Missing installations:")
            for installation_id in validation['missing']:
                installation = registry.registry["installations"][installation_id]
                print(f"  - {installation['name']} ({installation_id})")

    elif args.command == 'cleanup':
        print("[INFO] Running cleanup operations...")

        # Clean up broken registry entries
        broken_count = registry.cleanup_broken(confirm=not args.yes)

        # Clean up zombie installations
        zombie_count = registry.cleanup_zombie_installations(confirm=not args.yes)

        total_cleaned = broken_count + zombie_count
        if total_cleaned > 0:
            print(f"[OK] Cleanup complete: {broken_count} broken entries + {zombie_count} zombie installations = {total_cleaned} total")
        else:
            print("[OK] No cleanup needed - everything is clean!")

    elif args.command == 'install-scripts':
        print("[INFO] Installing LuaEnv scripts to global bin directory...")
        try:
            registry.install_scripts()
            print("[OK] Scripts installed successfully")
            print(f"[INFO] Scripts location: {registry.get_scripts_path()}")
            print("\n[INFO] To make scripts globally accessible, add the bin directory to your PATH:")
            print(registry.get_path_instructions())
        except Exception as e:
            print(f"[ERROR] Failed to install scripts: {e}")
            return 1

    elif args.command == 'scripts-path':
        print("[INFO] LuaEnv scripts directory information:")
        scripts_path = registry.get_scripts_path()
        print(f"Scripts location: {scripts_path}")

        if registry.check_scripts_in_path():
            print("[OK] Scripts directory is in PATH")
        else:
            print("[WARNING] Scripts directory is NOT in PATH")
            print("\nTo add to PATH, run one of these commands:")
            print(registry.get_path_instructions())

    elif args.command == 'check-scripts':
        print("[INFO] Checking script installation status...")
        scripts_path = registry.get_scripts_path()

        if scripts_path.exists():
            print(f"[OK] Scripts directory exists: {scripts_path}")

            # Check individual scripts
            scripts = ['setenv.ps1', 'use-lua.ps1']
            for script in scripts:
                script_path = scripts_path / script
                if script_path.exists():
                    print(f"[OK] {script} installed")
                else:
                    print(f"[ERROR] {script} missing")

            # Check PATH
            if registry.check_scripts_in_path():
                print("[OK] Scripts directory is in PATH")
            else:
                print("[WARNING] Scripts directory is NOT in PATH")
                print("Run 'python registry.py scripts-path' for setup instructions")
        else:
            print(f"[ERROR] Scripts directory does not exist: {scripts_path}")
            print("Run 'python registry.py install-scripts' to install")

    elif args.command == 'install-cli':
        print("[INFO] Installing F# CLI executable...")
        from pathlib import Path
        exe_path = Path(args.exe_path)

        if registry.install_fsharp_cli(exe_path, force=args.force):
            print("[SUCCESS] F# CLI executable installed successfully")
            print("[INFO] You can now use 'luaenv.exe' commands globally")
            scripts_path = registry.get_scripts_path()
            print(f"[INFO] Make sure {scripts_path} is in your PATH")
        else:
            print("[ERROR] Failed to install F# CLI executable")
            return 1

    elif args.command == 'install-cli-deps':
        from pathlib import Path
        print("[INFO] Installing F# CLI with dependencies...")
        publish_dir = Path(args.publish_dir)

        if registry.install_fsharp_cli_with_deps(publish_dir, force=args.force):
            print("[SUCCESS] F# CLI with dependencies installed successfully")
            print("[INFO] You can now use 'luaenv.exe' commands globally")
            scripts_path = registry.get_scripts_path()
            print(f"[INFO] Make sure {scripts_path} is in your PATH")
        else:
            print("[ERROR] Failed to install F# CLI with dependencies")
            return 1


if __name__ == "__main__":
    main()
