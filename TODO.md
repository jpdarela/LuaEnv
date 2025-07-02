# TODO - Lua MSVC Build System

## 📅 July 1, 2025 - F# CLI Thin Wrapper Implementation


# TESTS

- We need to refactor the backend tests to ensure they are compatible with the new UUID-based registry system.
- We should also ensure that the F# CLI tests cover all delegated commands and error handling scenarios.

- Include tests for:
   - registry operations (list, install, remove)
     - regidtry.json structure validation
   - downloading and extraction of Lua versions
    - download registry validation
   - build and installation processes
    - lua tests
   - configuration file generation

## To read:

Interesting blogpost about implementations of a luaenv system: [LuaEnv Blog Post](https://www.frank-mitchell.com/projects/luaenv/)

---

**Last Updated**: July 1, 2025
**Status**: Ready for F# CLI Implementation


TODO ADAPT THE DOWNLOAD OF LUAROCKS 32 BIT FOR X86 LUA BUILDS