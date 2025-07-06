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

// For long path support - Windows supports paths up to ~32767 chars with proper prefixing
// Increased from 520 to 1024 to handle longer paths more safely
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
    // Verify that the CLI executable exists
    DWORD cliAttrs = GetFileAttributes(cliPath);
    if (cliAttrs == INVALID_FILE_ATTRIBUTES) {
        DWORD error = GetLastError();
        if (error == ERROR_FILE_NOT_FOUND || error == ERROR_PATH_NOT_FOUND) {
            fprintf(stderr, "Error: CLI executable not found: %s\n", cliPath);
        } else {
            fprintf(stderr, "Error: Cannot access CLI executable: %s (Error code: %lu)\n", cliPath, error);
        }
        cleanup_resources(executablePathW, executablePath, scriptDir, cliPath, configPath, NULL, NULL, NULL);
        return 1;
    }

    // Check that the CLI is not a directory
    if (cliAttrs & FILE_ATTRIBUTE_DIRECTORY) {
        fprintf(stderr, "Error: CLI path points to a directory, not a file: %s\n", cliPath);
        cleanup_resources(executablePathW, executablePath, scriptDir, cliPath, configPath, NULL, NULL, NULL);
        return 1;
    }

    // Verify that the config file exists
    DWORD configAttrs = GetFileAttributes(configPath);
    if (configAttrs == INVALID_FILE_ATTRIBUTES) {
        DWORD error = GetLastError();
        if (error == ERROR_FILE_NOT_FOUND || error == ERROR_PATH_NOT_FOUND) {
            fprintf(stderr, "Error: Configuration file not found: %s\n", configPath);
        } else {
            fprintf(stderr, "Error: Cannot access configuration file: %s (Error code: %lu)\n", configPath, error);
        }
        cleanup_resources(executablePathW, executablePath, scriptDir, cliPath, configPath, NULL, NULL, NULL);
        return 1;
    }

    // Check that the config file is not a directory
    if (configAttrs & FILE_ATTRIBUTE_DIRECTORY) {
        fprintf(stderr, "Error: Config path points to a directory, not a file: %s\n", configPath);
        cleanup_resources(executablePathW, executablePath, scriptDir, cliPath, configPath, NULL, NULL, NULL);
        return 1;
    }
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

    // Enhanced quoting and escaping for Windows command line arguments
    // This follows Windows command line parsing rules for proper argument handling
    for (i = 1; i < argc; i++) {
        // Check for empty argument or characters requiring quoting
        BOOL needsQuotes = (*argv[i] == '\0');  // Empty string always needs quotes

        if (!needsQuotes) {
            // Check for characters that need special handling
            for (size_t j = 0; argv[i][j] != '\0'; j++) {
                char c = argv[i][j];
                if (c == ' ' || c == '\t' || c == '&' || c == '|' || c == '^' ||
                    c == '%' || c == '<' || c == '>' || c == '"' || c == '\'') {
                    needsQuotes = TRUE;
                    break;
                }
            }
        }

        if (needsQuotes) {
            // Add opening quote
            result = _snprintf_s(commandLine + pos, remainingSpace, _TRUNCATE, " \"");
            if (result < 0 || (size_t)result >= remainingSpace - 1) {
                fprintf(stderr, "Error: Command line too long at argument %d\n", i);
                cleanup_resources(executablePathW, executablePath, scriptDir, cliPath, configPath, commandLine, NULL, NULL);
                return 1;
            }
            pos += (size_t)result;
            remainingSpace = (size_t)totalLength + 1 - pos;

            // Process argument character by character with proper escaping
            for (size_t j = 0; argv[i][j] != '\0'; j++) {
                // Count backslashes before a quote (they need doubling)
                if (argv[i][j] == '"') {
                    // Add backslash before quote                    result = _snprintf_s(commandLine + pos, remainingSpace, _TRUNCATE, "\\");
                    if (result < 0 || (size_t)result >= remainingSpace - 1) {
                        fprintf(stderr, "Error: Command line too long while escaping quotes\n");
                        cleanup_resources(executablePathW, executablePath, scriptDir, cliPath, configPath, commandLine, NULL, NULL);
                        return 1;
                    }
                    pos += (size_t)result;
                    remainingSpace = (size_t)totalLength + 1 - pos;
                }

                // Add the character
                result = _snprintf_s(commandLine + pos, remainingSpace, _TRUNCATE, "%c", argv[i][j]);
                if (result < 0 || (size_t)result >= remainingSpace - 1) {
                    fprintf(stderr, "Error: Command line too long while adding character\n");
                    cleanup_resources(executablePathW, executablePath, scriptDir, cliPath, configPath, commandLine, NULL, NULL);
                    return 1;
                }
                pos += (size_t)result;
                remainingSpace = (size_t)totalLength + 1 - pos;
            }

            // Add closing quote
            result = _snprintf_s(commandLine + pos, remainingSpace, _TRUNCATE, "\"");
            if (result < 0 || (size_t)result >= remainingSpace - 1) {
                fprintf(stderr, "Error: Command line too long at argument end\n");
                cleanup_resources(executablePathW, executablePath, scriptDir, cliPath, configPath, commandLine, NULL, NULL);
                return 1;
            }
            pos += (size_t)result;
        } else {
            // Add argument without quotes if it doesn't need them
            result = _snprintf_s(commandLine + pos, remainingSpace, _TRUNCATE, " %s", argv[i]);
            if (result < 0 || (size_t)result >= remainingSpace - 1) {
                fprintf(stderr, "Error: Command line too long for argument %d\n", i);
                cleanup_resources(executablePathW, executablePath, scriptDir, cliPath, configPath, commandLine, NULL, NULL);
                return 1;
            }
            pos += (size_t)result;
        }

        remainingSpace = (size_t)totalLength + 1 - pos;
    }

    // Add terminating null just in case (redundant but safe)
    commandLine[pos] = '\0';
    TIMING_END("Command line construction phase");

    // Initialize startup info structure
    ZeroMemory(&si, sizeof(si));
    si.cb = sizeof(si);
    ZeroMemory(&pi, sizeof(pi));

    // Debug output of command line in verbose mode (optional)
    #ifdef _DEBUG
    fprintf(stderr, "Command line: %s\n", commandLine);
    #endif

    TIMING_START("Process creation phase");
    // Execute command with error handling
    success = CreateProcessA(
        NULL,                // No module name (use command line)
        commandLine,         // Command line
        NULL,                // Process handle not inheritable
        NULL,                // Thread handle not inheritable
        TRUE,                // Handle inheritance (needed for std handles)
        0,                   // No creation flags
        NULL,                // Use parent's environment block
        NULL,                // Use parent's starting directory
        &si,                 // Startup info
        &pi                  // Process information
    );

    if (!success) {
        TIMING_END("Process creation phase");
        DWORD error = GetLastError();
        // Provide more specific error information based on common CreateProcess errors
        switch (error) {
            case ERROR_FILE_NOT_FOUND:
                fprintf(stderr, "Error: The CLI executable was not found\n");
                break;
            case ERROR_PATH_NOT_FOUND:
                fprintf(stderr, "Error: Path to CLI executable not found\n");
                break;
            case ERROR_ACCESS_DENIED:
                fprintf(stderr, "Error: Access denied when trying to run CLI executable\n");
                break;
            case ERROR_BAD_EXE_FORMAT:
                fprintf(stderr, "Error: The CLI executable is invalid or corrupted\n");
                break;
            default:
                fprintf(stderr, "Error: CreateProcess failed with error code: %lu\n", error);
        }
        cleanup_resources(executablePathW, executablePath, scriptDir, cliPath, configPath, commandLine, NULL, NULL);
        return 1;
    }
    TIMING_END("Process creation phase");

    TIMING_START("CLI execution and wait phase");

    // Wait for the process to complete with timeout handling
    DWORD waitResult = WaitForSingleObject(pi.hProcess, 20000); // 20-second timeout (increased from 15)
    if (waitResult == WAIT_TIMEOUT) {
        TIMING_END("CLI execution and wait phase");
        fprintf(stderr, "Warning: Command execution timed out after 20 seconds, terminating\n");
        TerminateProcess(pi.hProcess, 1);
        cleanup_resources(executablePathW, executablePath, scriptDir, cliPath, configPath, commandLine, pi.hProcess, pi.hThread);
        return 1;
    } else if (waitResult != WAIT_OBJECT_0) {
        TIMING_END("CLI execution and wait phase");
        fprintf(stderr, "Error: Failed to wait for process completion (Error code: %lu)\n", GetLastError());
        cleanup_resources(executablePathW, executablePath, scriptDir, cliPath, configPath, commandLine, pi.hProcess, pi.hThread);
        return 1;
    }
    TIMING_END("CLI execution and wait phase");

    TIMING_START("Process cleanup phase");
    // Get the exit code with error handling
    DWORD procExitCode = 1; // Default failure code
    if (!GetExitCodeProcess(pi.hProcess, &procExitCode)) {
        fprintf(stderr, "Error: Failed to get process exit code (Error code: %lu)\n", GetLastError());
        // Continue with cleanup but use default exit code
    } else {
        exitCode = (int)procExitCode;
    }

    // Clean up all resources
    cleanup_resources(executablePathW, executablePath, scriptDir, cliPath, configPath, commandLine, pi.hProcess, pi.hThread);
    TIMING_END("Process cleanup phase");

    TIMING_END("Total execution time");

    #ifdef _DEBUG
    fprintf(stderr, "[TIMING] luaconfig.exe execution completed with exit code: %d\n", exitCode);
    #endif

    // Return the same exit code as the child process
    return exitCode;
}