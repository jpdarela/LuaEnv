#!/usr/bin/env lua

-- Simple script to start the Fennel REPL
print("=== Starting Fennel REPL ===")
print()
print("Welcome to the Fennel REPL on Windows!")
print("You can now write Fennel code interactively.")
print()
print("Try these examples:")
print("  (+ 1 2 3)")
print("  (fn greet [name] (print (.. \"Hello, \" name)))")
print("  (greet \"REPL User\")")
print("  {:name \"Alice\" :age 30}")
print()
print("Type Ctrl+C to exit the REPL.")
print()

local fennel = require('fennel')
fennel.repl()
