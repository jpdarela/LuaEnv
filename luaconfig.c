/* This is free and unencumbered software released into the public domain.
 * For more details, see the LICENSE file in the project root.
 */

/*
 * Wrapper for LuaEnv CLI pkg-config command
 *
 * This program is designed to run the LuaEnv CLI with proper path handling and command line argument management.
 * It ensures that the CLI executable and configuration file are correctly located and executed.
 * The program is specifically designed to wrap the LuaEnv CLI executable (pkg-config command)
 *
 * PERFORMANCE DIAGNOSTICS:
 * To enable timing diagnostics, compile with the _DEBUG flag:
 *   cl /D_DEBUG luaconfig.c
 * or add #define _DEBUG at the top of this file before the includes.
 *
 * This will output detailed timing information to stderr showing:
 * - Memory allocation overhead
 * - Path resolution and validation time
 * - File system operations duration
 * - Command line construction time
 * - Process creation overhead
 * - CLI execution time (the main bottleneck)
 * - Cleanup operations time
 *
 * This code is part of the LuaEnv project, which provides a Lua environment for Windows.
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <process.h>
#include <windows.h>
#include <errno.h>


#define CMD_BUFFER_SIZE 260

#define CLI_RELATIVE_PATH "cli\\LuaEnv.CLI.exe"
#define CONFIG_RELATIVE_PATH "backend.config"

#ifdef _DEBUG
// Timing diagnostic macros - only active when _DEBUG is defined
#define TIMING_DECLARE_VARS() \
    LARGE_INTEGER timing_freq, timing_start, timing_current; \
    QueryPerformanceFrequency(&timing_freq);

#define TIMING_START(name) \
    do { \
        QueryPerformanceCounter(&timing_start); \
        fprintf(stderr, "[TIMING] Starting %s...\n", name); \
    } while(0)

#define TIMING_END(name) \
    do { \
        QueryPerformanceCounter(&timing_current); \
        double elapsed = (double)(timing_current.QuadPart - timing_start.QuadPart) / timing_freq.QuadPart * 1000.0; \
        fprintf(stderr, "[TIMING] %s completed in %.2f ms\n", name, elapsed); \
    } while(0)

#define TIMING_POINT(description) \
    do { \
        QueryPerformanceCounter(&timing_current); \
        double elapsed = (double)(timing_current.QuadPart - timing_start.QuadPart) / timing_freq.QuadPart * 1000.0; \
        fprintf(stderr, "[TIMING] %s: %.2f ms elapsed\n", description, elapsed); \
    } while(0)

#define TIMING_RESET() \
    do { \
        QueryPerformanceCounter(&timing_start); \
    } while(0)
#else
// Empty macros when not in debug mode
#define TIMING_DECLARE_VARS() do {} while(0)
#define TIMING_START(name) do {} while(0)
#define TIMING_END(name) do {} while(0)
#define TIMING_POINT(description) do {} while(0)
#define TIMING_RESET() do {} while(0)
#endif

// Simplified cleanup function for handles only
void cleanup_handles(HANDLE hProcess, HANDLE hThread, HANDLE hCliFile, HANDLE hConfigFile) {
    if (hProcess) CloseHandle(hProcess);
    if (hThread) CloseHandle(hThread);
    if (hCliFile && hCliFile != INVALID_HANDLE_VALUE) CloseHandle(hCliFile);
    if (hConfigFile && hConfigFile != INVALID_HANDLE_VALUE) CloseHandle(hConfigFile);
}

int main(int argc, char *argv[]) {
    // Stack-based buffers - much smaller and safer
    WCHAR executablePathW[MAX_PATH];
    char executablePath[MAX_PATH];
    char scriptDir[MAX_PATH];
    char cliPath[MAX_PATH];
    char configPath[MAX_PATH];
    char commandLine[CMD_BUFFER_SIZE];

    int i, exitCode = 1;
    STARTUPINFOA si;
    PROCESS_INFORMATION pi;
    DWORD pathLength;
    HANDLE hCliFile = INVALID_HANDLE_VALUE;
    HANDLE hConfigFile = INVALID_HANDLE_VALUE;

    // Initialize timing variables for performance diagnostics
    TIMING_DECLARE_VARS();

    // Zero out structures
    ZeroMemory(&si, sizeof(si));
    ZeroMemory(&pi, sizeof(pi));
    ZeroMemory(commandLine, sizeof(commandLine));

    TIMING_START("Total execution time");

    TIMING_START("Path resolution phase");
    // Get the full path of the current executable
    pathLength = GetModuleFileNameW(NULL, executablePathW, MAX_PATH);
    if (pathLength == 0 || pathLength >= MAX_PATH) {
        fprintf(stderr, "Error: Could not get executable path (Error code: %lu)\n", GetLastError());
        return 1;
    }

    // Convert wide char path to multi-byte
    if (WideCharToMultiByte(CP_UTF8, 0, executablePathW, -1, executablePath, MAX_PATH, NULL, NULL) == 0) {
        fprintf(stderr, "Error: Failed to convert path encoding (Error code: %lu)\n", GetLastError());
        return 1;
    }

    // Create a copy of the executable path to extract the directory
    if (_snprintf_s(scriptDir, MAX_PATH, _TRUNCATE, "%s", executablePath) < 0) {
        fprintf(stderr, "Error: Failed to copy executable path\n");
        return 1;
    }

    // Find last backslash to get directory
    char *lastBackslash = strrchr(scriptDir, '\\');
    if (lastBackslash == NULL) {
        fprintf(stderr, "Error: Invalid executable path format\n");
        return 1;
    }
    *lastBackslash = '\0';

    // Build paths using hardcoded relative paths - simpler and safer
    if (_snprintf_s(cliPath, MAX_PATH, _TRUNCATE, "%s\\%s", scriptDir, CLI_RELATIVE_PATH) < 0) {
        fprintf(stderr, "Error: Path to CLI executable is too long\n");
        return 1;
    }

    if (_snprintf_s(configPath, MAX_PATH, _TRUNCATE, "%s\\%s", scriptDir, CONFIG_RELATIVE_PATH) < 0) {
        fprintf(stderr, "Error: Path to config file is too long\n");
        return 1;
    }
    TIMING_END("Path resolution phase");

    TIMING_START("File system validation phase");
    // Basic file validation - check CLI exists
    hCliFile = CreateFileA(cliPath, GENERIC_READ, FILE_SHARE_READ, NULL, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, NULL);
    if (hCliFile == INVALID_HANDLE_VALUE) {
        fprintf(stderr, "Error: CLI executable not found: %s\n", cliPath);
        return 1;
    }

    // Basic file validation - check config exists
    hConfigFile = CreateFileA(configPath, GENERIC_READ, FILE_SHARE_READ, NULL, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, NULL);
    if (hConfigFile == INVALID_HANDLE_VALUE) {
        fprintf(stderr, "Error: Configuration file not found: %s\n", configPath);
        CloseHandle(hCliFile);
        return 1;
    }
    TIMING_END("File system validation phase");

    TIMING_START("Command line construction phase");
    // Build simple command line without complex argument escaping
    // Format: "cliPath" --config "configPath" pkg-config [simple args...]
    size_t pos = 0;
    int result;

    // Add CLI path with quotes
    result = _snprintf_s(commandLine, CMD_BUFFER_SIZE, _TRUNCATE, "\"%s\" --config \"%s\" pkg-config", cliPath, configPath);
    if (result < 0) {
        fprintf(stderr, "Error: Command line truncated\n");
        cleanup_handles(NULL, NULL, hCliFile, hConfigFile);
        return 1;
    }
    pos = (size_t)result;

    // Add remaining arguments with simple space separation
    for (i = 1; i < argc; i++) {
        // Simple concatenation - let the CLI handle argument parsing
        size_t remaining = CMD_BUFFER_SIZE - pos;
        result = _snprintf_s(commandLine + pos, remaining, _TRUNCATE, " %s", argv[i]);
        if (result < 0) {
            fprintf(stderr, "Error: Command line too long\n");
            cleanup_handles(NULL, NULL, hCliFile, hConfigFile);
            return 1;
        }
        pos += (size_t)result;
    }
    TIMING_END("Command line construction phase");

    TIMING_START("Process creation phase");
    // Create the process
    if (!CreateProcessA(
        cliPath,                      // Application name
        commandLine,                  // Command line
        NULL,                        // Process security attributes
        NULL,                        // Thread security attributes
        FALSE,                       // Inherit handles
        0,                           // Creation flags
        NULL,                        // Environment
        NULL,                        // Current directory
        &si,                         // Startup info
        &pi                          // Process information
    )) {
        fprintf(stderr, "Error: Failed to create process (Error code: %lu)\n", GetLastError());
        cleanup_handles(NULL, NULL, hCliFile, hConfigFile);
        return 1;
    }
    TIMING_END("Process creation phase");

    // Wait for completion and get exit code
    WaitForSingleObject(pi.hProcess, INFINITE);
    GetExitCodeProcess(pi.hProcess, (LPDWORD)&exitCode);

    // Cleanup
    cleanup_handles(pi.hProcess, pi.hThread, hCliFile, hConfigFile);

    TIMING_END("Total execution time");
    return exitCode;
}