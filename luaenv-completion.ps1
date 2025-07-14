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

    # Parse command line into words
    $words = $commandAst.ToString() -split '\s+' | Where-Object { $_ -ne '' }

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
        'current' = @('--verbose', '--help', '-h')
        'local' = @('--unset', '--help', '-h')
    }

    # Determine what to complete based on position
    $completions = @()

    if ($words.Count -eq 1 -or ($words.Count -eq 2 -and $wordToComplete)) {
        # Complete main commands (first argument after luaenv)
        $completions = $mainCommands
    } elseif ($words.Count -ge 2) {
        # Complete options for specific commands
        $command = $words[1]
        if ($commandOptions.ContainsKey($command)) {
            $completions = $commandOptions[$command]
        } else {
            # Default help options for commands without specific options
            $completions = @('--help', '-h')
        }
    }

    # Filter and return matches
    $completions | Where-Object { $_ -like "$wordToComplete*" } | ForEach-Object {
        [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
    }
}

# Register completion for both alias and direct script
Register-ArgumentCompleter -CommandName luaenv -ScriptBlock $luaenvCompleter
Register-ArgumentCompleter -CommandName luaenv.ps1 -ScriptBlock $luaenvCompleter

Write-Host "LuaEnv tab completion loaded. Try: luaenv <TAB>" -ForegroundColor Green
