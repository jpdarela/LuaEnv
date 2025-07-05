#!/usr/bin/env pwsh
# This script demonstrates compiling a C application using Lua, with compiler
# and linker flags provided by `luaconfig`. It's designed for use
# with MSVC (cl.exe) in a PowerShell environment.

# If using a dll build, ensure that the dll is in the same directory as the executable or in the system PATH.
# You can use luaenv activate --alias dev to set up the environment for development.
# This will set the bin path of the lua installation to the PATH variable, enabling the findin of the lua.dll
# This script assumes that you have an installation of lua made with luaenv with the dev alias.
# If using a DLL build, ensure that the DLL is in the same directory as the executable or in the system PATH.


Write-Host "[build.ps1] Starting PowerShell build..."

# Ensure we're using the Windows path style for cl.exe
$cflags = luaconfig dev --cflag --path-style windows
$lua_lib = luaconfig dev --liblua --path-style windows

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
