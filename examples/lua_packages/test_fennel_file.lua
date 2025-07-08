#!/usr/bin/env lua

-- Script to demonstrate loading and using Fennel files (.fnl)
print("=== Loading Fennel Files Demo ===")
print()

local fennel = require('fennel')

-- Add Fennel to the package searchers so we can require .fnl files
table.insert(package.searchers or package.loaders, fennel.searcher)

-- Now we can require Fennel files directly!
print("Loading hello.fnl...")
local hello = require('hello')
print("✓ Successfully loaded hello.fnl")
print()

-- Run the demo function from the Fennel file
hello.demo()

print()
print("=== Individual Function Tests ===")
print()

-- Test individual functions
print("Testing individual functions:")
print("  greet('Lua User'):")
hello.greet("Lua User")

print("  square(8):", hello.square(8))
print("  sum(10, 20, 30):", hello.sum(10, 20, 30))
print("  fibonacci(8):", hello.fibonacci(8))

print()
print("  Pattern matching tests:")
print("   ", hello.classify({type = "user", name = "Charlie", active = true}))
print("   ", hello.classify({type = "product", id = "X999", price = 15.50}))
print("   ", hello.classify({10, 20, 30}))

print()
print("✓ All Fennel functions work perfectly!")
print("✓ You can now write Fennel code in .fnl files and use them in Lua!")
print()
print("This demonstrates that Fennel integrates seamlessly with Lua on Windows.")
