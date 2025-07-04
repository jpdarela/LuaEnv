@REM @echo off
@REM :: luaenv-pkg-config.cmd - Command-line wrapper for luaenv pkg-config
@REM :: This is a helper script for CMake and other build systems
@REM :: It simply forwards the pkg-config request to PowerShell without activating the environment

@REM :: Get the directory where this script is located
@REM set "SCRIPT_DIR=%~dp0"

@REM :: Remove trailing backslash from script dir
@REM if %SCRIPT_DIR:~-1%==\ set "SCRIPT_DIR=%SCRIPT_DIR:~0,-1%"

@REM :: Construct the PowerShell command
@REM :: Pass all arguments to the pkg-config command
@REM powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "& '%SCRIPT_DIR%\luaenv.ps1' pkg-config %*"

@REM :: Exit with PowerShell's exit code
@REM exit /b %ERRORLEVEL%

@echo off
REM filepath: c:\Users\darel\Desktop\lua_msvc_build\backend\luaenv-pkg-config.cmd
REM Wrapper for direct CLI call with backend.config

REM Get the directory where this script is located
set "SCRIPT_DIR=%~dp0"
if "%SCRIPT_DIR:~-1%"=="\" set "SCRIPT_DIR=%SCRIPT_DIR:~0,-1%"

REM Path to CLI executable and config (matches luaenv.ps1 logic)
set "LUAENV_CLI=%SCRIPT_DIR%\cli\LuaEnv.CLI.exe"
set "LUAENV_CONFIG=%SCRIPT_DIR%\backend.config"

REM Call the CLI directly, forwarding all arguments after pkg-config
"%LUAENV_CLI%" --config "%LUAENV_CONFIG%" pkg-config %*

exit /b %ERRORLEVEL%