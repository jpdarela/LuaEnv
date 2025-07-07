# This is free and unencumbered software released into the public domain.
# For more details, see the LICENSE file in the project root.

# setenv.ps1 - PowerShell script to set up Visual Studio Developer Environment
# This script automatically finds and configures the Visual Studio Developer Environment
# for building native C/C++ projects. It searches for Visual Studio installations and
# sets up the necessary environment variables (PATH, INCLUDE, LIB, etc.) required for
# compilation using MSVC compiler toolchain.


param(

    [Alias("h")]
    [switch]$Help,

    [Alias("platform", "a")]
    [ValidateSet("amd64", "x86", "x64")]
    [string]$Arch = "amd64",

    [Alias("env")]
    [switch]$Current,

    [Alias("p")]
    [string]$Path,

    [Alias("dry-run")]
    [switch]$DryRun

)

# Show help if requested
if ($Help) {
    Write-Host ""
    Write-Host "Visual Studio Developer Environment Setup Script" -ForegroundColor Cyan
    Write-Host "===============================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "DESCRIPTION:" -ForegroundColor Yellow
    Write-Host "  This script automatically finds and configures the Visual Studio Developer Environment" -ForegroundColor White
    Write-Host "  for building native C/C++ projects. It searches for Visual Studio installations" -ForegroundColor White
    Write-Host "  and sets up the necessary environment variables (PATH, INCLUDE, LIB, etc.)" -ForegroundColor White
    Write-Host "  required for compilation using the MSVC compiler toolchain." -ForegroundColor White
    Write-Host ""
    Write-Host "USAGE:" -ForegroundColor Yellow
    Write-Host "  .\setenv.ps1 [parameters]" -ForegroundColor White
    Write-Host ""
    Write-Host "PARAMETERS:" -ForegroundColor Yellow
    Write-Host "  -Arch <String> (alias: -platform, -a)" -ForegroundColor Green
    Write-Host "      Target architecture. Valid values: amd64, x64, x86." -ForegroundColor White
    Write-Host "      Default: amd64 (64-bit)" -ForegroundColor White
    Write-Host ""
    Write-Host "  -Current [<SwitchParameter>] (alias: -env)" -ForegroundColor Green
    Write-Host "      Configure the current PowerShell session instead of launching a new shell." -ForegroundColor White
    Write-Host "      When this flag is set, environment variables will be set in the current process." -ForegroundColor White
    Write-Host "      Otherwise, a new Visual Studio Developer Shell will be launched." -ForegroundColor Gray
    Write-Host ""
    Write-Host "  -Path <String> (alias: -p)" -ForegroundColor Green
    Write-Host "      Specify a custom Visual Studio installation path." -ForegroundColor White
    Write-Host "      This path should be the root of the Visual Studio installation," -ForegroundColor White
    Write-Host "      e.g., 'C:\Program Files\Microsoft Visual Studio\2022\Community'" -ForegroundColor Gray
    Write-Host "      The path will be saved to a config file for future use." -ForegroundColor Gray
    Write-Host ""
    Write-Host "  -DryRun [<SwitchParameter>] (alias: -dry-run)" -ForegroundColor Green
    Write-Host "      Show what would be configured without actually changing environment variables." -ForegroundColor White
    Write-Host "      Config file will still be updated when -Path is specified." -ForegroundColor White
    Write-Host "      Useful for testing and verification before making changes." -ForegroundColor Gray
    Write-Host ""
    Write-Host "  -Help [<SwitchParameter>] (alias: -h)" -ForegroundColor Green
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
    Write-Host "  .\setenv.ps1 -DryRun" -ForegroundColor White
    Write-Host "      Show what would be configured without making changes" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  .\setenv.ps1 -Path 'C:\MyVS' -DryRun" -ForegroundColor White
    Write-Host "      Save custom path to config file but don't change environment" -ForegroundColor Gray
    Write-Host ""
    Write-Host "NOTES:" -ForegroundColor Yellow
    Write-Host "  - The script automatically searches for Visual Studio installations using vswhere" -ForegroundColor White
    Write-Host "  - Supports Visual Studio 2017, 2019, and 2022 (Community, Professional, Enterprise)" -ForegroundColor White
    Write-Host "  - Falls back to common installation paths if vswhere is not available" -ForegroundColor White
    Write-Host "  - Custom path specified with -Path takes precedence and is saved to '.vspath.txt'" -ForegroundColor White
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
if ($DryRun) {
    Write-Host "Mode: DRY RUN - No environment changes will be made" -ForegroundColor Magenta
}

# Normalize architecture parameter (x64 is an alias for amd64)
if ($Arch -eq "x64") {
    $Arch = "amd64"
    Write-Host "[INFO] Normalized architecture 'x64' to 'amd64' for Visual Studio compatibility" -ForegroundColor Gray
}

Write-Host ""

# Config file path
$ConfigFile = ".vspath.txt"

# Handle custom path parameter and config file
$CustomInstallPath = $null

# First check if the -Path parameter was provided
if ($Path) {
    Write-Host "[INFO] Custom Visual Studio path provided: $Path" -ForegroundColor Yellow

    # Validate the path exists
    if (-not (Test-Path $Path)) {
        Write-Host "  [ERROR] Specified path does not exist: $Path" -ForegroundColor Red
        Write-Host "  [INFO] Falling back to automatic detection..." -ForegroundColor Yellow
    }
    else {
        # Check if it's a valid VS installation
        $vsDevShellPath = Join-Path $Path "Common7\Tools\Launch-VsDevShell.ps1"
        $vsDevCmdPath = Join-Path $Path "Common7\Tools\VsDevCmd.bat"

        if (-not (Test-Path $vsDevShellPath) -and -not (Test-Path $vsDevCmdPath)) {
            Write-Host "  [ERROR] Specified path does not appear to be a valid Visual Studio installation." -ForegroundColor Red
            Write-Host "  [INFO] Expected to find 'Common7\Tools\Launch-VsDevShell.ps1' or 'Common7\Tools\VsDevCmd.bat'" -ForegroundColor Yellow
            Write-Host "  [INFO] Falling back to automatic detection..." -ForegroundColor Yellow
        }
        else {
            $CustomInstallPath = $Path
            # Save to config file (overwrite if exists)
            try {
                Set-Content -Path $ConfigFile -Value $Path -Force
                Write-Host "  [OK] Path saved to config file: $ConfigFile" -ForegroundColor Green
            }
            catch {
                Write-Host "  [WARN] Failed to save path to config file: $($_.Exception.Message)" -ForegroundColor Yellow
            }
        }
    }
}
elseif (Test-Path $ConfigFile) {
    Write-Host "[INFO] Found config file: $ConfigFile" -ForegroundColor Yellow
    try {
        $SavedPath = Get-Content -Path $ConfigFile -Raw | ForEach-Object { $_.Trim() }
        if ($SavedPath -and (Test-Path $SavedPath)) {
            # Validate it's a valid VS installation
            $vsDevShellPath = Join-Path $SavedPath "Common7\Tools\Launch-VsDevShell.ps1"
            $vsDevCmdPath = Join-Path $SavedPath "Common7\Tools\VsDevCmd.bat"

            if (-not (Test-Path $vsDevShellPath) -and -not (Test-Path $vsDevCmdPath)) {
                Write-Host "  [WARN] Saved path is not a valid Visual Studio installation: $SavedPath" -ForegroundColor Yellow
                Write-Host "  [INFO] Falling back to automatic detection..." -ForegroundColor Yellow
            } else {
                $CustomInstallPath = $SavedPath
                Write-Host "  [OK] Using saved Visual Studio path: $CustomInstallPath" -ForegroundColor Green
            }
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

# First priority: use specified path if provided
if ($CustomInstallPath) {
    $VsDevShellPath = Join-Path $CustomInstallPath "Common7\Tools\Launch-VsDevShell.ps1"

    Write-Host "[INFO] Using specified Visual Studio installation path..." -ForegroundColor Yellow
    Write-Host "  -> Path: $CustomInstallPath" -ForegroundColor Gray

    if (Test-Path $VsDevShellPath) {
        Write-Host "  [OK] Found Visual Studio Developer Shell script" -ForegroundColor Green
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

                if ($DryRun) {
                    Write-Host "[DRY RUN] Would set the following environment variables:" -ForegroundColor Magenta
                    foreach ($line in $envVars) {
                        if ($line -match '^([^=]+)=(.*)$') {
                            Write-Host "  $($matches[1]) = $($matches[2])" -ForegroundColor Gray
                        }
                    }
                    Write-Host "[DRY RUN] Visual Studio Developer Environment would be configured in current session!" -ForegroundColor Magenta
                } else {
                    foreach ($line in $envVars) {
                        if ($line -match '^([^=]+)=(.*)$') {
                            [Environment]::SetEnvironmentVariable($matches[1], $matches[2], 'Process')
                        }
                    }
                    Write-Host "[SUCCESS] Visual Studio Developer Environment configured in current session!" -ForegroundColor Green
                }

                $VsDevShellFound = $true
                Write-Host "  -> PATH, INCLUDE, LIB, and other VS variables are now available" -ForegroundColor Gray
            }
            catch {
                if ($DryRun) {
                    Write-Host "  [DRY RUN] Would try Launch-VsDevShell as fallback..." -ForegroundColor Magenta
                } else {
                    Write-Host "  [WARN] Failed to configure environment in current session, trying Launch-VsDevShell..." -ForegroundColor Yellow
                    & $VsDevShellPath -Arch $Arch -SkipAutomaticLocation
                }
                $VsDevShellFound = $true
                Write-Host "[SUCCESS] Visual Studio Developer Environment successfully configured!" -ForegroundColor Green
            }
        } else {
            # Default behavior: Launch new shell
            if ($DryRun) {
                Write-Host "[DRY RUN] Would launch new Developer Shell with command:" -ForegroundColor Magenta
                Write-Host "  & `"$VsDevShellPath`" -Arch $Arch -SkipAutomaticLocation" -ForegroundColor Gray
            } else {
                & $VsDevShellPath -Arch $Arch -SkipAutomaticLocation
            }
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

    # Expanded list of possible vswhere.exe locations
    $VsWherePaths = @(
        # Standard installer locations
        "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe",
        "${env:ProgramFiles}\Microsoft Visual Studio\Installer\vswhere.exe",

        # Package cache location
        "${env:ProgramData}\Microsoft\VisualStudio\Packages\_Instances\vswhere.exe",
        "${env:ProgramData}\Microsoft\VisualStudio\Setup\vswhere.exe",

        # Chocolatey installation
        "${env:ChocolateyInstall}\lib\vswhere\tools\vswhere.exe",
        "${env:ProgramData}\chocolatey\lib\vswhere\tools\vswhere.exe",
        "C:\ProgramData\chocolatey\lib\vswhere\tools\vswhere.exe",

        # Scoop installation
        "${env:USERPROFILE}\scoop\apps\vswhere\current\vswhere.exe",
        "${env:USERPROFILE}\scoop\shims\vswhere.exe",

        # Winget installation
        "${env:LOCALAPPDATA}\Microsoft\WinGet\Packages\vswhere.exe",
        "${env:LOCALAPPDATA}\Microsoft\WinGet\Links\vswhere.exe",

        # Build tools specific locations
        "${env:ProgramFiles(x86)}\Microsoft Visual Studio\2022\BuildTools\Installer\vswhere.exe",
        "${env:ProgramFiles(x86)}\Microsoft Visual Studio\2019\BuildTools\Installer\vswhere.exe",
        "${env:ProgramFiles(x86)}\Microsoft Visual Studio\2017\BuildTools\Installer\vswhere.exe",

        # Alternative VS installer locations
        "${env:ProgramFiles}\Microsoft Visual Studio\Shared\Installer\vswhere.exe",
        "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Shared\Installer\vswhere.exe",

        # Custom tools directories
        "C:\Tools\vswhere\vswhere.exe",
        "D:\Tools\vswhere\vswhere.exe",

        # Developer command prompt tools
        "${env:VSINSTALLDIR}\Installer\vswhere.exe",
        "${env:VS170COMNTOOLS}\..\..\Installer\vswhere.exe",
        "${env:VS160COMNTOOLS}\..\..\Installer\vswhere.exe",

        # Portable/standalone locations
        "${env:USERPROFILE}\Downloads\vswhere.exe",
        "${env:USERPROFILE}\vswhere\vswhere.exe",
        "${env:LOCALAPPDATA}\vswhere\vswhere.exe",

        # CI/CD common locations
        "C:\vswhere\vswhere.exe",
        "C:\BuildTools\vswhere.exe"
    )

    # Find the first existing vswhere.exe
    $VsWherePath = $null
    foreach ($path in $VsWherePaths) {
        if (Test-Path $path) {
            $VsWherePath = $path
            Write-Host "  [OK] Found vswhere.exe at: $VsWherePath" -ForegroundColor Green
            break
        }
    }

    if ($VsWherePath) {
    Write-Host "  [OK] vswhere.exe available" -ForegroundColor Green
    try {
        # Try multiple ways to find VS installations
        $VsInstallations = $null

        # First try: Find latest installation with C++ tools specifically
        Write-Host "  -> Searching for latest installation with C++ development tools..." -ForegroundColor Gray
        $VsInstallations = & $VsWherePath -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath -format value

        # Second try: Look for any version with C++ tools
        if (-not $VsInstallations) {
            Write-Host "  -> Searching for any version with VC tools..." -ForegroundColor Yellow
            $VsInstallations = & $VsWherePath -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath -format value
        }

        # Third try: Look for Windows Desktop development with C++
        if (-not $VsInstallations) {
            Write-Host "  -> Searching for installations with Windows Desktop C++ workload..." -ForegroundColor Yellow
            $VsInstallations = & $VsWherePath -requires Microsoft.VisualStudio.Workload.NativeDesktop -property installationPath -format value
        }

        # Fourth try: Look for any installation with a native compiler
        if (-not $VsInstallations) {
            Write-Host "  -> Searching for any installation with native compiler..." -ForegroundColor Yellow
            $VsInstallations = & $VsWherePath -requires Microsoft.Component.MSBuild -property installationPath -format value
        }

        # Fifth try: Look for Build Tools specifically
        if (-not $VsInstallations) {
            Write-Host "  -> Searching for Build Tools installation..." -ForegroundColor Yellow
            $VsInstallations = & $VsWherePath -products Microsoft.VisualStudio.Product.BuildTools -property installationPath -format value
        }

        # Sixth try: Any VS installation as fallback
        if (-not $VsInstallations) {
            Write-Host "  -> Searching for any VS installation..." -ForegroundColor Yellow
            $VsInstallations = & $VsWherePath -products * -property installationPath -format value
        }

        # Seventh try: Include prerelease versions (e.g. preview versions)
        if (-not $VsInstallations) {
            Write-Host "  -> Searching for preview/prerelease versions..." -ForegroundColor Yellow
            $VsInstallations = & $VsWherePath -prerelease -products * -property installationPath -format value
        }

        # Eighth try: All-inclusive search with legacy versions
        if (-not $VsInstallations) {
            Write-Host "  -> Searching with all-inclusive parameters..." -ForegroundColor Yellow
            $VsInstallations = & $VsWherePath -all -prerelease -legacy -products * -property installationPath -format value
        }

        # Ninth try: Look for any instances, including incomplete installations
        if (-not $VsInstallations) {
            Write-Host "  -> Searching for any instances, including incomplete installations..." -ForegroundColor Yellow
            $VsInstallations = & $VsWherePath -all -products * -property installationPath -format value -includeIncomplete
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

                        if ($DryRun) {
                            Write-Host "[DRY RUN] Would set the following environment variables:" -ForegroundColor Magenta
                            foreach ($line in $envVars) {
                                if ($line -match '^([^=]+)=(.*)$') {
                                    Write-Host "  $($matches[1]) = $($matches[2])" -ForegroundColor Gray
                                }
                            }
                            Write-Host "[DRY RUN] Visual Studio Developer Environment would be configured in current session!" -ForegroundColor Magenta
                        } else {
                            foreach ($line in $envVars) {
                                if ($line -match '^([^=]+)=(.*)$') {
                                    [Environment]::SetEnvironmentVariable($matches[1], $matches[2], 'Process')
                                }
                            }
                            Write-Host "[SUCCESS] Visual Studio Developer Environment configured in current session!" -ForegroundColor Green
                        }

                        $VsDevShellFound = $true
                        Write-Host "  -> PATH, INCLUDE, LIB, and other VS variables are now available" -ForegroundColor Gray
                    }
                    catch {
                        if ($DryRun) {
                            Write-Host "  [DRY RUN] Would try Launch-VsDevShell as fallback..." -ForegroundColor Magenta
                        } else {
                            Write-Host "  [WARN] Failed to configure environment in current session, trying Launch-VsDevShell..." -ForegroundColor Yellow
                            & $VsDevShellPath -Arch $Arch -SkipAutomaticLocation
                        }
                        $VsDevShellFound = $true
                        Write-Host "[SUCCESS] Visual Studio Developer Environment successfully configured!" -ForegroundColor Green
                    }
                } else {
                    # Default behavior: Launch new shell
                    if ($DryRun) {
                        Write-Host "[DRY RUN] Would launch new Developer Shell with command:" -ForegroundColor Magenta
                        Write-Host "  & `"$VsDevShellPath`" -Arch $Arch -SkipAutomaticLocation" -ForegroundColor Gray
                    } else {
                        & $VsDevShellPath -Arch $Arch -SkipAutomaticLocation
                    }
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

# Check for Visual Studio environment variables
if (-not $VsDevShellFound) {
    Write-Host "[INFO] Trying to detect Visual Studio from environment variables..." -ForegroundColor Yellow

    $vsEnvVars = @(
        # Primary VS installation environment variables
        "VS2022INSTALLDIR",
        "VS2019INSTALLDIR",
        "VS2017INSTALLDIR",
        "VSINSTALLDIR",

        # Visual Studio common tools
        "VS170COMNTOOLS",
        "VS160COMNTOOLS",
        "VS150COMNTOOLS",

        # MSBuild paths
        "MSBUILD_PATH",
        "MSBUILD_DIR"
    )

    $foundVsPath = $null
    $foundVarName = $null

    foreach ($varName in $vsEnvVars) {
        $varValue = [Environment]::GetEnvironmentVariable($varName)
        if ($varValue -and (Test-Path $varValue)) {
            $foundVsPath = $varValue
            $foundVarName = $varName
            Write-Host "  [OK] Found Visual Studio path via environment variable: ${foundVarName} = ${foundVsPath}" -ForegroundColor Green
            break
        }
    }

    if ($foundVsPath) {
        # If we found a path to common tools, navigate up to the main VS directory
        if ($foundVarName -like "VS*COMNTOOLS") {
            $foundVsPath = Split-Path (Split-Path $foundVsPath)
        }

        $VsDevShellPath = Join-Path $foundVsPath "Common7\Tools\Launch-VsDevShell.ps1"

        if (Test-Path $VsDevShellPath) {
            Write-Host "  [OK] Found Developer Shell via environment variable at: $VsDevShellPath" -ForegroundColor Green

            if ($Current) {
                # Import VS environment into current session
                try {
                    $tempFile = [System.IO.Path]::GetTempFileName() + ".bat"
                    $batContent = @"
@echo off
call "$($foundVsPath)\Common7\Tools\VsDevCmd.bat" -arch=$Arch -no_logo
set
"@
                    Set-Content -Path $tempFile -Value $batContent

                    $envVars = & cmd /c $tempFile
                    Remove-Item $tempFile -Force

                    if ($DryRun) {
                        Write-Host "[DRY RUN] Would set the following environment variables:" -ForegroundColor Magenta
                        foreach ($line in $envVars) {
                            if ($line -match '^([^=]+)=(.*)$') {
                                Write-Host "  $($matches[1]) = $($matches[2])" -ForegroundColor Gray
                            }
                        }
                    } else {
                        foreach ($line in $envVars) {
                            if ($line -match '^([^=]+)=(.*)$') {
                                [Environment]::SetEnvironmentVariable($matches[1], $matches[2], 'Process')
                            }
                        }
                        Write-Host "[SUCCESS] Visual Studio Developer Environment configured via environment variables!" -ForegroundColor Green
                    }

                    $VsDevShellFound = $true
                }
                catch {
                    Write-Host "  [WARN] Failed to import environment: $($_.Exception.Message)" -ForegroundColor Yellow

                    if (-not $DryRun) {
                        Write-Host "  -> Trying to launch Developer Shell directly..." -ForegroundColor Gray
                        & $VsDevShellPath -Arch $Arch -SkipAutomaticLocation
                    }
                    $VsDevShellFound = $true
                }
            } else {
                # Launch new shell
                if ($DryRun) {
                    Write-Host "[DRY RUN] Would launch new Developer Shell with command:" -ForegroundColor Magenta
                    Write-Host "  & `"$VsDevShellPath`" -Arch $Arch -SkipAutomaticLocation" -ForegroundColor Gray
                } else {
                    & $VsDevShellPath -Arch $Arch -SkipAutomaticLocation
                }
                $VsDevShellFound = $true
                Write-Host "[SUCCESS] Visual Studio Developer Shell launched via environment variables!" -ForegroundColor Green
            }
        } else {
            # Try VsDevCmd.bat as a fallback
            $VsDevCmdPath = Join-Path $foundVsPath "Common7\Tools\VsDevCmd.bat"

            if (Test-Path $VsDevCmdPath) {
                Write-Host "  [OK] Found VsDevCmd.bat via environment variable at: $VsDevCmdPath" -ForegroundColor Yellow

                if ($Current) {
                    # Import environment
                    try {
                        $tempFile = [System.IO.Path]::GetTempFileName() + ".bat"
                        $batContent = @"
@echo off
call "$VsDevCmdPath" -arch=$Arch -no_logo
set
"@
                        Set-Content -Path $tempFile -Value $batContent

                        $envVars = & cmd /c $tempFile
                        Remove-Item $tempFile -Force

                        if ($DryRun) {
                            Write-Host "[DRY RUN] Would set environment variables from VsDevCmd.bat" -ForegroundColor Magenta
                        } else {
                            foreach ($line in $envVars) {
                                if ($line -match '^([^=]+)=(.*)$') {
                                    [Environment]::SetEnvironmentVariable($matches[1], $matches[2], 'Process')
                                }
                            }
                            Write-Host "[SUCCESS] Visual Studio Developer Environment configured via VsDevCmd.bat!" -ForegroundColor Green
                        }

                        $VsDevShellFound = $true
                    }
                    catch {
                        Write-Host "  [ERROR] Failed to import environment: $($_.Exception.Message)" -ForegroundColor Red
                    }
                } else {
                    # Launch cmd with VsDevCmd
                    if ($DryRun) {
                        Write-Host "[DRY RUN] Would launch CMD with VsDevCmd.bat" -ForegroundColor Magenta
                    } else {
                        Start-Process cmd.exe -ArgumentList '/k', "`"$VsDevCmdPath`" -arch=$Arch -no_logo"
                        Write-Host "[SUCCESS] Launched CMD with Visual Studio environment!" -ForegroundColor Green
                    }

                    $VsDevShellFound = $true
                }
            }
        }
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
call "$($InstallPath)\Common7\Tools\VsDevCmd.bat" -arch=$Arch -no_logo
set
"@
                    Set-Content -Path $tempFile -Value $batContent

                    $envVars = & cmd /c $tempFile
                    Remove-Item $tempFile -Force

                    if ($DryRun) {
                        Write-Host "[DRY RUN] Would set the following environment variables:" -ForegroundColor Magenta
                        foreach ($line in $envVars) {
                            if ($line -match '^([^=]+)=(.*)$') {
                                Write-Host "  $($matches[1]) = $($matches[2])" -ForegroundColor Gray
                            }
                        }
                        Write-Host "[DRY RUN] Visual Studio Developer Environment would be configured!" -ForegroundColor Magenta
                    } else {
                        foreach ($line in $envVars) {
                            if ($line -match '^([^=]+)=(.*)$') {
                                [Environment]::SetEnvironmentVariable($matches[1], $matches[2], 'Process')
                            }
                        }
                        Write-Host "[SUCCESS] Visual Studio Developer Environment configured in current session!" -ForegroundColor Green
                    }

                    $VsDevShellFound = $true
                }
                catch {
                    Write-Host "  [ERROR] Failed to configure environment: $($_.Exception.Message)" -ForegroundColor Red

                    if (-not $DryRun) {
                        Write-Host "  -> Trying to launch Developer Shell directly..." -ForegroundColor Gray
                        & $VsDevShellPath -Arch $Arch -SkipAutomaticLocation
                    }
                    $VsDevShellFound = $true
                }
            } else {
                # Launch new shell
                if ($DryRun) {
                    Write-Host "[DRY RUN] Would launch new Developer Shell with command:" -ForegroundColor Magenta
                    Write-Host "  & `"$VsDevShellPath`" -Arch $Arch -SkipAutomaticLocation" -ForegroundColor Gray
                } else {
                    & $VsDevShellPath -Arch $Arch -SkipAutomaticLocation
                }
                $VsDevShellFound = $true
                Write-Host "[SUCCESS] Visual Studio Developer Shell launched!" -ForegroundColor Green
            }
            break
        }
    }
}

# Fallback to registry detection if file path checks didn't work
if (-not $VsDevShellFound) {
    Write-Host "[INFO] Trying registry detection for Visual Studio installations..." -ForegroundColor Yellow

    $vsRegKeys = @(
        # VS 2022
        "HKLM:\SOFTWARE\Microsoft\VisualStudio\17.0",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\VisualStudio\17.0",

        # VS 2019
        "HKLM:\SOFTWARE\Microsoft\VisualStudio\16.0",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\VisualStudio\16.0",

        # VS 2017
        "HKLM:\SOFTWARE\Microsoft\VisualStudio\15.0",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\VisualStudio\15.0",

        # Build Tools specific
        "HKLM:\SOFTWARE\Microsoft\VisualCpp\17.0",
        "HKLM:\SOFTWARE\Microsoft\VisualCpp\16.0",
        "HKLM:\SOFTWARE\Microsoft\VisualCpp\15.0"
    )

    $foundVsInstallPath = $null

    # Check for VS registry entries and extract installation path
    foreach ($regKey in $vsRegKeys) {
        if (Test-Path $regKey) {
            Write-Host "  [INFO] Found Visual Studio registry key: $regKey" -ForegroundColor Gray

            try {
                $installDir = Get-ItemProperty -Path $regKey -Name "InstallDir" -ErrorAction SilentlyContinue
                if ($installDir -and (Test-Path $installDir.InstallDir)) {
                    # The InstallDir points to the Tools directory, so go up two levels to get main VS path
                    $foundVsInstallPath = Split-Path (Split-Path $installDir.InstallDir)
                    Write-Host "  [OK] Found VS installation via registry: $foundVsInstallPath" -ForegroundColor Green
                    break
                }

                # Check for ShellFolder if InstallDir doesn't exist
                $shellFolder = Get-ItemProperty -Path $regKey -Name "ShellFolder" -ErrorAction SilentlyContinue
                if ($shellFolder -and (Test-Path $shellFolder.ShellFolder)) {
                    $foundVsInstallPath = $shellFolder.ShellFolder
                    Write-Host "  [OK] Found VS installation via ShellFolder: $foundVsInstallPath" -ForegroundColor Green
                    break
                }
            }
            catch {
                Write-Host "  [WARN] Error checking registry key: $($_.Exception.Message)" -ForegroundColor Yellow
            }
        }
    }

    # Also check for VS installation path in VSINSTALLDIR env variable
    if (-not $foundVsInstallPath -and $env:VSINSTALLDIR -and (Test-Path $env:VSINSTALLDIR)) {
        $foundVsInstallPath = $env:VSINSTALLDIR
        Write-Host "  [OK] Found VS installation from VSINSTALLDIR: $foundVsInstallPath" -ForegroundColor Green
    }

    # Try to locate Developer Shell from registry-found installation path
    if ($foundVsInstallPath) {
        $VsDevShellPath = Join-Path $foundVsInstallPath "Common7\Tools\Launch-VsDevShell.ps1"

        if (Test-Path $VsDevShellPath) {
            Write-Host "  [OK] Found VS Developer Shell via registry at: $VsDevShellPath" -ForegroundColor Green

            if ($Current) {
                # Import VS environment into current session
                try {
                    $tempFile = [System.IO.Path]::GetTempFileName() + ".bat"
                    $batContent = @"
@echo off
call "$($foundVsInstallPath)\Common7\Tools\VsDevCmd.bat" -arch=$Arch -no_logo
set
"@
                    Set-Content -Path $tempFile -Value $batContent

                    $envVars = & cmd /c $tempFile
                    Remove-Item $tempFile -Force

                    if ($DryRun) {
                        Write-Host "[DRY RUN] Would set the following environment variables:" -ForegroundColor Magenta
                        foreach ($line in $envVars) {
                            if ($line -match '^([^=]+)=(.*)$') {
                                Write-Host "  $($matches[1]) = $($matches[2])" -ForegroundColor Gray
                            }
                        }
                        Write-Host "[DRY RUN] Visual Studio Developer Environment would be configured!" -ForegroundColor Magenta
                    } else {
                        foreach ($line in $envVars) {
                            if ($line -match '^([^=]+)=(.*)$') {
                                [Environment]::SetEnvironmentVariable($matches[1], $matches[2], 'Process')
                            }
                        }
                        Write-Host "[SUCCESS] Visual Studio Developer Environment configured in current session!" -ForegroundColor Green
                    }

                    $VsDevShellFound = $true
                }
                catch {
                    Write-Host "  [WARN] Failed to configure environment from registry path: $($_.Exception.Message)" -ForegroundColor Yellow

                    if ($DryRun) {
                        Write-Host "[DRY RUN] Would launch Developer Shell directly..." -ForegroundColor Magenta
                    } else {
                        Write-Host "  -> Trying to launch Developer Shell directly..." -ForegroundColor Gray
                        & $VsDevShellPath -Arch $Arch -SkipAutomaticLocation
                    }
                    $VsDevShellFound = $true
                }
            } else {
                # Launch new shell
                if ($DryRun) {
                    Write-Host "[DRY RUN] Would launch new Developer Shell with command:" -ForegroundColor Magenta
                    Write-Host "  & `"$VsDevShellPath`" -Arch $Arch -SkipAutomaticLocation" -ForegroundColor Gray
                } else {
                    & $VsDevShellPath -Arch $Arch -SkipAutomaticLocation
                }
                $VsDevShellFound = $true
                Write-Host "[SUCCESS] Visual Studio Developer Shell launched!" -ForegroundColor Green
            }
        } else {
            Write-Host "  [WARN] Found VS installation, but Developer Shell script not found at: $VsDevShellPath" -ForegroundColor Yellow

            # Try VsDevCmd.bat as a fallback
            $VsDevCmdPath = Join-Path $foundVsInstallPath "Common7\Tools\VsDevCmd.bat"

            if (Test-Path $VsDevCmdPath) {
                Write-Host "  [INFO] Found VsDevCmd.bat instead, attempting to use..." -ForegroundColor Yellow

                if ($Current) {
                    # Import environment from VsDevCmd.bat
                    try {
                        $tempFile = [System.IO.Path]::GetTempFileName() + ".bat"
                        $batContent = @"
@echo off
call "$VsDevCmdPath" -arch=$Arch -no_logo
set
"@
                        Set-Content -Path $tempFile -Value $batContent

                        $envVars = & cmd /c $tempFile
                        Remove-Item $tempFile -Force

                        if ($DryRun) {
                            Write-Host "[DRY RUN] Would set the following environment variables:" -ForegroundColor Magenta
                            foreach ($line in $envVars) {
                                if ($line -match '^([^=]+)=(.*)$') {
                                    Write-Host "  $($matches[1]) = $($matches[2])" -ForegroundColor Gray
                                }
                            }
                        } else {
                            foreach ($line in $envVars) {
                                if ($line -match '^([^=]+)=(.*)$') {
                                    [Environment]::SetEnvironmentVariable($matches[1], $matches[2], 'Process')
                                }
                            }
                            Write-Host "[SUCCESS] Visual Studio Developer Environment configured via VsDevCmd.bat!" -ForegroundColor Green
                        }

                        $VsDevShellFound = $true
                    }
                    catch {
                        Write-Host "  [ERROR] Failed to import environment from VsDevCmd.bat: $($_.Exception.Message)" -ForegroundColor Red
                    }
                } else {
                    # Launch cmd with VsDevCmd.bat
                    if ($DryRun) {
                        Write-Host "[DRY RUN] Would launch CMD with VsDevCmd.bat:" -ForegroundColor Magenta
                        Write-Host "  Start-Process cmd.exe -ArgumentList '/k', `"$VsDevCmdPath -arch=$Arch -no_logo`"" -ForegroundColor Gray
                    } else {
                        Start-Process cmd.exe -ArgumentList '/k', "`"$VsDevCmdPath`" -arch=$Arch -no_logo"
                        Write-Host "[SUCCESS] Launched CMD with Visual Studio environment!" -ForegroundColor Green
                    }

                    $VsDevShellFound = $true
                }
            }
        }
    }
}

# Last resort: Check for Windows SDK if all previous methods failed
if (-not $VsDevShellFound) {
    Write-Host "[INFO] All Visual Studio detection methods failed, checking for Windows SDK..." -ForegroundColor Yellow

    # Check for Windows SDK paths
    $WindowsSdkPaths = @(
        "${env:ProgramFiles(x86)}\Windows Kits\10\bin\10.0.22000.0\x64",
        "${env:ProgramFiles(x86)}\Windows Kits\10\bin\10.0.20348.0\x64",
        "${env:ProgramFiles(x86)}\Windows Kits\10\bin\10.0.19041.0\x64",
        "${env:ProgramFiles(x86)}\Windows Kits\10\bin\10.0.18362.0\x64",
        "${env:ProgramFiles(x86)}\Windows Kits\10\bin\10.0.17763.0\x64",
        "${env:ProgramFiles(x86)}\Windows Kits\10\bin\x64"
    )

    $foundSdkPath = $null
    foreach ($path in $WindowsSdkPaths) {
        if (Test-Path $path) {
            $foundSdkPath = $path
            Write-Host "  [OK] Found Windows SDK: $foundSdkPath" -ForegroundColor Green
            break
        }
    }

    if ($foundSdkPath) {
        if ($Current) {
            if ($DryRun) {
                Write-Host "[DRY RUN] Would add Windows SDK to PATH and set basic environment variables" -ForegroundColor Magenta
            } else {
                # Add Windows SDK to PATH and set minimal environment
                $env:PATH = "$foundSdkPath;" + $env:PATH

                # Try to find WindowsSdkDir
                $sdkRoot = Split-Path (Split-Path $foundSdkPath)
                $sdkVersion = Split-Path $foundSdkPath -Leaf

                # Set common SDK environment variables
                [Environment]::SetEnvironmentVariable("WindowsSdkDir", $sdkRoot, 'Process')
                [Environment]::SetEnvironmentVariable("WindowsSdkVersion", $sdkVersion, 'Process')

                # Find include and lib folders
                $includeFolder = Join-Path $sdkRoot "Include"
                $libFolder = Join-Path $sdkRoot "Lib"

                if (Test-Path $includeFolder) {
                    [Environment]::SetEnvironmentVariable("INCLUDE", "$includeFolder;$($env:INCLUDE)", 'Process')
                }

                if (Test-Path $libFolder) {
                    [Environment]::SetEnvironmentVariable("LIB", "$libFolder;$($env:LIB)", 'Process')
                }

                Write-Host "[SUCCESS] Added Windows SDK to environment as last resort (minimal build environment)" -ForegroundColor Green
                Write-Host "  [WARN] This is a minimal build environment without full Visual Studio tools" -ForegroundColor Yellow
            }

            $VsDevShellFound = $true
        } else {
            if ($DryRun) {
                Write-Host "[DRY RUN] Would open Command Prompt with Windows SDK in PATH" -ForegroundColor Magenta
            } else {
                # Launch a command prompt with the SDK in PATH
                $cmdArgs = "/k SET PATH=$foundSdkPath;%PATH% && echo Windows SDK environment set up without Visual Studio"
                Start-Process cmd.exe -ArgumentList $cmdArgs

                Write-Host "[SUCCESS] Launched Command Prompt with Windows SDK environment" -ForegroundColor Green
                Write-Host "  [WARN] This is a minimal build environment without full Visual Studio tools" -ForegroundColor Yellow
            }

            $VsDevShellFound = $true
        }
    }
}

# Final status check
if (-not $VsDevShellFound) {
    Write-Host "[ERROR] Failed to find any Visual Studio installations or compatible build environments" -ForegroundColor Red
    Write-Host "  -> Please install Visual Studio with C++ development tools, Build Tools, or Windows SDK" -ForegroundColor Red
    exit 1
}
