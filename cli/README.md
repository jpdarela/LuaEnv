# LuaEnv - F# Lua Version Manager

A modern Lua version manager for Windows built with F# and .NET, featuring both CLI and GUI interfaces.

## 🚀 Quick Start

### Prerequisites

- **.NET 9.0 SDK** or later
- **Python 3.x** (for backend build scripts)
- **Visual Studio** with C++ build tools (for Lua compilation)

### Building the Project

```bash
# Clone and build
git clone <repository-url>
cd cli
dotnet build

# Run the CLI
dotnet run --project LuaEnv.CLI -- versions --available
```

## 📋 Features

### Current (v0.1)
- ✅ **Version Discovery**: List available Lua versions from official sources
- ✅ **Installation Management**: Install/uninstall different Lua versions
- ✅ **Build Configurations**: Support for Static/DLL and Debug/Release builds
- ✅ **Global Version**: Set system-wide default Lua version
- ✅ **Configuration Management**: JSON-based configuration system
- ✅ **Python Integration**: Wraps existing robust Python build scripts

### Planned (v0.2+)
- 🔄 **Avalonia GUI**: Modern desktop interface
- 🔄 **Shell Integration**: PowerShell and CMD shims
- 🔄 **Project-Local Versions**: Per-project `.lua-version` files
- 🔄 **Advanced CLI**: Better help, autocomplete, colored output

## 🖥️ CLI Usage

```bash
# List installed versions
luaenv versions

# List available versions for installation
luaenv versions --available

# Install a version (default: static release)
luaenv install 5.4.8

# Install with specific build type
luaenv install 5.4.8 --dll --debug

# Set global version
luaenv global 5.4.8

# Uninstall a version
luaenv uninstall 5.4.8

# Show configuration
luaenv config

# Validate configuration
luaenv config --validate

# Clean download cache
luaenv clean
```

## 🏗️ Architecture

### Project Structure
```
cli/
├── LuaEnv.Core/          # Shared business logic
│   └── Types.fs          # Core types and functionality
├── LuaEnv.CLI/           # Command-line interface
│   └── Program.fs        # CLI entry point
├── LuaEnv.GUI/           # Avalonia desktop app (planned)
└── LuaEnv.sln           # Solution file
```

### Design Principles

1. **Functional-First**: Built with F#'s functional programming strengths
2. **Wrapper Architecture**: Reuses existing robust Python build scripts
3. **Type Safety**: Leverages F#'s type system to prevent runtime errors
4. **Cross-Platform**: Uses .NET for Windows/Linux/macOS compatibility
5. **Modern UX**: Clean CLI now, beautiful GUI coming soon

## 🔧 Development

### Running Tests
```bash
# Build all projects
dotnet build

# Test specific CLI commands
dotnet run --project LuaEnv.CLI -- versions --available
dotnet run --project LuaEnv.CLI -- config --validate
```

### Adding New Commands

1. Add functionality to `LuaEnv.Core/Types.fs`
2. Add command parsing to `LuaEnv.CLI/Program.fs`
3. Test with `dotnet run --project LuaEnv.CLI -- <your-command>`

### Python Integration

The F# application integrates with existing Python scripts:
- **config.py**: Version discovery and validation
- **setup_lua.py**: Lua installation and building
- **clean.py**: Cache management

## 📦 Build Types

LuaEnv supports four Lua build configurations:

| Type | Description | Use Case |
|------|-------------|----------|
| **StaticRelease** | Static library, optimized | Production embedding |
| **StaticDebug** | Static library, debug symbols | Development/debugging |
| **DllRelease** | Dynamic library, optimized | Production applications |
| **DllDebug** | Dynamic library, debug symbols | Development/debugging |

## 🗂️ Configuration

LuaEnv stores configuration in JSON format at `~/.luaenv/config.json`:

```json
{
  "GlobalVersion": "5.4.8",
  "Installations": {
    "5.4.8": {
      "Version": "5.4.8",
      "Path": "C:\\Users\\user\\.luaenv\\versions\\5.4.8",
      "BuildType": "StaticRelease",
      "LuaRocksVersion": "3.12.2",
      "InstallDate": "2025-01-01T00:00:00Z"
    }
  },
  "CachePath": "",
  "LastUpdate": "2025-01-01T00:00:00Z"
}
```

## 🎯 Roadmap

### Phase 1: Core CLI ✅
- [x] Basic version management
- [x] Python script integration
- [x] Configuration system
- [x] Build type support

### Phase 2: Enhanced CLI 🔄
- [ ] System.CommandLine integration
- [ ] Colored output and better formatting
- [ ] Shell integration (PowerShell/CMD)
- [ ] Auto-completion support

### Phase 3: Desktop GUI 🔄
- [ ] Avalonia UI application
- [ ] Visual installation progress
- [ ] Project management interface
- [ ] Settings and preferences

### Phase 4: Advanced Features 🔄
- [ ] Per-project version files
- [ ] IDE integration helpers
- [ ] Automatic environment switching
- [ ] Plugin system

## 🤝 Contributing

1. **Fork the repository**
2. **Create a feature branch**: `git checkout -b feature/amazing-feature`
3. **Make your changes** following F# conventions
4. **Test thoroughly**: Ensure CLI commands work correctly
5. **Submit a pull request**

## 📜 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 🙏 Acknowledgments

- Built on top of the robust Lua MSVC Build System Python scripts
- Inspired by pyenv, rbenv, and other version managers
- Uses Avalonia UI for cross-platform desktop applications
