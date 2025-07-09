#!/usr/bin/env pwsh

# This is free and unencumbered software released into the public domain.
# For more details, see the LICENSE file in the project root.

<#
.SYNOPSIS
    LuaEnv - Combined Lua Environment Management CLI wrapper and PowerShell activator

.DESCRIPTION
    This script serves as the main entry point for the LuaEnv system, providing two modes of operation:
    1. CLI Mode: Delegates most commands to the LuaEnv CLI executable for installation management
    2. PowerShell Mode: Handles the 'activate' command natively to modify the current shell environment

    The script automatically detects the command type and routes to the appropriate handler.

.PARAMETER Command
    The LuaEnv command to execute (e.g., 'install', 'list', 'activate', 'help')

.PARAMETER Arguments
    Additional arguments passed to the specified command

.EXAMPLE
    .\luaenv.ps1 install --alias dev
    Installs a new Lua environment with the alias 'dev' (handled by CLI)

.EXAMPLE
    .\luaenv.ps1 activate dev
    Activates the 'dev' environment in the current PowerShell session

.NOTES
    Author: LuaEnv Project
    License: Public Domain
#>

param(
    [Parameter(Position=0)]
    [string]$Command,

    [Parameter(ValueFromRemainingArguments=$true)]
    [string[]]$Arguments
)

# Determine script location and working directories
# ScriptRoot points to the installation [%USERPROFILE%\.luaenv\bin] directory containing this script
$ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Definition
$BinDir = $ScriptRoot        # Installation directory (contains this script)

# ==================================================================================
# MODULE IMPORTS
# ==================================================================================

# Import the LuaEnv Core module for registry management and environment setup
$coreModule = Join-Path $ScriptRoot "luaenv_core.psm1"
if (Test-Path $coreModule) {
    try {
        Import-Module $coreModule -Force
        Write-Verbose "Successfully imported luaenv_core module"
    }
    catch {
        Write-Error "Failed to import luaenv_core module: $($_.Exception.Message)"
        Write-Error "This module is required for LuaEnv operation"
        exit 1
    }
} else {
    Write-Error "luaenv_core.psm1 module not found at: $coreModule"
    Write-Error "This module is required for LuaEnv operation"
    exit 1
}

# Import the LuaEnv UI module for display and user interface functions
$uiModule = Join-Path $ScriptRoot "luaenv_ui.psm1"
if (Test-Path $uiModule) {
    try {
        Import-Module $uiModule -Force
        Write-Verbose "Successfully imported luaenv_ui module"
    }
    catch {
        Write-Error "Failed to import luaenv_ui module: $($_.Exception.Message)"
        Write-Error "This module is required for LuaEnv operation"
        exit 1
    }
} else {
    Write-Error "luaenv_ui.psm1 module not found at: $uiModule"
    Write-Error "This module is required for LuaEnv operation"
    exit 1
}

# Import the LuaEnv Visual Studio module for C/C++ development support
$vsModule = Join-Path $ScriptRoot "luaenv_vs.psm1"
if (Test-Path $vsModule) {
    try {
        Import-Module $vsModule -Force
        Write-Verbose "Successfully imported luaenv_vs module"
        $script:UseLuaEnvVsModule = $true
    }
    catch {
        Write-Warning "Failed to import luaenv_vs module: $($_.Exception.Message)"
        Write-Warning "Falling back to legacy Visual Studio detection methods"
        $script:UseLuaEnvVsModule = $false
    }
} else {
    Write-Warning "luaenv_vs.psm1 module not found, falling back to legacy Visual Studio detection methods"
    $script:UseLuaEnvVsModule = $false
}

# ==================================================================================
# HELP COMMAND HANDLER
# ==================================================================================
# Display comprehensive help information for the LuaEnv tool
# This runs independently of the CLI executable to provide immediate help access
if ($Command -eq "help" -or $Command -eq "-h" -or $Command -eq "--help" -or $Command -eq "/?") {
    Show-LuaEnvHelp
    exit 0
}

# ==================================================================================
# ACTIVATE COMMAND HANDLER (PowerShell-specific)
# ==================================================================================
# The 'activate' command is handled natively in PowerShell to modify the current
# shell environment. This cannot be delegated to the CLI executable because
# environment changes must occur in the current process context.
if ($Command -eq "activate") {
    # ------------------------------------------------------------------
    # Display activate command help
    # ------------------------------------------------------------------
    if ($Arguments -contains "--help" -or $Arguments -contains "-h") {
        Show-ActivateHelp
        exit 0
    }

    # ------------------------------------------------------------------
    # Parse and validate activate command arguments
    # ------------------------------------------------------------------
    # Initialize argument parsing variables
    $Id = ""                      # Installation UUID (full or partial)
    $Alias = ""                   # Installation alias name
    $List = $false                # Show available installations
    $Environment = $false         # Show current environment info
    $Tree = ""                    # Custom LuaRocks tree path (deprecated)
    $DevShell = ""               # Custom Visual Studio tools path
    $Help = $false               # Show help (redundant with above check)
    $ExplicitAliasOrId = $false  # Track if --alias or --id was explicitly provided

    # Parse command line arguments using a switch statement
    # This allows for flexible argument ordering and validation
    for ($i = 0; $i -lt $Arguments.Count; $i++) {
        $arg = $Arguments[$i]

        switch -regex ($arg) {
            "--id|-Id" {
                # Parse installation UUID parameter
                if ($i + 1 -ge $Arguments.Count) {
                    Write-Error "Missing value for $arg option"
                    exit 1
                }
                $Id = $Arguments[++$i]
                $ExplicitAliasOrId = $true
            }
            "--alias|-Alias" {
                # Parse installation alias parameter
                if ($i + 1 -ge $Arguments.Count) {
                    Write-Error "Missing value for $arg option"
                    exit 1
                }
                $Alias = $Arguments[++$i]
                $ExplicitAliasOrId = $true
            }
            "--list|-List" {
                # Flag to list available installations
                $List = $true
            }
            "--env|-Env" {
                # Flag to show current environment information
                $Environment = $true
            }
            "--tree|-Tree" {
                # Parse custom LuaRocks tree path (deprecated feature)
                if ($i + 1 -ge $Arguments.Count) {
                    Write-Error "Missing value for $arg option"
                    exit 1
                }
                $Tree = $Arguments[++$i]
            }
            "--devshell|-DevShell" {
                # Parse custom Visual Studio tools path
                if ($i + 1 -ge $Arguments.Count) {
                    Write-Error "Missing value for $arg option"
                    exit 1
                }
                $DevShell = $Arguments[++$i]
            }
            "--help|-h" {
                # Flag to show help (already handled above)
                $Help = $true
            }
            default {
                # Handle positional arguments and unknown options
                # If the argument doesn't start with - or -- and no explicit alias/id was provided,
                # treat it as a shorthand alias specification
                if (-not $arg.StartsWith('-') -and -not $ExplicitAliasOrId) {
                    $Alias = $arg
                    $ExplicitAliasOrId = $true
                } else {
                    Write-Warning "Unexpected argument: $arg"
                }
            }
        }
    }

    # ------------------------------------------------------------------
    # Validate argument combinations
    # ------------------------------------------------------------------
    # Check for invalid combinations where flags are provided without required parameters
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

    # ==================================================================
    # MAIN ACTIVATION LOGIC
    # ==================================================================
    # All helper functions are now handled by backend modules:
    # - Get-LuaEnvRegistry -> luaenv_core.psm1
    # - Find-Installation -> luaenv_core.psm1
    # - Show-Installations -> luaenv_ui.psm1
    # - Show-EnvironmentInfo -> luaenv_ui.psm1
    # - Initialize-LuaEnvironment -> luaenv_core.psm1
    # Process the activation request and configure the environment
    try {
        # Load the LuaEnv registry
        $registry = Get-LuaEnvRegistry
        if (-not $registry) {
            return
        }

        # Handle list installations request
        if ($List) {
            Show-Installations $registry
            return
        }

        # Handle environment information request
        if ($Environment) {
            Show-EnvironmentInfo
            return

        }

        # Handle case when no explicit arguments were provided
        if ($Arguments.Count -eq 0) {
            # Check for local .lua-version file first
            $localVersion = Get-LocalLuaVersion
            if ($localVersion) {
                Write-Host "[INFO] Using local version from .lua-version: $localVersion" -ForegroundColor Cyan

                # Use the local version to find the installation
                $installation = $null
                if ($registry.aliases.PSObject.Properties.Name -contains $localVersion) {
                    # Local version is an alias
                    $installationId = $registry.aliases.$localVersion
                    if ($registry.installations.PSObject.Properties.Name -contains $installationId) {
                        $installation = $registry.installations.$installationId
                    }
                }
                elseif ($registry.installations.PSObject.Properties.Name -contains $localVersion) {
                    # Local version is a UUID
                    $installation = $registry.installations.$localVersion
                }
                elseif ($localVersion.Length -ge 8) {
                    # Try partial UUID match
                    $matches_lv = @()
                    foreach ($installationId in $registry.installations.PSObject.Properties.Name) {
                        if ($installationId.StartsWith($localVersion)) {
                            $matches_lv += $installationId
                        }
                    }
                    if ($matches_lv.Count -eq 1) {
                        $installation = $registry.installations.($matches_lv[0])
                    }
                }

                if ($installation) {
                    # Configure the environment with the local version
                    $success = Setup-LuaEnv $installation $Tree $DevShell
                    if ($success) {
                        # Clean up PATH by removing duplicate entries
                        $uniquePaths = $env:PATH -split ';' | Select-Object -Unique
                        $env:PATH = $uniquePaths -join ';'
                        exit 0
                    }
                    exit 1
                }
                else {
                    Write-Host "[ERROR] Invalid installation in .lua-version: $localVersion" -ForegroundColor Red
                    Write-Host "[INFO] To update local version, use: luaenv local <alias|uuid>" -ForegroundColor Yellow
                    Write-Host "[INFO] To see available installations: luaenv list" -ForegroundColor Yellow
                    exit 1
                }
            }

            # No local version, try using default installation
            if ($registry.default_installation -and
                $registry.installations.PSObject.Properties.Name -contains $registry.default_installation) {
                $defaultId = $registry.default_installation
                $installation = $registry.installations.$defaultId

                Write-Host "[INFO] Using default installation: $($installation.name)" -ForegroundColor Cyan

                # Configure the environment with the default installation
                $success = Initialize-LuaEnvironment -Installation $installation -CustomTree $Tree -CustomDevShell $DevShell
                if ($success) {
                    # Clean up PATH by removing duplicate entries
                    $uniquePaths = $env:PATH -split ';' | Select-Object -Unique
                    $env:PATH = $uniquePaths -join ';'
                    exit 0
                }
                exit 1
            }
            else {
                Write-Host "[ERROR] No local version or default installation found" -ForegroundColor Red
                Write-Host "[INFO] To set a local version: luaenv local <alias|uuid>" -ForegroundColor Yellow
                Write-Host "[INFO] Available installations:" -ForegroundColor Yellow
                Show-Installations -Registry $registry
                exit 1
            }
        }

        # Explicit arguments were provided - verify that an alias or ID was specified
        if (-not $Id -and -not $Alias) {
            Write-Host "[ERROR] No alias or ID specified" -ForegroundColor Red
            Write-Host "[INFO] Usage: luaenv activate <alias> or luaenv activate --id <uuid>" -ForegroundColor Yellow
            Write-Host "[INFO] Run 'luaenv activate --help' for more information" -ForegroundColor Yellow
            Show-Installations -Registry $registry
            exit 1
        }

        # Locate the specified installation
        $installation = Find-Installation $registry $Id $Alias
        if (-not $installation) {
            Write-Host "[ERROR] Could not find the specified Lua installation" -ForegroundColor Red
            Write-Host "[INFO] Available installations:" -ForegroundColor Yellow
            Show-Installations -Registry $registry
            exit 1
        }

        # Configure the Lua environment
        $success = Initialize-LuaEnvironment -Installation $installation -CustomTree $Tree -CustomDevShell $DevShell
        if (-not $success) {
            exit 1
        }

        # Clean up PATH by removing duplicate entries
        $uniquePaths = $env:PATH -split ';' | Select-Object -Unique
        $env:PATH = $uniquePaths -join ';'

        # Exit successfully to prevent passing the 'activate' command to CLI
        exit 0
    }
    catch {
        Write-Host "[ERROR] Script failed: $_" -ForegroundColor Red
        exit 1
    }
}

# The local version helper functions are now defined at the script root level:
# - Get-LocalLuaVersion
# - Set-LocalLuaVersion
# - Remove-LocalLuaVersion

# ==================================================================================
# DEACTIVATE COMMAND HANDLER (PowerShell-specific)
# ==================================================================================
# The 'deactivate' command reverts changes made by 'activate' to restore the original shell environment
if ($Command -eq "deactivate") {
    # Display deactivate command help if requested
    if ($Arguments -contains "--help" -or $Arguments -contains "-h") {
        Show-DeactivateHelp
        exit 0
    }

    # Check if there's an active environment
    if (-not $env:LUAENV_CURRENT) {
        Write-Host "[INFO] No active LuaEnv environment found" -ForegroundColor Yellow
        exit 0
    }

    # Get the original PATH if it was saved during activation
    $origPathVarName = "LUAENV_ORIGINAL_PATH"
    $origPath = [Environment]::GetEnvironmentVariable($origPathVarName, "Process")

    if ($origPath) {
        # Restore original PATH
        $env:PATH = $origPath
        Write-Host "[OK] Restored original PATH" -ForegroundColor Green
    } else {
        Write-Host "[WARNING] Original PATH not found, cannot fully restore environment" -ForegroundColor Yellow

        # Best-effort cleanup: remove LuaEnv-specific paths from PATH
        $pathEntries = $env:PATH.Split(';')
        $cleanedEntries = $pathEntries | Where-Object {
            -not ($_ -like "*\.luaenv\installations\*\bin" -or
                  $_ -like "*\.luaenv\installations\*\luarocks" -or
                  $_ -like "*\.luaenv\environments\*\bin")
        }
        $env:PATH = $cleanedEntries -join ';'
    }

    # Clear LuaEnv-specific environment variables
    $luaEnvVars = @(
        # Core LuaEnv variables
        "LUAENV_CURRENT",
        "LUAENV_ORIGINAL_PATH",

        # Lua variables
        "LUA_PATH",
        "LUA_CPATH",
        "LUA_BINDIR",
        "LUA_INCDIR",
        "LUA_LIBDIR",
        "LUA_LIBRARIES",

        # LuaRocks variables
        "LUAROCKS_CONFIG",
        "LUAROCKS_SYSCONFDIR",
        "LUAROCKS_SYSCONFIG",
        "LUAROCKS_USERCONFIG",
        "LUAROCKS_PREFIX"
    )

    # Clear all LuaEnv-related variables
    foreach ($var in $luaEnvVars) {
        if ([Environment]::GetEnvironmentVariable($var, "Process")) {
            [Environment]::SetEnvironmentVariable($var, $null, "Process")
        }
    }

    Write-Host "[OK] LuaEnv environment deactivated" -ForegroundColor Green
    Write-Host "[INFO] You may need to restart your shell to completely reset all environment variables" -ForegroundColor Cyan

    exit 0
}

# ==================================================================================
# CURRENT COMMAND HANDLER (PowerShell-specific)
# ==================================================================================
# The 'current' command displays information about the currently active Lua environment
if ($Command -eq "current") {
    # Display current command help if requested
    if ($Arguments -contains "--help" -or $Arguments -contains "-h") {
        Show-CurrentHelp
        exit 0
    }

    # Check for verbose flag
    $verbose = $Arguments -contains "--verbose" -or $Arguments -contains "-v"

    # Load the registry and use the backend module to display current environment
    $registry = Get-LuaEnvRegistry
    if (-not $registry) {
        exit 1
    }

    Show-CurrentEnvironment -Registry $registry -ShowVerbose:$verbose

    exit 0
}

# ==================================================================================
# LOCAL COMMAND HANDLER (PowerShell-specific)
# ==================================================================================
# The 'local' command is handled natively in PowerShell to manage the .lua-version file
# This command cannot be delegated to the CLI executable because it needs to
# interact with the local filesystem in the current working directory
if ($Command -eq "local") {
    # ------------------------------------------------------------------
    # Display local command help
    # ------------------------------------------------------------------
    if ($Arguments -contains "--help" -or $Arguments -contains "-h") {
        Show-LocalHelp
        exit 0
    }

    # Check if user wants to unset the local version
    if ($Arguments -contains "--unset" -or $Arguments -contains "-u") {
        $removed = Remove-LocalLuaVersion
        if ($removed) {
            Write-Host "[OK] Removed local version configuration" -ForegroundColor Green
        } else {
            Write-Host "[INFO] No local version was configured" -ForegroundColor Cyan
        }
        exit 0
    }

    # Check if the local version should be displayed (no arguments)
    if ($Arguments.Count -eq 0) {
        $localVersion = Get-LocalLuaVersion
        if ($localVersion) {
            Write-Host "Local version set to: $localVersion" -ForegroundColor Green

            # Load registry to validate if the version exists
            $registry = Get-LuaEnvRegistry
            if ($registry) {
                # Use the shared Find-Installation function to validate the version
                $installation = Find-Installation -registry $registry -id $localVersion -alias $localVersion
                if ($installation) {
                    Write-Host "[OK] $($installation.name) ($($installation.lua_version), $($installation.luarocks_version))" -ForegroundColor Green
                } else {
                    Write-Host "[WARNING] This version is not currently installed in the registry" -ForegroundColor Yellow
                    Write-Host "[INFO] Use 'luaenv list' to see available versions" -ForegroundColor Yellow
                }
            }
        } else {
            Write-Host "No local version configured for this directory" -ForegroundColor Yellow
            Write-Host "[INFO] Use 'luaenv local <alias|uuid>' to set a local version" -ForegroundColor Yellow
        }
        exit 0
    }

    # Set the local version (argument provided)
    $versionArg = $Arguments[0]

    # Load registry to validate the version
    $registry = Get-LuaEnvRegistry
    if (-not $registry) {
        exit 1
    }

    # Validate that the provided version exists using the shared Find-Installation function
    $installation = Find-Installation -registry $registry -id $versionArg -alias $versionArg

    if ($installation) {
        # Valid installation found, save to .lua-version file
        $success = Set-LocalLuaVersion -Version $versionArg
        if ($success) {
            Write-Host "[OK] Local version set to: $versionArg" -ForegroundColor Green
            Write-Host "[OK] $($installation.name) ($($installation.lua_version), $($installation.luarocks_version))" -ForegroundColor Green
            Write-Host "[INFO] Run 'luaenv activate' to use this version now" -ForegroundColor Cyan
        }
    } else {
        Write-Host "[ERROR] Installation not found: $versionArg" -ForegroundColor Red
        Write-Host "[INFO] Use 'luaenv list' to see available installations" -ForegroundColor Yellow
        exit 1
    }

    exit 0
}

# ==================================================================================
# CLI WRAPPER FUNCTIONALITY
# ==================================================================================
# All non-activate and non-local commands are delegated to the LuaEnv CLI executable
# This section handles the discovery and execution of the CLI with proper configuration

<#
.SYNOPSIS
    Invokes the LuaEnv CLI executable with the provided command and arguments.

.DESCRIPTION
    This function serves as a wrapper for the LuaEnv CLI executable, handling:
    - Discovery of the CLI executable and backend configuration
    - Validation of required files and paths
    - Argument forwarding to the CLI application
    - Error handling for missing components

.NOTES
    The CLI executable handles all commands except 'activate' which must be
    processed natively in PowerShell to modify the current shell environment.
#>
function Invoke-LuaEnvCLI {
    # Determine CLI executable and configuration paths
    $BinDir = $ScriptRoot
    $BackendConfig = Join-Path $BinDir "backend.config"
    $CliExe = Join-Path $BinDir "cli\LuaEnv.CLI.exe"

    # Validate required files exist
    if (-not (Test-Path $BackendConfig)) {
        Write-Error "[ERROR] Backend configuration not found: $BackendConfig"
        exit 1
    }

    if (-not (Test-Path $CliExe)) {
        Write-Error "[ERROR] CLI executable not found: $CliExe"
        exit 1
    }

    # Build complete arguments array for CLI
    $allArgs = @()
    if ($Command) {
        $allArgs += $Command
    }
    $allArgs += $Arguments

    # Execute CLI with backend configuration and forward all arguments
    & $CliExe --config $BackendConfig $allArgs
}

# ==================================================================================
# MAIN ENTRY POINT
# ==================================================================================
# Delegate to the CLI wrapper for all non-activate commands
Invoke-LuaEnvCLI
