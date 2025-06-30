open System
open LuaEnv.Core

// Simple argument parsing without System.CommandLine for now
let main argv =
    printfn "LuaEnv - Lua Version Manager"
    printfn ""

    match Array.toList argv with
    | [] ->
        printfn "Usage: luaenv <command> [options]"
        printfn ""
        printfn "Commands:"
        printfn "  versions              List installed Lua versions"
        printfn "  versions -l, --list   List available versions for installation"
        printfn "  luarocks              List available LuaRocks versions"
        printfn "  install <alias> [lua_version] [--luarocks <version>] [--dll] [--debug] [--dry-run]"
        printfn "                        Install Lua with LuaRocks (alias is mandatory, lua_version is optional)"
        printfn "  uninstall <alias>     Uninstall a Lua installation by alias"
        printfn "  activate <alias>      Activate a Lua version for the current directory"
        printfn "  which                 Show path to current Lua executable"
        printfn "  use                   Show commands to set up environment for current version"
        printfn "  config                Show configuration"
        printfn "  config --validate     Validate configuration"
        printfn "  clean                 Clean download cache"
        0

    | "versions" :: rest ->
        match rest with
        | ["-l"] | ["--list"] ->
            printfn "Available Lua versions:"
            VersionManager.listAvailable() |> List.iter (printfn "  %s")
        | [] ->
            printfn "Installed Lua versions:"
            let installed = VersionManager.listInstalled()
            if installed.IsEmpty then
                printfn "  No Lua versions installed"
            else
                installed |> List.iter (printfn "  %s")
        | _ ->
            printfn "Usage: luaenv versions [-l | --list]"
        0

    | "luarocks" :: [] ->
        printfn "Available LuaRocks versions:"
        VersionManager.listAvailableLuaRocks() |> List.iter (printfn "  %s")
        0

    | "install" :: args ->
        // Check for help first
        if args |> List.contains "--help" || args |> List.contains "-h" then
            printfn "Usage: luaenv install <alias> [lua_version] [--luarocks luarocks_version] [--dll] [--debug] [--dry-run]"
            printfn ""
            printfn "Arguments:"
            printfn "  alias                 MANDATORY: Alias name for this installation (e.g., 'dev', 'prod', 'lua54')"
            printfn "  lua_version           Specific Lua version to install (e.g., 5.4.8)"
            printfn "                        If not specified, installs the latest available version"
            printfn ""
            printfn "Options:"
            printfn "  --luarocks VERSION    Specific LuaRocks version to install (e.g., 3.12.2)"
            printfn "                        If not specified, installs the latest available version"
            printfn "  --dll                 Build as DLL instead of static library"
            printfn "  --debug               Build debug version instead of release"
            printfn "  --dry-run             Show what would be installed without actually doing it"
            printfn ""
            printfn "Examples:"
            printfn "  luaenv install dev --dry-run                    # Show what would be installed (latest versions)"
            printfn "  luaenv install current                          # Install latest Lua + latest LuaRocks as 'current'"
            printfn "  luaenv install dev 5.4.7                       # Install Lua 5.4.7 + latest LuaRocks as 'dev'"
            printfn "  luaenv install prod --luarocks 3.11.0          # Install latest Lua + LuaRocks 3.11.0 as 'prod'"
            printfn "  luaenv install debug-build --dll --debug       # Install DLL debug build as 'debug-build'"
            0
        else
            // Parse install arguments: <alias> [lua_version] [--luarocks luarocks_version] [--dll] [--debug] [--dry-run]
            match args with
            | [] ->
                printfn "[ERROR] Alias is required for install command"
                printfn "Usage: luaenv install <alias> [lua_version] [options]"
                printfn "Run 'luaenv install --help' for more details"
                1
            | alias :: rest ->
                let rec parseInstallArgs args luaVersion luaRocksVersion dll debug dryRun =
                    match args with
                    | [] -> (luaVersion, luaRocksVersion, dll, debug, dryRun)
                    | "--dll" :: rest -> parseInstallArgs rest luaVersion luaRocksVersion true debug dryRun
                    | "--debug" :: rest -> parseInstallArgs rest luaVersion luaRocksVersion dll true dryRun
                    | "--dry-run" :: rest -> parseInstallArgs rest luaVersion luaRocksVersion dll debug true
                    | "--luarocks" :: version :: rest -> parseInstallArgs rest luaVersion (Some version) dll debug dryRun
                    | version :: rest when String.IsNullOrEmpty(luaVersion) && not (version.StartsWith("--")) ->
                        parseInstallArgs rest version luaRocksVersion dll debug dryRun
                    | unknown :: rest ->
                        printfn $"Unknown install option: {unknown}"
                        parseInstallArgs rest luaVersion luaRocksVersion dll debug dryRun

                let (luaVersion, luaRocksVersion, dll, debug, dryRun) = parseInstallArgs rest "" None false false false

                let buildType =
                    match (dll, debug) with
                    | (true, true) -> DllDebug
                    | (true, false) -> DllRelease
                    | (false, true) -> StaticDebug
                    | (false, false) -> StaticRelease

                // Use the new integrated installation function with mandatory alias
                if VersionManager.installWithLuaRocks luaVersion luaRocksVersion buildType (Some alias) dryRun then 0 else 1

    | "uninstall" :: [alias] ->
        if VersionManager.uninstall alias then 0 else 1

    | "uninstall" :: [] ->
        printfn "[ERROR] Alias is required for uninstall command"
        printfn "Usage: luaenv uninstall <alias>"
        printfn "Run 'luaenv versions' to see installed versions"
        1

    | "uninstall" :: _ ->
        printfn "[ERROR] Only one alias can be uninstalled at a time"
        printfn "Usage: luaenv uninstall <alias>"
        1

    | "activate" :: [alias] ->
        if VersionManager.activate alias then 0 else 1

    | "activate" :: [] ->
        printfn "[ERROR] Alias is required for activate command"
        printfn "Usage: luaenv activate <alias>"
        printfn "Run 'luaenv versions' to see available installations"
        1

    | "activate" :: _ ->
        printfn "[ERROR] Only one alias can be activated at a time"
        printfn "Usage: luaenv activate <alias>"
        1

    | "which" :: [] ->
        VersionManager.showCurrentLua()
        0

    | "use" :: [] ->
        VersionManager.showEnvironmentCommands()
        0

    | "config" :: rest ->
        match rest with
        | ["--validate"] ->
            if VersionManager.validateConfig() then
                printfn "[SUCCESS] Configuration is valid"
                0
            else
                printfn "[ERROR] Configuration validation failed"
                1
        | [] ->
            VersionManager.showConfig()
            0
        | _ ->
            printfn "Usage: luaenv config [--validate]"
            1

    | "clean" :: [] ->
        if VersionManager.cleanCache() then 0 else 1

    | command :: _ ->
        printfn $"Unknown command: {command}"
        printfn "Run 'luaenv' without arguments to see usage."
        1

[<EntryPoint>]
let entryPoint argv = main argv
