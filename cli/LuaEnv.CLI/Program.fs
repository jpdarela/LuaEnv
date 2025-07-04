open System
open LuaEnv.Core
open LuaEnv.Core.Config
open LuaEnv.Core.Backend

/// Display help information
let showHelp () =
    printfn "LuaEnv CLI - Lua Environment Management Tool"
    printfn ""
    printfn "USAGE:"
    printfn "    luaenv <command> [options]"
    printfn ""
    printfn "COMMANDS:"
    printfn "    install [options]              Install a new Lua environment"
    printfn "    uninstall <alias|uuid>         Remove a Lua installation"
    printfn "    list                           List all installed Lua environments"
    printfn "    status                         Show system status and registry information"
    printfn "    versions                       Show installed and available versions"
    printfn "    pkg-config <alias|uuid>        Show pkg-config information for C developers"
    printfn "    set-alias <alias|uuid> <new>   Set or update an installation alias"
    printfn "    config                         Show current configuration"
    printfn "    help                           Show this help message"
    printfn ""
    printfn "For command-specific help, use:"
    printfn "    luaenv install --help"
    printfn "    luaenv uninstall --help"
    printfn "    luaenv list --help"
    printfn "    luaenv status --help"
    printfn "    luaenv versions --help"
    printfn "    luaenv pkg-config --help"
    printfn ""
    printfn "NOTE: 'luaenv' is a wrapper script that automatically passes the --config"
    printfn "      parameter to the CLI executable located in ~/.luaenv/bin/cli/"

/// Display install-specific help
let showInstallHelp () =
    printfn "LuaEnv CLI - Install Command"
    printfn ""
    printfn "USAGE:"
    printfn "    luaenv install [options]"
    printfn ""
    printfn "DESCRIPTION:"
    printfn "    Install a new Lua environment with specified versions and options."
    printfn ""
    printfn "OPTIONS:"
    printfn "    --lua-version <version>        Use specific Lua version (e.g. 5.4.7, 5.3.6)"
    printfn "    --luarocks-version <version>   Use specific LuaRocks version (e.g. 3.11.1)"
    printfn "    --alias <name>                 Set an alias for the installation"
    printfn "    --name <display-name>          Set display name for the installation"
    printfn "    --dll                          Build as DLL instead of static library"
    printfn "    --debug                        Include debug symbols"
    printfn "    --x86                          Build for x86 (32-bit) architecture"
    printfn "    --x64                          Build for x64 (64-bit) architecture (default)"
    printfn "    --skip-env-check               Skip Visual Studio environment check"
    printfn "    --skip-tests                   Skip test suite after building"
    printfn "    --help, -h                     Show this help message"
    printfn ""
    printfn "ARCHITECTURE:"
    printfn "    By default, installs are built for x64 (64-bit) architecture."
    printfn "    Use --x86 for 32-bit builds. The backend will automatically download"
    printfn "    the appropriate LuaRocks binaries for the target architecture."
    printfn ""
    printfn "EXAMPLES:"
    printfn "    luaenv install"
    printfn "    luaenv install --alias dev --dll"
    printfn "    luaenv install --x86 --alias legacy"
    printfn "    luaenv install --lua-version 5.3.6 --alias old"
    printfn "    luaenv install --luarocks-version 3.11.1 --alias stable"

/// Display uninstall-specific help
let showUninstallHelp () =
    printfn "LuaEnv CLI - Uninstall Command"
    printfn ""
    printfn "USAGE:"
    printfn "    luaenv uninstall <alias|uuid> [options]"
    printfn ""
    printfn "DESCRIPTION:"
    printfn "    Remove a Lua installation completely, including all files and registry entries."
    printfn ""
    printfn "ARGUMENTS:"
    printfn "    <alias|uuid>                   Installation alias or UUID to remove"
    printfn ""
    printfn "OPTIONS:"
    printfn "    --force, --yes                 Skip confirmation prompt"
    printfn "    --help, -h                     Show this help message"
    printfn ""
    printfn "EXAMPLES:"
    printfn "    luaenv uninstall dev"
    printfn "    luaenv uninstall a1b2c3d4 --force"
    printfn "    luaenv uninstall my-project --yes"

/// Display list-specific help
let showListHelp () =
    printfn "LuaEnv CLI - List Command"
    printfn ""
    printfn "USAGE:"
    printfn "    luaenv list [options]"
    printfn ""
    printfn "DESCRIPTION:"
    printfn "    List all installed Lua environments with their details."
    printfn ""
    printfn "OPTIONS:"
    printfn "    --detailed                     Show detailed information including paths, validation, and disk usage"
    printfn "    --help, -h                     Show this help message"
    printfn ""
    printfn "EXAMPLES:"
    printfn "    luaenv list                    # Basic list from backend"
    printfn "    luaenv list --detailed         # Detailed list with validation and disk usage"

/// Display status-specific help
let showStatusHelp () =
    printfn "LuaEnv CLI - Status Command"
    printfn ""
    printfn "USAGE:"
    printfn "    luaenv status"
    printfn ""
    printfn "DESCRIPTION:"
    printfn "    Show comprehensive system status and registry information."
    printfn ""
    printfn "OPTIONS:"
    printfn "    --help, -h                     Show this help message"
    printfn ""
    printfn "STATUS EXPLANATIONS:"
    printfn "    [ACTIVE]     Installation is working and available for use"
    printfn "    [BROKEN]     Installation has issues and may need repair"
    printfn "    [BUILDING]   Installation is currently being set up"
    printfn "    [INACTIVE]   Installation exists but is not currently usable (zombie)"
    printfn ""
    printfn "NOTE: The 'list' command shows [DEFAULT] instead of status for the default"
    printfn "      installation, while 'status' shows actual status for all installations."
    printfn ""
    printfn "USEFUL COMMANDS:"
    printfn "    luaenv list                    Show detailed installation information"
    printfn "    luaenv install                 Install a new Lua environment"
    printfn "    luaenv default <alias>         Set a different default installation"
    printfn ""
    printfn "EXAMPLES:"
    printfn "    luaenv status"

/// Display set-alias-specific help
let showSetAliasHelp () =
    printfn "LuaEnv CLI - Set-Alias Command"
    printfn ""
    printfn "USAGE:"
    printfn "    luaenv set-alias <alias|uuid> <new-alias>"
    printfn ""
    printfn "DESCRIPTION:"
    printfn "    Set or update an alias for a Lua installation."
    printfn ""
    printfn "ARGUMENTS:"
    printfn "    <alias|uuid>                   Installation alias or UUID to modify"
    printfn "    <new-alias>                    New alias to assign to the installation"
    printfn ""
    printfn "OPTIONS:"
    printfn "    --help, -h                     Show this help message"
    printfn ""
    printfn "EXAMPLES:"
    printfn "    luaenv set-alias fe5253dd-ee2d-488a-9a38-70534ae9d2e6 dev-lua54"
    printfn "    luaenv set-alias old-alias new-alias"
    printfn ""

/// Display versions-specific help
let showVersionsHelp () =
    printfn "LuaEnv CLI - Versions Command"
    printfn ""
    printfn "USAGE:"
    printfn "    luaenv versions [options]"
    printfn ""
    printfn "DESCRIPTION:"
    printfn "    Show version information for installed and available Lua/LuaRocks versions."
    printfn ""
    printfn "DEFAULT BEHAVIOR:"
    printfn "    luaenv versions                Show installed versions (fast, direct registry access)"
    printfn ""
    printfn "OPTIONS:"
    printfn "    --available, -a                Show versions available for installation (online lookup)"
    printfn "    --online                       Alias for --available (online lookup)"
    printfn "    --refresh                      Force refresh of online version cache (use with --available)"
    printfn "    --help, -h                     Show this help message"
    printfn ""
    printfn "EXAMPLES:"
    printfn "    luaenv versions                # Show installed versions"
    printfn "    luaenv versions --available    # Discover available versions (cached)"
    printfn "    luaenv versions -a --refresh   # Refresh and show available versions"
    printfn ""
    printfn "OUTPUT FORMATS:"
    printfn "    Installed: alias/id | Lua version | LuaRocks version | architecture [DEFAULT]"
    printfn "    Available: Comprehensive list with current defaults marked and cache status"

/// Display pkg-config-specific help
let showPkgConfigHelp () =
    printfn "LuaEnv CLI - Pkg-Config Command"
    printfn ""
    printfn "USAGE:"
    printfn "    luaenv pkg-config <alias|uuid> [options]"
    printfn ""
    printfn "DESCRIPTION:"
    printfn "    Generate pkg-config style information for C developers to integrate"
    printfn "    Lua installations into their build systems."
    printfn ""
    printfn "ARGUMENTS:"
    printfn "    <alias|uuid>                   Installation alias or UUID (full or partial)"
    printfn ""
    printfn "OPTIONS:"
    printfn "    --cflag                        Show compiler flag with /I prefix"
    printfn "    --lua-include                  Show include directory path only"
    printfn "    --liblua                       Show resolved path to lua54.lib file only"
    printfn "    --path                         Show installation paths only"
    printfn "    --path-style <style>           Output path style ('windows', 'unix', or 'native')"
    printfn "    --help, -h                     Show this help message"
    printfn ""
    printfn "EXAMPLES:"
    printfn "    luaenv pkg-config dev          # Show all pkg-config information"
    printfn "    luaenv pkg-config old_x86 --cflag  # Show compiler flag (/I\"path\")"
    printfn "    luaenv pkg-config dynamic --lua-include # Show include directory path"
    printfn "    luaenv pkg-config static --liblua # Show path to lua54.lib file"
    printfn "    luaenv pkg-config devel --path   # Show paths for installation"
    printfn "    luaenv pkg-config a6f63bc5 --path-style unix # Use forward slashes for paths. Get installation by UUID (atial match, 8 characters)"
    printfn ""
    printfn "USAGE IN BUILD SYSTEMS:"
    printfn "    Batch file:     for /f %%i in ('luaenv pkg-config dev --cflag') do set CFLAGS=%%i"
    printfn "    PowerShell:     $cflags = luaenv pkg-config dev --cflag"
    printfn "    nmake:          !IF [luaenv pkg-config dev --cflag > temp.txt] == 0"
    printfn "    CMake:          execute_process(COMMAND luaenv pkg-config dev --cflag ...)"
    printfn ""
    printfn "NOTE: For DLL builds, ensure lua54.dll is available at runtime by:"
    printfn "      - Copying lua54.dll to your application directory, or"
    printfn "      - Adding the DLL directory to your system PATH, or"
    printfn "      - Using SetDllDirectory() in your application code"
    printfn "      Use '--path' to see the DLL location for dynamically linked builds."

/// Command line argument parsing
type CliArgs = {
    ConfigPath: string option
    Command: Command option
}

/// Parse command line arguments
let parseArgs (args: string array) : CliArgs =
    let rec parseArgsRec args acc =
        match args with
        | [] -> acc
        | "--config" :: configPath :: rest ->
            parseArgsRec rest { acc with ConfigPath = Some configPath }
        | "--help" :: rest ->
            parseArgsRec rest { acc with Command = Some Help }
        | "-h" :: rest ->
            parseArgsRec rest { acc with Command = Some Help }
        | "help" :: rest ->
            parseArgsRec rest { acc with Command = Some Help }
        | "install" :: rest ->
            try
                let installOptions = parseInstallOptions rest
                { acc with Command = Some (Install installOptions) }
            with
            | Failure "HELP_REQUESTED" ->
                { acc with Command = Some Help }
        | "uninstall" :: "--help" :: rest ->
            showUninstallHelp ()
            exit 0
        | "uninstall" :: "-h" :: rest ->
            showUninstallHelp ()
            exit 0
        | "uninstall" :: idOrAlias :: rest when not (String.IsNullOrWhiteSpace(idOrAlias)) ->
            try
                let uninstallOptions = parseUninstallOptions idOrAlias rest
                { acc with Command = Some (Uninstall uninstallOptions) }
            with
            | Failure "HELP_REQUESTED" ->
                { acc with Command = Some Help }
        | "uninstall" :: rest ->
            printfn "[ERROR] Missing required argument: <alias|uuid>"
            printfn "Use 'luaenv uninstall --help' for usage information"
            exit 1
        | "list" :: rest ->
            try
                let listOptions = parseListOptions rest
                { acc with Command = Some (List listOptions) }
            with
            | Failure "HELP_REQUESTED" ->
                { acc with Command = Some Help }
        | "status" :: rest ->
            try
                let statusOptions = parseStatusOptions rest
                { acc with Command = Some (Status statusOptions) }
            with
            | Failure "HELP_REQUESTED" ->
                { acc with Command = Some Help }
        | "config" :: rest ->
            parseArgsRec rest { acc with Command = Some ShowConfig }
        | "versions" :: rest ->
            try
                let versionsOptions = parseVersionsOptions rest
                { acc with Command = Some (Versions versionsOptions) }
            with
            | Failure "HELP_REQUESTED" ->
                { acc with Command = Some Help }
        | "pkg-config" :: "--help" :: rest ->
            showPkgConfigHelp ()
            exit 0
        | "pkg-config" :: "-h" :: rest ->
            showPkgConfigHelp ()
            exit 0
        | "pkg-config" :: installation :: rest when not (String.IsNullOrWhiteSpace(installation)) ->
            try
                let pkgConfigOptions = parsePkgConfigOptions installation rest
                { acc with Command = Some (PkgConfig pkgConfigOptions) }
            with
            | Failure "HELP_REQUESTED" ->
                { acc with Command = Some Help }
        | "pkg-config" :: rest ->
            printfn "[ERROR] Missing required argument: <alias|uuid>"
            printfn "Use 'luaenv pkg-config --help' for usage information"
            exit 1
        | "set-alias" :: "--help" :: rest ->
            showSetAliasHelp ()
            exit 0
        | "set-alias" :: "-h" :: rest ->
            showSetAliasHelp ()
            exit 0
        | "set-alias" :: idOrAlias :: newAlias :: rest when
            not (String.IsNullOrWhiteSpace(idOrAlias)) ->
            try
                // Only validate idOrAlias is not empty, allow empty alias
                let setAliasOptions = {
                    IdOrAlias = idOrAlias
                    NewAlias = newAlias // Even if empty string, this will be properly handled
                }
                { acc with Command = Some (SetAlias setAliasOptions) }
            with
            | Failure "HELP_REQUESTED" ->
                { acc with Command = Some Help }
        | "set-alias" :: [idOrAlias] ->
            printfn "[ERROR] Missing required argument: <new-alias>"
            printfn "Use 'luaenv set-alias --help' for usage information"
            exit 1
        | "set-alias" :: [] ->
            printfn "[ERROR] Missing required arguments: <alias|uuid> <new-alias>"
            printfn "Use 'luaenv set-alias --help' for usage information"
            exit 1
        | arg :: rest ->
            printfn "[ERROR] Unknown argument: %s" arg
            printfn "Use 'luaenv --help' for available commands"
            exit 1

    and parseInstallOptions args =
        let rec parseInstallRec args acc =
            match args with
            | [] -> acc
            | "--help" :: rest ->
                // Return Help command for install help
                showInstallHelp ()
                exit 0
            | "-h" :: rest ->
                // Return Help command for install help
                showInstallHelp ()
                exit 0
            | "--lua-version" :: version :: rest ->
                parseInstallRec rest ({ acc with LuaVersion = Some version } : InstallOptions)
            | "--lua-version" :: [] ->
                printfn "[ERROR] Missing value for option: --lua-version"
                printfn "Use 'luaenv install --help' for available options"
                exit 1
            | "--luarocks-version" :: version :: rest ->
                parseInstallRec rest ({ acc with LuaRocksVersion = Some version } : InstallOptions)
            | "--luarocks-version" :: [] ->
                printfn "[ERROR] Missing value for option: --luarocks-version"
                printfn "Use 'luaenv install --help' for available options"
                exit 1
            | "--alias" :: alias :: rest ->
                parseInstallRec rest ({ acc with Alias = Some alias } : InstallOptions)
            | "--alias" :: [] ->
                printfn "[ERROR] Missing value for option: --alias"
                printfn "Use 'luaenv install --help' for available options"
                exit 1
            | "--name" :: name :: rest ->
                parseInstallRec rest ({ acc with Name = Some name } : InstallOptions)
            | "--name" :: [] ->
                printfn "[ERROR] Missing value for option: --name"
                printfn "Use 'luaenv install --help' for available options"
                exit 1
            | "--dll" :: rest ->
                parseInstallRec rest ({ acc with UseDll = true } : InstallOptions)
            | "--debug" :: rest ->
                parseInstallRec rest ({ acc with UseDebug = true } : InstallOptions)
            | "--x86" :: rest ->
                parseInstallRec rest ({ acc with UseX86 = true } : InstallOptions)
            | "--x64" :: rest ->
                parseInstallRec rest ({ acc with UseX86 = false } : InstallOptions)
            | "--skip-env-check" :: rest ->
                parseInstallRec rest ({ acc with SkipEnvCheck = true } : InstallOptions)
            | "--skip-tests" :: rest ->
                parseInstallRec rest ({ acc with SkipTests = true } : InstallOptions)
            | arg :: rest ->
                printfn "[ERROR] Unknown install option: %s" arg
                printfn "Use 'luaenv install --help' for available options"
                exit 1

        try
            parseInstallRec args ({
                LuaVersion = None
                LuaRocksVersion = None
                Alias = None
                Name = None
                UseDll = false
                UseDebug = false
                UseX86 = false
                SkipEnvCheck = false
                SkipTests = false
            } : InstallOptions)
        with
        | Failure "HELP_REQUESTED" ->
            // This will cause the parent parser to return Help command
            failwith "HELP_REQUESTED"

    and parseUninstallOptions idOrAlias args =
        let rec parseUninstallRec args acc =
            match args with
            | [] -> acc
            | "--help" :: rest ->
                // Return Help command for uninstall help
                showUninstallHelp ()
                exit 0
            | "-h" :: rest ->
                // Return Help command for uninstall help
                showUninstallHelp ()
                exit 0
            | "--force" :: rest ->
                parseUninstallRec rest { acc with Force = true }
            | "--yes" :: rest ->
                parseUninstallRec rest { acc with Force = true }
            | arg :: rest ->
                printfn "[ERROR] Unknown uninstall option: %s" arg
                printfn "Use 'luaenv uninstall --help' for available options"
                exit 1

        try
            parseUninstallRec args {
                IdOrAlias = idOrAlias
                Force = false
            }
        with
        | Failure "HELP_REQUESTED" ->
            // This will cause the parent parser to return Help command
            failwith "HELP_REQUESTED"

    and parseListOptions args =
        let rec parseListRec args acc =
            match args with
            | [] -> acc
            | "--help" :: rest ->
                // Return Help command for list help
                showListHelp ()
                exit 0
            | "-h" :: rest ->
                // Return Help command for list help
                showListHelp ()
                exit 0
            | "--detailed" :: rest ->
                parseListRec rest { ListOptions.Detailed = true }
            | arg :: rest ->
                printfn "[ERROR] Unknown list option: %s" arg
                printfn "Use 'luaenv list --help' for available options"
                exit 1

        try
            parseListRec args { Detailed = false }
        with
        | Failure "HELP_REQUESTED" ->
            // This will cause the parent parser to return Help command
            failwith "HELP_REQUESTED"

    and parseStatusOptions args =
        let rec parseStatusRec args acc =
            match args with
            | [] -> acc
            | "--help" :: rest ->
                // Return Help command for status help
                showStatusHelp ()
                exit 0
            | "-h" :: rest ->
                // Return Help command for status help
                showStatusHelp ()
                exit 0
            | arg :: rest ->
                printfn "[ERROR] Unknown status option: %s" arg
                printfn "Use 'luaenv status --help' for available options"
                exit 1

        try
            parseStatusRec args ()
        with
        | Failure "HELP_REQUESTED" ->
            // This will cause the parent parser to return Help command
            failwith "HELP_REQUESTED"

    and parseVersionsOptions args =
        let rec parseVersionsRec args acc =
            match args with
            | [] -> acc
            | "--help" :: rest ->
                showVersionsHelp ()
                exit 0
            | "-h" :: rest ->
                showVersionsHelp ()
                exit 0
            | "--available" :: rest ->
                parseVersionsRec rest { acc with ShowAvailable = true }
            | "-a" :: rest ->
                parseVersionsRec rest { acc with ShowAvailable = true }
            | "--online" :: rest ->
                parseVersionsRec rest { acc with ShowAvailable = true }
            | "--refresh" :: rest ->
                parseVersionsRec rest { acc with Refresh = true }
            | arg :: rest ->
                printfn "[ERROR] Unknown versions option: %s" arg
                printfn "Use 'luaenv versions --help' for available options"
                exit 1

        try
            parseVersionsRec args { ShowAvailable = false; Refresh = false }
        with
        | Failure "HELP_REQUESTED" ->
            failwith "HELP_REQUESTED"

    and parsePkgConfigOptions installation args =
        let rec parsePkgConfigRec args acc =
            match args with
            | [] -> acc
            | "--help" :: rest ->
                // Return Help command for pkg-config help
                showPkgConfigHelp ()
                exit 0
            | "-h" :: rest ->
                // Return Help command for pkg-config help
                showPkgConfigHelp ()
                exit 0
            | "--cflag" :: rest ->
                parsePkgConfigRec rest { acc with ShowCFlag = true }
            | "--lua-include" :: rest ->
                parsePkgConfigRec rest { acc with ShowLuaInclude = true }
            | "--liblua" :: rest ->
                parsePkgConfigRec rest { acc with ShowLibLua = true }
            | "--path" :: rest ->
                parsePkgConfigRec rest { acc with ShowPaths = true }
            | "--path-style" :: style :: rest when List.contains style ["windows"; "unix"; "native"] ->
                parsePkgConfigRec rest { acc with PathStyle = Some style }
            | "--path-style" :: style :: rest ->
                printfn "[ERROR] Invalid path style: %s. Must be one of: 'windows', 'unix', 'native'" style
                printfn "Use 'luaenv pkg-config --help' for available options"
                exit 1
            | "--path-style" :: [] ->
                printfn "[ERROR] Missing value for option: --path-style"
                printfn "Use 'luaenv pkg-config --help' for available options"
                exit 1
            | arg :: rest ->
                printfn "[ERROR] Unknown pkg-config option: %s" arg
                printfn "Use 'luaenv pkg-config --help' for available options"
                exit 1

        try
            parsePkgConfigRec args { Installation = installation; ShowCFlag = false; ShowLuaInclude = false; ShowLibLua = false; ShowPaths = false; PathStyle = None }
        with
        | Failure "HELP_REQUESTED" ->
            // This will cause the parent parser to return Help command
            failwith "HELP_REQUESTED"

    parseArgsRec (Array.toList args) { ConfigPath = None; Command = None }

/// Display configuration information
let showConfig (config: BackendConfig) =
    printfn "[INFO] LuaEnv Configuration Loaded Successfully"
    printfn ""
    printfn "Configuration Details:"
    printfn "  Backend Directory: %s" config.BackendDir
    printfn "  Project Root: %s" config.ProjectRoot
    printfn "  Config Version: %s" config.ConfigVersion
    printfn "  Created: %s" config.Created
    printfn ""
    printfn "Embedded Python:"
    printfn "  Python Directory: %s" config.EmbeddedPython.PythonDir
    printfn "  Python Executable: %s" config.EmbeddedPython.PythonExe
    printfn "  Available: %s" (if config.EmbeddedPython.Available then "Yes" else "No")

/// Execute a command with the loaded configuration
let executeCommand (config: BackendConfig) (command: Command) : int =
    match command with
    | Install options ->
        printfn "[INFO] Starting Lua installation..."
        match executeInstall config options with
        | Ok exitCode -> exitCode
        | Error errorMsg ->
            printfn "%s" errorMsg
            1

    | Uninstall options ->
        printfn "[INFO] Starting Lua uninstallation..."
        match executeUninstall config options with
        | Ok exitCode -> exitCode
        | Error errorMsg ->
            printfn "%s" errorMsg
            1

    | List options ->
        printfn "[INFO] Listing installed Lua environments..."
        match executeList config options with
        | Ok exitCode -> exitCode
        | Error errorMsg ->
            printfn "%s" errorMsg
            1

    | Status options ->
        printfn "[INFO] Checking system status..."
        match executeStatus config options with
        | Ok exitCode ->
            // Add educational epilog after successful status output
            printfn ""
            printfn "STATUS EXPLANATIONS:"
            printfn "  [ACTIVE]     Installation is working and available for use"
            printfn "  [BROKEN]     Installation has issues and may need repair"
            printfn "  [BUILDING]   Installation is currently being set up"
            printfn "  [INACTIVE]   Installation exists but is not currently usable (zombie)"
            printfn ""
            printfn "NOTE: The 'list' command shows [DEFAULT] instead of status for the default"
            printfn "      installation, while 'status' shows actual status for all installations."
            printfn ""
            printfn "USEFUL COMMANDS:"
            printfn "  luaenv list                    Show detailed installation information"
            printfn "  luaenv install                 Install a new Lua environment"
            printfn "  luaenv default <alias>         Set a different default installation"
            exitCode
        | Error errorMsg ->
            printfn "%s" errorMsg
            1

    | ShowConfig ->
        showConfig config
        0

    | Help ->
        showHelp ()
        0

    | Versions options ->
        match executeVersions config options with
        | Ok exitCode -> exitCode
        | Error errorMsg ->
            printfn "%s" errorMsg
            1

    | PkgConfig options ->
        match executePkgConfig config options.Installation options.ShowCFlag options.ShowLuaInclude options.ShowLibLua options.ShowPaths options.PathStyle with
        | Ok exitCode -> exitCode
        | Error errorMsg ->
            printfn "%s" errorMsg
            1

    | Environment ->
        printfn "[INFO] Environment management commands are implemented in the luaenv.ps1 PowerShell wrapper"
        printfn "       Please use the wrapper script for commands like 'luaenv activate'"
        0

    | SetAlias options ->
        // Validate arguments before calling the backend
        if String.IsNullOrWhiteSpace(options.IdOrAlias) then
            printfn "[ERROR] Installation ID or alias cannot be empty"
            1
        else
            printfn "[INFO] Updating installation alias..."
            match Backend.executeSetAlias config options with
            | Ok exitCode -> exitCode
            | Error errorMsg ->
                printfn "%s" errorMsg
                1

/// Main entry point
[<EntryPoint>]
let main args =
    try
        let cliArgs = parseArgs args

        match cliArgs.Command with
        | Some Help ->
            showHelp ()
            0
        | _ ->
            match cliArgs.ConfigPath with
            | None ->
                printfn "[ERROR] Missing required --config parameter"
                printfn ""
                showHelp ()
                1
            | Some configPath ->
                match loadConfig configPath with
                | Ok config ->
                    match cliArgs.Command with
                    | Some command -> executeCommand config command
                    | None ->
                        printfn "[ERROR] No command specified"
                        printfn ""
                        showHelp ()
                        1
                | Error errorMsg ->
                    printfn "%s" errorMsg
                    1
    with
    | ex ->
        printfn "[ERROR] Unexpected error: %s" ex.Message
        1