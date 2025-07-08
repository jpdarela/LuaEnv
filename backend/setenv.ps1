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

# Import the LuaEnv Visual Studio module
$moduleScript = Join-Path $PSScriptRoot "luaenv_vs.psm1"
if (Test-Path $moduleScript) {
    try {
        Import-Module $moduleScript -Force
        Write-Verbose "Successfully imported luaenv_vs module"
    }
    catch {
        Write-Error "Failed to import luaenv_vs module: $($_.Exception.Message)"
        Write-Error "Cannot proceed without the Visual Studio detection module"
        exit 1
    }
} else {
    Write-Error "luaenv_vs.psm1 module not found at: $moduleScript"
    Write-Error "Cannot proceed without the Visual Studio detection module"
    exit 1
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
    # Write-Host "[INFO] Normalized architecture 'x64' to 'amd64' for Visual Studio compatibility" -ForegroundColor Gray
}

Write-Host ""

# Use the luaenv_vs module for Visual Studio detection and setup
# Write-Host "[INFO] Using enhanced Visual Studio detection module..." -ForegroundColor Yellow

try {
    # Initialize Visual Studio environment using the module
    $vsResult = Initialize-VisualStudioEnvironment -Architecture $Arch -CustomPath $Path -SaveConfig:($Path -ne $null -and $Path -ne "") -ImportEnvironment:$Current -Verbose:$VerbosePreference

    if ($vsResult.Success) {
        Write-Host "[SUCCESS] $($vsResult.Message)" -ForegroundColor Green

        if ($DryRun) {
            Write-Host "[DRY RUN] Would use Visual Studio installation:" -ForegroundColor Magenta
            Write-Host "  -> Path: $($vsResult.Installation.InstallPath)" -ForegroundColor Gray
            Write-Host "  -> Version: $($vsResult.Installation.Version)" -ForegroundColor Gray
            Write-Host "  -> Edition: $($vsResult.Installation.DisplayName)" -ForegroundColor Gray
            Write-Host "  -> Architecture: $($vsResult.Architecture)" -ForegroundColor Gray
            Write-Host "  -> Has C++ Tools: $($vsResult.Installation.HasCppTools)" -ForegroundColor Gray

            if ($Current) {
                Write-Host "[DRY RUN] Would configure current PowerShell session" -ForegroundColor Magenta
            } else {
                Write-Host "[DRY RUN] Would launch new Developer Shell" -ForegroundColor Magenta
            }
        } else {
            if ($Current) {
                Write-Host "  -> Visual Studio environment configured in current session" -ForegroundColor Gray
                Write-Host "  -> PATH, INCLUDE, LIB, and other VS variables are now available" -ForegroundColor Gray
            } else {
                # Launch new Developer Shell since -Current was not specified
                Write-Host "  -> Launching new Visual Studio Developer Shell..." -ForegroundColor Gray
                if ($vsResult.Installation.DevShellPath -and (Test-Path $vsResult.Installation.DevShellPath)) {
                    & $vsResult.Installation.DevShellPath -Arch $Arch -SkipAutomaticLocation
                } elseif ($vsResult.Installation.DevCmdPath -and (Test-Path $vsResult.Installation.DevCmdPath)) {
                    Start-Process cmd.exe -ArgumentList '/k', "`"$($vsResult.Installation.DevCmdPath)`" -arch=$Arch -no_logo"
                }
                Write-Host "  -> Visual Studio Developer Shell launched" -ForegroundColor Gray
            }
        }
    } else {
        Write-Host "[ERROR] $($vsResult.Message)" -ForegroundColor Red
        Write-Host ""
        Write-Host "To resolve this issue, try one of the following:" -ForegroundColor Cyan
        Write-Host "1. Install Visual Studio with C++ build tools from: https://visualstudio.microsoft.com/downloads/" -ForegroundColor White
        Write-Host "2. Install Build Tools for Visual Studio from: https://visualstudio.microsoft.com/downloads/#build-tools-for-visual-studio-2022" -ForegroundColor White
        Write-Host "3. Specify your VS installation path: setenv.ps1 -Path <path-to-vs-installation>" -ForegroundColor White
        Write-Host ""
        Write-Host "Common VS installation locations:" -ForegroundColor Gray
        Write-Host "  - C:\Program Files\Microsoft Visual Studio\2022\Community" -ForegroundColor Gray
        Write-Host "  - C:\Program Files (x86)\Microsoft Visual Studio\2019\BuildTools" -ForegroundColor Gray
        Write-Host ""
        Write-Host "Supported editions: Community, Professional, Enterprise, BuildTools, Preview" -ForegroundColor Yellow
        exit 1
    }
}
catch {
    Write-Host "[ERROR] Visual Studio detection failed: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Please ensure the luaenv_vs module is properly installed and try again." -ForegroundColor Red
    exit 1
}
