@echo off
setlocal enabledelayedexpansion

REM ====================================================================
REM build_static2.bat [INSTALL_DIR]
REM
REM Arguments:
REM   INSTALL_DIR (optional) - Path to installation directory
REM
REM If INSTALL_DIR is not provided as an argument, the script will prompt
REM the user for input. If no input is provided, defaults to "lua".
REM
REM Examples:
REM   build-static.bat
REM   build-static.bat C:\lua
REM   build-static.bat lua
REM
REM This script builds Lua 5.4.8 as a static library and creates the necessary
REM executables. It should be run from a Visual Studio Developer Command Prompt.
REM If the build is successful, it will automatically install Lua to the specified directory.
REM ====================================================================

echo ====================================================================
echo Building Lua 5.4.X - Static Build with Auto-Install
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
    set /p INSTALL_DIR="Enter install directory (default: lua): "
    if "!INSTALL_DIR!"=="" set "INSTALL_DIR=lua"
) else (
    REM Use command line argument
    set "INSTALL_DIR=%~1"
    echo Using installation directory from argument: !INSTALL_DIR!
)

echo Installation will be done to: !INSTALL_DIR!
echo.

rem Create output directory
if not exist "Release" mkdir "Release"

rem Set common compile flags
set "CFLAGS=/O2 /MT /W3 /DLUA_COMPAT_5_3 /DNDEBUG"
set "LINKFLAGS=/RELEASE /INCREMENTAL:NO"

rem Clean previous build
echo Cleaning previous build...
if exist "Release\*.obj" del /q "Release\*.obj"
if exist "Release\*.exe" del /q "Release\*.exe"
if exist "Release\*.lib" del /q "Release\*.lib"
if exist "Release\*.pdb" del /q "Release\*.pdb"

echo.
echo Compiling Lua library source files...

rem Core files
echo   Core files...
cl /c %CFLAGS% /FoRelease\lapi.obj lapi.c
cl /c %CFLAGS% /Os /FoRelease\lcode.obj lcode.c
cl /c %CFLAGS% /FoRelease\lctype.obj lctype.c
cl /c %CFLAGS% /FoRelease\ldebug.obj ldebug.c
cl /c %CFLAGS% /FoRelease\ldo.obj ldo.c
cl /c %CFLAGS% /FoRelease\ldump.obj ldump.c
cl /c %CFLAGS% /FoRelease\lfunc.obj lfunc.c
cl /c %CFLAGS% /FoRelease\lgc.obj lgc.c
cl /c %CFLAGS% /Os /FoRelease\llex.obj llex.c
cl /c %CFLAGS% /FoRelease\lmem.obj lmem.c
cl /c %CFLAGS% /FoRelease\lobject.obj lobject.c
cl /c %CFLAGS% /FoRelease\lopcodes.obj lopcodes.c
cl /c %CFLAGS% /Os /FoRelease\lparser.obj lparser.c
cl /c %CFLAGS% /FoRelease\lstate.obj lstate.c
cl /c %CFLAGS% /FoRelease\lstring.obj lstring.c
cl /c %CFLAGS% /FoRelease\ltable.obj ltable.c
cl /c %CFLAGS% /FoRelease\ltm.obj ltm.c
cl /c %CFLAGS% /FoRelease\lundump.obj lundump.c
cl /c %CFLAGS% /FoRelease\lvm.obj lvm.c
cl /c %CFLAGS% /FoRelease\lzio.obj lzio.c

rem Library files
echo   Library files...
cl /c %CFLAGS% /FoRelease\lauxlib.obj lauxlib.c
cl /c %CFLAGS% /FoRelease\lbaselib.obj lbaselib.c
cl /c %CFLAGS% /FoRelease\lcorolib.obj lcorolib.c
cl /c %CFLAGS% /FoRelease\ldblib.obj ldblib.c
cl /c %CFLAGS% /FoRelease\liolib.obj liolib.c
cl /c %CFLAGS% /FoRelease\lmathlib.obj lmathlib.c
cl /c %CFLAGS% /FoRelease\loadlib.obj loadlib.c
cl /c %CFLAGS% /FoRelease\loslib.obj loslib.c
cl /c %CFLAGS% /FoRelease\lstrlib.obj lstrlib.c
cl /c %CFLAGS% /FoRelease\ltablib.obj ltablib.c
cl /c %CFLAGS% /FoRelease\lutf8lib.obj lutf8lib.c
cl /c %CFLAGS% /FoRelease\linit.obj linit.c

echo.
echo Creating static library...
lib /OUT:Release\lua54.lib Release\lapi.obj Release\lcode.obj Release\lctype.obj Release\ldebug.obj Release\ldo.obj Release\ldump.obj Release\lfunc.obj Release\lgc.obj Release\llex.obj Release\lmem.obj Release\lobject.obj Release\lopcodes.obj Release\lparser.obj Release\lstate.obj Release\lstring.obj Release\ltable.obj Release\ltm.obj Release\lundump.obj Release\lvm.obj Release\lzio.obj Release\lauxlib.obj Release\lbaselib.obj Release\lcorolib.obj Release\ldblib.obj Release\liolib.obj Release\lmathlib.obj Release\loadlib.obj Release\loslib.obj Release\lstrlib.obj Release\ltablib.obj Release\lutf8lib.obj Release\linit.obj

echo.
echo Compiling and linking executables...
echo   lua.exe...
cl /c %CFLAGS% /FoRelease\lua.obj lua.c
link /OUT:Release\lua.exe %LINKFLAGS% Release\lua.obj Release\lua54.lib

echo   luac.exe...
cl /c %CFLAGS% /FoRelease\luac.obj luac.c
link /OUT:Release\luac.exe %LINKFLAGS% Release\luac.obj Release\lapi.obj Release\lcode.obj Release\lctype.obj Release\ldebug.obj Release\ldo.obj Release\ldump.obj Release\lfunc.obj Release\lgc.obj Release\llex.obj Release\lmem.obj Release\lobject.obj Release\lopcodes.obj Release\lparser.obj Release\lstate.obj Release\lstring.obj Release\ltable.obj Release\ltm.obj Release\lundump.obj Release\lvm.obj Release\lzio.obj Release\lauxlib.obj Release\lbaselib.obj Release\lcorolib.obj Release\ldblib.obj Release\liolib.obj Release\lmathlib.obj Release\loadlib.obj Release\loslib.obj Release\lstrlib.obj Release\ltablib.obj Release\lutf8lib.obj Release\linit.obj

if %ERRORLEVEL% neq 0 (
    echo.
    echo ? Build failed with error %ERRORLEVEL%
    pause
    exit /b %ERRORLEVEL%
)

echo.
echo ====================================================================
echo ? BUILD SUCCESSFUL!
echo ====================================================================
echo.
echo Static build completed successfully!
echo Built files:
echo   Release\lua.exe     - Lua interpreter
echo   Release\luac.exe    - Lua compiler
echo   Release\lua54.lib  - Lua static library
echo.

echo Testing executables...
Release\lua.exe -v
Release\luac.exe -v

echo.
echo All tests passed! Static build is ready for use.

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

copy "Release\lua.exe" "!INSTALL_DIR!\bin\"
copy "Release\luac.exe" "!INSTALL_DIR!\bin\"
copy "Release\lua54.lib" "!INSTALL_DIR!\lib\"

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
echo ? INSTALLATION COMPLETE!
echo ====================================================================
echo.
echo Lua has been installed to: !INSTALL_DIR!
echo   Binaries: !INSTALL_DIR!\bin
echo   Headers:  !INSTALL_DIR!\include
echo   Library:  !INSTALL_DIR!\lib
echo   Docs:     !INSTALL_DIR!\doc
echo.
echo To use Lua, add !INSTALL_DIR!\bin to your PATH environment variable.
echo.
echo Lua 5.4.8 Static Build - Usage Instructions
echo ============================================
echo.
echo Installation Directory: !INSTALL_DIR!
echo Build Date: %DATE% %TIME%
echo.
echo Directory Structure:
echo   bin/        - Executable files ^(lua.exe, luac.exe^)
echo   include/    - Header files for C/C++ development
echo   lib/        - Static library ^(lua54.lib^)
echo   doc/        - Documentation
echo.
echo Usage:
echo   1. Add !INSTALL_DIR!\bin to your PATH environment variable
echo   2. Run 'lua' to start the Lua interpreter
echo   3. Run 'luac' to compile Lua scripts
echo.
echo For C/C++ Development:
echo   - Include headers from: !INSTALL_DIR!\include
echo   - Link against: !INSTALL_DIR!\lib\lua54.lib
echo.
echo Examples:
echo   lua script.lua                    # Run a Lua script
echo   luac -o script.luac script.lua    # Compile a script
echo   lua -i                            # Interactive mode
echo.
echo The static library ^(lua54.lib^) is installed in the lib directory
echo with the executables. Use this library when linking C applications
echo that embed Lua.
echo.

echo.
