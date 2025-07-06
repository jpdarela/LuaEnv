# LuaEnv - Lua Environment Management for Windows

Under development. Contributions are welcome!

A Lua environment management system for Windows that provides automated building, installation, and configuration of Lua using the Microsoft Visual C++ (MSVC) toolchain. LuaEnv enables developers to easily manage multiple Lua installations with different versions and build configurations while providing integration with C/C++ development workflows. Luarocks binaries are download and installed/configured automatically. The system supports environment isolation through a UUID-based registry system.

Note: Each Lua installation is set with an independent instalation of Luarocks. This is probably not the best approach, but it is the simplest one for now. The LuaRocks installation is done automatically during the Lua installation process. This means that each Lua installation has its own LuaRocks executable, which can be useful for testing different versions of LuaRocks with different versions of Lua.

Note: The system supports working version of Lua (5.4) and LuaRocks > 3.9.0

Note: Older versions of Lua (5.1, 5.2, 5.3) are not supported by the system but can be integrated in the future.

Note: Check the [TODO.md](./TODO.md) file for the current development status and future plans.

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
- [Contributing](#contributing)
- [Use of LLMs via GitHub Copilot](#use-of-llms-via-github-copilot)
- [Notes on the backend system](#notes-on-the-backend-system)

# Project Overview

LuaEnv is a Lua environment management system designed specifically for Windows developers using the Microsoft Visual C++ (MSVC) toolchain. The system provides automated installation, building, and configuration of Lua and LuaRocks while enabling management of multiple isolated environments.

## Architecture Components

### 1. Bootstrap and Installation System
- **PowerShell Bootstrap**: `setup.ps1` script for initial setup and embedded Python management [To be improved for final deployment]
- **Embedded Python Environment**: Self-contained Python 3.13.5 for reliable execution across systems


### 2. F# CLI Application
- **Multi-Architecture Support**: Builds for x64, x86, and ARM64 platforms
- **Environment Management**: Installation creation, listing, removal, and configuration
- **pkg-config Integration**: MSVC-compatible compiler flag generation for C/C++ projects

### 3. Python Backend System
- **Download Management**: Version-aware downloading with registry and caching
- **Build Orchestration**: Complete Lua/LuaRocks compilation process with MSVC integration
- **Registry System**: UUID-based installation tracking in `%USERPROFILE%\.luaenv` with integrity verification

### 4. PowerShell Integration
- **Environment Activation**: Session-specific Lua environment setup
- **Visual Studio Integration**: Automatic MSVC toolchain detection and configuration
- **CLI Wrapper System**: Seamless command forwarding and environment handling

## Key Features

- **Multi-Version Support**: Manage multiple Lua and LuaRocks versions simultaneously
- **Build Configuration**: Static library and DLL builds with debug/release configurations
- **Environment Isolation**: Separate installations with UUID-based identification
- **MSVC Integration**: Automatic Visual Studio toolchain detection and setup
- **pkg-config-like Support**: Compiler flag generation for build systems


# Installation

## Prerequisites

- **Visual Studio 2019/2022** with C++ development tools (Community, Professional, or Enterprise)
- **PowerShell 7** (install via winget `winget install Microsoft.PowerShell`)
- **.NET SDK 8.0+** (for CLI building, optional - pre-built binaries are included for [amd64](./win64/), [arm64](./win-arm64/), and [x86](./win-x86/) architectures)
- **Internet connection** (for downloading Lua/LuaRocks sources and embedded Python)

## Installation Steps

### Overview of the Bootstrap Process

LuaEnv installation is orchestrated through two main scripts located in the repository root:

1. **setup.ps1**: Bootstrap script that downloads embedded Python 3.13.5 and orchestrates installation
2. **install.py**: Installation script that uses the embedded Python and backend registry system (used by `setup.ps1`)

### Step 1: Clone the Repository

```powershell
git clone https://github.com/jpdarela/LuaEnv.git
cd LuaEnv
```
Alternatively, download the repository as a [ZIP file](https://github.com/jpdarela/LuaEnv/archive/refs/heads/main.zip) and extract it to your desired location.

### Step 2: Run Bootstrap Installation

The installation process is very rudimentary and will be improved in the future. The `setup.ps1` script provides a simple way to bootstrap the system, including building the CLI and installing the Python environment. Currently only the cli binaries and some core scripts of the backend are installed to the `~/.luaenv/bin` directory. The Python backend and the embedded Python are not installed yet, they stay in the repository root directory. The installation process will be improved in the future to deploy the backend folder and the embedded Python to the `~/.luaenv` directory.

Note: Check the [execution policy of your PowerShell session](https://learn.microsoft.com/en-us/powershell/scripting/learn/ps101/01-getting-started?view=powershell-7.5#execution-policy). You may need to set it to allow script execution:


```powershell
# Run the bootstrap script to set up the environment
# After that you can add ~/.luaenv/bin to your PATH to use luaenv.
.\setup.ps1 -Bootstrap

# The script offer some useful options to control the installation process, facilitating development and testing.
# Build the CLI application and deploy it to ~/.luaenv/bin - Requires .NET SDK 8.0+
.\setup.ps1 -BuildCli -WarmUp

# Complete setup (deploys CLI, backend scripts, and configuration)
.\setup.ps1

# Complete reset (removes ~/.luaenv and re-installs everything from scratch). Removes all installed Lua environments.
.\setup.ps1 -Reset

.\setup.ps1 -Help  # Show help for the setup script
```

Add the ~/.luaenv/bin directory to your PATH for easier access to the CLI commands.

```powershell
# Add ~/.luaenv/bin to PATH for current session
$env:PATH += ";$HOME\.luaenv\bin"
# Verify PATH update
$env:PATH -split ';' | Where-Object { $_ -like "*luaenv*" }
```
Add to the $PROFILE for persistent PATH update:

```powershell
notepad $PROFILE  # Open PowerShell profile in Notepad
```
Add the following line to the profile script:

```powershell
# Add LuaEnv to PATH
$env:PATH += ";$HOME\.luaenv\bin"
```
Save and close the file. Restart PowerShell to apply changes.

You can also add the .luaenv directory to your PATH permanently by modifying the system environment variables:
1. Open the Start Menu and search for "Environment Variables".
2. Click on "Edit the system environment variables".
3. In the System Properties window, click on the "Environment Variables" button.
4. In the Environment Variables window, find the "Path" variable in the "System variables" section and select it.
5. Click on "Edit" and then "New" to add a new entry.
6. Enter the path to the LuaEnv bin directory: `%USERPROFILE%\.luaenv\bin`.
7. Click "OK" to close all dialog boxes.

# Usage

## Running the CLI

LuaEnv uses a PowerShell wrapper script system that provides integration between PowerShell and the F# CLI application.

## Wrapper Script Architecture

The CLI system uses a multi-layer architecture:

1. **luaenv.ps1**: PowerShell wrapper script installed to `~/.luaenv/bin/`
2. **LuaEnv.CLI.exe**: F# executable installed to `~/.luaenv/bin/cli/`
3. **backend.config**: JSON configuration file for backend integration

The wrapper automatically:
- Loads backend configuration from `~/.luaenv/bin/backend.config`
- Validates commands and forwards CLI commands to the F# executable
- Handles PowerShell-specific environment activation
- Provides consistent error handling and help

## Primary Interface: luaenv Command

After installation, use the `luaenv` command from the `~/.luaenv/bin` directory:

Note: Requires `~/.luaenv/bin` to be in your PATH.

```powershell
# Environment management
luaenv help  # Show help information
```
Output:

```plaintext
LuaEnv - Lua Environment Management Tool
=======================================
USAGE:
  luaenv <command> [options]

COMMANDS:

  Environment Management (CLI):
    install [options]                  Install a new Lua environment
    uninstall <alias|uuid>             Remove a Lua installation
    list                               List all installed Lua environments
    status                             Show system status and registry information
    versions                           Show installed and available versions
    default <alias|uuid>               Set the default Lua installation
    pkg-config <alias|uuid>            Show pkg-config information for C developers
    config                             Show current configuration
    set-alias <uuid> <alias>           Set or update the alias of an installation
    remove-alias <alias|uuid> [alias]  Remove an alias from an installation
    help                               Show CLI help message

  Shell Integration (PowerShell):
    activate [alias|options]      Activate a Lua environment in current shell
    local [<alias|uuid>|--unset]  Set/show/unset local version in current directory

For command-specific help:
  luaenv <command> --help

EXAMPLES:
  luaenv install --alias dev           # Install Lua with alias 'dev'
  luaenv activate dev                  # Activate 'dev' environment (shorthand)
  luaenv activate                      # Activate using .lua-version or default
  luaenv local dev                     # Set local version to 'dev' in current directory
  luaenv local                         # Display current local version
  luaenv local --unset                 # Remove local version
  luaenv default dev                   # Set 'dev' installation as global default
  luaenv list                          # Show all installations
  luaenv activate --list               # List available environments
  luaenv set-alias 1234abcd prod       # Set alias 'prod' for installation
                                         with UUID 1234abcd (matches first 8 chars)
  luaenv remove-alias dev              # Remove the 'dev' alias
  luaenv remove-alias 1234abcd prod    # Remove alias 'prod' from installation with UUID 1234abcd

Note: 'activate' is a PowerShell-only command that modifies your current shell.
      All other commands are handled by the LuaEnv CLI application.
```


```powershell
luaenv install --dll --lua-version 5.4.0 --luarocks-version 3.9.0   # Install Lua 5.4.0 with LuaRocks 3.9.0 as a DLL build
luaenv list                                                         # List all installations
luaenv install --alias dev                                          # Create new installation with alias
luaenv install --alias prod --x86                                   # Create 32-bit installation
luaenv install --dll --debug                                        # Create DLL build with debug symbols
luaenv uninstall dev                                                # Remove installation
luaenv status                                                       # Show system status
```
A separete executable ```luaconfig```, also installed to ~/.luaenv provides package configuration capabilites for C/C++ integration. See the `examples/build_systems/` directory for usage examples.

```powershell
## There are two separate commands for MSVC pkg-config support
luaconfig --help               # Get help on the pkg-config command
luaconfig dev --cflag          # Get MSVC compiler flags (prepeded with /I for include directories)
luaconfig dev --lua-include    # Get include directory
luaconfig dev --liblua         # Get library file path
```
System information commands provide additional details about the LuaEnv installation and configuration:

```powershell
# System information (commands have extra options and comprehensive help)
luaenv versions    # Show version information
luaenv config      # Show current configuration
luaenv help        # Show help information
```

## Environment Activation

```powershell
# Activate environment in current PowerShell session. THe MSVC toolchain is configured automatically based on the current Lua environment.
luaenv activate  --help              # Show help
luaenv activate  dev                 # Activate environment 'dev'. Shorthand for:
luaenv activate --alias dev          # Activate environment by alias

# Activate environment by UUID (matches the first 8 characters of the UUID in the registry)
luaenv activate --id a1b2c3d4

luaenv activate --list               # List available environments

# Visual Studio environment setup - Can be helpful for C/C++ development. Not used in luaenv activate
setenv.ps1 -Current                  # Configure MSVC toolchain in current session
setenv.ps1 -Help                     # Launch help for setenv.ps1
setenv.ps1 -Arch x86 -Current        # Configure for 32-bit builds
```

## What `luaenv activate` Does

1. **Visual Studio Setup**: Automatically configures MSVC toolchain (arm not supported yet)
   - Sets environment variables for compiler, linker, and tools
   - Configures include and library paths for Lua
2. **PATH Configuration**: Adds Lua and LuaRocks executables to PATH
3. **Module Paths**: Sets `LUA_PATH` and `LUA_CPATH` for module loading
4. **LuaRocks Config**: Configures LuaRocks for package compilation

## Available CLI Commands

- **install**: Install new Lua environment with version and build options
- **uninstall**: Remove existing installation by alias or UUID
- **list**: Display all installed environments with details
- **status**: Show system status and registry information
- **versions**: Display available and installed versions
- **pkg-config**: Generate MSVC-compatible compiler flags for C/C++ projects
- **config**: Show current backend configuration
- **activate**: PowerShell-only command for environment activation/inspection
- **set-alias**: Set or update an alias for an installation
- **help**: Display help information for commands

# Environment Isolation

LuaEnv provides complete environment isolation through a UUID-based registry system and separate installation directories.

## Installation Separation
- **Unique UUIDs**: Each installation has a unique identifier stored in the registry
- **Separate Directories**: `~/.luaenv/installations/{uuid}/` for each environment
- **Independent Configurations**: Separate build configurations and package trees
- **Version Independence**: Different Lua/LuaRocks versions per environment

## Package Isolation
- **Dedicated LuaRocks Trees**: Each environment has its own package tree in the installation directory (Can be overridden with luaenv activate --tree)
- **Module Path Isolation**: `LUA_PATH` and `LUA_CPATH` are environment-specific during activation
- **No Cross-Contamination**: Packages installed in one environment don't affect others

# Available Versions od Lua and LuaRocks
- **Build Settings**: Static vs DLL, Debug vs Release configurations per environment

# Project Structure

## Repository Structure

Outdated.

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
├── tests/                     # Repository-level tests # Incipient tests, only for download currently
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
├── registry.json             # Installation registry with UUID tracking
├── bin/                      # Global scripts and CLI binaries
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

# Tests

Not completed yet.

# Architecture Guidelines

- **Backend Scripts**: Designed to run from `backend/` directory with relative imports
- **Dual-Context Design**: Support both CLI execution and module import patterns
- **No Backwards Compatibility**: Rapid iteration without breaking change concerns
- **Configuration-Driven**: Use `build_config.txt` as single source of truth
- **Error Recovery**: Include comprehensive error handling and cleanup

# Contributing
Contributions are welcome!


# Use of LLMs via GitHub Copilot
This project uses GitHub Copilot for code suggestions and improvements. The code is generated based on the context provided by the user and is not directly copied from any source. The use of Copilot is intended to enhance productivity and code quality, but the final implementation is reviewed and modified by the project maintainers to ensure correctness and adherence to project standards.

## Notes on the backend system

This project started as a simple set of scripts to download and build Lua and LuaRocks on Windows using the MSVC toolchain. Over time, it evolved into a more complex system with a Python backend that manages downloads, builds, and configurations. The backend is designed to be modular and extensible, allowing for easy addition of new features and improvements.

The backend system can be used independently of the CLI, allowing for flexible integration with other tools and workflows. It provides a robust foundation for managing Lua environments on Windows, with a focus on reliability, performance, and ease of use. Check the `backend/` directory for (outdated) documentation on the backend components and their usage.
