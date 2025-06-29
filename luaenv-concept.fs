// LuaEnv - F# Proof of Concept
// This shows what the F# CLI structure could look like

open System
open System.IO
open System.Diagnostics
open System.CommandLine
open System.CommandLine.Invocation
open System.Text.Json

// Configuration types
type BuildType = StaticRelease | StaticDebug | DllRelease | DllDebug
type LuaInstallation = {
    Version: string
    Path: string
    BuildType: BuildType
    LuaRocksVersion: string
    InstallDate: DateTime
}

type LuaEnvConfig = {
    GlobalVersion: string option
    Installations: Map<string, LuaInstallation>
    CachePath: string
    LastUpdate: DateTime
}

// Core functionality
module LuaEnv =
    let configPath = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.UserProfile), ".luaenv", "config.json")
    let versionsPath = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.UserProfile), ".luaenv", "versions")

    let loadConfig () =
        if File.Exists(configPath) then
            let json = File.ReadAllText(configPath)
            JsonSerializer.Deserialize<LuaEnvConfig>(json)
        else
            { GlobalVersion = None; Installations = Map.empty; CachePath = ""; LastUpdate = DateTime.Now }

    let saveConfig (config: LuaEnvConfig) =
        Directory.CreateDirectory(Path.GetDirectoryName(configPath)) |> ignore
        let json = JsonSerializer.Serialize(config, JsonSerializerOptions(WriteIndented = true))
        File.WriteAllText(configPath, json)

    let listInstalled () =
        let config = loadConfig()
        config.Installations |> Map.toSeq |> Seq.map fst |> Seq.toList

    let listAvailable () =
        // Call our existing Python script to get available versions
        let psi = ProcessStartInfo("python", "config.py --discover")
        psi.RedirectStandardOutput <- true
        psi.UseShellExecute <- false
        let proc = Process.Start(psi)
        proc.WaitForExit()
        proc.StandardOutput.ReadToEnd().Split('\n')
        |> Array.filter (fun line -> line.Contains("5.4."))
        |> Array.toList

    let install version buildType =
        printfn $"Installing Lua {version} ({buildType})..."

        // Build arguments for Python setup.py
        let args =
            match buildType with
            | StaticRelease -> "--skip-tests"
            | StaticDebug -> "--debug --skip-tests"
            | DllRelease -> "--dll --skip-tests"
            | DllDebug -> "--dll --debug --skip-tests"

        let installPath = Path.Combine(versionsPath, version)
        let pythonArgs = $"setup.py {args} --prefix {installPath}"

        // Execute the Python setup script
        let psi = ProcessStartInfo("python", pythonArgs)
        psi.UseShellExecute <- false
        let proc = Process.Start(psi)
        proc.WaitForExit()

        if proc.ExitCode = 0 then
            // Update configuration
            let config = loadConfig()
            let installation = {
                Version = version
                Path = installPath
                BuildType = buildType
                LuaRocksVersion = "3.12.2" // Could parse from setup output
                InstallDate = DateTime.Now
            }
            let newConfig = { config with Installations = config.Installations.Add(version, installation) }
            saveConfig newConfig
            printfn $"✅ Successfully installed Lua {version}"
        else
            printfn $"❌ Failed to install Lua {version}"

    let uninstall version =
        printfn $"Uninstalling Lua {version}..."
        let config = loadConfig()
        match config.Installations.TryFind(version) with
        | Some installation ->
            // Remove installation directory
            if Directory.Exists(installation.Path) then
                Directory.Delete(installation.Path, true)

            // Update config
            let newConfig = { config with Installations = config.Installations.Remove(version) }
            saveConfig newConfig
            printfn $"✅ Successfully uninstalled Lua {version}"
        | None ->
            printfn $"❌ Lua {version} is not installed"

    let setGlobal version =
        let config = loadConfig()
        if config.Installations.ContainsKey(version) then
            let newConfig = { config with GlobalVersion = Some version }
            saveConfig newConfig
            printfn $"✅ Set global Lua version to {version}"
        else
            printfn $"❌ Lua {version} is not installed"

// Command line interface
let main argv =
    let rootCommand = RootCommand("LuaEnv - Lua Version Manager")

    // luaenv versions
    let versionsCommand = Command("versions", "List Lua versions")
    let availableOption = Option<bool>("--available", "Show available versions for installation")
    versionsCommand.AddOption(availableOption)
    versionsCommand.SetHandler(fun (available: bool) ->
        if available then
            printfn "Available Lua versions:"
            LuaEnv.listAvailable() |> List.iter (printfn "  %s")
        else
            printfn "Installed Lua versions:"
            LuaEnv.listInstalled() |> List.iter (printfn "  %s")
    , availableOption)

    // luaenv install <version>
    let installCommand = Command("install", "Install a Lua version")
    let versionArgument = Argument<string>("version", "Lua version to install")
    let dllOption = Option<bool>("--dll", "Build as DLL")
    let debugOption = Option<bool>("--debug", "Build with debug symbols")
    installCommand.AddArgument(versionArgument)
    installCommand.AddOption(dllOption)
    installCommand.AddOption(debugOption)
    installCommand.SetHandler(fun (version: string) (dll: bool) (debug: bool) ->
        let buildType =
            match (dll, debug) with
            | (true, true) -> DllDebug
            | (true, false) -> DllRelease
            | (false, true) -> StaticDebug
            | (false, false) -> StaticRelease
        LuaEnv.install version buildType
    , versionArgument, dllOption, debugOption)

    // luaenv uninstall <version>
    let uninstallCommand = Command("uninstall", "Uninstall a Lua version")
    let uninstallVersionArg = Argument<string>("version", "Lua version to uninstall")
    uninstallCommand.AddArgument(uninstallVersionArg)
    uninstallCommand.SetHandler(fun (version: string) ->
        LuaEnv.uninstall version
    , uninstallVersionArg)

    // luaenv global <version>
    let globalCommand = Command("global", "Set global Lua version")
    let globalVersionArg = Argument<string>("version", "Lua version to set as global")
    globalCommand.AddArgument(globalVersionArg)
    globalCommand.SetHandler(fun (version: string) ->
        LuaEnv.setGlobal version
    , globalVersionArg)

    // Add commands to root
    rootCommand.AddCommand(versionsCommand)
    rootCommand.AddCommand(installCommand)
    rootCommand.AddCommand(uninstallCommand)
    rootCommand.AddCommand(globalCommand)

    // Execute
    rootCommand.Invoke(argv)

[<EntryPoint>]
let entryPoint argv = main argv
