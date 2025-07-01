namespace LuaEnv.Core

open System
open System.IO
open System.Text.Json

/// Represents embedded Python configuration
type EmbeddedPython = {
    PythonDir: string
    PythonExe: string
    Available: bool
}

/// Represents the backend configuration loaded from JSON
type BackendConfig = {
    BackendDir: string
    EmbeddedPython: EmbeddedPython
    ProjectRoot: string
    ConfigVersion: string
    Created: string
}

/// Configuration module for reading and parsing backend.config
module Config =

    /// Parse backend.config JSON file
    let parseConfig (configPath: string) : Result<BackendConfig, string> =
        try
            if not (File.Exists configPath) then
                Error $"[ERROR] Config file not found: {configPath}"
            else
                let json = File.ReadAllText configPath
                let options = JsonSerializerOptions()
                options.PropertyNameCaseInsensitive <- true
                options.PropertyNamingPolicy <- JsonNamingPolicy.SnakeCaseLower

                let config = JsonSerializer.Deserialize<BackendConfig>(json, options)
                Ok config
        with
        | ex -> Error $"[ERROR] Failed to parse config file: {ex.Message}"

    /// Validate that required paths exist
    let validateConfig (config: BackendConfig) : Result<BackendConfig, string> =
        let errors = ResizeArray<string>()

        if not (Directory.Exists config.BackendDir) then
            errors.Add $"Backend directory not found: {config.BackendDir}"

        if not (Directory.Exists config.ProjectRoot) then
            errors.Add $"Project root not found: {config.ProjectRoot}"

        if config.EmbeddedPython.Available && not (File.Exists config.EmbeddedPython.PythonExe) then
            errors.Add $"Embedded Python executable not found: {config.EmbeddedPython.PythonExe}"

        if errors.Count > 0 then
            Error (String.Join("\n", errors))
        else
            Ok config

    /// Load and validate configuration from file
    let loadConfig (configPath: string) : Result<BackendConfig, string> =
        parseConfig configPath
        |> Result.bind validateConfig

/// Install command options
type InstallOptions = {
    LuaVersion: string option
    LuaRocksVersion: string option
    Alias: string option
    Name: string option
    UseDll: bool
    UseDebug: bool
    SkipEnvCheck: bool
    SkipTests: bool
}

/// Uninstall command options
type UninstallOptions = {
    IdOrAlias: string
    Force: bool
}

/// CLI Commands
type Command =
    | Install of InstallOptions
    | Uninstall of UninstallOptions
    | ShowConfig
    | Help

/// Backend execution module
module Backend =
    open System.Diagnostics

    /// Execute a Python script in the backend directory
    let executePython (config: BackendConfig) (scriptName: string) (args: string list) : Result<int, string> =
        try
            let pythonExe =
                if config.EmbeddedPython.Available then
                    config.EmbeddedPython.PythonExe
                else
                    "python"  // Fallback to system Python

            let scriptPath = Path.Combine(config.BackendDir, scriptName)
            if not (File.Exists scriptPath) then
                Error $"[ERROR] Backend script not found: {scriptPath}"
            else
                // Use relative script name and set working directory to backend folder
                let arguments = String.Join(" ", scriptName :: args)

                let startInfo = ProcessStartInfo()
                startInfo.FileName <- pythonExe
                startInfo.Arguments <- arguments
                startInfo.WorkingDirectory <- config.BackendDir
                startInfo.UseShellExecute <- false
                // Let scripts print directly to console - no I/O redirection

                use proc = Process.Start(startInfo)
                proc.WaitForExit()

                Ok proc.ExitCode
        with
        | ex -> Error $"[ERROR] Failed to execute backend script: {ex.Message}"

    /// Execute install command via setup_lua.py
    let executeInstall (config: BackendConfig) (options: InstallOptions) : Result<int, string> =
        let args = ResizeArray<string>()

        // Add version options
        match options.LuaVersion with
        | Some version -> args.Add("--lua-version"); args.Add(version)
        | None -> ()

        match options.LuaRocksVersion with
        | Some version -> args.Add("--luarocks-version"); args.Add(version)
        | None -> ()

        // Add build options
        if options.UseDll then args.Add("--dll")
        if options.UseDebug then args.Add("--debug")
        if options.SkipEnvCheck then args.Add("--skip-env-check")
        if options.SkipTests then args.Add("--skip-tests")

        // Add metadata options
        match options.Name with
        | Some name -> args.Add("--name"); args.Add($"\"{name}\"")
        | None -> ()

        match options.Alias with
        | Some alias -> args.Add("--alias"); args.Add(alias)
        | None -> ()

        executePython config "setup_lua.py" (List.ofSeq args)

    /// Execute uninstall command via registry.py
    let executeUninstall (config: BackendConfig) (options: UninstallOptions) : Result<int, string> =
        let args = ["remove"; options.IdOrAlias]
        let finalArgs = if options.Force then args @ ["--yes"] else args

        executePython config "registry.py" finalArgs