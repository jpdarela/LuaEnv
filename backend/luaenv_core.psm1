# This is free and unencumbered software released into the public domain.
# For more details, see the LICENSE file in the project root.

<#
.SYNOPSIS
    LuaEnv Core Module - Registry Reading and Environment Management

.DESCRIPTION
    This module provides core functionality for LuaEnv including registry reading,
    installation discovery, environment setup, and path management. It serves as the
    foundation for all LuaEnv operations. Registry creation and modification is handled
    by the Python backend (registry.py).

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

if ($VERBOSE_MESSAGES -eq "Continue") { $VerbosePreference = "Continue" } else { $VerbosePreference = "SilentlyContinue" }
if ($DEBUG_MESSAGES -eq "Continue") { $DebugPreference = "Continue" } else { $DebugPreference = "SilentlyContinue" }
if ($WARNING_MESSAGES -eq "Continue") { $WarningPreference = "Continue" } else { $WarningPreference = "SilentlyContinue" }


# ==================================================================================
# MODULE INITIALIZATION
# ==================================================================================

# Set strict mode for better error handling
Set-StrictMode -Version Latest

# Module-level variables
$script:RegistryCache = $null
$script:LastRegistryLoad = $null
$script:CacheTimeout = 300 # 5 minutes in seconds

# ==================================================================================
# REGISTRY MANAGEMENT FUNCTIONS
# ==================================================================================

<#
.SYNOPSIS
    Gets the LuaEnv registry with caching support.

.DESCRIPTION
    Loads the LuaEnv registry from the registry.json file with intelligent caching
    to improve performance. The registry contains information about all installed
    Lua environments, aliases, and configuration.

.PARAMETER Force
    Forces a reload of the registry, bypassing the cache.

.PARAMETER RegistryPath
    Custom path to the registry file. If not specified, uses the default location.

.EXAMPLE
    $registry = Get-LuaEnvRegistry
    Gets the cached registry or loads it from disk.

.EXAMPLE
    $registry = Get-LuaEnvRegistry -Force
    Forces a fresh load of the registry from disk.

.OUTPUTS
    PSCustomObject containing the registry data, or $null if loading fails.
#>
function Get-LuaEnvRegistry {
    param(
        [switch]$Force,
        [string]$RegistryPath
    )

    # Determine registry path
    if (-not $RegistryPath) {
        $luaenvHome = $env:USERPROFILE + "\.luaenv"
        $RegistryPath = Join-Path $luaenvHome "registry.json"
    }

    # Check if we can use cached registry
    if (-not $Force -and $script:RegistryCache -and $script:LastRegistryLoad) {
        $timeSinceLoad = (Get-Date) - $script:LastRegistryLoad
        if ($timeSinceLoad.TotalSeconds -lt $script:CacheTimeout) {
            Write-Verbose "Using cached registry (age: $([math]::Round($timeSinceLoad.TotalSeconds))s)"
            return $script:RegistryCache
        }
    }

    # Load registry from disk
    try {
        Write-Verbose "Loading registry from: $RegistryPath"

        if (-not (Test-Path $RegistryPath)) {
            Write-Warning "Registry file not found at: $RegistryPath"
            Write-Host "Please, use luaenv install to create your first Lua environment and start the registry."
            return $null
        }

        # Read and parse registry file
        $registryContent = Get-Content $RegistryPath -Raw -ErrorAction Stop
        $registry = $registryContent | ConvertFrom-Json -ErrorAction Stop

        # Validate registry structure
        if (-not $registry.PSObject.Properties.Name -contains 'installations') {
            Write-Error "Please, use luaenv install to create your first Lua environment and start the registry."
            return $null
        }

        if (-not $registry.PSObject.Properties.Name -contains 'aliases') {
            Write-Error "Please use luaenv install to create your first Lua environment and start the registry."
            return $null
        }

        # Update cache
        $script:RegistryCache = $registry
        $script:LastRegistryLoad = Get-Date

        $installationCount = 0
        if ($registry.installations -and $registry.installations.PSObject.Properties.Name) {
            $propertyNames = $registry.installations.PSObject.Properties.Name
            if ($propertyNames -is [Array]) {
                $installationCount = $propertyNames.Count
            } else {
                $installationCount = 1
            }
        }
        Write-Verbose "Registry loaded successfully with $installationCount installations"
        return $registry
    }
    catch {
        Write-Error "Failed to load registry: $($_.Exception.Message)"
        Write-Error "Please use luaenv install to create your first Lua environment and start the registry."
        return $null
    }
}

<#
.SYNOPSIS
    Clears the registry cache.

.DESCRIPTION
    Forces the next registry access to reload from disk by clearing the cache.
    Useful for testing or when the registry has been modified externally.

.EXAMPLE
    Clear-LuaEnvRegistryCache
    Clears the registry cache.
#>
function Clear-LuaEnvRegistryCache {
    $script:RegistryCache = $null
    $script:LastRegistryLoad = $null
    Write-Verbose "Registry cache cleared"
}

# ==================================================================================
# INSTALLATION DISCOVERY FUNCTIONS
# ==================================================================================

<#
.SYNOPSIS
    Finds a Lua installation by ID, alias, or using fallback logic.

.DESCRIPTION
    Searches for a Lua installation using multiple strategies:
    1. Direct ID match
    2. Alias resolution
    3. Partial UUID match
    4. Local .lua-version file
    5. Default installation fallback

.PARAMETER Registry
    The registry object to search in.

.PARAMETER Id
    Installation ID (UUID) to search for.

.PARAMETER Alias
    Installation alias to search for.

.PARAMETER UsePriority
    Enable priority-based fallback logic.

.PARAMETER LocalVersion
    Local version from .lua-version file.

.EXAMPLE
    $installation = Find-Installation -Registry $registry -Id "dev"
    Finds installation with ID or alias "dev".

.OUTPUTS
    PSCustomObject containing the installation details, or $null if not found.
#>
function Find-Installation {
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$Registry,
        [string]$Id,
        [string]$Alias,
        [switch]$UsePriority,
        [string]$LocalVersion
    )

    Write-Verbose "Searching for installation - ID: '$Id', Alias: '$Alias', LocalVersion: '$LocalVersion'"

    # Priority 1: Direct ID match
    if ($Id -and $Registry.installations.PSObject.Properties.Name -contains $Id) {
        Write-Verbose "Found installation by direct ID match: $Id"
        return $Registry.installations.$Id
    }

    # Priority 2: Alias resolution
    if ($Alias -and $Registry.aliases -and $Registry.aliases.PSObject.Properties.Name -contains $Alias) {
        $installationId = $Registry.aliases.$Alias
        if ($Registry.installations.PSObject.Properties.Name -contains $installationId) {
            Write-Verbose "Found installation by alias '$Alias' -> '$installationId'"
            return $Registry.installations.$installationId
        }
    }

    # Priority 3: Try ID as alias
    if ($Id -and $Registry.aliases -and $Registry.aliases.PSObject.Properties.Name -contains $Id) {
        $installationId = $Registry.aliases.$Id
        if ($Registry.installations.PSObject.Properties.Name -contains $installationId) {
            Write-Verbose "Found installation by ID used as alias '$Id' -> '$installationId'"
            return $Registry.installations.$installationId
        }
    }

    # Priority 4: Partial UUID match
    if ($Id -and $Id.Length -ge 8) {
        $matches_uuid = @()
        foreach ($installationId in $Registry.installations.PSObject.Properties.Name) {
            if ($installationId.StartsWith($Id)) {
                $matches_uuid += $installationId
            }
        }

        if ($matches_uuid.Count -eq 1) {
            Write-Verbose "Found installation by partial UUID match: $Id -> $($matches_uuid[0])"
            return $Registry.installations.($matches_uuid[0])
        }
        elseif ($matches_uuid.Count -gt 1) {
            Write-Warning "Multiple installations match partial UUID '$Id': $($matches_uuid -join ', ')"
        }
    }

    # Priority 5: Local version fallback (if using priority)
    if ($UsePriority -and $LocalVersion) {
        # Try local version as alias
        if ($Registry.aliases -and $Registry.aliases.PSObject.Properties.Name -contains $LocalVersion) {
            $installationId = $Registry.aliases.$LocalVersion
            if ($Registry.installations.PSObject.Properties.Name -contains $installationId) {
                Write-Verbose "Found installation by local version alias '$LocalVersion' -> '$installationId'"
                return $Registry.installations.$installationId
            }
        }

        # Try local version as direct ID
        if ($Registry.installations.PSObject.Properties.Name -contains $LocalVersion) {
            Write-Verbose "Found installation by local version ID: $LocalVersion"
            return $Registry.installations.$LocalVersion
        }

        # Try local version as partial UUID
        if ($LocalVersion.Length -ge 8) {
            $matches_uuid = @()
            foreach ($installationId in $Registry.installations.PSObject.Properties.Name) {
                if ($installationId.StartsWith($LocalVersion)) {
                    $matches_uuid += $installationId
                }
            }

            if ($matches_uuid.Count -eq 1) {
                Write-Verbose "Found installation by local version partial UUID: $LocalVersion -> $($matches_uuid[0])"
                return $Registry.installations.($matches_uuid[0])
            }
        }
    }

    # Priority 6: Default installation fallback (if using priority)
    if ($UsePriority -and $Registry.default_installation -and
        $Registry.installations.PSObject.Properties.Name -contains $Registry.default_installation) {
        Write-Verbose "Using default installation: $($Registry.default_installation)"
        return $Registry.installations.($Registry.default_installation)
    }

    Write-Verbose "No installation found matching criteria"
    return $null
}

<#
.SYNOPSIS
    Tests if a Lua installation is valid and accessible.

.DESCRIPTION
    Validates that a Lua installation has all required components and is properly configured.
    Checks for Lua executable, LuaRocks, and environment directory structure.

.PARAMETER Installation
    The installation object to test.

.PARAMETER CheckLuaRocks
    Also validate LuaRocks installation.

.EXAMPLE
    $isValid = Test-LuaInstallation -Installation $installation
    Tests if the installation is valid.

.OUTPUTS
    Boolean indicating if the installation is valid.
#>
function Test-LuaInstallation {
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$Installation,
        [switch]$CheckLuaRocks
    )

    try {
        # Check required properties
        $requiredProperties = @('id', 'lua_version', 'installation_path', 'environment_path')
        foreach ($prop in $requiredProperties) {
            if (-not $Installation.PSObject.Properties.Name -contains $prop -or -not $Installation.$prop) {
                Write-Verbose "Installation missing required property: $prop"
                return $false
            }
        }

        # Check if installation directory exists
        if (-not (Test-Path $Installation.installation_path)) {
            Write-Verbose "Installation directory does not exist: $($Installation.installation_path)"
            return $false
        }

        # Check for Lua executable
        $luaExe = Join-Path $Installation.installation_path "bin\lua.exe"
        if (-not (Test-Path $luaExe)) {
            Write-Verbose "Lua executable not found: $luaExe"
            return $false
        }

        # Check for LuaRocks if requested
        if ($CheckLuaRocks) {
            $luarocksExe = Join-Path $Installation.installation_path "luarocks\luarocks.exe"
            if (-not (Test-Path $luarocksExe)) {
                Write-Verbose "LuaRocks executable not found: $luarocksExe"
                return $false
            }
        }

        # Check environment directory
        if (-not (Test-Path $Installation.environment_path)) {
            Write-Verbose "Environment directory does not exist: $($Installation.environment_path)"
            return $false
        }

        Write-Verbose "Installation validation passed: $($Installation.id)"
        return $true
    }
    catch {
        Write-Verbose "Installation validation failed: $($_.Exception.Message)"
        return $false
    }
}

# ==================================================================================
# LOCAL VERSION MANAGEMENT FUNCTIONS
# ==================================================================================

<#
.SYNOPSIS
    Gets the local Lua version from .lua-version file.

.DESCRIPTION
    Reads the .lua-version file from the specified directory and returns the
    version alias or UUID contained within it.

.PARAMETER Directory
    Directory to check for .lua-version file. Defaults to current directory.

.EXAMPLE
    $version = Get-LocalLuaVersion
    Gets the local version from the current directory.

.OUTPUTS
    String containing the version alias or UUID, or $null if not found.
#>
function Get-LocalLuaVersion {
    param(
        [string]$Directory = "."
    )

    $versionFile = Join-Path $Directory ".lua-version"
    if (Test-Path $versionFile) {
        try {
            $version = Get-Content $versionFile -Raw -ErrorAction Stop | ForEach-Object { $_.Trim() }
            if ([string]::IsNullOrWhiteSpace($version)) {
                Write-Verbose ".lua-version file exists but is empty"
                return $null
            }
            Write-Verbose "Found local version: $version"
            return $version
        }
        catch {
            Write-Warning "Failed to read .lua-version file: $($_.Exception.Message)"
            return $null
        }
    }
    return $null
}

<#
.SYNOPSIS
    Sets the local Lua version in .lua-version file.

.DESCRIPTION
    Creates or updates the .lua-version file with the specified version alias or UUID.

.PARAMETER Version
    The version alias or UUID to set.

.PARAMETER Directory
    Directory where the .lua-version file should be created. Defaults to current directory.

.EXAMPLE
    Set-LocalLuaVersion -Version "dev"
    Sets the local version to "dev" in the current directory.

.OUTPUTS
    Boolean indicating success or failure.
#>
function Set-LocalLuaVersion {
    param(
        [Parameter(Mandatory)]
        [string]$Version,
        [string]$Directory = "."
    )

    try {
        $versionFile = Join-Path $Directory ".lua-version"
        $Version | Out-File $versionFile -NoNewline -Encoding utf8 -ErrorAction Stop
        Write-Verbose "Set local version to: $Version"
        return $true
    }
    catch {
        Write-Error "Failed to write .lua-version file: $($_.Exception.Message)"
        return $false
    }
}

<#
.SYNOPSIS
    Removes the local .lua-version file.

.DESCRIPTION
    Deletes the .lua-version file from the specified directory if it exists.

.PARAMETER Directory
    Directory containing the .lua-version file. Defaults to current directory.

.EXAMPLE
    Remove-LocalLuaVersion
    Removes the .lua-version file from the current directory.

.OUTPUTS
    Boolean indicating whether the file was removed.
#>
function Remove-LocalLuaVersion {
    param(
        [string]$Directory = "."
    )

    $versionFile = Join-Path $Directory ".lua-version"
    if (Test-Path $versionFile) {
        try {
            Remove-Item $versionFile -Force -ErrorAction Stop
            Write-Verbose "Removed .lua-version file"
            return $true
        }
        catch {
            Write-Error "Failed to remove .lua-version file: $($_.Exception.Message)"
            return $false
        }
    }
    return $false
}

# ==================================================================================
# ENVIRONMENT STATUS FUNCTIONS
# ==================================================================================

<#
.SYNOPSIS
    Gets the current LuaEnv environment status.

.DESCRIPTION
    Checks if a LuaEnv environment is currently active and returns status information.

.EXAMPLE
    $status = Get-LuaEnvStatus
    Gets the current environment status.

.OUTPUTS
    PSCustomObject containing environment status information.
#>
function Get-LuaEnvStatus {
    $status = [PSCustomObject]@{
        IsActive = $false
        CurrentId = $null
        CurrentAlias = $null
        OriginalPath = $null
        LuaVersion = $null
        LuaRocksVersion = $null
        HasLuaInPath = $false
        HasLuaRocksInPath = $false
    }

    # Check if LuaEnv is active
    if ($env:LUAENV_CURRENT) {
        $status.IsActive = $true
        $status.CurrentId = $env:LUAENV_CURRENT
        $status.OriginalPath = $env:LUAENV_ORIGINAL_PATH

        # Try to get alias for current installation
        try {
            $registry = Get-LuaEnvRegistry
            if ($registry -and $registry.aliases -and $registry.aliases.PSObject.Properties.Name) {
                foreach ($alias in $registry.aliases.PSObject.Properties.Name) {
                    if ($registry.aliases.$alias -eq $env:LUAENV_CURRENT) {
                        $status.CurrentAlias = $alias
                        break
                    }
                }
            }
        }
        catch {
            Write-Verbose "Failed to get registry for status check: $($_.Exception.Message)"
        }

        # Test Lua availability
        try {
            $luaVersion = & lua -v 2>&1
            $status.HasLuaInPath = $true
            $status.LuaVersion = $luaVersion
        }
        catch {
            $status.HasLuaInPath = $false
        }

        # Test LuaRocks availability
        try {
            $luarocksVersion = & luarocks --version 2>&1
            $status.HasLuaRocksInPath = $true
            $status.LuaRocksVersion = $luarocksVersion
        }
        catch {
            $status.HasLuaRocksInPath = $false
        }
    }

    return $status
}

<#
.SYNOPSIS
    Tests if a LuaEnv environment is currently active.

.DESCRIPTION
    Simple check to determine if any LuaEnv environment is active in the current session.

.EXAMPLE
    $isActive = Test-LuaEnvActive
    Tests if any environment is active.

.OUTPUTS
    Boolean indicating if an environment is active.
#>
function Test-LuaEnvActive {
    return $null -ne $env:LUAENV_CURRENT
}

# ==================================================================================
# ENVIRONMENT SETUP FUNCTIONS
# ==================================================================================

<#
.SYNOPSIS
    Initializes a complete Lua environment for the current PowerShell session.

.DESCRIPTION
    Main orchestrator function that sets up a Lua environment including:
    - Installation validation
    - vcpkg detection
    - Visual Studio Developer Shell setup
    - PATH configuration
    - Lua module search paths
    - LuaRocks configuration

.PARAMETER Installation
    The installation object containing paths and configuration details

.PARAMETER CustomTree
    Optional custom LuaRocks tree path (overrides default environment path)

.PARAMETER CustomDevShell
    Optional custom Visual Studio tools path for C compilation

.EXAMPLE
    Initialize-LuaEnvironment -Installation $installation
    Sets up the environment using default settings.

.OUTPUTS
    Boolean indicating successful environment setup
#>
function Initialize-LuaEnvironment {
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$Installation,
        [string]$CustomTree,
        [string]$CustomDevShell
    )

    Write-Verbose "Initializing Lua environment for installation: $($Installation.id)"

    try {
        # Step 1: Validate installation integrity
        if (-not (Test-LuaInstallation -Installation $Installation -CheckLuaRocks)) {
            Write-LuaEnvMessage "Installation validation failed" -Type Error
            return $false
        }

        # Step 2: Detect vcpkg (before Visual Studio setup)
        $vcpkgInfo = Find-VcpkgForEnvironment -Installation $Installation

        # Step 3: Setup Visual Studio environment
        $vsResult = Initialize-VisualStudioForLua -Installation $Installation -CustomDevShell $CustomDevShell
        if (-not $vsResult) {
            Write-LuaEnvMessage "Visual Studio environment setup failed" -Type Error
        }

        # Step 4: Configure LuaRocks tree
        $treeInfo = Initialize-LuaRocksTree -Installation $Installation -CustomTree $CustomTree

        # Step 5: Setup environment variables
        Set-LuaEnvironmentVariables -Installation $Installation

        # Step 6: Configure PATH
        $pathResult = Set-LuaEnvironmentPath -Installation $Installation -VcpkgInfo $vcpkgInfo -TreeInfo $treeInfo
        if (-not $pathResult) {
            Write-LuaEnvMessage "Failed to configure PATH" -Type Error
        }

        # Step 7: Configure Lua module search paths
        Set-LuaModulePaths -Installation $Installation -TreeInfo $treeInfo

        # Step 8: Create LuaRocks configuration
        $configResult = New-LuaRocksConfiguration -Installation $Installation -TreeInfo $treeInfo -VcpkgInfo $vcpkgInfo
        if (-not $configResult) {
            Write-LuaEnvMessage "Failed to create LuaRocks configuration" -Type Error
        }

        Write-LuaEnvMessage "Lua environment initialized successfully" -Type Success
        return $true
    }
    catch {
        Write-LuaEnvMessage "Failed to initialize Lua environment: $($_.Exception.Message)" -Type Error
        return $false
    }
}

<#
.SYNOPSIS
    Detects vcpkg installation for use with Lua environment.

.DESCRIPTION
    Detects vcpkg before Visual Studio setup to ensure system/global vcpkg
    is found rather than VS-internal vcpkg installations.

.PARAMETER Installation
    The Lua installation object

.OUTPUTS
    PSCustomObject containing vcpkg information or null if not found
#>
function Find-VcpkgForEnvironment {
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$Installation
    )

    # Determine target architecture
    $architecture = if ($Installation.architecture) { $Installation.architecture } else { "x64" }

    # Convert to vcpkg triplet format
    $vcpkgArchitecture = switch ($architecture.ToLower()) {
        "x86" { "x86-windows" }
        "x64" { "x64-windows" }
        "amd64" { "x64-windows" }
        "arm" { "arm-windows" }
        "arm64" { "arm64-windows" }
        default { "x64-windows" }
    }

    Write-LuaEnvMessage "Detecting vcpkg installation..." -Type Info
    Write-Verbose "Installation architecture: $architecture"
    Write-Verbose "vcpkg triplet: $vcpkgArchitecture"

    try {
        # Use the VS module if available for vcpkg detection
        if (Get-Command Find-VcpkgInstallation -ErrorAction SilentlyContinue) {
            # Pass the original architecture to the VS module, not the vcpkg triplet
            $vcpkgResult = Find-VcpkgInstallation -Architecture $architecture -Verbose:$VerbosePreference

            if ($vcpkgResult.Found) {
                Write-LuaEnvMessage "vcpkg detected at: $($vcpkgResult.RootPath)" -Type Success
                Write-Verbose "  -> Architecture: $($vcpkgResult.Triplet)"
                Write-Verbose "  -> Binary path: $($vcpkgResult.BinPath)"
                Write-Verbose "  -> Include path: $($vcpkgResult.IncludePath)"
                Write-Verbose "  -> Library path: $($vcpkgResult.LibPath)"
                Write-Verbose "  -> Installed path: $($vcpkgResult.InstalledPath)"

                return [PSCustomObject]@{
                    Found = $true
                    RootPath = $vcpkgResult.RootPath
                    BinPath = $vcpkgResult.BinPath
                    Architecture = $vcpkgResult.Triplet
                    IncludePath = $vcpkgResult.IncludePath
                    LibPath = $vcpkgResult.LibPath
                    InstalledPath = $vcpkgResult.InstalledPath
                }
            }
        }

        Write-LuaEnvMessage "vcpkg not found - C library dependencies may need manual configuration" -Type Info
        return $null
    }
    catch {
        Write-LuaEnvMessage "vcpkg detection failed: $($_.Exception.Message)" -Type Warning
        return $null
    }
}

<#
.SYNOPSIS
    Initializes Visual Studio development environment for Lua.

.DESCRIPTION
    Sets up Visual Studio Developer Shell and saves original PATH for restoration.

.PARAMETER Installation
    The Lua installation object

.PARAMETER CustomDevShell
    Optional custom Visual Studio tools path

.OUTPUTS
    PSCustomObject containing Visual Studio setup results
#>
function Initialize-VisualStudioForLua {
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$Installation,
        [string]$CustomDevShell
    )

    # Determine target architecture
    $architecture = if ($Installation.architecture) { $Installation.architecture } else { "x64" }

    # Save original system PATH before VS Developer Shell modifies it
    $originalSystemPath = $env:PATH
    $env:LUAENV_ORIGINAL_PATH = $originalSystemPath

    Write-LuaEnvMessage "Setting up Visual Studio environment..." -Type Info

    try {
        # Use VS module if available
        if (Get-Command Initialize-VisualStudioEnvironment -ErrorAction SilentlyContinue) {
            $savePathToConfig = $CustomDevShell -ne ""
            $vsResult = Initialize-VisualStudioEnvironment -Architecture $architecture -CustomPath $CustomDevShell -SaveConfig:$savePathToConfig -ImportEnvironment:$true

            return [PSCustomObject]@{
                Success = $vsResult.Success
                OriginalPath = $originalSystemPath
                Architecture = $architecture
                VSResult = $vsResult
            }
        }

        Write-LuaEnvMessage "Visual Studio module not available" -Type Warning
        return [PSCustomObject]@{
            Success = $false
            OriginalPath = $originalSystemPath
            Architecture = $architecture
        }
    }
    catch {
        Write-LuaEnvMessage "Visual Studio setup failed: $($_.Exception.Message)" -Type Error
        return [PSCustomObject]@{
            Success = $false
            OriginalPath = $originalSystemPath
            Architecture = $architecture
        }
    }
}

<#
.SYNOPSIS
    Initializes LuaRocks package tree directory.

.DESCRIPTION
    Sets up the LuaRocks tree directory for package installation.

.PARAMETER Installation
    The Lua installation object

.PARAMETER CustomTree
    Optional custom LuaRocks tree path

.OUTPUTS
    PSCustomObject containing tree information
#>
function Initialize-LuaRocksTree {
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$Installation,
        [string]$CustomTree
    )

    # Determine LuaRocks tree path (custom or default environment path)
    $luarocksTree = if ($CustomTree) {
        $CustomTree
    } else {
        $Installation.environment_path
    }

    # Create LuaRocks tree directory if it doesn't exist
    if (-not (Test-Path $luarocksTree)) {
        try {
            New-Item -ItemType Directory -Path $luarocksTree -Force | Out-Null
            Write-Verbose "Created LuaRocks tree: $luarocksTree"
        }
        catch {
            Write-LuaEnvMessage "Failed to create LuaRocks tree directory: $($_.Exception.Message)" -Type Error
            throw
        }
    }

    return [PSCustomObject]@{
        TreePath = $luarocksTree
        LibPath = Join-Path $luarocksTree "lib\lua\5.4"
        SharePath = Join-Path $luarocksTree "share\lua\5.4"
        HomePage = Join-Path $luarocksTree "home"
        CachePath = Join-Path $luarocksTree "cache"
    }
}

<#
.SYNOPSIS
    Sets up Lua environment variables.

.DESCRIPTION
    Configures basic Lua environment variables and clears conflicting ones.

.PARAMETER Installation
    The Lua installation object
#>
function Set-LuaEnvironmentVariables {
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$Installation
    )

    # Clear potentially conflicting LuaRocks environment variables
    $env:LUAROCKS_SYSCONFIG = $null
    $env:LUAROCKS_USERCONFIG = $null
    $env:LUAROCKS_PREFIX = $null

    # Set LuaEnv current installation identifier
    $env:LUAENV_CURRENT = $Installation.id

    # Set Lua directory environment variables
    $luaBinPath = Join-Path $Installation.installation_path "bin"
    $luaIncDir = Join-Path $Installation.installation_path "include"
    $luaLibDir = Join-Path $Installation.installation_path "lib"

    $env:LUA_BINDIR = $luaBinPath
    $env:LUA_INCDIR = $luaIncDir
    $env:LUA_INC = $luaIncDir
    $env:LUA_LIBDIR = $luaLibDir
    $env:LUA_LIB = $luaLibDir
    $env:LUA_LIBRARIES = Join-Path $luaLibDir "lua54.lib"

    Write-Verbose "Set Lua environment variables for installation: $($Installation.id)"
}

<#
.SYNOPSIS
    Configures the PATH environment variable for Lua.

.DESCRIPTION
    Sets up PATH with proper priority ordering while preserving VS and system paths.

.PARAMETER Installation
    The Lua installation object

.PARAMETER VcpkgInfo
    vcpkg information object

.PARAMETER TreeInfo
    LuaRocks tree information object

.OUTPUTS
    Boolean indicating success
#>
function Set-LuaEnvironmentPath {
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$Installation,
        [PSCustomObject]$VcpkgInfo,
        [Parameter(Mandatory)]
        [PSCustomObject]$TreeInfo
    )

    try {
        # Get current and original paths
        $currentPath = $env:PATH
        $originalSystemPath = $env:LUAENV_ORIGINAL_PATH

        # Build Lua-specific paths
        $luaBinPath = Join-Path $Installation.installation_path "bin"
        $luarocksBinPath = Join-Path $Installation.installation_path "luarocks"
        $envBinPath = Join-Path $Installation.environment_path "bin"

        # Create the environment bin directory if it doesn't exist
        if (-not (Test-Path $envBinPath)) {
            New-Item -ItemType Directory -Path $envBinPath -Force | Out-Null
        }

        # Extract VS-specific paths (added by VS Developer Shell)
        $vsPathEntries = Get-VisualStudioPathEntries -CurrentPath $currentPath -OriginalPath $originalSystemPath

        # Clean up previous LuaEnv paths from original system PATH
        $cleanedSystemPath = Remove-LuaEnvPathEntries -OriginalPath $originalSystemPath

        # Build new PATH with priority order: Lua bins -> VS paths -> vcpkg bin -> system paths
        $pathComponents = @($luaBinPath, $envBinPath, $luarocksBinPath)
        $pathComponents += $vsPathEntries

        if ($VcpkgInfo -and $VcpkgInfo.BinPath -and (Test-Path $VcpkgInfo.BinPath)) {
            $pathComponents += $VcpkgInfo.BinPath
        }

        $pathComponents += $cleanedSystemPath.Split(';')
        $env:PATH = ($pathComponents | Where-Object { $_ -ne "" }) -join ';'

        Write-Verbose "Configured PATH for Lua environment"
        return $true
    }
    catch {
        Write-LuaEnvMessage "Failed to configure PATH: $($_.Exception.Message)" -Type Error
        return $false
    }
}

<#
.SYNOPSIS
    Sets up Lua module search paths (LUA_PATH and LUA_CPATH).

.PARAMETER Installation
    The Lua installation object

.PARAMETER TreeInfo
    LuaRocks tree information object
#>
function Set-LuaModulePaths {
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$Installation,
        [Parameter(Mandatory)]
        [PSCustomObject]$TreeInfo
    )

    # Set LUA_PATH for Lua script modules
    $env:LUA_PATH = ".\?.lua;.\?\init.lua;$($TreeInfo.SharePath)\?.lua;$($TreeInfo.SharePath)\?\init.lua;;"

    # Set LUA_CPATH for compiled C modules
    $env:LUA_CPATH = ".\?.dll;$($TreeInfo.LibPath)\?.dll;;"

    Write-Verbose "Configured Lua module search paths"
}

<#
.SYNOPSIS
    Creates LuaRocks configuration file with vcpkg integration.

.PARAMETER Installation
    The Lua installation object

.PARAMETER TreeInfo
    LuaRocks tree information object

.PARAMETER VcpkgInfo
    vcpkg information object

.OUTPUTS
    Boolean indicating success
#>
function New-LuaRocksConfiguration {
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$Installation,
        [Parameter(Mandatory)]
        [PSCustomObject]$TreeInfo,
        [PSCustomObject]$VcpkgInfo
    )

    try {
        # Create config directory
        $luarocksConfigDir = Join-Path $env:TEMP "luarocks-config"
        if (-not (Test-Path $luarocksConfigDir)) {
            New-Item -ItemType Directory -Path $luarocksConfigDir -Force | Out-Null
        }

        # Generate configuration content
        $configContent = New-LuaRocksConfigContent -Installation $Installation -TreeInfo $TreeInfo -VcpkgInfo $VcpkgInfo

        # Write configuration file
        $luarocksConfigFile = Join-Path $luarocksConfigDir "$($Installation.id)-config.lua"
        $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
        [System.IO.File]::WriteAllText($luarocksConfigFile, $configContent, $utf8NoBom)

        # Set LuaRocks configuration environment variables
        $env:LUAROCKS_CONFIG = $luarocksConfigFile
        $env:LUAROCKS_SYSCONFDIR = $luarocksConfigDir

        Write-Verbose "Created LuaRocks configuration: $luarocksConfigFile"
        return $true
    }
    catch {
        Write-LuaEnvMessage "Failed to create LuaRocks configuration: $($_.Exception.Message)" -Type Error
        return $false
    }
}

# ==================================================================================
# PATH MANAGEMENT HELPER FUNCTIONS
# ==================================================================================

<#
.SYNOPSIS
    Extracts Visual Studio-specific PATH entries.

.PARAMETER CurrentPath
    Current PATH environment variable

.PARAMETER OriginalPath
    Original PATH before VS setup

.OUTPUTS
    Array of VS-specific path entries
#>
function Get-VisualStudioPathEntries {
    param(
        [Parameter(Mandatory)]
        [string]$CurrentPath,
        [Parameter(Mandatory)]
        [string]$OriginalPath
    )

    $vsPathEntries = @()
    foreach ($path in $CurrentPath.Split(';')) {
        if ($OriginalPath.Split(';') -notcontains $path) {
            $vsPathEntries += $path
        }
    }
    return $vsPathEntries
}

<#
.SYNOPSIS
    Removes LuaEnv-specific paths from the original system PATH.

.PARAMETER OriginalPath
    Original system PATH

.OUTPUTS
    Cleaned system PATH string
#>
function Remove-LuaEnvPathEntries {
    param(
        [Parameter(Mandatory)]
        [string]$OriginalPath
    )

    $cleanedSystemPaths = @()
    foreach ($path in $OriginalPath.Split(';')) {
        # Skip any paths that point to LuaEnv installations
        if (-not ($path -like "*\.luaenv\installations\*\bin" -or
                  $path -like "*\.luaenv\installations\*\luarocks" -or
                  $path -like "*\.luaenv\environments\*\bin")) {
            $cleanedSystemPaths += $path
        }
    }
    return $cleanedSystemPaths -join ';'
}

<#
.SYNOPSIS
    Generates LuaRocks configuration content.

.PARAMETER Installation
    The Lua installation object

.PARAMETER TreeInfo
    LuaRocks tree information

.PARAMETER VcpkgInfo
    vcpkg information object

.OUTPUTS
    String containing the complete LuaRocks configuration
#>
function New-LuaRocksConfigContent {
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$Installation,
        [Parameter(Mandatory)]
        [PSCustomObject]$TreeInfo,
        [PSCustomObject]$VcpkgInfo
    )

    $luaExe = Join-Path $Installation.installation_path "bin\lua.exe"
    $luaIncDir = Join-Path $Installation.installation_path "include"
    $luaLibDir = Join-Path $Installation.installation_path "lib"
    $luaBinPath = Join-Path $Installation.installation_path "bin"

    # Base configuration
    $configContent = @"
-- LuaRocks configuration for LuaEnv installation: $($Installation.id)
rocks_trees = {
    { name = "user", root = "$($TreeInfo.TreePath.Replace('\', '\\'))" }
}
lua_interpreter = "$($luaExe.Replace('\', '\\'))"
lua_version = "5.4"
lua_incdir = "$($luaIncDir.Replace('\', '\\'))"
lua_libdir = "$($luaLibDir.Replace('\', '\\'))"
lua_bindir = "$($luaBinPath.Replace('\', '\\'))"
lua_lib = "lua54.lib"

-- Environment isolation settings
local_cache = "$($TreeInfo.CachePath.Replace('\', '\\'))"
home_tree = ""
local_by_default = true
home = "$($TreeInfo.HomePage.Replace('\', '\\'))"

"@

    # Add vcpkg integration if available
    if ($VcpkgInfo -and $VcpkgInfo.Found) {
        $vcpkgConfig = New-VcpkgLuaRocksConfig -VcpkgInfo $VcpkgInfo
        $configContent += $vcpkgConfig
    }

    return $configContent
}

<#
.SYNOPSIS
    Generates vcpkg integration configuration for LuaRocks.

.PARAMETER VcpkgInfo
    vcpkg information object

.OUTPUTS
    String containing vcpkg configuration section
#>
function New-VcpkgLuaRocksConfig {
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$VcpkgInfo
    )

    if (-not ((Test-Path $VcpkgInfo.IncludePath) -and (Test-Path $VcpkgInfo.LibPath))) {
        Write-Verbose "vcpkg paths not found, skipping integration"
        Write-Verbose "  -> Include path: $($VcpkgInfo.IncludePath) (exists: $(Test-Path $VcpkgInfo.IncludePath))"
        Write-Verbose "  -> Library path: $($VcpkgInfo.LibPath) (exists: $(Test-Path $VcpkgInfo.LibPath))"
        return ""
    }

    Write-LuaEnvMessage "Adding vcpkg integration to LuaRocks configuration" -Type Info
    Write-Verbose "  -> vcpkg root: $($VcpkgInfo.RootPath)"
    Write-Verbose "  -> Architecture: $($VcpkgInfo.Architecture)"
    Write-Verbose "  -> Include path: $($VcpkgInfo.IncludePath)"
    Write-Verbose "  -> Library path: $($VcpkgInfo.LibPath)"
    Write-Verbose "  -> Installed path: $($VcpkgInfo.InstalledPath)"

    # Escape paths for Lua configuration
    $vcpkgIncludeEscaped = $VcpkgInfo.IncludePath.TrimEnd('\').Replace('\', '\\')
    $vcpkgLibEscaped = $VcpkgInfo.LibPath.TrimEnd('\').Replace('\', '\\')
    $vcpkgInstalledEscaped = $VcpkgInfo.InstalledPath.TrimEnd('\').Replace('\', '\\')

    return @"

-- vcpkg integration for C library dependencies (Architecture: $($VcpkgInfo.Architecture))
variables = {
    CPPFLAGS = "/I\"$vcpkgIncludeEscaped\"",
    LIBFLAG = "/LIBPATH:\"$vcpkgLibEscaped\"",
    LDFLAGS = "/LIBPATH:\"$vcpkgLibEscaped\"",
    READLINE_DIR = "$vcpkgInstalledEscaped",
    READLINE_INCDIR = "$vcpkgIncludeEscaped",
    READLINE_LIBDIR = "$vcpkgLibEscaped"
}

-- Additional library search paths
external_deps_dirs = {
    "$vcpkgInstalledEscaped"
}
"@
}

# ==================================================================================
# UTILITY FUNCTIONS
# ==================================================================================

<#
.SYNOPSIS
    Writes a formatted message to the console with appropriate coloring.

.DESCRIPTION
    Provides centralized message formatting for LuaEnv operations with consistent
    color coding and formatting.

.PARAMETER Message
    The message to display.

.PARAMETER Type
    The type of message (Info, Success, Warning, Error).

.EXAMPLE
    Write-LuaEnvMessage "Operation completed successfully" -Type Success
#>
function Write-LuaEnvMessage {
    param(
        [Parameter(Mandatory)]
        [string]$Message,

        [Parameter(Mandatory)]
        [ValidateSet('Info', 'Success', 'Warning', 'Error')]
        [string]$Type
    )

    $color = switch ($Type) {
        'Info' { 'Cyan' }
        'Success' { 'Green' }
        'Warning' { 'Yellow' }
        'Error' { 'Red' }
    }

    $prefix = switch ($Type) {
        'Info' { '[INFO]' }
        'Success' { '[SUCCESS]' }
        'Warning' { '[WARNING]' }
        'Error' { '[ERROR]' }
    }

    Write-Host "$prefix $Message" -ForegroundColor $color
}

<#
.SYNOPSIS
    Gets standard LuaEnv directory paths.

.DESCRIPTION
    Returns a hashtable containing standard LuaEnv directory paths.

.OUTPUTS
    Hashtable with directory paths.
#>
function Get-LuaEnvDirectories {
    $home_luaenv = $env:USERPROFILE + "\.luaenv"

    return @{
        Home = $home_luaenv
        Installations = Join-Path $home_luaenv "installations"
        Environments = Join-Path $home_luaenv "environments"
        Registry = Join-Path $home_luaenv "registry.json"
        Cache = Join-Path $home_luaenv "cache"
    }
}

<#
.SYNOPSIS
    Formats a version string for display.

.DESCRIPTION
    Formats version strings consistently for display in LuaEnv output.

.PARAMETER Version
    The version string to format.

.OUTPUTS
    Formatted version string.
#>
function Format-LuaEnvVersion {
    param(
        [string]$Version
    )

    if (-not $Version) {
        return "unknown"
    }

    # Clean up version string (remove prefixes like 'v', 'lua-', etc.)
    $cleaned = $Version -replace '^(v|lua-)', ''

    # Ensure it looks like a version number
    if ($cleaned -match '^\d+\.\d+') {
        return $cleaned
    }

    return $Version
}

# ==================================================================================
# MODULE EXPORTS
# ==================================================================================

Export-ModuleMember -Function @(
    # Registry Management (Read-Only)
    'Get-LuaEnvRegistry',
    'Clear-LuaEnvRegistryCache',

    # Installation Discovery
    'Find-Installation',
    'Test-LuaInstallation',

    # Local Version Management
    'Get-LocalLuaVersion',
    'Set-LocalLuaVersion',
    'Remove-LocalLuaVersion',

    # Environment Status
    'Get-LuaEnvStatus',
    'Test-LuaEnvActive',

    # Utility Functions
    'Write-LuaEnvMessage',
    'Get-LuaEnvDirectories',
    'Format-LuaEnvVersion',

    # Environment Setup
    'Initialize-LuaEnvironment',
    'Find-VcpkgForEnvironment',
    'Initialize-VisualStudioForLua',
    'Initialize-LuaRocksTree',
    'Set-LuaEnvironmentVariables',
    'Set-LuaEnvironmentPath',
    'Set-LuaModulePaths',
    'New-LuaRocksConfiguration'
)
