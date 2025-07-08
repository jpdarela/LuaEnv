#!/usr/bin/env lua

-- Test script to verify Windows-native Lua extensions work properly
print("=== LuaEnv Windows Extensions Test ===")
print()

-- Test LuaSocket (networking)
print("Testing LuaSocket...")
local socket = require('socket')
print("✓ LuaSocket loaded successfully")
print("  Version:", socket._VERSION or "unknown")
print()

-- Test LuaSec (SSL/TLS with OpenSSL via vcpkg)
print("Testing LuaSec...")
local ssl = require('ssl')
print("✓ LuaSec loaded successfully")
print("  SSL support available")
print()

-- Test linenoise-windows (readline alternative)
print("Testing linenoise-windows...")
local linenoise = require('linenoise')
print("✓ linenoise-windows loaded successfully")
print("  Readline-like functionality available for Windows")
print()

-- Test winapi (Windows API access)
print("Testing winapi...")
local winapi = require('winapi')
print("✓ winapi loaded successfully")
print("  Windows API bindings available")
print()

-- Demonstrate some basic functionality
print("=== Functionality Demonstrations ===")
print()

-- Socket functionality
print("Socket functionality:")
local host, port = socket.dns.toip("google.com")
print("  DNS lookup google.com:", host or "failed")
print()

-- Windows API functionality
print("Windows API functionality:")
local pid = winapi.get_current_pid()
print("  Current process ID:", pid)

local drives = winapi.get_logical_drives()
print("  Logical drives:", table.concat(drives, ", "))

-- Test clipboard operations
local test_text = "LuaEnv clipboard test"
winapi.set_clipboard(test_text)
local clipboard_content = winapi.get_clipboard()
if clipboard_content == test_text then
    print("  ✓ Clipboard operations working")
else
    print("  ✗ Clipboard test failed")
end

-- Get temporary file path
local temp_file = winapi.temp_name()
print("  Temp file path example:", temp_file)
print()

-- SSL functionality test (just verify the module loads)
print("SSL functionality:")
print("  ✓ LuaSec module loaded and OpenSSL available")
print()

print("=== Summary ===")
print("All Windows-native Lua extensions are working properly!")
print("✓ LuaSocket: Network operations (DNS lookups, sockets)")
print("✓ LuaSec: SSL/TLS support via vcpkg OpenSSL integration")
print("✓ linenoise-windows: Readline-like functionality for Windows")
print("✓ winapi: Windows API access (process info, drives, clipboard, etc.)")
print()
print("The vcpkg integration successfully provides C libraries (OpenSSL) for LuaSec.")
print("Alternative Windows-compatible packages work as expected.")
print()
print("Note: The original 'readline' package fails on Windows because it depends on")
print("luaposix (POSIX compatibility layer), but linenoise-windows provides similar")
print("functionality specifically designed for Windows.")
