#Requires -Version 5.1
<#
.SYNOPSIS
    LuaEnv Bootstrap Setup Script

.DESCRIPTION
    Bootstrap script for LuaEnv installation. Downloads embedded Python if needed
    and manages the complete LuaEnv installation lifecycle.

.PARAMETER Python
    Force install/reinstall embedded Python only. Does not run installation.

.PARAMETER Reset
    DANGEROUS: Completely removes existing installation and recreates it.
    This will delete your ~/.luaenv folder and all configurations.

.PARAMETER Help
    Show detailed help information about this script and LuaEnv.

.EXAMPLE
    .\setup.ps1
    Check for Python, install if needed, then run LuaEnv installation

.EXAMPLE
    .\setup.ps1 -Python
    Force download/install embedded Python only

.EXAMPLE
    .\setup.ps1 -Reset
    WARNING: Complete reset - removes ~/.luaenv and recreates it

.EXAMPLE
    .\setup.ps1 -Help
    Show detailed help information
#>

[CmdletBinding(DefaultParameterSetName='Default')]
param(
    [Parameter(ParameterSetName='Python')]
    [switch]$Python,

    [Parameter(ParameterSetName='Reset')]
    [switch]$Reset,

    [Parameter(ParameterSetName='Help')]
    [switch]$Help
)

$ErrorActionPreference = "Stop"

# Configuration
$PythonVersion = "3.13.5"
$PythonUrl = "https://www.python.org/ftp/python/$PythonVersion/python-$PythonVersion-embed-amd64.zip"
$ProjectRoot = $PSScriptRoot
$PythonDir = Join-Path $ProjectRoot "python"
$PythonExe = Join-Path $PythonDir "python.exe"
$TempZip = Join-Path $ProjectRoot "python-temp.zip"
$InstallScript = Join-Path $ProjectRoot "install.py"

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
     • PowerShell scripts (use-lua.ps1, setenv.ps1)
     • CLI wrapper (luaenv.cmd)
     • Backend configuration (backend.config JSON)

AFTER INSTALLATION:
    Add to PATH: ~/.luaenv/bin
    Then use: luaenv status

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

function Install-EmbeddedPython {
    param([switch]$ForceReinstall)

    Write-Info "Embedded Python Setup"
    Write-Info "====================="

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
        Write-Info "Downloading Python $PythonVersion embedded..."
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
            if ($confirm -ne 'RESET') {
                Write-Info "Reset cancelled by user"
                exit 0
            }

            Write-Info "Mode: Complete reset and reinstall"

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
            if (-not (Invoke-LuaEnvInstall @())) {
                Write-Err "Failed to recreate installation"
                exit 1
            }

            Write-OK "Complete reset and reinstall finished successfully!"
        }

        'Default' {
            Write-Info "Mode: Standard installation"

            # Step 1: Ensure Python is available (install if missing)
            if (-not (Install-EmbeddedPython)) {
                Write-Err "Failed to setup embedded Python"
                exit 1
            }

            # Step 2: Run LuaEnv installation
            if (-not (Invoke-LuaEnvInstall @())) {
                Write-Err "LuaEnv installation failed"
                exit 1
            }

            Write-OK "LuaEnv installation completed successfully!"
        }
    }

    # Final success message (for modes that complete installation)
    if ($PSCmdlet.ParameterSetName -in @('Default', 'Reset')) {
        Write-Info ""
        Write-OK "LuaEnv is now ready to use!"
        Write-Info "Next steps:"
        Write-Info "  1. Add to PATH: ~/.luaenv/bin"
        Write-Info "  2. Try: luaenv status"
        Write-Info "  3. For help: luaenv --help"
    }

} catch {
    Write-Err "Setup failed: $_"
    Write-Info "For help, run: .\setup.ps1 -Help"
    exit 1
}