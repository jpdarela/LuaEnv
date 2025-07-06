// This is free and unencumbered software released into the public domain.
// For more details, see the LICENSE file in the project root.

namespace LuaEnv.Core

open System
open System.IO
open System.Text.Json

/// Package information from registry
type PackageInfo = {
    count: int
    last_updated: string option
}

/// Complete installation record from registry
type Installation = {
    id: string
    name: string
    alias: string option
    lua_version: string
    luarocks_version: string
    build_type: string
    build_config: string
    architecture: string
    created: string
    last_used: string option
    status: string
    installation_path: string
    environment_path: string
    packages: PackageInfo
    tags: string list
}

/// Registry data structure
type RegistryData = {
    registry_version: string
    created: string
    updated: string
    default_installation: string option
    installations: Map<string, Installation>
    aliases: Map<string, string>
}

/// Registry access module for direct JSON operations
module RegistryAccess =

    /// Get the default registry path in user's home directory
    let getDefaultRegistryPath () : string =
        let homeDir = Environment.GetFolderPath(Environment.SpecialFolder.UserProfile)
        Path.Combine(homeDir, ".luaenv", "registry.json")

    /// Parse registry JSON with custom JSON options
    let private parseRegistryJson (json: string) : Result<RegistryData, string> =
        try
            let options = JsonSerializerOptions()
            options.PropertyNameCaseInsensitive <- true
            options.PropertyNamingPolicy <- JsonNamingPolicy.SnakeCaseLower

            let registryData = JsonSerializer.Deserialize<RegistryData>(json, options)
            Ok registryData
        with
        | ex -> Error (sprintf "Failed to parse registry JSON: %s" ex.Message)

    /// Load registry from file
    let loadRegistry (registryPath: string option) : Result<RegistryData, string> =
        let path = registryPath |> Option.defaultValue (getDefaultRegistryPath())

        try
            if not (File.Exists path) then
                Error (sprintf "Registry file not found: %s" path)
            else
                let json = File.ReadAllText path
                parseRegistryJson json
        with
        | ex -> Error (sprintf "Failed to read registry file: %s" ex.Message)

    /// Get all installations as a list with resolved aliases
    let getInstallations (registry: RegistryData) : Installation list =
        registry.installations
        |> Map.toList
        |> List.map (fun (id, installation) ->
            // Collect all aliases that point to this installation ID
            let aliases =
                registry.aliases
                |> Map.toList
                |> List.filter (fun (_, aliasId) -> aliasId = id)
                |> List.map fst

            // Convert list of aliases to a single comma-separated string
            let aliasString =
                match aliases with
                | [] -> None
                | _ -> Some (String.concat ", " aliases)

            { installation with alias = aliasString })
        |> List.sortBy (fun i -> i.created)

    /// Get default installation if set
    let getDefaultInstallation (registry: RegistryData) : Installation option =
        match registry.default_installation with
        | Some defaultId when registry.installations.ContainsKey defaultId ->
            let installation = registry.installations.[defaultId]
            // Collect all aliases that point to this installation ID
            let aliases =
                registry.aliases
                |> Map.toList
                |> List.filter (fun (_, aliasId) -> aliasId = defaultId)
                |> List.map fst

            // Convert list of aliases to a single comma-separated string
            let aliasString =
                match aliases with
                | [] -> None
                | _ -> Some (String.concat ", " aliases)

            Some { installation with alias = aliasString }
        | _ -> None

    /// Validate installation paths exist
    let validateInstallation (installation: Installation) : {| IsValid: bool; Issues: string list |} =
        let issues = ResizeArray<string>()

        if not (Directory.Exists installation.installation_path) then
            issues.Add (sprintf "Installation directory missing: %s" installation.installation_path)

        if not (Directory.Exists installation.environment_path) then
            issues.Add (sprintf "Environment directory missing: %s" installation.environment_path)

        // Check for key binaries
        let luaExe = Path.Combine(installation.installation_path, "bin", "lua.exe")
        if not (File.Exists luaExe) then
            issues.Add (sprintf "Lua executable missing: %s" luaExe)

        // LuaRocks is in its own subdirectory, not in bin
        let luarocksExe = Path.Combine(installation.installation_path, "luarocks", "luarocks.exe")
        if not (File.Exists luarocksExe) then
            issues.Add (sprintf "LuaRocks executable missing: %s" luarocksExe)

        {| IsValid = issues.Count = 0; Issues = issues |> List.ofSeq |}

    /// Format file size in human-readable format
    let private formatFileSize (bytes: int64) : string =
        let units = [| "B"; "KB"; "MB"; "GB" |]
        let mutable size = float bytes
        let mutable unitIndex = 0

        while size >= 1024.0 && unitIndex < units.Length - 1 do
            size <- size / 1024.0
            unitIndex <- unitIndex + 1

        sprintf "%.1f %s" size units.[unitIndex]

    /// Get directory size recursively
    let private getDirectorySize (path: string) : int64 option =
        try
            if Directory.Exists path then
                let dirInfo = DirectoryInfo(path)
                let totalSize =
                    dirInfo.GetFiles("*", SearchOption.AllDirectories)
                    |> Array.sumBy (fun f -> f.Length)
                Some totalSize
            else
                None
        with
        | _ -> None

    /// Get installation size information
    let getInstallationSize (installation: Installation) : {| InstallationSize: string; EnvironmentSize: string; TotalSize: string |} =
        let installSize = getDirectorySize installation.installation_path
        let envSize = getDirectorySize installation.environment_path

        let installSizeStr =
            match installSize with
            | Some size -> formatFileSize size
            | None -> "Unknown"

        let envSizeStr =
            match envSize with
            | Some size -> formatFileSize size
            | None -> "Unknown"

        let totalSizeStr =
            match installSize, envSize with
            | Some iSize, Some eSize -> formatFileSize (iSize + eSize)
            | Some iSize, None -> formatFileSize iSize
            | None, Some eSize -> formatFileSize eSize
            | None, None -> "Unknown"

        {| InstallationSize = installSizeStr; EnvironmentSize = envSizeStr; TotalSize = totalSizeStr |}
