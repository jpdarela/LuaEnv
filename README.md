# Lua MSVC 2022 Build

Work in progress! Keep an eye on this project for updates.

A set of build scripts for compiling Lua and configuring LuaRocks on Windows using Microsoft Visual Studio C++ (MSVC) 2022 (x86 and amd64).

I decided to learn Lua and am currently using Windows 11 with Visual Studio 2022. The options for building Lua on Windows are somewhat limited, so I created this set of scripts to automate the process of downloading, building, and configuring Lua (with LuaRocks) for my use. This project can be adapted for future Lua releases and can be used as a reference for building Lua on Windows with MSVC. Feel free to adapt, use, and contribute to this project!

### 📦 Available Versions

**Lua 5.4.x versions:**
- 5.4.8, 5.4.7, 5.4.6, 5.4.5, 5.4.4, 5.4.3, 5.4.2, 5.4.1, 5.4.0

**LuaRocks versions (≥3.9.1):**
- 3.12.2, 3.12.1, 3.12.0, 3.11.1, 3.11.0, 3.10.0, 3.9.2, 3.9.1

**Platforms for luarocks:**
- `windows-64`
- `windows-32`

See `build_config.txt` for configuration options.

## 🚀 Quick Start

### Prerequisites

- **Visual Studio** (Tested with 2022 Community edition) with C++ build tools installed (Community, Professional, or Enterprise)
- **Python 3.x** for automation scripts
- **Internet connection** for downloading Lua and LuaRocks

## 📝 Configuration

The system uses `build_config.txt` to manage versions. Edit this file to use different versions:

```ini
# Lua Configuration
LUA_VERSION=5.4.8
LUA_MAJOR_MINOR=5.4

# LuaRocks Configuration
LUAROCKS_VERSION=3.12.2
LUAROCKS_PLATFORM=windows-64
```

**Examples:**
- For Lua 5.4.7 with LuaRocks 3.11.1: Change `LUA_VERSION=5.4.7` and `LUAROCKS_VERSION=3.11.1`
- For Lua 5.3.6 with LuaRocks 3.10.0: Change `LUA_VERSION=5.3.6` and `LUAROCKS_VERSION=3.10.0`

Use `python config.py --discover` to see available versions, or `python config.py --check` to validate your configuration.

## 🛠️ Environment Setup

### Visual Studio Developer Command Prompt
**Critical:** All build commands must be run from a **Visual Studio Developer Command Prompt** or **Developer PowerShell**.

**Automatic Search of DEveloment tools:** The scripts will automatically search for the Visual Studio Developer Shell and set up the environment. If it cannot find it, you can manually run the `setenv.ps1` script to set up the environment. See the [setenv.ps1](setenv.ps1) script for details. Use the -Path option to specify the path to your Visual Studio installation if needed.

### Download the Scripts

Download the [zip file](https://github.com/jpdarela/lua_msvc_build/archive/refs/heads/main.zip) and unzip it.

Or clone it using git:

```Powershell
# Clone the repository
git clone https://github.com/jpdarela/lua_msvc_build.git
# Change to the project directory
cd lua_msvc_build
```

### Environment Setup:

If you have Visual Studio installed in in the default location, then the scripts will automatically find it. If you have installed Visual Studio in a custom location, you can run the `setenv.ps1` script with the `-Path` option to specify the path to your Visual Studio installation:

```powershell
./setenv.ps1 -Path "C:\CustomPath\to\VS\2022\Community" -DryRun

# After that, re run the setenv.ps1 script without the -DryRun option to set up the environment variables.
./setenv.ps1 -Arch "amd64" # or "x86" for 32-bit builds
```
Swich -Arch to the appropriate architecture if needed (e.g., `-Arch "x86"` for 32-bit builds).

Run the -Help option to see all available options:

```powershell
./setenv.ps1 -Help
```

## 🔨 Build Process

The download and build process is simple. You can use the all-in-one `setup_lua.py` command or run individual steps.

### Option 1: All-in-One Build (Recommended)

For a static build:
```powershell
python setup_lua.py
```

For a DLL build:
```powershell
python setup_lua.py --dll
```

With custom installation directory:
```powershell
python setup_lua.py --dll --prefix C:\Users\Corisco\opt\lua
```

Debug build (DLL or static[default]):
```powershell
python setup_lua.py --debug (--dll)
```

### Version Management

```powershell
# Check current configuration and validate URLs
python config.py --check

# Discover available versions (with caching)
python config.py --discover

# Force refresh version cache
python config.py --discover --refresh

# View cache information
python config.py --cache-info

# Clear version cache
python config.py --clear-cache
```

## 🧹 Cleanup

The system includes a cleanup script that respects your configuration and protects installations:

```powershell

# Print help and usage information
python clean.py --help

# Standard cleanup (removes downloads, extracted sources, cache)
python clean.py

# Clean everything including installation files if they were installed in the project directory
# (use with caution, as it will remove all Lua-related directories)
python clean.py --all

# Clean only specific items
python clean.py --downloads-only
python clean.py --cache-only
```

Note: To uninstall Lua (that was installed by these scripts) use the setup script with the `--uninstall` option, which will remove the Lua installation directory. This removes only the Lua and LuaRocks directories. Other files related to LuaRocks or Lua modules will not be removed, so you may need to clean them up manually if necessary. The setup_lua.py script with the --uninstall flag will output some about the files that will not be removed so you can delete them manually if needed.

```powershell
# Uninstall Lua and LuaRocks
python setup_lua.py --uninstall
```

## 🧪 Testing


## Lua build automated test

We use the tests provided by the lua team to test the lua build. The tests are run automatically after the build is completed. In general it fails with builds for x86 and with debug builds, but it is a good way to test the build process and the Lua installation.

The project includes test suite (incomplete) for internal fucntionality with an test runner (Not related to the lua distribution):

```powershell
# Run all tests (default)
python run_tests.py

# Run specific test categories
python run_tests.py --config        # All config tests
python run_tests.py --config-basic  # Basic config tests only
python run_tests.py --config-cache  # Config cache tests only
python run_tests.py --config-cli    # Config CLI tests only
python run_tests.py --download      # Download functionality tests
python run_tests.py --setup-build   # Build setup tests

# Get help with all options
python run_tests.py --help
```

**Test Categories:**
- **Config tests**: Configuration system validation and version discovery
- **Download tests**: File download, extraction, and bootstrap functionality
- **Setup build tests**: Build script setup and all build combinations (static/DLL, release/debug)
- **Bootstrap integration**: Automatic dependency management between test categories


## 📁 Project Structure

```
lua_msvc_build/
├── README.md                      # This file
├── build_config.txt               # 🔧 User configuration file (EDIT THIS)
├── config.py                      # Configuration system and URL validation
├── setup_lua.py                       # Master setup script (all-in-one)
├── download_lua_luarocks.py       # Downloads and extracts Lua/LuaRocks
├── setup_build.py                 # Prepares build environment
├── build.py                       # Main build script
├── clean.py                       # Smart cleanup script
├── run_tests.py                   # Test runner with individual test options
├── build_scripts/                 # Build scripts directory (organized)
│   ├── build-static.bat           # Static Lua library build script
│   ├── build-static-debug.bat     # Static Lua library build (with debug info) script
│   ├── build-dll.bat              # Dynamic Lua library (DLL) build script
│   ├── build-dll-debug.bat        # Dynamic Lua library (DLL) build (with debug info) script
│   ├── install_lua_dll.py         # DLL build installer
│   └── setup-luarocks.bat         # LuaRocks configuration script
├── tests/                         # Test suite directory
│   ├── test_config_basic.py       # Basic configuration tests
│   ├── test_config_cache.py       # Configuration cache tests
│   ├── test_config_cli.py         # Configuration CLI tests
│   ├── test_download.py           # Download functionality tests
│   └── test_setup_build.py        # Build setup tests
├── use-lua.ps1                    # PowerShell environment LUA/MSVC setup script
├── setenv.ps1                     # PowerShell script to set up MSVC environment variables
├── check-env.bat                  # Environment verification utility
├── version_cache.json             # Version discovery cache (auto-generated)
├── downloads/                     # Downloaded archives (auto-created)
├── lua-{VERSION}/                 # Extracted Lua source (auto-extracted)
├── luarocks-{VERSION}-{PLATFORM}/ # Extracted LuaRocks (auto-extracted)
└── [installation directories]     # Your Lua installations (e.g., ./lua)
```

**NOTES:**
- **`build_config.txt`**: The main configuration file - edit this to change versions
- **`version_cache.json`**: Automatically managed cache file - don't edit manually
- **`build_scripts/`**: Organized directory containing all build scripts and installers
- **`tests/`**: Comprehensive test suite with individual test categories
- **`run_tests.py`**: Enhanced test runner with options for individual test categories
- **`use-lua.ps1`**: PowerShell script to set up the environment for Lua and LuaRocks
- **`debug builds`**: The debug build scripts are in `build_scripts/` directory and are automatically copied when needed

### After Installation
Your Lua installation will have this structure:

```
├── .lua_prefix.txt  # Installation path reference (auto-generated)
├── your-install-dir/# Example: ./lua
│   ├── bin/         # Executables (lua.exe, luac.exe, lua54.dll if DLL build)
│   ├── include/     # Header files for C/C++ development
│   ├── lib/         # Libraries (lua54.lib for both static and DLL builds)
│   ├── doc/         # Documentation files
│   └── luarocks/    # LuaRocks installation (if configured)
│       ├── luarocks.exe
│       └── ...
└── ...              # Other build files and directories
```

## 🔧 Build Options

### Static Build (Default)
Creates a statically linked Lua interpreter and compiler:
- **Library:** `lua54.lib` (static library)
- **Executables:** `lua.exe`, `luac.exe` (standalone, no DLL dependencies)
- **Advantages:** Self-contained, no runtime dependencies, easier distribution
- **Use case:** Standalone applications, embedded Lua, simple deployment

### Dynamic Build (DLL)
Creates a dynamically linked Lua with shared library:
- **Library:** `lua54.dll` (dynamic library) + `lua54.lib` (import library)
- **Executables:** `lua.exe` (requires DLL), `luac.exe` (static)
- **Advantages:** Smaller executables, shared library across multiple apps
- **Use case:** Plugin systems, multiple applications sharing Lua

### Build Configuration Details
Both builds use optimized MSVC compiler settings:
- **Optimization:** `/O2` (maximize speed)
- **Runtime:** `/MT` (static) or `/MD` (DLL)
- **Compatibility:** `LUA_COMPAT_5_3` enabled
- **Architecture:** amd64 on Visual Studio 2022

### Build Output Details

#### Static Build Output
The static build (`build-static.bat`) creates:
```
Release/
├── lua.exe          # Lua interpreter (standalone)
├── luac.exe         # Lua compiler (standalone)
├── lua54.lib        # Static library for linking
└── *.obj            # Object files (intermediate)
```

#### DLL Build Output
The DLL build (`build-dll.bat`) creates:
```
Release/
├── lua.exe          # Lua interpreter (requires lua54.dll)
├── luac.exe         # Lua compiler (standalone, statically linked)
├── lua54.dll        # Dynamic library
├── lua54.lib        # Import library for linking
├── lua54.exp        # Export file
└── *.obj            # Object files (separate sets for DLL and static)
```

### Environment Setup Script (use-lua.ps1)

The `use-lua.ps1` script provides a convenient way to configure your current PowerShell session to use any Lua installation, not just those built with this project. This script can work with official Lua distributions, pre-compiled binaries, or any custom Lua installation, and can be used to set up the environment without modifying system-wide PATH settings.

#### Quick Usage

Note: If the prefix directory is on your PATH as it is for me, you can run the script directly without specifying path to the use-lua.ps1 script. (e.g. `.\`)

```powershell
# Basic usage - automatically detects Lua installation from .lua_prefix.txt
.\use-lua.ps1

# Use with custom Lua installation paths
.\use-lua.ps1 -Lua "C:\CustomLua" -Luarocks "C:\CustomLuaRocks"

# Customize where packages are installed
.\use-lua.ps1 -Tree "C:\MyProject\lua_modules"

# Get comprehensive help with all options
.\use-lua.ps1 -Help

# Now you can use lua and luarocks commands directly
lua -v
luarocks --version
```

#### Environment Variables Set by `use-lua.ps1`
- **`PATH`**: Updated with custom or detected Lua and LuaRocks directories
- **`LUA_PATH`**: Configured for `.lua` module discovery from custom package locations
- **`LUA_CPATH`**: Configured for `.dll` (compiled) module discovery from custom trees
- **`LUAROCKS_CONFIG`**: Points to dynamically generated configuration file with custom paths
- **Visual Studio variables**: Set by the Developer Shell initialization (for native module compilation)


#### Troubleshooting
- **"Visual Studio Developer Shell not found"**: Install Visual Studio with C++ build tools (needed for native module compilation)
- **"Lua installation not found"**: Verify the Lua path contains a `bin` directory with `lua.exe`
- **"LuaRocks installation not found"**: Ensure LuaRocks path contains `luarocks.exe`
- **"Execution Policy"**: Run `Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser` if script execution is blocked
- **Package installation issues**: Ensure the custom tree directory is writable and the path is correctly specified

### After Installation
Your Lua installation will be ready to use. Here's a quick reference:

#### Running Lua
```bash
# If installation directory is in PATH
lua --version
lua script.lua
lua -i                                        # Interactive mode

# Direct path usage
C:\MyLua\bin\lua.exe script.lua
```

#### Compiling Lua Scripts
```bash
luac -o script.luac script.lua               # Compile to bytecode
luac -l script.lua                           # List bytecode
```

#### Installing Packages with LuaRocks
```bash
# Popular packages
luarocks install luasocket                   # Network programming
luarocks install lpeg                        # Parsing expression grammars
luarocks install lua-cjson                   # JSON handling
luarocks install lfs                         # File system access

# Package management
luarocks list                                # List installed packages
luarocks search json                         # Search for packages
luarocks show luasocket                      # Package information

# Custom installation locations
luarocks install --tree="./project_rocks" packagename
```

### C/C++ Development Integration
```c
// Include Lua headers
#include "lua.h"
#include "lauxlib.h"
#include "lualib.h"
// ... your code here ...

// Link against:
// - Static build: lua54.lib
// - DLL build: lua54.lib (requires lua54.dll at runtime)
```

## 🧪 Testing Your Lua Build

#### Check Lua Installation
```bash
# Add the Lua installation directory to PATH so you can run the use-lua.ps1 script
set PATH=%PATH%;C:\path\to\your\prefix\set

# load lua and luarocks in your environment
use-lua.ps1

# Verify Lua works
lua -e "print(_VERSION)"

# Check library linking (for DLL builds)
lua -e "print(package.cpath)"
```

#### Verify LuaRocks Configuration
```bash
luarocks config                              # Show all configuration
luarocks config variables.LUA                # Check Lua path
luarocks list                                # List system packages
luarocks search lua-cjson                    # Search for packages
luarocks show luasocket                      # Show package details
luarocks config variables.ROCKS_TREE         # Check package installation tree
```

**We welcome contributions!** Feel free to submit issues, improvements, or adaptations for newer versions of lua and luarocks.

## 📄 License

This build system is provided as-is for educational and development purposes.
Lua and LuaRocks are distributed under their respective licenses.

---

**Current supported Versions:**
- Lua: 5.4.X (Release build)
- LuaRocks: >= 3.9.1 (Downloaded binaries)
- VS: Visual Studio 2022 (Community, Professional, or Enterprise)
---
