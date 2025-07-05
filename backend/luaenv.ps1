#!/usr/bin/env pwsh

# This is free and unencumbered software released into the public domain.
# For more details, see the LICENSE file in the project root.

# luaenv.ps1 - Combined LuaEnv CLI wrapper and environment activator

param(
    [Parameter(Position=0)]
    [string]$Command,

    [Parameter(ValueFromRemainingArguments=$true)]
    [string[]]$Arguments
)

# Get the directory where this script is located (bin directory)
$PSScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Definition
$BinDir = $PSScriptRoot
$backendDir = $PSScriptRoot

# Help command - can be run directly without the CLI
if ($Command -eq "help" -or $Command -eq "-h" -or $Command -eq "--help" -or $Command -eq "/?") {
    Write-Host ""
    Write-Host "LuaEnv - Lua Environment Management Tool" -ForegroundColor Cyan
    Write-Host "======================================="
    Write-Host "USAGE:"
    Write-Host "  luaenv <command> [options]"
    Write-Host ""
    Write-Host "COMMANDS:"
    Write-Host ""
    Write-Host "  Environment Management (CLI):"
    Write-Host "    install [options]          Install a new Lua environment"
    Write-Host "    uninstall <alias|uuid>     Remove a Lua installation"
    Write-Host "    list                       List all installed Lua environments"
    Write-Host "    status                     Show system status and registry information"
    Write-Host "    versions                   Show installed and available versions"
    Write-Host "    pkg-config <alias|uuid>    Show pkg-config information for C developers"
    Write-Host "    config                     Show current configuration"
    Write-Host "    set-alias <uuid> <alias>   Set or update the alias of an installation"
    Write-Host "    help                       Show CLI help message"
    Write-Host ""
    Write-Host "  Shell Integration (PowerShell):"
    Write-Host "    activate [alias|options] Activate a Lua environment in current shell"
    Write-Host ""
    Write-Host "For command-specific help:"
    Write-Host "  luaenv <command> --help"
    Write-Host ""
    Write-Host "EXAMPLES:"
    Write-Host "  luaenv install --alias dev           # Install Lua with alias 'dev'"
    Write-Host "  luaenv activate dev                  # Activate 'dev' environment (shorthand)"
    Write-Host "  luaenv activate --alias dev          # Activate 'dev' environment"
    Write-Host "  luaenv list                          # Show all installations"
    Write-Host "  luaenv activate --list               # List available environments"
    Write-Host "  luaenv set-alias 1234abcd prod       # Set alias 'prod' for installation "
    Write-Host "                                         with UUID 1234abcd (matches first 8 chars)"
    Write-Host ""
    Write-Host "Note: 'activate' is a PowerShell-only command that modifies your current shell." -ForegroundColor Yellow
    Write-Host "      All other commands are handled by the LuaEnv CLI application." -ForegroundColor Yellow
    exit 0
}

# PowerShell-specific activate command - changes the current shell environment
if ($Command -eq "activate") {
    if ($Arguments -contains "--help" -or $Arguments -contains "-h") {
        Write-Host ""
        Write-Host "Usage: luaenv activate [options]"
        Write-Host ""
        Write-Host "Activate a Lua environment in the current PowerShell session."
        Write-Host "This command modifies environment variables in your current shell."
        Write-Host ""
        Write-Host "Options:"
        Write-Host "  <alias>            Activate installation with the specified alias (shorthand syntax)"
        Write-Host "  --id <uuid>        Activate installation with the specified UUID"
        Write-Host "  --alias <name>     Activate installation with the specified alias"
        Write-Host "  --list             List available installations"
        Write-Host "  --env              Show current environment information"
        Write-Host "  --tree <path>      Set custom LuaRocks tree path"
        Write-Host "  --devshell <path>  Use custom Visual Studio Developer Shell"
        Write-Host "  --help, -h         Show this help information"
        Write-Host ""
        Write-Host "Examples:"
        Write-Host "  luaenv activate dev          # Shorthand to activate installation with alias 'dev'"
        Write-Host "  luaenv activate --alias dev  # Same as above, with explicit flag"
        Write-Host "  luaenv activate --list       # List all available installations"
        Write-Host ""
        exit 0
    }

    # Parse activate-specific arguments
    $Id = ""
    $Alias = ""
    $List = $false
    $Environment = $false
    $Tree = ""
    $DevShell = ""
    $Help = $false
    $ExplicitAliasOrId = $false  # Track if --alias or --id was explicitly provided

    # Process arguments
    for ($i = 0; $i -lt $Arguments.Count; $i++) {
        $arg = $Arguments[$i]

        switch -regex ($arg) {
            "--id|-Id" {
                if ($i + 1 -ge $Arguments.Count) {
                    Write-Error "Missing value for $arg option"
                    exit 1
                }
                $Id = $Arguments[++$i]
                $ExplicitAliasOrId = $true
            }
            "--alias|-Alias" {
                if ($i + 1 -ge $Arguments.Count) {
                    Write-Error "Missing value for $arg option"
                    exit 1
                }
                $Alias = $Arguments[++$i]
                $ExplicitAliasOrId = $true
            }
            "--list|-List" {
                $List = $true
            }
            "--env|-Env" {
                $Environment = $true
            }
            "--tree|-Tree" {
                if ($i + 1 -ge $Arguments.Count) {
                    Write-Error "Missing value for $arg option"
                    exit 1
                }
                $Tree = $Arguments[++$i]
            }
            "--devshell|-DevShell" {
                if ($i + 1 -ge $Arguments.Count) {
                    Write-Error "Missing value for $arg option"
                    exit 1
                }
                $DevShell = $Arguments[++$i]
            }
            "--help|-h" {
                $Help = $true
            }
            default {
                # If the argument doesn't start with - or -- and no explicit alias/id was provided,
                # treat it as an alias
                if (-not $arg.StartsWith('-') -and -not $ExplicitAliasOrId) {
                    $Alias = $arg
                    $ExplicitAliasOrId = $true
                } else {
                    Write-Warning "Unexpected argument: $arg"
                }
            }
        }
    }

    # Check for empty args but with flags
    # If we have flags like --tree or --devshell but no alias or id, we need to show an error
    if (-not $Help -and -not $List -and -not $Environment -and -not $Id -and -not $Alias) {
        $hasOtherFlags = $Tree -or $DevShell
        if ($hasOtherFlags) {
            Write-Host "[ERROR] Missing required alias or ID parameter" -ForegroundColor Red
            Write-Host "[INFO] Usage: luaenv activate <alias> or luaenv activate --alias <name>" -ForegroundColor Yellow
            Write-Host "[INFO] Run 'luaenv activate --help' for more information" -ForegroundColor Yellow
            exit 1
        }
    }

    # Include all the activate functionality from luaenv2.ps1
    function Get-LuaEnvRegistry {
        # Load and parse the LuaEnv registry.
        $registryPath = Join-Path $env:USERPROFILE ".luaenv\registry.json"

        if (-not (Test-Path $registryPath)) {
            Write-Host "[ERROR] LuaEnv registry not found at: $registryPath" -ForegroundColor Red
            Write-Host "[INFO] Run 'luaenv install' to create your first installation" -ForegroundColor Yellow
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

            Write-Host "[ERROR] Installation with alias '$alias' not found" -ForegroundColor Red
            Write-Host "[INFO] Run 'luaenv list' to see all available installations" -ForegroundColor Yellow
            return $null
        }

        # Try direct ID match
        if ($id) {
            if ($registry.installations.PSObject.Properties.Name -contains $id) {
                return $registry.installations.$id
            }

            # Try to match partial UUID (minimum 8 chars)
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

        # If registry is null, don't show anything (error already handled by Get-LuaEnvRegistry)
        if (-not $registry) {
            return
        }

        $installations = @()
        foreach ($key in $registry.installations.PSObject.Properties.Name) {
            $installations += $registry.installations.$key
        }

        if ($installations.Count -eq 0) {
            Write-Host "[INFO] No installations found" -ForegroundColor Yellow
            Write-Host "[INFO] Run 'luaenv install --alias my-lua' to create your first installation" -ForegroundColor Yellow
            return
        }

        Write-Host "[INFO] Available installations:" -ForegroundColor Green
        Write-Host ""

        foreach ($installation in $installations) {
            $defaultMark = if ($registry.default_installation -eq $installation.id) { " [DEFAULT]" } else { "" }
            $aliasList = ""

            # Find all aliases for this installation
            $aliases = @()
            foreach ($key in $registry.aliases.PSObject.Properties.Name) {
                if ($registry.aliases.$key -eq $installation.id) {
                    $aliases += $key
                }
            }

            if ($aliases.Count -gt 0) {
                $aliasList = " (alias: $($aliases -join ", "))"
            }

            $status = $installation.status.ToUpper()
            $statusColor = switch ($status) {
                "ACTIVE" { "Green" }
                "BUILDING" { "Yellow" }
                "BROKEN" { "Red" }
                default { "Gray" }
            }

            Write-Host "  [$status]$defaultMark $($installation.name)$aliasList" -ForegroundColor $statusColor
            Write-Host "    ID: $($installation.id)" -ForegroundColor Gray
            Write-Host "    Lua: $($installation.lua_version), LuaRocks: $($installation.luarocks_version)" -ForegroundColor Gray
            Write-Host "    Build: $($installation.build_type.ToUpper()) $($installation.build_config)" -ForegroundColor Gray
            Write-Host "    Path: $($installation.installation_path)" -ForegroundColor Gray

            if ($installation.last_used) {
                try {
                    $lastUsed = [DateTime]::Parse($installation.last_used)
                    $timeAgo = (Get-Date) - $lastUsed
                    if ($timeAgo.TotalDays -gt 1) {
                        $usedInfo = "{0:N0} days ago" -f $timeAgo.TotalDays
                    }
                    elseif ($timeAgo.TotalHours -gt 1) {
                        $usedInfo = "{0:N0} hours ago" -f $timeAgo.TotalHours
                    }
                    else {
                        $usedInfo = "{0:N0} minutes ago" -f $timeAgo.TotalMinutes
                    }
                    Write-Host "    Last used: $usedInfo" -ForegroundColor Gray
                }
                catch {
                    # Ignore date parsing errors
                }
            }

            if ($installation.packages -and $installation.packages.count -gt 0) {
                Write-Host "    Packages: $($installation.packages.count)" -ForegroundColor Gray
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
            Write-Host "  No active installation" -ForegroundColor Yellow
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
            Write-Host "  Lua: $luaVersion" -ForegroundColor Green
        }
        catch {
            Write-Host "  Lua: Not in PATH" -ForegroundColor Yellow
        }

        try {
            $luarocksVersion = & luarocks --version 2>&1
            Write-Host "  LuaRocks: $luarocksVersion" -ForegroundColor Green
        }
        catch {
            Write-Host "  LuaRocks: Not in PATH" -ForegroundColor Yellow
        }
    }

    function Get-VsPathConfig {
        # Get Visual Studio path from .vspath.txt config file.
        $configPath = Join-Path $PSScriptRoot ".vspath.txt"

        if (Test-Path $configPath) {
            try {
                $path = Get-Content $configPath -Raw
                if ($path -and (Test-Path $path)) {
                    return $path
                }
            }
            catch {
                # Silently ignore errors
            }
        }

        return $null
    }

    function Set-VsPathConfig {
        param([string]$VsPath)
        # Save Visual Studio path to .vspath.txt config file.

        $configPath = Join-Path $PSScriptRoot ".vspath.txt"

        try {
            $VsPath | Set-Content $configPath -Force
            Write-Host "[INFO] Visual Studio path saved to config: $VsPath" -ForegroundColor Green
            return $true
        }
        catch {
            Write-Host "[ERROR] Failed to save Visual Studio path: $_" -ForegroundColor Red
            return $false
        }
    }

    function Find-VisualStudioDeveloperShell {
        param(
            [string]$Architecture = "x64",
            [string]$CustomPath = "",        # Custom VS Tools path
            [switch]$SavePathToConfig = $false  # Only save when explicitly provided via --devshell
        )
        # Find and initialize Visual Studio Developer Shell.

        # Determine VS arch parameter based on architecture
        $vsArch = if ($Architecture -eq "x86") { "x86" } else { "amd64" }

        # Write-Host "[INFO] Setting up Visual Studio Developer Shell for $Architecture architecture..."

        # Priority 1: Try custom path if provided
        if ($CustomPath) {
            $launchPath = Join-Path $CustomPath "Launch-VsDevShell.ps1"
            if (Test-Path $launchPath) {
                Write-Host "[INFO] Using custom VS Developer Shell: $launchPath"
                try {
                    # Launch VS Developer Shell and import environment
                    & $launchPath -Arch $vsArch -SkipAutomaticLocation
                    # Write-Host "[OK] Visual Studio Developer Shell initialized" -ForegroundColor Green

                    # Save path for future use, but only if explicitly provided via --devshell
                    if ($SavePathToConfig) {
                        Set-VsPathConfig -VsPath $CustomPath
                    }

                    return $true
                }
                catch {
                    Write-Host "[ERROR] Failed to initialize VS Developer Shell: $_" -ForegroundColor Red
                    return $false
                }
            }
            else {
                Write-Host "[ERROR] Custom VS Developer Shell not found: $launchPath" -ForegroundColor Red
            }
        }

        # Priority 2: Try path from .vspath.txt config
        $configPath = Get-VsPathConfig
        if ($configPath) {
            $launchPath = Join-Path $configPath "Launch-VsDevShell.ps1"
            if (Test-Path $launchPath) {
                Write-Host "[INFO] Using VS Developer Shell from config: $launchPath"
                try {
                    # Launch VS Developer Shell and import environment
                    & $launchPath -Arch $vsArch -SkipAutomaticLocation
                    # Write-Host "[OK] Visual Studio Developer Shell initialized" -ForegroundColor Green
                    return $true
                }
                catch {
                    Write-Host "[ERROR] Failed to initialize VS Developer Shell: $_" -ForegroundColor Red
                }
            }
            else {
                Write-Host "[WARNING] VS Developer Shell from config not found: $launchPath" -ForegroundColor Yellow
            }
        }

        # Priority 3: Try using vswhere to find VS installation
        $vswherePath = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
        if (Test-Path $vswherePath) {
            # Write-Host "[INFO] Searching for Visual Studio installation using vswhere..."
            try {
                $vsInstallPath = & $vswherePath -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
                if ($vsInstallPath) {
                    $launchPath = Join-Path $vsInstallPath "Common7\Tools\Launch-VsDevShell.ps1"
                    if (Test-Path $launchPath) {
                        # Write-Host "[INFO] Using VS Developer Shell found by vswhere: $launchPath"
                        & $launchPath -Arch $vsArch -SkipAutomaticLocation
                        # Write-Host "[OK] Visual Studio Developer Shell initialized" -ForegroundColor Green

                        # Save path for future use only if explicitly requested
                        if ($SavePathToConfig) {
                            $vsToolsPath = Join-Path $vsInstallPath "Common7\Tools"
                            Set-VsPathConfig -VsPath $vsToolsPath
                        }

                        return $true
                    }
                }
            }
            catch {
                # Write-Host "[ERROR] Failed to use vswhere: $_" -ForegroundColor Yellow
            }
        }

        # Priority 4: Try common VS paths
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
                Write-Host "[INFO] Using VS Developer Shell: $vsPath"
                try {
                    & $vsPath -Arch $vsArch -SkipAutomaticLocation

                    # Write-Host "[OK] Visual Studio Developer Shell initialized" -ForegroundColor Green

                    # Save path for future use only if explicitly requested
                    if ($SavePathToConfig) {
                        $vsToolsPath = Split-Path -Parent $vsPath
                        Set-VsPathConfig -VsPath $vsToolsPath
                    }

                    return $true
                }
                catch {
                    Write-Host "[WARNING] Failed to initialize VS Developer Shell: $_" -ForegroundColor Yellow
                }
            }
        }

        Write-Host "[WARNING] Visual Studio Developer Shell not found. C extension compilation may not work." -ForegroundColor Yellow
        Write-Host "[INFO] Install Visual Studio with C++ build tools for full functionality." -ForegroundColor Yellow
        Write-Host "[INFO] Or specify VS path with: --devshell <path>" -ForegroundColor Yellow
        return $false
    }

    function Setup-LuaEnvironment {
        param($installation, $customTree, $customDevShell)

        $installPath = $installation.installation_path
        $envPath = $installation.environment_path

        # Get architecture from installation (default to x64 if not specified)
        $architecture = if ($installation.architecture) { $installation.architecture } else { "x64" }

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

        # Write-Host "[INFO] Setting up environment for: $($installation.name)" -ForegroundColor Green
        # Write-Host "[INFO] Architecture: $architecture" -ForegroundColor Gray
        # Write-Host "[INFO] Installation: $installPath" -ForegroundColor Gray
        # Write-Host "[INFO] Environment: $envPath" -ForegroundColor Gray

        # Save original system PATH before any modifications
        $originalSystemPath = $env:PATH

        # Find and setup Visual Studio Developer Shell with correct architecture
        # Only save the VS path to config if a custom path was explicitly provided
        $savePathToConfig = $customDevShell -ne ""
        $vsFound = Find-VisualStudioDeveloperShell -Architecture $architecture -CustomPath $customDevShell -SavePathToConfig:$savePathToConfig

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

        # Use a smarter PATH handling approach that preserves both VS Developer environment and original system paths
        # This ensures that both Lua/LuaRocks tools AND system tools like code, git, etc. remain available
        $currentPath = $env:PATH

        # Extract VS-specific paths (added by VS Developer Shell) by comparing with original system PATH
        $vsPathEntries = @()
        foreach ($path in $currentPath.Split(';')) {
            if ($originalSystemPath.Split(';') -notcontains $path) {
                $vsPathEntries += $path
            }
        }

        # Rebuild PATH with: Lua bins first, then VS paths, then original system paths
        # This ensures both VS Developer tools and system tools are available
        $env:PATH = "$luaBinPath;$luarocksBinPath;" + ($vsPathEntries -join ';') + ";$originalSystemPath"

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

        $luarocksConfigFile = Join-Path $luarocksConfigDir "$($installation.id)-config.lua"
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

-- Environment isolation settings
local_cache = "$($luarocksTree.Replace('\', '\\'))\\cache"
home_tree = ""
local_by_default = true
"@

        # Write config file without BOM
        $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
        [System.IO.File]::WriteAllText($luarocksConfigFile, $configContent, $utf8NoBom)

        $env:LUAROCKS_CONFIG = $luarocksConfigFile
        $env:LUAROCKS_SYSCONFDIR = $luarocksConfigDir

        # Write-Host "[OK] Lua environment configured successfully!" -ForegroundColor Green

        # # Display version information
        # try {
        #     Write-Host "[INFO] Lua version:" -ForegroundColor Yellow
        #     $luaVersion = & lua -v 2>&1
        #     Write-Host "  $luaVersion" -ForegroundColor Green
        # }
        # catch {
        #     Write-Host "  [WARNING] Could not verify Lua installation: $_" -ForegroundColor Yellow
        # }

        # try {
        #     Write-Host "[INFO] LuaRocks version:" -ForegroundColor Yellow
        #     $luarocksVersion = & luarocks --version 2>&1 | Select-Object -First 1
        #     Write-Host "  $luarocksVersion" -ForegroundColor Green
        # }
        # catch {
        #     Write-Host "  [WARNING] Could not verify LuaRocks installation: $_" -ForegroundColor Yellow
        # }

        # Write-Host "[INFO] Environment variables set:" -ForegroundColor Yellow
        # Write-Host "  LUAENV_CURRENT: $env:LUAENV_CURRENT" -ForegroundColor Gray
        # Write-Host "  LUA_PATH: $env:LUA_PATH" -ForegroundColor Gray
        # Write-Host "  LUA_CPATH: $env:LUA_CPATH" -ForegroundColor Gray
        # Write-Host "  LUAROCKS_CONFIG: $env:LUAROCKS_CONFIG" -ForegroundColor Gray
        # Write-Host "  PATH updated with Lua and LuaRocks directories" -ForegroundColor Gray
        # Write-Host ""

        # Write-Host "[SUCCESS] You can now use 'lua' and 'luarocks' commands in this shell session." -ForegroundColor Green

        return $true
    }

    # Main activate logic
    try {
        # Load registry
        $registry = Get-LuaEnvRegistry
        if (-not $registry) {
            return
        }

        # Check if any arguments were provided
        if ($Arguments.Count -eq 0) {
            Write-Host "[ERROR] No arguments provided to 'activate' command" -ForegroundColor Red
            Write-Host "[INFO] Usage: luaenv activate <alias> or luaenv activate --alias <name>" -ForegroundColor Yellow
            Write-Host "[INFO] Run 'luaenv activate --help' for more information" -ForegroundColor Yellow
            Show-Installations $registry
            exit 1
        }

        # Handle list command
        if ($List) {
            Show-Installations $registry
            return
        }

        # Handle environment info command
        if ($Environment) {
            Show-EnvironmentInfo
            return
        }

        # Verify that an alias or ID was provided
        if (-not $Id -and -not $Alias) {
            Write-Host "[ERROR] No alias or ID specified" -ForegroundColor Red
            Write-Host "[INFO] Usage: luaenv activate <alias> or luaenv activate --id <uuid>" -ForegroundColor Yellow
            Write-Host "[INFO] Run 'luaenv activate --help' for more information" -ForegroundColor Yellow
            Show-Installations $registry
            exit 1
        }

        # Find installation
        $installation = Find-Installation $registry $Id $Alias
        if (-not $installation) {
            Write-Host "[ERROR] Could not find the specified Lua installation" -ForegroundColor Red
            Write-Host "[INFO] Available installations:" -ForegroundColor Yellow
            Show-Installations $registry
            exit 1
        }

        # Setup environment
        $success = Setup-LuaEnvironment $installation $Tree $DevShell
        if (-not $success) {
            exit 1
        }
        # Remove duplicate entries from PATH
        $uniquePaths = $env:PATH -split ';' | Select-Object -Unique
        $env:PATH = $uniquePaths -join ';'
        # Exit after successful activation to prevent passing the 'activate' command to CLI
        exit 0
    }
    catch {
        Write-Host "[ERROR] Script failed: $_" -ForegroundColor Red
        exit 1
    }
}

# CLI wrapper functionality - delegate all validation to the CLI executable

function Invoke-LuaEnvCLI {
    # Get the directory where this script is located (bin directory)
    $BinDir = $PSScriptRoot

    # Set the backend config path
    $BackendConfig = Join-Path $BinDir "backend.config"

    # Set the CLI executable path
    $CliExe = Join-Path $BinDir "cli\LuaEnv.CLI.exe"

    # Check if config exists
    if (-not (Test-Path $BackendConfig)) {
        Write-Error "[ERROR] Backend configuration not found: $BackendConfig"
        exit 1
    }

    # Check if CLI exists
    if (-not (Test-Path $CliExe)) {
        Write-Error "[ERROR] CLI executable not found: $CliExe"
        exit 1
    }

    # Build arguments array
    $allArgs = @()
    if ($Command) {
        $allArgs += $Command
    }
    $allArgs += $Arguments

    # Execute CLI with config and pass through all arguments
    & $CliExe --config $BackendConfig $allArgs
}

# Call the CLI function
Invoke-LuaEnvCLI

