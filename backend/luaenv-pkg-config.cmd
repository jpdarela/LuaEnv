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