// This is free and unencumbered software released into the public domain.
// For more details, see the LICENSE file in the project root.

namespace LuaEnv.Core

open System
open System.IO
open System.Text.Json
open System.Text.Json.Serialization
open System.Diagnostics

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

/// Represents cache information from backend
type CacheInfo = {
    [<JsonPropertyName("used_cache")>]
    UsedCache: bool
    [<JsonPropertyName("cache_age_hours")>]
    CacheAgeHours: float option
    [<JsonPropertyName("cache_file")>]
    CacheFile: string option
    [<JsonPropertyName("forced_refresh")>]
    ForcedRefresh: bool option
}

/// Represents current configuration from backend
type CurrentConfig = {
    [<JsonPropertyName("lua_version")>]
    LuaVersion: string
    [<JsonPropertyName("lua_major_minor")>]
    LuaMajorMinor: string
    [<JsonPropertyName("luarocks_version")>]
    LuaRocksVersion: string
    [<JsonPropertyName("luarocks_platform")>]
    LuaRocksPlatform: string
}

/// Represents available versions from backend
type AvailableVersions = {
    [<JsonPropertyName("lua")>]
    Lua: string array
    [<JsonPropertyName("luarocks")>]
    LuaRocks: Map<string, string array>
}

/// Represents URLs from backend
type BackendUrls = {
    [<JsonPropertyName("lua")>]
    Lua: string
    [<JsonPropertyName("lua_tests")>]
    LuaTests: string
    [<JsonPropertyName("luarocks")>]
    LuaRocks: string
}

/// Represents config information from backend
type ConfigInfo = {
    [<JsonPropertyName("config_file")>]
    ConfigFile: string
    [<JsonPropertyName("backend_dir")>]
    BackendDir: string
}

/// Represents the full backend discovery response
type BackendDiscoveryResponse = {
    [<JsonPropertyName("current_config")>]
    CurrentConfig: CurrentConfig
    [<JsonPropertyName("cache_info")>]
    CacheInfo: CacheInfo
    [<JsonPropertyName("available_versions")>]
    AvailableVersions: AvailableVersions
    [<JsonPropertyName("discovery_timestamp")>]
    DiscoveryTimestamp: string
    [<JsonPropertyName("urls")>]
    Urls: BackendUrls
    [<JsonPropertyName("config_info")>]
    ConfigInfo: ConfigInfo
}

/// Configuration module for reading and parsing backend.config
module Config =

    /// Parse backend.config JSON file
    let parseConfig (configPath: string) : Result<BackendConfig, string> =
        try
            if not (File.Exists configPath) then
                Error (sprintf "[ERROR] Config file not found: %s" configPath)
            else
                let json = File.ReadAllText configPath
                let options = JsonSerializerOptions()
                options.PropertyNameCaseInsensitive <- true
                options.PropertyNamingPolicy <- JsonNamingPolicy.SnakeCaseLower

                let config = JsonSerializer.Deserialize<BackendConfig>(json, options)
                Ok config
        with
        | ex -> Error (sprintf "[ERROR] Failed to parse config file: %s" ex.Message)

    /// Validate that required paths exist
    let validateConfig (config: BackendConfig) : Result<BackendConfig, string> =
        let errors = ResizeArray<string>()

        if not (Directory.Exists config.BackendDir) then
            errors.Add (sprintf "Backend directory not found: %s" config.BackendDir)

        if not (Directory.Exists config.ProjectRoot) then
            errors.Add (sprintf "Project root not found: %s" config.ProjectRoot)

        if config.EmbeddedPython.Available && not (File.Exists config.EmbeddedPython.PythonExe) then
            errors.Add (sprintf "Embedded Python executable not found: %s" config.EmbeddedPython.PythonExe)

        if errors.Count > 0 then
            Error (String.Join("\n", errors))
        else
            Ok config

    /// Load and validate configuration from file
    let loadConfig (configPath: string) : Result<BackendConfig, string> =
        parseConfig configPath
        |> Result.bind validateConfig

    /// Call backend to discover available versions
    let discoverVersions (config: BackendConfig) (refresh: bool) : Result<BackendDiscoveryResponse, string> =
        try
            let pythonExe = config.EmbeddedPython.PythonExe
            let configScript = Path.Combine(config.BackendDir, "config.py")

            let args =
                if refresh then
                    "--discover --json --refresh"
                else
                    "--discover --json"

            let startInfo = ProcessStartInfo()
            startInfo.FileName <- pythonExe
            startInfo.Arguments <- sprintf "\"%s\" %s" configScript args
            startInfo.WorkingDirectory <- config.BackendDir
            startInfo.RedirectStandardOutput <- true
            startInfo.RedirectStandardError <- true
            startInfo.UseShellExecute <- false
            startInfo.CreateNoWindow <- true

            // Explicitly copy current environment to ensure VS variables are passed
            startInfo.EnvironmentVariables.Clear()
            for envVar in System.Environment.GetEnvironmentVariables() do
                let entry = envVar :?> System.Collections.DictionaryEntry
                startInfo.EnvironmentVariables.[entry.Key.ToString()] <- entry.Value.ToString()

            use proc = Process.Start(startInfo)
            let output = proc.StandardOutput.ReadToEnd()
            let error = proc.StandardError.ReadToEnd()
            proc.WaitForExit()

            if proc.ExitCode <> 0 then
                Error (sprintf "[ERROR] Backend command failed (exit code %d):\n%s" proc.ExitCode error)
            else
                let options = JsonSerializerOptions()
                options.PropertyNameCaseInsensitive <- true

                try
                    let response = JsonSerializer.Deserialize<BackendDiscoveryResponse>(output, options)
                    Ok response
                with
                | ex -> Error (sprintf "[ERROR] Failed to parse backend response: %s\nOutput: %s" ex.Message output)
        with
        | ex -> Error (sprintf "[ERROR] Failed to execute backend command: %s" ex.Message)

/// Install command options
type InstallOptions = {
    LuaVersion: string option
    LuaRocksVersion: string option
    Alias: string option
    Name: string option
    UseDll: bool
    UseDebug: bool
    UseX86: bool
    SkipEnvCheck: bool
    SkipTests: bool
}

/// Uninstall command options
type UninstallOptions = {
    IdOrAlias: string
    Force: bool
}

/// Set alias command options
type SetAliasOptions = {
    IdOrAlias: string
    NewAlias: string
}

/// Remove alias command options
type RemoveAliasOptions = {
    IdOrAlias: string
    AliasToRemove: string option
}

/// Default installation command options
type DefaultOptions = {
    IdOrAlias: string
}

/// List command options
type ListOptions = {
    Detailed: bool
}

/// Status command options (simplified - no additional options needed)
type StatusOptions = unit

// Environment-related types have been removed as they are implemented in the luaenv.ps1 wrapper
// and not used in the CLI core library.

/// Versions command options
type VersionsOptions = {
    ShowAvailable: bool
    Refresh: bool
}

/// Options for pkg-config command
type PkgConfigOptions = {
    Installation: string
    ShowCFlag: bool
    ShowLuaInclude: bool
    ShowLibDir: bool
    ShowLibLua: bool
    ShowPaths: bool
    PathStyle: string option
}

/// CLI Commands
type Command =
    | Install of InstallOptions
    | Uninstall of UninstallOptions
    | List of ListOptions
    | Status of StatusOptions
    | Versions of VersionsOptions
    | PkgConfig of PkgConfigOptions
    | SetAlias of SetAliasOptions
    | RemoveAlias of RemoveAliasOptions
    | Default of DefaultOptions
    | ShowConfig
    | Help
    | Environment // No parameters needed, command handled by PowerShell wrapper

/// Represents paths information from pkg-config backend
type PkgConfigPaths = {
    [<JsonPropertyName("prefix")>]
    Prefix: string
    [<JsonPropertyName("bin")>]
    Bin: string
    [<JsonPropertyName("include")>]
    Include: string
    [<JsonPropertyName("lib")>]
    Lib: string
    [<JsonPropertyName("share")>]
    Share: string
    [<JsonPropertyName("doc")>]
    Doc: string
    [<JsonPropertyName("lua_exe")>]
    LuaExe: string option
    [<JsonPropertyName("luac_exe")>]
    LuacExe: string option
    [<JsonPropertyName("lua_dll")>]
    LuaDll: string option
    [<JsonPropertyName("lua_lib")>]
    LuaLib: string option
    [<JsonPropertyName("lua_h")>]
    LuaH: string option
}

/// Represents flags information from pkg-config backend
type PkgConfigFlags = {
    [<JsonPropertyName("cflags")>]
    CFlags: string
    [<JsonPropertyName("libs")>]
    Libs: string
    [<JsonPropertyName("ldflags")>]
    LdFlags: string
}

/// Represents the complete pkg-config response from backend
type PkgConfigResponse = {
    [<JsonPropertyName("id")>]
    Id: string
    [<JsonPropertyName("name")>]
    Name: string
    [<JsonPropertyName("alias")>]
    Alias: string option
    [<JsonPropertyName("lua_version")>]
    LuaVersion: string
    [<JsonPropertyName("luarocks_version")>]
    LuaRocksVersion: string
    [<JsonPropertyName("build_type")>]
    BuildType: string
    [<JsonPropertyName("build_config")>]
    BuildConfig: string
    [<JsonPropertyName("architecture")>]
    Architecture: string
    [<JsonPropertyName("installation_path")>]
    InstallationPath: string
    [<JsonPropertyName("paths")>]
    Paths: PkgConfigPaths
    [<JsonPropertyName("flags")>]
    Flags: PkgConfigFlags
}

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
                    "py"  // Fallback to system Python

            let scriptPath = Path.Combine(config.BackendDir, scriptName)
            if not (File.Exists scriptPath) then
                Error (sprintf "[ERROR] Backend script not found: %s" scriptPath)
            else
                // Use relative script name and set working directory to backend folder
                let arguments = String.Join(" ", scriptName :: args)

                let startInfo = ProcessStartInfo()
                startInfo.FileName <- pythonExe
                startInfo.Arguments <- arguments
                startInfo.WorkingDirectory <- config.BackendDir
                startInfo.UseShellExecute <- false
                // Let scripts print directly to console - no I/O redirection

                // Explicitly copy current environment to ensure VS variables are passed
                startInfo.EnvironmentVariables.Clear()
                for envVar in System.Environment.GetEnvironmentVariables() do
                    let entry = envVar :?> System.Collections.DictionaryEntry
                    startInfo.EnvironmentVariables.[entry.Key.ToString()] <- entry.Value.ToString()

                use proc = Process.Start(startInfo)
                proc.WaitForExit()

                Ok proc.ExitCode
        with
        | ex -> Error (sprintf "[ERROR] Failed to execute backend script: %s" ex.Message)

    /// Execute install command via setup_lua.py
    let executeInstall (config: BackendConfig) (options: InstallOptions) : Result<int, string> =
        try
            // Validate all parameters first
            let validationErrors = ResizeArray<string>()

            // Check Lua version if provided
            match options.LuaVersion with
            | Some version when String.IsNullOrWhiteSpace(version) ->
                validationErrors.Add("Lua version cannot be empty when specified")
            | _ -> ()

            // Check LuaRocks version if provided
            match options.LuaRocksVersion with
            | Some version when String.IsNullOrWhiteSpace(version) ->
                validationErrors.Add("LuaRocks version cannot be empty when specified")
            | _ -> ()

            // Check alias if provided
            match options.Alias with
            | Some alias when String.IsNullOrWhiteSpace(alias) ->
                validationErrors.Add("Alias cannot be empty when specified")
            | _ -> ()

            // Check name if provided
            match options.Name with
            | Some name when String.IsNullOrWhiteSpace(name) ->
                validationErrors.Add("Installation name cannot be empty when specified")
            | _ -> ()

            // If there are any validation errors, return them
            if validationErrors.Count > 0 then
                Error (sprintf "[ERROR] Invalid parameters: %s" (String.Join(", ", validationErrors)))
            else
                // All parameters valid, build argument list
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
                if options.UseX86 then args.Add("--x86")
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
        with
        | ex -> Error (sprintf "[ERROR] Failed to execute install command: %s" ex.Message)

    /// Execute uninstall command via registry.py
    let executeUninstall (config: BackendConfig) (options: UninstallOptions) : Result<int, string> =
        try
            // Validate required parameters
            if String.IsNullOrWhiteSpace(options.IdOrAlias) then
                Error "[ERROR] Installation ID or alias cannot be empty"
            else
                // Parameter is valid, call the backend
                let args = ["remove"; options.IdOrAlias]
                let finalArgs = if options.Force then args @ ["--yes"] else args
                executePython config "registry.py" finalArgs
        with
        | ex -> Error (sprintf "[ERROR] Failed to execute uninstall command: %s" ex.Message)

    /// Execute list command via registry.py (backend) or direct registry access (detailed)
    let executeList (config: BackendConfig) (options: ListOptions) : Result<int, string> =
        if options.Detailed then
            // Use direct registry access for detailed mode
            try
                match RegistryAccess.loadRegistry None with
                | Ok registry ->
                    let installations = RegistryAccess.getInstallations registry
                    let defaultInstallation = RegistryAccess.getDefaultInstallation registry

                    if List.isEmpty installations then
                        printfn "[INFO] No installations found"
                    else
                        printfn "[INFO] Found %d installations (detailed view):" installations.Length
                        printfn ""

                        for installation in installations do
                            let isDefault =
                                match defaultInstallation with
                                | Some def -> def.id = installation.id
                                | None -> false

                            let statusMark = if isDefault then "[DEFAULT]" else sprintf "[%s]" (installation.status.ToUpper())
                            let aliasInfo =
                                match installation.alias with
                                | Some alias -> sprintf " (alias: %s)" alias
                                | None -> ""

                            printfn "  %s %s%s" statusMark installation.name aliasInfo
                            printfn "    ID: %s" installation.id
                            printfn "    Lua: %s, LuaRocks: %s" installation.lua_version installation.luarocks_version
                            printfn "    Build: %s %s (%s)" installation.build_type installation.build_config installation.architecture
                            printfn "    Created: %s" installation.created

                            printfn "    Installation Path: %s" installation.installation_path
                            printfn "    Environment Path: %s" installation.environment_path

                            if not (List.isEmpty installation.tags) then
                                let tagsStr = String.Join(", ", installation.tags)
                                printfn "    Tags: %s" tagsStr

                            // Get size information
                            let sizeInfo = RegistryAccess.getInstallationSize installation
                            printfn "    Disk Usage: %s (Installation: %s, Environment: %s)"
                                sizeInfo.TotalSize sizeInfo.InstallationSize sizeInfo.EnvironmentSize

                            // Validate installation
                            let validation = RegistryAccess.validateInstallation installation
                            if not validation.IsValid then
                                printfn "    [WARNING] Issues detected:"
                                for issue in validation.Issues do
                                    printfn "      - %s" issue
                            else
                                printfn "    [OK] Installation validated successfully"

                            printfn ""

                    Ok 0
                | Error errorMsg ->
                    printfn "[ERROR] %s" errorMsg
                    Ok 1
            with
            | ex ->
                Error (sprintf "[ERROR] Failed to access registry: %s" ex.Message)
        else
            // Use backend for standard mode
            // printfn "Fetching installation list from backend..."
            let args = ["list"]
            executePython config "registry.py" args

    /// Execute status command via registry.py (backend)
    let executeStatus (config: BackendConfig) (options: StatusOptions) : Result<int, string> =
        // For now, always use backend - detailed mode can be added later
        let args = ["status"]
        executePython config "registry.py" args

    // Environment command functions have been removed as they are implemented in the luaenv.ps1 wrapper
    // and not used in the CLI core library.

    /// Execute installed versions command using direct registry access
    let executeInstalledVersions (config: BackendConfig) : Result<int, string> =
        try
            let luaenvDir = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.UserProfile), ".luaenv")
            let registryPath = Path.Combine(luaenvDir, "registry.json")
            if not (File.Exists registryPath) then
                printfn "[ERROR] Registry file not found: %s" registryPath
                printfn "[INFO] Make sure you have installed at least one Lua environment"
                Ok 1
            else
                let jsonContent = File.ReadAllText registryPath
                let registryData = JsonSerializer.Deserialize<JsonElement>(jsonContent)

                printfn "INSTALLED VERSIONS:"
                printfn "%-20s | %-8s | %-10s | %-4s" "Alias" "Lua" "LuaRocks" "Arch"
                printfn "%s+%s+%s+%s" (String.replicate 21 "-") (String.replicate 10 "-") (String.replicate 12 "-") (String.replicate 5 "-")

                let installations = registryData.GetProperty("installations")
                let mutable defaultElement = Unchecked.defaultof<JsonElement>
                let defaultId =
                    if registryData.TryGetProperty("default_installation", &defaultElement) then
                        Some(defaultElement.GetString())
                    else
                        None

                let mutable hasInstallations = false
                for installation in installations.EnumerateObject() do
                    hasInstallations <- true
                    let inst = installation.Value
                    let id = inst.GetProperty("id").GetString()
                    let mutable aliasElement = Unchecked.defaultof<JsonElement>
                    let alias =
                        if inst.TryGetProperty("alias", &aliasElement) && aliasElement.ValueKind <> JsonValueKind.Null then
                            aliasElement.GetString()
                        else
                            id.Substring(0, 8)
                    let luaVersion = inst.GetProperty("lua_version").GetString()
                    let luarocksVersion = inst.GetProperty("luarocks_version").GetString()
                    let architecture = inst.GetProperty("architecture").GetString()
                    let isDefault = defaultId.IsSome && defaultId.Value = id
                    let defaultMarker = if isDefault then " [DEFAULT]" else ""

                    printfn "%-20s | %-8s | %-10s | %-4s%s" alias luaVersion luarocksVersion architecture defaultMarker

                if not hasInstallations then
                    printfn "  No installations found"
                    printfn ""
                    printfn "Use 'luaenv install' to install a Lua environment"

                Ok 0
        with
        | ex ->
            Error (sprintf "[ERROR] Failed to read registry: %s" ex.Message)

    /// Execute versions command
    let executeVersions (config: BackendConfig) (options: VersionsOptions) : Result<int, string> =
        if options.ShowAvailable then
            // Show progress message for refresh operations
            if options.Refresh then
                printfn "Discovering available versions (this may take a moment)..."
                printfn "Checking lua.org and luarocks.github.io servers..."
                printfn ""

            // Use new structured backend JSON API for available versions
            match Config.discoverVersions config options.Refresh with
            | Ok response ->
                try
                    let currentConfig = response.CurrentConfig
                    let availableVersions = response.AvailableVersions
                    let cacheInfo = response.CacheInfo

                    printfn "AVAILABLE VERSIONS"
                    printfn ""

                    // Lua versions (more concise)
                    printfn "Lua:"
                    for version in availableVersions.Lua do
                        let marker = if version = currentConfig.LuaVersion then " ●" else "  "
                        printfn "%s%s" marker version

                    printfn ""

                    // LuaRocks versions for all platforms (show both 32-bit and 64-bit)
                    let currentPlatform = currentConfig.LuaRocksPlatform
                    let currentLuaRocksVersion = currentConfig.LuaRocksVersion

                    // Sort platforms to show 64-bit first, then 32-bit
                    let sortedPlatforms =
                        availableVersions.LuaRocks.Keys
                        |> Seq.sort
                        |> Seq.toList

                    for platform in sortedPlatforms do
                        let versions = availableVersions.LuaRocks.[platform]
                        let platformDisplay =
                            if platform = currentPlatform then
                                sprintf "LuaRocks (%s) [current]:" platform
                            else
                                sprintf "LuaRocks (%s):" platform

                        printfn "%s" platformDisplay
                        for version in versions do
                            let marker =
                                if platform = currentPlatform && version = currentLuaRocksVersion then " ●"
                                else "  "
                            printfn "%s%s" marker version
                        printfn ""

                    // Show cache age only if using cache and it's relevant
                    if cacheInfo.UsedCache && cacheInfo.CacheAgeHours.IsSome then
                        let age = cacheInfo.CacheAgeHours.Value
                        if age > 24.0 then
                            printfn ""
                            printfn "Cache: %.0f days old (use --refresh to update)" (age / 24.0)
                        elif age > 1.0 then
                            printfn ""
                            printfn "Cache: %.0f hours old (use --refresh to update)" age

                    // Add helpful note about marked versions
                    printfn ""
                    printfn "Note: Versions marked with ● are the default when running 'luaenv install'"
                    printfn "      These defaults are configured in the backend system:"
                    printfn "      %s" response.ConfigInfo.ConfigFile
                    printfn ""
                    printfn "      [WARNING] Editing build_config.txt directly may cause unexpected behavior."
                    printfn "      Use 'luaenv config' commands when available, or edit with caution."

                    Ok 0
                with
                | ex ->
                    Error (sprintf "[ERROR] Failed to format version information: %s" ex.Message)
            | Error errorMsg ->
                Error errorMsg
        else
            // Direct registry access for installed versions (fast)
            executeInstalledVersions config

    /// Execute set-alias command via registry.py
    let executeSetAlias (config: BackendConfig) (options: SetAliasOptions) : Result<int, string> =
        try
            // Validate required parameters
            if String.IsNullOrWhiteSpace(options.IdOrAlias) then
                Error "[ERROR] Installation ID or alias cannot be empty"
            else if String.IsNullOrWhiteSpace(options.NewAlias) then
                Error "[ERROR] New alias cannot be empty"
            else
                // Both parameters are valid, call the backend with correct subcommand structure
                // The registry.py expects: alias set <id> <alias>
                let args = ["alias"; "set"; options.IdOrAlias; options.NewAlias]
                executePython config "registry.py" args
        with
        | ex -> Error (sprintf "[ERROR] Failed to execute set-alias command: %s" ex.Message)

    /// Execute remove-alias command via registry.py
    let executeRemoveAlias (config: BackendConfig) (options: RemoveAliasOptions) : Result<int, string> =
        try
            // Validate required parameter
            if String.IsNullOrWhiteSpace(options.IdOrAlias) then
                Error "[ERROR] Alias or installation ID cannot be empty"
            else
                // Handle the two use cases:
                // 1. UUID + mandatory alias to remove
                // 2. Alias (with optional second alias to remove)

                // Try to find if IdOrAlias is a UUID (full or partial)
                let isUuid =
                    Guid.TryParse(options.IdOrAlias, ref Unchecked.defaultof<Guid>)
                    || (options.IdOrAlias.Length >= 4 && options.IdOrAlias.ToLower() |> Seq.forall (fun c -> "0123456789abcdef-".Contains(c)))

                if isUuid then
                    // Case 1: UUID provided, so second argument (alias) is required
                    match options.AliasToRemove with
                    | None ->
                        Error "[ERROR] When specifying an installation ID, you must provide an alias to remove"
                    | Some aliasToRemove ->
                        if String.IsNullOrWhiteSpace(aliasToRemove) then
                            Error "[ERROR] Alias to remove cannot be empty"
                        else
                            // Call registry.py to remove the specific alias
                            // We use "alias remove <alias>" because registry.py doesn't support
                            // removing a specific alias from a specific installation directly
                            let args = ["alias"; "remove"; aliasToRemove]
                            executePython config "registry.py" args
                else
                    // Case 2: Alias provided, so remove that alias
                    // If a second alias is provided, validate and use that instead
                    let aliasToRemove =
                        match options.AliasToRemove with
                        | Some alias when not (String.IsNullOrWhiteSpace(alias)) -> alias
                        | _ -> options.IdOrAlias

                    // Call registry.py to remove the alias
                    let args = ["alias"; "remove"; aliasToRemove]
                    executePython config "registry.py" args
        with
        | ex -> Error (sprintf "[ERROR] Failed to execute remove-alias command: %s" ex.Message)

    /// Execute 'default' command to set the default Lua installation
    let executeDefault (config: BackendConfig) (options: DefaultOptions) : Result<int, string> =
        try
            // Validate required parameter
            if String.IsNullOrWhiteSpace(options.IdOrAlias) then
                Error "[ERROR] Alias or installation ID cannot be empty"
            else
                // Call the registry.py script with 'default' command and the provided ID/alias
                executePython config "registry.py" ["default"; options.IdOrAlias]
        with
        | ex -> Error $"[ERROR] Failed to set default installation: {ex.Message}"

    /// Execute pkg-config command for specific installation
// Fix the executePkgConfig function to properly display all output from pkg_config.py

    let executePkgConfig (config: BackendConfig) (installation: string) (showCFlag: bool) (showLuaInclude: bool) (showLibLua: bool) (showLibDir: bool) (showPaths: bool) (pathStyle: string option) : Result<int, string> =
        try
            // Validate required parameters
            if String.IsNullOrWhiteSpace(installation) then
                Error "[ERROR] Installation ID or alias cannot be empty"
            else
                // Check pathStyle if provided
                match pathStyle with
                | Some style when String.IsNullOrWhiteSpace(style) ->
                    Error "[ERROR] Path style cannot be empty when specified"
                | Some style when not (List.contains style ["windows"; "unix"; "native"]) ->
                    Error (sprintf "[ERROR] Invalid path style: %s. Must be one of: 'windows', 'unix', 'native'" style)
                | _ ->
                    // All parameters are valid, proceed with execution
                    let pythonExe = config.EmbeddedPython.PythonExe
                    let pkgConfigScript = Path.Combine(config.BackendDir, "pkg_config.py")

                    // Build arguments based on options
                    let mutable args = $"\"{pkgConfigScript}\" \"{installation}\""

                    if showCFlag then
                        args <- args + " --cflag"
                    elif showLuaInclude then
                        args <- args + " --lua-include"
                    elif showLibLua then
                        args <- args + " --liblua"
                    elif showLibDir then
                        args <- args + " --libdir"
                    elif showPaths then
                        args <- args + " --path"
                    // No --json flag for full output format
                    // This will let pkg_config.py handle the formatting
                    // and show all information including DLL requirements

                    // Add path style if specified
                    match pathStyle with
                    | Some style -> args <- args + $" --path-style {style}"
                    | None -> ()

                    let startInfo = ProcessStartInfo()
                    startInfo.FileName <- pythonExe
                    startInfo.Arguments <- args
                    startInfo.WorkingDirectory <- config.BackendDir
                    startInfo.RedirectStandardOutput <- true
                    startInfo.RedirectStandardError <- true
                    startInfo.UseShellExecute <- false
                    startInfo.CreateNoWindow <- true

                    // Explicitly copy current environment to ensure VS variables are passed
                    startInfo.EnvironmentVariables.Clear()
                    for envVar in System.Environment.GetEnvironmentVariables() do
                        let entry = envVar :?> System.Collections.DictionaryEntry
                        startInfo.EnvironmentVariables.[entry.Key.ToString()] <- entry.Value.ToString()

                    use proc = Process.Start(startInfo)
                    let output = proc.StandardOutput.ReadToEnd()
                    let errorOutput = proc.StandardError.ReadToEnd()

                    proc.WaitForExit()

                    if proc.ExitCode <> 0 then
                        if not (String.IsNullOrWhiteSpace errorOutput) then
                            Error (errorOutput.Trim())
                        else
                            Error (sprintf "[ERROR] Pkg-config command failed with exit code %d.\n%s" proc.ExitCode output)
                    else
                        // Always print the output directly
                        printf "%s" output
                        Ok 0
        with
        | ex ->
            Error (sprintf "[ERROR] Failed to execute pkg-config command: %s" ex.Message)