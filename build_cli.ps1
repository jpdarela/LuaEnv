# This is free and unencumbered software released into the public domain.
# For more details, see the LICENSE file in the project root.

# Build CLI project and publish to architecture-specific directories
# Ensure you have the .NET SDK installed and available in your PATH
# This script assumes you are running it from the root of the LuaEnv project

param(
    [string]$Target = "auto",  # auto, win64, win-x86, win-arm64, all, or clean
    [switch]$SelfContained = $false,
    [switch]$WarmUp = $false,
    [switch]$Clean = $false,
    [switch]$Help = $false
)

# Function to detect host architecture (windows)
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

# Function to clean all intermediate build files
function Invoke-Clean {
    param([switch]$Verbose = $false)

    Write-Host "Cleaning intermediate build files..." -ForegroundColor Cyan

    # Clean each project with dotnet clean
    $projects = @("cli/LuaEnv.CLI", "cli/LuaEnv.Core")

    foreach ($project in $projects) {
        Write-Host "  Cleaning project: $project" -ForegroundColor Gray

        # Clean both Debug and Release configurations
        & dotnet clean $project -c Debug -v minimal
        & dotnet clean $project -c Release -v minimal

        if ($LASTEXITCODE -ne 0) {
            Write-Warning "Clean command returned non-zero exit code for $project"
        }

        # Also manually clean bin and obj folders for complete cleanup
        $projectPath = (Resolve-Path $project).Path
        $binDir = Join-Path $projectPath "bin"
        $objDir = Join-Path $projectPath "obj"

        if (Test-Path $binDir) {
            Write-Host "  Cleaning $binDir" -ForegroundColor Gray
            Remove-Item -Path $binDir -Recurse -Force -ErrorAction SilentlyContinue
        }

        if (Test-Path $objDir) {
            Write-Host "  Cleaning $objDir" -ForegroundColor Gray
            Remove-Item -Path $objDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    # Clean output directories as well
    $outputDirs = @("win64") #, "win-x86", "win-arm64")

    foreach ($dir in $outputDirs) {
        if (Test-Path $dir) {
            Write-Host "  Cleaning output directory: $dir" -ForegroundColor Gray
            Remove-Item -Path $dir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    Write-Host "Cleanup completed successfully!" -ForegroundColor Green
}

# Function to warm up JIT compilation for a build
function Invoke-WarmUp {
    param([string]$BuildPath, [string]$Platform)

    $exeName = "LuaEnv.CLI.exe"
    $exePath = Join-Path $BuildPath $exeName

    if (-not (Test-Path $exePath)) {
        Write-Warning "Executable not found: $exePath - skipping warm-up"
        return
    }

    Write-Host "  Warming up JIT compilation..." -ForegroundColor Cyan

    try {
        # Run several commands to warm up different code paths
        $commands = @("--help", "help", "versions")

        foreach ($cmd in $commands) {
            Write-Host "    Running: $exeName $cmd" -ForegroundColor Gray
            $startTime = Get-Date

            # Windows executable - suppress output and errors (warm-up only)
            & $exePath $cmd 2>&1 | Out-Null

            $endTime = Get-Date
            $duration = ($endTime - $startTime).TotalMilliseconds
            Write-Host "    Completed in $([math]::Round($duration, 2))ms" -ForegroundColor Gray
        }

        Write-Host "  JIT warm-up completed successfully!" -ForegroundColor Green

    } catch {
        Write-Warning "Warm-up failed: $($_.Exception.Message)"
    }
}

# Auto-detect target if set to "auto"
if ($Target -eq "auto") {
    $Target = Get-HostArchitecture
    Write-Host "Auto-detected architecture: $Target" -ForegroundColor Cyan
}

# Show help if requested
if ($Help) {
    Write-Host "LuaEnv CLI Build Script" -ForegroundColor Green
    Write-Host "=======================" -ForegroundColor Green
    Write-Host ""
    Write-Host "DESCRIPTION:" -ForegroundColor Yellow
    Write-Host "  Build script for the LuaEnv CLI application on Windows."
    Write-Host "  Supports Windows x64, x86 (32-bit), and ARM64 targets."
    Write-Host ""
    Write-Host "USAGE:" -ForegroundColor Yellow
    Write-Host "  .\build_cli.ps1 [-Target <platform>] [-SelfContained] [-Clean] [-WarmUp] [-Help]"
    Write-Host ""
    Write-Host "PARAMETERS:" -ForegroundColor Yellow
    Write-Host "  -Target <platform>     Target platform to build for"
    Write-Host "                         Options: auto, win64, win-x86, win-arm64, all, clean"
    Write-Host "                         Default: auto (detects current Windows architecture)"
    Write-Host "                         Use 'clean' to only clean without building"
    Write-Host ""
    Write-Host "  -SelfContained         Include .NET runtime in the output"
    Write-Host "                         Makes the app portable but increases size"
    Write-Host "                         Default: false (requires .NET runtime on target)"
    Write-Host ""
    Write-Host "  -Clean                 Clean all intermediate build files before building"
    Write-Host "                         Removes bin, obj folders and build outputs"
    Write-Host "                         Ensures a clean build environment"
    Write-Host ""
    Write-Host "  -WarmUp                Run JIT warm-up after building"
    Write-Host "                         Executes the CLI to trigger JIT compilation"
    Write-Host "                         Improves first-run performance"
    Write-Host ""
    Write-Host "  -Help                  Show this help message"
    Write-Host ""
    Write-Host "EXAMPLES:" -ForegroundColor Yellow
    Write-Host "  .\build_cli.ps1"                                    # Auto-detect and build for current arch
    Write-Host "  .\build_cli.ps1 -Clean"                             # Clean and build
    Write-Host "  .\build_cli.ps1 -Target clean"                      # Only clean, don't build
    Write-Host "  .\build_cli.ps1 -Clean -WarmUp"                     # Clean, build and warm up JIT
    Write-Host "  .\build_cli.ps1 -Target win64"                      # Force build for Windows x64
    Write-Host "  .\build_cli.ps1 -Target win-x86"                    # Build for Windows x86 (32-bit)
    Write-Host "  .\build_cli.ps1 -Target win-arm64 -SelfContained"   # Self-contained Windows ARM64
    Write-Host "  .\build_cli.ps1 -Target all -Clean -WarmUp"         # Clean and build all platforms and warm up
    Write-Host "  .\build_cli.ps1 -Help"                              # Show this help
    Write-Host ""
    Write-Host "OUTPUT DIRECTORIES:" -ForegroundColor Yellow
    Write-Host "  win64/        - Windows x64 build"
    Write-Host "  win-x86/      - Windows x86 (32-bit) build"
    Write-Host "  win-arm64/    - Windows ARM64 build"
    Write-Host ""
    Write-Host "REQUIREMENTS:" -ForegroundColor Yellow
    Write-Host "  - .NET SDK 8.0 or later"
    Write-Host "  - F# compiler (included with .NET SDK)"
    Write-Host "  - Internet connection (for package restoration)"
    Write-Host ""
    return
}

# Handle clean-only target
if ($Target -eq "clean") {
    Invoke-Clean
    Write-Host "Clean completed successfully!" -ForegroundColor Green
    return
}

# Clean if requested as a flag
if ($Clean) {
    Invoke-Clean
}

# Auto-detect target if set to "auto"
if ($Target -eq "auto") {
    $Target = Get-HostArchitecture
    Write-Host "Auto-detected architecture: $Target" -ForegroundColor Cyan
}

# Standard JIT build (fast startup after first run)
if ($Target -eq "win64" -or $Target -eq "all") {
    Write-Host "Building for Windows x64..." -ForegroundColor Green
    & dotnet publish cli/LuaEnv.CLI -c Release -o ./win64 `
      --self-contained $SelfContained `
      -p:PublishSingleFile=true `
      -p:IncludeNativeLibrariesForSelfExtract=true `
      -p:SatelliteResourceLanguages=en

    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to build Windows x64 version (exit code: $LASTEXITCODE)"
        exit $LASTEXITCODE
    }

    if ($WarmUp) {
        Invoke-WarmUp -BuildPath "./win64" -Platform "win64"
    }
}

if ($Target -eq "win-x86" -or $Target -eq "all") {
    Write-Host "Building for Windows x86 (32-bit)..." -ForegroundColor Green
    & dotnet publish cli/LuaEnv.CLI -c Release -o ./win-x86 `
      --runtime win-x86 `
      --self-contained $SelfContained `
      -p:PublishSingleFile=false `
      -p:IncludeNativeLibrariesForSelfExtract=true `
      -p:SatelliteResourceLanguages=en

    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to build Windows x86 version (exit code: $LASTEXITCODE)"
        exit $LASTEXITCODE
    }

    if ($WarmUp) {
        Invoke-WarmUp -BuildPath "./win-x86" -Platform "win-x86"
    }
}

if ($Target -eq "win-arm64" -or $Target -eq "all") {
    Write-Host "Building for Windows ARM64..." -ForegroundColor Green
    & dotnet publish cli/LuaEnv.CLI -c Release -o ./win-arm64 `
      --runtime win-arm64 `
      --self-contained $SelfContained `
      -p:PublishSingleFile=false `
      -p:IncludeNativeLibrariesForSelfExtract=true `
      -p:SatelliteResourceLanguages=en

    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to build Windows ARM64 version (exit code: $LASTEXITCODE)"
        exit $LASTEXITCODE
    }

    if ($WarmUp) {
        Invoke-WarmUp -BuildPath "./win-arm64" -Platform "win-arm64"
    }
}

Write-Host "Build completed successfully for: $Target" -ForegroundColor Green
exit 0
