#!/usr/bin/env pwsh

<#
.SYNOPSIS
    Comprehensive Lua Package Installation and Testing Script

.DESCRIPTION
    This script activates a LuaEnv environment and installs a comprehensive list
    of famous and popular Lua packages using LuaRocks. It tests the compatibility
    and functionality of LuaEnv with the broader Lua ecosystem.

.PARAMETER Environment
    The Lua environment to activate (alias or UUID). If not specified, uses default.

.PARAMETER SkipInstall
    If specified, skips package installation and only runs tests.

.PARAMETER TestOnly
    Space-separated list of specific packages to test (instead of all).

.EXAMPLE
    .\install_famous_packages.ps1

.EXAMPLE
    .\install_famous_packages.ps1 -Environment "dev"

.EXAMPLE
    .\install_famous_packages.ps1 -SkipInstall -TestOnly "luasocket fennel"
#>

param(
    [string]$Environment = "test_packages",
    [switch]$SkipInstall = $false,
    [string]$TestOnly = ""
)

# Define comprehensive list of famous Lua packages categorized by purpose

# Required external tools libraries:
# OpenSSL (for luasec) installed via vcpkg

$LuaPackages = @{
    # Core Utilities and Libraries
    "Core" = @(
        "penlight",          # Lua utility library (like Python's standard library)
        "luafilesystem",     # File system manipulation
        "luasocket",         # Network programming
        "luasec",            # SSL/TLS support (Requires OpenSSL)
        "lua-cjson",         # Fast JSON encoding/decoding
        "lpeg",              # Parsing Expression Grammars
        "stdlib",            # Standard library extensions
        "compat53",          # Lua 5.3+ compatibility for older versions
        "luasystem",         # System utilities (environment, process info, platform detection)
        "lua-term"           # Terminal control (colors, cursor, screen clearing)
    )

    # Language Extensions and Compilers
    "Language" = @(
        "fennel",            # Lisp that compiles to Lua (version 1.4.2-1)
        "moonscript",        # Language that compiles to Lua
        "yuescript",         # Another language that compiles to Lua
        "lua-parser"         # Lua parser written in Lua
    )

    # # Web Development and HTTP
    # "Web" = @(
    #     "lua-resty-http",    # HTTP client for OpenResty/ngx_lua
    #     "httpclient",        # Simple HTTP client
    #     "copas",             # Coroutine-based networking
    #     "xavante",           # Lua web server
    #     "wsapi",             # Web Server API for Lua
    #     "sailor",            # MVC framework for Lua
    #     "lapis",             # Web framework (may have dependencies)
    #     "turbo"              # Async web framework
    # )

    # # Database and Data
    # "Database" = @(
    #     "luasql-sqlite3",    # SQLite3 database driver
    #     "redis-lua",         # Redis client
    #     "lua-resty-redis",   # Redis for OpenResty
    #     "luadbi",            # Database abstraction layer
    #     "cassandra",         # Cassandra database driver
    #     "elasticsearch-lua"  # Elasticsearch client
    # )

    # # Template Engines
    # "Templates" = @(
    #     "lustache",          # Mustache templates for Lua
    #     "etlua",             # Embedded Lua templates
    #     "cosmo",             # Template library
    #     "lua-resty-template" # Templating for OpenResty
    # )

    # # Testing and Development
    # "Testing" = @(
    #     "busted",            # BDD-style testing framework
    #     "luaunit",           # Unit testing framework
    #     "telescope",         # BDD testing framework
    #     "luacov",            # Coverage analysis
    #     "ldoc",              # Documentation generator
    #     "luacheck"           # Static analyzer and linter
    # )

    # # Math and Science
    # "Math" = @(
    #     "torch",             # Machine learning (may be complex)
    #     "sci",               # Scientific computing
    #     "numlua",            # Numerical computing
    #     "complex",           # Complex numbers
    #     "matrix",            # Matrix operations
    #     "lcomplex"           # Complex number library
    # )

    # # Graphics and Game Development
    # "Graphics" = @(
    #     "love",              # 2D game framework (may need special setup)
    #     "cairo",             # 2D graphics library
    #     "gd",                # Graphics library
    #     "lua-gd"             # GD graphics binding
    # )

    # # Serialization and Data Formats
    # "Serialization" = @(
    #     "lua-messagepack",   # MessagePack serialization
    #     "xml",               # XML processing
    #     "yaml",              # YAML processing
    #     "base64",            # Base64 encoding/decoding
    #     "md5",               # MD5 hashing
    #     "sha1",              # SHA1 hashing
    #     "lua-zlib"           # Compression
    # )

    # # Windows-Specific and System
    # "Windows" = @(
    #     "winapi",            # Windows API bindings
    #     "linenoise-windows", # Readline alternative for Windows
    #     "lanes",             # Multithreading
    #     "luaproc",           # Message-passing concurrency
    #     "copilot"            # Process control
    # )

    # # Utilities and Tools
    # "Utilities" = @(
    #     "argparse",          # Command-line argument parsing
    #     "lunajson",          # Pure Lua JSON
    #     "inspect",           # Pretty printing/debugging
    #     "say",               # String interpolation and formatting
    #     "tabular",           # Table manipulation
    #     "moses",             # Utility library
    #     "ansicolors",        # ANSI color codes
    #     "uuid"               # UUID generation
    # )
}

# Colors for output
$Colors = @{
    Header = "Cyan"
    Success = "Green"
    Warning = "Yellow"
    Error = "Red"
    Info = "Gray"
    Category = "Magenta"
}

function Write-ColorOutput {
    param(
        [string]$Message,
        [string]$Color = "White"
    )
    Write-Host $Message -ForegroundColor $Colors[$Color]
}

function Test-LuaPackage {
    param(
        [string]$PackageName,
        [string]$Category
    )

    Write-Host "  Testing $PackageName... " -NoNewline

    # Special test cases for packages that need specific testing
    $testScript = switch ($PackageName) {
        "luasocket" { "local s = require('socket'); print(s._VERSION or 'OK')" }
        "luasec" { "local ssl = require('ssl'); print('SSL available')" }
        "fennel" { "local f = require('fennel'); print('Fennel v' .. (f.version or 'unknown'))" }
        "penlight" { "local pl = require('pl'); print('Penlight OK')" }
        "lua-cjson" { "local cjson = require('cjson'); local t = cjson.encode({test=123}); print('JSON: ' .. t)" }
        "lpeg" { "local lpeg = require('lpeg'); print('LPEG v' .. (lpeg.version or 'OK'))" }
        "luafilesystem" { "local lfs = require('lfs'); print('LFS: ' .. lfs.currentdir())" }
        "stdlib" { "local std = require('std'); print('stdlib v' .. (std.version or 'unknown')); local list = require('std.list'); print('List module: ' .. type(list))" }
        "compat53" { "local compat53 = require('compat53'); print('Compat53 loaded - Lua 5.3 features available')" }
        "luasystem" { "local sys = require('system'); print('LuaSystem ' .. sys._VERSION .. ' - Windows: ' .. tostring(sys.windows))" }
        "lua-term" { "local term = require('term'); print('lua-term - TTY: ' .. tostring(term.isatty(io.stdout)) .. ', Colors: ' .. type(term.colors))" }
        "fennel" { "local f = require('fennel'); print('Fennel v' .. (f.version or 'unknown'))" }
        "winapi" { "local w = require('winapi'); print('PID: ' .. w.get_current_pid())" }
        "linenoise-windows" { "local ln = require('linenoise'); print('Linenoise OK')" }
        "inspect" { "local inspect = require('inspect'); print(inspect({test=123}))" }
        "argparse" { "local argparse = require('argparse'); print('Argparse OK')" }
        default { "local m = require('$PackageName'); print('$PackageName loaded successfully')" }
    }

    try {
        $output = & lua -e "$testScript" 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Host "✓ PASS" -ForegroundColor Green
            if ($output -and $output -ne $PackageName) {
                Write-Host "    Output: $output" -ForegroundColor Gray
            }
            return @{ Package = $PackageName; Category = $Category; Status = "PASS"; Output = $output }
        } else {
            Write-Host "✗ FAIL" -ForegroundColor Red
            Write-Host "    Error: $output" -ForegroundColor Red
            return @{ Package = $PackageName; Category = $Category; Status = "FAIL"; Output = $output }
        }
    }
    catch {
        Write-Host "✗ ERROR" -ForegroundColor Red
        Write-Host "    Exception: $_" -ForegroundColor Red
        return @{ Package = $PackageName; Category = $Category; Status = "ERROR"; Output = $_.Exception.Message }
    }
}

function Install-LuaPackage {
    param(
        [string]$PackageName,
        [string]$Category
    )

    Write-Host "  Installing $PackageName... " -NoNewline

    try {
        # Special handling for packages that need specific versions
        if ($PackageName -eq "fennel") {
            $output = & luarocks install fennel 1.4.2-1 2>&1
        } else {
            $output = & luarocks install $PackageName 2>&1
        }
        if ($LASTEXITCODE -eq 0) {
            Write-Host "✓ SUCCESS" -ForegroundColor Green
            return @{ Package = $PackageName; Category = $Category; Status = "SUCCESS"; Output = "" }
        } else {
            Write-Host "✗ FAILED" -ForegroundColor Red
            # Show only the most relevant error line
            $errorLine = ($output | Where-Object { $_ -match "Error:" } | Select-Object -First 1) -replace "Error: ", ""
            if ($errorLine) {
                Write-Host "    Error: $errorLine" -ForegroundColor Red
            }
            return @{ Package = $PackageName; Category = $Category; Status = "FAILED"; Output = $errorLine }
        }
    }
    catch {
        Write-Host "✗ ERROR" -ForegroundColor Red
        Write-Host "    Exception: $_" -ForegroundColor Red
        return @{ Package = $PackageName; Category = $Category; Status = "ERROR"; Output = $_.Exception.Message }
    }
}

# Main script execution
Write-ColorOutput "=== LuaEnv Comprehensive Package Testing ===" "Header"
Write-Host ""

# Activate LuaEnv environment
if ($Environment) {
    Write-ColorOutput "Preparing LuaEnv environment. One minute: $Environment" "Info"
    # Send output to null to avoid cluttering the console
    # & luaenv uninstall $Environment --yes > $null 2>&1
    # & luaenv install --alias $Environment --dll > $null 2>&1 # Install the environment for testing
    & luaenv activate $Environment
} else {
    Write-ColorOutput "Activating default LuaEnv environment" "Info"
    & luaenv activate
}

if ($LASTEXITCODE -ne 0) {
    Write-ColorOutput "Failed to activate LuaEnv environment!" "Error"
    exit 1
}

Write-Host ""

# Get list of packages to process
$packagesToProcess = @()
if ($TestOnly) {
    $testPackages = $TestOnly -split '\s+'
    foreach ($pkg in $testPackages) {
        $category = "Manual"
        foreach ($cat in $LuaPackages.Keys) {
            if ($LuaPackages[$cat] -contains $pkg) {
                $category = $cat
                break
            }
        }
        $packagesToProcess += @{ Package = $pkg; Category = $category }
    }
} else {
    foreach ($category in $LuaPackages.Keys) {
        foreach ($package in $LuaPackages[$category]) {
            $packagesToProcess += @{ Package = $package; Category = $category }
        }
    }
}

$totalPackages = $packagesToProcess.Count
Write-ColorOutput "Processing $totalPackages packages..." "Info"
Write-Host ""

# Installation phase
$installResults = @()
if (-not $SkipInstall) {
    Write-ColorOutput "=== INSTALLATION PHASE ===" "Header"
    Write-Host ""

    $currentCategory = ""
    foreach ($item in $packagesToProcess) {
        if ($item.Category -ne $currentCategory) {
            $currentCategory = $item.Category
            Write-ColorOutput "[$currentCategory Packages]" "Category"
        }

        $result = Install-LuaPackage -PackageName $item.Package -Category $item.Category
        $installResults += $result
    }
}

# Testing phase
Write-Host ""
Write-ColorOutput "=== TESTING PHASE ===" "Header"
Write-Host ""

$testResults = @()
$currentCategory = ""
foreach ($item in $packagesToProcess) {
    if ($item.Category -ne $currentCategory) {
        $currentCategory = $item.Category
        Write-ColorOutput "[$currentCategory Packages]" "Category"
    }

    $result = Test-LuaPackage -PackageName $item.Package -Category $item.Category
    $testResults += $result
}

# Generate comprehensive report
Write-Host ""
Write-ColorOutput "=== COMPREHENSIVE REPORT ===" "Header"
Write-Host ""

# Summary statistics
$totalTested = $testResults.Count
$passCount = ($testResults | Where-Object { $_.Status -eq "PASS" }).Count
$failCount = ($testResults | Where-Object { $_.Status -eq "FAIL" }).Count
$errorCount = ($testResults | Where-Object { $_.Status -eq "ERROR" }).Count

Write-ColorOutput "Total packages tested: $totalTested" "Info"
Write-ColorOutput "✓ Successful: $passCount" "Success"
Write-ColorOutput "✗ Failed: $failCount" "Error"
Write-ColorOutput "⚠ Errors: $errorCount" "Warning"
Write-Host ""

$successRate = [math]::Round(($passCount / $totalTested) * 100, 1)
Write-ColorOutput "Success Rate: $successRate%" $(if ($successRate -gt 80) { "Success" } elseif ($successRate -gt 60) { "Warning" } else { "Error" })
Write-Host ""

# Category breakdown
Write-ColorOutput "Results by Category:" "Header"
foreach ($category in ($testResults | Group-Object Category | Sort-Object Name)) {
    $catPassed = ($category.Group | Where-Object { $_.Status -eq "PASS" }).Count
    $catTotal = $category.Group.Count
    $catRate = [math]::Round(($catPassed / $catTotal) * 100, 1)

    $color = if ($catRate -gt 80) { "Success" } elseif ($catRate -gt 50) { "Warning" } else { "Error" }
    Write-ColorOutput "  $($category.Name): $catPassed/$catTotal ($catRate%)" $color
}
Write-Host ""

# Failed packages detail
$failedPackages = $testResults | Where-Object { $_.Status -ne "PASS" }
if ($failedPackages.Count -gt 0) {
    Write-ColorOutput "Failed Packages:" "Header"
    foreach ($failed in $failedPackages) {
        Write-ColorOutput "  ✗ $($failed.Package) [$($failed.Category)] - $($failed.Status)" "Error"
        if ($failed.Output) {
            Write-Host "    $($failed.Output)" -ForegroundColor Gray
        }
    }
    Write-Host ""
}

# Successful packages
$successfulPackages = $testResults | Where-Object { $_.Status -eq "PASS" }
if ($successfulPackages.Count -gt 0) {
    Write-ColorOutput "✓ Successfully Working Packages:" "Success"
    foreach ($category in ($successfulPackages | Group-Object Category | Sort-Object Name)) {
        Write-ColorOutput "  [$($category.Name)]" "Category"
        foreach ($pkg in $category.Group) {
            Write-Host "    ✓ $($pkg.Package)" -ForegroundColor Green
        }
    }
    Write-Host ""
}

# Installation summary (if installation was performed)
if (-not $SkipInstall -and $installResults.Count -gt 0) {
    $installedCount = ($installResults | Where-Object { $_.Status -eq "SUCCESS" }).Count
    $installFailedCount = ($installResults | Where-Object { $_.Status -ne "SUCCESS" }).Count

    Write-ColorOutput "Installation Summary:" "Header"
    Write-ColorOutput "  ✓ Successfully installed: $installedCount" "Success"
    Write-ColorOutput "  ✗ Installation failed: $installFailedCount" "Error"
    Write-Host ""
}

# Recommendations
Write-ColorOutput "=== RECOMMENDATIONS ===" "Header"
Write-Host ""

if ($successRate -gt 80) {
    Write-ColorOutput "🎉 Excellent! LuaEnv has outstanding compatibility with the Lua ecosystem." "Success"
} elseif ($successRate -gt 60) {
    Write-ColorOutput "👍 Good! LuaEnv works well with most popular Lua packages." "Success"
} else {
    Write-ColorOutput "⚠️  Some compatibility issues detected. See failed packages above." "Warning"
}

Write-Host ""
Write-ColorOutput "For production use, focus on the successfully tested packages." "Info"
Write-ColorOutput "Consider investigating alternatives for failed packages." "Info"

# Save detailed report to file
$reportFile = "luaenv_core_packages_test_report_$(Get-Date -Format 'yyyyMMdd_HHmmss').txt"
$report = @"
LuaEnv Core Packages Test Report
Generated: $(Get-Date)
Environment: $Environment
Total Packages: $totalTested
Success Rate: $successRate%

SUCCESSFUL PACKAGES:
$($successfulPackages | ForEach-Object { "✓ $($_.Package) [$($_.Category)]" } | Out-String)

FAILED PACKAGES:
$($failedPackages | ForEach-Object { "✗ $($_.Package) [$($_.Category)] - $($_.Status): $($_.Output)" } | Out-String)
"@

$report | Out-File -FilePath $reportFile -Encoding UTF8
Write-ColorOutput "Detailed report saved to: $reportFile" "Info"

Write-Host ""
Write-ColorOutput "=== Test Complete ===" "Header"
