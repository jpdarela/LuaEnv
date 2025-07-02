# TODO

## Phase 1 CLI Implementation - Printing Commands (July 2, 2025)

### 🎯 **Objective**
Implement CLI commands for printing and understanding the LuaEnv system state:
- Available versions (what can be downloaded)
- Installed versions (what's currently installed)
- System state (help users understand their LuaEnv setup)

### 💡 **Commands to Implement**

#### **Core Information Commands**

**1. `luaenv list` - Show Installed Environments** ✅ IMPLEMENTED - ENHANCED VERSION READY
```bash
luaenv list                 ✅ DONE   # List all installations with details (backend)
luaenv list --detailed      🚧 NEXT   # Rich output with validation (direct registry)
luaenv list --validate      💡 FUTURE # Health check installations
luaenv list --json          💡 FUTURE # Machine-readable output (direct registry)
```
- ✅ Basic backend integration complete
- 🚧 Ready for `--detailed` flag using direct registry access
- 💡 Foundation for advanced features (validation, filtering, custom output)

**2. `luaenv status` - System Overview** ✅ IMPLEMENTED - ENHANCED VERSION READY
```bash
luaenv status                  ✅ DONE   # Overall system status (backend)
luaenv status --detailed       🚧 NEXT   # Enhanced system info (direct registry)
luaenv status --validate       💡 FUTURE # System health validation
luaenv status --disk-usage     💡 FUTURE # Show space usage per installation
```
- ✅ Basic backend integration complete
- 🚧 Ready for `--detailed` flag with registry validation and rich statistics
- 💡 Foundation for system health monitoring and diagnostics

**3. `luaenv versions` - Available Versions**
```bash
luaenv versions                # Show available Lua versions
luaenv versions --luarocks     # Show available LuaRocks versions
luaenv versions --all          # Show both Lua and LuaRocks
luaenv versions --installed    # Show only installed versions
```
- Integrate with `download_manager.py` or version detection
- Display what can be downloaded vs what's installed
- Show compatibility matrix

#### **Advanced Inspection Commands**

**4. `luaenv info <alias|uuid>` - Installation Details**
```bash
luaenv info dev                # Detailed info about specific installation
luaenv info a1b2c3d4           # Info by UUID
```
- Show build details, paths, environment variables
- Display LuaRocks configuration, package counts
- Show architecture, build type, creation date

**5. `luaenv which <alias|uuid>` - Path Information**
```bash
luaenv which dev               # Show paths for installation
luaenv which dev --bin         # Show just binary paths
```
- Display installation paths, binary locations
- Show LuaRocks tree paths, package directories

**6. `luaenv pkg-config <alias|uuid>` - C Developer Support**
```bash
luaenv pkg-config dev          # Show pkg-config style output
luaenv pkg-config dev --cflags # Show compiler flags
luaenv pkg-config dev --libs   # Show linker flags
luaenv pkg-config dev --path   # Show installation paths
```
- Offers functionality to C developers for finding Lua includes, libraries, and binaries (DLL)
- Output format suitable for Makefiles and build systems
- Support for both static and DLL builds

#### **System Health Commands**

**7. `luaenv check` - System Validation**
```bash
luaenv check                   # Validate system health
luaenv check --fix             # Attempt to fix issues
```
- Validate registry integrity, check for broken installations
- Verify embedded Python, backend scripts
- Check PATH configuration, wrapper functionality

### 🔧 **Implementation Strategy**

#### **Backend Integration Approach**
1. **Leverage Existing Scripts**: Use registry.py, download_manager.py, config.py
2. **JSON Communication**: Extend backend.config for additional script integration
3. **Error Handling**: Consistent error reporting across CLI and backend
4. **Performance**: Cache version information when possible

#### **F# CLI Architecture**
1. **Extend Types.fs**: Add new command types for printing operations
2. **Backend Execution**: Use existing `executePython` pattern
3. **Output Formatting**: Consistent, user-friendly display formatting
4. **Help Integration**: Context-specific help for each command

#### **Development Priority**
1. **Start Simple**: `luaenv list` and `luaenv status` (direct registry.py integration)
2. **Version Info**: `luaenv versions` (integrate with download manager)
3. **Enhanced Details**: `luaenv info` and `luaenv which`
4. **C Developer Support**: `luaenv pkg-config` for build system integration
5. **System Health**: `luaenv check` for validation

### 🚀 **Next Steps**
- Start with `luaenv list` (backend already exists, simple CLI integration)
- Foundation for other commands using established patterns
- Leverage existing registry.py functionality

### 📋 **Implementation Notes**
- Use existing backend scripts where possible
- Maintain consistent CLI argument parsing patterns
- Follow established error handling and help system
- All commands should integrate with luaenv.cmd wrapper



## To read (do not edit this section):

Interesting blogpost about implementations of a luaenv system: [LuaEnv Blog Post](https://www.frank-mitchell.com/projects/luaenv/)

---

**Last Updated**: July 2, 2025
**Status**: WORKING on F# CLI Implementation
