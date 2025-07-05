#!/usr/bin/env pwsh
# Build script to test all build systems with luaenv pkg-config integration

Write-Host "===============================================" -ForegroundColor Green
Write-Host "Testing LuaEnv pkg-config integration" -ForegroundColor Green
Write-Host "===============================================" -ForegroundColor Green

# Hardcoded path to GNU Make executable. Change this to your actual path.
$gnuMakePath = "C:\Users\darel\miniforge3\envs\linux_tools\Library\bin\make.exe"

# Check if Visual Studio environment is available and initialize if necessary
Write-Host "`n[INFO] Checking Visual Studio development environment..." -ForegroundColor Cyan
$vsDevCmd = $null

# Look for VS Developer Command Prompt in common locations
$vsLocations = @(
    "${env:ProgramFiles(x86)}\Microsoft Visual Studio\2022\Professional\Common7\Tools\VsDevCmd.bat",
    "${env:ProgramFiles(x86)}\Microsoft Visual Studio\2022\Enterprise\Common7\Tools\VsDevCmd.bat",
    "${env:ProgramFiles(x86)}\Microsoft Visual Studio\2022\Community\Common7\Tools\VsDevCmd.bat",
    "${env:ProgramFiles(x86)}\Microsoft Visual Studio\2019\Professional\Common7\Tools\VsDevCmd.bat",
    "${env:ProgramFiles(x86)}\Microsoft Visual Studio\2019\Enterprise\Common7\Tools\VsDevCmd.bat",
    "${env:ProgramFiles(x86)}\Microsoft Visual Studio\2019\Community\Common7\Tools\VsDevCmd.bat"
)

foreach ($location in $vsLocations) {
    if (Test-Path $location) {
        $vsDevCmd = $location
        break
    }
}

# Check if cl.exe is already in path
$clPath = Get-Command cl.exe -ErrorAction SilentlyContinue
if ($clPath) {
    Write-Host "[OK] Visual Studio environment is already configured" -ForegroundColor Green
    Write-Host "     Using cl.exe from: $($clPath.Source)" -ForegroundColor Gray
}
elseif ($vsDevCmd) {
    Write-Host "[INFO] Found VS Developer Command Prompt: $vsDevCmd" -ForegroundColor Yellow
    Write-Host "[INFO] To use this script with Visual Studio tools:" -ForegroundColor Yellow
    Write-Host "       1. Open a Visual Studio Developer Command Prompt" -ForegroundColor Yellow
    Write-Host "       2. Run: pwsh -Command ""& '$PSCommandPath'"" " -ForegroundColor Yellow
    Write-Host "[WARNING] Continuing without Visual Studio environment may cause failures" -ForegroundColor Yellow
}
else {
    Write-Host "[WARNING] Visual Studio environment not found" -ForegroundColor Yellow
    Write-Host "         Some build methods may fail. Please run this script from a" -ForegroundColor Yellow
    Write-Host "         Visual Studio Developer Command Prompt for best results." -ForegroundColor Yellow
}

# Check if luaenv is available
Write-Host "`n[INFO] Checking luaenv availability..." -ForegroundColor Cyan
try {
    $luaenvVersion = luaenv --help 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "[OK] luaenv is available" -ForegroundColor Green
    } else {
        Write-Host "[ERROR] luaenv command not found" -ForegroundColor Red
        exit 1
    }
} catch {
    Write-Host "[ERROR] luaenv command not found" -ForegroundColor Red
    exit 1
}

# Show current Lua installations
Write-Host "`n[INFO] Available Lua installations:" -ForegroundColor Cyan
luaenv list

# Test pkg-config output
Write-Host "`n[INFO] Testing pkg-config output:" -ForegroundColor Cyan
Write-Host "Compiler flag: " -NoNewline
$cflag = luaenv pkg-config dev --cflag
Write-Host $cflag -ForegroundColor Yellow

Write-Host "Include path: " -NoNewline
$includePath = luaenv pkg-config dev --lua-include
Write-Host $includePath -ForegroundColor Yellow

Write-Host "Library path: " -NoNewline
$libPath = luaenv pkg-config dev --liblua
Write-Host $libPath -ForegroundColor Yellow

# Define a structured results tracking system
$buildResults = @{
    "nmake" = @{
        Tested = $false
        Success = $false
        Executables = @()
        Details = @{
            Method = "Uses temporary files to store pkg-config output"
            PathStyle = "windows"
            Files = @()
        }
    }
    "meson" = @{
        Tested = $false
        Success = $false
        Executables = @()
        Details = @{
            Method = "Uses run_command to execute luaenv pkg-config"
            PathStyle = "windows"
            Files = @()
        }
    }
    "cmake" = @{
        Tested = $false
        Success = $false
        Executables = @()
        Details = @{
            Method = "Uses execute_process to run luaenv pkg-config"
            PathStyle = "windows"
            Files = @()
        }
    }
    "batch" = @{
        Tested = $false
        Success = $false
        Executables = @()
        Details = @{
            Method = "Uses for /f to capture luaenv pkg-config output"
            PathStyle = "windows"
            Files = @()
        }
    }
    "powershell" = @{
        Tested = $false
        Success = $false
        Executables = @()
        Details = @{
            Method = "Uses direct variable assignment from command output"
            PathStyle = "windows"
            Files = @()
        }
    }
    "gnumake" = @{
        Tested = $false
        Success = $false
        Executables = @()
        Details = @{
            Method = "Uses shell command substitution in make variables"
            PathStyle = "unix"
            Files = @()
        }
    }
}

# Function to collect file info
function Add-ExecutableInfo {
    param (
        [string]$BuildSystem,
        [string]$FilePath,
        [string]$Description
    )

    if (Test-Path $FilePath) {
        $fileInfo = Get-Item $FilePath
        $buildResults[$BuildSystem].Executables += @{
            Name = $fileInfo.Name
            Path = $fileInfo.FullName
            Size = $fileInfo.Length
            Description = $Description
        }
        $buildResults[$BuildSystem].Details.Files += $fileInfo.Name
        return $true
    }
    return $false
}

# Function to clean up build artifacts for a specific build system
function Clean-BuildSystem {
    param (
        [string]$BuildSystem,
        [string]$BuildDir = $null
    )

    Write-Host "[INFO] Cleaning $BuildSystem artifacts..." -ForegroundColor Cyan

    switch ($BuildSystem) {
        "nmake" {
            if (Get-Command nmake -ErrorAction SilentlyContinue) {
                nmake -f Makefile_win clean 2>$null
            }
        }
        "meson" {
            if (Test-Path "builddir") {
                Remove-Item -Recurse -Force builddir
            }
        }
        "cmake" {
            if (Test-Path "build") {
                Remove-Item -Recurse -Force build
            }
        }
        "gnumake" {
            if (Test-Path $gnuMakePath) {
                & $gnuMakePath clean 2>$null
            }
        }
        "batch" {
            if (Test-Path "main_bat.exe") { Remove-Item "main_bat.exe" }
            if (Test-Path "main_bat.obj") { Remove-Item "main_bat.obj" }
        }
        "powershell" {
            if (Test-Path "main_ps.exe") { Remove-Item "main_ps.exe" }
            if (Test-Path "main_ps.obj") { Remove-Item "main_ps.obj" }
        }
        "msbuild" {
            if (Test-Path ".\x64") { Remove-Item -Recurse -Force .\x64 }
            if (Test-Path ".\Debug") { Remove-Item -Recurse -Force .\Debug }
            if (Test-Path ".\Release") { Remove-Item -Recurse -Force .\Release }
            if (Test-Path ".\main_msbuild.exe") { Remove-Item -Force .\main_msbuild.exe }
            if (Test-Path ".\luaenv.props") { Remove-Item -Force .\luaenv.props }
            if (Test-Path ".\LuaEnvTest.vcxproj.user") { Remove-Item -Force .\LuaEnvTest.vcxproj.user }
        }
    }

    if ($BuildDir -and (Test-Path $BuildDir)) {
        Remove-Item -Recurse -Force $BuildDir
    }
}

# Initial cleanup before starting
if (Test-Path "build") { Remove-Item -Recurse -Force build }
if (Test-Path "builddir") { Remove-Item -Recurse -Force builddir }

Write-Host "`n===============================================" -ForegroundColor Green
Write-Host "Testing nmake (Windows Makefile)" -ForegroundColor Green
Write-Host "===============================================" -ForegroundColor Green

if (Get-Command nmake -ErrorAction SilentlyContinue) {
    $buildResults["nmake"].Tested = $true
    Write-Host "[INFO] Testing nmake with pkg-config integration..." -ForegroundColor Cyan

    # First, let's see what the pkg-config commands return
    Write-Host "[DEBUG] Testing pkg-config commands:" -ForegroundColor Gray
    $cflagResult = luaenv pkg-config dev --cflag
    $libResult = luaenv pkg-config dev --liblua
    Write-Host "  --cflag returns: $cflagResult" -ForegroundColor Gray
    Write-Host "  --liblua returns: $libResult" -ForegroundColor Gray

    # Create the temporary files that nmake expects
    Write-Host "[DEBUG] Creating temporary files for nmake..." -ForegroundColor Gray
    "CFLAGS = /TC /W4 /EHsc $cflagResult" | Out-File -Encoding ASCII cflags.tmp
    "LUA_LIB = $libResult" | Out-File -Encoding ASCII lua_lib.tmp

    Write-Host "[DEBUG] Contents of cflags.tmp:" -ForegroundColor Gray
    Get-Content cflags.tmp | ForEach-Object { Write-Host "  $_" -ForegroundColor Gray }

    Write-Host "[DEBUG] Contents of lua_lib.tmp:" -ForegroundColor Gray
    Get-Content lua_lib.tmp | ForEach-Object { Write-Host "  $_" -ForegroundColor Gray }

    # Clean any previous builds
    Write-Host "[INFO] Cleaning previous nmake builds..." -ForegroundColor Cyan
    nmake -f Makefile_win clean 2>$null

    # Build with nmake
    Write-Host "[INFO] Building with nmake..." -ForegroundColor Cyan
    nmake -f Makefile_win

    if ($LASTEXITCODE -eq 0 -and (Test-Path "main.exe")) {
        Write-Host "[SUCCESS] nmake compilation successful!" -ForegroundColor Green
        Write-Host "[INFO] Testing executable..." -ForegroundColor Cyan
        $output = .\main.exe
        Write-Host $output

        # Rename the nmake executables to ensure they're uniquely identifiable in the summary
        if (Test-Path "main_nmake.exe") { Remove-Item "main_nmake.exe" }
        Copy-Item "main.exe" "main_nmake.exe"

        # Update build results
        $buildResults["nmake"].Success = $true
        Add-ExecutableInfo -BuildSystem "nmake" -FilePath "main_nmake.exe" -Description "NMake built executable"
    } else {
        Write-Host "[ERROR] nmake compilation failed with exit code: $LASTEXITCODE" -ForegroundColor Red
        $buildResults["nmake"].Success = $false
    }

    # We'll clean temporary files at the end, after the summary
} else {
    Write-Host "[WARNING] nmake not found, skipping nmake test" -ForegroundColor Yellow
}

# Testing other build methods

Write-Host "`n===============================================" -ForegroundColor Green
Write-Host "Testing Meson" -ForegroundColor Green
Write-Host "===============================================" -ForegroundColor Green

if (Get-Command meson -ErrorAction SilentlyContinue) {
    $buildResults["meson"].Tested = $true
    Write-Host "[INFO] Testing Meson with pkg-config integration..." -ForegroundColor Cyan

    if (Test-Path "builddir") { Remove-Item -Recurse -Force builddir }

    meson setup builddir
    if ($LASTEXITCODE -eq 0) {
        meson compile -C builddir

        if ($LASTEXITCODE -eq 0 -and (Test-Path "builddir\main.exe")) {
            Write-Host "[SUCCESS] Meson compilation successful!" -ForegroundColor Green
            Write-Host "[INFO] Testing executable..." -ForegroundColor Cyan
            $output = .\builddir\main.exe
            Write-Host $output

            # Update build results
            $buildResults["meson"].Success = $true
            Add-ExecutableInfo -BuildSystem "meson" -FilePath "builddir\main.exe" -Description "Meson built executable"
        } else {
            Write-Host "[ERROR] Meson build failed!" -ForegroundColor Red
            $buildResults["meson"].Success = $false
        }
    } else {
        Write-Host "[ERROR] Meson setup failed!" -ForegroundColor Red
        $buildResults["meson"].Success = $false
    }
} else {
    Write-Host "[WARNING] meson not found, skipping Meson test" -ForegroundColor Yellow
}

Write-Host "`n===============================================" -ForegroundColor Green
Write-Host "Testing CMake" -ForegroundColor Green
Write-Host "===============================================" -ForegroundColor Green

if (Get-Command cmake -ErrorAction SilentlyContinue) {
    $buildResults["cmake"].Tested = $true
    Write-Host "[INFO] Testing CMake with pkg-config integration..." -ForegroundColor Cyan

    if (Test-Path "build") { Remove-Item -Recurse -Force build }
    New-Item -ItemType Directory -Name build | Out-Null

    Push-Location build

    cmake .. -G "Visual Studio 17 2022" -A x64
    if ($LASTEXITCODE -eq 0) {
        cmake --build . --config Release

        if ($LASTEXITCODE -eq 0 -and (Test-Path "Release\main.exe")) {
            Write-Host "[SUCCESS] CMake compilation successful!" -ForegroundColor Green
            Write-Host "[INFO] Testing executable..." -ForegroundColor Cyan
            $output = .\Release\main.exe
            Write-Host $output

            # Update build results
            $buildResults["cmake"].Success = $true
            Add-ExecutableInfo -BuildSystem "cmake" -FilePath "build/Release/main.exe" -Description "CMake built executable"
        } else {
            Write-Host "[ERROR] CMake build failed!" -ForegroundColor Red
            $buildResults["cmake"].Success = $false
        }
    } else {
        Write-Host "[ERROR] CMake configuration failed!" -ForegroundColor Red
        $buildResults["cmake"].Success = $false
    }

    Pop-Location
} else {
    Write-Host "[WARNING] cmake not found, skipping CMake test" -ForegroundColor Yellow
}

Write-Host "`n===============================================" -ForegroundColor Green
Write-Host "Testing Batch Script (build.bat)" -ForegroundColor Green
Write-Host "===============================================" -ForegroundColor Green

if (Test-Path "build.bat") {
    $buildResults["batch"].Tested = $true
    Write-Host "[INFO] Testing Batch Script with pkg-config integration..." -ForegroundColor Cyan

    cmd /c .\build.bat

    if ($LASTEXITCODE -eq 0 -and (Test-Path "main_bat.exe")) {
        Write-Host "[SUCCESS] Batch script compilation successful!" -ForegroundColor Green
        Write-Host "[INFO] Testing executable..." -ForegroundColor Cyan
        $output = .\main_bat.exe
        Write-Host $output

        # Update build results
        $buildResults["batch"].Success = $true
        Add-ExecutableInfo -BuildSystem "batch" -FilePath "main_bat.exe" -Description "Batch script built executable"
    } else {
        Write-Host "[ERROR] batch compilation failed with exit code: $LASTEXITCODE" -ForegroundColor Red
        $buildResults["batch"].Success = $false
    }
}

Write-Host "`n===============================================" -ForegroundColor Green
Write-Host "Testing PowerShell build script" -ForegroundColor Green
Write-Host "===============================================" -ForegroundColor Green

$buildResults["powershell"].Tested = $true
Write-Host "[INFO] Testing build.ps1..." -ForegroundColor Cyan

.\build.ps1

if ($LASTEXITCODE -eq 0 -and (Test-Path "main_ps.exe")) {
    Write-Host "[SUCCESS] PowerShell build successful!" -ForegroundColor Green
    Write-Host "[INFO] Testing executable..." -ForegroundColor Cyan
    $output = .\main_ps.exe
    Write-Host $output

    # Update build results
    $buildResults["powershell"].Success = $true
    Add-ExecutableInfo -BuildSystem "powershell" -FilePath "main_ps.exe" -Description "PowerShell built executable"
} else {
    Write-Host "[ERROR] PowerShell build failed with exit code: $LASTEXITCODE" -ForegroundColor Red
    $buildResults["powershell"].Success = $false
}

Write-Host "`n===============================================" -ForegroundColor Green
Write-Host "Testing GNU Make with unix path style" -ForegroundColor Green
Write-Host "===============================================" -ForegroundColor Green

if (Test-Path $gnuMakePath) {
    $buildResults["gnumake"].Tested = $true
    Write-Host "[INFO] Testing GNU Make with pkg-config unix path style integration..." -ForegroundColor Cyan

    # Clean any previous builds
    Write-Host "[INFO] Cleaning previous GNU Make builds..." -ForegroundColor Cyan
    & $gnuMakePath clean

    # Show configuration
    Write-Host "[DEBUG] GNU Make configuration with Unix paths:" -ForegroundColor Gray
    & $gnuMakePath config

    # Build release version
    Write-Host "[INFO] Building release with Unix paths..." -ForegroundColor Cyan
    & $gnuMakePath release

    if ($LASTEXITCODE -eq 0 -and (Test-Path "main.exe")) {
        Write-Host "[SUCCESS] GNU Make (Unix paths) compilation successful!" -ForegroundColor Green
        Write-Host "[INFO] Testing executable..." -ForegroundColor Cyan
        $output = .\main.exe
        Write-Host $output

        # Rename the executable to prevent overwrite
        if (Test-Path "main_gnu.exe") { Remove-Item "main_gnu.exe" }
        Rename-Item "main.exe" "main_gnu.exe"

        # Update build results
        $buildResults["gnumake"].Success = $true
        Add-ExecutableInfo -BuildSystem "gnumake" -FilePath "main_gnu.exe" -Description "GNU Make built executable"
    } else {
        Write-Host "[ERROR] GNU Make compilation with Unix paths failed with exit code: $LASTEXITCODE" -ForegroundColor Red
        $buildResults["gnumake"].Success = $false
    }

    # We'll clean up later, after the summary
} else {
    Write-Host "[WARNING] GNU Make not found at path: $gnuMakePath, skipping GNU Make test" -ForegroundColor Yellow
}
Write-Host "`n===============================================" -ForegroundColor Green
Write-Host "Summary of tests" -ForegroundColor Green
Write-Host "===============================================" -ForegroundColor Green

Write-Host "`n===============================================" -ForegroundColor Green
Write-Host "Build Testing Complete!" -ForegroundColor Green
Write-Host "===============================================" -ForegroundColor Green

# Debug output to see what executables exist
Write-Host "`n[DEBUG] Listing all executable files in the directory:" -ForegroundColor DarkGray
Get-ChildItem -Path . -Filter *.exe -Recurse | ForEach-Object {
    Write-Host ("  - {0} ({1:N0} bytes)" -f $_.FullName, $_.Length) -ForegroundColor DarkGray
}

# Function to render colorized status
function Get-StatusColor {
    param (
        [bool]$Status,
        [bool]$Tested
    )

    if (-not $Tested) {
        return "SKIPPED", "DarkGray"
    }
    elseif ($Status) {
        return "SUCCESS", "Green"
    }
    else {
        return "FAILED", "Red"
    }
}

# Generate summary table from build results
Write-Host "`n===============================================" -ForegroundColor Yellow
Write-Host "       BUILD SYSTEM TEST SUMMARY" -ForegroundColor Yellow
Write-Host "===============================================" -ForegroundColor Yellow

$i = 1
$totalTested = 0
$totalSuccess = 0
$nameMap = @{
    "nmake" = "NMake (Windows Makefile)"
    "meson" = "Meson Build System"
    "cmake" = "CMake Build System"
    "batch" = "Batch Script (.bat)"
    "powershell" = "PowerShell Script (.ps1)"
    "gnumake" = "GNU Make with Unix paths"
}

# Print header
Write-Host ("{0,-3} {1,-25} {2,-10} {3,-15} {4,-25}" -f "#", "Build System", "Status", "Path Style", "Integration Method")
Write-Host ("-" * 85)

# Print rows
foreach ($buildSystem in $buildResults.Keys) {
    $result = $buildResults[$buildSystem]
    $statusText, $statusColor = Get-StatusColor -Status $result.Success -Tested $result.Tested

    if ($result.Tested) { $totalTested++ }
    if ($result.Success) { $totalSuccess++ }

    $displayName = $nameMap[$buildSystem]
    if (-not $displayName) { $displayName = $buildSystem }

    Write-Host ("{0,-3} {1,-25} " -f $i, $displayName) -NoNewline
    Write-Host ("{0,-10}" -f $statusText) -ForegroundColor $statusColor -NoNewline
    Write-Host (" {0,-15} {1}" -f $result.Details.PathStyle, $result.Details.Method)
    $i++
}

Write-Host ("-" * 85)
Write-Host "Total build systems tested: $totalTested, Succeeded: $totalSuccess, Failed: ($totalTested - $totalSuccess)" -ForegroundColor Yellow

# Generate executable summary
Write-Host "`n===============================================" -ForegroundColor Yellow
Write-Host "       EXECUTABLES CREATED" -ForegroundColor Yellow
Write-Host "===============================================" -ForegroundColor Yellow

# Gather executables from build results
$exeTable = @()
foreach ($buildSystem in $buildResults.Keys) {
    foreach ($exe in $buildResults[$buildSystem].Executables) {
        $exeTable += [PSCustomObject]@{
            Name = $exe.Name
            BuildSystem = $nameMap[$buildSystem]
            Size = $exe.Size
            Path = $exe.Path
        }
    }
}

# Print table of executables
if ($exeTable.Count -gt 0) {
    Write-Host ("{0,-20} {1,-25} {2,-15}" -f "Executable", "Build System", "Size (bytes)")
    Write-Host ("-" * 70)
    foreach ($exe in $exeTable | Sort-Object Name) {
        Write-Host ("{0,-20} {1,-25} {2,-15:N0}" -f $exe.Name, $exe.BuildSystem, $exe.Size)
    }

    Write-Host "`nNote: All executables print the same output: 'Hello from Lua! x from Lua: 42'" -ForegroundColor Cyan
} else {
    Write-Host "No executables were created during testing." -ForegroundColor Yellow
}

# Final cleanup
Write-Host "`n[INFO] Cleaning up build artifacts..." -ForegroundColor Cyan
$ProgressPreference = 'SilentlyContinue' # Suppress progress bars

# Clean GNU Make artifacts if available
if ($buildResults["gnumake"].Tested) {
    Write-Host "[INFO] Cleaning GNU Make artifacts..." -ForegroundColor Cyan
    & $gnuMakePath clean 2>$null
}

# Remove build directories
if (Test-Path "build") { Remove-Item -Recurse -Force build }
if (Test-Path "builddir") { Remove-Item -Recurse -Force builddir }

# Clean up each build system's artifacts
Write-Host "[INFO] Cleaning up build system artifacts..." -ForegroundColor Cyan
foreach ($buildSystem in $buildResults.Keys) {
    if ($buildResults[$buildSystem].Tested) {
        Clean-BuildSystem -BuildSystem $buildSystem
    }
}

# Extra checks for any remaining executables
if (Test-Path "main.exe") { Remove-Item "main.exe" }
if (Test-Path "main_debug.exe") { Remove-Item "main_debug.exe" }

# Remove temp files and build artifacts
Write-Host "[INFO] Removing build artifacts and temporary files..." -ForegroundColor Cyan
if (Test-Path "*.obj") { Remove-Item *.obj }
if (Test-Path "*.pdb") { Remove-Item *.pdb }
if (Test-Path "*.ilk") { Remove-Item *.ilk }
if (Test-Path "*.tmp") { Remove-Item *.tmp -ErrorAction SilentlyContinue }
if (Test-Path "*.inc") { Remove-Item *.inc }

Write-Host "`n===============================================" -ForegroundColor Green
Write-Host "All Tests Complete!" -ForegroundColor Green
Write-Host "===============================================" -ForegroundColor Green
Write-Host "`nLuaEnv pkg-config integration testing complete. This script validates" -ForegroundColor Cyan
Write-Host "the integration between luaenv's pkg-config system and various build tools." -ForegroundColor Cyan
Write-Host "`nKey points:" -ForegroundColor Yellow
Write-Host "  • Different build systems use different methods to invoke luaenv pkg-config" -ForegroundColor White
Write-Host "  • Each method demonstrates how to integrate with luaenv in that environment" -ForegroundColor White
Write-Host "  • Path style (windows vs unix) must match the expectations of the build tool" -ForegroundColor White
Write-Host "  • All methods compile the same main.c file that demonstrates Lua integration" -ForegroundColor White
Write-Host "`nIf some build systems failed, ensure you are running from a" -ForegroundColor Yellow
Write-Host "Visual Studio Developer Command Prompt or have the MSVC build tools in your PATH." -ForegroundColor Yellow
