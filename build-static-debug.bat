@echo off
setlocal enabledelayedexpansion

REM ====================================================================
REM build-static-debug.bat [INSTALL_DIR]
REM
REM Arguments:
REM   INSTALL_DIR (optional) - Path to installation directory
REM
REM If INSTALL_DIR is not provided as an argument, the script will prompt
REM the user for input. If no input is provided, defaults to "lua_debug".
REM
REM Examples:
REM   build-static-debug.bat
REM   build-static-debug.bat C:\lua_debug
REM   build-static-debug.bat lua_debug
REM
REM This script builds Lua 5.4.8 as a static library with debug symbols
REM and creates the necessary executables. It should be run from a Visual
REM Studio Developer Command Prompt. If the build is successful, it will
REM automatically install Lua to the specified directory.
REM ====================================================================

echo ====================================================================
echo Building Lua 5.4.8 - Static Debug Build with Auto-Install
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
    set /p INSTALL_DIR="Enter install directory (default: lua_debug): "
    if "!INSTALL_DIR!"=="" set "INSTALL_DIR=lua_debug"
) else (
    REM Use command line argument
    set "INSTALL_DIR=%~1"
    echo Using installation directory from argument: !INSTALL_DIR!
)

echo Installation will be done to: !INSTALL_DIR!
echo.

rem Create output directory
if not exist "Debug" mkdir "Debug"

rem Set debug compile flags
set "CFLAGS=/Od /MDd /W3 /Zi /DLUA_COMPAT_5_3 /D_DEBUG"
set "LINKFLAGS=/DEBUG /INCREMENTAL:NO"

rem Clean previous build
echo Cleaning previous debug build...
if exist "Debug\*.obj" del /q "Debug\*.obj"
if exist "Debug\*.exe" del /q "Debug\*.exe"
if exist "Debug\*.lib" del /q "Debug\*.lib"
if exist "Debug\*.pdb" del /q "Debug\*.pdb"
if exist "Debug\*.ilk" del /q "Debug\*.ilk"

echo.
echo Compiling Lua library source files (Debug mode)...

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
echo Creating static debug library...
lib /OUT:Debug\lua54d.lib Debug\lapi.obj Debug\lcode.obj Debug\lctype.obj Debug\ldebug.obj Debug\ldo.obj Debug\ldump.obj Debug\lfunc.obj Debug\lgc.obj Debug\llex.obj Debug\lmem.obj Debug\lobject.obj Debug\lopcodes.obj Debug\lparser.obj Debug\lstate.obj Debug\lstring.obj Debug\ltable.obj Debug\ltm.obj Debug\lundump.obj Debug\lvm.obj Debug\lzio.obj Debug\lauxlib.obj Debug\lbaselib.obj Debug\lcorolib.obj Debug\ldblib.obj Debug\liolib.obj Debug\lmathlib.obj Debug\loadlib.obj Debug\loslib.obj Debug\lstrlib.obj Debug\ltablib.obj Debug\lutf8lib.obj Debug\linit.obj

echo.
echo Compiling and linking debug executables...
echo   lua_debug.exe...
cl /c %CFLAGS% /FoDebug\lua.obj lua.c
link /OUT:Debug\lua_debug.exe %LINKFLAGS% Debug\lua.obj Debug\lua54d.lib

echo   luac_debug.exe...
cl /c %CFLAGS% /FoDebug\luac.obj luac.c
link /OUT:Debug\luac_debug.exe %LINKFLAGS% Debug\luac.obj Debug\lapi.obj Debug\lcode.obj Debug\lctype.obj Debug\ldebug.obj Debug\ldo.obj Debug\ldump.obj Debug\lfunc.obj Debug\lgc.obj Debug\llex.obj Debug\lmem.obj Debug\lobject.obj Debug\lopcodes.obj Debug\lparser.obj Debug\lstate.obj Debug\lstring.obj Debug\ltable.obj Debug\ltm.obj Debug\lundump.obj Debug\lvm.obj Debug\lzio.obj Debug\lauxlib.obj Debug\lbaselib.obj Debug\lcorolib.obj Debug\ldblib.obj Debug\liolib.obj Debug\lmathlib.obj Debug\loadlib.obj Debug\loslib.obj Debug\lstrlib.obj Debug\ltablib.obj Debug\lutf8lib.obj Debug\linit.obj

if %ERRORLEVEL% neq 0 (
    echo.
    echo ? Debug build failed with error %ERRORLEVEL%
    pause
    exit /b %ERRORLEVEL%
)

echo.
echo ====================================================================
echo ? DEBUG BUILD SUCCESSFUL!
echo ====================================================================
echo.
echo Static debug build completed successfully!
echo Built files:
echo   Debug\lua_debug.exe  - Lua interpreter with debug symbols
echo   Debug\luac_debug.exe - Lua compiler with debug symbols
echo   Debug\lua54d.lib     - Lua static debug library
echo   Debug\*.pdb          - Program database files (debug symbols)
echo.

echo Testing debug executables...
Debug\lua_debug.exe -v
Debug\luac_debug.exe -v

echo.
echo All tests passed! Debug build is ready for debugging.

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

copy "Debug\lua_debug.exe" "!INSTALL_DIR!\bin\"
copy "Debug\luac_debug.exe" "!INSTALL_DIR!\bin\"
copy "Debug\lua54d.lib" "!INSTALL_DIR!\lib\"
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
echo ? DEBUG INSTALLATION COMPLETE!
echo ====================================================================
echo.
echo Lua Debug Build has been installed to: !INSTALL_DIR!
echo   Binaries: !INSTALL_DIR!\bin
echo   Headers:  !INSTALL_DIR!\include
echo   Library:  !INSTALL_DIR!\lib
echo   Docs:     !INSTALL_DIR!\doc
echo.
echo To use Lua Debug, add !INSTALL_DIR!\bin to your PATH environment variable.
echo.
echo Lua 5.4.8 Static Debug Build - Usage Instructions
echo ==================================================
echo.
echo Installation Directory: !INSTALL_DIR!
echo Build Date: %DATE% %TIME%
echo Build Type: DEBUG (with debug symbols)
echo.
echo Directory Structure:
echo   bin/        - Executable files ^(lua_debug.exe, luac_debug.exe^) + PDB files
echo   include/    - Header files for C/C++ development
echo   lib/        - Static debug library ^(lua54d.lib^)
echo   doc/        - Documentation
echo.
echo Usage:
echo   1. Add !INSTALL_DIR!\bin to your PATH environment variable
echo   2. Run 'lua_debug' to start the Lua interpreter with debug symbols
echo   3. Run 'luac_debug' to compile Lua scripts with debug info
echo.
echo For C/C++ Development:
echo   - Include headers from: !INSTALL_DIR!\include
echo   - Link against: !INSTALL_DIR!\lib\lua54d.lib ^(debug version^)
echo   - Use with debugger: PDB files are available in bin/
echo.
echo Examples:
echo   lua_debug script.lua                     # Run a Lua script ^(debuggable^)
echo   luac_debug -o script.luac script.lua     # Compile with debug info
echo   lua_debug -i                             # Interactive mode ^(debuggable^)
echo.
echo Debugging Features:
echo   - Full debug symbols ^(.pdb files^)
echo   - Unoptimized code ^(/Od^) for better debugging experience
echo   - Debug runtime ^(/MDd^) for memory debugging
echo   - _DEBUG preprocessor definition
echo.
echo The debug library ^(lua54d.lib^) should be used when developing
echo and debugging C applications that embed Lua. Switch to the release
echo version ^(lua54.lib^) for production builds.
echo.

echo.
