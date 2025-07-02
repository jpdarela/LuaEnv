# LuaEnv Environment Management

## Overview

The `~/.luaenv/environments/` directories serve as **per-installation LuaRocks package trees**, providing isolated package management similar to Python virtual environments. Each Lua installation gets its own environment directory for managing its specific package dependencies.

## Current Implementation

### Structure
```
~/.luaenv/
├── installations/
│   ├── <uuid>/              # Lua/LuaRocks binaries
│   └── ...
├── environments/
│   ├── <uuid>/              # LuaRocks package tree (same UUID as installation)
│   │   ├── lib/lua/5.4/     # Compiled modules (.dll files)
│   │   ├── share/lua/5.4/   # Lua modules (.lua files)
│   │   └── bin/             # Package executables
│   └── ...
└── registry.json           # Installation metadata
```

### How It Works
1. **Creation**: Environment directories are created automatically when installations are registered
2. **Activation**: When using `use-lua.ps1`, the environment path becomes the LuaRocks tree
3. **Isolation**: Each installation has its own package dependencies and module paths
4. **Configuration**: LuaRocks is configured to install packages to the environment directory

## Current Status

**Investigation Results** (as of current inspection):
- 4 environment directories exist: `00cbbdd0...`, `00d886f9...`, `59ae2702...`, `92eeca9a...`
- All directories are currently **empty** (no packages installed)
- Environment paths are stored in `registry.json` under `environment_path` field
- `use-lua.ps1` script correctly configures LuaRocks to use these directories

## Proposed CLI Enhancements

### New Command: `luaenv env`

#### Subcommands

1. **`luaenv env list`** - List all environments
   ```powershell
   luaenv env list                    # Basic list
   luaenv env list --detailed         # Show disk usage and package counts
   luaenv env list --show-packages    # Include package details
   ```

2. **`luaenv env show <id|alias>`** - Show environment details
   ```powershell
   luaenv env show lua54              # Show environment for installation
   luaenv env show 00cbbdd0           # Show by UUID
   ```

3. **`luaenv env clean [id|alias]`** - Clean empty/orphaned environments
   ```powershell
   luaenv env clean                   # Clean all empty environments
   luaenv env clean lua54             # Clean specific environment
   ```

4. **`luaenv env reset <id|alias>`** - Reset environment (remove all packages)
   ```powershell
   luaenv env reset lua54             # Remove all packages from environment
   ```

#### Example Output

```
$ luaenv env list --detailed

LuaEnv Package Environments
============================

ID        NAME          ALIAS   PACKAGES  DISK USAGE  STATUS
--------  ------------  ------  --------  ----------  --------
00cbbdd0  Lua 5.4.8     lua54   0         0 B         Empty
00d886f9  Lua 5.4.8     dev     3         2.4 MB      Active
59ae2702  Lua 5.4.8     test    0         0 B         Empty
92eeca9a  Lua 5.4.8     prod    8         15.7 MB     Active

$ luaenv env show dev

Environment Details: Lua 5.4.8 (dev)
=====================================
Installation ID: 00d886f9-9229-43d4-8019-71f3e6c52ff3
Environment Path: C:\Users\user\.luaenv\environments\00d886f9-9229-43d4-8019-71f3e6c52ff3
Package Count: 3
Disk Usage: 2.4 MB

Installed Packages:
  • luasocket 3.1.0 - Network support for Lua
  • luafilesystem 1.8.0 - File system library
  • lpeg 1.0.2 - Parsing Expression Grammars
```

## Implementation Plan

### Phase 1: CLI Commands (Current)
- [x] Add environment types to `Types.fs`
- [x] Add argument parsing for `env` command
- [ ] Create `env_manager.py` backend script
- [ ] Implement environment inspection and management

### Phase 2: Backend Integration
- [ ] Add environment scanning to registry operations
- [ ] Implement package detection (parse LuaRocks manifests)
- [ ] Add cleanup operations for orphaned environments

### Phase 3: Advanced Features (Future)
- [ ] Package installation tracking
- [ ] Environment export/import
- [ ] Environment templates
- [ ] Integration with LuaRocks `list` command

## Technical Details

### Package Detection Strategy
1. **LuaRocks Manifest**: Parse `<env>/lib/luarocks/rocks-5.4/manifest` for installed packages
2. **Directory Scanning**: Scan `lib/lua/5.4/` and `share/lua/5.4/` for modules
3. **Metadata Extraction**: Read `.rockspec` files for package information

### Cleanup Operations
- **Empty Environments**: Remove environments with no packages
- **Orphaned Environments**: Remove environments whose installations no longer exist
- **Broken Packages**: Detect and remove incomplete package installations

### Integration Points
- **LuaRocks**: Use `luarocks list` to get accurate package information
- **Registry**: Update registry with package counts and environment status
- **Activation**: Ensure `use-lua.ps1` properly sets up environment paths

## Benefits

1. **Isolation**: Each installation has independent package dependencies
2. **Management**: Easy cleanup and reset of package environments
3. **Visibility**: Clear overview of what packages are installed where
4. **Maintenance**: Automated cleanup of orphaned and empty environments

## Notes

- Environment directories are separate from installation directories for flexibility
- Custom LuaRocks trees can still be specified via `use-lua.ps1 -Tree <path>`
- Environment management doesn't interfere with existing LuaRocks workflows
- Future versions could support environment templates or shared packages
