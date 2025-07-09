@echo off
setlocal enabledelayedexpansion

rem ====================================================================
rem build-dll.bat
rem This script builds Lua 5.4.8 as a DLL and creates the necessary executables.
rem It should be run from a Visual Studio Developer Command Prompt.
rem ====================================================================

echo ====================================================================
echo Building Lua 5.4.8 - Manual DLL Build
echo ====================================================================
echo.

rem Check if we're in a VS developer command prompt
if not defined VCINSTALLDIR (
    echo ERROR: Visual Studio environment not detected.
    echo Please run this script from a Visual Studio Developer Command Prompt.
    echo.
    exit /b 1
)

rem Display current environment
echo Visual Studio Environment: %VCINSTALLDIR%
echo Architecture: %VSCMD_ARG_TGT_ARCH%
echo.

rem Create output directory
if not exist "Release" mkdir "Release"

rem Set common compile flags for DLL build
REM For backwards compatibility with old lua versions add to the CFLAGS: /DLUA_COMPAT_5_3 /DLUA_COMPAT_5_2 /DLUA_COMPAT_5_1
set "CFLAGS=/O2 /MD /W4 /DNDEBUG /DLUA_BUILD_AS_DLL"
set "LINKFLAGS=/RELEASE  /INCREMENTAL:NO /DLL /NODEFAULTLIB:libcmt.lib /NODEFAULTLIB:libcmtd.lib /NODEFAULTLIB:msvcrtd.lib"

rem Clean previous build
echo Cleaning previous build...
if exist "Release\*.obj" del /q "Release\*.obj"
if exist "Release\*.exe" del /q "Release\*.exe"
if exist "Release\*.lib" del /q "Release\*.lib"
if exist "Release\*.dll" del /q "Release\*.dll"
if exist "Release\*.pdb" del /q "Release\*.pdb"
if exist "Release\*.exp" del /q "Release\*.exp"

echo.
echo Compiling Lua library source files for DLL...

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
echo Creating DLL and import library...
link /OUT:Release\lua54.dll %LINKFLAGS% /IMPLIB:Release\lua54.lib Release\lapi.obj Release\lcode.obj Release\lctype.obj Release\ldebug.obj Release\ldo.obj Release\ldump.obj Release\lfunc.obj Release\lgc.obj Release\llex.obj Release\lmem.obj Release\lobject.obj Release\lopcodes.obj Release\lparser.obj Release\lstate.obj Release\lstring.obj Release\ltable.obj Release\ltm.obj Release\lundump.obj Release\lvm.obj Release\lzio.obj Release\lauxlib.obj Release\lbaselib.obj Release\lcorolib.obj Release\ldblib.obj Release\liolib.obj Release\lmathlib.obj Release\loadlib.obj Release\loslib.obj Release\lstrlib.obj Release\ltablib.obj Release\lutf8lib.obj Release\linit.obj

if %ERRORLEVEL% neq 0 (
    echo.
    echo [ERROR] DLL creation failed with error %ERRORLEVEL%
    exit /b %ERRORLEVEL%
)

echo.
echo Compiling and linking executables...

rem Lua interpreter (links to DLL)
echo   lua.exe (using DLL)...
cl /c %CFLAGS% /FoRelease\lua.obj lua.c
link /OUT:Release\lua.exe /RELEASE /INCREMENTAL:NO Release\lua.obj Release\lua54.lib

if %ERRORLEVEL% neq 0 (
    echo.
    echo [ERROR] lua.exe linking failed with error %ERRORLEVEL%
    exit /b %ERRORLEVEL%
)

rem Lua compiler (statically linked)
echo   luac.exe (static)...
set "CFLAGS_STATIC=/O2 /MT /W3 /DLUA_COMPAT_5_3 /DNDEBUG"
cl /c %CFLAGS_STATIC% /FoRelease\luac.obj luac.c

rem For luac, we need to compile the core files again without DLL flags
echo   Compiling core files for static luac...
cl /c %CFLAGS_STATIC% /FoRelease\luac_lapi.obj lapi.c
cl /c %CFLAGS_STATIC% /Os /FoRelease\luac_lcode.obj lcode.c
cl /c %CFLAGS_STATIC% /FoRelease\luac_lctype.obj lctype.c
cl /c %CFLAGS_STATIC% /FoRelease\luac_ldebug.obj ldebug.c
cl /c %CFLAGS_STATIC% /FoRelease\luac_ldo.obj ldo.c
cl /c %CFLAGS_STATIC% /FoRelease\luac_ldump.obj ldump.c
cl /c %CFLAGS_STATIC% /FoRelease\luac_lfunc.obj lfunc.c
cl /c %CFLAGS_STATIC% /FoRelease\luac_lgc.obj lgc.c
cl /c %CFLAGS_STATIC% /Os /FoRelease\luac_llex.obj llex.c
cl /c %CFLAGS_STATIC% /FoRelease\luac_lmem.obj lmem.c
cl /c %CFLAGS_STATIC% /FoRelease\luac_lobject.obj lobject.c
cl /c %CFLAGS_STATIC% /FoRelease\luac_lopcodes.obj lopcodes.c
cl /c %CFLAGS_STATIC% /Os /FoRelease\luac_lparser.obj lparser.c
cl /c %CFLAGS_STATIC% /FoRelease\luac_lstate.obj lstate.c
cl /c %CFLAGS_STATIC% /FoRelease\luac_lstring.obj lstring.c
cl /c %CFLAGS_STATIC% /FoRelease\luac_ltable.obj ltable.c
cl /c %CFLAGS_STATIC% /FoRelease\luac_ltm.obj ltm.c
cl /c %CFLAGS_STATIC% /FoRelease\luac_lundump.obj lundump.c
cl /c %CFLAGS_STATIC% /FoRelease\luac_lvm.obj lvm.c
cl /c %CFLAGS_STATIC% /FoRelease\luac_lzio.obj lzio.c
cl /c %CFLAGS_STATIC% /FoRelease\luac_lauxlib.obj lauxlib.c

link /OUT:Release\luac.exe /RELEASE /INCREMENTAL:NO Release\luac.obj Release\luac_lapi.obj Release\luac_lcode.obj Release\luac_lctype.obj Release\luac_ldebug.obj Release\luac_ldo.obj Release\luac_ldump.obj Release\luac_lfunc.obj Release\luac_lgc.obj Release\luac_llex.obj Release\luac_lmem.obj Release\luac_lobject.obj Release\luac_lopcodes.obj Release\luac_lparser.obj Release\luac_lstate.obj Release\luac_lstring.obj Release\luac_ltable.obj Release\luac_ltm.obj Release\luac_lundump.obj Release\luac_lvm.obj Release\luac_lzio.obj Release\luac_lauxlib.obj

if %ERRORLEVEL% neq 0 (
    echo.
    echo [ERROR] luac.exe linking failed with error %ERRORLEVEL%
    exit /b %ERRORLEVEL%
)

echo.
echo ====================================================================
echo [OK] DLL BUILD SUCCESSFUL!
echo ====================================================================
echo.
echo DLL build completed successfully!
echo Built files:
echo   Release\lua54.dll   - Lua dynamic library
echo   Release\lua54.lib   - Import library for linking
echo   Release\lua.exe     - Lua interpreter (uses DLL)
echo   Release\luac.exe    - Lua compiler (static)
echo.

echo Testing executables...
Release\lua.exe -v
Release\luac.exe -v

echo.
echo ====================================================================
echo Building Lua 5.4.8 - Manual DLL Build - COMPLETED
echo ====================================================================
echo.
