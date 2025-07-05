# Meson build file for LuaEnv Integration
#
# This file demonstrates how to integrate a C project with a Lua environment
# managed by luaenv on Windows using Meson.
#
# Key integration points:
# 1. `run_command`: This is the standard Meson function to execute external
#    commands. It's used here to call `luaconfig`.
# 2. `--path-style windows`: This argument is crucial. It ensures that `luaenv`
#    outputs paths with backslashes (`\`), which Meson and the underlying
#    MSVC compiler expect on Windows.
# 3. `fs.parent()`: After getting the full path to the `.lib` file, we use the
#    `fs` module's `parent()` method to extract the directory. This is the
#    robust, platform-aware way to manipulate paths in Meson.
# 4. `cc.find_library`: We use the compiler object's `find_library` method to
#    locate the `lua54.lib` file within the directory we just found. This is
#    more reliable than hardcoding the full path.
# 5. `declare_dependency`: The results (include path and found library) are
#    wrapped in a dependency object, which is the standard way to manage
#    dependencies in Meson.

project('main', 'c', version : '0.1')

main_sources = ['main.c']

fs = import('fs')

cc = meson.get_compiler('c')
if cc.get_id() == 'msvc'
  c_args = ['/W2', '/DNDEBUG', '-D_CRT_SECURE_NO_WARNINGS']
else
  c_args = ['-Wall', '-Wextra', '-DNDEBUG']
endif

# Luaconfig integration for Windows/MSVC
# define the lueenv alias for the Lua environment
luaenv_alias = 'dev'  # This should match your luaenv alias
# define the luaconfig command
luaenv_pkg_config_cmd = ['luaconfig', luaenv_alias] # .cmd file extension is not needed in Meson

lua_dep = dependency('', required: false)  # Placeholder

if host_machine.system() == 'windows'
  fs = import('fs')
  # Use luaconfig to get Lua paths with Windows-style paths for Meson
  lua_include_cmd = run_command(luaenv_pkg_config_cmd, '--lua-include', '--path-style', 'windows', check: false)
  lua_lib_cmd = run_command(luaenv_pkg_config_cmd, '--liblua', '--path-style', 'windows', check: false)

  if lua_include_cmd.returncode() == 0 and lua_lib_cmd.returncode() == 0
    lua_include_dir = lua_include_cmd.stdout().strip()
    lua_lib_path = lua_lib_cmd.stdout().strip()

    message('Found Lua via luaenv:')
    message('  Include dir: ' + lua_include_dir)
    message('  Library: ' + lua_lib_path)

    # Get parent directory of the library path
    lua_lib_dir = fs.parent(lua_lib_path)
    message('  Library dir: ' + lua_lib_dir)

    lua_dep = declare_dependency(
      include_directories: include_directories(lua_include_dir),
      dependencies: cc.find_library('lua54', dirs: lua_lib_dir)
    )
  else
    warning('luaconfig failed, attempting fallback methods')
    # Fallback to traditional pkg-config or manual paths
    lua_dep = dependency('lua', required: false)
  endif
else
  # For non-Windows systems, use traditional pkg-config
  lua_dep = dependency('lua', required: true)
endif

main = executable('main', main_sources,
  c_args : c_args,
  dependencies : lua_dep,
  install : true
)