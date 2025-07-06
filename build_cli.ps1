# This is free and unencumbered software released into the public domain.
# For more details, see the LICENSE file in the project root.

# Build CLI project and publish to architecture-specific directories
# Ensure you have the .NET SDK installed and available in your PATH
# This script assumes you are running it from the root of the LuaEnv project

param(
    [string]$Target = "auto",  # auto, win64, win-x86, win-arm64, or all
    [switch]$SelfContained = $false,
    [switch]$WarmUp = $false,
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
    Write-Host "  .\build_cli.ps1 [-Target <platform>] [-SelfContained] [-Help]"
    Write-Host ""
    Write-Host "PARAMETERS:" -ForegroundColor Yellow
    Write-Host "  -Target <platform>     Target platform to build for"
    Write-Host "                         Options: auto, win64, win-x86, win-arm64, all"
    Write-Host "                         Default: auto (detects current Windows architecture)"
    Write-Host ""
    Write-Host "  -SelfContained         Include .NET runtime in the output"
    Write-Host "                         Makes the app portable but increases size"
    Write-Host "                         Default: false (requires .NET runtime on target)"
    Write-Host ""
    Write-Host "  -WarmUp                Run JIT warm-up after building"
    Write-Host "                         Executes the CLI to trigger JIT compilation"
    Write-Host "                         Improves first-run performance"
    Write-Host ""
    Write-Host "  -Help                  Show this help message"
    Write-Host ""
    Write-Host "EXAMPLES:" -ForegroundColor Yellow
    Write-Host "  .\build_cli.ps1"                                    # Auto-detect and build for current arch
    Write-Host "  .\build_cli.ps1 -WarmUp"                            # Build and warm up JIT
    Write-Host "  .\build_cli.ps1 -Target win64"                      # Force build for Windows x64
    Write-Host "  .\build_cli.ps1 -Target win-x86"                    # Build for Windows x86 (32-bit)
    Write-Host "  .\build_cli.ps1 -Target win-arm64 -SelfContained"   # Self-contained Windows ARM64
    Write-Host "  .\build_cli.ps1 -Target all -WarmUp"                # Build all platforms and warm up
    Write-Host "  .\build_cli.ps1 -Help"                              # Show this help
    Write-Host ""
    Write-Host "OUTPUT DIRECTORIES:" -ForegroundColor Yellow
    Write-Host "  win64/        - Windows x64 build"
    Write-Host "  win-x86/      - Windows x86 (32-bit) build"
    Write-Host "  win-arm64/    - Windows ARM64 build"
    Write-Host ""
    Write-Host "REQUIREMENTS:" -ForegroundColor Yellow
    Write-Host "  - .NET SDK 9.0 or later"
    Write-Host "  - F# compiler (included with .NET SDK)"
    Write-Host "  - Internet connection (for package restoration)"
    Write-Host ""
    return
}

# Standard JIT build (fast startup after first run)
if ($Target -eq "win64" -or $Target -eq "all") {
    Write-Host "Building for Windows x64..." -ForegroundColor Green
    & dotnet publish cli/LuaEnv.CLI -c Release -o ./win64 `
      --self-contained $SelfContained `
      -p:PublishSingleFile=false `
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
