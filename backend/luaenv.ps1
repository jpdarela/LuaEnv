#!/usr/bin/env pwsh

# This is free and unencumbered software released into the public domain.
# For more details, see the LICENSE file in the project root.

<#
.SYNOPSIS
    LuaEnv - Lua Environment Management Tool

.DESCRIPTION
    Cross-platform Lua environment management tool that provides environment
    isolation, version management, and development tool integration.

.PARAMETER Command
    The command to execute (activate, deactivate, current, local, help, etc.)

.PARAMETER Arguments
    Additional arguments for the command

.EXAMPLE
    .\luaenv.ps1 activate dev
    Activates the 'dev' Lua environment

.EXAMPLE
    .\luaenv.ps1 help
    Shows help information

.NOTES
    Author: LuaEnv Project
    License: Public Domain
#>

param(
    [Parameter(Position=0)]
    [string]$Command,

    [Parameter(ValueFromRemainingArguments=$true)]
    [string[]]$Arguments
)

# Set strict mode for better error handling
Set-StrictMode -Version Latest

# ==================================================================================
# Load global settings
# ==================================================================================

# Load global settings from global.psm1
$globalModulePath = Join-Path $PSScriptRoot "global.psm1"
if (Test-Path $globalModulePath) {
    Import-Module $globalModulePath -Force -ErrorAction Stop
} else {
    Write-Error "Global settings module not found: $globalModulePath"
}

if ($VERBOSE_MESSAGES -eq "Continue") { $VerbosePreference = "Continue" } else { $VerbosePreference = "SilentlyContinue" }
if ($DEBUG_MESSAGES -eq "Continue") { $DebugPreference = "Continue" } else { $DebugPreference = "SilentlyContinue" }
if ($WARNING_MESSAGES -eq "Continue") { $WarningPreference = "Continue" } else { $WarningPreference = "SilentlyContinue" }

# ==================================================================================
# MODULE LOADING (LOAD ONCE, USE EFFICIENTLY)
# ==================================================================================

# Get the directory containing this script
$ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Definition

# Define module paths
$coreModulePath = Join-Path $ScriptRoot "luaenv_core.psm1"
$uiModulePath = Join-Path $ScriptRoot "luaenv_ui.psm1"
$vsModulePath = Join-Path $ScriptRoot "luaenv_vs.psm1"

# Load modules efficiently (only if not already loaded)
function Import-LuaEnvModules {
    param([switch]$Force)

    $modulesToLoad = @(
        @{ Name = "luaenv_core"; Path = $coreModulePath },
        @{ Name = "luaenv_ui"; Path = $uiModulePath },
        @{ Name = "luaenv_vs"; Path = $vsModulePath }
    )

    foreach ($module in $modulesToLoad) {
        $isLoaded = Get-Module -Name $module.Name -ErrorAction SilentlyContinue

        if ($Force -or -not $isLoaded) {
            if ($isLoaded) {
                Remove-Module -Name $module.Name -Force -ErrorAction SilentlyContinue
            }

            if (Test-Path $module.Path) {
                try {
                    Import-Module $module.Path -Force -ErrorAction Stop
                    Write-Verbose "Successfully imported $($module.Name) module"
                } catch {
                    Write-Error "Failed to import $($module.Name) module: $($_.Exception.Message)"
                    return $false
                }
            } else {
                Write-Error "Module not found: $($module.Path)"
                return $false
            }
        }
    }
    return $true

}

# Load modules once at startup
if (-not (Import-LuaEnvModules)) {
    Write-Error "Failed to load required modules"
    exit 1
}

# ==================================================================================
# COMMAND IMPLEMENTATIONS
# ==================================================================================

function Invoke-ActivateCommand {
    param([string[]]$Arguments)

    # Parse activate arguments
    $alias = $null
    $id = $null
    $showList = $false
    $showEnv = $false
    $customTree = $null
    $customDevShell = $null

    # Handle null or empty arguments
    if (-not $Arguments) {
        $Arguments = @()
    }

    for ($i = 0; $i -lt $Arguments.Length; $i++) {
        switch ($Arguments[$i]) {
            "--help" { Show-ActivateHelp; return }
            "-h" { Show-ActivateHelp; return }
            "--list" { $showList = $true }
            "--env" { $showEnv = $true }
            "--tree" {
                if ($i + 1 -lt $Arguments.Length) {
                    $customTree = $Arguments[++$i]
                } else {
                    Write-Error "Missing value for --tree option"
                    return
                }
            }
            "--devshell" {
                if ($i + 1 -lt $Arguments.Length) {
                    $customDevShell = $Arguments[++$i]
                } else {
                    Write-Error "Missing value for --devshell option"
                    return
                }
            }
            "--alias" {
                if ($i + 1 -lt $Arguments.Length) {
                    $alias = $Arguments[++$i]
                } else {
                    Write-Error "Missing value for --alias option"
                    return
                }
            }
            "--id" {
                if ($i + 1 -lt $Arguments.Length) {
                    $id = $Arguments[++$i]
                } else {
                    Write-Error "Missing value for --id option"
                    return
                }
            }
            default {
                # Positional argument (shorthand for alias)
                if (-not $Arguments[$i].StartsWith('-') -and -not $alias -and -not $id) {
                    $alias = $Arguments[$i]
                } else {
                    Write-Warning "Unexpected argument: $($Arguments[$i])"
                }
            }
        }
    }

    # Handle --list option
    if ($showList) {
        $registry = Get-LuaEnvRegistry -Force
        if ($registry) {
            Show-Installations -Registry $registry
        }
        return
    }

    # Handle --env option
    if ($showEnv) {
        Show-EnvironmentInfo
        return
    }

    # Main activation logic
    try {
        $registry = Get-LuaEnvRegistry -Force
        if (-not $registry) {
            Write-Host "[ERROR] Failed to load registry" -ForegroundColor Red
            return
        }

        # Find installation using priority logic
        $localVersion = Get-LocalLuaVersion
        $installation = Find-Installation -Registry $registry -Id $id -Alias $alias -UsePriority -LocalVersion $localVersion

        if (-not $installation) {
            if ($alias -or $id) {
                Write-Host "[ERROR] No Lua installation found matching: $($alias)$($id)" -ForegroundColor Red
            } else {
                Write-Host "[ERROR] No local version or default installation found" -ForegroundColor Red
                Write-Host "[INFO] To set a local version: luaenv local <alias|uuid>" -ForegroundColor Yellow
                Write-Host "[INFO] Available installations:" -ForegroundColor Yellow
            }
            Show-Installations -Registry $registry
            return
        }

        # Initialize the environment
        $success = Initialize-LuaEnvironment -Installation $installation -CustomTree $customTree -CustomDevShell $customDevShell

        if (-not $success) {
            Write-Host "[ERROR] Failed to initialize Lua environment" -ForegroundColor Red
            return
        }

        # Set prompt to show the active environment
        $promptAlias = if ($installation.alias) { $installation.alias } else { $installation.name }
        $promptSet = Set-LuaEnvPrompt -Alias $promptAlias
        if ($promptSet) {
            Write-Verbose "Set prompt to show active environment: $promptAlias"
        } else {
            Write-Warning "Failed to set custom prompt"
        }

        # Clean up PATH by removing duplicate entries
        $uniquePaths = $env:PATH -split ';' | Select-Object -Unique
        $env:PATH = $uniquePaths -join ';'

        Write-Host "[OK] Activated $($installation.name) environment" -ForegroundColor Green

    } catch {
        Write-Host "[ERROR] Environment activation failed: $($_.Exception.Message)" -ForegroundColor Red
    }
}

function Invoke-DeactivateCommand {
    param([string[]]$Arguments)

    # Handle null arguments
    if (-not $Arguments) {
        $Arguments = @()
    }

    # Handle help
    if ($Arguments -contains "--help" -or $Arguments -contains "-h") {
        Show-DeactivateHelp
        return
    }

    if (-not (Test-LuaEnvActive)) {
        Write-Host "[INFO] No LuaEnv environment is currently active" -ForegroundColor Yellow
        return
    }

    try {
        # Restore original PATH
        if ($env:LUAENV_ORIGINAL_PATH) {
            $env:PATH = $env:LUAENV_ORIGINAL_PATH
            Write-Host "[OK] Restored original PATH" -ForegroundColor Green
        } else {
            Write-Host "[WARNING] Original PATH not found, performing best-effort cleanup" -ForegroundColor Yellow

            # Best-effort cleanup: remove LuaEnv-specific paths from PATH
            $pathEntries = $env:PATH.Split(';')
            $cleanedEntries = $pathEntries | Where-Object {
                -not ($_ -like "*\.luaenv\installations\*\bin" -or
                      $_ -like "*\.luaenv\installations\*\luarocks" -or
                      $_ -like "*\.luaenv\environments\*\bin")
            }
            $env:PATH = $cleanedEntries -join ';'
        }

        # Restore original prompt function
        $promptRemoved = Remove-LuaEnvPrompt
        if ($promptRemoved) {
            Write-Verbose "Restored original prompt"
        } else {
            Write-Warning "Failed to restore original prompt"
        }

        # Clear LuaEnv environment variables
        $luaEnvVars = @(
            "LUAENV_CURRENT", "LUAENV_ORIGINAL_PATH", "LUAENV_PROMPT_ALIAS",
            "LUA_PATH", "LUA_CPATH", "LUA_BINDIR", "LUA_INCDIR", "LUA_LIBDIR", "LUA_LIBRARIES",
            "LUAROCKS_CONFIG", "LUAROCKS_SYSCONFDIR", "LUAROCKS_SYSCONFIG", "LUAROCKS_USERCONFIG", "LUAROCKS_PREFIX"
        )

        foreach ($var in $luaEnvVars) {
            if ([Environment]::GetEnvironmentVariable($var, "Process")) {
                [Environment]::SetEnvironmentVariable($var, $null, "Process")
            }
        }

        Write-Host "[OK] LuaEnv environment deactivated" -ForegroundColor Green
        Write-Host "[INFO] You may need to restart your shell to completely reset all environment variables" -ForegroundColor Cyan

    } catch {
        Write-Host "[ERROR] Failed to deactivate environment: $($_.Exception.Message)" -ForegroundColor Red
    }
}

function Invoke-CurrentCommand {
    param([string[]]$Arguments)

    # Handle null arguments
    if (-not $Arguments) {
        $Arguments = @()
    }

    # Handle help
    if ($Arguments -contains "--help" -or $Arguments -contains "-h") {
        Show-CurrentHelp
        return
    }

    $verbose = $Arguments -contains "--verbose" -or $Arguments -contains "-v"

    if (-not (Test-LuaEnvActive)) {
        Write-Host "[INFO] No LuaEnv environment is currently active" -ForegroundColor Yellow
        Write-Host "To activate an environment, use: luaenv activate <alias|id>" -ForegroundColor Cyan
        return
    }

    try {
        $registry = Get-LuaEnvRegistry -Force
        if ($registry) {
            Show-CurrentEnvironment -Registry $registry -ShowVerbose:$verbose
        } else {
            Write-Host "[ERROR] Failed to load registry" -ForegroundColor Red
        }
    } catch {
        Write-Host "[ERROR] Failed to get current environment: $($_.Exception.Message)" -ForegroundColor Red
    }
}

function Invoke-LocalCommand {
    param([string[]]$Arguments)

    # Handle help
    if ($Arguments -contains "--help" -or $Arguments -contains "-h") {
        Show-LocalHelp
        return
    }

    # Handle null or empty arguments
    if (-not $Arguments -or $Arguments.Length -eq 0) {
        # Show current local version
        $localVersion = Get-LocalLuaVersion
        if ($localVersion) {
            $registry = Get-LuaEnvRegistry -Force
            Show-LocalVersion -LocalVersion $localVersion -Registry $registry
        } else {
            Write-Host "No local version configured for this directory" -ForegroundColor Yellow
            Write-Host "[INFO] Use 'luaenv local <alias|uuid>' to set a local version" -ForegroundColor Yellow
        }
        return
    }

    $firstArg = $Arguments[0]

    if ($firstArg -eq "--unset" -or $firstArg -eq "-u") {
        # Remove local version
        if (Remove-LocalLuaVersion) {
            Write-Host "[OK] Removed local version configuration" -ForegroundColor Green
        } else {
            Write-Host "[INFO] No local version was configured" -ForegroundColor Cyan
        }
        return
    }

    # Set local version
    try {
        # Load registry to validate the version
        $registry = Get-LuaEnvRegistry -Force
        if (-not $registry) {
            Write-Host "[ERROR] Failed to load registry" -ForegroundColor Red
            return
        }

        # Validate that the provided version exists
        $installation = Find-Installation -Registry $registry -Id $firstArg -Alias $firstArg

        if ($installation) {
            # Valid installation found, save to .lua-version file
            if (Set-LocalLuaVersion -Version $firstArg) {
                Write-Host "[OK] Local version set to: $firstArg" -ForegroundColor Green
                Write-Host "[OK] $($installation.name) ($($installation.lua_version), $($installation.luarocks_version))" -ForegroundColor Green
                Write-Host "[INFO] Run 'luaenv activate' to use this version now" -ForegroundColor Cyan
            }
        } else {
            Write-Host "[ERROR] Installation not found: $firstArg" -ForegroundColor Red
            Write-Host "[INFO] Use 'luaenv list' to see available installations" -ForegroundColor Yellow
        }
    } catch {
        Write-Host "[ERROR] Failed to set local version: $($_.Exception.Message)" -ForegroundColor Red
    }
}

function Invoke-LuaEnvCLI {
    # Get the CLI executable and configuration paths
    $BinDir = $ScriptRoot
    $BackendConfig = Join-Path $BinDir "backend.config"
    $CliExe = Join-Path $BinDir "cli\LuaEnv.CLI.exe"

    # Validate required files exist
    if (-not (Test-Path $BackendConfig)) {
        Write-Host "[ERROR] Backend configuration not found: $BackendConfig" -ForegroundColor Red
        exit 1
    }

    if (-not (Test-Path $CliExe)) {
        Write-Host "[ERROR] CLI executable not found: $CliExe" -ForegroundColor Red
        exit 1
    }

    # Build complete arguments array for CLI
    $allArgs = @()
    if ($Command) {
        $allArgs += $Command
    }
    $allArgs += $Arguments

    # Execute CLI with backend configuration and forward all arguments
    try {
        & $CliExe --config $BackendConfig $allArgs
    } catch {
        Write-Host "[ERROR] Failed to execute CLI command: $($_.Exception.Message)" -ForegroundColor Red
        exit 1
    }
}

# ==================================================================================
# COMMAND ROUTING
# ==================================================================================

# PowerShell parameter completion for LuaEnv
$luaenvCompleter = {
    param($wordToComplete, $commandAst, $cursorPosition)

    # Convert commandAst to string and split into words
    $commandLine = $commandAst.ToString()
    $words = @($commandLine -split '\s+' | Where-Object { $_ -ne '' })

   # Main commands available in LuaEnv
    $mainCommands = @(
        'activate', 'deactivate', 'current', 'local',
        'install', 'uninstall', 'list', 'status', 'versions',
        'default', 'pkg-config', 'config', 'set-alias', 'remove-alias', 'help'
    )

    # Command-specific options
    $commandOptions = @{
        'activate' = @('--id', '--alias', '--list', '--env', '--tree', '--devshell', '--help', '-h')
        'deactivate' = @('--help', '-h')
        'current' = @('--verbose', '-v', '--help', '-h')
        'local' = @('--unset', '-u', '--help', '-h')
        'install' = @('--lua-version', '--luarocks-version', '--alias', '--name',
                      '--dll', '--debug', '--x86', '--x64', '--skip-env-check',
                      '--skip-tests', '--help', '-h')
        'uninstall' = @('--force', '--yes', '--help', '-h')
        'list' = @('--detailed', '--help', '-h')
        'status' = @('--help', '-h')
        'versions' = @('--available', '-a', '--online', '--refresh', '--help', '-h')
        'default' = @('--help', '-h')
        'pkg-config' = @('--cflag', '--lua-include', '--liblua', '--libdir',
                         '--path', '--path-style', '--help', '-h')
        'config' = @('--help', '-h')
        'set-alias' = @('--help', '-h')
        'remove-alias' = @('--help', '-h')
        'help' = @()
    }

    $completions = @()

    # Determine what we're completing
    if ($words.Count -eq 1) {
        # Only the command name, complete with main commands
        $completions = $mainCommands
    }
    elseif ($words.Count -eq 2) {
        # We have "luaenv" and we're completing the first argument
        if ($mainCommands.Contains($words[1])) {
            $completions = $commandOptions[$words[1]]
        } else {
            # If the first argument is not a command, do not suggest options nor main commands
            $completions = $mainCommands
        }
        # $completions = $mainCommands
    }
    elseif ($words.Count -ge 3) {
        # We have "luaenv command ..." and we're completing options
        $command = $words[1]
        if ($commandOptions.ContainsKey($command)) {
            $completions = $commandOptions[$command]
        } else {
            $completions = @('--help', '-h')
        }
    }

    # Filter completions based on what the user has typed
    $filteredCompletions = $completions | Where-Object { $_ -like "$wordToComplete*" }

    # Return completion results
    $filteredCompletions | ForEach-Object {
        [System.Management.Automation.CompletionResult]::new(
            $_,                  # completionText
            $_,                  # listItemText
            'ParameterValue',    # resultType
            $_                   # toolTip
        )
    }
}

# Function to register or re-register the luaenv completers
function Register-LuaEnvCompletion {
    # Register the completers
    try {
        Register-ArgumentCompleter -Native -CommandName luaenv -ScriptBlock $luaenvCompleter
        Register-ArgumentCompleter -Native -CommandName luaenv.ps1 -ScriptBlock $luaenvCompleter
        Write-Verbose "LuaEnv tab completion registered successfully"
    }
    catch {
        Write-Warning "Failed to register LuaEnv completion: $_"
    }
}


# Handle empty command
if (-not $Command) {
    Show-LuaEnvHelp
    exit 0
}

# Route commands
switch ($Command.ToLower()) {
    "activate" {
        # Force reload modules for activate (needed for environment setup)
        Import-LuaEnvModules | Out-Null
        Invoke-ActivateCommand @Arguments
        Register-LuaEnvCompletion
    }
    "deactivate" {
        # Don't force reload for deactivate - just use already loaded modules
        Invoke-DeactivateCommand @Arguments
        Register-LuaEnvCompletion
    }
    "current" {
        Invoke-CurrentCommand @Arguments
        Register-LuaEnvCompletion
    }
    "local" {
        Invoke-LocalCommand @Arguments
        Register-LuaEnvCompletion
    }
    { $_ -in @("help", "-h", "--help", "/?") } {
        Show-LuaEnvHelp
        Register-LuaEnvCompletion
    }
    default {
        # For all other commands, delegate to CLI
        Invoke-LuaEnvCLI
        Register-LuaEnvCompletion
    }
}
