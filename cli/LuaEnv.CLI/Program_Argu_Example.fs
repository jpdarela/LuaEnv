open System
open Argu
open LuaEnv.Core
open LuaEnv.Core.Config
open LuaEnv.Core.Backend

/// Install command arguments using Argu
type InstallArgs =
    | [<AltCommandLine("--lua-version")>] Lua_Version of version:string
    | [<AltCommandLine("--luarocks-version")>] LuaRocks_Version of version:string
    | [<AltCommandLine("--alias")>] Alias of alias:string
    | [<AltCommandLine("--name")>] Name of name:string
    | [<AltCommandLine("--dll")>] Dll
    | [<AltCommandLine("--debug")>] Debug
    | [<AltCommandLine("--skip-env-check")>] Skip_Env_Check
    | [<AltCommandLine("--skip-tests")>] Skip_Tests

    interface IArgParserTemplate with
        member s.Usage =
            match s with
            | Lua_Version _ -> "Use specific Lua version (e.g. 5.4.7, 5.3.6)"
            | LuaRocks_Version _ -> "Use specific LuaRocks version (e.g. 3.11.1)"
            | Alias _ -> "Set an alias for the installation"
            | Name _ -> "Set display name for the installation"
            | Dll -> "Build as DLL instead of static library"
            | Debug -> "Include debug symbols"
            | Skip_Env_Check -> "Skip Visual Studio environment check"
            | Skip_Tests -> "Skip test suite after building"

/// Uninstall command arguments using Argu
type UninstallArgs =
    | [<MainCommand; ExactlyOnce; First>] Id_Or_Alias of string
    | [<AltCommandLine("--force", "--yes")>] Force

    interface IArgParserTemplate with
        member s.Usage =
            match s with
            | Id_Or_Alias _ -> "Installation alias or UUID to remove"
            | Force -> "Skip confirmation prompt"

/// Top-level CLI commands using Argu
type CliArgs =
    | [<AltCommandLine("--config")>] Config_Path of path:string
    | [<CliPrefix(CliPrefix.None)>] Install of ParseResults<InstallArgs>
    | [<CliPrefix(CliPrefix.None)>] Uninstall of ParseResults<UninstallArgs>
    | [<CliPrefix(CliPrefix.None)>] Config
    | [<CliPrefix(CliPrefix.None)>] Help

    interface IArgParserTemplate with
        member s.Usage =
            match s with
            | Config_Path _ -> "Path to backend configuration file"
            | Install _ -> "Install a new Lua environment"
            | Uninstall _ -> "Remove a Lua installation"
            | Config -> "Show current configuration"
            | Help -> "Show this help message"

/// Convert Argu InstallArgs to InstallOptions
let convertInstallArgs (results: ParseResults<InstallArgs>) : InstallOptions =
    {
        LuaVersion = results.TryGetResult(Lua_Version)
        LuaRocksVersion = results.TryGetResult(LuaRocks_Version)
        Alias = results.TryGetResult(Alias)
        Name = results.TryGetResult(Name)
        UseDll = results.Contains(Dll)
        UseDebug = results.Contains(Debug)
        SkipEnvCheck = results.Contains(Skip_Env_Check)
        SkipTests = results.Contains(Skip_Tests)
    }

/// Convert Argu UninstallArgs to UninstallOptions
let convertUninstallArgs (results: ParseResults<UninstallArgs>) : UninstallOptions =
    {
        IdOrAlias = results.GetResult(Id_Or_Alias)
        Force = results.Contains(Force)
    }

/// Show configuration information
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
        // This would be handled by Argu's built-in help
        0

/// Main entry point using Argu
[<EntryPoint>]
let main args =
    try
        let parser = ArgumentParser.Create<CliArgs>(programName = "luaenv")

        try
            let results = parser.ParseCommandLine(inputs = args, raiseOnUsage = true)

            let configPath = results.TryGetResult(Config_Path)

            // Handle commands that don't require config
            if results.Contains(Help) then
                printfn "%s" (parser.PrintUsage())
                0
            else
                match configPath with
                | None ->
                    printfn "[ERROR] Missing required --config parameter"
                    printfn ""
                    printfn "%s" (parser.PrintUsage())
                    1
                | Some configPath ->
                    match loadConfig configPath with
                    | Ok config ->
                        let command =
                            if results.Contains(Config) then
                                Some ShowConfig
                            elif results.Contains(Install) then
                                let installResults = results.GetResult(Install)
                                Some (Install (convertInstallArgs installResults))
                            elif results.Contains(Uninstall) then
                                let uninstallResults = results.GetResult(Uninstall)
                                Some (Uninstall (convertUninstallArgs uninstallResults))
                            else
                                None

                        match command with
                        | Some cmd -> executeCommand config cmd
                        | None ->
                            printfn "[ERROR] No command specified"
                            printfn ""
                            printfn "%s" (parser.PrintUsage())
                            1
                    | Error errorMsg ->
                        printfn "%s" errorMsg
                        1
        with
        | :? ArguParseException as ex ->
            printfn "%s" ex.Message
            1
        | ex ->
            printfn "[ERROR] Unexpected error: %s" ex.Message
            1
    with
    | ex ->
        printfn "[ERROR] Fatal error: %s" ex.Message
        1
