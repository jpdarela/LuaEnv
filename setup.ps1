# This is free and unencumbered software released into the public domain.
# For more details, see the LICENSE file in the project root.

#Requires -Version 7
<#
.SYNOPSIS
    LuaEnv Bootstrap Setup Script

.DESCRIPTION
    Bootstrap script for LuaEnv installation. Downloads embedded Python if needed
    and manages the complete LuaEnv installation lifecycle.

.PARAMETER BuildCli
    Build the CLI application before installation. Runs build_cli.ps1 with auto-detection.

.PARAMETER Python
    Force install/reinstall embedded Python only. Does not run installation.

.PARAMETER LuaConfig
    Build the luaconfig.exe tool before installation. Compiles the C program for pkg-config support.

.PAR            # Step 3: Run LuaEnv installation
            if (-not (Invoke-LuaEnvInstall @("--force", "--arch", $arch))) {
                Write-Err "LuaEnv installation failed"
                exit 1
            }

            # Step 4: Offer to add LuaEnv to PATH if not already there
            $luaEnvBinPath = Join-Path $env:USERPROFILE ".luaenv\bin"

            if (-not (Test-PathEnvironmentVariable -PathToCheck $luaEnvBinPath)) {
                Write-Host ""
                Write-Info "LuaEnv is not in your PATH environment variable."
                $addToPath = Read-Host "Would you like to add LuaEnv to your PATH? (Y/n)"

                if ($addToPath -eq "" -or $addToPath.ToLower() -eq "y") {
                    if (Add-ToPathEnvironmentVariable -PathToAdd $luaEnvBinPath) {
                        Write-OK "LuaEnv added to your PATH environment variable"
                        Write-Info "You may need to restart your terminal for the PATH change to take effect"
                    } else {
                        Write-Warn "Failed to add LuaEnv to PATH. You can add it manually later."
                    }
                } else {
                    Write-Info "LuaEnv was not added to PATH"
                    Write-Info "To use LuaEnv, you'll need to manually add $luaEnvBinPath to your PATH"
                }
            } else {
                Write-OK "LuaEnv is already in your PATH environment variable"
            }

            Write-OK "LuaEnv installation completed successfully!"Bootstrap
    Install pre-built components only, skipping CLI build. Downloads embedded Python,
    installs scripts and CLI binaries from win64 folder. Use for deployments where
    build tools are not available on the target system.

.PARAMETER Reset
    DANGEROUS: Completely removes existing installation and recreates it.
    This will delete your ~/.luaenv folder and all configurations.

.PARAMETER Help
    Show detailed help information about this script and LuaEnv.

.EXAMPLE
    .\setup.ps1
    Check for Python, install if needed, then run LuaEnv installation

.EXAMPLE
    .\setup.ps1 -BuildCli
    Build CLI application then run normal installation

.EXAMPLE
    .\setup.ps1 -LuaConfig
    Build luaconfig tool then run normal installation

.EXAMPLE
    .\setup.ps1 -Python
    Force download/install embedded Python only

.EXAMPLE
    .\setup.ps1 -Bootstrap
    Install pre-built components only (for deployment to systems without build tools)

.EXAMPLE
    .\setup.ps1 -Reset
    WARNING: Complete reset - removes ~/.luaenv and recreates it

.EXAMPLE
    .\setup.ps1 -Help
    Show detailed help information
#>

[CmdletBinding(DefaultParameterSetName='Default')]
param(
    [Parameter(ParameterSetName='BuildCli')]
    [switch]$BuildCli,

    [Parameter(ParameterSetName='LuaConfig')]
    [switch]$LuaConfig,

    [Parameter(ParameterSetName='Python')]
    [switch]$Python,

    [Parameter(ParameterSetName='Bootstrap')]
    [switch]$Bootstrap,

    [Parameter(ParameterSetName='Reset')]
    [switch]$Reset,

    [Parameter(ParameterSetName='Help')]
    [switch]$Help
)

$ErrorActionPreference = "Stop"

# Configuration
$PythonVersion = "3.13.5"

# Function to detect current architecture
function Get-HostArchitecture {
    $arch = $env:PROCESSOR_ARCHITECTURE
    switch ($arch) {
        "AMD64" { return "win64" }
        "ARM64" { return "win-arm64" }
        "x86"   { return "win-x86" }
        default {
            Write-Warning "Unknown architecture: $arch, defaulting to win64"
            return "win64"
        }
    }
}


# Function to get the appropriate Python URL based on architecture
function Get-PythonUrlForArchitecture {
    $arch = Get-HostArchitecture
    switch ($arch) {
        "win64" { return "https://www.python.org/ftp/python/$PythonVersion/python-$PythonVersion-embed-amd64.zip" }
        "win-arm64" { return "https://www.python.org/ftp/python/$PythonVersion/python-$PythonVersion-embed-arm64.zip" }
        "win-x86" { return "https://www.python.org/ftp/python/$PythonVersion/python-$PythonVersion-embed-win32.zip" }
        default { return "https://www.python.org/ftp/python/$PythonVersion/python-$PythonVersion-embed-amd64.zip" } # Default to amd64
    }
}

# Set paths and URLs
$PythonUrl = Get-PythonUrlForArchitecture
$ProjectRoot = $PSScriptRoot
$PythonDir = Join-Path $ProjectRoot "python"
$PythonExe = Join-Path $PythonDir "python.exe"
$TempZip = Join-Path $ProjectRoot "python-temp.zip"
$InstallScript = Join-Path $ProjectRoot "install.py"
$BuildCliScript = Join-Path $ProjectRoot "build_cli.ps1"

# Logging functions
function Write-Info($msg) { Write-Host "[INFO] $msg" -ForegroundColor White }
function Write-OK($msg) { Write-Host "[OK] $msg" -ForegroundColor Green }
function Write-Err($msg) { Write-Host "[ERROR] $msg" -ForegroundColor Red }
function Write-Warn($msg) { Write-Host "[WARNING] $msg" -ForegroundColor Yellow }

function Show-Help {
    Write-Host @"

LuaEnv Bootstrap Setup Script
=============================

This script manages the complete LuaEnv installation process, including downloading
embedded Python and setting up the LuaEnv environment.

USAGE:
    .\setup.ps1                 # Normal installation
    .\setup.ps1 -BuildCli       # Build CLI then install
    .\setup.ps1 -LuaConfig      # Build LuaConfig tool then install
    .\setup.ps1 -Bootstrap      # Install pre-built components only
    .\setup.ps1 -Python         # Python setup only
    .\setup.ps1 -Reset          # Complete reset (DANGEROUS)
    .\setup.ps1 -Help           # Show this help

MODES:

  DEFAULT (no switches)
    • Check if embedded Python exists
    • Download and install Python if missing
    • Run install.py to create ~/.luaenv structure
    • Install PowerShell scripts and CLI binaries
    • Configure backend with embedded Python paths

  -BuildCli
    • Build the CLI application using build_cli.ps1 (auto-detect architecture)
    • Includes JIT warm-up for optimal first-run performance
    • Then perform normal installation steps
    • Ensures you have the latest CLI build before installation
    • Equivalent to running .\build_cli.ps1 -WarmUp then .\setup.ps1

  -Bootstrap
    • For deployment to systems without build tools (.NET SDK)
    • Downloads and extracts architecture-specific embedded Python (ARM64, x64, x86)
    • Installs scripts and pre-built CLI binaries directly
    • Skips all build steps (CLI, LuaConfig)
    • Uses architecture-specific folder (win64, win-arm64, win-x86) for CLI binaries
    • Automatically detects host architecture and uses appropriate binaries
    • Useful for distributing to end users without development environment

  -LuaConfig
    • Build the LuaConfig tool (C program for pkg-config support)
    • Compiles luaconfig.c with security and optimization flags
    • Then perform normal installation steps
    • Ensures you have the LuaConfig support for pkg-config functionality
    • Useful for C/C++ development with Lua

  -Python
    • Force download/install embedded Python
    • Overwrites existing Python installation
    • Does NOT run install.py
    • Use this to update Python version or fix corrupted installation

  -Reset (DANGEROUS)
    • Calls install.py --reset to remove ~/.luaenv folder
    • Completely deletes your LuaEnv installation and configurations
    • Then recreates everything from scratch
    • WARNING: This will lose all your Lua installations and settings

  -Help
    • Shows this detailed help information

WHAT GETS INSTALLED:

  1. Embedded Python ($PythonVersion)
     Location: ./python/python.exe
     Purpose: Self-contained Python for running LuaEnv backend

  2. LuaEnv Directory Structure
     Location: ~/.luaenv/
     Contents:
       • bin/                   # Scripts and CLI binaries
       • registry.json          # Installation registry
       • installations/         # Lua version installations
       • environments/          # Virtual environments
       • cache/                # Download cache

  3. Scripts and Tools
     • PowerShell scripts (setenv.ps1, luaenv.ps1)
     • Backend configuration (backend.config JSON)

AFTER INSTALLATION:
    Add to PATH: ~/.luaenv/bin
    Then use: luaenv.ps1 status  (or luaenv status if in PATH)

REQUIREMENTS:
    • Windows PowerShell 5.1 or later
    • Internet connection for Python download
    • Administrator rights not required

TROUBLESHOOTING:
    • If Python download fails: Check internet connection
    • If installation fails: Try .\setup.ps1 -Reset
    • If CLI doesn't work: Ensure ~/.luaenv/bin is in PATH
    • For help: Run .\setup.ps1 -Help

"@ -ForegroundColor Cyan
}

function Invoke-CliBuild {
    if (-not (Test-Path $BuildCliScript)) {
        Write-Err "Build script not found: $BuildCliScript"
        return $false
    }

    # Check if .NET SDK is installed and available in the path
    $dotnetAvailable = $null
    $requiredVersion = 9

    try {
        $dotnetVersion = (dotnet --version 2>$null)
        if ($LASTEXITCODE -eq 0 -and $dotnetVersion) {
            $dotnetAvailable = $true
            # Extract major version number
            $majorVersion = [int]($dotnetVersion.Split('.')[0])
            if ($majorVersion -lt $requiredVersion) {
                Write-Warn ".NET SDK version $dotnetVersion found, but version $requiredVersion or higher is required"
                Write-Info "Please update your .NET SDK from https://dotnet.microsoft.com/download"
                return $false
            }
        } else {
            $dotnetAvailable = $false
        }
    } catch {
        $dotnetAvailable = $false
    }

    if (-not $dotnetAvailable) {
        Write-Err ".NET SDK not found in PATH"
        Write-Warn "To build the CLI application, you need .NET SDK $requiredVersion or higher"
        Write-Info "Options to fix this issue:"
        Write-Info "  1. Install .NET SDK from https://dotnet.microsoft.com/download"
        Write-Info "  2. Ensure the 'dotnet' command is in your PATH"
        Write-Info "  3. Restart your terminal after installation"
        return $false
    }

    # Get the appropriate architecture for the build
    $targetArch = Get-HostArchitecture

    Write-Info "CLI Build"
    Write-Info "========="
    Write-Info "Running: .\build_cli.ps1 -Target $targetArch -SelfContained -WarmUp"

    try {
        # Pass the detected architecture to the build script
        & $BuildCliScript -Target $targetArch -SelfContained -WarmUp
        $exitCode = $LASTEXITCODE
        if ($null -eq $exitCode) { $exitCode = 0 }

        if ($exitCode -eq 0) {
            Write-OK "CLI build and warm-up completed successfully for architecture: $targetArch"
            return $true
        } else {
            # Check if the error is likely due to .NET SDK issues
            if ($exitCode -eq 9009) {  # Command not found error
                Write-Err "Build command failed: Could not execute a required .NET command"
                Write-Warn "This could indicate a problem with your .NET SDK installation"
                Write-Info "Please ensure you have .NET SDK $requiredVersion or higher installed"
                Write-Info "Download from: https://dotnet.microsoft.com/download"
            } else {
                Write-Err "CLI build failed with exit code: $exitCode for architecture: $targetArch"
            }
            return $false
        }

    } catch {
        Write-Err "Failed to run CLI build: $_"
        Write-Info "If the error is related to missing .NET SDK tools, please ensure you have"
        Write-Info ".NET SDK version $requiredVersion or higher installed"
        return $false
    }
}

function Invoke-LuaConfigBuild {
    # Source file path
    $luaConfigSourcePath = Join-Path $ProjectRoot "luaconfig.c"
    $luaConfigExe = Join-Path $ProjectRoot "luaconfig.exe"

    # Verify the source file exists
    if (-not (Test-Path $luaConfigSourcePath)) {
        Write-Err "LuaConfig source file not found: $luaConfigSourcePath"
        return $false
    }

    Write-Info "LuaConfig Build"
    Write-Info "==============="
    Write-Info "Compiling luaconfig.c with optimization flags..."

    try {
        # Change to project directory to ensure proper execution context
        $currentLocation = Get-Location
        Set-Location -Path $ProjectRoot

        # Execute cl.exe directly in the current PowerShell session
        # This ensures we use the cl.exe that's already in the environment
        # if the compiled executable is already in the folder, remove it.
        $luaConfigExe = Join-Path $ProjectRoot "luaconfig.exe"
        if (Test-Path $luaConfigExe) {
            Write-Info "Removing existing luaconfig.exe..."
            Remove-Item $luaConfigExe -Force
        }

        # Try to compile with all necessary libraries
        # The advapi32.lib is needed for security functions
        Write-Info "Compiling luaconfig.c with release optimizations..."
        cl.exe luaconfig.c /O2 /Ot /GL /Gy /Fe:luaconfig.exe /link /OPT:REF /OPT:ICF /LTCG /NXCOMPAT /DYNAMICBASE advapi32.lib
        # cl.exe /D_DEBUG luaconfig.c /O2 /Ot /GL /Gy /Fe:luaconfig.exe /link /OPT:REF /OPT:ICF /LTCG /NXCOMPAT /DYNAMICBASE advapi32.lib
        $exitCode = $LASTEXITCODE

        # Restore original location
        Set-Location -Path $currentLocation

        if ($exitCode -eq 0) {
                Write-OK "LuaConfig tool built successfully"
        } else {
            Write-Err "LuaConfig build failed with exit code: $exitCode"
            return $false
        }
    } catch {
        Write-Err "Failed to compile luaconfig.c: $_"
        Write-Info "Error details: $($_.Exception.Message)"
        Write-Info "If the compiler wasn't found, please run this script from a Visual Studio Developer Command Prompt"
        return $false
    }
}

function Test-EmbeddedPython {
    if (-not (Test-Path $PythonExe)) {
        return $false
    }

    try {
        $version = & $PythonExe --version 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-OK "Embedded Python ready: $version"
            return $true
        }
    } catch {
        Write-Warn "Python executable found but not working"
    }

    return $false
}

# Function to check if LuaEnv path is already in the user's PATH
function Test-PathEnvironmentVariable {
    param (
        [string]$PathToCheck
    )

    # Get the current user's PATH environment variable
    $currentPath = [Environment]::GetEnvironmentVariable("PATH", "User")

    # Check if the path is already in PATH (case insensitive)
    $pathEntries = $currentPath -split ";"
    foreach ($entry in $pathEntries) {
        if ($entry -eq $PathToCheck) {
            return $true
        }
    }

    return $false
}

# Function to add LuaEnv path to user's PATH environment variable
function Add-ToPathEnvironmentVariable {
    param (
        [string]$PathToAdd
    )

    try {
        # Get the current user's PATH
        $currentPath = [Environment]::GetEnvironmentVariable("PATH", "User")

        # Add the new path
        $newPath = $currentPath + ";" + $PathToAdd

        # Set the updated PATH
        [Environment]::SetEnvironmentVariable("PATH", $newPath, "User")

        # Refresh current session's PATH as well
        $env:PATH = $env:PATH + ";" + $PathToAdd

        return $true
    } catch {
        Write-Err "Failed to update PATH environment variable: $_"
        return $false
    }
}

function Install-EmbeddedPython {
    param([switch]$ForceReinstall)

    Write-Info "Embedded Python Setup"
    Write-Info "====================="

    # Get architecture and show it
    $arch = Get-HostArchitecture
    Write-Info "Host architecture: $arch"

    # Always refresh URL in case of architecture changes
    $script:PythonUrl = Get-PythonUrlForArchitecture

    # Show which Python package we're using
    $urlParts = $PythonUrl -split "/"
    $packageName = $urlParts[-1]
    Write-Info "Using Python package: $packageName"

    # Check if already installed
    if ((Test-EmbeddedPython) -and (-not $ForceReinstall)) {
        Write-OK "Embedded Python already available"
        return $true
    }

    if ($ForceReinstall) {
        Write-Info "Force reinstalling embedded Python..."
    }

    # Remove existing if force
    if ($ForceReinstall -and (Test-Path $PythonDir)) {
        Write-Info "Removing existing python installation..."
        Remove-Item $PythonDir -Recurse -Force
    }

    # Clean up temp files
    if (Test-Path $TempZip) {
        Remove-Item $TempZip -Force
    }

    try {
        # Download
        Write-Info "Downloading Python $PythonVersion for $arch..."
        Invoke-WebRequest -Uri $PythonUrl -OutFile $TempZip -UseBasicParsing

        $fileSize = [math]::Round((Get-Item $TempZip).Length / 1MB, 1)
        Write-OK "Downloaded ($fileSize MB)"

        # Extract
        Write-Info "Extracting to: $PythonDir"
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        [System.IO.Compression.ZipFile]::ExtractToDirectory($TempZip, $PythonDir)
        Write-OK "Extracted successfully"

        # Cleanup
        Remove-Item $TempZip -Force

        # Verify
        if (Test-EmbeddedPython) {
            Write-OK "Embedded Python installation complete"
            return $true
        } else {
            Write-Err "Python installation failed verification"
            return $false
        }

    } catch {
        Write-Err "Failed to install Python: $_"
        # Cleanup on error
        if (Test-Path $TempZip) { Remove-Item $TempZip -Force }
        if (Test-Path $PythonDir) { Remove-Item $PythonDir -Recurse -Force }
        return $false
    }
}

function Invoke-LuaEnvInstall {
    param([string[]]$Arguments)

    if (-not (Test-Path $InstallScript)) {
        Write-Err "Install script not found: $InstallScript"
        return $false
    }

    if (-not (Test-EmbeddedPython)) {
        Write-Err "Embedded Python not available"
        return $false
    }

    Write-Info "LuaEnv Installation"
    Write-Info "==================="

    $argsDisplay = if ($Arguments.Count -gt 0) { $Arguments -join ' ' } else { "(default)" }
    Write-Info "Running: python install.py $argsDisplay"

    try {
        $allArgs = @($InstallScript) + $Arguments
        & $PythonExe @allArgs

        $exitCode = $LASTEXITCODE
        if ($null -eq $exitCode) { $exitCode = 0 }

        if ($exitCode -eq 0) {
            return $true
        } else {
            Write-Err "Installation failed with exit code: $exitCode"
            return $false
        }

    } catch {
        Write-Err "Failed to run installation: $_"
        return $false
    }
}

# Main execution logic
Write-Info "LuaEnv Bootstrap Setup"
Write-Info "======================"

try {
    switch ($PSCmdlet.ParameterSetName) {
        'Help' {
            Show-Help
            exit 0
        }

        'Bootstrap' {
            Write-Info "Mode: Bootstrap installation (pre-built components only)"

            # Get host architecture
            $arch = Get-HostArchitecture
            Write-Info "Host architecture: $arch"

            # Step 1: Ensure Python is available (install if missing)
            if (-not (Install-EmbeddedPython)) {
                Write-Err "Failed to setup embedded Python"
                exit 1
            }

            # Step 2: Verify architecture-specific CLI binaries directory exists
            $cliSourceDir = Join-Path $ProjectRoot $arch
            if (-not (Test-Path $cliSourceDir)) {
                Write-Err "CLI binaries directory not found for $arch``: $cliSourceDir"
                Write-Info "Bootstrap mode requires pre-built CLI binaries in $arch folder"

                # Check if win64 exists as a fallback
                $fallbackDir = Join-Path $ProjectRoot "win64"
                if ($arch -ne "win64" -and (Test-Path $fallbackDir)) {
                    Write-Warn "Falling back to win64 binaries. These may not work correctly on $arch."
                    $cliSourceDir = $fallbackDir
                } else {
                    exit 1
                }
            }

            # Step 3: Run LuaEnv installation with the force flag
            # This will install both scripts and CLI binaries in one step
            if (-not (Invoke-LuaEnvInstall @("--force", "--arch", $arch))) {
                Write-Err "Bootstrap installation failed"
                exit 1
            }

            # Step 4: Offer to add LuaEnv to PATH if not already there
            $luaEnvBinPath = Join-Path $env:USERPROFILE ".luaenv\bin"

            if (-not (Test-PathEnvironmentVariable -PathToCheck $luaEnvBinPath)) {
                Write-Host ""
                Write-Info "LuaEnv is not in your PATH environment variable."
                $addToPath = Read-Host "Would you like to add LuaEnv to your PATH? (Y/n)"

                if ($addToPath -eq "" -or $addToPath.ToLower() -eq "y") {
                    if (Add-ToPathEnvironmentVariable -PathToAdd $luaEnvBinPath) {
                        Write-OK "LuaEnv added to your PATH environment variable"
                        Write-Info "You may need to restart your terminal for the PATH change to take effect"
                    } else {
                        Write-Warn "Failed to add LuaEnv to PATH. You can add it manually later."
                    }
                } else {
                    Write-Info "LuaEnv was not added to PATH"
                    Write-Info "To use LuaEnv, you'll need to manually add $luaEnvBinPath to your PATH"
                }
            } else {
                Write-OK "LuaEnv is already in your PATH environment variable"
            }

            Write-OK "Bootstrap installation completed successfully!"
        }

        'BuildCli' {
            Write-Info "Mode: Build CLI then install"
            $arch = Get-HostArchitecture

            # Step 1: Build CLI application
            if (-not (Invoke-CliBuild)) {
                Write-Err "Failed to build CLI application"
                exit 1
            }

            # Step 2: Ensure Python is available (install if missing)
            if (-not (Install-EmbeddedPython)) {
                Write-Err "Failed to setup embedded Python"
                exit 1
            }

            # Step 3: Run LuaEnv installation
            if (-not (Invoke-LuaEnvInstall @("--force", "--arch", $arch))) {
                Write-Err "LuaEnv installation failed"
                exit 1
            }

            Write-OK "CLI build and LuaEnv installation completed successfully!"
        }

        'LuaConfig' {
            Write-Info "Mode: LuaConfig build then install"
            $arch = Get-HostArchitecture

            # Step 1: Build LuaConfig tool
            if (-not (Invoke-LuaConfigBuild)) {
                Write-Err "Failed to build LuaConfig tool"
                exit 1
            }

            # Step 2: Ensure Python is available (install if missing)
            if (-not (Install-EmbeddedPython)) {
                Write-Err "Failed to setup embedded Python"
                exit 1
            }

            # Step 3: Run LuaEnv installation
            if (-not (Invoke-LuaEnvInstall @("--force", "--arch", $arch))) {
                Write-Err "LuaEnv installation failed"
                exit 1
            }

            Write-OK "LuaConfig build completed successfully!"
        }

        'Python' {
            Write-Info "Mode: Python installation only"
            if (-not (Install-EmbeddedPython -ForceReinstall)) {
                Write-Err "Failed to install embedded Python"
                exit 1
            }
            Write-OK "Python installation completed successfully!"
            Write-Info "Run '.\setup.ps1' to complete LuaEnv installation."
            exit 0
        }

        'Reset' {
            Write-Warn "DANGER: Reset mode will completely remove your LuaEnv installation!"
            Write-Host "This will delete:" -ForegroundColor Yellow
            Write-Host "  • ~/.luaenv folder and all contents" -ForegroundColor Yellow
            Write-Host "  • All Lua installations and configurations" -ForegroundColor Yellow
            Write-Host "  • All virtual environments" -ForegroundColor Yellow
            Write-Host ""

            $confirm = Read-Host "Type 'RESET' to confirm complete removal"
            if ($confirm.ToUpper() -ne 'RESET') {
                Write-Info "Reset cancelled by user"
                exit 0
            }

            Write-Info "Mode: Complete reset and reinstall"
            $arch = Get-HostArchitecture

            # Ensure Python is available
            if (-not (Install-EmbeddedPython)) {
                Write-Err "Failed to setup embedded Python"
                exit 1
            }

            # Reset installation
            Write-Warn "Removing existing LuaEnv installation..."
            if (-not (Invoke-LuaEnvInstall @("--reset"))) {
                Write-Err "Failed to reset installation"
                exit 1
            }

            # Recreate installation
            Write-Info "Recreating LuaEnv installation..."
            if (-not (Invoke-LuaEnvInstall @("--force", "--arch", $arch))) {
                Write-Err "Failed to recreate installation"
                exit 1
            }

            Write-OK "Complete reset and reinstall finished successfully!"
        }

        'Default' {
            Write-Info "Mode: Standard installation"
            $arch = Get-HostArchitecture

            # Step 1: Ensure Python is available (install if missing)
            if (-not (Install-EmbeddedPython)) {
                Write-Err "Failed to setup embedded Python"
                exit 1
            }

            # Step 2: Run LuaEnv installation
            if (-not (Invoke-LuaEnvInstall @("--force", "--arch", $arch))) {
                Write-Err "LuaEnv installation failed"
                exit 1
            }

            Write-OK "LuaEnv installation completed successfully!"
        }
    }

    # Final success message (for modes that complete installation)
    if ($PSCmdlet.ParameterSetName -in @('Default', 'Reset', 'BuildCli', 'LuaConfig', 'Bootstrap')) {
        $luaEnvBinPath = Join-Path $env:USERPROFILE ".luaenv\bin"
        $inPath = Test-PathEnvironmentVariable -PathToCheck $luaEnvBinPath

        Write-Info ""
        Write-OK "LuaEnv is now ready to use!"
        Write-Info "Next steps:"

        if (-not $inPath) {
            Write-Info "  1. Add to PATH: ~/.luaenv/bin"
            Write-Info "     Or run this script with -Bootstrap to be prompted to add to PATH"
            Write-Info "  2. Try: luaenv.ps1 status  (or luaenv status if in PATH)"
        } else {
            Write-Info "  1. Try: luaenv status"
            Write-Info "     (LuaEnv is already in your PATH)"
        }

        Write-Info "  3. For help: luaenv.ps1 --help"
    }

} catch {
    Write-Err "Setup failed: $_"
    Write-Info "For help, run: .\setup.ps1 -Help"
    exit 1
}