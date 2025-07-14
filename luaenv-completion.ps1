# LuaEnv PowerShell Tab Completion
# Add this to your PowerShell profile ($PROFILE)

# Set up alias for luaenv
if (Get-Command luaenv.ps1 -ErrorAction SilentlyContinue) {
    Set-Alias -Name luaenv -Value luaenv.ps1 -Force
}

# Also check common installation location
$luaenvPath = Join-Path $env:USERPROFILE ".luaenv\bin\luaenv.ps1"
if (Test-Path $luaenvPath) {
    Set-Alias -Name luaenv -Value $luaenvPath -Force
}

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
            # This prevents suggesting options for non-command arguments
            $completions = $mainCommands
        }
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


# Register completion for both alias and direct script
Register-LuaEnvCompletion
