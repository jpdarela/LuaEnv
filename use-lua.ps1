#!/usr/bin/env pwsh

# use-lua.ps1 - Setup Lua environment in the current shell
# This script can be called from anywhere (if you add the containing folder to PATH)
# and will configure the current shell  to use Lua and LuaRocks from the opt directory
#
# Parameters:
#   -Tree <path>      Optional. Custom path for user LuaRocks tree.
#                     Default: $env:USERPROFILE\AppData\Roaming\luarocks
#   -Lua <path>       Optional. Custom path to Lua installation directory.
#                     Default: ./lua (overrides .prefix.txt file)
#   -Luarocks <path>  Optional. Custom path to LuaRocks installation directory.
#                     Default: ./lua/luarocks

# TODO add suport for other lua and luarocks options


param(
    [string]$Tree = "",
    [string]$Lua = "",
    [string]$Luarocks = "",
    [switch]$Help
)

# Display help information if requested
if ($Help) {
    Write-Host "use-lua.ps1 - Lua Environment Setup Script" -ForegroundColor Green
    Write-Host "=============================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "DESCRIPTION:" -ForegroundColor Yellow
    Write-Host "  Sets up the current PowerShell session to use Lua and LuaRocks from this installation."
    Write-Host "  Automatically configures Visual Studio Developer Shell, PATH, and Lua module paths."
    Write-Host ""
    Write-Host "SYNTAX:" -ForegroundColor Yellow
    Write-Host "  .\use-lua.ps1 [[-Tree] <string>] [[-Lua] <string>] [[-Luarocks] <string>] [-Help]"
    Write-Host ""
    Write-Host "PARAMETERS:" -ForegroundColor Yellow
    Write-Host "  -Tree <path>      Optional. Custom path for user LuaRocks package tree."
    Write-Host "                    Default: `$env:USERPROFILE\AppData\Roaming\luarocks"
    Write-Host ""
    Write-Host "  -Lua <path>       Optional. Custom path to Lua installation directory."
    Write-Host "                    Default: ./lua (overrides .prefix.txt file)"
    Write-Host ""
    Write-Host "  -Luarocks <path>  Optional. Custom path to LuaRocks installation directory."
    Write-Host "                    Default: ./lua/luarocks"
    Write-Host ""
    Write-Host "  -Help             Display this help information."
    Write-Host ""
    Write-Host "EXAMPLES:" -ForegroundColor Yellow
    Write-Host "  Basic usage (from Lua installation directory):"
    Write-Host "  .\use-lua.ps1" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  Use custom LuaRocks package tree:"
    Write-Host "  .\use-lua.ps1 -Tree 'C:\MyProject\lua_modules'" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  Use custom Lua installation path:"
    Write-Host "  .\use-lua.ps1 -Lua 'C:\CustomLua'" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  Use custom Lua and LuaRocks paths:"
    Write-Host "  .\use-lua.ps1 -Lua 'C:\CustomLua' -Luarocks 'C:\CustomLuaRocks'" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  Run from any location (if added to PATH):"
    Write-Host "  use-lua.ps1" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  Run with full path:"
    Write-Host "  C:\MyLua\use-lua.ps1 -Tree 'D:\ProjectRocks'" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "WHAT THIS SCRIPT DOES:" -ForegroundColor Yellow
    Write-Host "  1. Finds and initializes Visual Studio Developer Shell (for native module compilation)"
    Write-Host "  2. Adds Lua and LuaRocks executables to PATH for current session"
    Write-Host "  3. Configures LUA_PATH and LUA_CPATH for proper module loading"
    Write-Host "  4. Sets up LuaRocks configuration for compilation"
    Write-Host "  5. Creates necessary directories for LuaRocks packages"
    Write-Host ""
    Write-Host "AFTER RUNNING:" -ForegroundColor Yellow
    Write-Host "  You can use these commands in the current session:"
    Write-Host "  ? lua -v                    # Check Lua version"
    Write-Host "  ? lua script.lua            # Run Lua scripts"
    Write-Host "  ? lua -i                    # Interactive Lua REPL"
    Write-Host "  ? luarocks install <pkg>    # Install packages"
    Write-Host "  ? luarocks list             # List installed packages"
    Write-Host ""
    Write-Host "TROUBLESHOOTING:" -ForegroundColor Red
    Write-Host "  ? If you see 'Visual Studio Developer Shell not found':"
    Write-Host "    Install Visual Studio with C++ build tools"
    Write-Host ""
    Write-Host "  ? If you see 'Lua installation not found':"
    Write-Host "    Make sure you're running from the correct Lua installation directory"
    Write-Host ""
    Write-Host "  ? If script execution is blocked:"
    Write-Host "    Run: Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser"
    Write-Host ""
    Write-Host ""
    Write-Host "ENVIRONMENT VARIABLES SET:" -ForegroundColor Yellow
    Write-Host "  PATH, LUA_PATH, LUA_CPATH, LUAROCKS_CONFIG"
    Write-Host ""
    Write-Host "NOTE: All changes are session-specific and don't affect system-wide settings." -ForegroundColor Red
    Write-Host ""
    return
}

# Try to find and launch Visual Studio Developer Shell
$VsDevShellFound = $false

# First, try using vswhere to find VS installations (most reliable method)
$VsWherePath = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
if (Test-Path $VsWherePath) {
    try {
        $VsInstallations = & $VsWherePath -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath -format value
        if ($VsInstallations) {
            $VsDevShellPath = Join-Path $VsInstallations "Common7\Tools\Launch-VsDevShell.ps1"
            if (Test-Path $VsDevShellPath) {
                Write-Host "Found Visual Studio Developer Shell via vswhere: $VsDevShellPath" -ForegroundColor Gray
                & $VsDevShellPath -Arch "amd64" -SkipAutomaticLocation

                $VsDevShellFound = $true
            }
        }
    }
    catch {
        Write-Warning "Failed to use vswhere: $($_.Exception.Message)"
    }
}

# Fallback to common installation paths if vswhere didn't work
if (-not $VsDevShellFound) {
    $VsDevShellPaths = @(
        "${env:ProgramFiles}\Microsoft Visual Studio\2022\Enterprise\Common7\Tools\Launch-VsDevShell.ps1",
        "${env:ProgramFiles}\Microsoft Visual Studio\2022\Professional\Common7\Tools\Launch-VsDevShell.ps1",
        "${env:ProgramFiles}\Microsoft Visual Studio\2022\Community\Common7\Tools\Launch-VsDevShell.ps1",
        "${env:ProgramFiles}\Microsoft Visual Studio\2019\Enterprise\Common7\Tools\Launch-VsDevShell.ps1",
        "${env:ProgramFiles}\Microsoft Visual Studio\2019\Professional\Common7\Tools\Launch-VsDevShell.ps1",
        "${env:ProgramFiles}\Microsoft Visual Studio\2019\Community\Common7\Tools\Launch-VsDevShell.ps1"
    )

    foreach ($VsDevShellPath in $VsDevShellPaths) {
        if (Test-Path $VsDevShellPath) {
            Write-Host "Found Visual Studio Developer Shell at: $VsDevShellPath" -ForegroundColor Gray
            & $VsDevShellPath -Arch "amd64" -SkipAutomaticLocation

            $VsDevShellFound = $true
            break
        }
    }
}

if (-not $VsDevShellFound) {
    Write-Warning "Visual Studio Developer Shell not found. Compilation of native modules may fail."
    Write-Warning "Please ensure Visual Studio with C++ tools is installed."
}

# ============================================================


# Get the directory where this script is located
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition

# Set default paths for Lua and LuaRocks
$DefaultLuaBinPath = Join-Path $ScriptDir "lua\bin"
$DefaultLuaRocksPath = Join-Path $ScriptDir "lua\luarocks"

# Determine Lua installation path
# Try to read the .prefix.txt file to get the Lua installation path
# This is out firt option. If it fails, we will use the default path
# If the file is empty, we will use the default path
# If the user provided a Lua/Luarocks parameter, we will use that instead
# In any case we will try to read the .prefix.txt file first as it should contain the correct paths of the installation
$PrefixFile = Join-Path $ScriptDir ".lua_prefix.txt"
if (Test-Path $PrefixFile) {
    try {
        $LuaInstallPath = Get-Content $PrefixFile -Raw | ForEach-Object { $_.Trim() }
        $DefaultLuaBinPath = Join-Path $LuaInstallPath "bin"
        if ([string]::IsNullOrWhiteSpace($LuaInstallPath)) {
            Write-Warning "Empty .prefix.txt file found. Using default path .\lua"
            $LuaInstallPath = Join-Path $ScriptDir "lua"
        } else {
            Write-Host "Found installation path from .prefix.txt: $LuaInstallPath" -ForegroundColor Magenta
        }
        # Set LuaRocks path based on Lua installation path
        $LuaRocksInstallPath = Join-Path $LuaInstallPath "luarocks"
        $DefaultLuaRocksPath = $LuaRocksInstallPath
        Write-Host "Found LuaRocks installation path: $LuaRocksInstallPath" -ForegroundColor Magenta
    }
    catch {
        Write-Warning "Failed to read .prefix.txt file: $($_.Exception.Message). Using default path .\lua"
        $LuaInstallPath = Join-Path $ScriptDir "lua"
        $LuaRocksInstallPath = Join-Path $LuaInstallPath "luarocks"
    }
} else {
    Write-Warning ".prefix.txt file not found. Using default path .\lua" -ForegroundColor Yellow
    $LuaInstallPath = Join-Path $ScriptDir "lua"
    $LuaRocksInstallPath = Join-Path $LuaInstallPath "luarocks"
}

### LUA INSTALATION PATH provided by the user ###
# Lua installation path should be the directory where a bin folder exists and contains lua.exe
# If the user provided a Lua parameter, use it
# This has the highest priority over .prefix.txt file
if ($Lua -ne "") {
    # Use provided Lua parameter (highest priority)
    $LuaInstallPath = $Lua
    # Convert relative path to absolute path
    if (-not [System.IO.Path]::IsPathRooted($LuaInstallPath)) {
        $LuaInstallPath = Join-Path (Get-Location) $LuaInstallPath
    }
    # Check if the provided path exists
    if (-not (Test-Path $LuaInstallPath)) {
        Write-Error "Lua installation path does not exist: $LuaInstallPath" -ForegroundColor Red
        return
    }
    Write-Host "Using Lua installation path from -Lua parameter: $LuaInstallPath" -ForegroundColor Magenta
}
# Define paths based on Lua installation path and optional parameters
$LuaBinPath = Join-Path $LuaInstallPath "bin"

### LUA ROCKS INSTALLATION PATH provided by the user ###
# LuaRocks installation path should be the directory where a luarocks.exe exists
# Determine LuaRocks path
if ($Luarocks -ne "") {
    # Use provided Luarocks parameter
    $LuaRocksPath = $Luarocks
    # Convert relative path to absolute path
    if (-not [System.IO.Path]::IsPathRooted($LuaRocksPath)) {
        $LuaRocksPath = Join-Path (Get-Location) $LuaRocksPath
    }
    # Check if the provided path exists
    if (-not (Test-Path $LuaRocksPath)) {
        Write-Error "LuaRocks installation path does not exist: $LuaRocksPath"
        return
    }
    Write-Host "Using LuaRocks installation path from -Luarocks parameter: $LuaRocksPath" -ForegroundColor Cyan
} else {
    # Use default path relative to Lua installation
    $LuaRocksPath = $DefaultLuaRocksPath
}

# Check if Lua installation exists
if (-not (Test-Path $LuaBinPath)) {
    Write-Host "Lua installation not found at: $LuaBinPath"
    Write-Host "Using default Lua path: $DefaultLuaBinPath" -ForegroundColor Blue
    # Default to the Lua bin path relative to the script directory
    $LuaBinPath = $DefaultLuaBinPath
}

# Check if LuaRocks installation exists
if (-not (Test-Path $LuaRocksPath)) {
    Write-Host "LuaRocks installation not found at: $LuaRocksPath" -ForegroundColor Red
    Write-Host "Using default LuaRocks path: $DefaultLuaRocksPath" -ForegroundColor Blue
    # Default to the LuaRocks path relative to the script directory
    $LuaRocksPath = $DefaultLuaRocksPath
}

# Check if lua.exe exists
$LuaExe = Join-Path $LuaBinPath "lua.exe"
if (-not (Test-Path $LuaExe)) {
    Write-Error "lua.exe not found at: $LuaExe" -ForegroundColor Red
    Write-Host "Please ensure Lua is installed correctly." -ForegroundColor Yellow
    return
}

# Check if luarocks.exe exists
$LuaRocksExe = Join-Path $LuaRocksPath "luarocks.exe"
if (-not (Test-Path $LuaRocksExe)) {
    Write-Error "luarocks.exe not found at: $LuaRocksExe" -ForegroundColor Red
    Write-Host "Please ensure LuaRocks is installed correctly." -ForegroundColor Yellow
    return
}

# Add Lua and LuaRocks to PATH for the current session
$env:PATH = "$LuaBinPath;$LuaRocksPath;$env:PATH"

# Configure LuaRocks variables for compilation
$LuaIncludeDir = Join-Path $LuaInstallPath "include"
$LuaLibDir = Join-Path $LuaInstallPath "lib"

# Ensure the expected library name exists for LuaRocks
$TargetLib = Join-Path $LuaLibDir "lua54.lib"

# Use provided Tree parameter or default to user's AppData\Roaming\luarocks
if ($Tree -ne "") {
    $UserLuaRocksTree = $Tree
    # Convert relative path to absolute path
    if (-not [System.IO.Path]::IsPathRooted($UserLuaRocksTree)) {
        $UserLuaRocksTree = Join-Path (Get-Location) $UserLuaRocksTree
    }
    Write-Host "Debug: Tree parameter provided: $Tree" -ForegroundColor Yellow
    Write-Host "Debug: Resolved UserLuaRocksTree: $UserLuaRocksTree" -ForegroundColor Yellow
} else {
    $UserLuaRocksTree = Join-Path $env:USERPROFILE "AppData\Roaming\luarocks"
    Write-Host "Debug: Using default UserLuaRocksTree: $UserLuaRocksTree" -ForegroundColor Yellow
}

# Create user LuaRocks tree directory if it doesn't exist
if (-not (Test-Path $UserLuaRocksTree)) {
    New-Item -ItemType Directory -Path $UserLuaRocksTree -Force | Out-Null
}

# Create a temporary LuaRocks config file
$TempConfigDir = Join-Path $env:TEMP "luarocks-config"
if (-not (Test-Path $TempConfigDir)) {
    New-Item -ItemType Directory -Path $TempConfigDir -Force | Out-Null
}

$ConfigFile = Join-Path $TempConfigDir "config.lua"
$ConfigContent = @"
variables = {
    LUA_INCDIR = [[$LuaIncludeDir]],
    LUA_LIBDIR = [[$LuaLibDir]],
    LUA_BINDIR = [[$LuaBinPath]],
    LUA_LIB    = [[$TargetLib]],
}
rocks_trees = {
    { name = "user", root = [[$UserLuaRocksTree]] }
}
"@

$ConfigContent | Out-File -FilePath $ConfigFile -Encoding UTF8

# Clear any existing LuaRocks environment variables that might interfere
$env:LUAROCKS_SYSCONFIG = $null
$env:LUAROCKS_USERCONFIG = $null
$env:LUAROCKS_PREFIX = $null

# Set our custom config
$env:LUAROCKS_CONFIG = $ConfigFile

# Debug output for LuaRocks configuration
Write-Host "Debug: LuaRocks config file: $ConfigFile" -ForegroundColor Magenta
Write-Host "Debug: LuaRocks tree in config: $UserLuaRocksTree" -ForegroundColor Magenta

# Set Lua path and cpath for require() to work properly
$LuaVersion = "5.4"

# Use the UserLuaRocksTree that was already configured above
# This ensures consistency between LuaRocks config and Lua paths
$LuaRocksTree = $UserLuaRocksTree

# Debug output to verify the tree being used
Write-Host "Debug: Using LuaRocks tree: $LuaRocksTree" -ForegroundColor Magenta

# Set LUA_PATH for Lua modules
$LuaPath = @(
    ".\?.lua",
    ".\?\init.lua",
    "$LuaRocksTree\share\lua\$LuaVersion\?.lua",
    "$LuaRocksTree\share\lua\$LuaVersion\?\init.lua"
) -join ";"

$env:LUA_PATH = "$LuaPath;;"

# Set LUA_CPATH for compiled Lua modules
$LuaCPath = @(
    ".\?.dll",
    "$LuaRocksTree\lib\lua\$LuaVersion\?.dll"
) -join ";"

$env:LUA_CPATH = "$LuaCPath;;"

# Display success message with version information
Write-Host "Lua environment configured successfully!" -ForegroundColor Green
Write-Host ""

# Show Lua version
Write-Host "Lua version:" -ForegroundColor Cyan
& $LuaExe -v

Write-Host ""

# Show LuaRocks version
Write-Host "LuaRocks version:" -ForegroundColor Cyan
& $LuaRocksExe --version

Write-Host ""
Write-Host "Environment variables set:" -ForegroundColor Yellow
Write-Host "  LUA_PATH: $env:LUA_PATH" -ForegroundColor Gray
Write-Host "  LUA_CPATH: $env:LUA_CPATH" -ForegroundColor Gray
Write-Host "  PATH updated with Lua and LuaRocks directories" -ForegroundColor Gray

Write-Host ""
Write-Host "You can now use 'lua' and 'luarocks' commands in this shell session." -ForegroundColor Green
