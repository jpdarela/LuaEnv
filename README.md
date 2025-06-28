# Lua MSVC 2022 Build Scripts

A set of build scripts for compiling Lua 5.4.8 and configuring LuaRocks 3.12.2 on Windows using Microsoft Visual Studio C++ (MSVC) 2022.
I decided to learn Lua and am currently using Windows 11 with Visual Studio 2022. The options for building Lua on Windows are somewhat limited, so I created this set of scripts to automate the process of downloading, building, and configuring Lua (with LuaRocks) for my use. This project can be adapted for future Lua releases and can be used as a reference for building Lua on Windows with MSVC. Feel free to adapt, use, and contribute to this project!

## 🚀 Quick Start

### Prerequisites

- **Visual Studio 2022** with C++ build tools installed (Community, Professional, or Enterprise)
- **Python 3.x** for automation scripts
- **Internet connection** for downloading Lua and LuaRocks

## 🛠️ Environment Setup

### Visual Studio Developer Command Prompt
**Critical:** All build commands must be run from a **Visual Studio Developer Command Prompt** or **Developer PowerShell**.

### Download the scripts

Download the [zip file](https://github.com/jpdarela/lua_msvc_build/archive/refs/heads/main.zip) and unzip it.

Or clone it using git:

```Powershell
# Clone the repository
git clone https://github.com/jpdarela/lua_msvc_build.git
```

```Powershell
# Change to the project directory
cd lua_msvc_build
```

### Environment Setup:

```powershell
# Set the environment. Adjust path to your Visual Studio installation
&"C:\Program Files\Microsoft Visual Studio\2022\Community\Common7\Tools\Launch-VsDevShell.ps1" -Arch "amd64" -SkipAutomaticLocation
```

Then proceed with the setup command. This will build lua and install it to the directory (C:\lua_msvc_build\lua).

For a static build:

```powershell
python setup.py
```

For a DLL build:

```powershell
python setup.py --dll
```

Alternatively, you can set a custom installation directory. For instance, I install my stuff in a folder called opt in my home directory. This folder is already in my PATH, so I can just run and then everthing will be installed there (and the [use-lua.ps1](#environment-setup-script-use-luaps1) script will be already on my PATH):

```powershell
python setup.py  --dll --prefix C:\Users\darel\opt\lua
```

This single command will:
1. **Download** Lua 5.4.8 and LuaRocks 3.12.2 automatically
2. **Extract** archives and organize project structure
3. **Check** environment for Visual Studio and required tools
4. **Setup** build environment (copies scripts to appropriate directories)
5. **Compile** Lua with MSVC (static or DLL)
6. **Install** Lua to specified directory with proper structure
7. **Configure** LuaRocks to work with your Lua build
8. **Copy** `use-lua.ps1` environment setup script to the installation directory if you set `--prefix` option

Note: Using `setup.py` is the recommended approach as it automates the entire process from downloading Lua and LuaRocks to configuring your environment.


## 📁 Project Structure

```
lua_msvc_build/
├── README.md                    # This file
├── setup.py                     # Master setup script (recommended)
├── download_lua_luarocks.py     # Downloads and extracts Lua/LuaRocks
├── setup_build.py               # Prepares build environment
├── build.py                     # Main automated build script
├── build-static.bat             # Static Lua library build script with auto-install
├── build-dll.bat                # Dynamic Lua library (DLL) build script
├── install_lua_dll.py           # DLL build installer
├── setup-luarocks.bat           # LuaRocks configuration script
├── use-lua.ps1                  # PowerShell environment setup script
├── check-env.bat                # Environment verification utility
├── downloads/                   # Downloaded archives (created automatically)
├── lua-5.4.8/                   # Extracted Lua source (auto-extracted)
├── luarocks-3.12.2-windows-64/  # Extracted LuaRocks (auto-extracted)
└── [installation directories]   # Your Lua installations (e.g., ./lua)
```

### After Installation
Your Lua installation will have this structure:
```
project-root/        # Your build directory
├── use-lua.ps1      # PowerShell environment setup script
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
- Lua: 5.4.8 (Release build)
- LuaRocks: 3.12.2 (Downloaded binaries)
- VS: Visual Studio 2022 (Community, Professional, or Enterprise)
---
