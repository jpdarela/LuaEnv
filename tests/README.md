# Lua MSVC Build System - Test Suite

This directory contains comprehensive tests for the Lua MSVC Build System, designed to ensure all functionality works correctly across different scenarios.

## Test Structure

The test suite is organized into several modules:

### Core Test Modules

- **`test_download.py`** - Tests for downloading and extracting Lua/LuaRocks files
- **`test_config_basic.py`** - Basic configuration system tests
- **`test_config_cache.py`** - Version cache functionality tests
- **`test_config_cli.py`** - Command-line interface tests
- **`test_setup_build.py`** - Build script setup tests

### Bootstrap Test System

The test suite includes a **bootstrap test system** that ensures all required files are available before running tests that depend on them.

#### Bootstrap Test: `TestDownloadBootstrap.test_aaa_bootstrap_download_and_extract_all_files`

This critical test:

1. **Runs first** (enforced by `aaa_` prefix and test runner)
2. **Downloads all required files** (Lua source, LuaRocks, Lua tests)
3. **Extracts all files** to the correct directories
4. **Validates content** (file sizes, directory structure)
5. **Is idempotent** (fast when files already exist)
6. **Fails clearly** if network/download issues occur

**Key Features:**
- 📥 **Smart downloading**: Only downloads if files don't already exist
- ✅ **Comprehensive validation**: Checks file sizes, directory structure, and content
- 🔄 **Idempotent**: Runs fast (< 1 second) when files already exist
- ❌ **Clear failure messages**: Provides actionable error messages with troubleshooting tips
- 🎯 **Dependency aware**: Subsequent tests skip gracefully if bootstrap fails

#### Error Handling

If the bootstrap test fails, it provides clear error messages:

```
[BOOTSTRAP] ❌ CRITICAL FAILURE: Download failed: <specific error>
[BOOTSTRAP] ❌ This means either:
[BOOTSTRAP] ❌   1. No internet connection
[BOOTSTRAP] ❌   2. Download URLs are invalid
[BOOTSTRAP] ❌   3. Server is unavailable
[BOOTSTRAP] ❌ Subsequent tests WILL FAIL!

## Running Tests

### Recommended: Use the Test Runner

```bash
python run_tests.py
```

This ensures:
- Bootstrap test runs first
- All tests run in correct order
- Clear success/failure summary
- Proper error reporting

### Run Individual Tests

```bash
# Run just the bootstrap test
python -m unittest tests.test_download.TestDownloadBootstrap.test_aaa_bootstrap_download_and_extract_all_files -v

# Run specific test modules
python -m unittest tests.test_config_basic -v
python -m unittest tests.test_setup_build -v
```

### Run All Tests with unittest

```bash
python -m unittest discover tests -v
```

## Test Categories

### Unit Tests
- Configuration loading and validation
- Function existence and basic behavior
- Data structure validation
- Mocked external dependencies

### Integration Tests
- CLI command execution
- Cache file operations
- Version discovery and validation
- Real network operations (with graceful failure)

### End-to-End Tests
- Complete download and extraction workflows
- Build script copying and validation
- Real file operations in project directory

## Test Environment

### Working Directory
All tests run in the **project root directory** (not isolated test directories), ensuring:
- Tests use the same files users would use
- Real integration with the build system
- Proper validation of the complete workflow

### Dependencies
The tests are designed to work with:
- Python 3.6+ (using only standard library)
- Real internet connection (for download tests)
- Windows environment (PowerShell commands)

### File Management
- **Downloads**: Saved to `downloads/` in project root
- **Extracted files**: Saved to project root (e.g., `lua-5.4.8/`, `luarocks-3.12.2-windows-64/`)
- **Cache files**: Saved to project root (e.g., `.lua_versions_cache.json`)

## Robustness Features

### Clean Environment Testing
The test suite is robust to:
- ✅ **Clean project directory**: Bootstrap automatically downloads required files
- ✅ **Missing dependencies**: Tests skip gracefully with helpful messages
- ✅ **Network failures**: Clear error messages with troubleshooting guidance
- ✅ **Partial downloads**: Validates file integrity and re-downloads if needed

### Idempotency
- ✅ **Multiple runs**: Safe to run tests multiple times
- ✅ **Incremental testing**: Can run subsets of tests safely
- ✅ **Fast re-runs**: Bootstrap skips downloads when files exist

### Error Recovery
- ✅ **Graceful degradation**: Tests skip when dependencies missing
- ✅ **Clear error messages**: Actionable failure information
- ✅ **Troubleshooting guidance**: Specific commands to fix issues

## Test Design Principles

1. **Real over Mocked**: Tests use real files and operations where possible
2. **Incremental Complexity**: Simple tests build up to complex scenarios
3. **Clear Failure Messages**: Every failure provides actionable information
4. **Dependency Management**: Bootstrap ensures required files are available
5. **Robustness**: Tests work in clean environments and recover from failures

## Example Test Output

### Successful Bootstrap
```
[BOOTSTRAP] ✅ All required files are ready:
  Downloads: downloads (3 files)
  Lua: lua-5.4.8 (4 items)
  Lua src: lua-5.4.8\src (63 files)
  LuaRocks: luarocks-3.12.2-windows-64 (2 items)
  Lua Tests: lua-5.4.8-tests (35 items)
[BOOTSTRAP] ✅ Bootstrap complete - subsequent tests can run safely
```

### Test Runner Summary
```
🎉 All tests passed! ✅
📊 Ran 45 tests successfully
```

## Troubleshooting

### Common Issues

**"No internet connection"**
- Ensure internet connectivity
- Check firewall/proxy settings
- Verify download URLs in `build_config.txt`

**"Lua directory not found"**
- Run the bootstrap test: `python run_tests.py`
- Or run specific bootstrap: `python -m unittest tests.test_download.TestDownloadBootstrap.test_aaa_bootstrap_download_and_extract_all_files -v`

**"Tests taking too long"**
- First run downloads files (takes ~2 minutes)
- Subsequent runs are fast (< 1 second for bootstrap)
- Use `-v` flag to see detailed progress

### Getting Help

1. **Run the bootstrap test** first to ensure all dependencies are available
2. **Check error messages** - they include specific troubleshooting steps
3. **Verify network connectivity** for download-related issues
4. **Use verbose mode** (`-v`) to see detailed test progress

## Test Architecture

### Bootstrap Flow
```
1. TestDownloadBootstrap.test_aaa_bootstrap_download_and_extract_all_files
   ├─ Check if files/directories already exist
   ├─ Download files if needed (with validation)
   ├─ Extract files if needed (with validation)
   └─ Verify complete directory structure

2. All other tests run (depend on bootstrap)
   ├─ Skip gracefully if bootstrap failed
   ├─ Use downloaded/extracted files
   └─ Test actual functionality
```

### Test Independence
- Each test class is independent and can be run separately
- Tests clean up their own temporary modifications
- Bootstrap test is the only persistent setup
- No test depends on the execution order of other tests (except bootstrap)

### Error Propagation
- Bootstrap failures stop dependent tests with clear messages
- Individual test failures don't affect other tests
- Network issues are handled gracefully with skips
- All errors include specific troubleshooting guidance

The test suite can be expanded to include:
- **Build execution tests**: Actually run the build scripts (requires MSVC)
- **Full integration tests**: Complete download → extract → setup → build → install workflow
- **Cross-version tests**: Testing with different Lua/LuaRocks versions
- **Performance tests**: Download speed, cache efficiency, large file handling
