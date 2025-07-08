# This is free and unencumbered software released into the public domain.
# For more details, see the LICENSE file in the project root.

<#
.SYNOPSIS
    LuaEnv Visual Studio and vcpkg Integration Module

.DESCRIPTION
    This module provides comprehensive Visual Studio development environment detection
    and configuration capabilities for LuaEnv. It includes automatic detection of
    Visual Studio installations, vcpkg package manager, and environment setup for
    C/C++ compilation support.

.NOTES
    Author: LuaEnv Project
    License: Public Domain
    Module: luaenv_vs.psm1
#>

# ==================================================================================
# MODULE VARIABLES AND CONSTANTS
# ==================================================================================

# Cache for expensive operations
$script:VSDetectionCache = @{}
$script:VcpkgDetectionCache = @{}

# Visual Studio version mappings
$script:VSVersionMap = @{
    '17.0' = '2022'
    '16.0' = '2019'
    '15.0' = '2017'
    '14.0' = '2015'
    '12.0' = '2013'
    '11.0' = '2012'
    '10.0' = '2010'
}

# Supported architectures
$script:SupportedArchitectures = @('x86', 'x64', 'amd64', 'arm64')

# Configuration file name
$script:VSConfigFile = '.vspath.txt'

# ==================================================================================
# UTILITY FUNCTIONS
# ==================================================================================

<#
.SYNOPSIS
    Normalizes architecture names for Visual Studio compatibility.

.PARAMETER Architecture
    The architecture name to normalize

.OUTPUTS
    String containing the normalized architecture name
#>
function ConvertTo-VSArchitecture {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Architecture
    )

    switch ($Architecture.ToLower()) {
        'x64' { return 'amd64' }
        'x86' { return 'x86' }
        'amd64' { return 'amd64' }
        'arm64' { return 'arm64' }
        default {
            Write-Warning "Unknown architecture: $Architecture, defaulting to amd64"
            return 'amd64'
        }
    }
}

<#
.SYNOPSIS
    Tests if a path represents a valid Visual Studio installation.

.PARAMETER InstallPath
    The path to test

.OUTPUTS
    Hashtable containing validation results and tool paths
#>
function Test-VSInstallation {
    param(
        [Parameter(Mandatory = $true)]
        [string]$InstallPath
    )

    if (-not $InstallPath -or -not (Test-Path $InstallPath)) {
        return @{ IsValid = $false; Reason = "Path does not exist" }
    }

    # Check for VS Developer Shell (PowerShell script - preferred)
    $vsDevShellPath = Join-Path $InstallPath "Common7\Tools\Launch-VsDevShell.ps1"

    # Check for VS Command Prompt (batch file - fallback)
    $vsDevCmdPath = Join-Path $InstallPath "Common7\Tools\VsDevCmd.bat"

    # Check for MSBuild (additional validation)
    $msBuildPath = Join-Path $InstallPath "MSBuild\Current\Bin\MSBuild.exe"
    $msBuildLegacyPath = Join-Path $InstallPath "MSBuild\15.0\Bin\MSBuild.exe"

    $result = @{
        IsValid = $false
        InstallPath = $InstallPath
        DevShellPath = $null
        DevCmdPath = $null
        MSBuildPath = $null
        HasCppTools = $false
        VSVersion = $null
        Edition = $null
    }

    # Determine which tools are available
    if (Test-Path $vsDevShellPath) {
        $result.DevShellPath = $vsDevShellPath
        $result.IsValid = $true
    }

    if (Test-Path $vsDevCmdPath) {
        $result.DevCmdPath = $vsDevCmdPath
        $result.IsValid = $true
    }

    # Check for MSBuild
    if (Test-Path $msBuildPath) {
        $result.MSBuildPath = $msBuildPath
    } elseif (Test-Path $msBuildLegacyPath) {
        $result.MSBuildPath = $msBuildLegacyPath
    }

    # Extract VS version and edition from path
    if ($InstallPath -match '\\Microsoft Visual Studio\\(\d{4})\\(\w+)') {
        $result.VSVersion = $matches[1]
        $result.Edition = $matches[2]
    }

    # Check for C++ tools
    $vcToolsPath = Join-Path $InstallPath "VC\Tools\MSVC"
    if (Test-Path $vcToolsPath) {
        $result.HasCppTools = $true
    }

    return $result
}

<#
.SYNOPSIS
    Creates a cache key for VS detection operations.

.PARAMETER Architecture
    Target architecture

.PARAMETER CustomPath
    Custom installation path (if any)

.OUTPUTS
    String containing the cache key
#>
function Get-VSCacheKey {
    param(
        [string]$Architecture = 'amd64',
        [string]$CustomPath = ''
    )

    return "$Architecture|$CustomPath"
}

# ==================================================================================
# CONFIGURATION MANAGEMENT
# ==================================================================================

<#
.SYNOPSIS
    Retrieves the saved Visual Studio installation path from configuration.

.OUTPUTS
    String containing the VS installation path, or $null if not found
#>
function Get-VSPathConfig {
    $configPath = Join-Path (Get-Location) $script:VSConfigFile

    if (Test-Path $configPath) {
        try {
            $path = Get-Content $configPath -Raw | ForEach-Object { $_.Trim() }
            if ($path -and (Test-Path $path)) {
                return $path
            }
        }
        catch {
            Write-Warning "Failed to read VS config file: $_"
        }
    }

    return $null
}

<#
.SYNOPSIS
    Saves the Visual Studio installation path to configuration.

.PARAMETER VsPath
    The Visual Studio installation path to save

.OUTPUTS
    Boolean indicating success or failure
#>
function Set-VSPathConfig {
    param(
        [Parameter(Mandatory = $true)]
        [string]$VsPath
    )

    $configPath = Join-Path (Get-Location) $script:VSConfigFile

    try {
        $VsPath | Set-Content $configPath -Force
        Write-Verbose "Visual Studio path saved to config: $VsPath"
        return $true
    }
    catch {
        Write-Warning "Failed to save Visual Studio path: $_"
        return $false
    }
}

# ==================================================================================
# VISUAL STUDIO DETECTION METHODS
# ==================================================================================

<#
.SYNOPSIS
    Finds Visual Studio installations using vswhere.exe.

.PARAMETER Architecture
    Target architecture

.OUTPUTS
    Array of installation objects found by vswhere
#>
function Find-VSUsingVSWhere {
    param(
        [string]$Architecture = 'amd64'
    )

    Write-Verbose "Searching for Visual Studio installations using vswhere..."

    # Comprehensive list of vswhere.exe locations
    # Ordered by likelihood of success (most common first)
    $vswherePaths = @(
        # Official Microsoft installer locations (most common)
        "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe",
        "${env:ProgramFiles}\Microsoft Visual Studio\Installer\vswhere.exe",

        # Microsoft Visual Studio data locations
        "${env:ProgramData}\Microsoft\VisualStudio\Packages\_Instances\vswhere.exe",
        "${env:ProgramData}\Microsoft\VisualStudio\Setup\vswhere.exe",

        # Package manager locations
        "${env:ChocolateyInstall}\lib\vswhere\tools\vswhere.exe",
        "${env:ProgramData}\chocolatey\lib\vswhere\tools\vswhere.exe",
        "C:\ProgramData\chocolatey\lib\vswhere\tools\vswhere.exe",

        # Scoop package manager locations
        "${env:SCOOP}\apps\vswhere\current\vswhere.exe",
        "${env:USERPROFILE}\scoop\apps\vswhere\current\vswhere.exe",
        "${env:SCOOP_GLOBAL}\apps\vswhere\current\vswhere.exe",
        "${env:ProgramData}\scoop\apps\vswhere\current\vswhere.exe",
        "${env:USERPROFILE}\scoop\shims\vswhere.exe",

        # WinGet package manager locations
        "${env:LOCALAPPDATA}\Microsoft\WinGet\Packages\vswhere.exe",
        "${env:LOCALAPPDATA}\Microsoft\WinGet\Links\vswhere.exe",

        # BuildTools specific locations
        "${env:ProgramFiles(x86)}\Microsoft Visual Studio\2022\BuildTools\Installer\vswhere.exe",
        "${env:ProgramFiles(x86)}\Microsoft Visual Studio\2019\BuildTools\Installer\vswhere.exe",
        "${env:ProgramFiles(x86)}\Microsoft Visual Studio\2017\BuildTools\Installer\vswhere.exe",

        # Shared installer locations
        "${env:ProgramFiles}\Microsoft Visual Studio\Shared\Installer\vswhere.exe",
        "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Shared\Installer\vswhere.exe",
        "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Shared\vswhere\vswhere.exe",

        # NuGet package locations (handled separately with glob pattern)
        # "${env:USERPROFILE}\.nuget\packages\vswhere\*\tools\vswhere.exe",

        # Manual installation locations
        "C:\Tools\vswhere\vswhere.exe",
        "D:\Tools\vswhere\vswhere.exe",
        "${env:USERPROFILE}\Downloads\vswhere.exe",
        "${env:LOCALAPPDATA}\vswhere\vswhere.exe",

        # Environment variable based locations
        "${env:VSINSTALLDIR}\Installer\vswhere.exe",
        "${env:VS170COMNTOOLS}\..\..\Installer\vswhere.exe",
        "${env:VS160COMNTOOLS}\..\..\Installer\vswhere.exe",
        "${env:VS150COMNTOOLS}\..\..\Installer\vswhere.exe"
    )

    # Handle NuGet glob pattern separately
    $nugetPaths = Get-ChildItem -Path "${env:USERPROFILE}\.nuget\packages\vswhere\*\tools\vswhere.exe" -ErrorAction SilentlyContinue |
                  Sort-Object LastWriteTime -Descending |
                  Select-Object -First 1 -ExpandProperty FullName

    # Add NuGet paths to the list if found
    if ($nugetPaths) {
        $vswherePaths = @($nugetPaths) + $vswherePaths
    }

    # Find the first available vswhere.exe
    $vswherePath = $vswherePaths | Where-Object { Test-Path $_ } | Select-Object -First 1

    if (-not $vswherePath) {
        Write-Verbose "vswhere.exe not found"
        return @()
    }

    Write-Verbose "Found vswhere.exe at: $vswherePath"

    try {
        # Query for all VS installations with detailed information
        $vsInstallations = @()

        # Query 1: All products including prerelease
        $allQuery = & $vswherePath -all -prerelease -format json 2>$null
        if ($allQuery -and $LASTEXITCODE -eq 0) {
            $installations = $allQuery | ConvertFrom-Json
            if ($installations) {
                $vsInstallations += $installations
            }
        }

        # Query 2: Specific search for C++ workloads
        $cppQuery = & $vswherePath -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -format json 2>$null
        if ($cppQuery -and $LASTEXITCODE -eq 0) {
            $cppInstallations = $cppQuery | ConvertFrom-Json
            if ($cppInstallations) {
                $vsInstallations += $cppInstallations
            }
        }

        # Remove duplicates and process installations
        $uniqueInstallations = $vsInstallations | Sort-Object installationPath -Unique

        $results = @()
        foreach ($installation in $uniqueInstallations) {
            $testResult = Test-VSInstallation -InstallPath $installation.installationPath
            if ($testResult.IsValid) {
                $results += [PSCustomObject]@{
                    InstallPath = $installation.installationPath
                    Version = $installation.installationVersion
                    DisplayName = $installation.displayName
                    ProductId = $installation.productId
                    HasCppTools = $testResult.HasCppTools
                    DevShellPath = $testResult.DevShellPath
                    DevCmdPath = $testResult.DevCmdPath
                    MSBuildPath = $testResult.MSBuildPath
                    Source = 'vswhere'
                }
            }
        }

        # Sort by version (newest first) and C++ tools availability
        return $results | Sort-Object @{
            Expression = { $_.Version }; Descending = $true
        }, @{
            Expression = { $_.HasCppTools }; Descending = $true
        }
    }
    catch {
        Write-Warning "Error running vswhere: $_"
        return @()
    }
}

<#
.SYNOPSIS
    Finds Visual Studio installations using registry detection.

.OUTPUTS
    Array of installation objects found in registry
#>
function Find-VSUsingRegistry {
    Write-Verbose "Searching Windows Registry for VS installations..."

    $registryPaths = @(
        # Standard Visual Studio registry locations
        "HKLM:\SOFTWARE\Microsoft\VisualStudio\SxS\VS7",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\VisualStudio\SxS\VS7",
        "HKLM:\SOFTWARE\Microsoft\VisualStudio",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\VisualStudio",
        "HKCU:\SOFTWARE\Microsoft\VisualStudio",
        "HKLM:\SOFTWARE\Microsoft\VSCommon",

        # Visual Studio 2022+ specific locations
        "HKLM:\SOFTWARE\Microsoft\VisualStudio\17.0",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\VisualStudio\17.0",
        "HKCU:\SOFTWARE\Microsoft\VisualStudio\17.0",
        "HKCU:\SOFTWARE\Microsoft\VisualStudio\17.0_Config",

        # Visual Studio 2019 specific locations
        "HKLM:\SOFTWARE\Microsoft\VisualStudio\16.0",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\VisualStudio\16.0",
        "HKCU:\SOFTWARE\Microsoft\VisualStudio\16.0",
        "HKCU:\SOFTWARE\Microsoft\VisualStudio\16.0_Config",

        # Visual Studio 2017 specific locations
        "HKLM:\SOFTWARE\Microsoft\VisualStudio\15.0",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\VisualStudio\15.0",
        "HKCU:\SOFTWARE\Microsoft\VisualStudio\15.0",
        "HKCU:\SOFTWARE\Microsoft\VisualStudio\15.0_Config",

        # Visual Studio 2015 and earlier
        "HKLM:\SOFTWARE\Microsoft\VisualStudio\14.0",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\VisualStudio\14.0",
        "HKCU:\SOFTWARE\Microsoft\VisualStudio\14.0",

        # DevDiv registry locations
        "HKLM:\SOFTWARE\Microsoft\DevDiv\VS\Servicing",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\DevDiv\VS\Servicing",

        # Setup configuration registry
        "HKLM:\SOFTWARE\Microsoft\VisualStudio\Setup",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\VisualStudio\Setup",

        # Packages and component registry
        "HKLM:\SOFTWARE\Classes\Installer\Dependencies\Microsoft.VisualStudio.Community",
        "HKLM:\SOFTWARE\Classes\Installer\Dependencies\Microsoft.VisualStudio.Professional",
        "HKLM:\SOFTWARE\Classes\Installer\Dependencies\Microsoft.VisualStudio.Enterprise",
        "HKLM:\SOFTWARE\Classes\Installer\Dependencies\Microsoft.VisualStudio.BuildTools",

        # MSBuild registry locations
        "HKLM:\SOFTWARE\Microsoft\MSBuild\ToolsVersions",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\MSBuild\ToolsVersions",

        # Windows SDK registry locations (often installed with VS)
        "HKLM:\SOFTWARE\Microsoft\Windows Kits\Installed Roots",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows Kits\Installed Roots",

        # Visual C++ compiler registry locations
        "HKLM:\SOFTWARE\Microsoft\VisualStudio\VC",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\VisualStudio\VC",
        "HKLM:\SOFTWARE\Microsoft\VisualCpp\17.0",
        "HKLM:\SOFTWARE\Microsoft\VisualCpp\16.0",
        "HKLM:\SOFTWARE\Microsoft\VisualCpp\15.0",

        # Side-by-side installations registry
        "HKLM:\SOFTWARE\Microsoft\VisualStudio\SxS\Setup",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\VisualStudio\SxS\Setup"
    )

    $results = @()

    foreach ($regPath in $registryPaths) {
        try {
            if (Test-Path $regPath) {
                Write-Verbose "Checking registry path: $regPath"
                $regKey = Get-Item $regPath -ErrorAction SilentlyContinue
                if ($regKey) {
                    # Method 1: Check for direct InstallDir value
                    try {
                        $installDir = Get-ItemProperty -Path $regPath -Name "InstallDir" -ErrorAction SilentlyContinue
                        if ($installDir -and $installDir.InstallDir) {
                            # InstallDir typically points to Common7\IDE, go up to get root
                            $installPath = Split-Path (Split-Path $installDir.InstallDir)
                            if ($installPath -and (Test-Path $installPath)) {
                                $testResult = Test-VSInstallation -InstallPath $installPath
                                if ($testResult.IsValid) {
                                    $results += [PSCustomObject]@{
                                        InstallPath = $installPath
                                        Version = $testResult.VSVersion
                                        DisplayName = "Visual Studio (from registry InstallDir)"
                                        ProductId = "Registry"
                                        HasCppTools = $testResult.HasCppTools
                                        DevShellPath = $testResult.DevShellPath
                                        DevCmdPath = $testResult.DevCmdPath
                                        MSBuildPath = $testResult.MSBuildPath
                                        Source = 'registry'
                                    }
                                }
                            }
                        }
                    } catch { }

                    # Method 2: Check for ShellFolder value
                    try {
                        $shellFolder = Get-ItemProperty -Path $regPath -Name "ShellFolder" -ErrorAction SilentlyContinue
                        if ($shellFolder -and $shellFolder.ShellFolder) {
                            $installPath = $shellFolder.ShellFolder
                            if ($installPath -and (Test-Path $installPath)) {
                                $testResult = Test-VSInstallation -InstallPath $installPath
                                if ($testResult.IsValid) {
                                    $results += [PSCustomObject]@{
                                        InstallPath = $installPath
                                        Version = $testResult.VSVersion
                                        DisplayName = "Visual Studio (from registry ShellFolder)"
                                        ProductId = "Registry"
                                        HasCppTools = $testResult.HasCppTools
                                        DevShellPath = $testResult.DevShellPath
                                        DevCmdPath = $testResult.DevCmdPath
                                        MSBuildPath = $testResult.MSBuildPath
                                        Source = 'registry'
                                    }
                                }
                            }
                        }
                    } catch { }

                    # Method 3: Enumerate subkeys and check their values
                    try {
                        foreach ($valueName in $regKey.GetValueNames()) {
                            $installPath = $regKey.GetValue($valueName)
                            if ($installPath -and (Test-Path $installPath)) {
                                $testResult = Test-VSInstallation -InstallPath $installPath
                                if ($testResult.IsValid) {
                                    $results += [PSCustomObject]@{
                                        InstallPath = $installPath
                                        Version = $valueName
                                        DisplayName = "Visual Studio $($script:VSVersionMap[$valueName])"
                                        ProductId = "Registry"
                                        HasCppTools = $testResult.HasCppTools
                                        DevShellPath = $testResult.DevShellPath
                                        DevCmdPath = $testResult.DevCmdPath
                                        MSBuildPath = $testResult.MSBuildPath
                                        Source = 'registry'
                                    }
                                }
                            }
                        }
                    } catch { }

                    # Method 4: Check subkeys for installation paths
                    try {
                        $subKeys = Get-ChildItem $regPath -ErrorAction SilentlyContinue
                        foreach ($subKey in $subKeys) {
                            $installDir = Get-ItemProperty -Path $subKey.PSPath -Name "InstallDir" -ErrorAction SilentlyContinue
                            if ($installDir -and $installDir.InstallDir) {
                                $installPath = Split-Path (Split-Path $installDir.InstallDir)
                                if ($installPath -and (Test-Path $installPath)) {
                                    $testResult = Test-VSInstallation -InstallPath $installPath
                                    if ($testResult.IsValid) {
                                        $results += [PSCustomObject]@{
                                            InstallPath = $installPath
                                            Version = $subKey.Name
                                            DisplayName = "Visual Studio (from registry subkey)"
                                            ProductId = "Registry"
                                            HasCppTools = $testResult.HasCppTools
                                            DevShellPath = $testResult.DevShellPath
                                            DevCmdPath = $testResult.DevCmdPath
                                            MSBuildPath = $testResult.MSBuildPath
                                            Source = 'registry'
                                        }
                                    }
                                }
                            }
                        }
                    } catch { }
                }
            }
        }
        catch {
            Write-Verbose "Error reading registry path $regPath`: $_"
        }
    }

    # Remove duplicates based on InstallPath
    return $results | Sort-Object InstallPath -Unique
}

<#
.SYNOPSIS
    Finds Visual Studio installations using common installation paths.

.OUTPUTS
    Array of installation objects found in common paths
#>
function Find-VSUsingCommonPaths {
    Write-Verbose "Checking common Visual Studio installation paths..."

    $commonPaths = @(
        # VS 2022 - ordered by commonality (Community first)
        "${env:ProgramFiles}\Microsoft Visual Studio\2022\Community",
        "${env:ProgramFiles}\Microsoft Visual Studio\2022\Professional",
        "${env:ProgramFiles}\Microsoft Visual Studio\2022\Enterprise",
        "${env:ProgramFiles}\Microsoft Visual Studio\2022\Preview",
        "${env:ProgramFiles}\Microsoft Visual Studio\2022\BuildTools",
        "${env:ProgramFiles}\Microsoft Visual Studio\2022\TeamExplorer",

        # VS 2019 - ordered by commonality (Community first)
        "${env:ProgramFiles(x86)}\Microsoft Visual Studio\2019\Community",
        "${env:ProgramFiles(x86)}\Microsoft Visual Studio\2019\Professional",
        "${env:ProgramFiles(x86)}\Microsoft Visual Studio\2019\Enterprise",
        "${env:ProgramFiles(x86)}\Microsoft Visual Studio\2019\Preview",
        "${env:ProgramFiles(x86)}\Microsoft Visual Studio\2019\BuildTools",
        "${env:ProgramFiles(x86)}\Microsoft Visual Studio\2019\TeamExplorer",

        # VS 2017 - ordered by commonality (Community first)
        "${env:ProgramFiles(x86)}\Microsoft Visual Studio\2017\Community",
        "${env:ProgramFiles(x86)}\Microsoft Visual Studio\2017\Professional",
        "${env:ProgramFiles(x86)}\Microsoft Visual Studio\2017\Enterprise",
        "${env:ProgramFiles(x86)}\Microsoft Visual Studio\2017\BuildTools",
        "${env:ProgramFiles(x86)}\Microsoft Visual Studio\2017\TeamExplorer",

        # Alternative locations for VS 2022 in Program Files (x86)
        "${env:ProgramFiles(x86)}\Microsoft Visual Studio\2022\Community",
        "${env:ProgramFiles(x86)}\Microsoft Visual Studio\2022\Professional",
        "${env:ProgramFiles(x86)}\Microsoft Visual Studio\2022\Enterprise",
        "${env:ProgramFiles(x86)}\Microsoft Visual Studio\2022\Preview",
        "${env:ProgramFiles(x86)}\Microsoft Visual Studio\2022\BuildTools",

        # Legacy versions (older structure)
        "${env:ProgramFiles(x86)}\Microsoft Visual Studio 14.0",  # VS 2015
        "${env:ProgramFiles(x86)}\Microsoft Visual Studio 12.0",  # VS 2013
        "${env:ProgramFiles(x86)}\Microsoft Visual Studio 11.0",  # VS 2012
        "${env:ProgramFiles(x86)}\Microsoft Visual Studio 10.0",  # VS 2010
        "${env:ProgramFiles(x86)}\Microsoft Visual Studio 9.0",   # VS 2008
        "${env:ProgramFiles(x86)}\Microsoft Visual Studio 8"      # VS 2005
    )

    $results = @()

    foreach ($path in $commonPaths) {
        if (Test-Path $path) {
            $testResult = Test-VSInstallation -InstallPath $path
            if ($testResult.IsValid) {
                $results += [PSCustomObject]@{
                    InstallPath = $path
                    Version = $testResult.VSVersion
                    DisplayName = "Visual Studio $($testResult.VSVersion) $($testResult.Edition)"
                    ProductId = "CommonPath"
                    HasCppTools = $testResult.HasCppTools
                    DevShellPath = $testResult.DevShellPath
                    DevCmdPath = $testResult.DevCmdPath
                    MSBuildPath = $testResult.MSBuildPath
                    Source = 'common_paths'
                }
            }
        }
    }

    return $results
}

<#
.SYNOPSIS
    Finds Visual Studio installations using environment variables.

.OUTPUTS
    Array of installation objects found via environment variables
#>
function Find-VSUsingEnvironment {
    Write-Verbose "Searching for VS installations using environment variables..."

    $envVars = @(
        # Primary VS installation directories
        'VSINSTALLDIR',
        'VCINSTALLDIR',
        'VS2022INSTALLDIR',
        'VS2019INSTALLDIR',
        'VS2017INSTALLDIR',

        # Visual Studio common tools (ordered by version - newest first)
        'VS170COMNTOOLS',  # VS 2022
        'VS160COMNTOOLS',  # VS 2019
        'VS150COMNTOOLS',  # VS 2017
        'VS140COMNTOOLS',  # VS 2015
        'VS120COMNTOOLS',  # VS 2013
        'VS110COMNTOOLS',  # VS 2012
        'VS100COMNTOOLS',  # VS 2010
        'VS90COMNTOOLS',   # VS 2008
        'VS80COMNTOOLS',   # VS 2005

        # Visual Studio command environment variables
        'VisualStudioVersion',
        'VSCMD_START_DIR',
        'VSCMD_ARG_HOST_ARCH',
        'VSCMD_ARG_TGT_ARCH',
        'VSCMD_ARG_app_plat',
        'VSAPPIDDIR',
        'VSIDEInstallDir',
        'DevEnvDir',

        # Visual C++ tools
        'VCToolsInstallDir',
        'VCToolsRedistDir',
        'VCToolsVersion',

        # Windows SDK variables
        'WindowsSdkDir',
        'WindowsSdkVersion',
        'WindowsSDKLibVersion',
        'UniversalCRTSdkDir',
        'UCRTVersion',

        # .NET Framework variables
        'FrameworkDir',
        'FrameworkDir64',
        'FrameworkVersion',
        'Framework40Version',

        # MSBuild variables
        'MSBuildExtensionsPath',
        'MSBuildExtensionsPath32',
        'MSBuildExtensionsPath64',
        'MSBUILD_PATH',
        'MSBUILD_DIR',

        # vcpkg integration
        'VCPKG_ROOT',

        # Development environment paths
        'INCLUDE',
        'LIB',
        'LIBPATH'
    )

    $results = @()

    foreach ($varName in $envVars) {
        $value = [Environment]::GetEnvironmentVariable($varName)
        if ($value -and (Test-Path $value)) {
            # Navigate to installation root
            $installPath = $value
            if ($varName -like '*COMNTOOLS') {
                # CommonTools points to Common7\Tools, go up to installation root
                $installPath = Split-Path (Split-Path $value)
            }

            $testResult = Test-VSInstallation -InstallPath $installPath
            if ($testResult.IsValid) {
                $results += [PSCustomObject]@{
                    InstallPath = $installPath
                    Version = $testResult.VSVersion
                    DisplayName = "Visual Studio (from $varName)"
                    ProductId = "Environment"
                    HasCppTools = $testResult.HasCppTools
                    DevShellPath = $testResult.DevShellPath
                    DevCmdPath = $testResult.DevCmdPath
                    MSBuildPath = $testResult.MSBuildPath
                    Source = 'environment'
                }
            }
        }
    }

    return $results
}

# ==================================================================================
# VCPKG DETECTION
# ==================================================================================

<#
.SYNOPSIS
    Finds vcpkg installations on the system.

.PARAMETER Architecture
    Target architecture for vcpkg packages

.OUTPUTS
    Hashtable containing vcpkg installation information
#>
function Find-VcpkgInstallation {
    param(
        [string]$Architecture = 'x64-windows'
    )

    # Check cache first
    $cacheKey = "vcpkg|$Architecture"
    if ($script:VcpkgDetectionCache.ContainsKey($cacheKey)) {
        Write-Verbose "Using cached vcpkg detection result"
        return $script:VcpkgDetectionCache[$cacheKey]
    }

    Write-Verbose "Searching for vcpkg installations..."

    # Convert VS architecture to vcpkg triplet
    $vcpkgTriplet = switch ($Architecture.ToLower()) {
        'x86' { 'x86-windows' }
        'amd64' { 'x64-windows' }
        'x64' { 'x64-windows' }
        'arm64' { 'arm64-windows' }
        default { 'x64-windows' }
    }

    $searchPaths = @()

    # 1. Environment variable (highest priority)
    if ($env:VCPKG_ROOT -and (Test-Path $env:VCPKG_ROOT)) {
        $searchPaths += $env:VCPKG_ROOT
    }

    # 2. Common installation paths (ordered by likelihood)
    $searchPaths += @(
        "C:\vcpkg",
        "C:\tools\vcpkg",
        "C:\dev\vcpkg",
        "$env:USERPROFILE\vcpkg",
        "$env:USERPROFILE\opt\vcpkg",
        "$env:USERPROFILE\.local\vcpkg",
        "$env:USERPROFILE\installed\vcpkg",
        "$env:USERPROFILE\usr\vcpkg",
        "$env:USERPROFILE\dev\vcpkg",
        "$env:USERPROFILE\.vcpkg",
        "$env:LOCALAPPDATA\vcpkg",
        "D:\vcpkg",
        "E:\vcpkg"
    )

    # 3. Check if vcpkg is in PATH
    $vcpkgCmd = Get-Command "vcpkg" -ErrorAction SilentlyContinue
    if ($vcpkgCmd) {
        $searchPaths += (Split-Path $vcpkgCmd.Source -Parent)
    }

    # Find the first valid vcpkg installation
    foreach ($path in $searchPaths) {
        if (Test-Path $path) {
            $vcpkgExe = Join-Path $path "vcpkg.exe"
            $installedPath = Join-Path $path "installed\$vcpkgTriplet"

            if ((Test-Path $vcpkgExe) -and (Test-Path $installedPath)) {
                $result = @{
                    Found = $true
                    RootPath = $path
                    ExecutablePath = $vcpkgExe
                    InstalledPath = $installedPath
                    IncludePath = Join-Path $installedPath "include"
                    LibPath = Join-Path $installedPath "lib"
                    BinPath = Join-Path $installedPath "bin"
                    Triplet = $vcpkgTriplet
                    Architecture = $Architecture
                }

                # Cache the result
                $script:VcpkgDetectionCache[$cacheKey] = $result

                Write-Verbose "Found vcpkg installation: $path"
                Write-Verbose "Using triplet: $vcpkgTriplet"

                return $result
            }
        }
    }

    # No vcpkg found
    $result = @{
        Found = $false
        RootPath = $null
        ExecutablePath = $null
        InstalledPath = $null
        IncludePath = $null
        LibPath = $null
        BinPath = $null
        Triplet = $vcpkgTriplet
        Architecture = $Architecture
    }

    # Cache the negative result
    $script:VcpkgDetectionCache[$cacheKey] = $result

    Write-Verbose "vcpkg not found"
    return $result
}

# ==================================================================================
# ENVIRONMENT SETUP FUNCTIONS
# ==================================================================================

<#
.SYNOPSIS
    Imports Visual Studio environment variables into the current PowerShell session.

.PARAMETER Installation
    VS installation object

.PARAMETER Architecture
    Target architecture

.OUTPUTS
    Boolean indicating success or failure
#>
function Import-VSEnvironment {
    param(
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$Installation,

        [string]$Architecture = 'amd64'
    )

    $normalizedArch = ConvertTo-VSArchitecture -Architecture $Architecture

    try {
        # Prefer PowerShell script if available
        if ($Installation.DevShellPath -and (Test-Path $Installation.DevShellPath)) {
            Write-Verbose "Using PowerShell Developer Shell: $($Installation.DevShellPath)"

            # Import VS environment using PowerShell method
            & $Installation.DevShellPath -Arch $normalizedArch -SkipAutomaticLocation

            Write-Verbose "Visual Studio environment imported successfully"
            return $true
        }
        # Fallback to batch file method
        elseif ($Installation.DevCmdPath -and (Test-Path $Installation.DevCmdPath)) {
            Write-Verbose "Using batch file method: $($Installation.DevCmdPath)"

            return Import-VSEnvironmentFromBatch -BatchPath $Installation.DevCmdPath -Architecture $normalizedArch
        }
        else {
            Write-Warning "No valid VS environment setup method found"
            return $false
        }
    }
    catch {
        Write-Warning "Failed to import VS environment: $_"
        return $false
    }
}

<#
.SYNOPSIS
    Imports Visual Studio environment variables using VsDevCmd.bat.

.PARAMETER BatchPath
    Path to VsDevCmd.bat

.PARAMETER Architecture
    Target architecture

.OUTPUTS
    Boolean indicating success or failure
#>
function Import-VSEnvironmentFromBatch {
    param(
        [Parameter(Mandatory = $true)]
        [string]$BatchPath,

        [string]$Architecture = 'amd64'
    )

    try {
        # Create temporary batch file to capture environment
        $tempFile = [System.IO.Path]::GetTempFileName() + ".bat"
        $batContent = @"
@echo off
call "$BatchPath" -arch=$Architecture -no_logo
set
"@
        Set-Content -Path $tempFile -Value $batContent

        # Execute and capture environment variables
        $envVars = & cmd /c $tempFile 2>$null
        Remove-Item $tempFile -Force

        if ($LASTEXITCODE -ne 0) {
            Write-Warning "VsDevCmd.bat execution failed"
            return $false
        }

        # Import environment variables
        $importCount = 0
        foreach ($line in $envVars) {
            if ($line -match '^([^=]+)=(.*)$') {
                $varName = $matches[1]
                $varValue = $matches[2]

                # Skip certain system variables
                if ($varName -notmatch '^(COMSPEC|PATHEXT|PROCESSOR_|PSModulePath|TEMP|TMP|USERNAME|USERPROFILE|windir)$') {
                    [Environment]::SetEnvironmentVariable($varName, $varValue, 'Process')
                    $importCount++
                }
            }
        }

        Write-Verbose "Imported $importCount environment variables from VS batch file"
        return $true
    }
    catch {
        Write-Warning "Failed to import VS environment from batch: $_"
        return $false
    }
}

# ==================================================================================
# MAIN PUBLIC FUNCTIONS
# ==================================================================================

<#
.SYNOPSIS
    Finds and configures Visual Studio Developer Environment.

.PARAMETER Architecture
    Target architecture (x86, x64/amd64, arm64)

.PARAMETER CustomPath
    Optional custom VS installation path

.PARAMETER SaveConfig
    Whether to save custom path to configuration

.PARAMETER ImportEnvironment
    Whether to import environment into current session

.OUTPUTS
    Hashtable containing VS detection and setup results
#>
function Initialize-VisualStudioEnvironment {
    [CmdletBinding()]
    param(
        [ValidateSet('x86', 'x64', 'amd64', 'arm64')]
        [string]$Architecture = 'amd64',

        [string]$CustomPath = '',

        [switch]$SaveConfig,

        [switch]$ImportEnvironment = $true
    )

    $normalizedArch = ConvertTo-VSArchitecture -Architecture $Architecture

    # Check cache first
    $cacheKey = Get-VSCacheKey -Architecture $normalizedArch -CustomPath $CustomPath
    if ($script:VSDetectionCache.ContainsKey($cacheKey) -and -not $CustomPath) {
        Write-Verbose "Using cached VS detection result"
        $cachedResult = $script:VSDetectionCache[$cacheKey]

        if ($ImportEnvironment -and $cachedResult.Success) {
            Import-VSEnvironment -Installation $cachedResult.Installation -Architecture $normalizedArch | Out-Null
        }

        return $cachedResult
    }

    Write-Verbose "Initializing Visual Studio environment for $normalizedArch architecture"

    $result = @{
        Success = $false
        Installation = $null
        Architecture = $normalizedArch
        CustomPath = $CustomPath
        Message = ''
        AllInstallations = @()
    }

    try {
        # Priority 1: Custom path if provided
        if ($CustomPath) {
            Write-Verbose "Testing custom VS path: $CustomPath"

            if (-not (Test-Path $CustomPath)) {
                $result.Message = "Custom path does not exist: $CustomPath"
                return $result
            }

            $testResult = Test-VSInstallation -InstallPath $CustomPath
            if ($testResult.IsValid) {
                $installation = [PSCustomObject]@{
                    InstallPath = $CustomPath
                    Version = $testResult.VSVersion
                    DisplayName = "Custom VS Installation"
                    ProductId = "Custom"
                    HasCppTools = $testResult.HasCppTools
                    DevShellPath = $testResult.DevShellPath
                    DevCmdPath = $testResult.DevCmdPath
                    MSBuildPath = $testResult.MSBuildPath
                    Source = 'custom'
                }

                $result.Installation = $installation
                $result.Success = $true
                $result.Message = "Using custom VS installation: $CustomPath"

                # Save to config if requested
                if ($SaveConfig) {
                    Set-VSPathConfig -VsPath $CustomPath | Out-Null
                }

                # Import environment if requested
                if ($ImportEnvironment) {
                    Import-VSEnvironment -Installation $installation -Architecture $normalizedArch | Out-Null
                }

                return $result
            }
            else {
                $result.Message = "Custom path is not a valid VS installation: $CustomPath"
                return $result
            }
        }

        # Priority 2: Saved configuration
        $savedPath = Get-VSPathConfig
        if ($savedPath) {
            Write-Verbose "Testing saved VS path: $savedPath"

            $testResult = Test-VSInstallation -InstallPath $savedPath
            if ($testResult.IsValid) {
                $installation = [PSCustomObject]@{
                    InstallPath = $savedPath
                    Version = $testResult.VSVersion
                    DisplayName = "Saved VS Installation"
                    ProductId = "Saved"
                    HasCppTools = $testResult.HasCppTools
                    DevShellPath = $testResult.DevShellPath
                    DevCmdPath = $testResult.DevCmdPath
                    MSBuildPath = $testResult.MSBuildPath
                    Source = 'saved_config'
                }

                $result.Installation = $installation
                $result.Success = $true
                $result.Message = "Using saved VS installation: $savedPath"

                # Import environment if requested
                if ($ImportEnvironment) {
                    Import-VSEnvironment -Installation $installation -Architecture $normalizedArch | Out-Null
                }

                # Cache result
                $script:VSDetectionCache[$cacheKey] = $result

                return $result
            }
            else {
                Write-Verbose "Saved VS path is no longer valid, falling back to detection"
            }
        }

        # Priority 3-6: Automatic detection
        $allInstallations = @()

        # Try vswhere first (most reliable)
        $vswhere = Find-VSUsingVSWhere -Architecture $normalizedArch
        $allInstallations += $vswhere

        # Try registry detection
        $registry = Find-VSUsingRegistry
        $allInstallations += $registry

        # Try common paths
        $commonPaths = Find-VSUsingCommonPaths
        $allInstallations += $commonPaths

        # Try environment variables
        $environment = Find-VSUsingEnvironment
        $allInstallations += $environment

        # Remove duplicates and sort
        $uniqueInstallations = $allInstallations |
            Sort-Object InstallPath -Unique |
            Sort-Object @{
                Expression = { $_.Version }; Descending = $true
            }, @{
                Expression = { $_.HasCppTools }; Descending = $true
            }, @{
                Expression = { if ($_.Source -eq 'vswhere') { 0 } else { 1 } }
            }

        $result.AllInstallations = $uniqueInstallations

        if ($uniqueInstallations.Count -eq 0) {
            $result.Message = "No Visual Studio installations found"
            return $result
        }

        # Use the best installation found
        $bestInstallation = $uniqueInstallations[0]
        $result.Installation = $bestInstallation
        $result.Success = $true
        $result.Message = "Found VS installation: $($bestInstallation.DisplayName) at $($bestInstallation.InstallPath)"

        # Import environment if requested
        if ($ImportEnvironment) {
            $importSuccess = Import-VSEnvironment -Installation $bestInstallation -Architecture $normalizedArch
            if (-not $importSuccess) {
                $result.Success = $false
                $result.Message += " (failed to import environment)"
            }
        }

        # Cache the result
        $script:VSDetectionCache[$cacheKey] = $result

        return $result
    }
    catch {
        $result.Message = "Error during VS detection: $_"
        Write-Warning $result.Message
        return $result
    }
}

<#
.SYNOPSIS
    Gets information about all available Visual Studio installations.

.OUTPUTS
    Array of VS installation objects
#>
function Get-VisualStudioInstallations {
    [CmdletBinding()]
    param()

    Write-Verbose "Discovering all Visual Studio installations..."

    $allInstallations = @()

    # Collect from all primary detection methods
    $allInstallations += Find-VSUsingVSWhere
    $allInstallations += Find-VSUsingRegistry
    $allInstallations += Find-VSUsingCommonPaths
    $allInstallations += Find-VSUsingEnvironment

    # Add saved config if available
    $savedPath = Get-VSPathConfig
    if ($savedPath) {
        $testResult = Test-VSInstallation -InstallPath $savedPath
        if ($testResult.IsValid) {
            $allInstallations += [PSCustomObject]@{
                InstallPath = $savedPath
                Version = $testResult.VSVersion
                DisplayName = "Saved Configuration"
                ProductId = "SavedConfig"
                HasCppTools = $testResult.HasCppTools
                DevShellPath = $testResult.DevShellPath
                DevCmdPath = $testResult.DevCmdPath
                MSBuildPath = $testResult.MSBuildPath
                Source = 'saved_config'
            }
        }
    }

    # If no installations found, try WMI as last resort
    if ($allInstallations.Count -eq 0) {
        Write-Verbose "No VS installations found via standard methods, trying WMI fallback..."

        $wmiInstallations = Get-VSInstallationsViaWMI
        foreach ($wmiInstall in $wmiInstallations) {
            # Convert WMI result to standard format
            $testResult = Test-VSInstallation -InstallPath $wmiInstall.InstallationPath
            if ($testResult.IsValid) {
                $allInstallations += [PSCustomObject]@{
                    InstallPath = $wmiInstall.InstallationPath
                    Version = $wmiInstall.InstallationVersion
                    DisplayName = $wmiInstall.DisplayName
                    ProductId = "WMI-Detection"
                    HasCppTools = $testResult.HasCppTools
                    DevShellPath = $wmiInstall.DevShellPath
                    DevCmdPath = $testResult.DevCmdPath
                    MSBuildPath = $wmiInstall.ProductPath
                    Source = $wmiInstall.Source
                }
            }
        }
    }

    # Remove duplicates and sort
    return $allInstallations |
        Sort-Object InstallPath -Unique |
        Sort-Object @{
            Expression = { $_.Version }; Descending = $true
        }, @{
            Expression = { $_.HasCppTools }; Descending = $true
        }
}

<#
.SYNOPSIS
    Gets vcpkg installation information and configuration for LuaRocks.

.PARAMETER Architecture
    Target architecture

.OUTPUTS
    Hashtable containing vcpkg information and LuaRocks configuration
#>
function Get-VcpkgConfiguration {
    [CmdletBinding()]
    param(
        [string]$Architecture = 'amd64'
    )

    $vcpkg = Find-VcpkgInstallation -Architecture $Architecture

    $result = @{
        Found = $vcpkg.Found
        VcpkgInfo = $vcpkg
        LuaRocksConfig = ''
        EnvironmentVars = @{}
    }

    if ($vcpkg.Found) {
        Write-Verbose "Generating vcpkg configuration for LuaRocks"

        # Generate LuaRocks configuration
        $vcpkgIncludeEscaped = $vcpkg.IncludePath.TrimEnd('\').Replace('\', '\\')
        $vcpkgLibEscaped = $vcpkg.LibPath.TrimEnd('\').Replace('\', '\\')
        $vcpkgInstalledEscaped = $vcpkg.InstalledPath.TrimEnd('\').Replace('\', '\\')

        $result.LuaRocksConfig = @"

-- vcpkg integration for C library dependencies
variables = {
    CPPFLAGS = "/I`"$vcpkgIncludeEscaped`"",
    LIBFLAG = "/LIBPATH:`"$vcpkgLibEscaped`"",
    LDFLAGS = "/LIBPATH:`"$vcpkgLibEscaped`"",
    HISTORY_DIR = "$vcpkgInstalledEscaped",
    HISTORY_INCDIR = "$vcpkgIncludeEscaped",
    HISTORY_LIBDIR = "$vcpkgLibEscaped"
}

-- Additional library search paths
external_deps_dirs = {
    "$vcpkgInstalledEscaped"
}
"@

        # Generate environment variables
        $result.EnvironmentVars = @{
            'VCPKG_ROOT' = $vcpkg.RootPath
            'VCPKG_DEFAULT_TRIPLET' = $vcpkg.Triplet
            'CMAKE_TOOLCHAIN_FILE' = Join-Path $vcpkg.RootPath "scripts\buildsystems\vcpkg.cmake"
        }
    }

    return $result
}

<#
.SYNOPSIS
    Clears the detection cache (useful for testing or when installations change).
#>
function Clear-VSDetectionCache {
    [CmdletBinding()]
    param()

    $script:VSDetectionCache.Clear()
    $script:VcpkgDetectionCache.Clear()
    Write-Verbose "VS and vcpkg detection caches cleared"
}


# WMI-BASED DETECTION (LAST RESORT)
# ==================================================================================

<#
.SYNOPSIS
    Uses WMI to detect Visual Studio installations as a last resort.

.PARAMETER Architecture
    Target architecture

.OUTPUTS
    Array of detected VS installations
#>
function Get-VSInstallationsViaWMI {
    param(
        [string]$Architecture = 'amd64'
    )

    Write-Verbose "Attempting WMI-based Visual Studio detection as last resort..."

    $installations = @()

    try {
        # Use timeout to prevent hanging
        $timeout = 15 # seconds
        $job = Start-Job -ScriptBlock {
            param($Architecture)

            $results = @()

            # Query installed programs
            $vsPrograms = Get-CimInstance -ClassName Win32_Product -ErrorAction SilentlyContinue |
                          Where-Object { $_.Name -like "*Visual Studio*" -or $_.Name -like "*BuildTools*" }

            foreach ($program in $vsPrograms) {
                $name = $program.Name
                $version = $program.Version
                $installLocation = $program.InstallLocation

                # Skip if no install location
                if (-not $installLocation -or -not (Test-Path $installLocation)) {
                    continue
                }

                # Try to determine VS version from name
                $vsVersion = $null
                $displayName = $name

                if ($name -match "2022") {
                    $vsVersion = "17.0"
                } elseif ($name -match "2019") {
                    $vsVersion = "16.0"
                } elseif ($name -match "2017") {
                    $vsVersion = "15.0"
                } elseif ($name -match "2015") {
                    $vsVersion = "14.0"
                } elseif ($name -match "2013") {
                    $vsVersion = "12.0"
                } elseif ($name -match "2012") {
                    $vsVersion = "11.0"
                } elseif ($name -match "2010") {
                    $vsVersion = "10.0"
                }

                # Try to find MSBuild
                $msbuildPath = $null
                $possibleMSBuildPaths = @(
                    "MSBuild\Current\Bin\MSBuild.exe",
                    "MSBuild\$vsVersion\Bin\MSBuild.exe",
                    "MSBuild\15.0\Bin\MSBuild.exe",
                    "MSBuild\14.0\Bin\MSBuild.exe",
                    "MSBuild\12.0\Bin\MSBuild.exe",
                    "MSBuild\Bin\MSBuild.exe"
                )

                foreach ($msbuildRelPath in $possibleMSBuildPaths) {
                    $testPath = Join-Path $installLocation $msbuildRelPath
                    if (Test-Path $testPath) {
                        $msbuildPath = $testPath
                        break
                    }
                }

                # Try to find vcvarsall.bat
                $vcvarsallPath = $null
                $possibleVcvarsPaths = @(
                    "VC\Auxiliary\Build\vcvarsall.bat",
                    "VC\vcvarsall.bat",
                    "Common7\Tools\VsDevCmd.bat"
                )

                foreach ($vcvarsRelPath in $possibleVcvarsPaths) {
                    $testPath = Join-Path $installLocation $vcvarsRelPath
                    if (Test-Path $testPath) {
                        $vcvarsallPath = $testPath
                        break
                    }
                }

                # Try to find DevShell
                $devShellPath = $null
                $possibleDevShellPaths = @(
                    "Common7\Tools\Launch-VsDevShell.ps1",
                    "Common7\Tools\VsDevCmd.bat"
                )

                foreach ($devShellRelPath in $possibleDevShellPaths) {
                    $testPath = Join-Path $installLocation $devShellRelPath
                    if (Test-Path $testPath) {
                        $devShellPath = $testPath
                        break
                    }
                }

                # Only add if we found at least one build tool
                if ($msbuildPath -or $vcvarsallPath -or $devShellPath) {
                    $results += @{
                        InstallationPath = $installLocation
                        DisplayName = $displayName
                        InstallationVersion = $version
                        ProductPath = $msbuildPath
                        VcvarsallPath = $vcvarsallPath
                        DevShellPath = $devShellPath
                        Architecture = $Architecture
                        Source = "WMI"
                    }
                }
            }

            return $results
        } -ArgumentList $Architecture

        # Wait for job completion with timeout
        $completed = Wait-Job -Job $job -Timeout $timeout

        if ($completed) {
            $installations = Receive-Job -Job $job
            Remove-Job -Job $job

            if ($installations -and $installations.Count -gt 0) {
                Write-Verbose "WMI detection found $($installations.Count) Visual Studio installation(s)"
                return $installations
            }
        } else {
            Write-Verbose "WMI detection timed out after $timeout seconds"
            Stop-Job -Job $job
            Remove-Job -Job $job
        }

    } catch {
        Write-Verbose "WMI detection failed: $($_.Exception.Message)"
    }

    # Additional WMI query for services (sometimes more reliable)
    try {
        $timeout = 10 # seconds
        $job = Start-Job -ScriptBlock {
            $results = @()

            # Query for Visual Studio related services
            $vsServices = Get-CimInstance -ClassName Win32_Service -ErrorAction SilentlyContinue |
                          Where-Object { $_.Name -like "*VisualStudio*" -or $_.Name -like "*VSStandardCollectorService*" }

            foreach ($service in $vsServices) {
                $servicePath = $service.PathName
                if ($servicePath -and $servicePath -match '"?([^"]*Visual Studio[^"]*)"?') {
                    $vsPath = $matches[1]
                    $vsRoot = Split-Path (Split-Path $vsPath -Parent) -Parent

                    if ($vsRoot -and (Test-Path $vsRoot)) {
                        # Try to find version info
                        $versionFile = Join-Path $vsRoot "Common7\IDE\devenv.exe"
                        $version = "Unknown"

                        if (Test-Path $versionFile) {
                            try {
                                $fileVersion = (Get-ItemProperty $versionFile).VersionInfo.ProductVersion
                                if ($fileVersion) {
                                    $version = $fileVersion
                                }
                            } catch {
                                # Ignore version detection errors
                            }
                        }

                        $results += @{
                            InstallationPath = $vsRoot
                            DisplayName = "Visual Studio (from service)"
                            InstallationVersion = $version
                            ProductPath = $null
                            VcvarsallPath = $null
                            DevShellPath = $null
                            Architecture = "amd64"
                            Source = "WMI-Service"
                        }
                    }
                }
            }

            return $results
        }

        $completed = Wait-Job -Job $job -Timeout $timeout

        if ($completed) {
            $serviceResults = Receive-Job -Job $job
            Remove-Job -Job $job

            if ($serviceResults -and $serviceResults.Count -gt 0) {
                $installations += $serviceResults
                Write-Verbose "WMI service detection found $($serviceResults.Count) additional installation(s)"
            }
        } else {
            Write-Verbose "WMI service detection timed out after $timeout seconds"
            Stop-Job -Job $job
            Remove-Job -Job $job
        }

    } catch {
        Write-Verbose "WMI service detection failed: $($_.Exception.Message)"
    }

    if ($installations.Count -gt 0) {
        Write-Verbose "Total WMI-based detections: $($installations.Count)"
    } else {
        Write-Verbose "No Visual Studio installations found via WMI"
    }

    return $installations
}

# ==================================================================================
# MODULE EXPORTS
# ==================================================================================

# Export all public functions
Export-ModuleMember -Function @(
    'Initialize-VisualStudioEnvironment',
    'Get-VisualStudioInstallations',
    'Get-VcpkgConfiguration',
    'Get-VSPathConfig',
    'Set-VSPathConfig',
    'Clear-VSDetectionCache'
)

# Export useful utility functions
Export-ModuleMember -Function @(
    'ConvertTo-VSArchitecture',
    'Test-VSInstallation',
    'Find-VcpkgInstallation',
    'Get-VSInstallationsViaWMI'
)

