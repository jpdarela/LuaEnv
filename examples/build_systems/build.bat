@echo off
rem Build script for compiling main.c with Lua using luaenv
rem If using a dll build, ensure that the dll is in the same directory as
rem the executable or in the system PATH.
rem You can use luaenv activate --alias dev to set up the environment for development.
rem This will set the bin path of the lua installation to the PATH variable,
rem enabling the finding of the lua.dll and linking against the Lua library.
rem This script assumes that you have an installation of lua made with luaenv with the dev alias.


echo [INFO] Setting up environment variables from luaenv...

rem Capture the compiler flags
for /f "delims=" %%i in ('luaconfig dev --cflag --path-style windows') do set CFLAGS=%%i

rem Capture the library path
for /f "delims=" %%i in ('luaconfig dev --liblua --path-style windows') do set LUA_LIB=%%i

echo [DEBUG] CFLAGS: %CFLAGS%
echo [DEBUG] LUA_LIB: %LUA_LIB%

echo [INFO] Compiling main.c...
cl.exe /Fe:main_bat.exe main.c %CFLAGS% /link "%LUA_LIB%" /TC /W4 /D_CRT_SECURE_NO_WARNINGS

if %errorlevel% neq 0 (
    echo [ERROR] Compilation failed!
    exit /b %errorlevel%
) else (
    echo [SUCCESS] Compilation successful!
    echo [INFO] Created main_bat.exe
)
