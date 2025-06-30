<!-- Use this file to provide workspace-specific custom instructions to Copilot. For more details, visit https://code.visualstudio.com/docs/copilot/copilot-customization#_use-a-githubcopilotinstructionsmd-file -->

# LuaEnv F# Project Instructions

This is an F# project for LuaEnv, a Lua version manager for Windows.

## Project Structure

- **LuaEnv.Core**: Shared business logic library containing types, configuration management, and Python script integration
- **LuaEnv.CLI**: Command-line interface application using simple argument parsing
- **LuaEnv.GUI**: Avalonia UI desktop application (planned)

## Key Guidelines

1. **F# Best Practices**: Use functional programming principles, immutable data structures, and proper error handling with Result types
2. **Python Integration**: The project wraps existing Python build scripts located in the parent directory (`../`)
3. **Configuration**: Uses JSON configuration stored in `~/.luaenv/config.json`
4. **Build Types**: Support four Lua build configurations:
   - StaticRelease
   - StaticDebug
   - DllRelease
   - DllDebug

## Coding Conventions

- Use proper F# naming conventions (PascalCase for types, camelCase for values)
- Prefer immutable data structures and functional approaches
- Use Result types for error handling instead of exceptions where possible
- Keep Python script calls isolated in the PythonScripts module
- Use string interpolation carefully to avoid F# compiler issues

## Testing

- Test CLI commands with `dotnet run --project LuaEnv.CLI -- <command>`
- Verify Python integration by testing version discovery and installation
- Ensure cross-platform compatibility (Windows primary, but consider Linux/macOS)

## Integration Notes

- Python scripts are in parent directory and should be found automatically
- Build configuration is managed through `build_config.txt` in Python script directory
- Installation directories are managed in `~/.luaenv/versions/`
