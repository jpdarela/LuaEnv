param(

    [Alias("h")]
    [switch]$Help,

    [ValidateSet("amd64", "x86")]
    [string]$Arch = "amd64",

    [switch]$Current,

    [string]$Path

)

# Show help if requested
if ($Help) {
    Write-Host ""
    Write-Host "Visual Studio Developer Environment Setup Script" -ForegroundColor Cyan
    Write-Host "===============================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "DESCRIPTION:" -ForegroundColor Yellow
    Write-Host "  This script automatically finds and configures the Visual Studio Developer Environment" -ForegroundColor White
    Write-Host "  for building native C/C++ projects. It searches for Visual Studio installations and" -ForegroundColor White
    Write-Host "  sets up the necessary environment variables (PATH, INCLUDE, LIB, etc.) required for" -ForegroundColor White
    Write-Host "  compilation using MSVC compiler toolchain." -ForegroundColor White
    Write-Host ""
    Write-Host "USAGE:" -ForegroundColor Yellow
    Write-Host "  .\setenv.ps1 [[-Arch] <String>] [-Current] [-Path <String>] [-Help]" -ForegroundColor White
    Write-Host ""
    Write-Host "PARAMETERS:" -ForegroundColor Yellow
    Write-Host "  -Arch <String>" -ForegroundColor Green
    Write-Host "      Target architecture for the build environment." -ForegroundColor White
    Write-Host "      Valid values: 'amd64' (64-bit), 'x86' (32-bit)" -ForegroundColor White
    Write-Host "      Default: 'amd64'" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  -Current [<SwitchParameter>]" -ForegroundColor Green
    Write-Host "      Configure the Visual Studio environment in the current PowerShell session" -ForegroundColor White
    Write-Host "      instead of launching a new Developer Shell window." -ForegroundColor White
    Write-Host "      This allows you to continue using the same terminal with VS tools available." -ForegroundColor White
    Write-Host ""
    Write-Host "  -Path <String>" -ForegroundColor Green
    Write-Host "      Absolute path to the Visual Studio installation directory." -ForegroundColor White
    Write-Host "      Example: 'C:\Program Files\Microsoft Visual Studio\2022\Community'" -ForegroundColor White
    Write-Host "      This path will be saved to '.vs_install_path.txt' for future use." -ForegroundColor White
    Write-Host "      Takes precedence over automatic detection methods." -ForegroundColor Gray
    Write-Host ""
    Write-Host "  -Help [<SwitchParameter>] (aliases: -h, -H)" -ForegroundColor Green
    Write-Host "      Display this help message and exit." -ForegroundColor White
    Write-Host ""
    Write-Host "EXAMPLES:" -ForegroundColor Yellow
    Write-Host "  .\setenv.ps1" -ForegroundColor White
    Write-Host "      Launch a new Visual Studio Developer Shell for 64-bit development" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  .\setenv.ps1 -Arch x86" -ForegroundColor White
    Write-Host "      Launch a new Visual Studio Developer Shell for 32-bit development" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  .\setenv.ps1 -Current" -ForegroundColor White
    Write-Host "      Configure the current PowerShell session for 64-bit development" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  .\setenv.ps1 -Arch x86 -Current" -ForegroundColor White
    Write-Host "      Configure the current PowerShell session for 32-bit development" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  .\setenv.ps1 -Path 'C:\Program Files\Microsoft Visual Studio\2022\Community'" -ForegroundColor White
    Write-Host "      Use a specific Visual Studio installation path" -ForegroundColor Gray
    Write-Host ""
    Write-Host "NOTES:" -ForegroundColor Yellow
    Write-Host "  - The script automatically searches for Visual Studio installations using vswhere" -ForegroundColor White
    Write-Host "  - Supports Visual Studio 2017, 2019, and 2022 (Community, Professional, Enterprise)" -ForegroundColor White
    Write-Host "  - Falls back to common installation paths if vswhere is not available" -ForegroundColor White
    Write-Host "  - Custom path specified with -Path takes precedence and is saved to '.vs_install_path.txt'" -ForegroundColor White
    Write-Host ""
    return
}

Write-Host "Setting up Visual Studio Developer Environment..." -ForegroundColor Cyan
Write-Host "Target architecture: $Arch" -ForegroundColor Blue
if ($Current) {
    Write-Host "Mode: Configure current PowerShell session" -ForegroundColor DarkYellow
} else {
    Write-Host "Mode: Launch new Developer Shell" -ForegroundColor DarkYellow
}
Write-Host ""

# Config file path
$ConfigFile = ".vs_install_path.txt"

# Handle custom path parameter and config file
$CustomInstallPath = $null
if ($Path) {
    Write-Host "[INFO] Custom Visual Studio path provided: $Path" -ForegroundColor Yellow
    if (Test-Path $Path) {
        $CustomInstallPath = $Path
        # Save to config file (overwrite if exists)
        try {
            Set-Content -Path $ConfigFile -Value $Path -Force
            Write-Host "  [OK] Path saved to config file: $ConfigFile" -ForegroundColor Green
        }
        catch {
            Write-Host "  [WARN] Failed to save path to config file: $($_.Exception.Message)" -ForegroundColor Yellow
        }
    } else {
        Write-Host "  [ERROR] Specified path does not exist: $Path" -ForegroundColor Red
        Write-Host "  [INFO] Falling back to automatic detection..." -ForegroundColor Yellow
    }
} elseif (Test-Path $ConfigFile) {
    Write-Host "[INFO] Found config file: $ConfigFile" -ForegroundColor Yellow
    try {
        $SavedPath = Get-Content -Path $ConfigFile -Raw | ForEach-Object { $_.Trim() }
        if ($SavedPath -and (Test-Path $SavedPath)) {
            $CustomInstallPath = $SavedPath
            Write-Host "  [OK] Using saved Visual Studio path: $CustomInstallPath" -ForegroundColor Green
        } else {
            Write-Host "  [WARN] Saved path is invalid or doesn't exist: $SavedPath" -ForegroundColor Yellow
            Write-Host "  [INFO] Falling back to automatic detection..." -ForegroundColor Yellow
        }
    }
    catch {
        Write-Host "  [WARN] Failed to read config file: $($_.Exception.Message)" -ForegroundColor Yellow
        Write-Host "  [INFO] Falling back to automatic detection..." -ForegroundColor Yellow
    }
}

# Try to find and launch Visual Studio Developer Shell
$VsDevShellFound = $false

# First priority: Use custom path if available
if ($CustomInstallPath) {
    Write-Host "[INFO] Using custom Visual Studio installation path..." -ForegroundColor Yellow
    $VsDevShellPath = Join-Path $CustomInstallPath "Common7\Tools\Launch-VsDevShell.ps1"

    if (Test-Path $VsDevShellPath) {
        Write-Host "  [OK] Found Developer Shell script at: $VsDevShellPath" -ForegroundColor Green
        Write-Host "  -> Configuring Developer Shell environment with architecture: $Arch" -ForegroundColor Gray

        if ($Current) {
            # Import VS environment into current session
            try {
                $tempFile = [System.IO.Path]::GetTempFileName() + ".bat"
                $batContent = @"
@echo off
call "$($CustomInstallPath)\Common7\Tools\VsDevCmd.bat" -arch=$Arch -no_logo
set
"@
                Set-Content -Path $tempFile -Value $batContent

                $envVars = & cmd /c $tempFile
                Remove-Item $tempFile -Force

                foreach ($line in $envVars) {
                    if ($line -match '^([^=]+)=(.*)$') {
                        [Environment]::SetEnvironmentVariable($matches[1], $matches[2], 'Process')
                    }
                }

                $VsDevShellFound = $true
                Write-Host "[SUCCESS] Visual Studio Developer Environment configured in current session!" -ForegroundColor Green
                Write-Host "  -> PATH, INCLUDE, LIB, and other VS variables are now available" -ForegroundColor Gray
            }
            catch {
                Write-Host "  [WARN] Failed to configure environment in current session, trying Launch-VsDevShell..." -ForegroundColor Yellow
                & $VsDevShellPath -Arch $Arch -SkipAutomaticLocation
                $VsDevShellFound = $true
                Write-Host "[SUCCESS] Visual Studio Developer Environment successfully configured!" -ForegroundColor Green
            }
        } else {
            # Default behavior: Launch new shell
            & $VsDevShellPath -Arch $Arch -SkipAutomaticLocation
            $VsDevShellFound = $true
            Write-Host "[SUCCESS] Visual Studio Developer Shell launched!" -ForegroundColor Green
        }
    } else {
        Write-Host "  [ERROR] Developer Shell script not found at: $VsDevShellPath" -ForegroundColor Red
        Write-Host "  [INFO] Falling back to automatic detection..." -ForegroundColor Yellow
    }
}

# Second priority: try using vswhere to find VS installations (most reliable method)
if (-not $VsDevShellFound) {
    Write-Host "[INFO] Searching for Visual Studio installations using vswhere..." -ForegroundColor Yellow
    $VsWherePath = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
    if (Test-Path $VsWherePath) {
    Write-Host "  [OK] Found vswhere.exe" -ForegroundColor Green
    try {
        # Try with C++ tools requirement first
        Write-Host "  -> Searching for installations with C++ development tools..." -ForegroundColor Gray
        $VsInstallations = & $VsWherePath -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath -format value

        # If no installation found with C++ tools, try without the requirement
        if (-not $VsInstallations) {
            Write-Host "  -> No installations found with C++ tools, searching for any VS installation..." -ForegroundColor Yellow
            $VsInstallations = & $VsWherePath -latest -products * -property installationPath -format value
        }

        if ($VsInstallations) {
            # Handle multiple installations - split by newline and take the first one
            $InstallPath = ($VsInstallations -split "`n")[0].Trim()
            $VsDevShellPath = Join-Path $InstallPath "Common7\Tools\Launch-VsDevShell.ps1"

            Write-Host "  [OK] Found Visual Studio installation: $InstallPath" -ForegroundColor Green

            if (Test-Path $VsDevShellPath) {
                Write-Host "  [OK] Developer Shell script found and configuring environment..." -ForegroundColor Green
                Write-Host ""

                if ($Current) {
                    # Import VS environment into current session
                    try {
                        $tempFile = [System.IO.Path]::GetTempFileName() + ".bat"
                        $batContent = @"
@echo off
call "$($InstallPath)\Common7\Tools\VsDevCmd.bat" -arch=$Arch -no_logo
set
"@
                        Set-Content -Path $tempFile -Value $batContent

                        $envVars = & cmd /c $tempFile
                        Remove-Item $tempFile -Force

                        foreach ($line in $envVars) {
                            if ($line -match '^([^=]+)=(.*)$') {
                                [Environment]::SetEnvironmentVariable($matches[1], $matches[2], 'Process')
                            }
                        }

                        $VsDevShellFound = $true
                        Write-Host "[SUCCESS] Visual Studio Developer Environment configured in current session!" -ForegroundColor Green
                        Write-Host "  -> PATH, INCLUDE, LIB, and other VS variables are now available" -ForegroundColor Gray
                    }
                    catch {
                        Write-Host "  [WARN] Failed to configure environment in current session, trying Launch-VsDevShell..." -ForegroundColor Yellow
                        & $VsDevShellPath -Arch $Arch -SkipAutomaticLocation
                        $VsDevShellFound = $true
                        Write-Host "[SUCCESS] Visual Studio Developer Environment successfully configured!" -ForegroundColor Green
                    }
                } else {
                    # Default behavior: Launch new shell
                    & $VsDevShellPath -Arch $Arch -SkipAutomaticLocation
                    $VsDevShellFound = $true
                    Write-Host "[SUCCESS] Visual Studio Developer Shell launched!" -ForegroundColor Green
                }
            } else {
                Write-Host "  [ERROR] Developer Shell script not found at expected location" -ForegroundColor Red
                Write-Host "    Expected: $VsDevShellPath" -ForegroundColor Gray
            }
        } else {
            Write-Host "  [ERROR] No Visual Studio installations found by vswhere" -ForegroundColor Red
        }
    }
    catch {
        Write-Host "  [ERROR] Error running vswhere: $($_.Exception.Message)" -ForegroundColor Red
    }
} else {
    Write-Host "  [WARN] vswhere.exe not found - trying fallback methods..." -ForegroundColor Yellow
}
}

# Fallback to common installation paths if vswhere didn't work
if (-not $VsDevShellFound) {
    Write-Host "[INFO] Trying fallback method - checking common installation paths..." -ForegroundColor Yellow
    $VsDevShellPaths = @(
        # VS 2022 - Community edition first (most common)
        "${env:ProgramFiles}\Microsoft Visual Studio\2022\Community\Common7\Tools\Launch-VsDevShell.ps1",
        "${env:ProgramFiles}\Microsoft Visual Studio\2022\Professional\Common7\Tools\Launch-VsDevShell.ps1",
        "${env:ProgramFiles}\Microsoft Visual Studio\2022\Enterprise\Common7\Tools\Launch-VsDevShell.ps1",
        "${env:ProgramFiles}\Microsoft Visual Studio\2022\Preview\Common7\Tools\Launch-VsDevShell.ps1",
        "${env:ProgramFiles}\Microsoft Visual Studio\2022\BuildTools\Common7\Tools\Launch-VsDevShell.ps1",

        # VS 2019 - Community edition first
        "${env:ProgramFiles}\Microsoft Visual Studio\2019\Community\Common7\Tools\Launch-VsDevShell.ps1",
        "${env:ProgramFiles}\Microsoft Visual Studio\2019\Professional\Common7\Tools\Launch-VsDevShell.ps1",
        "${env:ProgramFiles}\Microsoft Visual Studio\2019\Enterprise\Common7\Tools\Launch-VsDevShell.ps1",
        "${env:ProgramFiles}\Microsoft Visual Studio\2019\Preview\Common7\Tools\Launch-VsDevShell.ps1",
        "${env:ProgramFiles}\Microsoft Visual Studio\2019\BuildTools\Common7\Tools\Launch-VsDevShell.ps1",

        # VS 2017 - Community edition first
        "${env:ProgramFiles(x86)}\Microsoft Visual Studio\2017\Community\Common7\Tools\Launch-VsDevShell.ps1",
        "${env:ProgramFiles(x86)}\Microsoft Visual Studio\2017\Professional\Common7\Tools\Launch-VsDevShell.ps1",
        "${env:ProgramFiles(x86)}\Microsoft Visual Studio\2017\Enterprise\Common7\Tools\Launch-VsDevShell.ps1",
        "${env:ProgramFiles(x86)}\Microsoft Visual Studio\2017\BuildTools\Common7\Tools\Launch-VsDevShell.ps1",

        # Alternative locations for VS 2022 in Program Files (x86)
        "${env:ProgramFiles(x86)}\Microsoft Visual Studio\2022\Community\Common7\Tools\Launch-VsDevShell.ps1",
        "${env:ProgramFiles(x86)}\Microsoft Visual Studio\2022\Professional\Common7\Tools\Launch-VsDevShell.ps1",
        "${env:ProgramFiles(x86)}\Microsoft Visual Studio\2022\Enterprise\Common7\Tools\Launch-VsDevShell.ps1",
        "${env:ProgramFiles(x86)}\Microsoft Visual Studio\2022\BuildTools\Common7\Tools\Launch-VsDevShell.ps1"
    )

    foreach ($VsDevShellPath in $VsDevShellPaths) {
        if (Test-Path $VsDevShellPath) {
            Write-Host "  [OK] Found Visual Studio Developer Shell at: $VsDevShellPath" -ForegroundColor Green
            Write-Host "  -> Configuring Developer Shell environment with architecture: $Arch" -ForegroundColor Gray

            if ($Current) {
                # Import VS environment into current session
                try {
                    $InstallPath = Split-Path (Split-Path (Split-Path $VsDevShellPath))
                    $tempFile = [System.IO.Path]::GetTempFileName() + ".bat"
                    $batContent = @"
@echo off
call "$InstallPath\Common7\Tools\VsDevCmd.bat" -arch=$Arch -no_logo
set
"@
                    Set-Content -Path $tempFile -Value $batContent

                    $envVars = & cmd /c $tempFile
                    Remove-Item $tempFile -Force

                    foreach ($line in $envVars) {
                        if ($line -match '^([^=]+)=(.*)$') {
                            [Environment]::SetEnvironmentVariable($matches[1], $matches[2], 'Process')
                        }
                    }

                    $VsDevShellFound = $true
                    Write-Host "[SUCCESS] Visual Studio Developer Environment configured in current session!" -ForegroundColor Green
                    break
                }
                catch {
                    Write-Host "  [WARN] Failed to configure environment in current session, trying Launch-VsDevShell..." -ForegroundColor Yellow
                    & $VsDevShellPath -Arch $Arch -SkipAutomaticLocation
                    $VsDevShellFound = $true
                    Write-Host "[SUCCESS] Visual Studio Developer Environment successfully configured!" -ForegroundColor Green
                    break
                }
            } else {
                # Default behavior: Launch new shell
                & $VsDevShellPath -Arch $Arch -SkipAutomaticLocation
                $VsDevShellFound = $true
                Write-Host "[SUCCESS] Visual Studio Developer Shell launched!" -ForegroundColor Green
                break
            }
        }
    }
}

# Check environment variable VCINSTALLDIR as another fallback
if (-not $VsDevShellFound -and $env:VCINSTALLDIR) {
    Write-Host "[INFO] Trying VCINSTALLDIR environment variable..." -ForegroundColor Yellow
    $VsDevShellPath = Join-Path $env:VCINSTALLDIR "Common7\Tools\Launch-VsDevShell.ps1"
    if (Test-Path $VsDevShellPath) {
        Write-Host "  [OK] Found Visual Studio Developer Shell via VCINSTALLDIR: $VsDevShellPath" -ForegroundColor Green

        if ($Current) {
            # Import VS environment into current session
            try {
                $InstallPath = $env:VCINSTALLDIR
                $tempFile = [System.IO.Path]::GetTempFileName() + ".bat"
                $batContent = @"
@echo off
call "$InstallPath\Common7\Tools\VsDevCmd.bat" -arch=$Arch -no_logo
set
"@
                Set-Content -Path $tempFile -Value $batContent

                $envVars = & cmd /c $tempFile
                Remove-Item $tempFile -Force

                foreach ($line in $envVars) {
                    if ($line -match '^([^=]+)=(.*)$') {
                        [Environment]::SetEnvironmentVariable($matches[1], $matches[2], 'Process')
                    }
                }

                $VsDevShellFound = $true
                Write-Host "[SUCCESS] Visual Studio Developer Environment configured in current session!" -ForegroundColor Green
            }
            catch {
                Write-Host "  [WARN] Failed to configure environment in current session, trying Launch-VsDevShell..." -ForegroundColor Yellow
                & $VsDevShellPath -Arch $Arch -SkipAutomaticLocation
                $VsDevShellFound = $true
                Write-Host "[SUCCESS] Visual Studio Developer Environment successfully configured!" -ForegroundColor Green
            }
        } else {
            # Default behavior: Launch new shell
            & $VsDevShellPath -Arch $Arch -SkipAutomaticLocation
            $VsDevShellFound = $true
            Write-Host "[SUCCESS] Visual Studio Developer Shell launched!" -ForegroundColor Green
        }
    } else {
        Write-Host "  [WARN] VCINSTALLDIR found but Launch-VsDevShell.ps1 not found at: $VsDevShellPath" -ForegroundColor Yellow
    }
}

if (-not $VsDevShellFound) {
    Write-Warning "Visual Studio Developer Shell not found. Compilation of native modules may fail."
    Write-Warning "Please ensure Visual Studio with C++ tools is installed."
    Write-Host ""
    Write-Host "Searched locations:" -ForegroundColor Yellow

    # Show vswhere attempt
    Write-Host "  - vswhere.exe at: $VsWherePath" -ForegroundColor Gray
    if (Test-Path $VsWherePath) {
        Write-Host "    (vswhere found but no valid VS installation detected)" -ForegroundColor Gray
    } else {
        Write-Host "    (vswhere not found)" -ForegroundColor Gray
    }

    # Show all fallback paths that were checked
    Write-Host "  - Fallback paths checked:" -ForegroundColor Gray
    foreach ($path in $VsDevShellPaths) {
        Write-Host "    $path" -ForegroundColor Gray
    }

    Write-Host ""
    Write-Host "To resolve this issue:" -ForegroundColor Cyan
    Write-Host "  1. Install Visual Studio Community (free) from https://visualstudio.microsoft.com/" -ForegroundColor White
    Write-Host "  2. Ensure 'Desktop development with C++' workload is selected during installation" -ForegroundColor White
    Write-Host "  3. Or install 'Build Tools for Visual Studio' if you only need the compiler" -ForegroundColor White
}
