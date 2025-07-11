@echo off
setlocal enabledelayedexpansion

REM ====================================================================
REM setup-luarocks.bat [LUA_DIR]
REM
REM Arguments:
REM   LUA_DIR (optional) - Path to Lua installation directory
REM
REM If LUA_DIR is not provided as an argument, the script will prompt
REM the user for input. If no input is provided, defaults to "lua".
REM
REM Examples:
REM   setup-luarocks.bat
REM   setup-luarocks.bat C:\lua
REM   setup-luarocks.bat lua-5.4.8
REM
REM If your luarocks.exe is not in the PATH, place this script in the same directory as luarocks.exe
REM or modify the PATH variable to include the directory where luarocks.exe is located.
REM This script configures LuaRocks to work with a Lua build (static or DLL).
REM Make sure to run this script from a Visual Studio Developer Command Prompt
REM to ensure the environment is set up correctly for compiling C extensions.
REM ====================================================================
REM LuaRocks Configuration Script for Lua Build


echo ====================================================================
echo LuaRocks Configuration Helper for Lua Build
echo ====================================================================
echo.

REM Check if LuaRocks is installed

where luarocks.exe >nul 2>&1
if %ERRORLEVEL% neq 0 (
    echo ERROR: LuaRocks not found in PATH.
    echo.
    echo Please download and install LuaRocks from:
    echo https://luarocks.org/releases/
    echo.
    echo Make sure luarocks.exe is in your PATH.
    exit /b 1
)

echo LuaRocks found:
luarocks --version
echo.

REM Get the Lua installation directory
REM Check if command line argument was provided
if "%~1"=="" (
    REM No argument provided, ask user
    set /p LUA_DIR="Enter your Lua installation directory (default: lua): "
    if "!LUA_DIR!"=="" set "LUA_DIR=lua"
) else (
    REM Use command line argument
    set "LUA_DIR=%~1"
    echo Using Lua installation directory from argument: !LUA_DIR!
)

REM Convert to absolute path if it's relative
if not "%LUA_DIR:~1,1%"==":" (
    set "LUA_DIR=%CD%\%LUA_DIR%"
)

echo.
echo Configuring LuaRocks for Lua installation at: %LUA_DIR%

REM Check if the Lua installation exists
if not exist "%LUA_DIR%\bin\lua.exe" (
    echo ERROR: lua.exe not found at %LUA_DIR%\bin\lua.exe
    echo Please check your Lua installation path.
    exit /b 1
)

if not exist "%LUA_DIR%\bin\luac.exe" (
    echo ERROR: luac.exe not found at %LUA_DIR%\bin\luac.exe
    echo Please check your Lua installation path.
    exit /b 1
)

REM Detect build type (static vs DLL)
set "BUILD_TYPE=static"
if exist "%LUA_DIR%\bin\lua54.dll" (
    set "BUILD_TYPE=dll"
    echo Detected DLL build (lua54.dll found)
) else (
    echo Detected static build (no lua54.dll found)
)

echo.
echo Configuring LuaRocks for %BUILD_TYPE% build...

REM Configure LuaRocks
luarocks config lua_interpreter "%LUA_DIR%\bin\lua.exe"
luarocks config lua_compiler "%LUA_DIR%\bin\luac.exe"
luarocks config lua_version 5.4
luarocks config lua_incdir "%LUA_DIR%\include"
luarocks config lua_libdir "%LUA_DIR%\lib"

REM Configure library linking based on build type
if "%BUILD_TYPE%"=="dll" (
    echo Configuring for DLL build...
    luarocks config lua_libname "lua54.lib"
    REM For DLL builds, we need to ensure the DLL is in PATH for runtime
    echo.
    echo IMPORTANT: For DLL build, lua54.dll must be in PATH or same directory as lua.exe
    if not exist "%LUA_DIR%\bin\lua54.dll" (
        echo WARNING: lua54.dll not found in %LUA_DIR%\bin\
        echo This may cause runtime issues with compiled packages.
    )
) else (
    echo Configuring for static build...
    luarocks config lua_libname "lua54.lib"
)

echo.
echo ====================================================================
echo ? LuaRocks Configuration Complete!
echo ====================================================================
echo.
echo LuaRocks has been configured to use your %BUILD_TYPE% Lua build:
echo   Build Type:  %BUILD_TYPE%
echo   Interpreter: %LUA_DIR%\bin\lua.exe
echo   Compiler:    %LUA_DIR%\bin\luac.exe
echo   Version:     5.4
echo   Headers:     %LUA_DIR%\include
echo   Library:     %LUA_DIR%\lib\lua54.lib

if "%BUILD_TYPE%"=="dll" (
    echo   Runtime DLL: %LUA_DIR%\bin\lua54.dll
    echo.
    echo NOTE: For DLL builds, ensure lua54.dll is accessible at runtime:
    echo   - Either add %LUA_DIR%\bin to your PATH
    echo   - Or copy lua54.dll alongside your applications
)

echo.

echo Testing configuration...
echo.
luarocks show --tree=system 2>nul || echo No system packages installed yet.

echo ====================================================================
echo LuaRocks Setup Complete!
echo ====================================================================

echo.
echo Use 'luaenv.ps1 activate --alias <name>' to set up your PowerShell
echo environment to use LuaRocks with your Lua installation.

echo Configuration saved. You can now use LuaRocks with your Lua build!
