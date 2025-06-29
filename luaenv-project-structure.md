# LuaEnv Project Structure

## Creating the F# + Avalonia Project

### Prerequisites
```bash
# Install .NET 8 SDK
# Install F# tools
dotnet new install Avalonia.ProjectTemplates
```

### Project Creation
```bash
# Create solution
dotnet new sln -n LuaEnv

# Create core library (shared logic)
dotnet new classlib -lang F# -n LuaEnv.Core
dotnet sln add LuaEnv.Core

# Create CLI application
dotnet new console -lang F# -n LuaEnv.CLI
dotnet sln add LuaEnv.CLI

# Create GUI application
dotnet new avalonia.fsharp -n LuaEnv.GUI
dotnet sln add LuaEnv.GUI

# Add project references
dotnet add LuaEnv.CLI reference LuaEnv.Core
dotnet add LuaEnv.GUI reference LuaEnv.Core
```

### Package Dependencies

#### LuaEnv.Core.fsproj
```xml
<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup>
    <TargetFramework>net8.0</TargetFramework>
  </PropertyGroup>

  <ItemGroup>
    <PackageReference Include="System.Text.Json" Version="8.0.0" />
    <PackageReference Include="System.CommandLine" Version="2.0.0-beta4.22272.1" />
  </ItemGroup>
</Project>
```

#### LuaEnv.CLI.fsproj
```xml
<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup>
    <OutputType>Exe</OutputType>
    <TargetFramework>net8.0</TargetFramework>
    <PublishSingleFile>true</PublishSingleFile>
    <SelfContained>true</SelfContained>
    <RuntimeIdentifier>win-x64</RuntimeIdentifier>
  </PropertyGroup>

  <ItemGroup>
    <ProjectReference Include="..\LuaEnv.Core\LuaEnv.Core.fsproj" />
  </ItemGroup>
</Project>
```

#### LuaEnv.GUI.fsproj
```xml
<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup>
    <OutputType>WinExe</OutputType>
    <TargetFramework>net8.0</TargetFramework>
    <Nullable>enable</Nullable>
    <BuiltInComInteropSupport>true</BuiltInComInteropSupport>
    <ApplicationManifest>app.manifest</ApplicationManifest>
    <AvaloniaUseCompiledBindingsByDefault>true</AvaloniaUseCompiledBindingsByDefault>
  </PropertyGroup>

  <ItemGroup>
    <PackageReference Include="Avalonia" Version="11.0.0" />
    <PackageReference Include="Avalonia.Desktop" Version="11.0.0" />
    <PackageReference Include="Avalonia.Themes.Fluent" Version="11.0.0" />
    <PackageReference Include="Avalonia.Fonts.Inter" Version="11.0.0" />
    <PackageReference Include="Avalonia.Diagnostics" Version="11.0.0" Condition="'$(Configuration)' == 'Debug'" />
  </ItemGroup>

  <ItemGroup>
    <ProjectReference Include="..\LuaEnv.Core\LuaEnv.Core.fsproj" />
  </ItemGroup>
</Project>
```

## File Structure
```
LuaEnv/
├── LuaEnv.sln
├── README.md
├── .gitignore
│
├── LuaEnv.Core/                 # Shared business logic
│   ├── LuaEnv.Core.fsproj
│   ├── Types.fs                 # Data types and models
│   ├── Configuration.fs         # Config management
│   ├── VersionManager.fs        # Version install/uninstall logic
│   ├── PythonWrapper.fs         # Interface to existing Python scripts
│   └── Utils.fs                 # Utility functions
│
├── LuaEnv.CLI/                  # Command-line interface
│   ├── LuaEnv.CLI.fsproj
│   ├── Program.fs               # CLI entry point
│   ├── Commands.fs              # Command definitions
│   └── CommandHandlers.fs       # Command implementations
│
├── LuaEnv.GUI/                  # Avalonia GUI
│   ├── LuaEnv.GUI.fsproj
│   ├── Program.fs               # GUI entry point
│   ├── App.axaml                # Application definition
│   ├── App.axaml.fs             # Application code-behind
│   ├── Views/
│   │   ├── MainWindow.axaml     # Main window XAML
│   │   ├── MainWindow.axaml.fs  # Main window code-behind
│   │   ├── VersionsView.axaml   # Versions tab
│   │   └── SettingsView.axaml   # Settings tab
│   └── ViewModels/
│       ├── MainWindowViewModel.fs
│       ├── VersionsViewModel.fs
│       └── SettingsViewModel.fs
│
├── assets/                      # Icons, images
│   ├── icon.ico
│   └── logo.png
│
├── scripts/                     # Build and deployment
│   ├── build.ps1
│   ├── package.ps1
│   └── installer.iss            # Inno Setup script
│
└── backend/                     # Keep existing Python scripts
    ├── setup.py
    ├── build.py
    ├── config.py
    └── ...                      # All our existing scripts
```

## Build Commands

### Development
```bash
# Build everything
dotnet build

# Run CLI
dotnet run --project LuaEnv.CLI -- versions

# Run GUI
dotnet run --project LuaEnv.GUI

# Watch GUI (hot reload)
dotnet watch --project LuaEnv.GUI
```

### Release
```bash
# Publish CLI (single executable)
dotnet publish LuaEnv.CLI -c Release -r win-x64 --self-contained

# Publish GUI
dotnet publish LuaEnv.GUI -c Release -r win-x64 --self-contained

# Create installer
iscc scripts/installer.iss
```

## Integration Strategy

### Phase 1: Wrapper Approach
- F# calls existing Python scripts
- Parse Python script outputs
- Gradually move logic to F#

### Phase 2: Native Implementation
- Rewrite core logic in F#
- Keep Python scripts as fallback
- Better error handling and performance

### Phase 3: Full Migration
- Complete F# implementation
- Remove Python dependencies
- Native Windows integration

## Benefits

1. **Single Tool**: `luaenv install 5.4.8 --dll --debug`
2. **Beautiful GUI**: Modern Avalonia interface
3. **Cross-Platform**: Works on Windows/Linux/macOS
4. **Performance**: Native .NET performance
5. **Type Safety**: F# type system prevents errors
6. **Extensible**: Easy to add new features
7. **Professional**: Single executable deployment
