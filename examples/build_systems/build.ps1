#!/usr/bin/env pwsh
# This script demonstrates compiling a C application using Lua, with compiler
# and linker flags provided by `luaenv pkg-config`. It's designed for use
# with MSVC (cl.exe) in a PowerShell environment.

# --- How it works ---
# 1. It captures the output of `luaenv pkg-config` for compiler flags (`--cflag`)
#    and the Lua library path (`--liblua`).
# 2. It constructs a `cl.exe` command line using these variables.
# 3. It invokes the command to compile `main.c` into `main_ps.exe`.
# 4. It checks the exit code of the compiler to determine success or failure.

Write-Host "[build.ps1] Starting PowerShell build..."

# Ensure we're using the Windows path style for cl.exe
$cflags = luaenv pkg-config dev --cflag --path-style windows
$lua_lib = luaenv pkg-config dev --liblua --path-style windows

if ($LASTEXITCODE -ne 0) {
    Write-Host "[build.ps1] ERROR: Failed to get pkg-config data from luaenv." -ForegroundColor Red
    exit 1
}

Write-Host "[build.ps1] CFLAGS: $cflags"
Write-Host "[build.ps1] LUA_LIB: $lua_lib"

# Clean previous build artifact
if (Test-Path "main_ps.exe") { Remove-Item "main_ps.exe" }
if (Test-Path "main_ps.obj") { Remove-Item "main_ps.obj" }


# Compile the application
# - /Fe: specifies the output executable name.
# - main.c is the source file.
# - $cflags provides the include path for lua.h.
# - $lua_lib provides the path to lua54.lib.
# - /TC specifies to treat the source file as C code.
# - /W4 sets a high warning level.
# - /link is used to specify the linker options.
$command = "cl.exe /Fe:main_ps.exe main.c $cflags /TC /W4 /link `"$lua_lib`""
Write-Host "[build.ps1] Executing: $command"

Invoke-Expression $command

if ($LASTEXITCODE -eq 0) {
    Write-Host "[build.ps1] Build successful!" -ForegroundColor Green
    exit 0
} else {
    Write-Host "[build.ps1] ERROR: Build failed with exit code $LASTEXITCODE." -ForegroundColor Red
    exit 1
}
