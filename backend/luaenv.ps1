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
$BinDir = $ScriptRoot        # Installatin directory (contains this script)
# $backendDir = $ScriptRoot    # Alias for clarity in legacy code

# Import the LuaEnv Visual Studio module for C/C++ development support
$moduleScript = Join-Path $ScriptRoot "luaenv_vs.psm1"
if (Test-Path $moduleScript) {
    try {
        Import-Module $moduleScript -Force
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
# SHARED HELPER FUNCTIONS (used by multiple commands)
# ==================================================================================

<#
.SYNOPSIS
    Loads and parses the LuaEnv installation registry from the user's profile.

.DESCRIPTION
    The registry is a JSON file that tracks all installed Lua environments,
    their aliases, and configuration details. This function handles loading
    and parsing the registry with proper error handling.

.OUTPUTS
    PSObject containing the parsed registry data, or $null if loading fails
#>
function Get-LuaEnvRegistry {
    # Load registry file from user's profile directory
    $registryPath = Join-Path $env:USERPROFILE ".luaenv\registry.json"

    # Check if registry file exists
    if (-not (Test-Path $registryPath)) {
        Write-Host "[ERROR] LuaEnv registry not found at: $registryPath" -ForegroundColor Red
        Write-Host "[INFO] Run 'luaenv install' to create your first installation" -ForegroundColor Yellow
        return $null
    }

    # Parse JSON registry with error handling
    try {
        $registryContent = Get-Content $registryPath -Raw | ConvertFrom-Json
        return $registryContent
    }
    catch {
        Write-Host "[ERROR] Failed to load registry: $_" -ForegroundColor Red
        return $null
    }
}

<#
.SYNOPSIS
    Reads the local .lua-version file from the specified directory.

.DESCRIPTION
    Reads and parses the .lua-version file which contains an alias or UUID
    specifying the Lua installation to be used in the current directory.
    The file should contain a single line with a valid alias or UUID.

.PARAMETER Directory
    The directory to check for .lua-version file (defaults to current directory)

.OUTPUTS
    String containing the version alias or UUID, or $null if file not found
#>
function Get-LocalLuaVersion {
    param(
        [string]$Directory = "."
    )

    $versionFile = Join-Path $Directory ".lua-version"
    if (Test-Path $versionFile) {
        try {
            # Read and trim the file content to get a clean version string
            $version = Get-Content $versionFile -Raw | ForEach-Object { $_.Trim() }
            if ([string]::IsNullOrWhiteSpace($version)) {
                Write-Host "[WARNING] .lua-version file exists but is empty" -ForegroundColor Yellow
                return $null
            }
            return $version
        }
        catch {
            Write-Host "[WARNING] Failed to read .lua-version file: $_" -ForegroundColor Yellow
            return $null
        }
    }
    return $null
}

<#
.SYNOPSIS
    Writes a version string to the local .lua-version file.

.DESCRIPTION
    Creates or overwrites the .lua-version file with the specified version alias or UUID.
    The file is created in the specified directory (defaults to current directory).

.PARAMETER Version
    The version alias or UUID to write to the file

.PARAMETER Directory
    The directory where the .lua-version file should be created (defaults to current directory)

.OUTPUTS
    Boolean indicating success or failure
#>
function Set-LocalLuaVersion {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Version,
        [string]$Directory = "."
    )

    try {
        $versionFile = Join-Path $Directory ".lua-version"
        # Write version to file without newline and with UTF-8 encoding
        $Version | Out-File $versionFile -NoNewline -Encoding utf8
        return $true
    }
    catch {
        Write-Host "[ERROR] Failed to write .lua-version file: $_" -ForegroundColor Red
        return $false
    }
}

<#
.SYNOPSIS
    Removes the local .lua-version file.

.DESCRIPTION
    Deletes the .lua-version file from the specified directory if it exists.

.PARAMETER Directory
    The directory containing the .lua-version file (defaults to current directory)

.OUTPUTS
    Boolean indicating whether the file was removed
#>
function Remove-LocalLuaVersion {
    param(
        [string]$Directory = "."
    )

    $versionFile = Join-Path $Directory ".lua-version"
    if (Test-Path $versionFile) {
        try {
            Remove-Item $versionFile -Force
            return $true
        }
        catch {
            Write-Host "[ERROR] Failed to remove .lua-version file: $_" -ForegroundColor Red
            return $false
        }
    }
    return $false  # File didn't exist
}

<#
.SYNOPSIS
    Finds a specific Lua installation by ID, alias, or local version.

.DESCRIPTION
    This function implements the installation lookup logic with the following priority:
    1. Search by alias name (if provided)
    2. Search by full or partial UUID (if provided)
    3. Search by local .lua-version file (if exists and usePriority is true)
    4. Use default installation (if no specific ID/alias given)

    Partial UUID matching requires minimum 8 characters and must be unambiguous.

.PARAMETER registry
    The loaded registry object containing installation data

.PARAMETER id
    Full or partial installation UUID to search for

.PARAMETER alias
    Installation alias name to search for

.PARAMETER localVersion
    Local version from .lua-version file

.PARAMETER usePriority
    Whether to apply search priority (local > default) or just search by ID/alias

.OUTPUTS
    PSObject containing installation details, or $null if not found
#>
function Find-Installation {
    param(
        $registry,
        $id = "",
        $alias = "",
        $localVersion = "",
        [bool]$usePriority = $false
    )

    # Priority 1: Search by alias name
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

    # Priority 2: Search by installation UUID (full or partial)
    if ($id) {
        # Try exact UUID match first
        if ($registry.installations.PSObject.Properties.Name -contains $id) {
            return $registry.installations.$id
        }

        # Try partial UUID match (requires minimum 8 characters for safety)
        if ($id.Length -ge 8) {
            $matches_lv = @()
            foreach ($installationId in $registry.installations.PSObject.Properties.Name) {
                if ($installationId.StartsWith($id)) {
                    $matches_lv += $installationId
                }
            }

            # Return single unambiguous match
            if ($matches_lv.Count -eq 1) {
                return $registry.installations.($matches_lv[0])
            }
            # Report ambiguous matches
            elseif ($matches_lv.Count -gt 1) {
                Write-Host "[ERROR] Ambiguous partial ID '$id'. Matches:" -ForegroundColor Red
                foreach ($match in $matches_lv) {
                    Write-Host "  $match" -ForegroundColor Yellow
                }
                return $null
            }
        }

        Write-Host "[ERROR] Installation '$id' not found" -ForegroundColor Red
        return $null
    }

    # If using priority ordering and local version is provided
    if ($usePriority -and $localVersion) {
        # Try to find installation by local version (could be alias or UUID)

        # Check if local version is an alias
        if ($registry.aliases.PSObject.Properties.Name -contains $localVersion) {
            $installationId = $registry.aliases.$localVersion
            if ($registry.installations.PSObject.Properties.Name -contains $installationId) {
                return $registry.installations.$installationId
            }
        }

        # Check if local version is a UUID
        if ($registry.installations.PSObject.Properties.Name -contains $localVersion) {
            return $registry.installations.$localVersion
        }

        # Try partial UUID match for local version
        if ($localVersion.Length -ge 8) {
            $matches_lv = @()
            foreach ($installationId in $registry.installations.PSObject.Properties.Name) {
                if ($installationId.StartsWith($localVersion)) {
                    $matches_lv += $installationId
                }
            }

            if ($matches_lv.Count -eq 1) {
                return $registry.installations.($matches_lv[0])
            }
        }
    }

    # Priority 3: Use default installation when no specific ID/alias given
    if ($usePriority -and $registry.default_installation -and
        $registry.installations.PSObject.Properties.Name -contains $registry.default_installation) {
        return $registry.installations.($registry.default_installation)
    }

    # No matching installation found
    if ($usePriority) {
        Write-Host "[ERROR] No default installation set" -ForegroundColor Red
    }
    return $null
}

# ==================================================================================
# HELP COMMAND HANDLER
# ==================================================================================
# Display comprehensive help information for the LuaEnv tool
# This runs independently of the CLI executable to provide immediate help access
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
    Write-Host "  luaenv current                      # Show current active environment"
    Write-Host "  luaenv current --verbose            # Show detailed environment information"
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
    Write-Host "Note: 'activate' is a PowerShell-only command that modifies your current shell." -ForegroundColor Yellow
    Write-Host "      All other commands are handled by the LuaEnv CLI application." -ForegroundColor Yellow
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
    # ACTIVATION HELPER FUNCTIONS
    # ==================================================================
    # These functions handle the core activation logic including registry
    # management, installation lookup, and environment setup

    # The shared functions Get-LuaEnvRegistry and Find-Installation
    # are now defined at the script root level

    <#
    .SYNOPSIS
        Displays formatted information about all available Lua installations.

    .DESCRIPTION
        This function provides a user-friendly display of all installed Lua environments,
        including their status, aliases, versions, and usage information. It handles
        color-coded status indicators and time-based usage reporting.

    .PARAMETER registry
        The loaded registry object containing installation data
    #>
    function Show-Installations {
        param($registry)

        # Early exit if registry is null (error already handled by Get-LuaEnvRegistry)
        if (-not $registry) {
            return
        }

        # Convert registry installations to array for easier processing
        $installations = @()
        foreach ($key in $registry.installations.PSObject.Properties.Name) {
            $installations += $registry.installations.$key
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
            $defaultMark = if ($registry.default_installation -eq $installation.id) { " [DEFAULT]" } else { "" }
            $aliasList = ""

            # Collect all aliases for this installation
            $aliases = @()
            foreach ($key in $registry.aliases.PSObject.Properties.Name) {
                if ($registry.aliases.$key -eq $installation.id) {
                    $aliases += $key
                }
            }

            if ($aliases.Count -gt 0) {
                $aliasList = " (alias: $($aliases -join ", "))"
            }

            # Color-code installation status
            $status = $installation.status.ToUpper()
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

    <#
    .SYNOPSIS
        Displays current Lua environment status and configuration.

    .DESCRIPTION
        Shows the currently active Lua installation along with environment variables
        and tests for the availability of lua and luarocks commands in the current PATH.
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
        Locates and initializes the Visual Studio Developer Shell environment.

    .DESCRIPTION
        This function implements a priority-based search for Visual Studio installations
        and configures the Developer Shell environment for C extension compilation.

        Search Priority:
        1. Custom path provided via --devshell parameter
        2. Saved path from .vspath.txt configuration
        3. Auto-detection using vswhere.exe
        4. Common VS installation paths (VS 2022, 2019)

        The function configures the shell environment with the appropriate compiler
        toolchain and build tools for the specified architecture.

    .PARAMETER Architecture
        Target architecture for the build environment (x86, x64, arm64)

    .PARAMETER CustomPath
        Custom Visual Studio Tools directory path

    .PARAMETER SavePathToConfig
        Whether to save the successfully located path to configuration

    .OUTPUTS
        Boolean indicating whether VS Developer Shell was successfully initialized
    #>

    <#
    .SYNOPSIS
        Locates and initializes the Visual Studio Developer Shell environment using the LuaEnv VS module.

    .DESCRIPTION
        This function uses the enhanced LuaEnv Visual Studio module for comprehensive Visual Studio
        detection and environment setup. It provides robust detection capabilities with fallback to
        legacy methods if the module is not available.

    .PARAMETER Architecture
        Target architecture for the build environment (x86, x64, arm64)

    .PARAMETER CustomPath
        Custom Visual Studio Tools directory path

    .PARAMETER SavePathToConfig
        Whether to save the successfully located path to configuration

    .OUTPUTS
        Boolean indicating whether VS Developer Shell was successfully initialized
    #>
    function Find-VisualStudioDeveloperShell {
        param(
            [string]$Architecture = "x64",
            [string]$CustomPath = "",        # Custom VS Tools path
            [switch]$SavePathToConfig = $false  # Only save when explicitly provided via --devshell
        )

        # Use the enhanced LuaEnv VS module if available
        if ($script:UseLuaEnvVsModule) {
            Write-Host "[INFO] Using enhanced Visual Studio detection module..." -ForegroundColor Yellow

            try {
                # Initialize Visual Studio environment using the module
                $vsResult = Initialize-VisualStudioEnvironment -Architecture $Architecture -CustomPath $CustomPath -SaveConfig:$SavePathToConfig -ImportEnvironment:$true -Verbose:$VerbosePreference

                if ($vsResult.Success) {
                    Write-Host "[SUCCESS] $($vsResult.Message)" -ForegroundColor Green
                    Write-Host "  -> Visual Studio installation: $($vsResult.Installation.DisplayName)" -ForegroundColor Gray
                    Write-Host "  -> Version: $($vsResult.Installation.Version)" -ForegroundColor Gray
                    Write-Host "  -> Architecture: $($vsResult.Architecture)" -ForegroundColor Gray
                    Write-Host "  -> Environment configured in current session" -ForegroundColor Gray
                    return $true
                } else {
                    Write-Host "[ERROR] $($vsResult.Message)" -ForegroundColor Red

                    # Show helpful error messages
                    Write-Host ""
                    Write-Host "To resolve this issue, try one of the following:" -ForegroundColor Cyan
                    Write-Host "1. Install Visual Studio with C++ build tools from: https://visualstudio.microsoft.com/downloads/" -ForegroundColor White
                    Write-Host "2. Install Build Tools for Visual Studio from: https://visualstudio.microsoft.com/downloads/#build-tools-for-visual-studio-2022" -ForegroundColor White
                    Write-Host "3. Specify your VS installation path: luaenv activate --devshell <path-to-vs-tools>" -ForegroundColor White
                    Write-Host "4. Run 'luaenv activate --vs-diagnostic' to see detailed search information" -ForegroundColor White
                    Write-Host ""
                    Write-Host "Common VS Tools locations:" -ForegroundColor Gray
                    Write-Host "  - C:\Program Files\Microsoft Visual Studio\2022\Community\Common7\Tools" -ForegroundColor Gray
                    Write-Host "  - C:\Program Files (x86)\Microsoft Visual Studio\2019\BuildTools\Common7\Tools" -ForegroundColor Gray
                    Write-Host ""
                    Write-Host "[INFO] Supported editions: Community, Professional, Enterprise, BuildTools, Preview" -ForegroundColor Yellow
                    return $false
                }
            }
            catch {
                Write-Host "[ERROR] Module-based Visual Studio detection failed: $($_.Exception.Message)" -ForegroundColor Red
                Write-Host "[ERROR] Please ensure the luaenv_vs.psm1 module is properly installed and configured." -ForegroundColor Red
                return $false
            }
        } else {
            # Module not available - show error with guidance
            Write-Host "[ERROR] LuaEnv Visual Studio module (luaenv_vs.psm1) not available" -ForegroundColor Red
            Write-Host "[ERROR] Visual Studio environment cannot be configured without the module" -ForegroundColor Red
            Write-Host ""
            Write-Host "To resolve this issue:" -ForegroundColor Cyan
            Write-Host "1. Ensure luaenv_vs.psm1 is in the same directory as this script" -ForegroundColor White
            Write-Host "2. Check that the module file is not corrupted" -ForegroundColor White
            Write-Host "3. Verify PowerShell execution policy allows module loading" -ForegroundColor White
            Write-Host ""
            Write-Host "Module path: $(Join-Path $ScriptRoot 'luaenv_vs.psm1')" -ForegroundColor Gray
            return $false
        }
    }





    <#
    .SYNOPSIS
        Configures the complete Lua environment for the current PowerShell session.

    .DESCRIPTION
        This is the main environment setup function that:
        1. Validates the installation integrity
        2. Sets up Visual Studio Developer Shell for C compilation
        3. Configures PATH with Lua and LuaRocks binaries
        4. Sets up Lua module search paths (LUA_PATH, LUA_CPATH)
        5. Creates and configures LuaRocks with isolated package trees
        6. Ensures proper environment variable isolation

        The function implements smart PATH management to preserve both VS Developer
        environment and original system paths while prioritizing Lua tools.

    .PARAMETER installation
        The installation object containing paths and configuration details

    .PARAMETER customTree
        Optional custom LuaRocks tree path (overrides default environment path)

    .PARAMETER customDevShell
        Optional custom Visual Studio tools path for C compilation

    .OUTPUTS
        Boolean indicating successful environment setup
    #>
    function Setup-LuaEnv {
        param($installation, $customTree, $customDevShell)

        # Extract installation paths and configuration
        $installPath = $installation.installation_path
        $envPath = $installation.environment_path

        # Determine target architecture (default to x64 if not specified)
        $architecture = if ($installation.architecture) { $installation.architecture } else { "x64" }

        # ------------------------------------------------------------------
        # Validate installation integrity
        # ------------------------------------------------------------------
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

        # ------------------------------------------------------------------
        # Early vcpkg detection (before Visual Studio setup)
        # ------------------------------------------------------------------
        # Detect vcpkg BEFORE Visual Studio setup to ensure system/global vcpkg
        # is found rather than VS-internal vcpkg installations
        $vcpkgBin = $null
        $vcpkgRoot = $null
        $vcpkgArchitecture = "x64-windows"  # Default architecture

        if ($script:UseLuaEnvVsModule) {
            Write-Host "[INFO] Detecting vcpkg installation..." -ForegroundColor Yellow

            try {
                # Determine vcpkg architecture based on requested architecture
                switch ($architecture.ToLower()) {
                    "x86" { $vcpkgArchitecture = "x86-windows" }
                    "x64" { $vcpkgArchitecture = "x64-windows" }
                    "amd64" { $vcpkgArchitecture = "x64-windows" }
                    "arm" { $vcpkgArchitecture = "arm-windows" }
                    "arm64" { $vcpkgArchitecture = "arm64-windows" }
                    default { $vcpkgArchitecture = "x64-windows" }
                }

                # Use the module to detect vcpkg (prioritizes system/global installations)
                $vcpkgResult = Find-VcpkgInstallation -Architecture $vcpkgArchitecture -Verbose:$VerbosePreference

                if ($vcpkgResult.Found) {
                    $vcpkgRoot = $vcpkgResult.RootPath
                    $vcpkgBin = $vcpkgResult.BinPath
                    Write-Host "[SUCCESS] vcpkg detected at: $vcpkgRoot" -ForegroundColor Green
                    Write-Host "  -> Architecture: $($vcpkgResult.Triplet)" -ForegroundColor Gray
                    Write-Host "  -> Binary path: $vcpkgBin" -ForegroundColor Gray
                } else {
                    Write-Host "[INFO] vcpkg not found - C library dependencies may need manual configuration" -ForegroundColor Yellow
                }
            }
            catch {
                Write-Host "[WARNING] Module-based vcpkg detection failed: $($_.Exception.Message)" -ForegroundColor Yellow
                Write-Host "[INFO] vcpkg not available - C library dependencies may need manual configuration" -ForegroundColor Yellow
            }
        } else {
            Write-Host "[INFO] vcpkg detection skipped - luaenv_vs.psm1 module not available" -ForegroundColor Yellow
        }

        # ------------------------------------------------------------------
        # Setup Visual Studio Developer Shell for C compilation
        # ------------------------------------------------------------------
        # Save original system PATH before VS Developer Shell modifies it
        $originalSystemPath = $env:PATH

        # Save original PATH in an environment variable for deactivate command
        $env:LUAENV_ORIGINAL_PATH = $originalSystemPath

        # Initialize VS Developer Shell with correct architecture
        # Only save the VS path to config if a custom path was explicitly provided
        $savePathToConfig = $customDevShell -ne ""
        $vsFound = Find-VisualStudioDeveloperShell -Architecture $architecture -CustomPath $customDevShell -SavePathToConfig:$savePathToConfig

        # ------------------------------------------------------------------
        # Configure LuaRocks package tree
        # ------------------------------------------------------------------
        # Determine LuaRocks tree path (custom or default environment path)
        $luarocksTree = if ($customTree) {
            $customTree
        } else {
            $envPath
        }

        # Create LuaRocks tree directory if it doesn't exist
        if (-not (Test-Path $luarocksTree)) {
            New-Item -ItemType Directory -Path $luarocksTree -Force | Out-Null
            Write-Host "[INFO] Created LuaRocks tree: $luarocksTree" -ForegroundColor Gray
        }

        # ------------------------------------------------------------------
        # Configure environment variables
        # ------------------------------------------------------------------
        # Clear potentially conflicting LuaRocks environment variables
        $env:LUAROCKS_SYSCONFIG = $null
        $env:LUAROCKS_USERCONFIG = $null
        $env:LUAROCKS_PREFIX = $null

        # Set LuaEnv current installation identifier
        $env:LUAENV_CURRENT = $installation.id

        # ------------------------------------------------------------------
        # Configure PATH with smart merging
        # ------------------------------------------------------------------
        # Add Lua and LuaRocks to PATH
        $luaBinPath = Join-Path $installPath "bin"
        $luarocksBinPath = Join-Path $installPath "luarocks"
        $envBinPath = Join-Path $envPath "bin"

        # Create the environment bin directory if it doesn't exist
        if (-not (Test-Path $envBinPath)) {
            New-Item -ItemType Directory -Path $envBinPath -Force | Out-Null
        }




        # Extract VS-specific paths (added by VS Developer Shell) by comparing with original system PATH
        # This preserves both VS Developer tools and original system tools
        $currentPath = $env:PATH
        $vsPathEntries = @()
        foreach ($path in $currentPath.Split(';')) {
            if ($originalSystemPath.Split(';') -notcontains $path) {
                $vsPathEntries += $path
            }
        }

        # Clean up previous LuaEnv installation paths from original system PATH
        # This prevents accumulation of multiple LuaEnv paths when activating different environments
        $cleanedSystemPaths = @()
        foreach ($path in $originalSystemPath.Split(';')) {
            # Skip any paths that point to LuaEnv installations (but keep the base LuaEnv bin directory)
            if (-not ($path -like "*\.luaenv\installations\*\bin" -or
                      $path -like "*\.luaenv\installations\*\luarocks" -or
                      $path -like "*\.luaenv\environments\*\bin")) {
                $cleanedSystemPaths += $path
            }
        }
        $cleanedSystemPath = $cleanedSystemPaths -join ';'

        # Rebuild PATH with priority order: Lua bins -> VS paths -> vcpkg bin -> cleaned system paths
        # This ensures Lua tools take precedence while preserving all other functionality
        # Include vcpkg bin directory for runtime DLL access (SSL, etc.)

        $pathComponents = @($luaBinPath, $envBinPath, $luarocksBinPath)
        $pathComponents += $vsPathEntries
        if ($vcpkgBin -and (Test-Path $vcpkgBin)) {
            $pathComponents += $vcpkgBin
        }
        $pathComponents += $cleanedSystemPath.Split(';')
        $env:PATH = ($pathComponents | Where-Object { $_ -ne "" }) -join ';'

        # ------------------------------------------------------------------
        # Configure Lua module search paths
        # ------------------------------------------------------------------
        $luaLibPath = Join-Path $luarocksTree "lib\lua\5.4"
        $luaSharePath = Join-Path $luarocksTree "share\lua\5.4"
        $luarocksHome = Join-Path $luarocksTree "home"

        # Set LUA_PATH for Lua script modules (includes current directory and LuaRocks paths)
        $env:LUA_PATH = ".\?.lua;.\?\init.lua;$luaSharePath\?.lua;$luaSharePath\?\init.lua;;"

        # Set LUA_CPATH for compiled C modules (includes current directory and LuaRocks paths)
        $env:LUA_CPATH = ".\?.dll;$luaLibPath\?.dll;;"

        # ------------------------------------------------------------------
        # Create LuaRocks configuration file
        # ------------------------------------------------------------------
        $luarocksConfigDir = Join-Path $env:TEMP "luarocks-config"
        if (-not (Test-Path $luarocksConfigDir)) {
            New-Item -ItemType Directory -Path $luarocksConfigDir -Force | Out-Null
        }

        # Generate installation-specific LuaRocks configuration
        $luarocksConfigFile = Join-Path $luarocksConfigDir "$($installation.id)-config.lua"
        $luaIncDir = Join-Path $installPath "include"
        $luaLibDir = Join-Path $installPath "lib"

        # Save to path
        $env:LUA_BINDIR = $luaBinPath
        $env:LUA_INCDIR = $luaIncDir
        $env:LUA_LIBDIR = $luaLibDir
        $env:LUA_LIBRARIES = Join-Path $luaLibDir "lua54.lib"

        # Create LuaRocks configuration content with proper path escaping
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
home = "$($luarocksHome.Replace('\', '\\'))"
"@

        # ------------------------------------------------------------------
        # Configure LuaRocks vcpkg integration
        # ------------------------------------------------------------------
        $vcpkgExtraConfig = ""

        # If vcpkg is found, add configuration for common C libraries
        if ($vcpkgRoot) {
            $vcpkgInstalled = Join-Path $vcpkgRoot "installed\$vcpkgArchitecture"
            $vcpkgInclude = Join-Path $vcpkgInstalled "include"
            $vcpkgLib = Join-Path $vcpkgInstalled "lib"

            if ((Test-Path $vcpkgInclude) -and (Test-Path $vcpkgLib)) {
                Write-Host "    Found vcpkg installation: $vcpkgRoot" -ForegroundColor Green
                Write-Host "    Using architecture: $vcpkgArchitecture" -ForegroundColor Green

                # Add vcpkg paths to LuaRocks configuration using safe string concatenation
                # Ensure paths don't end with backslash to avoid escaping closing quotes
                $vcpkgIncludeEscaped = $vcpkgInclude.TrimEnd('\').Replace('\', '\\')
                $vcpkgLibEscaped = $vcpkgLib.TrimEnd('\').Replace('\', '\\')
                $vcpkgInstalledEscaped = $vcpkgInstalled.TrimEnd('\').Replace('\', '\\')

                # Build vcpkg configuration with completely safe Lua syntax
                $vcpkgExtraConfig = "`n`n-- vcpkg integration for C library dependencies`n"
                $vcpkgExtraConfig += "variables = {`n"
                $vcpkgExtraConfig += "    CPPFLAGS = `"/I\`"$vcpkgIncludeEscaped\`"`",`n"
                $vcpkgExtraConfig += "    LIBFLAG = `"/LIBPATH:\`"$vcpkgLibEscaped\`"`",`n"
                $vcpkgExtraConfig += "    LDFLAGS = `"/LIBPATH:\`"$vcpkgLibEscaped\`"`",`n"
                $vcpkgExtraConfig += "    HISTORY_DIR = `"$vcpkgInstalledEscaped`",`n"
                $vcpkgExtraConfig += "    HISTORY_INCDIR = `"$vcpkgIncludeEscaped`",`n"
                $vcpkgExtraConfig += "    HISTORY_LIBDIR = `"$vcpkgLibEscaped`"`n"
                $vcpkgExtraConfig += "}`n`n"
                $vcpkgExtraConfig += "-- Additional library search paths`n"
                $vcpkgExtraConfig += "external_deps_dirs = {`n"
                $vcpkgExtraConfig += "    `"$vcpkgInstalledEscaped`"`n"
                $vcpkgExtraConfig += "}`n"
            }
        } else {
            Write-Host "    vcpkg not found - C library dependencies may need manual configuration" -ForegroundColor Yellow
        }

        # Append vcpkg configuration to the main config
        $configContent += $vcpkgExtraConfig

        # Write configuration file with UTF-8 encoding (no BOM)
        $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
        [System.IO.File]::WriteAllText($luarocksConfigFile, $configContent, $utf8NoBom)

        # Set LuaRocks configuration environment variables
        $env:LUAROCKS_CONFIG = $luarocksConfigFile
        $env:LUAROCKS_SYSCONFDIR = $luarocksConfigDir

        return $true
    }

    # ==================================================================
    # MAIN ACTIVATION LOGIC
    # ==================================================================
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
                Write-Host "[ERROR] No local version or default installation found" -ForegroundColor Red
                Write-Host "[INFO] To set a local version: luaenv local <alias|uuid>" -ForegroundColor Yellow
                Write-Host "[INFO] Available installations:" -ForegroundColor Yellow
                Show-Installations $registry
                exit 1
            }
        }

        # Explicit arguments were provided - verify that an alias or ID was specified
        if (-not $Id -and -not $Alias) {
            Write-Host "[ERROR] No alias or ID specified" -ForegroundColor Red
            Write-Host "[INFO] Usage: luaenv activate <alias> or luaenv activate --id <uuid>" -ForegroundColor Yellow
            Write-Host "[INFO] Run 'luaenv activate --help' for more information" -ForegroundColor Yellow
            Show-Installations $registry
            exit 1
        }

        # Locate the specified installation
        $installation = Find-Installation $registry $Id $Alias
        if (-not $installation) {
            Write-Host "[ERROR] Could not find the specified Lua installation" -ForegroundColor Red
            Write-Host "[INFO] Available installations:" -ForegroundColor Yellow
            Show-Installations $registry
            exit 1
        }

        # Configure the Lua environment
        $success = Setup-LuaEnv $installation $Tree $DevShell
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
                  $_ -like "*\.luaenv\installations\*\luarocks")
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
    }    Write-Host "[OK] LuaEnv environment deactivated" -ForegroundColor Green
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
        exit 0
    }

    # Check for verbose flag
    $verbose = $Arguments -contains "--verbose" -or $Arguments -contains "-v"

    # Check if there's an active environment
    if (-not $env:LUAENV_CURRENT) {
        Write-Host "[INFO] No active LuaEnv environment" -ForegroundColor Yellow
        Write-Host "To activate an environment, use: luaenv activate <name>" -ForegroundColor Cyan
        exit 0
    }

    # Get registry to retrieve installation details
    $registry = Get-LuaEnvRegistry
    if (-not $registry) {
        Write-Host "[ERROR] Failed to load LuaEnv registry" -ForegroundColor Red
        exit 1
    }

    # Find the active installation in registry
    $currentId = $env:LUAENV_CURRENT
    $installation = $null
    if ($registry.installations.PSObject.Properties.Name -contains $currentId) {
        $installation = $registry.installations.$currentId
    }

    # Display current environment information
    Write-Host ""
    Write-Host "Currently active Lua environment:" -ForegroundColor Green

    if ($installation) {
        # Get aliases for this installation
        $aliases = @()
        foreach ($key in $registry.aliases.PSObject.Properties.Name) {
            if ($registry.aliases.$key -eq $currentId) {
                $aliases += $key
            }
        }

        $aliasList = if ($aliases.Count -gt 0) { " (aliases: $($aliases -join ", "))" } else { "" }
        $defaultMark = if ($registry.default_installation -eq $currentId) { " [DEFAULT]" } else { "" }

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
        if ($verbose) {
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
    }    # Set the local version (argument provided)
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
