# LuaEnv `pkg-config` Integration Test Report

**Date:** 2025-07-02

## 1. Overview

This report details the successful integration and testing of the `luaenv pkg-config` command across a variety of native Windows build systems. The goal was to ensure that `luaenv` can provide robust, developer-friendly integration for C/C++ projects on Windows, particularly when using MSVC (the Visual Studio compiler).

The tests were conducted using a single C source file (`main.c`) that embeds a Lua interpreter, executes a simple script, and prints the result. A test harness, `build_all.ps1`, was created to automate the build and execution process for each system, ensuring consistent and repeatable results.

## 2. The `luaenv pkg-config` Command

The `luaenv pkg-config` command is the cornerstone of this integration. It is designed to provide build systems with the necessary compiler and linker flags to locate and link against a Lua installation managed by `luaenv`. This eliminates the need for hardcoded paths, making projects easier to configure.

### Key Features and Flags:

- **`dev` Alias**: The `dev` argument is an alias that points to the default Lua installation intended for development. This allows developers to switch their active Lua version without modifying build scripts.

- **`--cflag`**: This flag outputs the necessary compiler flag to locate the Lua header files (e.g., `lua.h`, `lauxlib.h`). For MSVC, this typically takes the form of `/I"C:\path\to\lua\include"`.

- **`--liblua`**: This flag outputs the full, direct path to the Lua static library file (e.g., `C:\path\to\lua\lib\lua54.lib`). This is the path the linker needs to find the Lua implementation.

- **`--lua-include`**: This flag returns only the path to the include directory, without the `/I` compiler flag.

- **`--path-style <windows|unix|native>`**: This is a critical feature for ensuring compatibility across different shells and build tools on Windows.
    - `windows` outputs paths with backslashes (e.g., `C:\\Users\\...`). This is required by `cl.exe`, `nmake`, and standard `cmd.exe` batch files.
    - `unix` outputs paths with forward slashes (e.g., `C:/Users/...`). This style is often preferred by cross-platform tools like CMake and Meson, and is essential in environments like MSYS2 or Cygwin.
    - `native` resolves to the appropriate style for the host operating system (\ in windows).

## 3. Test Methodology

The `build_all.ps1` script served as the master test harness. It performs the following steps:

1.  **Cleanup**: Removes all artifacts from previous builds to ensure a clean state.
2.  **Build**: Sequentially invokes each of the supported build systems.
3.  **Execute**: After each successful build, it runs the generated executable.
4.  **Report**: Captures the output and exit code, reporting success or failure for each step.
5.  **Summarize**: At the end, it provides a summary of which build methods were tested and what executables were created.

### Tested Build Systems:

1.  **nmake (`Makefile_win`)**: The classic Microsoft Program Maintenance Utility. Integration was achieved by having the `build_all.ps1` script generate temporary `.tmp` files containing the output of `pkg-config`, which are then included by the makefile.

2.  **Meson (`meson.build`)**: A modern and fast build system. Integration uses Meson's built-in `run_command` to execute `luaenv pkg-config` during the configuration phase. The `--path-style windows` flag was used to ensure the paths were correctly handled.

3.  **CMake (`CMakeLists.txt`)**: The de-facto standard for cross-platform C++ projects. Integration uses the `execute_process` command to run `luaenv` and capture the flags. The script demonstrates robust path handling using `get_filename_component` to extract the library directory for `find_library`.

4.  **Batch Script (`build.bat`)**: A standard Windows batch file. It uses a `for /f` loop to capture the output of `luaenv` into environment variables, which are then passed to `cl.exe`. This demonstrates a lightweight, dependency-free integration.

5.  **PowerShell Script (`build.ps1`)**: A modern scripting environment for Windows. The script directly invokes `luaenv`, captures the output into variables, and calls `cl.exe` using `Invoke-Expression`.

## 4. Results

**All tests passed successfully.**

Each of the five build systems was able to correctly configure, compile, link, and produce a working executable. The test harness confirmed that each executable ran and produced the expected output: `Hello from Lua! x from Lua: 42`.

The final run of the test harness produced the following executables, demonstrating the success of each build method:

```
Executables created:
  - main_bat.exe (batch) (533,504 bytes)
  - main_debug.exe (nmake) (1,283,584 bytes)
  - main_ps.exe (PowerShell) (533,504 bytes)
  - main.exe (cmake) (227,328 bytes)
  - main.exe (meson) (282,624 bytes)
  - main.exe (nmake) (533,504 bytes)
```

## 5. Conclusion

The `luaenv pkg-config` command, combined with the `--path-style` option, provides a powerful and flexible mechanism for integrating `luaenv`-managed Lua installations into any Windows C/C++ build environment. The tests confirm that developers using `nmake`, `Meson`, `CMake`, or simple batch and PowerShell scripts can easily and robustly link against Lua without hardcoding paths or complex configuration logic.

This functionality significantly lowers the barrier to entry for Windows developers wishing to use Lua in their native applications, fulfilling a key goal of the LuaEnv project.
