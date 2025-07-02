#!/usr/bin/env pwsh
# Build script to test all build systems with luaenv pkg-config integration

Write-Host "===============================================" -ForegroundColor Green
Write-Host "Testing LuaEnv pkg-config integration" -ForegroundColor Green
Write-Host "===============================================" -ForegroundColor Green

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

$nmakeTested = $false
$mesonTested = $false
$cmakeTested = $false
$batchTested = $false
$psTested = $false
$gnuMakeTested = $false

# Initial cleanup before starting
if (Test-Path "build") { Remove-Item -Recurse -Force build }
if (Test-Path "builddir") { Remove-Item -Recurse -Force builddir }

Write-Host "`n===============================================" -ForegroundColor Green
Write-Host "Testing nmake (Windows Makefile)" -ForegroundColor Green
Write-Host "===============================================" -ForegroundColor Green

if (Get-Command nmake -ErrorAction SilentlyContinue) {
    $nmakeTested = $true
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
    } else {
        Write-Host "[ERROR] nmake compilation failed with exit code: $LASTEXITCODE" -ForegroundColor Red
    }

    # Clean temp files
    Remove-Item *.tmp -ErrorAction SilentlyContinue
} else {
    Write-Host "[WARNING] nmake not found, skipping nmake test" -ForegroundColor Yellow
}

# Testing other build methods

Write-Host "`n===============================================" -ForegroundColor Green
Write-Host "5. Testing Meson" -ForegroundColor Green
Write-Host "===============================================" -ForegroundColor Green

if (Get-Command meson -ErrorAction SilentlyContinue) {
    $mesonTested = $true
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
        } else {
            Write-Host "[ERROR] Meson build failed!" -ForegroundColor Red
        }
    } else {
        Write-Host "[ERROR] Meson setup failed!" -ForegroundColor Red
    }
} else {
    Write-Host "[WARNING] meson not found, skipping Meson test" -ForegroundColor Yellow
}

Write-Host "`n===============================================" -ForegroundColor Green
Write-Host "Testing CMake" -ForegroundColor Green
Write-Host "===============================================" -ForegroundColor Green

if (Get-Command cmake -ErrorAction SilentlyContinue) {
    $cmakeTested = $true
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
        } else {
            Write-Host "[ERROR] CMake build failed!" -ForegroundColor Red
        }
    } else {
        Write-Host "[ERROR] CMake configuration failed!" -ForegroundColor Red
    }

    Pop-Location
} else {
    Write-Host "[WARNING] cmake not found, skipping CMake test" -ForegroundColor Yellow
}

Write-Host "`n===============================================" -ForegroundColor Green
Write-Host "Testing Batch Script (build.bat)" -ForegroundColor Green
Write-Host "===============================================" -ForegroundColor Green

if (Test-Path "build.bat") {
    $batchTested = $true
    Write-Host "[INFO] Testing Batch Script with pkg-config integration..." -ForegroundColor Cyan

    cmd /c .\build.bat

    if ($LASTEXITCODE -eq 0 -and (Test-Path "main_bat.exe")) {
        Write-Host "[SUCCESS] Batch script compilation successful!" -ForegroundColor Green
        Write-Host "[INFO] Testing executable..." -ForegroundColor Cyan
        $output = .\main_bat.exe
        Write-Host $output
    } else {
        Write-Host "[ERROR] batch compilation failed with exit code: $LASTEXITCODE" -ForegroundColor Red
    }
}

Write-Host "`n===============================================" -ForegroundColor Green
Write-Host "Testing PowerShell build script" -ForegroundColor Green
Write-Host "===============================================" -ForegroundColor Green

$psTested = $true
Write-Host "[INFO] Testing build.ps1..." -ForegroundColor Cyan

.\build.ps1

if ($LASTEXITCODE -eq 0 -and (Test-Path "main_ps.exe")) {
    Write-Host "[SUCCESS] PowerShell build successful!" -ForegroundColor Green
    Write-Host "[INFO] Testing executable..." -ForegroundColor Cyan
    $output = .\main_ps.exe
    Write-Host $output
} else {
    Write-Host "[ERROR] PowerShell build failed with exit code: $LASTEXITCODE" -ForegroundColor Red
}


Write-Host "`n===============================================" -ForegroundColor Green
Write-Host "Summary of tests" -ForegroundColor Green
Write-Host "===============================================" -ForegroundColor Green

# Keep these commented out for now
<#
Write-Host "`n===============================================" -ForegroundColor Green
Write-Host "1. Testing Direct cl.exe compilation" -ForegroundColor Green
Write-Host "===============================================" -ForegroundColor Green

Write-Host "[INFO] Compiling with direct cl.exe using pkg-config..." -ForegroundColor Cyan
$cmd = "cl.exe /Fe:main_direct.exe main.c $cflag $libPath /TC /W4 -D_CRT_SECURE_NO_WARNINGS"
Write-Host "Command: $cmd" -ForegroundColor Gray
Invoke-Expression $cmd

if ($LASTEXITCODE -eq 0 -and (Test-Path "main_direct.exe")) {
    Write-Host "[SUCCESS] Direct cl.exe compilation successful!" -ForegroundColor Green
    Write-Host "[INFO] Testing executable..." -ForegroundColor Cyan
    .\main_direct.exe
} else {
    Write-Host "[ERROR] Direct cl.exe compilation failed!" -ForegroundColor Red
}

Write-Host "`n===============================================" -ForegroundColor Green
Write-Host "2. Testing PowerShell variable method" -ForegroundColor Green
Write-Host "===============================================" -ForegroundColor Green

Write-Host "[INFO] Using PowerShell variables..." -ForegroundColor Cyan
$cflags = luaenv pkg-config dev --cflag
$lua_lib = luaenv pkg-config dev --liblua

Write-Host "CFLAGS: $cflags" -ForegroundColor Gray
Write-Host "LUA_LIB: $lua_lib" -ForegroundColor Gray

$cmd2 = "cl.exe /Fe:main_ps.exe main.c $cflags $lua_lib /TC /W4 -D_CRT_SECURE_NO_WARNINGS"
Write-Host "Command: $cmd2" -ForegroundColor Gray
Invoke-Expression $cmd2

if ($LASTEXITCODE -eq 0 -and (Test-Path "main_ps.exe")) {
    Write-Host "[SUCCESS] PowerShell method compilation successful!" -ForegroundColor Green
    Write-Host "[INFO] Testing executable..." -ForegroundColor Cyan
    .\main_ps.exe
} else {
    Write-Host "[ERROR] PowerShell method compilation failed!" -ForegroundColor Red
}
#>

Write-Host "`n===============================================" -ForegroundColor Green
Write-Host "Build Testing Complete!" -ForegroundColor Green
Write-Host "===============================================" -ForegroundColor Green

$testedMethods = @()
if ($nmakeTested) { $testedMethods += "nmake with temporary files" }
if ($mesonTested) { $testedMethods += "Meson with run_command" }
if ($cmakeTested) { $testedMethods += "CMake with execute_process" }
if ($batchTested) { $testedMethods += "Batch script with for /f" }
if ($psTested) { $testedMethods += "PowerShell script" }

if ($gnuMakeTested) { $testedMethods += "GNU Make with three path styles (windows/unix/native)" }

if ($testedMethods.Count -gt 0) {
    Write-Host "`nSummary of methods tested:" -ForegroundColor Yellow
    for ($i = 0; $i -lt $testedMethods.Count; $i++) {
        Write-Host ("{0}. {1}" -f ($i + 1), $testedMethods[$i])
    }
}

$executables = @{}
if (Test-Path "main.exe") { $executables["main.exe (nmake)"] = (Get-Item "main.exe").Length }
if (Test-Path "main_debug.exe") { $executables["main_debug.exe (nmake)"] = (Get-Item "main_debug.exe").Length }
if (Test-Path "builddir/main.exe") { $executables["main.exe (meson)"] = (Get-Item "builddir/main.exe").Length }
if (Test-Path "build/Release/main.exe") { $executables["main.exe (cmake)"] = (Get-Item "build/Release/main.exe").Length }
if (Test-Path "main_bat.exe") { $executables["main_bat.exe (batch)"] = (Get-Item "main_bat.exe").Length }
if (Test-Path "main_ps.exe") { $executables["main_ps.exe (PowerShell)"] = (Get-Item "main_ps.exe").Length }
if (Test-Path "main_windows.exe") { $executables["main_windows.exe (GNU Make, Windows paths)"] = (Get-Item "main_windows.exe").Length }
if (Test-Path "main_unix.exe") { $executables["main_unix.exe (GNU Make, Unix paths)"] = (Get-Item "main_unix.exe").Length }
if (Test-Path "main_native.exe") { $executables["main_native.exe (GNU Make, Native paths)"] = (Get-Item "main_native.exe").Length }

if ($executables.Keys.Count -gt 0) {
    Write-Host "`nExecutables created:" -ForegroundColor Yellow
    foreach ($exe in $executables.GetEnumerator() | Sort-Object Name) {
        Write-Host ("  - {0} ({1:N0} bytes)" -f $exe.Name, $exe.Value)
    }
}

# Final cleanup
Write-Host "`n[INFO] Cleaning up build artifacts..." -ForegroundColor Cyan
$ProgressPreference = 'SilentlyContinue' # Suppress progress bars
if (Test-Path "build") { Remove-Item -Recurse -Force build }
if (Test-Path "builddir") { Remove-Item -Recurse -Force builddir }
if (Test-Path "main.exe") { Remove-Item "main.exe" }
if (Test-Path "main_debug.exe") { Remove-Item "main_debug.exe" }
if (Test-Path "main_bat.exe") { Remove-Item "main_bat.exe" }
if (Test-Path "main_ps.exe") { Remove-Item "main_ps.exe" }
if (Test-Path "main_windows.exe") { Remove-Item "main_windows.exe" }
if (Test-Path "main_unix.exe") { Remove-Item "main_unix.exe" }
if (Test-Path "main_native.exe") { Remove-Item "main_native.exe" }
if (Test-Path "*.obj") { Remove-Item *.obj }
if (Test-Path "*.pdb") { Remove-Item *.pdb }
if (Test-Path "*.ilk") { Remove-Item *.ilk }
if (Test-Path "*.tmp") { Remove-Item *.tmp }
if (Test-Path "*.inc") { Remove-Item *.inc }

Write-Host "`n===============================================" -ForegroundColor Green
Write-Host "All Tests Complete!" -ForegroundColor Green
Write-Host "===============================================" -ForegroundColor Green

Write-Host "`n===============================================" -ForegroundColor Green
Write-Host "Testing GNU Make with path-style options" -ForegroundColor Green
Write-Host "===============================================" -ForegroundColor Green

$gnuMakePath = "C:\Users\darel\miniforge3\envs\linux_tools\Library\bin\make.exe"

if (Test-Path $gnuMakePath) {
    $gnuMakeTested = $true
    Write-Host "[INFO] Testing GNU Make with pkg-config path-style integration..." -ForegroundColor Cyan

    # Clean any previous builds
    Write-Host "[INFO] Cleaning previous GNU Make builds..." -ForegroundColor Cyan
    & $gnuMakePath clean

    # Test with Windows-style paths (double backslashes)
    Write-Host "`n[INFO] Testing with Windows-style paths (--path-style windows)..." -ForegroundColor Cyan

    # Update the Makefile temporarily
    $makefile = Get-Content -Path "Makefile" -Raw
    $windowsStyle = $makefile -replace "--path-style \w+", "--path-style windows"
    Set-Content -Path "Makefile" -Value $windowsStyle

    # Show configuration
    Write-Host "[DEBUG] GNU Make configuration with Windows paths:" -ForegroundColor Gray
    & $gnuMakePath config

    # Build release version
    Write-Host "[INFO] Building release with Windows paths..." -ForegroundColor Cyan
    & $gnuMakePath release

    if ($LASTEXITCODE -eq 0 -and (Test-Path "main.exe")) {
        Write-Host "[SUCCESS] GNU Make (Windows paths) compilation successful!" -ForegroundColor Green
        Write-Host "[INFO] Testing executable..." -ForegroundColor Cyan
        $output = .\main.exe
        Write-Host $output

        # Rename the executable to prevent overwrite
        if (Test-Path "main_windows.exe") { Remove-Item "main_windows.exe" }
        Rename-Item "main.exe" "main_windows.exe"
    } else {
        Write-Host "[ERROR] GNU Make compilation with Windows paths failed with exit code: $LASTEXITCODE" -ForegroundColor Red
    }

    # Clean between tests
    & $gnuMakePath clean

    # Test with Unix-style paths (forward slashes)
    Write-Host "`n[INFO] Testing with Unix-style paths (--path-style unix)..." -ForegroundColor Cyan

    # Update the Makefile temporarily
    $unixStyle = $makefile -replace "--path-style \w+", "--path-style unix"
    Set-Content -Path "Makefile" -Value $unixStyle

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
        if (Test-Path "main_unix.exe") { Remove-Item "main_unix.exe" }
        Rename-Item "main.exe" "main_unix.exe"
    } else {
        Write-Host "[ERROR] GNU Make compilation with Unix paths failed with exit code: $LASTEXITCODE" -ForegroundColor Red
    }

    # Clean between tests
    & $gnuMakePath clean

    # Test with native-style paths
    Write-Host "`n[INFO] Testing with native-style paths (--path-style native)..." -ForegroundColor Cyan

    # Update the Makefile temporarily
    $nativeStyle = $makefile -replace "--path-style \w+", "--path-style native"
    Set-Content -Path "Makefile" -Value $nativeStyle

    # Show configuration
    Write-Host "[DEBUG] GNU Make configuration with native paths:" -ForegroundColor Gray
    & $gnuMakePath config

    # Build release version
    Write-Host "[INFO] Building release with native paths..." -ForegroundColor Cyan
    & $gnuMakePath release

    if ($LASTEXITCODE -eq 0 -and (Test-Path "main.exe")) {
        Write-Host "[SUCCESS] GNU Make (native paths) compilation successful!" -ForegroundColor Green
        Write-Host "[INFO] Testing executable..." -ForegroundColor Cyan
        $output = .\main.exe
        Write-Host $output

        # Rename the executable to prevent overwrite
        if (Test-Path "main_native.exe") { Remove-Item "main_native.exe" }
        Rename-Item "main.exe" "main_native.exe"
    } else {
        Write-Host "[ERROR] GNU Make compilation with native paths failed with exit code: $LASTEXITCODE" -ForegroundColor Red
    }

    # Restore original Makefile
    Set-Content -Path "Makefile" -Value $makefile

    # Clean up after testing
    & $gnuMakePath clean
} else {
    Write-Host "[WARNING] GNU Make not found at path: $gnuMakePath, skipping GNU Make test" -ForegroundColor Yellow
}
