# LuaEnv pkg-config Integration Test Suite

This directory contains a comprehensive test suite for demonstrating `luaenv pkg-config` integration with various Windows build systems.

## Files

- **main.c** - Simple C program that uses Lua APIs
- **Makefile** - GNU Makefile with MSVC/luaenv pkg-config integration (cross-platform)
- **Makefile_win** - Windows nmake makefile with pkg-config integration
- **CMakeLists.txt** - CMake configuration with pkg-config integration
- **meson.build** - Meson build configuration with pkg-config integration
- **build.bat** - Batch script demonstrating pkg-config integration
- **build.ps1** - PowerShell script demonstrating pkg-config integration
- **build_all.ps1** - Comprehensive test script for all build methods

## Usage

### Quick Test
```powershell
# Run comprehensive test of all build systems
.\build_all.ps1
```

### Individual Build Methods

#### 1. Direct cl.exe compilation
```cmd
cl.exe /Fe:main.exe main.c $(luaenv pkg-config dev --cflag) $(luaenv pkg-config dev --liblua)
```

#### 2. PowerShell variables
```powershell
# Use splatting for cleaner command execution
$cl_args = @(
    "/Fe:main.exe",
    "main.c",
    (luaenv pkg-config dev --cflag),
    (luaenv pkg-config dev --liblua)
)
cl.exe @cl_args
```

#### 3. Batch file environment variables
```cmd
@echo off
for /f "delims=" %%i in ('luaenv pkg-config dev --cflag') do set CFLAGS=%%i
for /f "delims=" %%i in ('luaenv pkg-config dev --liblua') do set LUA_LIB=%%i
cl.exe /Fe:main.exe main.c %CFLAGS% %LUA_LIB%
```

#### 4. Batch script build
```cmd
build.bat
```

#### 5. PowerShell script build
```powershell
.\build.ps1
```

#### 6. GNU Makefile (cross-platform)
```cmd
make all
make config    # Show build configuration
make test      # Build and test both versions
```

#### 7. nmake integration
```cmd
nmake -f Makefile_win
```

#### 8. CMake integration
```cmd
mkdir build
cd build
cmake .. -G "Visual Studio 17 2022"
cmake --build . --config Release
```

#### 9. Meson integration
```cmd
meson setup builddir
meson compile -C builddir
```

## `--path-style` for Build System Compatibility

Different build systems on Windows have different expectations for how file paths should be formatted. The `--path-style` option ensures that `luaenv pkg-config` can provide paths in the correct format for your chosen tool.

- `--path-style windows` (Default on Windows): Outputs paths with backslashes (e.g., `C:\path\to\lib`). Ideal for `nmake`, `cl.exe`, MSBuild, and Meson on Windows.
- `--path-style unix`: Outputs paths with forward slashes (e.g., `/c/path/to/lib`). Necessary for `make` with MinGW/MSYS2, or other Unix-like environments on Windows.
- `--path-style native`: Uses the operating system's default separator.

## Expected Output

All methods should successfully compile and produce an executable that outputs:
```
Hello from Lua!
x from Lua: 42
```

## Integration Patterns Demonstrated

### Batch Scripts (.bat)
- Uses `for /f` loop for command output capture
- Environment variable assignment for reuse
- Traditional Windows batch file approach with error handling

### PowerShell Scripts (.ps1)
- Direct command substitution for interactive use
- Variable assignment for script automation
- Advanced error handling and colored output

### GNU Makefile (Cross-platform)
- Uses `$(shell ...)` function for command substitution at make time
- Conditional compilation for Windows vs Unix
- Works with GNU Make in MSYS2, Git Bash, GitHub Actions

### nmake (Windows Make)
- Uses temporary files to capture pkg-config output
- Demonstrates `!IF` and `!INCLUDE` directives for dynamic path resolution

### CMake
- Uses `execute_process()` to run pkg-config at configure time
- Captures output into CMake variables for use in target configuration

### Meson
- Uses `run_command()` to execute pkg-config during build setup
- Creates dependency objects with dynamic paths

### PowerShell
- Direct command substitution for interactive use
- Variable assignment for script automation

### Batch Files
- `for /f` loop for command output capture
- Environment variable assignment for reuse

## Prerequisites

- LuaEnv with at least one Lua installation (alias: `dev`)
- Visual Studio Build Tools or Visual Studio with MSVC compiler
- Optional: CMake, Meson for testing those build systems

## Notes

- All examples target Windows/MSVC toolchain
- Demonstrates proper handling of paths with spaces
- Shows both static library and DLL build compatibility
- Includes proper error handling and fallback methods
