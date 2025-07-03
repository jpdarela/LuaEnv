# luaenv-merged.ps1 - Combined LuaEnv CLI wrapper and environment activator
#
# Usage:
#   Without 'activate': Acts as CLI wrapper (forwards to LuaEnv.CLI.exe)
#   With 'activate': Sets up PowerShell session for Lua development
#
# Examples:
#   .\luaenv-merged.ps1 list                    # CLI command
#   .\luaenv-merged.ps1 activate --list         # List installations
#   .\luaenv-merged.ps1 activate --alias dev    # Activate 'dev' installation
#   .\luaenv-merged.ps1 activate --devshell "C:\Program Files\Microsoft Visual Studio\2022\Community\Common7\Tools"

param(
    [Parameter(Position=0)]
    [string]$Command = "",

    [Parameter(ValueFromRemainingArguments=$true)]
    [string[]]$Arguments
)

# Define valid commands
$validCommands = @(
    "install",
    "uninstall",
    "list",
    "status",
    "versions",
    "pkg-config",
    "config",
    "help",
    "--help",
    "-h",
    "activate"
)

# Define valid global options that can be used with CLI commands
$validGlobalOptions = @(
    "--config"
)

# Validate command
if ($Command -and $validCommands -notcontains $Command) {
    Write-Host "[ERROR] Unknown command: '$Command'" -ForegroundColor Red
    Write-Host ""
    Write-Host "Valid commands are:" -ForegroundColor Yellow
    Write-Host "  CLI commands:     install, uninstall, list, status, versions, pkg-config, config, help"
    Write-Host "  Script command:   activate"
    Write-Host ""
    Write-Host "For help, use: .\luaenv-merged.ps1 --help" -ForegroundColor Gray
    exit 1
}

# Handle help at the top level
if ($Command -eq "--help" -or $Command -eq "-h" -or $Command -eq "help") {
    Write-Host "LuaEnv - Lua Environment Management Tool" -ForegroundColor Green
    Write-Host "=======================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "USAGE:" -ForegroundColor Yellow
    Write-Host "  .\luaenv-merged.ps1 <command> [options]"
    Write-Host ""
    Write-Host "CLI COMMANDS (forwarded to LuaEnv.CLI.exe):" -ForegroundColor Yellow
    Write-Host "  install [options]              Install a new Lua environment"
    Write-Host "  uninstall <alias|uuid>         Remove a Lua installation"
    Write-Host "  list                           List all installed Lua environments"
    Write-Host "  status                         Show system status and registry information"
    Write-Host "  versions                       Show installed and available versions"
    Write-Host "  pkg-config <alias|uuid>        Show pkg-config information for C developers"
    Write-Host "  config                         Show current configuration"
    Write-Host "  help                           Show CLI help message"
    Write-Host ""
    Write-Host "SCRIPT COMMANDS:" -ForegroundColor Yellow
    Write-Host "  activate [options]             Activate a Lua environment in current shell"
    Write-Host ""
    Write-Host "For command-specific help, use:" -ForegroundColor Yellow
    Write-Host "  .\luaenv-merged.ps1 <command> --help"
    Write-Host ""
    Write-Host "EXAMPLES:" -ForegroundColor Yellow
    Write-Host "  .\luaenv-merged.ps1 install --help" -ForegroundColor Cyan
    Write-Host "  .\luaenv-merged.ps1 activate --help" -ForegroundColor Cyan
    Write-Host "  .\luaenv-merged.ps1 list" -ForegroundColor Cyan
    Write-Host "  .\luaenv-merged.ps1 activate --alias dev" -ForegroundColor Cyan
    exit 0
}

# Check if this is an activate command
if ($Command -eq "activate") {
    # Define valid options for activate command
    $validActivateOptions = @(
        "--id", "-Id",
        "--alias", "-Alias",
        "--tree", "-Tree",
        "--devshell", "-DevShell",
        "--list", "-List",
        "--info", "-Info",
        "--help", "-Help", "-h"
    )

    # Parse activate-specific arguments
    $Id = ""
    $Alias = ""
    $Tree = ""
    $DevShell = ""
    $List = $false
    $Info = $false
    $Help = $false

    # Validate and process arguments for activate command
    for ($i = 0; $i -lt $Arguments.Count; $i++) {
        $arg = $Arguments[$i]

        # Check if it's a flag/option (starts with - or --)
        if ($arg -match '^-') {
            # Validate that it's a known option
            $isValid = $false
            foreach ($validOption in $validActivateOptions) {
                if ($arg -match "^$validOption$") {
                    $isValid = $true
                    break
                }
            }

            if (-not $isValid) {
                Write-Host "[ERROR] Unknown option for activate command: '$arg'" -ForegroundColor Red
                Write-Host ""
                Write-Host "Valid options for 'activate' are:" -ForegroundColor Yellow
                Write-Host "  --id <uuid>        Use installation by UUID"
                Write-Host "  --alias <name>     Use installation by alias name"
                Write-Host "  --tree <path>      Custom LuaRocks package tree path"
                Write-Host "  --devshell <path>  Path to VS Tools folder"
                Write-Host "  --list             List all available installations"
                Write-Host "  --info             Show current environment information"
                Write-Host "  --help             Display help information"
                Write-Host ""
                Write-Host "Use: .\luaenv-merged.ps1 activate --help for more information" -ForegroundColor Gray
                exit 1
            }
        }

        switch -regex ($arg) {
            '^(--id|-Id)$' {
                if ($i + 1 -lt $Arguments.Count) {
                    $Id = $Arguments[++$i]
                }
                else {
                    Write-Host "[ERROR] Option '$arg' requires a value" -ForegroundColor Red
                    exit 1
                }
            }
            '^(--alias|-Alias)$' {
                if ($i + 1 -lt $Arguments.Count) {
                    $Alias = $Arguments[++$i]
                }
                else {
                    Write-Host "[ERROR] Option '$arg' requires a value" -ForegroundColor Red
                    exit 1
                }
            }
            '^(--tree|-Tree)$' {
                if ($i + 1 -lt $Arguments.Count) {
                    $Tree = $Arguments[++$i]
                }
                else {
                    Write-Host "[ERROR] Option '$arg' requires a value" -ForegroundColor Red
                    exit 1
                }
            }
            '^(--devshell|-DevShell)$' {
                if ($i + 1 -lt $Arguments.Count) {
                    $DevShell = $Arguments[++$i]
                }
                else {
                    Write-Host "[ERROR] Option '$arg' requires a value" -ForegroundColor Red
                    exit 1
                }
            }
            '^(--list|-List)$' {
                $List = $true
            }
            '^(--info|-Info)$' {
                $Info = $true
            }
            '^(--help|-Help|-h)$' {
                $Help = $true
            }
        }
    }

    # Display help information if requested
    if ($Help) {
        Write-Host "luaenv activate - LuaEnv Environment Setup" -ForegroundColor Green
        Write-Host "=========================================" -ForegroundColor Green
        Write-Host ""
        Write-Host "DESCRIPTION:" -ForegroundColor Yellow
        Write-Host "  Sets up the current PowerShell session to use a Lua installation from the LuaEnv registry."
        Write-Host "  Automatically configures Visual Studio Developer Shell, PATH, and Lua module paths."
        Write-Host ""
        Write-Host "USAGE:" -ForegroundColor Yellow
        Write-Host "  .\luaenv-merged.ps1 activate [options]"
        Write-Host ""
        Write-Host "OPTIONS:" -ForegroundColor Yellow
        Write-Host "  --id <uuid>        Use installation by UUID (full or partial, minimum 8 characters)"
        Write-Host "  --alias <name>     Use installation by alias name"
        Write-Host "  --tree <path>      Custom LuaRocks package tree path"
        Write-Host "  --devshell <path>  Path to VS Tools folder containing Launch-VsDevShell.ps1"
        Write-Host "                     (saves path to .vspath.txt for future use)"
        Write-Host "  --list             List all available installations"
        Write-Host "  --info             Show current environment information"
        Write-Host "  --help             Display this help information"
        Write-Host ""
        Write-Host "  Note: Both Unix-style (--option) and PowerShell-style (-Option) are supported"
        Write-Host ""
        Write-Host "EXAMPLES:" -ForegroundColor Yellow
        Write-Host "  List available installations:"
        Write-Host "  .\luaenv-merged.ps1 activate --list" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "  Use default installation:"
        Write-Host "  .\luaenv-merged.ps1 activate" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "  Use installation by alias:"
        Write-Host "  .\luaenv-merged.ps1 activate --alias dev" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "  Use installation by partial UUID:"
        Write-Host "  .\luaenv-merged.ps1 activate --id a1b2c3d4" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "  Use installation with custom LuaRocks tree:"
        Write-Host "  .\luaenv-merged.ps1 activate --alias dev --tree 'C:\MyProject\lua_modules'" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "  Set custom Visual Studio path:"
        Write-Host "  .\luaenv-merged.ps1 activate --devshell 'C:\Program Files\Microsoft Visual Studio\2022\Community\Common7\Tools'" -ForegroundColor Cyan
        Write-Host ""
        return
    }

    # Include all the activate functionality from luaenv2.ps1
    function Get-LuaEnvRegistry {
        """Load and parse the LuaEnv registry."""
        $registryPath = Join-Path $env:USERPROFILE ".luaenv\registry.json"

        if (-not (Test-Path $registryPath)) {
            Write-Host "[ERROR] LuaEnv registry not found at: $registryPath" -ForegroundColor Red
            Write-Host "[INFO] Run 'python setup_lua.py' to create your first installation" -ForegroundColor Yellow
            return $null
        }

        try {
            $registryContent = Get-Content $registryPath -Raw | ConvertFrom-Json
            return $registryContent
        }
        catch {
            Write-Host "[ERROR] Failed to load registry: $_" -ForegroundColor Red
            return $null
        }
    }

    function Find-Installation {
        param($registry, $id, $alias)

        # Try alias first if provided
        if ($alias) {
            if ($registry.aliases.PSObject.Properties.Name -contains $alias) {
                $installationId = $registry.aliases.$alias
                if ($registry.installations.PSObject.Properties.Name -contains $installationId) {
                    return $registry.installations.$installationId
                }
            }
            Write-Host "[ERROR] Alias '$alias' not found" -ForegroundColor Red
            return $null
        }

        # Try ID if provided
        if ($id) {
            # Try exact match first
            if ($registry.installations.PSObject.Properties.Name -contains $id) {
                return $registry.installations.$id
            }

            # Try partial match (minimum 8 characters)
            if ($id.Length -ge 8) {
                $matches = @()
                foreach ($installationId in $registry.installations.PSObject.Properties.Name) {
                    if ($installationId.StartsWith($id)) {
                        $matches += $installationId
                    }
                }

                if ($matches.Count -eq 1) {
                    return $registry.installations.($matches[0])
                }
                elseif ($matches.Count -gt 1) {
                    Write-Host "[ERROR] Ambiguous partial ID '$id'. Matches:" -ForegroundColor Red
                    foreach ($match in $matches) {
                        Write-Host "  $match" -ForegroundColor Yellow
                    }
                    return $null
                }
            }

            Write-Host "[ERROR] Installation '$id' not found" -ForegroundColor Red
            return $null
        }

        # Use default installation
        if ($registry.default_installation -and
            $registry.installations.PSObject.Properties.Name -contains $registry.default_installation) {
            return $registry.installations.($registry.default_installation)
        }

        Write-Host "[ERROR] No default installation set" -ForegroundColor Red
        return $null
    }

    function Show-Installations {
        param($registry)

        $installations = @()
        foreach ($prop in $registry.installations.PSObject.Properties) {
            $installations += $prop.Value
        }

        if ($installations.Count -eq 0) {
            Write-Host "[INFO] No installations found" -ForegroundColor Yellow
            Write-Host "[INFO] Run 'python setup_lua.py' to create your first installation" -ForegroundColor Yellow
            return
        }

        Write-Host "[INFO] Available installations:" -ForegroundColor Green
        Write-Host ""

        foreach ($installation in $installations) {
            $isDefault = $registry.default_installation -eq $installation.id
            $status = if ($isDefault) { "[DEFAULT]" } else { "[$($installation.status.ToUpper())]" }
            $aliasInfo = if ($installation.alias) { " (alias: $($installation.alias))" } else { "" }
            $archInfo = if ($installation.architecture) { $installation.architecture } else { "x64" }

            Write-Host "  $status $($installation.name)$aliasInfo" -ForegroundColor $(if ($isDefault) { "Green" } else { "White" })
            Write-Host "    ID: $($installation.id)" -ForegroundColor Gray
            Write-Host "    Lua: $($installation.lua_version), LuaRocks: $($installation.luarocks_version)" -ForegroundColor Gray
            Write-Host "    Build: $($installation.build_type) $($installation.build_config) ($archInfo)" -ForegroundColor Gray
            Write-Host "    Path: $($installation.installation_path)" -ForegroundColor Gray
            if ($installation.last_used) {
                Write-Host "    Last used: $($installation.last_used)" -ForegroundColor Gray
            }
            Write-Host ""
        }
    }

    function Show-EnvironmentInfo {
        Write-Host "[INFO] Current Environment Information:" -ForegroundColor Green
        Write-Host ""

        if ($env:LUAENV_CURRENT) {
            Write-Host "  Active Installation: $env:LUAENV_CURRENT" -ForegroundColor Green
        } else {
            Write-Host "  No LuaEnv installation active" -ForegroundColor Yellow
        }

        if ($env:LUA_PATH) {
            Write-Host "  LUA_PATH: $env:LUA_PATH" -ForegroundColor Gray
        }

        if ($env:LUA_CPATH) {
            Write-Host "  LUA_CPATH: $env:LUA_CPATH" -ForegroundColor Gray
        }

        if ($env:LUAROCKS_CONFIG) {
            Write-Host "  LUAROCKS_CONFIG: $env:LUAROCKS_CONFIG" -ForegroundColor Gray
        }

        # Test if lua and luarocks are available
        try {
            $luaVersion = & lua -v 2>&1
            Write-Host "  Lua Version: $luaVersion" -ForegroundColor Green
        }
        catch {
            Write-Host "  Lua: Not available in PATH" -ForegroundColor Red
        }

        try {
            $luarocksVersion = & luarocks --version 2>&1 | Select-Object -First 1
            Write-Host "  LuaRocks Version: $luarocksVersion" -ForegroundColor Green
        }
        catch {
            Write-Host "  LuaRocks: Not available in PATH" -ForegroundColor Red
        }
    }

    function Get-VsPathConfig {
        """Get Visual Studio path from .vspath.txt config file."""
        $configPath = Join-Path $PSScriptRoot ".vspath.txt"

        if (Test-Path $configPath) {
            try {
                $vsPath = Get-Content $configPath -Raw | ForEach-Object { $_.Trim() }
                if ($vsPath -and (Test-Path $vsPath)) {
                    return $vsPath
                }
            }
            catch {
                Write-Host "[WARNING] Failed to read .vspath.txt: $_" -ForegroundColor Yellow
            }
        }

        return $null
    }

    function Set-VsPathConfig {
        param([string]$VsPath)
        """Save Visual Studio path to .vspath.txt config file."""

        $configPath = Join-Path $PSScriptRoot ".vspath.txt"

        try {
            # Write path to config file
            Set-Content -Path $configPath -Value $VsPath -Force
            Write-Host "[OK] Saved Visual Studio path to .vspath.txt" -ForegroundColor Green
            return $true
        }
        catch {
            Write-Host "[ERROR] Failed to save .vspath.txt: $_" -ForegroundColor Red
            return $false
        }
    }

    function Find-VisualStudioDeveloperShell {
        param(
            [string]$Architecture = "x64",  # Default to x64
            [string]$CustomPath = ""        # Custom VS Tools path
        )
        """Find and initialize Visual Studio Developer Shell."""

        # Determine VS arch parameter based on architecture
        $vsArch = if ($Architecture -eq "x86") { "x86" } else { "amd64" }

        Write-Host "[INFO] Setting up Visual Studio Developer Shell for $Architecture architecture..."

        # Priority 1: Try custom path if provided
        if ($CustomPath) {
            $launchPath = Join-Path $CustomPath "Launch-VsDevShell.ps1"
            if (Test-Path $launchPath) {
                Write-Host "[OK] Found Visual Studio Developer Shell at custom path: $launchPath"
                Write-Host "[INFO] Configuring for $Architecture build ($vsArch toolset)"
                & $launchPath -Arch $vsArch -SkipAutomaticLocation >$null 2>&1
                # Save the custom path for future use
                Set-VsPathConfig -VsPath $CustomPath
                return $true
            }
            else {
                Write-Host "[ERROR] Launch-VsDevShell.ps1 not found at: $CustomPath" -ForegroundColor Red
                return $false
            }
        }

        # Priority 2: Try path from .vspath.txt config
        $configPath = Get-VsPathConfig
        if ($configPath) {
            $launchPath = Join-Path $configPath "Launch-VsDevShell.ps1"
            if (Test-Path $launchPath) {
                Write-Host "[OK] Found Visual Studio Developer Shell from config: $launchPath"
                Write-Host "[INFO] Configuring for $Architecture build ($vsArch toolset)"
                & $launchPath -Arch $vsArch -SkipAutomaticLocation >$null 2>&1
                return $true
            }
            else {
                Write-Host "[WARNING] Configured VS path no longer valid: $configPath" -ForegroundColor Yellow
            }
        }

        # Priority 3: Try using vswhere to find VS installation
        $vswherePath = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
        if (Test-Path $vswherePath) {
            Write-Host "[INFO] Searching for Visual Studio installation using vswhere..."
            try {
                $vsPath = & $vswherePath -latest -property installationPath 2>$null
                if ($vsPath) {
                    $launchPath = Join-Path $vsPath "Common7\Tools\Launch-VsDevShell.ps1"
                    if (Test-Path $launchPath) {
                        Write-Host "[OK] Found Visual Studio Developer Shell via vswhere: $launchPath"
                        Write-Host "[INFO] Configuring for $Architecture build ($vsArch toolset)"
                        & $launchPath -Arch $vsArch -SkipAutomaticLocation >$null 2>&1
                        return $true
                    }
                }
            }
            catch {
                Write-Host "[WARNING] vswhere failed: $_"
            }
        }

        # Priority 4: Try common VS paths
        $vsPaths = @(
            "${env:ProgramFiles}\Microsoft Visual Studio\2022\Enterprise\Common7\Tools\Launch-VsDevShell.ps1",
            "${env:ProgramFiles}\Microsoft Visual Studio\2022\Professional\Common7\Tools\Launch-VsDevShell.ps1",
            "${env:ProgramFiles}\Microsoft Visual Studio\2022\Community\Common7\Tools\Launch-VsDevShell.ps1",
            "${env:ProgramFiles(x86)}\Microsoft Visual Studio\2019\Enterprise\Common7\Tools\Launch-VsDevShell.ps1",
            "${env:ProgramFiles(x86)}\Microsoft Visual Studio\2019\Professional\Common7\Tools\Launch-VsDevShell.ps1",
            "${env:ProgramFiles(x86)}\Microsoft Visual Studio\2019\Community\Common7\Tools\Launch-VsDevShell.ps1"
        )

        foreach ($vsPath in $vsPaths) {
            if (Test-Path $vsPath) {
                Write-Host "[OK] Found Visual Studio Developer Shell: $vsPath"
                Write-Host "[INFO] Configuring for $Architecture build ($vsArch toolset)"
                & $vsPath -Arch $vsArch -SkipAutomaticLocation >$null 2>&1
                return $true
            }
        }

        Write-Host "[WARNING] Visual Studio Developer Shell not found. C extension compilation may not work." -ForegroundColor Yellow
        Write-Host "[INFO] Install Visual Studio with C++ build tools for full functionality." -ForegroundColor Yellow
        Write-Host "[INFO] Or specify VS path with: --devshell <path>" -ForegroundColor Yellow
        return $false
    }

    function Setup-LuaEnvironment {
        param($installation, $customTree, $customDevShell)

        $installPath = $installation.installation_path
        $envPath = $installation.environment_path

        # Get architecture from installation (default to x64 if not specified)
        $architecture = if ($installation.architecture) { $installation.architecture } else { "x64" }

        # Validate installation
        $luaExe = Join-Path $installPath "bin\lua.exe"
        $luarocksExe = Join-Path $installPath "luarocks\luarocks.exe"

        if (-not (Test-Path $luaExe)) {
            Write-Host "[ERROR] Lua executable not found: $luaExe" -ForegroundColor Red
            return $false
        }

        if (-not (Test-Path $luarocksExe)) {
            Write-Host "[ERROR] LuaRocks executable not found: $luarocksExe" -ForegroundColor Red
            return $false
        }

        Write-Host "[INFO] Setting up environment for: $($installation.name)" -ForegroundColor Green
        Write-Host "[INFO] Architecture: $architecture" -ForegroundColor Gray
        Write-Host "[INFO] Installation: $installPath" -ForegroundColor Gray
        Write-Host "[INFO] Environment: $envPath" -ForegroundColor Gray

        # Find and setup Visual Studio Developer Shell with correct architecture
        $vsFound = Find-VisualStudioDeveloperShell -Architecture $architecture -CustomPath $customDevShell

        # Determine LuaRocks tree path
        $luarocksTree = if ($customTree) {
            $customTree
        } else {
            $envPath
        }

        # Create directories if they don't exist
        if (-not (Test-Path $luarocksTree)) {
            New-Item -ItemType Directory -Path $luarocksTree -Force | Out-Null
            Write-Host "[INFO] Created LuaRocks tree: $luarocksTree" -ForegroundColor Gray
        }

        # Clear conflicting environment variables
        $env:LUAROCKS_SYSCONFIG = $null
        $env:LUAROCKS_USERCONFIG = $null
        $env:LUAROCKS_PREFIX = $null

        # Set LuaEnv current installation
        $env:LUAENV_CURRENT = $installation.id

        # Add Lua and LuaRocks to PATH
        $luaBinPath = Join-Path $installPath "bin"
        $luarocksBinPath = Join-Path $installPath "luarocks"
        $env:PATH = "$luaBinPath;$luarocksBinPath;$env:PATH"

        # Configure Lua module paths
        $luaLibPath = Join-Path $luarocksTree "lib\lua\5.4"
        $luaSharePath = Join-Path $luarocksTree "share\lua\5.4"

        $env:LUA_PATH = ".\?.lua;.\?\init.lua;$luaSharePath\?.lua;$luaSharePath\?\init.lua;;"
        $env:LUA_CPATH = ".\?.dll;$luaLibPath\?.dll;;"

        # Create LuaRocks configuration
        $luarocksConfigDir = Join-Path $env:TEMP "luarocks-config"
        if (-not (Test-Path $luarocksConfigDir)) {
            New-Item -ItemType Directory -Path $luarocksConfigDir -Force | Out-Null
        }

        $luarocksConfigFile = Join-Path $luarocksConfigDir "config.lua"
        $luaIncDir = Join-Path $installPath "include"
        $luaLibDir = Join-Path $installPath "lib"

        $configContent = @"
-- LuaRocks configuration for LuaEnv installation: $($installation.id)
rocks_trees = {
    { name = "user", root = "$($luarocksTree.Replace('\', '\\'))" }
}
lua_interpreter = "$($luaExe.Replace('\', '\\'))"
lua_version = "5.4"
lua_incdir = "$($luaIncDir.Replace('\', '\\'))"
lua_libdir = "$($luaLibDir.Replace('\', '\\'))"
lua_bindir = "$($luaBinPath.Replace('\', '\\'))"
lua_lib = "lua54.lib"
"@

        # Write config file without BOM
        $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
        [System.IO.File]::WriteAllText($luarocksConfigFile, $configContent, $utf8NoBom)

        $env:LUAROCKS_CONFIG = $luarocksConfigFile
        $env:LUAROCKS_SYSCONFDIR = $luarocksConfigDir

        Write-Host "[OK] Lua environment configured successfully!" -ForegroundColor Green

        # Display version information
        try {
            Write-Host "[INFO] Lua version:" -ForegroundColor Yellow
            & lua -v
            Write-Host "[INFO] LuaRocks version:" -ForegroundColor Yellow
            & luarocks --version | Select-Object -First 1
        }
        catch {
            Write-Host "[WARNING] Could not verify installation" -ForegroundColor Yellow
        }

        Write-Host "[INFO] Environment variables set:" -ForegroundColor Yellow
        Write-Host "  LUAENV_CURRENT: $env:LUAENV_CURRENT" -ForegroundColor Gray
        Write-Host "  LUA_PATH: $env:LUA_PATH" -ForegroundColor Gray
        Write-Host "  LUA_CPATH: $env:LUA_CPATH" -ForegroundColor Gray
        Write-Host "  LUAROCKS_CONFIG: $env:LUAROCKS_CONFIG" -ForegroundColor Gray
        Write-Host "  PATH updated with Lua and LuaRocks directories" -ForegroundColor Gray
        Write-Host ""
        Write-Host "[SUCCESS] You can now use 'lua' and 'luarocks' commands in this shell session." -ForegroundColor Green

        # Update last used timestamp
        try {
            & python -c "from registry import LuaEnvRegistry; LuaEnvRegistry().update_last_used('$($installation.id)')" 2>$null
        }
        catch {
            # Silently ignore registry update failures
        }

        return $true
    }

    # Main activate logic
    try {
        # Load registry
        $registry = Get-LuaEnvRegistry
        if (-not $registry) {
            exit 1
        }

        # Handle list command
        if ($List) {
            Show-Installations $registry
            return
        }

        # Handle info command
        if ($Info) {
            Show-EnvironmentInfo
            return
        }

        # Find installation
        $installation = Find-Installation $registry $Id $Alias
        if (-not $installation) {
            Write-Host "[INFO] Available installations:" -ForegroundColor Yellow
            Show-Installations $registry
            exit 1
        }

        # Setup environment
        $success = Setup-LuaEnvironment $installation $Tree $DevShell
        if (-not $success) {
            exit 1
        }
    }
    catch {
        Write-Host "[ERROR] Script failed: $_" -ForegroundColor Red
        exit 1
    }
}
else {
    # CLI wrapper functionality (from luaenv.ps1)
    # For CLI commands, validate that no invalid options are passed

    # Define known CLI command options
    $cliCommandOptions = @{
        "install" = @("--help", "--alias", "--build", "--config", "--arch", "--luarocks", "--update", "--set-default")
        "uninstall" = @("--help")
        "list" = @("--help", "--json", "--detailed")
        "status" = @("--help")
        "versions" = @("--help")
        "pkg-config" = @("--help")
        "config" = @("--help")
    }

    # Check if we know about this command's options
    if ($Command -and $cliCommandOptions.ContainsKey($Command)) {
        $validOptions = $cliCommandOptions[$Command] + $validGlobalOptions

        # Validate all arguments that look like options
        for ($i = 0; $i -lt $Arguments.Count; $i++) {
            $arg = $Arguments[$i]

            # If it looks like an option (starts with -)
            if ($arg -match '^-') {
                $isValid = $false

                # Check against valid options for this command
                foreach ($validOption in $validOptions) {
                    if ($arg -eq $validOption) {
                        $isValid = $true
                        break
                    }
                }

                # Special case: --config requires a value
                if ($arg -eq "--config" -and $i + 1 -lt $Arguments.Count) {
                    $i++ # Skip the next argument as it's the config value
                }

                if (-not $isValid) {
                    Write-Host "[ERROR] Unknown option '$arg' for command '$Command'" -ForegroundColor Red
                    Write-Host ""
                    Write-Host "Valid options for '$Command' are:" -ForegroundColor Yellow
                    foreach ($opt in $cliCommandOptions[$Command]) {
                        Write-Host "  $opt" -ForegroundColor Gray
                    }
                    if ($validGlobalOptions.Count -gt 0) {
                        Write-Host ""
                        Write-Host "Global options:" -ForegroundColor Yellow
                        foreach ($opt in $validGlobalOptions) {
                            Write-Host "  $opt" -ForegroundColor Gray
                        }
                    }
                    Write-Host ""
                    Write-Host "For help, use: .\luaenv-merged.ps1 $Command --help" -ForegroundColor Gray
                    exit 1
                }
            }
        }
    }

    function Invoke-LuaEnvCLI {
        # Get the directory where this script is located (bin directory)
        $BinDir = $PSScriptRoot

        # Set the backend config path
        $BackendConfig = Join-Path $BinDir "backend.config"

        # Set the CLI executable path
        $CliExe = Join-Path $BinDir "cli\LuaEnv.CLI.exe"

        # Check if config exists
        if (-not (Test-Path $BackendConfig)) {
            Write-Error "[ERROR] Backend configuration not found: $BackendConfig"
            exit 1
        }

        # Check if CLI exists
        if (-not (Test-Path $CliExe)) {
            Write-Error "[ERROR] CLI executable not found: $CliExe"
            exit 1
        }

        # Build arguments array
        $allArgs = @()
        if ($Command) {
            $allArgs += $Command
        }
        $allArgs += $Arguments

        # Execute CLI with config and pass through all arguments
        & $CliExe --config $BackendConfig $allArgs
    }

    # Call the CLI function
    Invoke-LuaEnvCLI
}