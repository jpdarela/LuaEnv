namespace LuaEnv.Core

open System
open System.IO
open System.Diagnostics
open System.Text.Json
open System.Text.Json.Serialization

// Configuration types
type BuildType =
    | StaticRelease
    | StaticDebug
    | DllRelease
    | DllDebug
    override this.ToString() =
        match this with
        | StaticRelease -> "Static Release"
        | StaticDebug -> "Static Debug"
        | DllRelease -> "DLL Release"
        | DllDebug -> "DLL Debug"

// Custom JSON converter for BuildType discriminated union
type BuildTypeConverter() =
    inherit JsonConverter<BuildType>()

    override _.Read(reader: byref<Utf8JsonReader>, typeToConvert: Type, options: JsonSerializerOptions) =
        let value = reader.GetString()
        match value with
        | "StaticRelease" -> StaticRelease
        | "StaticDebug" -> StaticDebug
        | "DllRelease" -> DllRelease
        | "DllDebug" -> DllDebug
        | _ -> StaticRelease // default fallback

    override _.Write(writer: Utf8JsonWriter, value: BuildType, options: JsonSerializerOptions) =
        let stringValue =
            match value with
            | StaticRelease -> "StaticRelease"
            | StaticDebug -> "StaticDebug"
            | DllRelease -> "DllRelease"
            | DllDebug -> "DllDebug"
        writer.WriteStringValue(stringValue)

type LuaInstallation = {
    Version: string
    Path: string
    BuildType: BuildType
    LuaRocksVersion: string
    InstallDate: DateTime
    Alias: string
}

type LuaEnvConfig = {
    GlobalVersion: string option
    Installations: Map<string, LuaInstallation>
    CachePath: string
    LastUpdate: DateTime
}

module Configuration =
    let private configPath = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.UserProfile), ".luaenv", "config.json")
    let private versionsPath = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.UserProfile), ".luaenv", "versions")

    let getConfigPath () = configPath
    let getVersionsPath () = versionsPath

    let loadConfig () =
        if File.Exists(configPath) then
            try
                let json = File.ReadAllText(configPath)
                let options = JsonSerializerOptions()
                options.Converters.Add(BuildTypeConverter())
                JsonSerializer.Deserialize<LuaEnvConfig>(json, options)
            with
            | ex ->
                printfn $"Warning: Failed to load config: {ex.Message}"
                { GlobalVersion = None; Installations = Map.empty; CachePath = ""; LastUpdate = DateTime.Now }
        else
            { GlobalVersion = None; Installations = Map.empty; CachePath = ""; LastUpdate = DateTime.Now }

    let saveConfig (config: LuaEnvConfig) =
        Directory.CreateDirectory(Path.GetDirectoryName(configPath)) |> ignore
        let options = JsonSerializerOptions(WriteIndented = true)
        options.Converters.Add(BuildTypeConverter())
        let json = JsonSerializer.Serialize(config, options)
        File.WriteAllText(configPath, json)

module PythonScripts =
    // Find Python scripts in backend folder
    let scriptBasePath =
        let assemblyLocation = System.Reflection.Assembly.GetExecutingAssembly().Location
        let currentDir = Path.GetDirectoryName(assemblyLocation)

        // Helper to go up directory levels safely
        let rec goUpLevels (dir: string) (levels: int) =
            if levels <= 0 then Some dir
            else
                try
                    let parent = Directory.GetParent(dir)
                    if parent = null then None
                    else goUpLevels parent.FullName (levels - 1)
                with
                | _ -> None

        // Check multiple levels up for backend folder
        let searchPaths =
            [0..6] // Check current and up to 6 levels up
            |> List.choose (fun level ->
                goUpLevels currentDir level
                |> Option.map (fun dir -> Path.Combine(dir, "backend")))

        // Find first path containing config.py
        searchPaths
        |> List.tryFind (fun path ->
            File.Exists(Path.Combine(path, "config.py")))

    let runPythonScript scriptName args =
        match scriptBasePath with
        | Some basePath ->
            let fullScriptPath = Path.Combine(basePath, scriptName)
            if not (File.Exists(fullScriptPath)) then
                Error $"Python script not found: {fullScriptPath}"
            else
                try
                    let psi = ProcessStartInfo("python", $"\"{fullScriptPath}\" {args}")
                    psi.RedirectStandardOutput <- true
                    psi.RedirectStandardError <- true
                    psi.UseShellExecute <- false
                    psi.WorkingDirectory <- basePath
                    psi.CreateNoWindow <- true

                    printfn $"Starting: python {scriptName} {args}"
                    let proc = Process.Start(psi)

                    // Set a timeout of 10 minutes for installation
                    let timeoutMs = 10 * 60 * 1000
                    let completed = proc.WaitForExit(timeoutMs)

                    if not completed then
                        proc.Kill()
                        Error "Installation timed out after 10 minutes"
                    else
                        let output = proc.StandardOutput.ReadToEnd()
                        let error = proc.StandardError.ReadToEnd()

                        // Print output immediately for user feedback
                        if not (String.IsNullOrEmpty(output)) then
                            printfn "Output:"
                            printfn "%s" output
                        if not (String.IsNullOrEmpty(error)) then
                            printfn "Error output:"
                            printfn "%s" error

                        Ok (proc.ExitCode, output, error)
                with
                | ex -> Error $"Failed to run Python script: {ex.Message}"
        | None ->
            Error "Could not find Python scripts directory"

module VersionManager =
    open PythonScripts

    let listInstalled () =
        let config = Configuration.loadConfig()
        config.Installations
        |> Map.toList
        |> List.map (fun (alias, installation) ->
            $"{alias} ({installation.Version}, {installation.BuildType})")

    let listAvailable () =
        match runPythonScript "config.py" "--discover" with
        | Ok (0, output, _) ->
            output.Split('\n')
            |> Array.map (fun line -> line.Trim())
            |> Array.filter (fun line -> line.StartsWith("  - "))
            |> Array.map (fun line -> line.Substring(4).Split(' ').[0])
            |> Array.filter (fun version -> version.Contains("."))
            |> Array.toList
        | Ok (_, _, error) ->
            printfn $"Error: {error}"
            []
        | Error msg ->
            printfn $"Error: {msg}"
            []

    let listAvailableLuaRocks () =
        match runPythonScript "config.py" "--discover" with
        | Ok (0, output, _) ->
            output.Split('\n')
            |> Array.map (fun line -> line.Trim())
            |> Array.filter (fun line -> line.Contains("LuaRocks") && line.StartsWith("  - "))
            |> Array.map (fun line -> line.Substring(4).Split(' ').[0])
            |> Array.toList
        | _ -> []

    let installWithLuaRocks luaVersion luaRocksVersion buildType aliasOpt dryRun =
        match aliasOpt with
        | Some alias ->
            let config = Configuration.loadConfig()
            let installPath = Path.Combine(Configuration.getVersionsPath(), alias)

            if config.Installations.ContainsKey(alias) then
                printfn $"❌ Installation with alias '{alias}' already exists"
                false
            else
                let finalLuaVersion = if String.IsNullOrEmpty(luaVersion) then "5.4.8" else luaVersion
                let finalLuaRocksVersion = luaRocksVersion |> Option.defaultValue "3.12.2"

                printfn $"Installing Lua {finalLuaVersion} with LuaRocks {finalLuaRocksVersion} ({buildType}) as '{alias}'..."

                if dryRun then
                    printfn "[INFO] DRY RUN - Would perform the following actions:"
                    printfn $"  - Lua version: {finalLuaVersion}"
                    printfn $"  - LuaRocks version: {finalLuaRocksVersion}"
                    printfn $"  - Build type: {buildType}"
                    printfn $"  - Alias: {alias}"
                    printfn $"  - Installation path: {installPath}"
                    printfn "  - Would create temporary build_config.txt"
                    printfn "  - Would run Python setup_lua.py with use_lua.ps1 integration"
                    printfn "  - Would setup self-contained LuaRocks configuration"
                    printfn "[SUCCESS] Dry run completed successfully"
                    true
                else
                    try
                        // Create temporary build_config.txt with the desired versions
                        match scriptBasePath with
                        | Some basePath ->
                            let buildConfigPath = Path.Combine(basePath, "build_config.txt")
                            let majorMinor = finalLuaVersion.Split('.')[0..1] |> String.concat "."
                            let currentTime = DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss")

                            let configContent = $"""# Temporary build configuration for LuaEnv F#
# Generated on {currentTime}
LUA_VERSION={finalLuaVersion}
LUA_MAJOR_MINOR={majorMinor}
LUAROCKS_VERSION={finalLuaRocksVersion}
LUAROCKS_PLATFORM=windows-64
"""
                            File.WriteAllText(buildConfigPath, configContent)
                            printfn $"✅ Created build configuration for Lua {finalLuaVersion} + LuaRocks {finalLuaRocksVersion}"

                            // Determine build arguments for setup_lua.py
                            let mutable buildArgsList = [
                                "--prefix"; $"\"{installPath}\""
                            ]

                            if buildType = DllRelease || buildType = DllDebug then
                                buildArgsList <- buildArgsList @ ["--dll"]
                            if buildType = StaticDebug || buildType = DllDebug then
                                buildArgsList <- buildArgsList @ ["--debug"]

                            let buildArgs = buildArgsList |> String.concat " "

                            printfn $"Running Lua installation: python setup_lua.py {buildArgs}"
                            printfn "This will:"
                            printfn "  1. Set up Visual Studio environment"
                            printfn "  2. Download Lua and LuaRocks sources"
                            printfn "  3. Build and install to the specified directory"
                            printfn "  4. Run basic functionality tests"
                            printfn ""
                            printfn "⏳ Installation in progress... (this may take several minutes)"
                            printfn "💡 You can press Ctrl+C to cancel if needed"
                            printfn ""

                            // Call setup_lua.py directly - it handles environment setup internally
                            match runPythonScript "setup_lua.py" buildArgs with
                            | Ok (0, output, _) ->
                                printfn "✅ Lua installation completed successfully"

                                // Create installation record and save to config
                                let installation = {
                                    Version = finalLuaVersion
                                    Path = installPath
                                    BuildType = buildType
                                    LuaRocksVersion = finalLuaRocksVersion
                                    InstallDate = DateTime.Now
                                    Alias = alias
                                }

                                let newConfig = {
                                    config with
                                        Installations = config.Installations.Add(alias, installation)
                                }
                                Configuration.saveConfig newConfig
                                printfn $"✅ Installation '{alias}' registered successfully"
                                true

                            | Ok (exitCode, output, error) ->
                                printfn $"❌ Installation failed with exit code {exitCode}"
                                if not (String.IsNullOrEmpty(output)) then
                                    printfn "Output:"
                                    printfn $"{output}"
                                if not (String.IsNullOrEmpty(error)) then
                                    printfn "Error:"
                                    printfn $"{error}"
                                false

                            | Error msg ->
                                printfn $"❌ Failed to run installation: {msg}"
                                false
                        | None ->
                            printfn "❌ Could not find Python scripts directory"
                            false
                    with
                    | ex ->
                        printfn $"❌ Installation failed: {ex.Message}"
                        false
        | None ->
            printfn "❌ Alias is required for installation"
            false

    let uninstall alias =
        let config = Configuration.loadConfig()
        match config.Installations.TryFind(alias) with
        | Some installation ->
            printfn $"Uninstalling Lua installation '{alias}'..."

            // Remove installation directory
            if Directory.Exists(installation.Path) then
                try
                    Directory.Delete(installation.Path, true)
                    printfn $"✅ Removed installation directory: {installation.Path}"
                with
                | ex -> printfn $"⚠️  Could not remove directory: {ex.Message}"

            // Update config
            let newConfig = { config with Installations = config.Installations.Remove(alias) }
            Configuration.saveConfig newConfig
            printfn $"✅ Successfully uninstalled '{alias}'"
            true
        | None ->
            printfn $"❌ Installation '{alias}' not found"
            false

    let activate alias =
        let config = Configuration.loadConfig()
        if config.Installations.ContainsKey(alias) then
            let localVersionFile = Path.Combine(Environment.CurrentDirectory, ".lua-version")
            File.WriteAllText(localVersionFile, alias)
            printfn $"✅ Activated Lua version '{alias}' for current directory"
            printfn ""

            let installation = config.Installations.[alias]
            let binPath = Path.Combine(installation.Path, "bin")
            let luaSharePath = Path.Combine(installation.Path, "share", "lua", "5.4", "?.lua")
            let luaShareInitPath = Path.Combine(installation.Path, "share", "lua", "5.4", "?", "init.lua")
            let luaCPath = Path.Combine(installation.Path, "lib", "lua", "5.4", "?.dll")

            // Create a PowerShell script file for easy sourcing
            let scriptContent = $"""# LuaEnv activation script for {alias}
$env:PATH = "{binPath};" + $env:PATH
$env:LUA_PATH = "{luaSharePath};{luaShareInitPath};" + $env:LUA_PATH
$env:LUA_CPATH = "{luaCPath};" + $env:LUA_CPATH

Write-Host "Lua {installation.Version} ({installation.BuildType}) is now available:"
Write-Host "  lua -v"
Write-Host "  luac -v"
"""
            let scriptPath = Path.Combine(Environment.CurrentDirectory, $"activate-{alias}.ps1")
            File.WriteAllText(scriptPath, scriptContent)

            printfn "To use this Lua version immediately, run:"
            printfn $"  . .\\activate-{alias}.ps1"
            printfn ""
            printfn "Or set up the environment manually:"
            printfn ""
            printfn "PowerShell:"
            printfn "  $env:PATH = \"%s;\" + $env:PATH" binPath
            printfn "  $env:LUA_PATH = \"%s;%s;\" + $env:LUA_PATH" luaSharePath luaShareInitPath
            printfn "  $env:LUA_CPATH = \"%s;\" + $env:LUA_CPATH" luaCPath
            printfn ""
            printfn "Command Prompt:"
            printfn "  set PATH=%s;%%PATH%%" binPath
            printfn "  set LUA_PATH=%s;%s;%%LUA_PATH%%" luaSharePath luaShareInitPath
            printfn "  set LUA_CPATH=%s;%%LUA_CPATH%%" luaCPath
            printfn ""
            printfn "Or run 'luaenv use' anytime to see these commands again."
            true
        else
            printfn $"❌ Installation '{alias}' not found"
            false

    let getCurrentVersion () =
        // Check for local .lua-version file
        let localVersionFile = Path.Combine(Environment.CurrentDirectory, ".lua-version")
        if File.Exists(localVersionFile) then
            let localAlias = File.ReadAllText(localVersionFile).Trim()
            let config = Configuration.loadConfig()
            match config.Installations.TryFind(localAlias) with
            | Some installation -> Some (localAlias, installation)
            | None -> None
        else
            None

    let showConfig () =
        let config = Configuration.loadConfig()
        printfn "LuaEnv Configuration (Windows):"
        printfn $"  Config path: {Configuration.getConfigPath()}"
        printfn $"  Versions path: {Configuration.getVersionsPath()}"

        match scriptBasePath with
        | Some path -> printfn $"  Python scripts found at: {path}"
        | None -> printfn "  [WARNING]  Python scripts not found!"

        printfn $"  Installed versions: {config.Installations.Count}"

        config.Installations |> Map.iter (fun alias installation ->
            printfn $"    {alias} ({installation.BuildType}) - {installation.Path}")

    let validateConfig () =
        match runPythonScript "config.py" "--check" with
        | Ok (0, _, _) -> true
        | _ -> false

    let cleanCache () =
        match runPythonScript "clean.py" "" with
        | Ok (0, _, _) ->
            printfn "✅ Cache cleaned successfully"
            true
        | _ ->
            printfn "❌ Failed to clean cache"
            false

    let showCurrentLua () =
        match getCurrentVersion() with
        | Some (alias, installation) ->
            printfn $"Current Lua version: {alias} ({installation.Version}, {installation.BuildType})"
            printfn $"Path: {installation.Path}"
        | None ->
            printfn "No Lua version is currently active"
            printfn "Use 'luaenv activate <alias>' to activate a version for this directory"

    let showEnvironmentCommands () =
        match getCurrentVersion() with
        | Some (alias, installation) ->
            let binPath = Path.Combine(installation.Path, "bin")
            let luaSharePath = Path.Combine(installation.Path, "share", "lua", "5.4", "?.lua")
            let luaShareInitPath = Path.Combine(installation.Path, "share", "lua", "5.4", "?", "init.lua")
            let luaCPath = Path.Combine(installation.Path, "lib", "lua", "5.4", "?.dll")

            printfn $"Environment setup for {alias} ({installation.Version}, {installation.BuildType}):"
            printfn ""
            printfn "PowerShell:"
            printfn $"  $env:PATH = \"{binPath};$env:PATH\""
            printfn $"  $env:LUA_PATH = \"{luaSharePath};{luaShareInitPath};$env:LUA_PATH\""
            printfn $"  $env:LUA_CPATH = \"{luaCPath};$env:LUA_CPATH\""
            printfn ""
            printfn "Command Prompt:"
            printfn "  set PATH=%s;%%PATH%%" binPath
            printfn "  set LUA_PATH=%s;%s;%%LUA_PATH%%" luaSharePath luaShareInitPath
            printfn "  set LUA_CPATH=%s;%%LUA_CPATH%%" luaCPath
        | None ->
            printfn "No Lua version is currently active"
            printfn "Use 'luaenv activate <alias>' to activate a version for this directory"