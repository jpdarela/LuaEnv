# Fennel on Windows with LuaEnv

Fennel is a programming language that brings together the speed, simplicity, and reach of Lua with the flexibility of a Lisp syntax and macro system.

## Installation

Fennel can be easily installed using LuaRocks in your LuaEnv environment:

```powershell
luaenv activate myenv  # Activate your LuaEnv environment
luarocks install fennel 1.4.2-1 #
```

## Basic Usage

### 1. Using Fennel as a Library in Lua

```lua
local fennel = require('fennel')

-- Compile Fennel code to Lua
local fennel_code = "(+ 1 2 3)"
local lua_code = fennel.compile_string(fennel_code)
print("Compiled Lua:", lua_code)

-- Evaluate Fennel code directly
local result = fennel.eval("(+ 1 2 3)")
print("Result:", result)

-- Compile and run more complex Fennel
local complex_fennel = [[
  (fn greet [name]
    (print (.. "Hello, " name "!")))
  (greet "World")
]]

fennel.eval(complex_fennel)
```

### 2. Working with Fennel Files

Create a file `hello.fnl`:
```fennel
;; hello.fnl - A simple Fennel program
(fn greet [name]
  (print (.. "Hello, " name " from Fennel!")))

(fn add [a b]
  (+ a b))

;; Export functions for use in Lua
{:greet greet
 :add add}
```

Load it in Lua:
```lua
local fennel = require('fennel')

-- Add Fennel file search path
table.insert(package.loaders or package.searchers, fennel.searcher)

-- Now you can require Fennel files directly
local hello = require('hello')  -- loads hello.fnl

hello.greet("Windows User")
print("2 + 3 =", hello.add(2, 3))
```

### 3. Interactive REPL

You can also use Fennel interactively:

```lua
local fennel = require('fennel')

-- Start Fennel REPL
fennel.repl()
```

## Fennel Language Features

### Functions and Variables
```fennel
;; Define variables
(local name "World")
(local numbers [1 2 3 4 5])

;; Define functions
(fn square [x] (* x x))
(fn sum [...]
  (var total 0)
  (each [_ v (ipairs [...])]
    (set total (+ total v)))
  total)

;; Use them
(print (square 5))
(print (sum 1 2 3 4 5))
```

### Tables and Data Structures
```fennel
;; Sequential tables (arrays)
(local fruits ["apple" "banana" "orange"])

;; Associative tables (dictionaries)
(local person {:name "Alice" :age 30 :city "Seattle"})

;; Access and manipulation
(print (. person :name))
(tset person :job "Developer")
```

### Control Flow
```fennel
;; Conditionals
(if (> 5 3)
    (print "5 is greater than 3")
    (print "Math is broken"))

;; Pattern matching
(match [1 2 3]
  [a b c] (print (.. "Got: " a " " b " " c))
  _ (print "No match"))

;; Loops
(for [i 1 5]
  (print (.. "Count: " i)))

(each [k v (pairs {:a 1 :b 2 :c 3})]
  (print (.. k " = " v)))
```

### Macros (Advanced)
```fennel
;; Define a simple macro
(macro when [condition ...]
  `(if ,condition
     (do ,...)))

;; Use the macro
(when (> 10 5)
  (print "10 is indeed greater than 5")
  (print "Macros are powerful!"))
```

## Integration with Lua Libraries

Fennel works seamlessly with existing Lua libraries:

```fennel
;; Using LuaSocket (if installed)
(local socket (require :socket))

;; Using other Lua modules
(local json (require :json))  ; if you have a JSON library
(local os (require :os))

;; All Lua standard library is available
(print (os.date))
```

## Advantages of Fennel

1. **Lisp Syntax**: Powerful macro system and functional programming features
2. **Lua Compatibility**: Compiles to readable Lua, works with all Lua libraries
3. **No Runtime Overhead**: Compiles to efficient Lua code
4. **Interactive Development**: REPL for rapid prototyping
5. **Pattern Matching**: Powerful destructuring capabilities
6. **Immutability Focus**: Encourages functional programming patterns

## Getting Started

1. **Install Fennel**: `luarocks install fennel`
2. **Try the examples**: Create `.fnl` files and experiment
3. **Read the documentation**: Visit https://fennel-lang.org/
4. **Join the community**: Fennel has an active community for help and discussion

## Tips for Windows Users

- Fennel files use `.fnl` extension
- The REPL works great in PowerShell or Command Prompt
- All Lua tools and libraries work with compiled Fennel code
- Use your favorite text editor - many have Fennel syntax highlighting
- Consider using VS Code with Fennel extensions for development

Fennel brings the elegance of Lisp to the simplicity and ubiquity of Lua, making it perfect for scripting, game development, configuration, and more!
