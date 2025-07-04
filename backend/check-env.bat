@echo off
setlocal enabledelayedexpansion
REM Diagnostic script for Lua build environment
REM Run this to check if your Visual Studio environment is properly set up
REM Returns: EXIT_CODE 0 if environment is OK, 1 if there are issues

set "ENV_OK=1"
set "ISSUES_FOUND="

REM Check if we should run in quiet mode (for programmatic use)
if "%1"=="--quiet" (
    set "QUIET_MODE=1"
) else (
    set "QUIET_MODE=0"
)

if %QUIET_MODE%==0 (
    echo Lua Build Environment Diagnostics
    echo ==================================
    echo.
    echo Checking Visual Studio environment variables...
)
if defined VCINSTALLDIR (
    if %QUIET_MODE%==0 echo [OK] VCINSTALLDIR = "%VCINSTALLDIR%"
) else (
    if %QUIET_MODE%==0 echo [ERROR] VCINSTALLDIR not set
    set "ENV_OK=0"
    set "ISSUES_FOUND=!ISSUES_FOUND!VCINSTALLDIR_MISSING;"
)

if defined VSCMD_ARG_TGT_ARCH (
    if %QUIET_MODE%==0 echo [OK] Target Architecture = %VSCMD_ARG_TGT_ARCH%
) else (
    if %QUIET_MODE%==0 echo [ERROR] Target Architecture not detected
    set "ENV_OK=0"
    set "ISSUES_FOUND=!ISSUES_FOUND!TARGET_ARCH_MISSING;"
)

if defined WindowsSdkDir (
    if %QUIET_MODE%==0 echo [OK] WindowsSdkDir = "%WindowsSdkDir%"
) else (
    if %QUIET_MODE%==0 echo [ERROR] WindowsSdkDir not set
    set "ENV_OK=0"
    set "ISSUES_FOUND=!ISSUES_FOUND!WINDOWS_SDK_MISSING;"
)

if defined WindowsSDKVersion (
    if %QUIET_MODE%==0 echo [OK] WindowsSDKVersion = "%WindowsSDKVersion%"
) else (
    if %QUIET_MODE%==0 echo [ERROR] WindowsSDKVersion not set
    set "ENV_OK=0"
    set "ISSUES_FOUND=!ISSUES_FOUND!WINDOWS_SDK_VERSION_MISSING;"
)

if %QUIET_MODE%==0 (
    echo.
    echo Checking for required tools...
)

where cl.exe >nul 2>&1
if !ERRORLEVEL! equ 0 (
    if %QUIET_MODE%==0 echo [OK] cl.exe ^(C compiler^) found in PATH
) else (
    if %QUIET_MODE%==0 echo [ERROR] cl.exe ^(C compiler^) not found in PATH
    set "ENV_OK=0"
    set "ISSUES_FOUND=!ISSUES_FOUND!CL_EXE_MISSING;"
)

where link.exe >nul 2>&1
if !ERRORLEVEL! equ 0 (
    if %QUIET_MODE%==0 echo [OK] link.exe ^(Linker^) found in PATH
) else (
    if %QUIET_MODE%==0 echo [ERROR] link.exe ^(Linker^) not found in PATH
    set "ENV_OK=0"
    set "ISSUES_FOUND=!ISSUES_FOUND!LINK_EXE_MISSING;"
)

where lib.exe >nul 2>&1
if !ERRORLEVEL! equ 0 (
    if %QUIET_MODE%==0 echo [OK] lib.exe ^(Librarian^) found in PATH
) else (
    if %QUIET_MODE%==0 echo [ERROR] lib.exe ^(Librarian^) not found in PATH
    set "ENV_OK=0"
    set "ISSUES_FOUND=!ISSUES_FOUND!LIB_EXE_MISSING;"
)

where nmake.exe >nul 2>&1
if !ERRORLEVEL! equ 0 (
    if %QUIET_MODE%==0 echo [OK] nmake.exe found in PATH
) else (
    if %QUIET_MODE%==0 echo [ERROR] nmake.exe not found in PATH
    set "ENV_OK=0"
    set "ISSUES_FOUND=!ISSUES_FOUND!NMAKE_EXE_MISSING;"
)

if %QUIET_MODE%==0 (
    echo.
    echo Checking library paths...
)

REM Check if ISSUES_FOUND has elements. If it does, terminate early
if defined ISSUES_FOUND (
    if %QUIET_MODE%==0 (
        echo.
        echo Some issues found, skipping library checks...
    )
    set "ENV_OK=0"
    set "ISSUES_FOUND=!ISSUES_FOUND!EARLY_EXIT;"
    goto :output_results
)


if defined LIB (
    if %QUIET_MODE%==0 (
        echo [OK] LIB environment variable set:
        for %%i in ("%LIB:;=" "%") do echo   %%~i
        echo.
        echo Checking for MSVCRT.lib...
    )
    set FOUND_MSVCRT=0
    for %%i in ("%LIB:;=" "%") do (
        if exist "%%~i\MSVCRT.lib" (
            if %QUIET_MODE%==0 echo [OK] Found MSVCRT.lib in %%~i
            set FOUND_MSVCRT=1
        )
    )
    if !FOUND_MSVCRT!==0 (
        if %QUIET_MODE%==0 echo [ERROR] MSVCRT.lib not found in any LIB path
        set "ENV_OK=0"
        set "ISSUES_FOUND=!ISSUES_FOUND!MSVCRT_LIB_MISSING;"
    )

    if %QUIET_MODE%==0 (
        echo.
        echo Checking for UCRT libraries...
    )
    set FOUND_UCRT=0
    for %%i in ("%LIB:;=" "%") do (
        if exist "%%~i\ucrt.lib" (
            if %QUIET_MODE%==0 echo [OK] Found ucrt.lib in %%~i
            set FOUND_UCRT=1
        )
    )
    if !FOUND_UCRT!==0 (
        if %QUIET_MODE%==0 echo [ERROR] ucrt.lib not found in any LIB path
        set "ENV_OK=0"
        set "ISSUES_FOUND=!ISSUES_FOUND!UCRT_LIB_MISSING;"
    )

    if %QUIET_MODE%==0 (
        echo.
        echo Checking for additional required libraries...
    )
    set FOUND_KERNEL32=0
    set FOUND_MSVCRT_LOWER=0
    for %%i in ("%LIB:;=" "%") do (
        if exist "%%~i\kernel32.lib" (
            if !FOUND_KERNEL32!==0 (
                if %QUIET_MODE%==0 echo [OK] Found kernel32.lib in %%~i
                set FOUND_KERNEL32=1
            )
        )
        if exist "%%~i\msvcrt.lib" (
            if !FOUND_MSVCRT_LOWER!==0 (
                if %QUIET_MODE%==0 echo [OK] Found msvcrt.lib in %%~i
                set FOUND_MSVCRT_LOWER=1
            )
        )
    )
    if !FOUND_KERNEL32!==0 (
        if %QUIET_MODE%==0 echo [ERROR] kernel32.lib not found in any LIB path
        set "ENV_OK=0"
        set "ISSUES_FOUND=!ISSUES_FOUND!KERNEL32_LIB_MISSING;"
    )
    if !FOUND_MSVCRT_LOWER!==0 (
        if %QUIET_MODE%==0 echo [ERROR] msvcrt.lib not found in any LIB path
        set "ENV_OK=0"
        set "ISSUES_FOUND=!ISSUES_FOUND!MSVCRT_LOWER_LIB_MISSING;"
    )

) else (
    if %QUIET_MODE%==0 echo [ERROR] LIB environment variable not set
    set "ENV_OK=0"
    set "ISSUES_FOUND=!ISSUES_FOUND!LIB_ENV_VAR_MISSING;"
)

REM Output results
if %QUIET_MODE%==1 (
    REM For programmatic use, output structured result
    if %ENV_OK%==1 (
        echo ENV_CHECK_RESULT=SUCCESS
    ) else (
        echo ENV_CHECK_RESULT=FAILED
        echo ENV_CHECK_ISSUES=!ISSUES_FOUND!
    )
) else (
    REM Interactive mode with recommendations
    echo.
    echo Recommendations:
    echo ================
    if not defined VCINSTALLDIR (
        echo 1. Run this script from a "Developer Command Prompt for VS 2022"
        echo    or "x64 Native Tools Command Prompt for VS 2022"
        echo.
        echo 2. Or manually run the Visual Studio environment setup:
        echo    "C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Auxiliary\Build\vcvars64.bat"
        echo    ^(adjust path based on your VS edition: Community/Professional/Enterprise^)
        echo.
        echo 3. Or use the build.bat script which will try to set up the environment automatically:
        echo    build.bat
    ) else (
        if not defined LIB (
            echo - LIB environment variable is missing. Try re-running vcvars64.bat
        )
        if not defined WindowsSdkDir (
            echo - Windows SDK not detected. Please install Windows SDK or run vcvars64.bat
        )
        if %ENV_OK%==1 (
            echo - Environment check passed, you can proceed with the build.
        ) else (
            echo - Some issues found. Please address them before building.
        )
    )
    echo.
    pause
)

REM Exit with appropriate code for programmatic use
if %ENV_OK%==1 (
    exit /b 0
) else (
    exit /b 1
)

:output_results
if %QUIET_MODE%==1 (
    REM For programmatic use, output structured result
    if %ENV_OK%==1 (
        echo ENV_CHECK_RESULT=SUCCESS
    ) else (
        echo ENV_CHECK_RESULT=FAILED
        echo ENV_CHECK_ISSUES=!ISSUES_FOUND!
    )
) else (
    REM Interactive mode with recommendations
    echo.
    echo Environment check completed.
    if %ENV_OK%==1 (
        echo All checks passed. You can proceed with the build.
    ) else (
        echo Some issues were found. Please review the output above.
    )
    echo.
)

REM Exit with appropriate code for programmatic use
if %ENV_OK%==1 (
    exit /b 0
) else (
    exit /b 1
)
