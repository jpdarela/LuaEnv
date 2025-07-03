# TODO


# LuaEnv Environment Management

## Overview

The `~/.luaenv/environments/` directories serve as **per-installation LuaRocks package trees**, providing isolated package management similar to Python virtual environments. Each Lua installation gets its own environment directory for managing its specific package dependencies.

## Current Implementation

### Structure
```
~/.luaenv/
├── installations/
│   ├── <uuid>/              # Lua/LuaRocks binaries
│   └── ...
├── environments/
│   ├── <uuid>/              # LuaRocks package tree (same UUID as installation)
│   │   ├── lib/lua/5.4/     # Compiled modules (.dll files)
│   │   ├── share/lua/5.4/   # Lua modules (.lua files)
│   │   └── bin/             # Package executables
│   └── ...
└── registry.json           # Installation metadata
```

### How It should Work
1. **Creation**: Environment directories are created automatically when installations are registered
2. **Activation**: When using `use-lua.ps1` [luaenv activate], the environment path becomes the LuaRocks tree
3. **Isolation**: Each installation has its own package dependencies and module paths
4. **Configuration**: LuaRocks is configured to install packages to the environment directory

## Proposed CLI Enhancements

### New Command: `luaenv activate <alias|id>`
This command will activate a specific Lua environment, setting the necessary paths for LuaRocks and Lua modules.

**Implement the CLI command to <activate> a Lua environment**

```PowerShell
luaenv activate <alias|id>         # Activate a specific Lua environment by alias or ID
luaenv activate --default          # Activate the default installation in the registry
luaenv activate --help, -h         # Show help for the activate command
```

The command will be developed based on the use-lua.ps1 script, which sets up the environment variables for LuaRocks and Lua modules. It will create a `.luaenv` file in the current directory to store the activated installation information.

### Command Details
 - only one command
 - Make an installation of lua (with an isolated package tree) available in the current session
 - When called with an alias or ID, it will set the environment variables for LuaRocks and Lua modules
 - A text file called .luaenv will be created in the current directory with the activated installation information
 - When called without arguments, it will search for the .luaenv file in the current directory
 - if no arguments are provided, and no .luaenv file is found, an error is raised
 - luaenv activate <alias|id> - Activate an environment/installation based on alias or ID
 - luaenv activate --help - Show help for the activate command
 - luaenv activate --default activates the default installation in the registry


### Integration Points
- **LuaRocks**: Use `luarocks list` to get accurate package information
- **Registry**: Update registry with package counts and environment status
- **Activation**: Ensure `use-lua.ps1` properly sets up environment paths

## Benefits

1. **Isolation**: Each installation has independent package dependencies
2. **Management**: Easy cleanup and reset of package environments
3. **Visibility**: Clear overview of what packages are installed where
4. **Maintenance**: Automated cleanup of orphaned and empty environments

## Notes
- Environment directories are separate from installation directories for flexibility
- Custom LuaRocks trees can still be specified via `use-lua.ps1 -Tree <path>`
- Environment management doesn't interfere with existing LuaRocks workflows


## To read (do not edit this section):

Interesting blogpost about implementations of a luaenv system: [LuaEnv Blog Post](https://www.frank-mitchell.com/projects/luaenv/)

---

**Last Updated**: July 2, 2025
**Status**: WORKING on F# CLI Implementation
