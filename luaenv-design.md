# LuaEnv - Lua Version Manager for Windows

## Vision
A `pyenv`-inspired Lua version manager with both CLI and GUI interfaces.

## Architecture
- **Language**: F# + .NET 8
- **GUI Framework**: Avalonia UI (cross-platform)
- **CLI Framework**: System.CommandLine
- **Configuration**: JSON + existing Python scripts as backend

## Features

### CLI Interface
```bash
# Version management
luaenv versions                    # List installed versions
luaenv versions --available       # List all available versions
luaenv install 5.4.8             # Install specific version
luaenv install 5.4.8 --debug     # Install debug build
luaenv install 5.4.8 --dll       # Install DLL build
luaenv uninstall 5.4.8           # Remove version

# Environment management
luaenv global 5.4.8              # Set global default
luaenv local 5.4.8               # Set local project version
luaenv shell 5.4.8               # Set session version
luaenv which lua                  # Show current lua path
luaenv whence lua                 # Show all versions with lua

# Project management
luaenv init                       # Setup shell integration
luaenv exec lua script.lua       # Run with specific version
luaenv shims                      # Manage shims

# Advanced
luaenv doctor                     # Check installation health
luaenv config                     # Show configuration
luaenv cache --clear             # Clear download cache
```

### GUI Interface
```bash
luaenv gui                        # Launch GUI
```

**GUI Features:**
- Version browser with install/uninstall buttons
- Build configuration (Static/DLL, Release/Debug)
- Project management
- Environment variable management
- Visual installation progress
- Integrated terminal
- Settings panel

## Implementation Plan

### Phase 1: Core CLI (F# Console App)
- Wrap existing Python scripts
- Basic version management
- Configuration management

### Phase 2: GUI (Avalonia UI)
- Modern, responsive interface
- Installation wizard
- Project management

### Phase 3: Advanced Features
- Shell integration (PowerShell, cmd)
- Auto-switching based on .lua-version files
- IDE integration helpers

## File Structure
```
luaenv/
├── src/
│   ├── LuaEnv.Core/           # Core logic (F#)
│   ├── LuaEnv.CLI/            # Command-line interface
│   ├── LuaEnv.GUI/            # Avalonia UI application
│   └── LuaEnv.Backend/        # Python script wrappers
├── assets/                    # UI assets, icons
├── docs/                      # Documentation
└── scripts/                   # Build/deployment scripts
```

## Technical Details

### Backend Integration
- Keep existing Python scripts as backend
- F# wrapper calls Python scripts
- Parse and transform outputs
- Handle configuration bridging

### Configuration
```json
{
  "globalVersion": "5.4.8",
  "installations": {
    "5.4.8": {
      "path": "C:\\Users\\user\\.luaenv\\versions\\5.4.8",
      "buildType": "static_release",
      "luaRocksVersion": "3.12.2"
    }
  },
  "cache": {
    "downloadPath": "C:\\Users\\user\\.luaenv\\cache",
    "lastUpdate": "2025-06-29T10:00:00Z"
  }
}
```

### Shims System
- Create executable shims for lua.exe, luac.exe
- Auto-route to correct version based on:
  1. LUAENV_VERSION env var
  2. .lua-version file (project local)
  3. Global default

## Benefits Over Current System

1. **Single Tool**: One command for everything
2. **Version Switching**: Easy switching between versions
3. **Project Isolation**: Per-project Lua versions
4. **GUI Option**: Visual management interface
5. **Shell Integration**: Automatic PATH management
6. **Cross-Platform**: Works on Windows/Linux/macOS (with Avalonia)

## Migration Path
1. Keep existing Python scripts as backend
2. F# wrapper provides new interface
3. Gradual feature migration to F#
4. Eventually could replace Python backend
