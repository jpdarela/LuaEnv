## TODO list

### HIGH PRIORITY
 - Remove duplicated logic to find vs tools in powershell scripts and Python scripts

 LuaEnv/
├── luaenv.ps1            # Main entry point (slim controller)
├── modules/
│   ├── LuaEnvCore.psm1   # Core registry and version functionality
│   ├── LuaEnvVS.psm1     # Visual Studio environment setup (shared)
│   ├── LuaEnvShell.psm1  # Shell integration (activate, deactivate, current)
│   ├── LuaEnvInstall.psm1 # Installation and package management
│   └── LuaEnvUtils.psm1  # Utility functions
└── backend/
    └── setenv.ps1        # Simplified to use shared VS module

### MEDIUM PRIORITY



 - Doc
 - tests
 - final deployment (move backend and embeded python to luaenv directory at install time)

**Last Updated**: July 7, 2025
**Status**: Working version of LuaEnv with basic features implemented. The system is functional and can be used to manage Lua installations on Windows.
