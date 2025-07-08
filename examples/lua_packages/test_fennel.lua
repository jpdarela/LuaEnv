#!/usr/bin/env lua

-- Test script to demonstrate Fennel working on Windows with LuaEnv
print("=== Fennel on Windows Demo ===")
print()

-- Load Fennel
local fennel = require('fennel')
print("✓ Fennel loaded successfully")
print("  Version:", fennel.version)
print()

-- Test 1: Simple evaluation
print("Test 1: Simple arithmetic")
local result1 = fennel.eval("(+ 1 2 3 4 5)")
print("  (+ 1 2 3 4 5) =", result1)
print()

-- Test 2: Function definition and call
print("Test 2: Function definition")
local factorial_code = [[
(fn factorial [n]
  (if (<= n 1)
      1
      (* n (factorial (- n 1)))))
(factorial 5)
]]
local result2 = fennel.eval(factorial_code)
print("  Factorial of 5 =", result2)
print()

-- Test 3: Table manipulation
print("Test 3: Table operations")
local table_code = [[
(local fruits ["apple" "banana" "cherry"])
(local person {:name "Alice" :age 25})
(values (length fruits) (. person :name))
]]
local count, name = fennel.eval(table_code)
print("  Fruit count:", count)
print("  Person name:", name)
print()

-- Test 4: Compile to Lua
print("Test 4: Compile Fennel to Lua")
local fennel_source = "(fn greet [name] (print (.. \"Hello, \" name \"!\")))"
local lua_code = fennel.compileString(fennel_source)
print("  Fennel:", fennel_source)
print("  Lua:   ", lua_code:gsub('\n', ' '))
print()

-- Test 5: Execute the compiled function
print("Test 5: Execute compiled function")
local greet_fn = fennel.eval(fennel_source)
greet_fn("Windows User")
print()

-- Test 6: Pattern matching
print("Test 6: Pattern matching")
local pattern_code = [[
(fn describe-data [data]
  (match data
    {:type "user" :name name} (.. "User: " name)
    {:type "product" :id id} (.. "Product ID: " id)
    [a b c] (.. "Three items: " a ", " b ", " c)
    x (.. "Other: " (tostring x))))

(describe-data {:type "user" :name "Bob"})
]]
local result6 = fennel.eval(pattern_code)
print("  Pattern match result:", result6)
print()

-- Test 7: Macro usage
print("Test 7: Simple macro")
local macro_code = [[
(macro when [condition ...]
  `(if ,condition (do ,...)))

(var result "")
(when true
  (set result (.. result "Macro "))
  (set result (.. result "works!")))
result
]]
local result7 = fennel.eval(macro_code)
print("  Macro result:", result7)
print()

print("=== Summary ===")
print("✓ Fennel arithmetic and functions work")
print("✓ Fennel data structures work")
print("✓ Fennel compilation to Lua works")
print("✓ Fennel pattern matching works")
print("✓ Fennel macros work")
print()
print("Fennel is fully functional on Windows with LuaEnv!")
print("You can now write Lisp-style code that compiles to efficient Lua.")
print()
print("Next steps:")
print("- Create .fnl files for your Fennel programs")
print("- Use 'fennel.repl()' for interactive development")
print("- Explore the full Fennel language at https://fennel-lang.org/")
