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


#define SAFE_PATH_SIZE 1024

// Command line size limits - based on actual luaconfig usage patterns
// Longest realistic command: ~500-1000 chars including very long paths
#define MIN_CMD_SIZE 2048    // 2KB minimum provides good safety margin
#define MAX_CMD_SIZE 4096    // 4KB maximum - reduced from 16KB (was overkill)

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

// Function to safely clean up allocated resources
void cleanup_resources(WCHAR *pathW, char *path, char *dir, char *cli, char *cfg, char *cmd,
                      HANDLE hProcess, HANDLE hThread) {
    if (pathW) free(pathW);
    if (path) free(path);
    if (dir) free(dir);
    if (cli) free(cli);
    if (cfg) free(cfg);
    if (cmd) free(cmd);
    if (hProcess) CloseHandle(hProcess);
    if (hThread) CloseHandle(hThread);
}

// Function to check for path traversal sequences
BOOL contains_path_traversal(const char* path) {
    if (!path) return TRUE;  // NULL is unsafe

    // Check for ".." path traversal sequences
    const char* ptr = path;
    while (*ptr) {
        // Look for ".." followed by path separator or end of string
        if (ptr[0] == '.' && ptr[1] == '.' &&
            (ptr[2] == '\\' || ptr[2] == '/' || ptr[2] == '\0')) {
            return TRUE;
        }
        ptr++;
    }
    return FALSE;
}

int main(int argc, char *argv[]) {
    // Use heap allocation for large buffers instead of stack
    WCHAR *executablePathW = NULL;
    char *executablePath = NULL;
    char *scriptDir = NULL;
    char *cliPath = NULL;
    char *configPath = NULL;
    char *commandLine = NULL;
    int i, totalLength = 0, exitCode = 1;
    STARTUPINFOA si;
    PROCESS_INFORMATION pi;
    BOOL success = FALSE;
    DWORD pathLength;

    // Initialize handles to NULL for safety
    pi.hProcess = NULL;
    pi.hThread = NULL;

    // Initialize timing variables for performance diagnostics
    TIMING_DECLARE_VARS();

    // Zero out structures
    ZeroMemory(&si, sizeof(si));
    ZeroMemory(&pi, sizeof(pi));

    TIMING_START("Total execution time");

    TIMING_START("Memory allocation phase");
    // Allocate memory for large buffers
    executablePathW = (WCHAR*)calloc(SAFE_PATH_SIZE, sizeof(WCHAR));
    if (!executablePathW) {
        fprintf(stderr, "Error: Failed to allocate memory for executable path\n");
        cleanup_resources(NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
        return 1;
    }

    executablePath = (char*)calloc(SAFE_PATH_SIZE, sizeof(char));
    if (!executablePath) {
        fprintf(stderr, "Error: Failed to allocate memory for executable path\n");
        cleanup_resources(executablePathW, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
        return 1;
    }

    scriptDir = (char*)calloc(SAFE_PATH_SIZE, sizeof(char));
    if (!scriptDir) {
        fprintf(stderr, "Error: Failed to allocate memory for script directory\n");
        cleanup_resources(executablePathW, executablePath, NULL, NULL, NULL, NULL, NULL, NULL);
        return 1;
    }

    cliPath = (char*)calloc(SAFE_PATH_SIZE, sizeof(char));
    if (!cliPath) {
        fprintf(stderr, "Error: Failed to allocate memory for CLI path\n");
        cleanup_resources(executablePathW, executablePath, scriptDir, NULL, NULL, NULL, NULL, NULL);
        return 1;
    }

    configPath = (char*)calloc(SAFE_PATH_SIZE, sizeof(char));
    if (!configPath) {
        fprintf(stderr, "Error: Failed to allocate memory for config path\n");
        cleanup_resources(executablePathW, executablePath, scriptDir, cliPath, NULL, NULL, NULL, NULL);
        return 1;
    }
    TIMING_END("Memory allocation phase");

    TIMING_START("Path resolution phase");
    // Get the full path of the current executable using wide character version
    pathLength = GetModuleFileNameW(NULL, executablePathW, SAFE_PATH_SIZE);
    if (pathLength == 0 || pathLength >= SAFE_PATH_SIZE) {
        fprintf(stderr, "Error: Could not get executable path (Error code: %lu)\n", GetLastError());
        cleanup_resources(executablePathW, executablePath, scriptDir, cliPath, configPath, NULL, NULL, NULL);
        return 1;
    }

    // Convert wide char path to multi-byte
    if (WideCharToMultiByte(CP_UTF8, 0, executablePathW, -1, executablePath, SAFE_PATH_SIZE, NULL, NULL) == 0) {
        fprintf(stderr, "Error: Failed to convert path encoding (Error code: %lu)\n", GetLastError());
        cleanup_resources(executablePathW, executablePath, scriptDir, cliPath, configPath, NULL, NULL, NULL);
        return 1;
    }

    // Create a copy of the executable path to extract the directory
    if (_snprintf_s(scriptDir, SAFE_PATH_SIZE, _TRUNCATE, "%s", executablePath) < 0) {
        fprintf(stderr, "Error: Failed to copy executable path\n");
        cleanup_resources(executablePathW, executablePath, scriptDir, cliPath, configPath, NULL, NULL, NULL);
        return 1;
    }

    // Find last backslash to get directory
    char *lastBackslash = strrchr(scriptDir, '\\');
    if (lastBackslash == NULL) {
        fprintf(stderr, "Error: Invalid executable path format\n");
        cleanup_resources(executablePathW, executablePath, scriptDir, cliPath, configPath, NULL, NULL, NULL);
        return 1;
    }
    *lastBackslash = '\0'; // Terminate string at last backslash

    // Check for path traversal attempts
    if (contains_path_traversal(scriptDir)) {
        fprintf(stderr, "Error: Executable path contains illegal path traversal sequences\n");
        cleanup_resources(executablePathW, executablePath, scriptDir, cliPath, configPath, NULL, NULL, NULL);
        return 1;
    }

    // Build paths to CLI executable and config file
    if (_snprintf_s(cliPath, SAFE_PATH_SIZE, _TRUNCATE, "%s\\cli\\LuaEnv.CLI.exe", scriptDir) < 0) {
        fprintf(stderr, "Error: Path to CLI executable is too long\n");
        cleanup_resources(executablePathW, executablePath, scriptDir, cliPath, configPath, NULL, NULL, NULL);
        return 1;
    }

    if (_snprintf_s(configPath, SAFE_PATH_SIZE, _TRUNCATE, "%s\\backend.config", scriptDir) < 0) {
        fprintf(stderr, "Error: Path to config file is too long\n");
        cleanup_resources(executablePathW, executablePath, scriptDir, cliPath, configPath, NULL, NULL, NULL);
        return 1;
    }
    TIMING_END("Path resolution phase");

    TIMING_START("File system validation phase");
    // Secure file access and validation using proper handle protection to prevent TOCTOU attacks
    HANDLE hCliFile = CreateFileA(
        cliPath,                      // Path to file
        GENERIC_READ | GENERIC_EXECUTE, // Read and execute access
        FILE_SHARE_READ,             // Allow others to read but not delete or modify
        NULL,                        // Default security attributes
        OPEN_EXISTING,               // Only open if it exists
        FILE_ATTRIBUTE_NORMAL,       // Normal file attributes
        NULL                         // No template
    );

    if (hCliFile == INVALID_HANDLE_VALUE) {
        DWORD error = GetLastError();
        if (error == ERROR_FILE_NOT_FOUND || error == ERROR_PATH_NOT_FOUND) {
            fprintf(stderr, "Error: CLI executable not found: %s\n", cliPath);
        } else {
            fprintf(stderr, "Error: Cannot access CLI executable: %s (Error code: %lu)\n", cliPath, error);
        }
        cleanup_resources(executablePathW, executablePath, scriptDir, cliPath, configPath, NULL, NULL, NULL);
        return 1;
    }

    // Get file attributes to ensure it's not a directory
    BY_HANDLE_FILE_INFORMATION fileInfo;
    if (!GetFileInformationByHandle(hCliFile, &fileInfo)) {
        fprintf(stderr, "Error: Failed to get CLI file information (Error code: %lu)\n", GetLastError());
        CloseHandle(hCliFile);
        cleanup_resources(executablePathW, executablePath, scriptDir, cliPath, configPath, NULL, NULL, NULL);
        return 1;
    }

    // Check that the CLI is not a directory
    if (fileInfo.dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY) {
        fprintf(stderr, "Error: CLI path points to a directory, not a file: %s\n", cliPath);
        CloseHandle(hCliFile);
        cleanup_resources(executablePathW, executablePath, scriptDir, cliPath, configPath, NULL, NULL, NULL);
        return 1;
    }

    // Keep the handle open until after process creation to prevent TOCTOU attacks

    // We've already checked that the CLI is not a directory using the file handle above

    // Secure file access for config file to prevent TOCTOU attacks
    HANDLE hConfigFile = CreateFileA(
        configPath,                   // Path to file
        GENERIC_READ,                // Read access only
        FILE_SHARE_READ,             // Allow others to read but not modify
        NULL,                        // Default security attributes
        OPEN_EXISTING,               // Only open if it exists
        FILE_ATTRIBUTE_NORMAL,       // Normal file attributes
        NULL                         // No template
    );

    if (hConfigFile == INVALID_HANDLE_VALUE) {
        DWORD error = GetLastError();
        if (error == ERROR_FILE_NOT_FOUND || error == ERROR_PATH_NOT_FOUND) {
            fprintf(stderr, "Error: Configuration file not found: %s\n", configPath);
        } else {
            fprintf(stderr, "Error: Cannot access configuration file: %s (Error code: %lu)\n", configPath, error);
        }
        CloseHandle(hCliFile); // Close the CLI file handle before exiting
        cleanup_resources(executablePathW, executablePath, scriptDir, cliPath, configPath, NULL, NULL, NULL);
        return 1;
    }

    // Get file attributes to ensure it's not a directory
    BY_HANDLE_FILE_INFORMATION configFileInfo;
    if (!GetFileInformationByHandle(hConfigFile, &configFileInfo)) {
        fprintf(stderr, "Error: Failed to get config file information (Error code: %lu)\n", GetLastError());
        CloseHandle(hConfigFile);
        CloseHandle(hCliFile);
        cleanup_resources(executablePathW, executablePath, scriptDir, cliPath, configPath, NULL, NULL, NULL);
        return 1;
    }

    // Check that the config file is not a directory
    if (configFileInfo.dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY) {
        fprintf(stderr, "Error: Config path points to a directory, not a file: %s\n", configPath);
        CloseHandle(hConfigFile);
        CloseHandle(hCliFile);
        cleanup_resources(executablePathW, executablePath, scriptDir, cliPath, configPath, NULL, NULL, NULL);
        return 1;
    }

    // Keep both handles open until process creation
    TIMING_END("File system validation phase");

    TIMING_START("Command line construction phase");

    // Calculate required buffer size for command line with checks for integer overflow
    // Start with: "cliPath" --config "configPath" pkg-config
    size_t baseLength = strlen(cliPath) + strlen(" --config ") + strlen(configPath) + strlen(" pkg-config ");
    size_t quotesLength = 4; // For quotes around paths    // Initialize totalLength with check for overflow
    if (baseLength > SIZE_MAX - quotesLength) {
        fprintf(stderr, "Error: Integer overflow in buffer size calculation (base + quotes)\n");
        cleanup_resources(executablePathW, executablePath, scriptDir, cliPath, configPath, NULL, NULL, NULL);
        return 1;
    }
    totalLength = (int)(baseLength + quotesLength);

    // Safety check - ensure totalLength is not negative or suspiciously small
    if (totalLength <= 0 || totalLength < (int)strlen(cliPath)) {
        fprintf(stderr, "Error: Invalid command line length calculation\n");
        cleanup_resources(executablePathW, executablePath, scriptDir, cliPath, configPath, NULL, NULL, NULL);
        return 1;
    }

    // Add space for all arguments with proper escaping
    for (i = 1; i < argc; i++) {
        size_t argLen = strlen(argv[i]);

        // Each char might need escaping (worst case: 2x original) + space + quotes + null terminator
        size_t spaceNeeded = (argLen * 2) + 3;        // Check for integer overflow
        if (spaceNeeded > SIZE_MAX - (size_t)totalLength) {
            fprintf(stderr, "Error: Integer overflow in buffer size calculation (args)\n");
            cleanup_resources(executablePathW, executablePath, scriptDir, cliPath, configPath, NULL, NULL, NULL);
            return 1;
        }

        totalLength += (int)spaceNeeded;
    }

    // Add safety margin
    if (100 > SIZE_MAX - (size_t)totalLength) {
        fprintf(stderr, "Error: Integer overflow in buffer size calculation (safety margin)\n");
        cleanup_resources(executablePathW, executablePath, scriptDir, cliPath, configPath, NULL, NULL, NULL);
        return 1;
    }
    totalLength += 100;

    // Enforce minimum and maximum size bounds
    if (totalLength < MIN_CMD_SIZE) {
        totalLength = MIN_CMD_SIZE;
    } else if (totalLength > MAX_CMD_SIZE) {
        fprintf(stderr, "Error: Command line would exceed maximum allowed length (%d > %d)\n",
                totalLength, MAX_CMD_SIZE);
        cleanup_resources(executablePathW, executablePath, scriptDir, cliPath, configPath, NULL, NULL, NULL);
        return 1;
    }

    // Allocate memory for command line with error handling
    errno = 0;
    commandLine = (char *)calloc(1, (size_t)totalLength + 1); // calloc zeros memory, +1 for null terminator
    if (!commandLine) {
        char errBuf[128] = {0};
        strerror_s(errBuf, sizeof(errBuf), errno);
        fprintf(stderr, "Error: Memory allocation failed (requested %d bytes): %s\n",
                totalLength + 1, errBuf);
        cleanup_resources(executablePathW, executablePath, scriptDir, cliPath, configPath, NULL, NULL, NULL);
        return 1;
    }

    // Build command line: "cliPath" --config "configPath" pkg-config arg1 arg2 ...
    // Using safer string functions and tracking position/remaining space
    size_t pos = 0;
    size_t remainingSpace = (size_t)totalLength + 1;
    int result;

    // Add CLI path with quotes - checking for truncation
    result = _snprintf_s(commandLine + pos, remainingSpace, _TRUNCATE, "\"%s\"", cliPath);
    if (result < 0 || (size_t)result >= remainingSpace - 1) {
        fprintf(stderr, "Error: Command line truncated while adding CLI path\n");
        cleanup_resources(executablePathW, executablePath, scriptDir, cliPath, configPath, commandLine, NULL, NULL);
        return 1;
    }
    pos += (size_t)result;
    remainingSpace = (size_t)totalLength + 1 - pos;

    // Add --config parameter and config path with quotes
    result = _snprintf_s(commandLine + pos, remainingSpace, _TRUNCATE, " --config \"%s\" pkg-config", configPath);
    if (result < 0 || (size_t)result >= remainingSpace - 1) {
        fprintf(stderr, "Error: Command line truncated while adding config path\n");
        cleanup_resources(executablePathW, executablePath, scriptDir, cliPath, configPath, commandLine, NULL, NULL);
        return 1;
    }
    pos += (size_t)result;
    remainingSpace = (size_t)totalLength + 1 - pos;

    // Correctly quote and escape arguments for the Windows command line
    for (i = 1; i < argc; i++) {
        // Add a space before each argument
        result = _snprintf_s(commandLine + pos, remainingSpace, _TRUNCATE, " ");
        if (result < 0 || (size_t)result >= remainingSpace) {
            goto command_line_too_long;
        }
        pos += (size_t)result;
        remainingSpace -= (size_t)result;

        const char* arg = argv[i];
        // An argument needs to be quoted if it's empty, contains a space/tab, or a double quote.
        BOOL needsQuotes = (arg[0] == '\0') || (strchr(arg, ' ') != NULL) || (strchr(arg, '\t') != NULL) || (strchr(arg, '"') != NULL);

        if (needsQuotes) {
            result = _snprintf_s(commandLine + pos, remainingSpace, _TRUNCATE, "\"");
            if (result < 0 || (size_t)result >= remainingSpace) goto command_line_too_long;
            pos += (size_t)result;
            remainingSpace -= (size_t)result;
        }

        int backslashCount = 0;
        for (const char* p = arg; *p != '\0'; p++) {
            if (*p == '\\') {
                backslashCount++;
            } else if (*p == '\"') {
                // Escape backslashes before a quote: 2n+1 backslashes + the quote
                for (int j = 0; j < backslashCount * 2 + 1; j++) {
                    result = _snprintf_s(commandLine + pos, remainingSpace, _TRUNCATE, "\\");
                    if (result < 0 || (size_t)result >= remainingSpace) goto command_line_too_long;
                    pos += (size_t)result;
                    remainingSpace -= (size_t)result;
                }
                // Add the quote character itself
                result = _snprintf_s(commandLine + pos, remainingSpace, _TRUNCATE, "\"");
                if (result < 0 || (size_t)result >= remainingSpace) goto command_line_too_long;
                pos += (size_t)result;
                remainingSpace -= (size_t)result;
                backslashCount = 0;
            } else {
                // Not a special character, output pending backslashes literally
                for (int j = 0; j < backslashCount; j++) {
                    result = _snprintf_s(commandLine + pos, remainingSpace, _TRUNCATE, "\\");
                    if (result < 0 || (size_t)result >= remainingSpace) goto command_line_too_long;
                    pos += (size_t)result;
                    remainingSpace -= (size_t)result;
                }
                backslashCount = 0;
                // Add the character itself
                result = _snprintf_s(commandLine + pos, remainingSpace, _TRUNCATE, "%c", *p);
                if (result < 0 || (size_t)result >= remainingSpace) goto command_line_too_long;
                pos += (size_t)result;
                remainingSpace -= (size_t)result;
            }
        }

        if (needsQuotes) {
            // At the end of a quoted argument, double any trailing backslashes
            for (int j = 0; j < backslashCount * 2; j++) {
                result = _snprintf_s(commandLine + pos, remainingSpace, _TRUNCATE, "\\");
                if (result < 0 || (size_t)result >= remainingSpace) goto command_line_too_long;
                pos += (size_t)result;
                remainingSpace -= (size_t)result;
            }
            // Add the closing quote
            result = _snprintf_s(commandLine + pos, remainingSpace, _TRUNCATE, "\"");
            if (result < 0 || (size_t)result >= remainingSpace) goto command_line_too_long;
            pos += (size_t)result;
            remainingSpace -= (size_t)result;
        } else {
            // If not quoted, trailing backslashes are literal
            for (int j = 0; j < backslashCount; j++) {
                result = _snprintf_s(commandLine + pos, remainingSpace, _TRUNCATE, "\\");
                if (result < 0 || (size_t)result >= remainingSpace) goto command_line_too_long;
                pos += (size_t)result;
                remainingSpace -= (size_t)result;
            }
        }
    }

    // Ensure null termination
    commandLine[pos] = '\0';

    // Create the process
    if (!CreateProcessA(
        cliPath,                      // Application name (CLI executable)
        commandLine,                  // Command line arguments
        NULL,                        // Process security attributes
        NULL,                        // Primary thread security attributes
        FALSE,                       // Inherit handles flag
        0,                           // Creation flags
        NULL,                        // Use parent's environment block
        NULL,                        // Use parent's starting directory
        &si,                         // Pointer to STARTUPINFO structure
        &pi                          // Pointer to PROCESS_INFORMATION structure
    )) {
        fprintf(stderr, "Error: Failed to create process (Error code: %lu)\n", GetLastError());
        cleanup_resources(executablePathW, executablePath, scriptDir, cliPath, configPath, commandLine, NULL, NULL);
        return 1;
    }
    TIMING_END("Process creation phase");

    // Wait for the process to complete and get the exit code
    WaitForSingleObject(pi.hProcess, INFINITE);
    GetExitCodeProcess(pi.hProcess, (LPDWORD)&exitCode);

    // Close process and thread handles
    CloseHandle(pi.hProcess);
    CloseHandle(pi.hThread);

    // Output the exit code of the CLI
    // printf("CLI exited with code: %d\n", exitCode);

    // Cleanup allocated resources
    cleanup_resources(executablePathW, executablePath, scriptDir, cliPath, configPath, commandLine, NULL, NULL);

    TIMING_END("Total execution time");

    return exitCode;

command_line_too_long:
    fprintf(stderr, "Error: Command line construction failed, buffer too small.");
    cleanup_resources(executablePathW, executablePath, scriptDir, cliPath, configPath, commandLine, NULL, NULL);
    return 1;
}