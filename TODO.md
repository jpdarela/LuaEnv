## TODO list

### HIGH PRIORITY

- Add the remove-alias command to the CLI (OK)

- define the correct behaviour of the set-alias and remove-alias commands (OK)

- Make sure that the activate command overwrites the correct environment variables (OK)

- Add the ability to the activate command to activate a default LuaEnv based on the registry [DEFAULT]. If a local file .lua-version is present, it should override the registry setting. If a file .lua-version is present and the activate command is called with a version, it should not override the file setting. To create or modify the .lua-version file, the user will use the implemented (to be) `local` command (OK)

- Add the `local` command to create or modify the .lua-version file in the current directory. This command should allow users to set a local Lua version that overrides the global setting when in that directory. (OK)

- Add the default command to set the default Lua version in the registry. This command should allow users to set a global Lua version that will be used when no local version is specified and no alias is provided at activation time. (OK)

- Check the behaviour of the download cache expiry and work on the help messages to refresh the cache

### MEDIUM PRIORITY

- Add the ability to install Lua versions from a local file (e.g., a tarball) using the CLI. This should include a command like `luaenv install-local <file>` that installs Lua from a specified local file.

- Improve version finding and installation process for all Lua versions >=5.1 and LuaRocks >=3.0. This includes: (started)
  - Implementing a more robust version detection mechanism that can handle different version formats.
  - Ensuring that the installation process correctly identifies and installs the latest versions of Lua and LuaRocks.
  - Add build scripts for Lua versions >=5.1.

 - Doc
 - tests
 - final deployment (move backend and embeded python to luaenv directory at install time)

**Last Updated**: July 7, 2025
**Status**: Working version of LuaEnv with basic features implemented. The system is functional and can be used to manage Lua installations on Windows.
