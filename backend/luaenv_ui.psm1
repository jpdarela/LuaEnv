# This is free and unencumbered software released into the public domain.
# For more details, see the LICENSE file in the project root.

<#
.SYNOPSIS
    LuaEnv UI Module - Display and User Interface Functions

.DESCRIPTION
    This module provides display and user interface functions for LuaEnv including
    help text, installation listings, environment information, and formatted output.
    It handles all user-facing display logic and presentation.

.NOTES
    Author: LuaEnv Project
    License: Public Domain
    Version: 1.0.0
#>


# ==================================================================================
# Load global settings
# ==================================================================================

# Load global settings from global.psm1
$globalModulePath = Join-Path $PSScriptRoot "global.psm1"
if (Test-Path $globalModulePath) {
    Import-Module $globalModulePath -Force -ErrorAction Stop
} else {
    Write-Error "Global settings module not found: $globalModulePath"
}

$VerbosePreference = $VERBOSE_MESSAGES -eq "Continue" ? "Continue" : "SilentlyContinue"
$DebugPreference = $DEBUG_MESSAGES -eq "Continue" ? "Continue" : "SilentlyContinue"
$WarningPreference = $WARNING_MESSAGES -eq "Continue" ? "Continue" : "SilentlyContinue"

# ==================================================================================
# MODULE INITIALIZATION
# ==================================================================================

# Set strict mode for better error handling
Set-StrictMode -Version Latest

# ==================================================================================
# HELP DISPLAY FUNCTIONS
# ==================================================================================

<#
.SYNOPSIS
    Displays the main LuaEnv help information.

.DESCRIPTION
    Shows comprehensive help information for the LuaEnv tool including all available
    commands, their usage, and examples. This is the main entry point for help.
#>
function Show-LuaEnvHelp {
    Write-Host ""
    Write-Host "LuaEnv - Lua Environment Management Tool" -ForegroundColor Cyan
    Write-Host "======================================="
    Write-Host "USAGE:"
    Write-Host "  luaenv <command> [options]"
    Write-Host ""
    Write-Host "COMMANDS:"
    Write-Host ""
    Write-Host "  Environment Management (CLI):"
    Write-Host "    install [options]                  Install a new Lua environment"
    Write-Host "    uninstall <alias|uuid>             Remove a Lua installation"
    Write-Host "    list                               List all installed Lua environments"
    Write-Host "    status                             Show system status and registry information"
    Write-Host "    versions                           Show installed and available versions"
    Write-Host "    default <alias|uuid>               Set the default Lua installation"
    Write-Host "    pkg-config <alias|uuid>            Show pkg-config information for C developers"
    Write-Host "    config                             Show current configuration"
    Write-Host "    set-alias <uuid> <alias>           Set or update the alias of an installation"
    Write-Host "    remove-alias <alias|uuid> [alias]  Remove an alias from an installation"
    Write-Host "    help                               Show CLI help message"
    Write-Host ""
    Write-Host "  Shell Integration (PowerShell):"
    Write-Host "    activate [alias|options]        Activate a Lua environment in current shell"
    Write-Host "    deactivate                      Deactivate the current Lua environment"
    Write-Host "    current [options]               Show information about the active environment"
    Write-Host "    local [<alias|uuid>|--unset]    Set/show/unset local version in current directory"
    Write-Host ""
    Write-Host "  Auxiliary tools:"
    Write-Host "    luaconfig [options]             Pkg-config-like tool for Lua development"
    Write-Host ""
    Write-Host "For command-specific help:"
    Write-Host "  luaenv <command> --help"
    Write-Host ""
    Write-Host "EXAMPLES:"
    Write-Host "  luaenv install --alias dev           # Install Lua with alias 'dev'"
    Write-Host "  luaenv activate dev                  # Activate 'dev' environment (shorthand)"
    Write-Host "  luaenv activate                      # Activate using .lua-version or default"
    Write-Host "  luaenv current                       # Show current active environment"
    Write-Host "  luaenv current --verbose             # Show detailed environment information"
    Write-Host "  luaenv local dev                     # Set local version to 'dev' in current directory"
    Write-Host "  luaenv local                         # Display current local version"
    Write-Host "  luaenv local --unset                 # Remove local version"
    Write-Host "  luaenv default dev                   # Set 'dev' installation as global default"
    Write-Host "  luaenv list                          # Show all installations"
    Write-Host "  luaenv activate --list               # List available environments"
    Write-Host "  luaenv set-alias 1234abcd prod       # Set alias 'prod' for installation "
    Write-Host "                                         with UUID 1234abcd (matches first 8 chars)"
    Write-Host "  luaenv remove-alias dev              # Remove the 'dev' alias"
    Write-Host "  luaenv remove-alias 1234abcd prod    # Remove alias 'prod' from installation with UUID 1234abcd"
    Write-Host ""
}

<#
.SYNOPSIS
    Displays help information for the activate command.

.DESCRIPTION
    Shows detailed help for the activate command including options, version resolution,
    and usage examples.
#>
function Show-ActivateHelp {
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
    Write-Host "  --tree <path>      Set custom LuaRocks tree path - Deprecated- old functionality, not tested in a while"
    Write-Host "  --devshell <path>  Use custom Visual Studio install path. Saves it to .vspath.txt config file."
    Write-Host "  --help, -h         Show this help information"
    Write-Host ""
    Write-Host "Version Resolution:"
    Write-Host "  With no arguments, activate will check in this order:"
    Write-Host "  1. .lua-version file in current directory (set with 'luaenv local')"
    Write-Host "  2. Default installation from registry (set with 'luaenv default')"
    Write-Host ""
    Write-Host "Examples:"
    Write-Host "  luaenv activate              # Use local version or default installation"
    Write-Host "  luaenv activate dev          # Shorthand to activate installation with alias 'dev'"
    Write-Host "  luaenv activate --alias dev  # Same as above, with explicit flag"
    Write-Host "  luaenv activate --list       # List all available installations"
    Write-Host ""
}

<#
.SYNOPSIS
    Displays help information for the deactivate command.

.DESCRIPTION
    Shows detailed help for the deactivate command including options and usage examples.
#>
function Show-DeactivateHelp {
    Write-Host ""
    Write-Host "Usage: luaenv deactivate [options]"
    Write-Host ""
    Write-Host "Deactivate the current Lua environment in this PowerShell session."
    Write-Host "This command restores your original environment variables."
    Write-Host ""
    Write-Host "Options:"
    Write-Host "  --help, -h         Show this help information"
    Write-Host ""
    Write-Host "Example:"
    Write-Host "  luaenv deactivate  # Restore original shell environment"
    Write-Host ""
}

<#
.SYNOPSIS
    Displays help information for the current command.

.DESCRIPTION
    Shows detailed help for the current command including options and usage examples.
#>
function Show-CurrentHelp {
    Write-Host ""
    Write-Host "Usage: luaenv current [options]"
    Write-Host ""
    Write-Host "Display information about the currently active Lua environment."
    Write-Host ""
    Write-Host "Options:"
    Write-Host "  --verbose, -v      Show detailed environment information"
    Write-Host "  --help, -h         Show this help information"
    Write-Host ""
    Write-Host "Example:"
    Write-Host "  luaenv current     # Show current active environment"
    Write-Host "  luaenv current -v  # Show detailed information"
    Write-Host ""
}

<#
.SYNOPSIS
    Displays help information for the local command.

.DESCRIPTION
    Shows detailed help for the local command including options and usage examples.
#>
function Show-LocalHelp {
    Write-Host ""
    Write-Host "Usage: luaenv local [<alias|uuid>]"
    Write-Host ""
    Write-Host "Set or show the local Lua version in the current directory."
    Write-Host "This command creates or modifies the .lua-version file in the current directory."
    Write-Host ""
    Write-Host "Arguments:"
    Write-Host "  <alias|uuid>       The Lua installation alias or UUID to use locally"
    Write-Host "                     If omitted, shows the current local version (if any)"
    Write-Host ""
    Write-Host "Options:"
    Write-Host "  --unset, -u        Remove the local version file"
    Write-Host "  --help, -h         Show this help information"
    Write-Host ""
    Write-Host "Examples:"
    Write-Host "  luaenv local dev            # Set local version to the 'dev' installation"
    Write-Host "  luaenv local 1234abcd       # Set local version using UUID (or partial UUID)"
    Write-Host "  luaenv local                # Show current local version"
    Write-Host "  luaenv local --unset        # Remove the local version"
    Write-Host ""
}

# ==================================================================================
# INSTALLATION DISPLAY FUNCTIONS
# ==================================================================================

<#
.SYNOPSIS
    Displays formatted information about all available Lua installations.

.DESCRIPTION
    This function provides a user-friendly display of all installed Lua environments,
    including their status, aliases, versions, and usage information. It handles
    color-coded status indicators and time-based usage reporting.

.PARAMETER Registry
    The loaded registry object containing installation data

.EXAMPLE
    Show-Installations -Registry $registry
    Displays all installations with their status, aliases, and details
#>
function Show-Installations {
    param(
        [Parameter(Mandatory = $true)]
        [object]$Registry
    )

    # Early exit if registry is null
    if (-not $Registry) {
        Write-Host "[ERROR] Registry is null or invalid" -ForegroundColor Red
        return
    }

    # Convert registry installations to array for easier processing
    $installations = @()
    if ($Registry.installations) {
        foreach ($key in $Registry.installations.PSObject.Properties.Name) {
            $installations += $Registry.installations.$key
        }
    }

    # Handle empty installation list
    if ($installations.Count -eq 0) {
        Write-Host "[INFO] No installations found" -ForegroundColor Yellow
        Write-Host "[INFO] Run 'luaenv install --alias my-lua' to create your first installation" -ForegroundColor Yellow
        return
    }

    Write-Host "[INFO] Available installations:" -ForegroundColor Green
    Write-Host ""

    # Display each installation with formatted information
    foreach ($installation in $installations) {
        # Determine default installation marker
        $defaultMark = if ($Registry.default_installation -eq $installation.id) { " [DEFAULT]" } else { "" }
        $aliasList = ""

        # Collect all aliases for this installation
        $aliases = @()
        if ($Registry.aliases) {
            foreach ($key in $Registry.aliases.PSObject.Properties.Name) {
                if ($Registry.aliases.$key -eq $installation.id) {
                    $aliases += $key
                }
            }
        }

        if ($aliases.Count -gt 0) {
            $aliasList = " (alias: $($aliases -join ", "))"
        }

        # Color-code installation status
        $status = if ($installation.status) { $installation.status.ToUpper() } else { "UNKNOWN" }
        $statusColor = switch ($status) {
            "ACTIVE" { "Green" }     # Ready for use
            "BUILDING" { "Yellow" }  # Currently being built
            "BROKEN" { "Red" }       # Installation has issues
            default { "Gray" }       # Unknown status
        }

        # Main installation info line
        Write-Host "  [$status]$defaultMark $($installation.name)$aliasList" -ForegroundColor $statusColor
        Write-Host "    ID: $($installation.id)" -ForegroundColor Gray
        Write-Host "    Lua: $($installation.lua_version), LuaRocks: $($installation.luarocks_version)" -ForegroundColor Gray
        Write-Host "    Build: $($installation.build_type.ToUpper()) $($installation.build_config)" -ForegroundColor Gray
        Write-Host "    Path: $($installation.installation_path)" -ForegroundColor Gray

        # Display last used information with relative time formatting
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
                # Silently ignore date parsing errors for malformed timestamps
            }
        }

        # Display package count if available
        if ($installation.packages -and $installation.packages.count -gt 0) {
            Write-Host "    Packages: $($installation.packages.count)" -ForegroundColor Gray
        }

        Write-Host ""
    }
}

# ==================================================================================
# ENVIRONMENT DISPLAY FUNCTIONS
# ==================================================================================

<#
.SYNOPSIS
    Displays current Lua environment status and configuration.

.DESCRIPTION
    Shows the currently active Lua installation along with environment variables
    and tests for the availability of lua and luarocks commands in the current PATH.

.EXAMPLE
    Show-EnvironmentInfo
    Displays current environment variables and executable availability
#>
function Show-EnvironmentInfo {
    Write-Host "[INFO] Current Environment Information:" -ForegroundColor Green
    Write-Host ""

    # Display active installation information
    if ($env:LUAENV_CURRENT) {
        Write-Host "  Active Installation: $env:LUAENV_CURRENT" -ForegroundColor Green
    } else {
        Write-Host "  No active installation" -ForegroundColor Yellow
    }

    # Display relevant environment variables
    if ($env:LUA_PATH) {
        Write-Host "  LUA_PATH: $env:LUA_PATH" -ForegroundColor Gray
    }

    if ($env:LUA_CPATH) {
        Write-Host "  LUA_CPATH: $env:LUA_CPATH" -ForegroundColor Gray
    }

    if ($env:LUAROCKS_CONFIG) {
        Write-Host "  LUAROCKS_CONFIG: $env:LUAROCKS_CONFIG" -ForegroundColor Gray
    }

    # Test actual availability of Lua and LuaRocks executables
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

<#
.SYNOPSIS
    Displays detailed information about the currently active environment.

.DESCRIPTION
    Shows comprehensive information about the active Lua installation including
    installation details, environment variables, and installed packages.

.PARAMETER Registry
    The loaded registry object containing installation data

.PARAMETER ShowVerbose
    Whether to show detailed information including environment variables and packages

.EXAMPLE
    Show-CurrentEnvironment -Registry $registry -ShowVerbose
    Displays detailed information about the current environment
#>
function Show-CurrentEnvironment {
    param(
        [Parameter(Mandatory = $true)]
        [object]$Registry,

        [Parameter(Mandatory = $false)]
        [bool]$ShowVerbose = $false
    )

    # Check if there's an active environment
    if (-not $env:LUAENV_CURRENT) {
        Write-Host "[INFO] No active LuaEnv environment" -ForegroundColor Yellow
        Write-Host "To activate an environment, use: luaenv activate <name>" -ForegroundColor Cyan
        return
    }

    # Find the active installation in registry
    $currentId = $env:LUAENV_CURRENT
    $installation = $null
    if ($Registry.installations -and $Registry.installations.PSObject.Properties.Name -contains $currentId) {
        $installation = $Registry.installations.$currentId
    }

    # Display current environment information
    Write-Host ""
    Write-Host "Currently active Lua environment:" -ForegroundColor Green

    if ($installation) {
        # Get aliases for this installation
        $aliases = @()
        if ($Registry.aliases) {
            foreach ($key in $Registry.aliases.PSObject.Properties.Name) {
                if ($Registry.aliases.$key -eq $currentId) {
                    $aliases += $key
                }
            }
        }

        $aliasList = if ($aliases.Count -gt 0) { " (aliases: $($aliases -join ", "))" } else { "" }
        $defaultMark = if ($Registry.default_installation -eq $currentId) { " [DEFAULT]" } else { "" }

        Write-Host "  $($installation.name)$aliasList$defaultMark" -ForegroundColor White
        Write-Host "  ID: $currentId" -ForegroundColor Gray
        Write-Host "  Lua: $($installation.lua_version), LuaRocks: $($installation.luarocks_version)" -ForegroundColor Gray
        Write-Host "  Path: $($installation.installation_path)" -ForegroundColor Gray

        # Check if Lua and LuaRocks are actually in PATH
        try {
            $luaVersion = & lua -v 2>&1
            Write-Host "  Lua executable: $luaVersion" -ForegroundColor Green
        } catch {
            Write-Host "  Lua executable: Not available in PATH" -ForegroundColor Red
        }

        try {
            $luarocksVersion = & luarocks --version 2>&1
            Write-Host "  LuaRocks executable: $luarocksVersion" -ForegroundColor Green
        } catch {
            Write-Host "  LuaRocks executable: Not available in PATH" -ForegroundColor Red
        }

        # Show additional details if verbose mode requested
        if ($ShowVerbose) {
            Write-Host ""
            Write-Host "Environment Variables:" -ForegroundColor Cyan
            Write-Host "  LUA_PATH: $env:LUA_PATH" -ForegroundColor Gray
            Write-Host "  LUA_CPATH: $env:LUA_CPATH" -ForegroundColor Gray
            if ($env:LUAROCKS_CONFIG) {
                Write-Host "  LUAROCKS_CONFIG: $env:LUAROCKS_CONFIG" -ForegroundColor Gray
            }
            if ($env:LUA_BINDIR) {
                Write-Host "  LUA_BINDIR: $env:LUA_BINDIR" -ForegroundColor Gray
            }
            if ($env:LUA_INCDIR) {
                Write-Host "  LUA_INCDIR: $env:LUA_INCDIR" -ForegroundColor Gray
            }
            if ($env:LUA_LIBDIR) {
                Write-Host "  LUA_LIBDIR: $env:LUA_LIBDIR" -ForegroundColor Gray
            }

            # Show installed packages if available
            if ($installation.packages -and $installation.packages.count -gt 0) {
                Write-Host ""
                Write-Host "Installed packages: $($installation.packages.count)" -ForegroundColor Cyan
                # Limit to top 10 packages to avoid overwhelming output
                $packageList = $installation.packages | Select-Object -First 10
                foreach ($pkg in $packageList) {
                    Write-Host "  $($pkg.name) $($pkg.version)" -ForegroundColor Gray
                }
                if ($installation.packages.count -gt 10) {
                    Write-Host "  ... and $($installation.packages.count - 10) more" -ForegroundColor Gray
                }
            }
        }
    } else {
        Write-Host "  ID: $currentId (not found in registry)" -ForegroundColor Yellow
        Write-Host "  This environment might have been uninstalled or the registry was modified." -ForegroundColor Yellow

        # Try to detect actual Lua version from PATH
        try {
            $luaVersion = & lua -v 2>&1
            Write-Host "  Lua: $luaVersion" -ForegroundColor Green
        } catch {
            Write-Host "  Lua: Not available in PATH" -ForegroundColor Red
        }
    }
}

<#
.SYNOPSIS
    Displays information about the local version configuration.

.DESCRIPTION
    Shows the current local version setting and validates it against the registry.

.PARAMETER LocalVersion
    The local version read from .lua-version file

.PARAMETER Registry
    The loaded registry object for validation

.EXAMPLE
    Show-LocalVersion -LocalVersion "dev" -Registry $registry
    Displays information about the local version and validates it
#>
function Show-LocalVersion {
    param(
        [Parameter(Mandatory = $true)]
        [string]$LocalVersion,

        [Parameter(Mandatory = $false)]
        [object]$Registry
    )

    Write-Host "Local version set to: $LocalVersion" -ForegroundColor Green

    # Validate against registry if provided
    if ($Registry) {
        # Import the Find-Installation function from luaenv_core if available
        if (Get-Command -Name "Find-Installation" -ErrorAction SilentlyContinue) {
            $installation = Find-Installation -Registry $Registry -Id $LocalVersion -Alias $LocalVersion
            if ($installation) {
                Write-Host "[OK] $($installation.name) ($($installation.lua_version), $($installation.luarocks_version))" -ForegroundColor Green
            } else {
                Write-Host "[WARNING] This version is not currently installed in the registry" -ForegroundColor Yellow
                Write-Host "[INFO] Use 'luaenv list' to see available versions" -ForegroundColor Yellow
            }
        } else {
            Write-Host "[INFO] Cannot validate version without core module" -ForegroundColor Yellow
        }
    }
}

# ==================================================================================
# MESSAGE DISPLAY FUNCTIONS
# ==================================================================================

<#
.SYNOPSIS
    Displays error messages with consistent formatting.

.DESCRIPTION
    Provides standardized error message display with proper color coding and formatting.

.PARAMETER Message
    The error message to display

.PARAMETER Details
    Optional additional details to display

.EXAMPLE
    Show-ErrorMessage -Message "Installation not found" -Details "Use 'luaenv list' to see available installations"
#>
function Show-ErrorMessage {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,

        [Parameter(Mandatory = $false)]
        [string]$Details
    )

    Write-Host "[ERROR] $Message" -ForegroundColor Red
    if ($Details) {
        Write-Host "[INFO] $Details" -ForegroundColor Yellow
    }
}

<#
.SYNOPSIS
    Displays success messages with consistent formatting.

.DESCRIPTION
    Provides standardized success message display with proper color coding and formatting.

.PARAMETER Message
    The success message to display

.PARAMETER Details
    Optional additional details to display

.EXAMPLE
    Show-SuccessMessage -Message "Environment activated" -Details "Run 'luaenv current' to see details"
#>
function Show-SuccessMessage {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,

        [Parameter(Mandatory = $false)]
        [string]$Details
    )

    Write-Host "[OK] $Message" -ForegroundColor Green
    if ($Details) {
        Write-Host "[INFO] $Details" -ForegroundColor Cyan
    }
}

<#
.SYNOPSIS
    Displays informational messages with consistent formatting.

.DESCRIPTION
    Provides standardized informational message display with proper color coding and formatting.

.PARAMETER Message
    The informational message to display

.PARAMETER Type
    The type of message (Info, Warning, etc.)

.EXAMPLE
    Show-InfoMessage -Message "No local version configured" -Type "Info"
#>
function Show-InfoMessage {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,

        [Parameter(Mandatory = $false)]
        [ValidateSet("Info", "Warning", "Tip")]
        [string]$Type = "Info"
    )

    $color = switch ($Type) {
        "Info" { "Cyan" }
        "Warning" { "Yellow" }
        "Tip" { "Green" }
        default { "White" }
    }

    $prefix = switch ($Type) {
        "Info" { "[INFO]" }
        "Warning" { "[WARNING]" }
        "Tip" { "[TIP]" }
        default { "[INFO]" }
    }

    Write-Host "$prefix $Message" -ForegroundColor $color
}

# ==================================================================================
# MODULE EXPORTS
# ==================================================================================

# Export all public functions
Export-ModuleMember -Function @(
    # Help functions
    'Show-LuaEnvHelp',
    'Show-ActivateHelp',
    'Show-DeactivateHelp',
    'Show-CurrentHelp',
    'Show-LocalHelp',

    # Installation display functions
    'Show-Installations',

    # Environment display functions
    'Show-EnvironmentInfo',
    'Show-CurrentEnvironment',
    'Show-LocalVersion',

    # Message display functions
    'Show-ErrorMessage',
    'Show-SuccessMessage',
    'Show-InfoMessage'
)
