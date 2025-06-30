#!/usr/bin/env pwsh

# use-lua.ps1 - LuaEnv Environment Setup Script
# Configures current PowerShell session to use a Lua installation from the LuaEnv registry
#
# Parameters:
#   -Id <uuid>        Use installation by UUID (full or partial)
#   -Alias <name>     Use installation by alias
#   -List             List available installations
#   -Info             Show current environment information
#   -Tree <path>      Custom LuaRocks package tree path
#   -Help             Display help information

param(
    [string]$Id = "",
    [string]$Alias = "",
    [string]$Tree = "",
    [switch]$List,
    [switch]$Info,
    [switch]$Help
)

# Display help information if requested
if ($Help) {
    Write-Host "use-lua.ps1 - LuaEnv Environment Setup Script" -ForegroundColor Green
    Write-Host "=============================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "DESCRIPTION:" -ForegroundColor Yellow
    Write-Host "  Sets up the current PowerShell session to use a Lua installation from the LuaEnv registry."
    Write-Host "  Automatically configures Visual Studio Developer Shell, PATH, and Lua module paths."
    Write-Host ""
    Write-Host "SYNTAX:" -ForegroundColor Yellow
    Write-Host "  .\use-lua.ps1 [[-Id] <string>] [[-Alias] <string>] [[-Tree] <string>] [-List] [-Info] [-Help]"
    Write-Host ""
    Write-Host "PARAMETERS:" -ForegroundColor Yellow
    Write-Host "  -Id <uuid>        Use installation by UUID (full or partial, minimum 8 characters)"
    Write-Host "  -Alias <name>     Use installation by alias name"
    Write-Host "  -Tree <path>      Custom LuaRocks package tree path"
    Write-Host "  -List             List all available installations"
    Write-Host "  -Info             Show current environment information"
    Write-Host "  -Help             Display this help information"
    Write-Host ""
    Write-Host "EXAMPLES:" -ForegroundColor Yellow
    Write-Host "  List available installations:"
    Write-Host "  .\use-lua.ps1 -List" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  Use default installation:"
    Write-Host "  .\use-lua.ps1" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  Use installation by alias:"
    Write-Host "  .\use-lua.ps1 -Alias dev" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  Use installation by partial UUID:"
    Write-Host "  .\use-lua.ps1 -Id a1b2c3d4" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  Use installation with custom LuaRocks tree:"
    Write-Host "  .\use-lua.ps1 -Alias dev -Tree 'C:\MyProject\lua_modules'" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  Show current environment info:"
    Write-Host "  .\use-lua.ps1 -Info" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "WHAT THIS SCRIPT DOES:" -ForegroundColor Yellow
    Write-Host "  1. Loads the LuaEnv registry from %USERPROFILE%\.luaenv"
    Write-Host "  2. Resolves installation by ID, alias, or default"
    Write-Host "  3. Finds and initializes Visual Studio Developer Shell"
    Write-Host "  4. Adds Lua and LuaRocks to PATH for current session"
    Write-Host "  5. Configures LUA_PATH and LUA_CPATH for module loading"
    Write-Host "  6. Sets up LuaRocks configuration for compilation"
    Write-Host ""
    Write-Host "PRIORITY ORDER:" -ForegroundColor Yellow
    Write-Host "  1. -Id parameter (highest priority)"
    Write-Host "  2. -Alias parameter"
    Write-Host "  3. Registry default installation"
    Write-Host "  4. Error if no installations found"
    Write-Host ""
    Write-Host "NOTE: All changes are session-specific and don't affect system-wide settings." -ForegroundColor Red
    Write-Host ""
    return
}

function Get-LuaEnvRegistry {
    """Load and parse the LuaEnv registry."""
    $registryPath = Join-Path $env:USERPROFILE ".luaenv\registry.json"

    if (-not (Test-Path $registryPath)) {
        Write-Host "[ERROR] LuaEnv registry not found at: $registryPath" -ForegroundColor Red
        Write-Host "[INFO] Run 'python setup_lua.py' to create your first installation" -ForegroundColor Yellow
        return $null
    }

    try {
        $registryContent = Get-Content $registryPath -Raw | ConvertFrom-Json
        return $registryContent
    }
    catch {
        Write-Host "[ERROR] Failed to load registry: $_" -ForegroundColor Red
        return $null
    }
}

function Find-Installation {
    param($registry, $id, $alias)

    # Try alias first if provided
    if ($alias) {
        if ($registry.aliases.PSObject.Properties.Name -contains $alias) {
            $installationId = $registry.aliases.$alias
            if ($registry.installations.PSObject.Properties.Name -contains $installationId) {
                return $registry.installations.$installationId
            }
        }
        Write-Host "[ERROR] Alias '$alias' not found" -ForegroundColor Red
        return $null
    }

    # Try ID if provided
    if ($id) {
        # Try exact match first
        if ($registry.installations.PSObject.Properties.Name -contains $id) {
            return $registry.installations.$id
        }

        # Try partial match (minimum 8 characters)
        if ($id.Length -ge 8) {
            $matches = @()
            foreach ($installationId in $registry.installations.PSObject.Properties.Name) {
                if ($installationId.StartsWith($id)) {
                    $matches += $installationId
                }
            }

            if ($matches.Count -eq 1) {
                return $registry.installations.($matches[0])
            }
            elseif ($matches.Count -gt 1) {
                Write-Host "[ERROR] Ambiguous partial ID '$id'. Matches:" -ForegroundColor Red
                foreach ($match in $matches) {
                    Write-Host "  $match" -ForegroundColor Yellow
                }
                return $null
            }
        }

        Write-Host "[ERROR] Installation '$id' not found" -ForegroundColor Red
        return $null
    }

    # Use default installation
    if ($registry.default_installation -and
        $registry.installations.PSObject.Properties.Name -contains $registry.default_installation) {
        return $registry.installations.($registry.default_installation)
    }

    Write-Host "[ERROR] No default installation set" -ForegroundColor Red
    return $null
}

function Show-Installations {
    param($registry)

    $installations = @()
    foreach ($prop in $registry.installations.PSObject.Properties) {
        $installations += $prop.Value
    }

    if ($installations.Count -eq 0) {
        Write-Host "[INFO] No installations found" -ForegroundColor Yellow
        Write-Host "[INFO] Run 'python setup_lua.py' to create your first installation" -ForegroundColor Yellow
        return
    }

    Write-Host "[INFO] Available installations:" -ForegroundColor Green
    Write-Host ""

    foreach ($installation in $installations) {
        $isDefault = $registry.default_installation -eq $installation.id
        $status = if ($isDefault) { "[DEFAULT]" } else { "[$($installation.status.ToUpper())]" }
        $aliasInfo = if ($installation.alias) { " (alias: $($installation.alias))" } else { "" }

        Write-Host "  $status $($installation.name)$aliasInfo" -ForegroundColor $(if ($isDefault) { "Green" } else { "White" })
        Write-Host "    ID: $($installation.id)" -ForegroundColor Gray
        Write-Host "    Lua: $($installation.lua_version), LuaRocks: $($installation.luarocks_version)" -ForegroundColor Gray
        Write-Host "    Build: $($installation.build_type) $($installation.build_config)" -ForegroundColor Gray
        Write-Host "    Path: $($installation.installation_path)" -ForegroundColor Gray
        if ($installation.last_used) {
            Write-Host "    Last used: $($installation.last_used)" -ForegroundColor Gray
        }
        Write-Host ""
    }
}

function Show-EnvironmentInfo {
    Write-Host "[INFO] Current Environment Information:" -ForegroundColor Green
    Write-Host ""

    if ($env:LUAENV_CURRENT) {
        Write-Host "  Active Installation: $env:LUAENV_CURRENT" -ForegroundColor Green
    } else {
        Write-Host "  No LuaEnv installation active" -ForegroundColor Yellow
    }

    if ($env:LUA_PATH) {
        Write-Host "  LUA_PATH: $env:LUA_PATH" -ForegroundColor Gray
    }

    if ($env:LUA_CPATH) {
        Write-Host "  LUA_CPATH: $env:LUA_CPATH" -ForegroundColor Gray
    }

    if ($env:LUAROCKS_CONFIG) {
        Write-Host "  LUAROCKS_CONFIG: $env:LUAROCKS_CONFIG" -ForegroundColor Gray
    }

    # Test if lua and luarocks are available
    try {
        $luaVersion = & lua -v 2>&1
        Write-Host "  Lua Version: $luaVersion" -ForegroundColor Green
    }
    catch {
        Write-Host "  Lua: Not available in PATH" -ForegroundColor Red
    }

    try {
        $luarocksVersion = & luarocks --version 2>&1 | Select-Object -First 1
        Write-Host "  LuaRocks Version: $luarocksVersion" -ForegroundColor Green
    }
    catch {
        Write-Host "  LuaRocks: Not available in PATH" -ForegroundColor Red
    }
}

function Find-VisualStudioDeveloperShell {
    """Find and initialize Visual Studio Developer Shell."""

    # Try using vswhere to find VS installation (most reliable method)
    $vswherePath = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
    if (Test-Path $vswherePath) {
        Write-Host "[INFO] Searching for Visual Studio installation using vswhere..."
        try {
            $vsPath = & $vswherePath -latest -property installationPath 2>$null
            if ($vsPath) {
                $launchPath = Join-Path $vsPath "Common7\Tools\Launch-VsDevShell.ps1"
                if (Test-Path $launchPath) {
                    Write-Host "[OK] Found Visual Studio Developer Shell via vswhere: $launchPath"
                    # Import the VS Developer Shell with directory preservation
                    & $launchPath -Arch amd64 -HostArch amd64 -SkipAutomaticLocation >$null 2>&1
                    return $true
                }
            }
        }
        catch {
            Write-Host "[WARNING] vswhere failed: $_"
        }
    }

    # Fallback: Try common VS paths
    $vsPaths = @(
        "${env:ProgramFiles}\Microsoft Visual Studio\2022\Enterprise\Common7\Tools\Launch-VsDevShell.ps1",
        "${env:ProgramFiles}\Microsoft Visual Studio\2022\Professional\Common7\Tools\Launch-VsDevShell.ps1",
        "${env:ProgramFiles}\Microsoft Visual Studio\2022\Community\Common7\Tools\Launch-VsDevShell.ps1",
        "${env:ProgramFiles(x86)}\Microsoft Visual Studio\2019\Enterprise\Common7\Tools\Launch-VsDevShell.ps1",
        "${env:ProgramFiles(x86)}\Microsoft Visual Studio\2019\Professional\Common7\Tools\Launch-VsDevShell.ps1",
        "${env:ProgramFiles(x86)}\Microsoft Visual Studio\2019\Community\Common7\Tools\Launch-VsDevShell.ps1"
    )

    foreach ($vsPath in $vsPaths) {
        if (Test-Path $vsPath) {
            Write-Host "[OK] Found Visual Studio Developer Shell: $vsPath"
            & $vsPath -Arch amd64 -HostArch amd64 -SkipAutomaticLocation >$null 2>&1
            return $true
        }
    }

    Write-Host "[WARNING] Visual Studio Developer Shell not found. C extension compilation may not work." -ForegroundColor Yellow
    Write-Host "[INFO] Install Visual Studio with C++ build tools for full functionality." -ForegroundColor Yellow
    return $false
}

function Setup-LuaEnvironment {
    param($installation, $customTree)

    $installPath = $installation.installation_path
    $envPath = $installation.environment_path

    # Validate installation
    $luaExe = Join-Path $installPath "bin\lua.exe"
    $luarocksExe = Join-Path $installPath "luarocks\luarocks.exe"

    if (-not (Test-Path $luaExe)) {
        Write-Host "[ERROR] Lua executable not found: $luaExe" -ForegroundColor Red
        return $false
    }

    if (-not (Test-Path $luarocksExe)) {
        Write-Host "[ERROR] LuaRocks executable not found: $luarocksExe" -ForegroundColor Red
        return $false
    }

    Write-Host "[INFO] Setting up environment for: $($installation.name)" -ForegroundColor Green
    Write-Host "[INFO] Installation: $installPath" -ForegroundColor Gray
    Write-Host "[INFO] Environment: $envPath" -ForegroundColor Gray

    # Find and setup Visual Studio Developer Shell
    $vsFound = Find-VisualStudioDeveloperShell

    # Determine LuaRocks tree path
    $luarocksTree = if ($customTree) {
        $customTree
    } else {
        $envPath
    }

    # Create directories if they don't exist
    if (-not (Test-Path $luarocksTree)) {
        New-Item -ItemType Directory -Path $luarocksTree -Force | Out-Null
        Write-Host "[INFO] Created LuaRocks tree: $luarocksTree" -ForegroundColor Gray
    }

    # Clear conflicting environment variables
    $env:LUAROCKS_SYSCONFIG = $null
    $env:LUAROCKS_USERCONFIG = $null
    $env:LUAROCKS_PREFIX = $null

    # Set LuaEnv current installation
    $env:LUAENV_CURRENT = $installation.id

    # Add Lua and LuaRocks to PATH
    $luaBinPath = Join-Path $installPath "bin"
    $luarocksBinPath = Join-Path $installPath "luarocks"
    $env:PATH = "$luaBinPath;$luarocksBinPath;$env:PATH"

    # Configure Lua module paths
    $luaLibPath = Join-Path $luarocksTree "lib\lua\5.4"
    $luaSharePath = Join-Path $luarocksTree "share\lua\5.4"

    $env:LUA_PATH = ".\?.lua;.\?\init.lua;$luaSharePath\?.lua;$luaSharePath\?\init.lua;;"
    $env:LUA_CPATH = ".\?.dll;$luaLibPath\?.dll;;"

    # Create LuaRocks configuration
    $luarocksConfigDir = Join-Path $env:TEMP "luarocks-config"
    if (-not (Test-Path $luarocksConfigDir)) {
        New-Item -ItemType Directory -Path $luarocksConfigDir -Force | Out-Null
    }

    $luarocksConfigFile = Join-Path $luarocksConfigDir "config.lua"
    $luaIncDir = Join-Path $installPath "include"
    $luaLibDir = Join-Path $installPath "lib"

    $configContent = @"
-- LuaRocks configuration for LuaEnv installation: $($installation.id)
rocks_trees = {
    { name = "user", root = "$($luarocksTree.Replace('\', '\\'))" }
}
lua_interpreter = "$($luaExe.Replace('\', '\\'))"
lua_version = "5.4"
lua_incdir = "$($luaIncDir.Replace('\', '\\'))"
lua_libdir = "$($luaLibDir.Replace('\', '\\'))"
lua_bindir = "$($luaBinPath.Replace('\', '\\'))"
lua_lib = "lua54.lib"
"@

    # Write config file without BOM
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($luarocksConfigFile, $configContent, $utf8NoBom)

    $env:LUAROCKS_CONFIG = $luarocksConfigFile
    $env:LUAROCKS_SYSCONFDIR = $luarocksConfigDir

    Write-Host "[OK] Lua environment configured successfully!" -ForegroundColor Green

    # Display version information
    try {
        Write-Host "[INFO] Lua version:" -ForegroundColor Yellow
        & lua -v
        Write-Host "[INFO] LuaRocks version:" -ForegroundColor Yellow
        & luarocks --version | Select-Object -First 1
    }
    catch {
        Write-Host "[WARNING] Could not verify installation" -ForegroundColor Yellow
    }

    Write-Host "[INFO] Environment variables set:" -ForegroundColor Yellow
    Write-Host "  LUAENV_CURRENT: $env:LUAENV_CURRENT" -ForegroundColor Gray
    Write-Host "  LUA_PATH: $env:LUA_PATH" -ForegroundColor Gray
    Write-Host "  LUA_CPATH: $env:LUA_CPATH" -ForegroundColor Gray
    Write-Host "  LUAROCKS_CONFIG: $env:LUAROCKS_CONFIG" -ForegroundColor Gray
    Write-Host "  PATH updated with Lua and LuaRocks directories" -ForegroundColor Gray
    Write-Host ""
    Write-Host "[SUCCESS] You can now use 'lua' and 'luarocks' commands in this shell session." -ForegroundColor Green

    # Update last used timestamp
    try {
        & python -c "from registry import LuaEnvRegistry; LuaEnvRegistry().update_last_used('$($installation.id)')" 2>$null
    }
    catch {
        # Silently ignore registry update failures
    }

    return $true
}

# Main script logic
try {
    # Load registry
    $registry = Get-LuaEnvRegistry
    if (-not $registry) {
        exit 1
    }

    # Handle list command
    if ($List) {
        Show-Installations $registry
        return
    }

    # Handle info command
    if ($Info) {
        Show-EnvironmentInfo
        return
    }

    # Find installation
    $installation = Find-Installation $registry $Id $Alias
    if (-not $installation) {
        Write-Host "[INFO] Available installations:" -ForegroundColor Yellow
        Show-Installations $registry
        exit 1
    }

    # Setup environment
    $success = Setup-LuaEnvironment $installation $Tree
    if (-not $success) {
        exit 1
    }
}
catch {
    Write-Host "[ERROR] Script failed: $_" -ForegroundColor Red
    exit 1
}
