;; hello.fnl - A simple Fennel program demonstrating various features

;; Simple function definitions
(fn greet [name]
  "Greets someone by name"
  (print (.. "Hello, " name " from Fennel!")))

(fn square [x]
  "Returns the square of a number"
  (* x x))

(fn sum [...]
  "Sums all provided arguments"
  (var total 0)
  (each [_ v (ipairs [...])]
    (set total (+ total v)))
  total)

;; Working with tables
(local fruits ["apple" "banana" "cherry" "date"])
(local person {:name "Alice" :age 25 :job "Developer"})

(fn print-fruits []
  "Prints all fruits in the list"
  (print "Available fruits:")
  (each [i fruit (ipairs fruits)]
    (print (.. "  " i ". " fruit))))

(fn describe-person [p]
  "Describes a person"
  (print (.. (. p :name) " is " (. p :age) " years old and works as a " (. p :job))))

;; Pattern matching example
(fn classify [data]
  "Classifies different types of data"
  (match data
    {:type "user" :name name :active true} (.. "Active user: " name)
    {:type "user" :name name :active false} (.. "Inactive user: " name)
    {:type "product" :id id :price price} (.. "Product " id " costs $" price)
    [a b c] (.. "Triple: " a ", " b ", " c)
    n (if (= (type n) "number")
          (.. "Number: " n)
          (.. "Other: " (tostring n)))))

;; Control flow
(fn fibonacci [n]
  "Calculates the nth Fibonacci number"
  (if (<= n 1)
      n
      (+ (fibonacci (- n 1)) (fibonacci (- n 2)))))

;; Demonstration function
(fn demo []
  "Runs a demonstration of Fennel features"
  (print "=== Fennel Demo Program ===")
  (print)

  ;; Basic functions
  (greet "Windows User")
  (print (.. "Square of 7: " (square 7)))
  (print (.. "Sum of 1,2,3,4,5: " (sum 1 2 3 4 5)))
  (print)

  ;; Tables
  (print-fruits)
  (print)
  (describe-person person)
  (print)

  ;; Pattern matching
  (print "Pattern matching examples:")
  (print (.. "  " (classify {:type "user" :name "Bob" :active true})))
  (print (.. "  " (classify {:type "product" :id "A123" :price 29.99})))
  (print (.. "  " (classify [1 2 3])))
  (print (.. "  " (classify 42)))
  (print)

  ;; Fibonacci
  (print "Fibonacci sequence (first 10 numbers):")
  (for [i 0 9]
    (print (.. "  F(" i ") = " (fibonacci i))))
  (print)

  (print "Demo complete!"))

;; Export the functions for use in Lua
{:greet greet
 :square square
 :sum sum
 :print-fruits print-fruits
 :describe-person describe-person
 :classify classify
 :fibonacci fibonacci
 :demo demo
 :fruits fruits
 :person person}
