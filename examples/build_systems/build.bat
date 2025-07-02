@echo off
rem Build script for compiling main.c with Lua using luaenv

echo [INFO] Setting up environment variables from luaenv...

rem Capture the compiler flags
for /f "delims=" %%i in ('luaenv pkg-config dev --cflag --path-style windows') do set CFLAGS=%%i

rem Capture the library path
for /f "delims=" %%i in ('luaenv pkg-config dev --liblua --path-style windows') do set LUA_LIB=%%i

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
