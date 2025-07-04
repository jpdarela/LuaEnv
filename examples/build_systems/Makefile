# GNU Makefile for Windows/MSVC with luaenv pkg-config integration
# Demonstrates cross-platform Makefile that works with MSVC on Windows
# Usage: make (requires GNU make, works in MSYS2, GitHub Actions, etc.)

# If using a dll build, ensure that the dll is in the same directory as the executable or in the system PATH.
# You can use luaenv activate --alias dev to set up the environment for development.
# This will set the bin path of the lua installation to the PATH variable, enabling the findin of the lua.dll
# This script assumes that you have an installation of lua made with luaenv with the dev alias.
# If using a DLL build, ensure that the DLL is in the
# same directory as the executable or in the system PATH.


# Detect Windows environment and use MSVC
ifeq ($(OS),Windows_NT)
    CC = cl.exe
    TARGET_EXT = .exe
    OBJ_EXT = .obj
    # Get Lua configuration from luaenv pkg-config with unix path style
    LUA_CFLAGS := $(shell luaenv-pkg-config dev --cflag --path-style unix)
    LUA_LIB := $(shell luaenv-pkg-config dev --liblua --path-style unix)

    # MSVC-specific flags
    CFLAGS = /TC /W4 -D_CRT_SECURE_NO_WARNINGS $(LUA_CFLAGS)
    DEBUG_FLAGS = /Zi /Od /DEBUG
    RELEASE_FLAGS = /O2 /DNDEBUG
    LINK_FLAGS = /link "$(LUA_LIB)"

    # Clean command for Windows
    RM = del /f /q
    CLEAN_FILES = *.exe *.obj *.pdb *.ilk
else
    # Unix/Linux fallback (not used in this Windows-focused test)
    CC = gcc
    TARGET_EXT =
    OBJ_EXT = .o
    LUA_CFLAGS := $(shell pkg-config --cflags lua)
    LUA_LIB := $(shell pkg-config --libs lua)

    CFLAGS = -Wall -Wextra $(LUA_CFLAGS)
    DEBUG_FLAGS = -g -O0
    RELEASE_FLAGS = -O2 -DNDEBUG
    LINK_FLAGS = $(LUA_LIB)

    RM = rm -f
    CLEAN_FILES = main main_debug *.o
endif

TARGET = main
SOURCE = main.c

.PHONY: all debug release clean test

all: release debug

release: $(TARGET)$(TARGET_EXT)

debug: $(TARGET)_debug$(TARGET_EXT)

# Release build rule
$(TARGET)$(TARGET_EXT): $(SOURCE)
ifeq ($(OS),Windows_NT)
	@echo [INFO] Building release version with GNU Make + MSVC...
	$(CC) $(CFLAGS) $(RELEASE_FLAGS) $(SOURCE) /Fe:$@ $(LINK_FLAGS)
	@echo [SUCCESS] Release build completed: $@
else
	$(CC) $(CFLAGS) $(RELEASE_FLAGS) -o $@ $(SOURCE) $(LINK_FLAGS)
endif

# Debug build rule
$(TARGET)_debug$(TARGET_EXT): $(SOURCE)
ifeq ($(OS),Windows_NT)
	@echo [INFO] Building debug version with GNU Make + MSVC...
	$(CC) $(CFLAGS) $(DEBUG_FLAGS) $(SOURCE) /Fe:$@ $(LINK_FLAGS)
	@echo [SUCCESS] Debug build completed: $@
else
	$(CC) $(CFLAGS) $(DEBUG_FLAGS) -o $@ $(SOURCE) $(LINK_FLAGS)
endif

# Test both executables
test: all
	@echo [INFO] Testing release executable...
	./$(TARGET)$(TARGET_EXT)
	@echo [INFO] Testing debug executable...
	./$(TARGET)_debug$(TARGET_EXT)

clean:
	@echo [INFO] Cleaning build artifacts...
	-$(RM) $(CLEAN_FILES) 2>nul || true

# Display configuration (useful for debugging)
config:
	@echo Build Configuration:
	@echo   OS: $(OS)
	@echo   CC: $(CC)
	@echo   LUA_CFLAGS: $(LUA_CFLAGS)
	@echo   LUA_LIB: $(LUA_LIB)
	@echo   CFLAGS: $(CFLAGS)
	@echo   Target extension: $(TARGET_EXT)

# Help target
help:
	@echo GNU Makefile for Windows/MSVC with luaenv pkg-config
	@echo.
	@echo Targets:
	@echo   all      - Build both release and debug versions
	@echo   release  - Build release version only
	@echo   debug    - Build debug version only
	@echo   test     - Build and test both versions
	@echo   clean    - Remove build artifacts
	@echo   config   - Show build configuration
	@echo   help     - Show this help
	@echo.
	@echo Requirements:
	@echo   - GNU Make (available in MSYS2, Git Bash, GitHub Actions)
	@echo   - MSVC compiler (cl.exe in PATH)
	@echo   - luaenv with pkg-config support






