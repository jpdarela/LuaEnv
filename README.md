# LuaEnv - Lua Environment Management for Windows

A Lua environment management system for Windows that provides automated installation, building, and configuration of Lua and LuaRocks using the Microsoft Visual C++ (MSVC) toolchain. LuaEnv enables developers to easily manage multiple Lua installations with different versions and build configurations while providing integration with C/C++ development workflows.

# Table of Contents

- [Project Overview](#project-overview)
- [Installation](#installation)
  - [Prerequisites](#prerequisites)
  - [Installation Steps](#installation-steps)
- [Usage](#usage)
  - [Running the CLI](#running-the-cli)
  - [Environment Isolation](#environment-isolation)
- [Project Structure](#project-structure)
  - [Repository Structure](#repository-structure)
  - [Installation Directory Structure](#installation-directory-structure)
- [Testing](#testing)
- [Contributing](#contributing)

# Project Overview

LuaEnv is a Lua environment management system designed specifically for Windows developers using the Microsoft Visual C++ (MSVC) toolchain. The system provides automated installation, building, and configuration of Lua and LuaRocks while enabling management of multiple isolated environments.

## Architecture Components

### 1. Bootstrap and Installation System
- **Embedded Python Environment**: Self-contained Python 3.13.5 for reliable execution across systems
- **Automated Setup**: Complete system bootstrap from scratch via `setup.ps1`
- **Installation Management**: Comprehensive installation orchestration through `install.py`

### 2. F# CLI Application
- **Multi-Architecture Support**: Builds for x64, x86, and ARM64 platforms
- **Environment Management**: Installation creation, listing, removal, and configuration
- **pkg-config Integration**: MSVC-compatible compiler flag generation for C/C++ projects
- **JIT Optimization**: Warm-up functionality for improved first-run performance

### 3. Python Backend System
- **Configuration Management**: Centralized version control via `build_config.txt`
- **Download Management**: Version-aware downloading with registry and caching (240-hour expiry)
- **Build Orchestration**: Complete Lua/LuaRocks compilation process with MSVC integration
- **Registry System**: UUID-based installation tracking in `%USERPROFILE%\.luaenv`

### 4. PowerShell Integration
- **Environment Activation**: Session-specific Lua environment setup
- **Visual Studio Integration**: Automatic MSVC toolchain detection and configuration
- **CLI Wrapper System**: Seamless command forwarding and environment handling

## Key Features

- **Multi-Version Support**: Manage multiple Lua and LuaRocks versions simultaneously
- **Build Configuration**: Static library and DLL builds with debug/release configurations
- **Environment Isolation**: Separate installations with UUID-based identification
- **MSVC Integration**: Automatic Visual Studio toolchain detection and setup
- **pkg-config Support**: MSVC-compatible compiler flag generation for build systems
- **Download Management**: Version-aware downloading with caching and integrity verification

# Installation

## Prerequisites

- **Visual Studio 2019/2022** with C++ development tools (Community, Professional, or Enterprise)
- **PowerShell 5.1+** (included with Windows)
- **.NET SDK 9.0+** (for CLI building, optional - pre-built binaries are included)
- **Internet connection** (for downloading Lua/LuaRocks sources)

## Installation Steps

### Overview of the Bootstrap Process

LuaEnv uses a two-stage bootstrap process:

1. **setup.ps1**: Bootstrap script that downloads embedded Python 3.13.5 and orchestrates installation
2. **install.py**: Installation script that uses the embedded Python and backend registry system

The `setup.ps1` script handles:
- Downloads and extracts embedded Python 3.13.5 (24MB zip file)
- Optionally builds the F# CLI application with JIT warm-up
- Calls `install.py` with appropriate arguments for system installation

The `install.py` script handles:
- Uses embedded Python with fallback to system Python
- Installs PowerShell wrapper scripts to `~/.luaenv/bin`
- Deploys CLI binaries from build output to installation directory
- Creates backend configuration file and directory structure

### Step 1: Clone the Repository

```powershell
git clone <repository-url>
cd lua_msvc_build
```

### Step 2: Run Bootstrap Installation

```powershell
# Complete setup (recommended)
.\setup.ps1

# Build CLI first, then install (includes JIT warm-up)
.\setup.ps1 -BuildCli

# Force Python reinstall only
.\setup.ps1 -Python

# Complete reset (removes ~/.luaenv)
.\setup.ps1 -Reset
```

### Step 3: Verify Installation

Dependencies are automatically managed:
- Embedded Python 3.13.5 is downloaded automatically
- CLI binaries are deployed from pre-built `win64/` folder
- PowerShell wrapper scripts are installed to `~/.luaenv/bin`
- Visual Studio toolchain is detected automatically during environment usage

# Usage

## Running the CLI

LuaEnv uses a PowerShell wrapper script system that provides seamless integration between PowerShell and the F# CLI application.

### Wrapper Script Architecture

The CLI system uses a multi-layer architecture:

1. **luaenv.ps1**: PowerShell wrapper script installed to `~/.luaenv/bin/`
2. **LuaEnv.CLI.exe**: F# executable located in `~/.luaenv/bin/cli/`
3. **backend.config**: JSON configuration file for backend integration

The wrapper automatically:
- Loads backend configuration from `~/.luaenv/bin/backend.config`
- Validates commands and forwards CLI commands to the F# executable
- Handles PowerShell-specific environment activation
- Provides consistent error handling and help

### Primary Interface: luaenv Command

After installation, use the `luaenv` command from the `~/.luaenv/bin` directory:

```powershell
# Environment management
luaenv list                          # List all installations
luaenv install --alias dev           # Create new installation with alias
luaenv install --alias prod --x86    # Create 32-bit installation
luaenv install --dll --debug         # Create DLL build with debug symbols
luaenv uninstall dev                 # Remove installation
luaenv status                        # Show system status

# Package configuration for C/C++ integration
luaenv pkg-config dev --cflag        # Get MSVC compiler flags
luaenv pkg-config dev --lua-include  # Get include directory
luaenv pkg-config dev --liblua       # Get library file path
luaenv pkg-config dev --json         # JSON output for build systems

# System information
luaenv versions                      # Show version information
luaenv config                        # Show current configuration
luaenv help                          # Show help information
```

### Environment Activation

```powershell
# Activate environment in current PowerShell session
luaenv activate --alias dev
luaenv activate --id a1b2c3d4
luaenv activate --list               # List available environments

# Visual Studio environment setup
setenv.ps1 -Current                  # Configure MSVC toolchain in current session
setenv.ps1                           # Launch new VS Developer Shell
setenv.ps1 -Arch x86 -Current        # Configure for 32-bit builds
```

### What Environment Activation Does

1. **Visual Studio Setup**: Automatically configures MSVC toolchain using `setenv.ps1`
2. **PATH Configuration**: Adds Lua and LuaRocks executables to PATH
3. **Module Paths**: Sets `LUA_PATH` and `LUA_CPATH` for module loading
4. **LuaRocks Config**: Configures LuaRocks for package compilation
5. **Session Variables**: Sets environment markers for current session

### Available CLI Commands

- **install**: Install new Lua environment with version and build options
- **uninstall**: Remove existing installation by alias or UUID
- **list**: Display all installed environments with details
- **status**: Show system status and registry information
- **versions**: Display available and installed versions
- **pkg-config**: Generate MSVC-compatible compiler flags for C/C++ projects
- **config**: Show current backend configuration
- **activate**: PowerShell-only command for environment activation
- **help**: Display help information for commands

## Environment Isolation

LuaEnv provides complete environment isolation through a UUID-based registry system and separate installation directories.

### Installation Separation
- **Unique UUIDs**: Each installation has a unique identifier stored in the registry
- **Separate Directories**: `~/.luaenv/installations/{uuid}/` for each environment
- **Independent Configurations**: Separate build configurations and package trees
- **Version Independence**: Different Lua/LuaRocks versions per environment

### Package Isolation
- **Dedicated LuaRocks Trees**: Each environment has its own package tree in the installation directory
- **Module Path Isolation**: `LUA_PATH` and `LUA_CPATH` are environment-specific during activation
- **No Cross-Contamination**: Packages installed in one environment don't affect others

### Configuration Isolation
- **Build Settings**: Static vs DLL, Debug vs Release configurations per environment
- **Compiler Flags**: Environment-specific MSVC configurations via pkg-config
- **Runtime Dependencies**: Separate DLL and library paths prevent conflicts

# Project Structure

## Repository Structure

```
lua_msvc_build/
├── README.md                   # This file
├── setup.ps1                   # Bootstrap installer with embedded Python management
├── build_cli.ps1              # F# CLI builder with multi-architecture support
├── install.py                  # Installation orchestrator using embedded Python
├── activate.cmd                # Command prompt activation wrapper
├── build_cli_aot.ps1          # AOT (Ahead-of-Time) CLI compilation script
├── backend/                    # Python backend system
│   ├── __init__.py            # Package initialization
│   ├── config.py              # Configuration management (build_config.txt)
│   ├── registry.py            # UUID-based installation registry
│   ├── download_manager.py    # Version-aware download system
│   ├── download_lua_luarocks.py # Download orchestration script
│   ├── build.py               # Lua/LuaRocks compilation orchestrator
│   ├── setup_build.py         # Build script preparation
│   ├── setup_lua.py           # Complete installation workflow
│   ├── pkg_config.py          # MSVC pkg-config support
│   ├── utils.py               # Utility functions and file operations
│   ├── clean.py               # Smart cleanup with safety checks
│   ├── run_tests.py           # Test runner for backend components
│   ├── luaenv.ps1            # CLI wrapper and environment activator
│   ├── setenv.ps1            # Visual Studio environment setup
│   ├── version_cache.json     # Version discovery cache
│   ├── build_scripts/         # MSVC build scripts
│   │   ├── build-static.bat   # Static library build
│   │   ├── build-dll.bat      # DLL build
│   │   ├── build-static-debug.bat # Debug static build
│   │   ├── build-dll-debug.bat    # Debug DLL build
│   │   ├── install_lua_dll.py     # DLL installation script
│   │   └── setup-luarocks.bat     # LuaRocks setup
│   ├── downloads/             # Downloaded source archives
│   │   ├── download_registry.json # Download tracking
│   │   ├── lua/              # Lua source archives by version
│   │   └── luarocks/         # LuaRocks archives by version
│   ├── extracted/            # Extracted source directories
│   │   ├── lua-X.X.X/        # Extracted Lua sources
│   │   ├── lua-X.X.X-tests/  # Extracted Lua test suites
│   │   └── luarocks-X.X.X-windows-XX/ # Extracted LuaRocks
│   └── tests/                # Backend-specific tests
│       ├── test_config_basic.py      # Basic configuration tests
│       ├── test_config_cache.py      # Version cache tests
│       ├── test_config_cli.py        # CLI configuration tests
│       ├── test_download.py          # Download system tests
│       └── test_setup_build.py       # Build setup tests
├── cli/                       # F# CLI application
│   ├── LuaEnv.sln            # Visual Studio solution
│   ├── LuaEnv.CLI/           # Main CLI project
│   │   ├── LuaEnv.CLI.fsproj # Project file
│   │   ├── Program.fs        # CLI entry point and command parsing
│   │   ├── bin/              # Build output
│   │   └── obj/              # Build intermediates
│   └── LuaEnv.Core/          # Core library project
│       ├── LuaEnv.Core.fsproj # Core project file
│       ├── Types.fs          # Type definitions
│       ├── RegistryAccess.fs # Registry integration
│       ├── bin/              # Build output
│       └── obj/              # Build intermediates
├── examples/                  # Integration examples and tests
│   └── build_systems/        # Build system integration examples
│       ├── main.c            # Sample C program using Lua API
│       ├── CMakeLists.txt    # CMake configuration
│       ├── meson.build       # Meson build configuration
│       ├── Makefile          # GNU Make configuration
│       ├── Makefile_win      # Windows nmake configuration
│       ├── build.bat         # Batch script example
│       ├── build.ps1         # PowerShell script example
│       ├── build_all.ps1     # Comprehensive test script
│       └── README.md         # Integration documentation
├── tests/                     # Repository-level tests
│   ├── unit/                 # Unit tests
│   └── integration/          # Integration tests
├── python/                    # Embedded Python 3.13.5
│   ├── python.exe            # Python interpreter
│   ├── python313.dll         # Python runtime
│   ├── python313.zip         # Standard library
│   └── [additional runtime files]
├── win64/                   # Pre-built CLI binaries (.NET runtime included)
│   ├── LuaEnv.CLI.exe        # Main CLI executable
│   ├── LuaEnv.Core.dll       # Core library
│   ├── FSharp.Core.dll       # F# runtime
│   └── [.NET runtime dependencies]
```

## Installation Directory Structure

```
%USERPROFILE%\.luaenv/
├── registry.json              # Installation registry with UUID tracking
├── bin/                       # Global scripts and CLI binaries
│   ├── luaenv.ps1            # CLI wrapper and environment activator
│   ├── setenv.ps1            # Visual Studio environment setup
│   ├── backend.config        # Backend configuration (JSON)
│   └── cli/                  # F# CLI binaries
│       ├── LuaEnv.CLI.exe    # Main executable
│       ├── LuaEnv.Core.dll   # Core library
│       ├── FSharp.Core.dll   # F# runtime
│       └── [dependencies]    # .NET runtime dependencies
├── installations/             # Individual Lua installations
│   └── {uuid}/               # UUID-named installations
│       ├── bin/              # Lua executables (lua.exe, luac.exe)
│       ├── include/          # Header files (lua.h, luaconf.h, etc.)
│       ├── lib/              # Libraries (lua54.lib, lua54.dll if DLL build)
│       ├── share/            # Documentation and extras
│       │   ├── lua/          # Lua module directory
│       │   └── doc/          # Documentation
│       └── luarocks/         # LuaRocks installation tree
│           ├── bin/          # luarocks.exe
│           ├── lua/          # LuaRocks modules
│           └── rocks/        # Installed packages
├── environments/             # Environment-specific data
│   └── {uuid}/               # Per-environment configurations
└── cache/                    # Download and build cache
    ├── downloads/            # Cached source downloads
    └── build/                # Build artifacts cache
```

### Tests

Not completed yet.

```powershell
# Run repository-level tests
cd tests
python run_all_tests.py

# Run specific test types
python -m pytest unit/            # Unit tests only
python -m pytest integration/     # Integration tests only
```

### CLI Development Testing Workflow

Check the --help output for the CLI commands to understand their usage and options.

```powershell
# Build and test CLI changes
.\build_cli.ps1                   # Build CLI from root directory
.\install.py --cli --force        # Deploy CLI to ~/.luaenv/bin
cd ~/.luaenv/bin
.\luaenv.ps1 help                 # Test CLI functionality
.\luaenv.ps1 list                 # Test environment listing
.\luaenv.ps1 status               # Test status reporting
```


## Development Workflow

1. **Build CLI**: `.\build_cli.ps1` (from root directory)
2. **Deploy Changes**: `.\install.py --cli --force` (deploy CLI only) or `.\setup.ps1 -Reset` (complete reset)
3. **Test Changes**: Navigate to `~/.luaenv/bin` and test with `.\luaenv.ps1`
4. **Run Tests**: Execute backend tests and integration tests as needed

## Architecture Guidelines

- **Backend Scripts**: Designed to run from `backend/` directory with relative imports
- **Dual-Context Design**: Support both CLI execution and module import patterns
- **No Backwards Compatibility**: Rapid iteration without breaking change concerns
- **Configuration-Driven**: Use `build_config.txt` as single source of truth
- **Error Recovery**: Include comprehensive error handling and cleanup

## Code Style

- **PowerShell**: Use `-Help` parameters and comprehensive help systems for all scripts
- **Python**: Follow dual-context import patterns for CLI execution and module usage
- **F#**: Maintain clean separation between CLI (command parsing) and Core (logic) projects
- **Documentation**: TODO

## Testing Requirements

- **Unit Tests**: Test individual components in isolation (download_manager, config system) PARTIAL
- **Integration Tests**: Test complete workflows end-to-end (download → build → install) PARTIAL
- **Build Examples**: Verify pkg-config integration with real build systems (CMake, Meson, Make)
- **CLI Tests**: Validate command parsing, backend communication, and output formatting TODO

## Development Notes

- The project is in active development with no established userbase
- Breaking changes are acceptable in favor of simplicity and clarity
- Embedded Python (3.13.5) is preferred over system Python for reliability
- Pre-built CLI binaries are included in `win64/` directory for convenience
