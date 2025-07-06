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
# PSScriptRoot points to the installation [%USERPROFILE%\.luaenv\bin] directory containing this script
$PSScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Definition
$BinDir = $PSScriptRoot        # Installatin directory (contains this script)
$backendDir = $PSScriptRoot    # Alias for clarity in legacy code

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
            $matches = @()
            foreach ($installationId in $registry.installations.PSObject.Properties.Name) {
                if ($installationId.StartsWith($id)) {
                    $matches += $installationId
                }
            }

            # Return single unambiguous match
            if ($matches.Count -eq 1) {
                return $registry.installations.($matches[0])
            }
            # Report ambiguous matches
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
            $matches = @()
            foreach ($installationId in $registry.installations.PSObject.Properties.Name) {
                if ($installationId.StartsWith($localVersion)) {
                    $matches += $installationId
                }
            }

            if ($matches.Count -eq 1) {
                return $registry.installations.($matches[0])
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
    Write-Host "    activate [alias|options]      Activate a Lua environment in current shell"
    Write-Host "    local [<alias|uuid>|--unset]  Set/show/unset local version in current directory"
    Write-Host ""
    Write-Host "For command-specific help:"
    Write-Host "  luaenv <command> --help"
    Write-Host ""
    Write-Host "EXAMPLES:"
    Write-Host "  luaenv install --alias dev           # Install Lua with alias 'dev'"
    Write-Host "  luaenv activate dev                  # Activate 'dev' environment (shorthand)"
    Write-Host "  luaenv activate                      # Activate using .lua-version or default"
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
        Retrieves the saved Visual Studio installation path from configuration.

    .DESCRIPTION
        Reads the Visual Studio tools path from the .vspath.txt config file.
        This path is used to locate and initialize the VS Developer Shell for
        C extension compilation support.

    .OUTPUTS
        String containing the VS tools path, or $null if not found/invalid
    #>
    function Get-VsPathConfig {
        # Read VS tools path from config file
        $configPath = Join-Path $PSScriptRoot ".vspath.txt"

        if (Test-Path $configPath) {
            try {
                $path = Get-Content $configPath -Raw
                # Validate that the path exists and is not empty
                if ($path -and (Test-Path $path)) {
                    return $path
                }
            }
            catch {
                # Silently ignore file reading errors
            }
        }

        return $null
    }

    <#
    .SYNOPSIS
        Saves the Visual Studio installation path to the configuration file.

    .DESCRIPTION
        Persists the VS tools path to .vspath.txt for future use. This allows
        the system to remember a custom VS installation location across sessions.

    .PARAMETER VsPath
        The Visual Studio tools directory path to save

    .OUTPUTS
        Boolean indicating success or failure of the save operation
    #>
    function Set-VsPathConfig {
        param([string]$VsPath)

        # Write VS tools path to config file
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
    function Find-VisualStudioDeveloperShell {
        param(
            [string]$Architecture = "x64",
            [string]$CustomPath = "",        # Custom VS Tools path
            [switch]$SavePathToConfig = $false  # Only save when explicitly provided via --devshell
        )

        # Map architecture names to VS Developer Shell parameters
        $vsArch = if ($Architecture -eq "x86") { "x86" } else { "amd64" }

        # Priority 1: Try custom path if provided via --devshell
        if ($CustomPath) {
            $launchPath = Join-Path $CustomPath "Launch-VsDevShell.ps1"
            if (Test-Path $launchPath) {
                Write-Host "[INFO] Using custom VS Developer Shell: $launchPath"
                try {
                    # Initialize VS Developer Shell with specified architecture
                    & $launchPath -Arch $vsArch -SkipAutomaticLocation

                    # Save path for future use only if explicitly provided via --devshell
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

        # Priority 2: Try path from .vspath.txt config file
        $configPath = Get-VsPathConfig
        if ($configPath) {
            $launchPath = Join-Path $configPath "Launch-VsDevShell.ps1"
            if (Test-Path $launchPath) {
                Write-Host "[INFO] Using VS Developer Shell from config: $launchPath"
                try {
                    # Initialize VS Developer Shell from saved config
                    & $launchPath -Arch $vsArch -SkipAutomaticLocation
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

        # Priority 3: Auto-detect using vswhere.exe (Microsoft's official VS locator)
        $vswherePath = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
        if (Test-Path $vswherePath) {
            try {
                # Query for latest VS installation with C++ build tools
                $vsInstallPath = & $vswherePath -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
                if ($vsInstallPath) {
                    $launchPath = Join-Path $vsInstallPath "Common7\Tools\Launch-VsDevShell.ps1"
                    if (Test-Path $launchPath) {
                        # Initialize VS Developer Shell from auto-detected installation
                        & $launchPath -Arch $vsArch -SkipAutomaticLocation

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
                # Silently continue to next method if vswhere fails
            }
        }

        # Priority 4: Try common VS installation paths (fallback)
        $vsPaths = @(
            "${env:ProgramFiles}\Microsoft Visual Studio\2022\Enterprise\Common7\Tools\Launch-VsDevShell.ps1",
            "${env:ProgramFiles}\Microsoft Visual Studio\2022\Professional\Common7\Tools\Launch-VsDevShell.ps1",
            "${env:ProgramFiles}\Microsoft Visual Studio\2022\Community\Common7\Tools\Launch-VsDevShell.ps1",
            "${env:ProgramFiles(x86)}\Microsoft Visual Studio\2019\Enterprise\Common7\Tools\Launch-VsDevShell.ps1",
            "${env:ProgramFiles(x86)}\Microsoft Visual Studio\2019\Professional\Common7\Tools\Launch-VsDevShell.ps1",
            "${env:ProgramFiles(x86)}\Microsoft Visual Studio\2019\Community\Common7\Tools\Launch-VsDevShell.ps1"
        )

        # Try each common VS installation path
        foreach ($vsPath in $vsPaths) {
            if (Test-Path $vsPath) {
                Write-Host "[INFO] Using VS Developer Shell: $vsPath"
                try {
                    # Initialize VS Developer Shell from common installation path
                    & $vsPath -Arch $vsArch -SkipAutomaticLocation

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

        # All VS detection methods failed
        Write-Host "[WARNING] Visual Studio Developer Shell not found. C extension compilation may not work." -ForegroundColor Yellow
        Write-Host "[INFO] Install Visual Studio with C++ build tools for full functionality." -ForegroundColor Yellow
        Write-Host "[INFO] Or specify VS path with: --devshell <path>" -ForegroundColor Yellow
        return $false
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
    function Setup-LuaEnvironment {
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
        # Setup Visual Studio Developer Shell for C compilation
        # ------------------------------------------------------------------
        # Save original system PATH before VS Developer Shell modifies it
        $originalSystemPath = $env:PATH

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
            if (-not ($path -like "*\.luaenv\installations\*\bin" -or $path -like "*\.luaenv\installations\*\luarocks")) {
                $cleanedSystemPaths += $path
            }
        }
        $cleanedSystemPath = $cleanedSystemPaths -join ';'

        # Rebuild PATH with priority order: Lua bins -> VS paths -> cleaned system paths
        # This ensures Lua tools take precedence while preserving all other functionality
        $env:PATH = "$luaBinPath;$luarocksBinPath;" + ($vsPathEntries -join ';') + ";$cleanedSystemPath"

        # ------------------------------------------------------------------
        # Configure Lua module search paths
        # ------------------------------------------------------------------
        $luaLibPath = Join-Path $luarocksTree "lib\lua\5.4"
        $luaSharePath = Join-Path $luarocksTree "share\lua\5.4"

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
"@

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
                    $matches = @()
                    foreach ($installationId in $registry.installations.PSObject.Properties.Name) {
                        if ($installationId.StartsWith($localVersion)) {
                            $matches += $installationId
                        }
                    }
                    if ($matches.Count -eq 1) {
                        $installation = $registry.installations.($matches[0])
                    }
                }

                if ($installation) {
                    # Configure the environment with the local version
                    $success = Setup-LuaEnvironment $installation $Tree $DevShell
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
                $success = Setup-LuaEnvironment $installation $Tree $DevShell
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
        $success = Setup-LuaEnvironment $installation $Tree $DevShell
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
    $BinDir = $PSScriptRoot
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

