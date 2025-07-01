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
    printfn "    config                         Show current configuration"
    printfn "    help                           Show this help message"
    printfn ""
    printfn "For command-specific help, use:"
    printfn "    luaenv install --help"
    printfn "    luaenv uninstall --help"
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
    printfn "    --skip-env-check               Skip Visual Studio environment check"
    printfn "    --skip-tests                   Skip test suite after building"
    printfn "    --help, -h                     Show this help message"
    printfn ""
    printfn "EXAMPLES:"
    printfn "    luaenv install"
    printfn "    luaenv install --alias dev --dll"
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
        | "config" :: rest ->
            parseArgsRec rest { acc with Command = Some ShowConfig }
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
                parseInstallRec rest { acc with LuaVersion = Some version }
            | "--luarocks-version" :: version :: rest ->
                parseInstallRec rest { acc with LuaRocksVersion = Some version }
            | "--alias" :: alias :: rest ->
                parseInstallRec rest { acc with Alias = Some alias }
            | "--name" :: name :: rest ->
                parseInstallRec rest { acc with Name = Some name }
            | "--dll" :: rest ->
                parseInstallRec rest { acc with UseDll = true }
            | "--debug" :: rest ->
                parseInstallRec rest { acc with UseDebug = true }
            | "--skip-env-check" :: rest ->
                parseInstallRec rest { acc with SkipEnvCheck = true }
            | "--skip-tests" :: rest ->
                parseInstallRec rest { acc with SkipTests = true }
            | arg :: rest ->
                printfn "[ERROR] Unknown install option: %s" arg
                printfn "Use 'luaenv install --help' for available options"
                exit 1

        try
            parseInstallRec args {
                LuaVersion = None
                LuaRocksVersion = None
                Alias = None
                Name = None
                UseDll = false
                UseDebug = false
                SkipEnvCheck = false
                SkipTests = false
            }
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

    | ShowConfig ->
        showConfig config
        0

    | Help ->
        showHelp ()
        0

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