@echo off
setlocal enabledelayedexpansion

REM ====================================================================
REM build-dll-debug.bat [INSTALL_DIR]
REM
REM Arguments:
REM   INSTALL_DIR (optional) - Path to installation directory
REM
REM If INSTALL_DIR is not provided as an argument, the script will prompt
REM the user for input. If no input is provided, defaults to "lua_debug_dll".
REM
REM Examples:
REM   build-dll-debug.bat
REM   build-dll-debug.bat C:\lua_debug_dll
REM   build-dll-debug.bat lua_debug_dll
REM
REM This script builds Lua 5.4.8 as a DLL with debug symbols
REM and creates the necessary executables. It should be run from a Visual
REM Studio Developer Command Prompt. If the build is successful, it will
REM automatically install Lua to the specified directory.
REM ====================================================================

echo ====================================================================
echo Building Lua 5.4.X - DLL Debug Build with Auto-Install
echo ====================================================================
echo.

rem Check if we're in a VS developer command prompt
if not defined VCINSTALLDIR (
    echo ERROR: Visual Studio environment not detected.
    echo Please run this script from a Visual Studio Developer Command Prompt.
    echo.
    pause
    exit /b 1
)

rem Display current environment
echo Visual Studio Environment: %VCINSTALLDIR%
echo Architecture: %VSCMD_ARG_TGT_ARCH%
echo.

rem Get the installation directory
rem Check if command line argument was provided
if "%~1"=="" (
    REM No argument provided, ask user
    set /p INSTALL_DIR="Enter install directory (default: lua_debug_dll): "
    if "!INSTALL_DIR!"=="" set "INSTALL_DIR=lua_debug_dll"
) else (
    REM Use command line argument
    set "INSTALL_DIR=%~1"
    echo Using installation directory from argument: !INSTALL_DIR!
)

echo Installation will be done to: !INSTALL_DIR!
echo.

rem Create output directory
if not exist "Debug" mkdir "Debug"

rem Set debug compile flags for DLL
set "CFLAGS=/Od /MDd /W3 /Zi /DLUA_COMPAT_5_3 /D_DEBUG /DLUA_BUILD_AS_DLL"
set "LINKFLAGS=/DEBUG /INCREMENTAL:NO /DLL"

rem Clean previous build
echo Cleaning previous debug DLL build...
if exist "Debug\*.obj" del /q "Debug\*.obj"
if exist "Debug\*.exe" del /q "Debug\*.exe"
if exist "Debug\*.dll" del /q "Debug\*.dll"
if exist "Debug\*.lib" del /q "Debug\*.lib"
if exist "Debug\*.pdb" del /q "Debug\*.pdb"
if exist "Debug\*.ilk" del /q "Debug\*.ilk"
if exist "Debug\*.exp" del /q "Debug\*.exp"

echo.
echo Compiling Lua library source files (Debug DLL mode)...

rem Core files
echo   Core files...
cl /c %CFLAGS% /FoDebug\lapi.obj lapi.c
cl /c %CFLAGS% /FoDebug\lcode.obj lcode.c
cl /c %CFLAGS% /FoDebug\lctype.obj lctype.c
cl /c %CFLAGS% /FoDebug\ldebug.obj ldebug.c
cl /c %CFLAGS% /FoDebug\ldo.obj ldo.c
cl /c %CFLAGS% /FoDebug\ldump.obj ldump.c
cl /c %CFLAGS% /FoDebug\lfunc.obj lfunc.c
cl /c %CFLAGS% /FoDebug\lgc.obj lgc.c
cl /c %CFLAGS% /FoDebug\llex.obj llex.c
cl /c %CFLAGS% /FoDebug\lmem.obj lmem.c
cl /c %CFLAGS% /FoDebug\lobject.obj lobject.c
cl /c %CFLAGS% /FoDebug\lopcodes.obj lopcodes.c
cl /c %CFLAGS% /FoDebug\lparser.obj lparser.c
cl /c %CFLAGS% /FoDebug\lstate.obj lstate.c
cl /c %CFLAGS% /FoDebug\lstring.obj lstring.c
cl /c %CFLAGS% /FoDebug\ltable.obj ltable.c
cl /c %CFLAGS% /FoDebug\ltm.obj ltm.c
cl /c %CFLAGS% /FoDebug\lundump.obj lundump.c
cl /c %CFLAGS% /FoDebug\lvm.obj lvm.c
cl /c %CFLAGS% /FoDebug\lzio.obj lzio.c

rem Library files
echo   Library files...
cl /c %CFLAGS% /FoDebug\lauxlib.obj lauxlib.c
cl /c %CFLAGS% /FoDebug\lbaselib.obj lbaselib.c
cl /c %CFLAGS% /FoDebug\lcorolib.obj lcorolib.c
cl /c %CFLAGS% /FoDebug\ldblib.obj ldblib.c
cl /c %CFLAGS% /FoDebug\liolib.obj liolib.c
cl /c %CFLAGS% /FoDebug\lmathlib.obj lmathlib.c
cl /c %CFLAGS% /FoDebug\loadlib.obj loadlib.c
cl /c %CFLAGS% /FoDebug\loslib.obj loslib.c
cl /c %CFLAGS% /FoDebug\lstrlib.obj lstrlib.c
cl /c %CFLAGS% /FoDebug\ltablib.obj ltablib.c
cl /c %CFLAGS% /FoDebug\lutf8lib.obj lutf8lib.c
cl /c %CFLAGS% /FoDebug\linit.obj linit.c

echo.
echo Creating debug DLL...
link /OUT:Debug\lua54.dll %LINKFLAGS% /IMPLIB:Debug\lua54.lib Debug\lapi.obj Debug\lcode.obj Debug\lctype.obj Debug\ldebug.obj Debug\ldo.obj Debug\ldump.obj Debug\lfunc.obj Debug\lgc.obj Debug\llex.obj Debug\lmem.obj Debug\lobject.obj Debug\lopcodes.obj Debug\lparser.obj Debug\lstate.obj Debug\lstring.obj Debug\ltable.obj Debug\ltm.obj Debug\lundump.obj Debug\lvm.obj Debug\lzio.obj Debug\lauxlib.obj Debug\lbaselib.obj Debug\lcorolib.obj Debug\ldblib.obj Debug\liolib.obj Debug\lmathlib.obj Debug\loadlib.obj Debug\loslib.obj Debug\lstrlib.obj Debug\ltablib.obj Debug\lutf8lib.obj Debug\linit.obj

echo.
echo Compiling and linking debug executables...
echo   lua.exe...
cl /c %CFLAGS% /FoDebug\lua.obj lua.c
link /OUT:Debug\lua.exe /DEBUG /INCREMENTAL:NO Debug\lua.obj Debug\lua54.lib

echo   luac.exe...
cl /c %CFLAGS% /FoDebug\luac.obj luac.c
link /OUT:Debug\luac.exe /DEBUG /INCREMENTAL:NO Debug\luac.obj Debug\lapi.obj Debug\lcode.obj Debug\lctype.obj Debug\ldebug.obj Debug\ldo.obj Debug\ldump.obj Debug\lfunc.obj Debug\lgc.obj Debug\llex.obj Debug\lmem.obj Debug\lobject.obj Debug\lopcodes.obj Debug\lparser.obj Debug\lstate.obj Debug\lstring.obj Debug\ltable.obj Debug\ltm.obj Debug\lundump.obj Debug\lvm.obj Debug\lzio.obj Debug\lauxlib.obj Debug\lbaselib.obj Debug\lcorolib.obj Debug\ldblib.obj Debug\liolib.obj Debug\lmathlib.obj Debug\loadlib.obj Debug\loslib.obj Debug\lstrlib.obj Debug\ltablib.obj Debug\lutf8lib.obj Debug\linit.obj

if %ERRORLEVEL% neq 0 (
    echo.
    echo ? Debug DLL build failed with error %ERRORLEVEL%
    pause
    exit /b %ERRORLEVEL%
)

echo.
echo ====================================================================
echo ? DEBUG DLL BUILD SUCCESSFUL!
echo ====================================================================
echo.
echo Debug DLL build completed successfully!
echo Built files:
echo   Debug\lua.exe     - Lua interpreter with debug symbols
echo   Debug\luac.exe    - Lua compiler with debug symbols
echo   Debug\lua54.dll   - Lua debug DLL
echo   Debug\lua54.lib   - Import library for debug DLL
echo   Debug\*.pdb       - Program database files (debug symbols)
echo.

echo Testing debug executables...
Debug\lua.exe -v
Debug\luac.exe -v

echo.
echo All tests passed! Debug DLL build is ready for debugging.

echo.
echo Installing to !INSTALL_DIR!...

REM Convert to absolute path if it's relative
if not "!INSTALL_DIR:~1,1!"==":" (
    set "INSTALL_DIR=%CD%\!INSTALL_DIR!"
)

if not exist "!INSTALL_DIR!" mkdir "!INSTALL_DIR!"
if not exist "!INSTALL_DIR!\bin" mkdir "!INSTALL_DIR!\bin"
if not exist "!INSTALL_DIR!\include" mkdir "!INSTALL_DIR!\include"
if not exist "!INSTALL_DIR!\lib" mkdir "!INSTALL_DIR!\lib"
if not exist "!INSTALL_DIR!\doc" mkdir "!INSTALL_DIR!\doc"

copy "Debug\lua.exe" "!INSTALL_DIR!\bin\"
copy "Debug\luac.exe" "!INSTALL_DIR!\bin\"
copy "Debug\lua54.dll" "!INSTALL_DIR!\bin\"
copy "Debug\lua54.lib" "!INSTALL_DIR!\lib\"
copy "Debug\*.pdb" "!INSTALL_DIR!\bin\"

copy "lua.h" "!INSTALL_DIR!\include\"
copy "luaconf.h" "!INSTALL_DIR!\include\"
copy "lualib.h" "!INSTALL_DIR!\include\"
copy "lauxlib.h" "!INSTALL_DIR!\include\"
copy "lua.hpp" "!INSTALL_DIR!\include\"

if exist "..\README" copy "..\README" "!INSTALL_DIR!\doc\"
if exist "..\doc\*.html" copy "..\doc\*.html" "!INSTALL_DIR!\doc\"
if exist "..\doc\*.css" copy "..\doc\*.css" "!INSTALL_DIR!\doc\"

echo.
echo ====================================================================
echo ? DEBUG DLL INSTALLATION COMPLETE!
echo ====================================================================
echo.
echo Lua Debug DLL Build has been installed to: !INSTALL_DIR!
echo   Binaries: !INSTALL_DIR!\bin
echo   Headers:  !INSTALL_DIR!\include
echo   Library:  !INSTALL_DIR!\lib
echo   Docs:     !INSTALL_DIR!\doc
echo.
echo To use Lua Debug DLL, add !INSTALL_DIR!\bin to your PATH environment variable.
echo.
echo Lua 5.4.8 Debug DLL Build - Usage Instructions
echo ===============================================
echo.
echo Installation Directory: !INSTALL_DIR!
echo Build Date: %DATE% %TIME%
echo Build Type: DEBUG DLL (with debug symbols)
echo.
echo Directory Structure:
echo   bin/        - Executable and DLL files ^(lua.exe, luac.exe, lua54.dll^) + PDB files
echo   include/    - Header files for C/C++ development
echo   lib/        - Import library ^(lua54.lib^)
echo   doc/        - Documentation
echo.
echo Usage:
echo   1. Add !INSTALL_DIR!\bin to your PATH environment variable
echo   2. Run 'lua' to start the Lua interpreter with debug symbols
echo   3. Run 'luac' to compile Lua scripts with debug info
echo.
echo For C/C++ Development:
echo   - Include headers from: !INSTALL_DIR!\include
echo   - Link against: !INSTALL_DIR!\lib\lua54.lib ^(debug import library^)
echo   - Ensure lua54.dll is in PATH or same directory as your executable
echo   - Use with debugger: PDB files are available in bin/
echo.
echo Examples:
echo   lua script.lua                     # Run a Lua script ^(debuggable^)
echo   luac -o script.luac script.lua     # Compile with debug info
echo   lua -i                             # Interactive mode ^(debuggable^)
echo.
echo Debugging Features:
echo   - Full debug symbols ^(.pdb files^)
echo   - Unoptimized code ^(/Od^) for better debugging experience
echo   - Debug runtime ^(/MDd^) for memory debugging
echo   - _DEBUG preprocessor definition
echo   - DLL build for easier debugging and smaller executables
echo.
echo The debug DLL ^(lua54.dll^) and import library ^(lua54.lib^) should be used
echo when developing and debugging C applications that embed Lua. Switch to the
echo release version for production builds.
echo.

echo.
