# TODO - Lua MSVC Build System

This document tracks planned improvements and future development tasks for the Lua MSVC Build System.

## 🧪 Testing Enhancements

### Build Script Testing
- [ ] **Add tests for build.py script**
  - Test static vs DLL build functionality
  - Test debug vs release build configurations
  - Test build error handling and validation
  - Test build output verification
  - Test integration with setup_build.py workflow

- [ ] **Add tests for setup.py script**
  - Test all-in-one build workflow (static/DLL)
  - Test custom prefix directory handling
  - Test integration with download, build, and installation steps
  - Test command-line argument parsing and validation
  - Test error handling for missing dependencies
  - Test cleanup and recovery scenarios

## 📊 Documentation & Coverage

### Test Coverage Documentation
- [ ] **Create comprehensive test coverage document**
  - Document current test coverage status for all modules
  - Include coverage for build.py and setup.py once tests are added
  - Maintain coverage metrics and statistics
  - Document test categories and their purpose
  - Include examples of test output and validation
  - Create coverage reports and analysis
  - Update coverage documentation as new tests are added

## 🏗️ Architecture Support

### Multi-Platform Build Support
- [ ] **Check x86 platform support for build batch scripts**
  - Review build-static.bat for x86 compatibility
  - Review build-static-debug.bat for x86 compatibility
  - Review build-dll.bat for x86 compatibility
  - Review build-dll-debug.bat for x86 compatibility
  - Test compiler flags and settings for 32-bit builds
  - Validate library naming conventions for x86 builds
  - Update documentation for x86 build instructions

## 🔍 Developer Experience Improvements

### Visual Studio Auto-Discovery
- [ ] **Implement automatic Visual Studio installation detection**
  - Replace manual environment setup requirement in build.py
  - Detect Visual Studio installation paths automatically
  - Support multiple VS versions (2019, 2022, future versions)
  - Auto-detect available architectures (x86, x64, ARM)
  - Implement fallback mechanisms for manual configuration
  - Provide clear error messages when VS is not found
  - Update documentation to reflect automatic detection

## 🎯 Future Projects

### LuaEnv Project
- [ ] **Implement LuaEnv - Lua Environment Management System**
  - Create environment management similar to Python's virtualenv/conda
  - Support multiple Lua versions and isolated environments
  - Implement environment switching and activation
  - Package management per environment
  - Integration with existing build system
  - Cross-platform support (Windows, Linux, macOS)
  - CLI interface for environment management
  - Documentation and user guides

## 📋 Implementation Notes

### Testing Priority
1. **build.py tests** - Critical for build reliability
2. **setup.py tests** - Important for end-to-end workflow validation
3. **Test coverage documentation** - Track and maintain coverage metrics
4. Integration tests for the complete build pipeline

### Architecture Support Priority
1. **x86 compatibility review** - Ensure current scripts work correctly
2. **Cross-architecture testing** - Validate builds on different platforms
3. **Documentation updates** - Clear instructions for all supported architectures

### Auto-Discovery Implementation
1. **Research VS detection methods** - Registry, vswhere.exe, environment variables
2. **Design fallback strategy** - Manual override options
3. **Update build.py workflow** - Seamless integration
4. **Comprehensive testing** - Multiple VS installations and configurations

### LuaEnv Implementation
1. **Design environment structure** - Directory layout and configuration
2. **Research existing solutions** - Learn from Python virtualenv, Node.js nvm, etc.
3. **Define CLI interface** - Commands for create, activate, deactivate, list environments
4. **Implement core functionality** - Environment creation and switching
5. **Package management integration** - LuaRocks per-environment support
6. **Cross-platform compatibility** - Windows, Linux, macOS support

## 🎯 Success Criteria

### Testing
- [ ] All build.py functionality covered by automated tests
- [ ] All setup.py workflows validated by test suite
- [ ] Comprehensive test coverage documentation maintained
- [ ] Test coverage reports available
- [ ] CI/CD integration for automated testing

### Architecture Support
- [ ] x86 builds work correctly on 32-bit and 64-bit systems
- [ ] Clear documentation for all supported architectures
- [ ] Automated testing for multiple architectures

### Auto-Discovery
- [ ] Build.py automatically detects and configures Visual Studio
- [ ] No manual environment setup required for most users
- [ ] Clear error messages and troubleshooting for edge cases
- [ ] Backwards compatibility with manual configuration

### LuaEnv Project
- [ ] Multiple Lua environments can be created and managed
- [ ] Seamless environment switching and activation
- [ ] Isolated package management per environment
- [ ] Cross-platform compatibility (Windows, Linux, macOS)
- [ ] Integration with existing build system
- [ ] Comprehensive CLI interface and documentation

## 📅 Estimated Timeline

- **Testing Enhancements**: 1-2 weeks
- **Architecture Support Review**: 3-5 days
- **Visual Studio Auto-Discovery**: 1-2 weeks
- **LuaEnv Project**: 4-6 weeks (major project)

## 🔗 Related Files

- `build.py` - Main build script requiring VS auto-discovery
- `setup.py` - Master script needing comprehensive testing
- `build_scripts/*.bat` - Batch scripts requiring x86 review
- `tests/` - Directory for new test implementations
- `tests/BUILD_SCRIPT_TEST_COVERAGE.md` - Existing coverage documentation for setup_build.py
- `run_tests.py` - Test runner to include new test categories
- `luaenv-design.md` - Design document for LuaEnv project
- `luaenv-*.md` - Additional LuaEnv project documentation and concepts

---

## To read:

Intersting blogpost about implementations of a luaenv system: [LuaEnv Blog Post](https://www.frank-mitchell.com/projects/luaenv/)



**Last Updated**: June 30, 2025
**Status**: Planning Phase
