# Chapter 2: Motoko Fundamentals

Motoko is a strongly typed, functional-first programming language specifically designed for the Internet Computer. Its syntax draws inspiration from JavaScript, Swift, and Rust, but its semantics are meticulously crafted to leverage the unique capabilities and constraints of the Internet Computer Protocol (ICP). This chapter provides a comprehensive introduction to Motoko's fundamental concepts, syntax, and programming patterns.

Before building sophisticated decentralized applications, you must master Motoko's core building blocks. This chapter walks through the essential language features that form the foundation of all Motoko programs: from basic syntax and type systems to advanced concepts like actors, asynchronous programming, and orthogonal persistence.

## 2.1 Hello, World!

Every programming journey begins with a simple "Hello, World!" program. In Motoko, this introduces you to the actor model and basic output.

```js
actor {
    public func greet(name : Text) : async Text {
        return "Hello, " # name # "!";
    };
};
```

This minimal program demonstrates several key concepts:
- **Actor**: The fundamental unit of computation on the Internet Computer
- **Public function**: Exposed as a canister endpoint
- **Async**: All public functions must return async values
- **Text concatenation**: Using the `#` operator


## 2.2 Basic Syntax

Motoko's syntax is designed to be familiar yet precise. Understanding these foundational elements is crucial for writing correct and efficient code.

### 2.2.1 Comments

Motoko supports both single-line and multi-line comments:

```js
// This is a single-line comment

/* This is a 
   multi-line comment */

/// Documentation comment for functions
public func example() : async () {};
```

### 2.2.2 Expressions and Blocks

Motoko is an **expression-oriented language**—nearly everything evaluates to a value. Code blocks return the value of their last expression.

```js
let result = {
    let x = 10;
    let y = 20;
    x + y  // Returns 30 (no semicolon!)
};

let noValue = {
    let x = 10;
    let y = 20;
    x + y;  // Returns () because of semicolon
};
```

**The Semicolon Rule**: The semicolon `;` is a separator, not a terminator. If the last expression in a block ends with a semicolon, the block returns `()` (Unit type, similar to void).

### 2.2.3 Identifiers and Naming

- **Variables and functions**: Use camelCase (`myVariable`, `calculateTotal`)
- **Types and modules**: Use PascalCase (`UserAccount`, `HashMapModule`)
- **Constants**: Can use UPPER_CASE by convention
- **Reserved keywords**: `actor`, `async`, `await`, `break`, `case`, `catch`, `class`, `continue`, `debug`, `else`, `false`, `for`, `func`, `if`, `in`, `import`, `let`, `loop`, `module`, `null`, `object`, `public`, `private`, `return`, `shared`, `switch`, `true`, `try`, `type`, `var`, `while`

```js
let userName = "Alice";        // Valid
let user_name = "Bob";         // Valid
let MAX_RETRIES = 3;           // Valid
// let 123abc = "Invalid";     // Invalid: cannot start with digit
```

## 2.3 Types

Motoko's type system is its greatest strength, providing compile-time guarantees that prevent entire categories of bugs. The language is **strongly typed** and uses **type inference** to reduce verbosity while maintaining safety.

### 2.3.1 Primitive Types

#### Numeric Types

```js
// Natural numbers (non-negative, unbounded)
let count : Nat = 42;
let large : Nat = 1_000_000_000;

// Integers (signed, unbounded)
let temperature : Int = -15;
let delta : Int = +100;

// Fixed-width unsigned integers
let byte : Nat8 = 255;          // 0 to 255
let port : Nat16 = 8080;        // 0 to 65,535
let id : Nat32 = 4_294_967_295; // 0 to 2^32-1
let bigId : Nat64 = 18_446_744_073_709_551_615;

// Fixed-width signed integers
let smallInt : Int8 = -128;     // -128 to 127
let medInt : Int16 = -32_768;   // -32,768 to 32,767
let normalInt : Int32 = -2_147_483_648;
let bigInt : Int64 = -9_223_372_036_854_775_808;

// Floating-point (64-bit IEEE 754)
let pi : Float = 3.14159;
let scientific : Float = 1.23e-4;
```

**Key Points**:
- `Nat` and `Int` are **unbounded** (arbitrary precision)
- Use fixed-width types (`Nat32`, `Int64`) for performance-critical code
- Overflow behavior: unbounded types never overflow; fixed-width types trap

#### Boolean Type

```js
let isActive : Bool = true;
let hasPermission : Bool = false;

let result = isActive and hasPermission;  // false
let canProceed = isActive or hasPermission;  // true
let inverted = not isActive;  // false
```

#### Text and Character Types

```js
// Text (UTF-8 strings)
let greeting : Text = "Hello, Motoko!";
let emoji : Text = "🚀";
let multiline : Text = "Line 1\nLine 2\nLine 3";

// Character (single Unicode scalar value)
let letter : Char = 'M';
let unicode : Char = '∑';

// Text concatenation
let fullName = "Alice" # " " # "Smith";  // "Alice Smith"
```

#### Special Types

```js
// Blob (immutable byte arrays)
let data : Blob = "\00\01\02\03";
let empty : Blob = "";

// Principal (unique identifiers for users and canisters)
let user : Principal = Principal.fromText("aaaaa-aa");
let canisterId : Principal = Principal.fromActor(myActor);

// Unit type (like void)
let nothing : () = ();
```

### 2.3.2 Composite Types

#### Arrays

Arrays in Motoko are **immutable by default** and have fixed size.

```js
// Immutable array
let numbers : [Nat] = [1, 2, 3, 4, 5];
let names : [Text] = ["Alice", "Bob", "Charlie"];
let empty : [Int] = [];

// Array access
let first = numbers[0];  // 1
let last = numbers[numbers.size() - 1];  // 5

// Mutable array (requires explicit initialization)
let mutable : [var Nat] = [var 1, 2, 3];
mutable[0] := 10;  // Now [10, 2, 3]

// Array initialization
let zeros = Array.init<Nat>(100, 0);  // 100 zeros
let indices = Array.tabulate<Nat>(10, func(i) = i);  // [0,1,2,...,9]
```

#### Tuples

Tuples are anonymous records with positional fields.

```js
// Simple tuple
let coordinates : (Float, Float) = (10.5, 20.3);
let person : (Text, Nat) = ("Alice", 30);

// Accessing tuple elements
let x = coordinates.0;  // 10.5
let y = coordinates.1;  // 20.3

// Pattern matching with tuples
let (name, age) = person;

// Nested tuples
let complex : (Nat, (Text, Bool)) = (42, ("active", true));
```

#### Records

Records are structured types with named fields.

```js
// Type definition
type User = {
    name : Text;
    age : Nat;
    email : Text;
};

// Creating records
let alice : User = {
    name = "Alice";
    age = 30;
    email = "alice@example.com";
};

// Accessing fields
let userName = alice.name;
let userAge = alice.age;

// Record with mutable fields
type Counter = {
    var count : Nat;
    name : Text;
};

let myCounter : Counter = {
    var count = 0;
    name = "Main Counter";
};

myCounter.count := myCounter.count + 1;
```

#### Variants

Variants are tagged unions (sum types), similar to enums in other languages but more powerful.

```js
// Simple variant (enum-like)
type Color = {
    #Red;
    #Green;
    #Blue;
};

let favorite : Color = #Blue;

// Variant with associated data
type Result<T, E> = {
    #Ok : T;
    #Err : E;
};

let success : Result<Nat, Text> = #Ok(42);
let failure : Result<Nat, Text> = #Err("Division by zero");

// Complex variant
type PaymentMethod = {
    #Cash;
    #CreditCard : { number : Text; cvv : Nat };
    #Crypto : { wallet : Principal; amount : Nat };
};

let payment = #CreditCard({
    number = "1234-5678-9012-3456";
    cvv = 123;
});
```

#### Options

The `Option` type represents values that may or may not exist, eliminating null pointer errors.

```js
// Option type
type OptionalNat = ?Nat;

let hasValue : ?Nat = ?42;
let noValue : ?Nat = null;

// Checking for values
switch (hasValue) {
    case null { Debug.print("No value"); };
    case (?value) { Debug.print("Value: " # Nat.toText(value)); };
};

// Option in records
type User = {
    name : Text;
    email : ?Text;  // Optional email
};

let bob = { name = "Bob"; email = null };
let alice = { name = "Alice"; email = ?"alice@example.com" };
```

### 2.3.3 Function Types

Functions are first-class values with explicit types.

```js
// Function type signature
type MathOperation = (Nat, Nat) -> Nat;

// Function implementation
let add : MathOperation = func(a, b) { a + b };
let multiply : MathOperation = func(a, b) { a * b };

// Higher-order functions
func applyOperation(op : MathOperation, x : Nat, y : Nat) : Nat {
    op(x, y);
};

let result = applyOperation(add, 5, 3);  // 8

// Generic function types
type Transformer<A, B> = A -> B;

let toString : Transformer<Nat, Text> = Nat.toText;
```

### 2.3.4 Async Types

Async types represent values that will be available in the future, essential for inter-canister calls.

```js
// Async function
public func fetchData() : async Nat {
    // Simulated async operation
    return 42;
};

// Calling async functions
public func processData() : async Text {
    let data = await fetchData();
    return "Received: " # Nat.toText(data);
};
```

### 2.3.5 Generic Types

Generics enable code reuse while maintaining type safety.

```js
// Generic function
func identity<T>(x : T) : T {
    x;
};

let num = identity<Nat>(42);
let text = identity<Text>("hello");

// Generic type
type Container<T> = {
    value : T;
    isEmpty : Bool;
};

let numContainer : Container<Nat> = {
    value = 42;
    isEmpty = false;
};

// Generic with constraints
func compare<T>(a : T, b : T, eq : (T, T) -> Bool) : Bool {
    eq(a, b);
};
```

## 2.4 Declarations

Declarations introduce new names into scope. Motoko distinguishes between immutable and mutable bindings.

### 2.4.1 Immutable Declarations (`let`)

The default and recommended way to declare values.

```js
let name = "Alice";
let age = 30;
let isActive = true;

// Type inference
let inferred = 42;  // Type: Nat

// Explicit type annotation
let explicit : Int = -42;

// Multiple bindings (pattern matching)
let (x, y) = (10, 20);
let {name = userName; age = userAge} = {name = "Bob"; age = 25};
```

### 2.4.2 Mutable Declarations (`var`)

Use `var` for values that need to change. Mutation uses the `:=` operator.

```js
var counter = 0;
counter := counter + 1;  // 1
counter := counter * 2;  // 2

// Compound assignment
var total = 100;
total += 50;   // 150
total -= 30;   // 120
total *= 2;    // 240
total /= 4;    // 60

// Mutable in data structures
type Account = {
    var balance : Nat;
    owner : Text;
};

let account = {
    var balance = 1000;
    owner = "Alice";
};

account.balance := account.balance - 100;
```

### 2.4.3 Function Declarations

Functions can be declared in multiple ways.

```js
// Named function (private by default)
func add(a : Nat, b : Nat) : Nat {
    a + b;
};

// Public function (within actor)
public func publicAdd(a : Nat, b : Nat) : async Nat {
    async (a + b);
};

// Shared function (accessible from other canisters)
public shared func sharedAdd(a : Nat, b : Nat) : async Nat {
    a + b;
};

// Query function (fast, read-only)
public shared query func getBalance() : async Nat {
    balance;
};

// Anonymous function (lambda)
let multiply = func(a : Nat, b : Nat) : Nat {
    a * b;
};

// Function with generic parameters
func map<A, B>(arr : [A], f : A -> B) : [B] {
    Array.map<A, B>(arr, f);
};
```

### 2.4.4 Type Declarations

Define custom types for better code organization.

```js
// Type alias
type UserId = Principal;
type Balance = Nat;

// Record type
type Account = {
    id : UserId;
    balance : Balance;
    isActive : Bool;
};

// Variant type
type TransactionStatus = {
    #Pending;
    #Completed;
    #Failed : Text;
};

// Generic type
type Result<T, E> = {
    #Ok : T;
    #Err : E;
};
```

## 2.5 Control Flow

Motoko provides familiar control flow constructs, all designed as expressions that return values.

### 2.5.1 Conditionals

The `if-else` construct is an expression that must return the same type from both branches.

```js
// Simple conditional
let status = if (balance > 0) "Active" else "Inactive";

// Multi-line conditional
let message = if (age < 18) {
    "Minor";
} else if (age < 65) {
    "Adult";
} else {
    "Senior";
};

// Conditional with side effects
if (isValid) {
    processData();
} else {
    logError();
};

// Nested conditionals
let category = if (score >= 90) {
    "Excellent";
} else {
    if (score >= 75) "Good" else "Needs Improvement";
};
```

### 2.5.2 Loops

Motoko supports several looping constructs for iteration.

#### For Loops

Iterate over collections using iterators.

```js
import Iter "mo:base/Iter";

// Iterate over array
let numbers = [1, 2, 3, 4, 5];
for (num in numbers.vals()) {
    Debug.print(Nat.toText(num));
};

// Iterate with index
for ((index, value) in numbers.vals() |> Iter.enumerate(_)) {
    Debug.print(Nat.toText(index) # ": " # Nat.toText(value));
};

// Iterate over range
for (i in Iter.range(0, 9)) {
    Debug.print(Nat.toText(i));  // 0 to 9
};

// Iterate over text characters
let text = "Hello";
for (char in text.chars()) {
    Debug.print(Char.toText(char));
};
```

#### While Loops

Execute code while a condition is true.

```js
var counter = 0;
while (counter < 5) {
    Debug.print(Nat.toText(counter));
    counter += 1;
};

// Infinite loop with break
var running = true;
while (running) {
    // Do something
    if (shouldStop) {
        running := false;
    };
};
```

#### Loop-While

Execute code at least once, then check condition.

```js
var attempts = 0;
loop {
    attempts += 1;
    Debug.print("Attempt: " # Nat.toText(attempts));
} while (attempts < 3);
```

#### Loop with Break and Continue

```js
// Infinite loop with break
var count = 0;
loop {
    count += 1;
    if (count > 10) {
        break;
    };
    if (count % 2 == 0) {
        continue;  // Skip even numbers
    };
    Debug.print(Nat.toText(count));
};
```

### 2.5.3 Switch and Pattern Matching

The `switch` statement provides exhaustive pattern matching, ensuring all cases are handled.

```js
// Basic switch on variant
type Status = { #Active; #Suspended; #Closed };

func describeStatus(status : Status) : Text {
    switch (status) {
        case (#Active) "Account is active";
        case (#Suspended) "Account is suspended";
        case (#Closed) "Account is closed";
    };
};

// Switch with data extraction
type Result = { #Ok : Nat; #Err : Text };

func handleResult(result : Result) : Text {
    switch (result) {
        case (#Ok(value)) "Success: " # Nat.toText(value);
        case (#Err(message)) "Error: " # message;
    };
};

// Switch on Option
func processOption(opt : ?Nat) : Nat {
    switch (opt) {
        case null 0;
        case (?value) value * 2;
    };
};

// Switch on tuples
func describe(point : (Int, Int)) : Text {
    switch (point) {
        case (0, 0) "Origin";
        case (x, 0) "X-axis at " # Int.toText(x);
        case (0, y) "Y-axis at " # Int.toText(y);
        case (x, y) "Point at (" # Int.toText(x) # ", " # Int.toText(y) # ")";
    };
};

// Complex pattern matching
type Shape = {
    #Circle : { radius : Float };
    #Rectangle : { width : Float; height : Float };
    #Triangle : { base : Float; height : Float };
};

func area(shape : Shape) : Float {
    switch (shape) {
        case (#Circle({radius})) 3.14159 * radius * radius;
        case (#Rectangle({width; height})) width * height;
        case (#Triangle({base; height})) 0.5 * base * height;
    };
};
```

## 2.6 Actors and Async Data

Actors are the fundamental building blocks of Internet Computer applications. They encapsulate state and provide asynchronous message-passing interfaces.

### 2.6.1 Understanding Actors

An actor in Motoko represents a **canister**—a smart contract running on the Internet Computer. Each actor:
- Has its own isolated state
- Communicates asynchronously with other actors
- Processes messages one at a time (no concurrency issues)
- Can be upgraded while preserving state

```js
// Simple actor
actor Counter {
    var count : Nat = 0;
    
    public func increment() : async Nat {
        count += 1;
        return count;
    };
    
    public query func get() : async Nat {
        return count;
    };
};
```

### 2.6.2 Public and Private Functions

```js
actor MyActor {
    var privateState : Nat = 0;
    
    // Private function (not exposed)
    func privateHelper(n : Nat) : Nat {
        n * 2;
    };
    
    // Public shared function (update call - goes through consensus)
    public shared func updateState(n : Nat) : async Nat {
        privateState := privateHelper(n);
        return privateState;
    };
    
    // Public query function (read-only - fast, no consensus)
    public query func getState() : async Nat {
        return privateState;
    };
};
```

**Key Differences**:
- **Update calls** (`public shared func`): Modify state, go through consensus, take ~2 seconds
- **Query calls** (`public query func`): Read-only, do not modify state, return in milliseconds
- **Private functions** (`func`): Only callable within the actor, synchronous

### 2.6.3 Async and Await

All inter-actor communication is asynchronous. Use `await` to wait for async results.

```js
actor AsyncExample {
    // Call another actor
    public func callOtherActor() : async Nat {
        let otherActor = actor("canister-id") : actor {
            getValue : () -> async Nat;
        };
        
        let result = await otherActor.getValue();
        return result * 2;
    };
    
    // Multiple async calls
    public func multipleCallsSequential() : async Nat {
        let actor1 = actor("id-1") : actor { get : () -> async Nat };
        let actor2 = actor("id-2") : actor { get : () -> async Nat };
        
        let val1 = await actor1.get();
        let val2 = await actor2.get();
        return val1 + val2;
    };
    
    // Error handling with async
    public func safeCall() : async ?Nat {
        try {
            let other = actor("id") : actor { get : () -> async Nat };
            let result = await other.get();
            return ?result;
        } catch (e) {
            return null;
        };
    };
};
```

### 2.6.4 Actor Classes

Actor classes are templates for creating multiple actor instances.

```js
// Actor class definition
actor class Counter(initValue : Nat) {
    var count = initValue;
    
    public func increment() : async Nat {
        count += 1;
        return count;
    };
    
    public query func get() : async Nat {
        return count;
    };
};

// Usage (in a management canister)
import Counter "counter";

actor Manager {
    public func createCounter(init : Nat) : async Principal {
        let newCounter = await Counter.Counter(init);
        return Principal.fromActor(newCounter);
    };
};
```

### 2.6.5 Caller Identity

Access the caller's principal in shared functions.

```js
import Principal "mo:base/Principal";

actor Auth {
    var owner : Principal = Principal.fromText("aaaaa-aa");
    
    public shared(msg) func setOwner() : async () {
        owner := msg.caller;
    };
    
    public shared(msg) func restrictedAction() : async Text {
        if (msg.caller == owner) {
            return "Access granted";
        } else {
            return "Access denied";
        };
    };
    
    public shared query(msg) func whoAmI() : async Principal {
        return msg.caller;
    };
};
```

## 2.7 Mutable State

Managing mutable state is crucial for building stateful applications. Motoko provides clear semantics for mutation.

### 2.7.1 Mutable Variables

```js
actor StateExample {
    // Mutable scalar
    var counter : Nat = 0;
    var name : Text = "Default";
    var isActive : Bool = true;
    
    // Mutable in records
    type Account = {
        var balance : Nat;
        owner : Principal;
    };
    
    var account : Account = {
        var balance = 1000;
        owner = Principal.fromText("aaaaa-aa");
    };
    
    public func updateBalance(amount : Nat) : async () {
        account.balance += amount;
    };
    
    // Mutable arrays
    var items : [var Nat] = [var 1, 2, 3];
    
    public func updateItem(index : Nat, value : Nat) : async () {
        items[index] := value;
    };
};
```

### 2.7.2 Mutable Collections

Use specialized data structures for efficient mutable collections.

```js
import Buffer "mo:base/Buffer";
import HashMap "mo:base/HashMap";
import Hash "mo:base/Hash";
import Nat "mo:base/Nat";

actor Collections {
    // Dynamic array (Buffer)
    let buffer = Buffer.Buffer<Nat>(0);
    
    public func addItem(item : Nat) : async () {
        buffer.add(item);
    };
    
    public query func getSize() : async Nat {
        buffer.size();
    };
    
    // HashMap (mutable key-value store)
    let map = HashMap.HashMap<Nat, Text>(10, Nat.equal, Hash.hash);
    
    public func putValue(key : Nat, value : Text) : async () {
        map.put(key, value);
    };
    
    public query func getValue(key : Nat) : async ?Text {
        map.get(key);
    };
};
```

### 2.7.3 State Transitions

Pattern for safe state transitions.

```js
actor StateMachine {
    type State = {
        #Idle;
        #Processing;
        #Complete;
        #Failed : Text;
    };
    
    var currentState : State = #Idle;
    
    public func startProcessing() : async Result.Result<(), Text> {
        switch (currentState) {
            case (#Idle) {
                currentState := #Processing;
                #ok(());
            };
            case (_) {
                #err("Cannot start: not in idle state");
            };
        };
    };
    
    public func completeProcessing() : async Result.Result<(), Text> {
        switch (currentState) {
            case (#Processing) {
                currentState := #Complete;
                #ok(());
            };
            case (_) {
                #err("Cannot complete: not processing");
            };
        };
    };
    
    public query func getState() : async State {
        currentState;
    };
};
```

## 2.8 Messaging

Messaging is how actors communicate. Understanding message types and patterns is essential for building robust applications.

### 2.8.1 Update vs Query Messages

```js
actor Messaging {
    var data : Nat = 0;
    
    // Update message: modifies state, goes through consensus (~2s)
    public shared func update(value : Nat) : async () {
        data := value;
    };
    
    // Query message: read-only, fast (~100ms)
    public shared query func query() : async Nat {
        data;
    };
    
    // Composite query (calling other queries)
    public shared composite query func compositeQuery() : async Nat {
        // Can call other query functions
        let result = await query();
        result * 2;
    };
};
```

### 2.8.2 One-way Messages

Use one-way messages when you don't need a response.

```js
actor Logger {
    var logs : [Text] = [];
    
    // One-way message (fire and forget)
    public shared func log(message : Text) : async () {
        // No return value needed
        logs := Array.append(logs, [message]);
    };
};
```

### 2.8.3 Inter-Canister Calls

```js
actor Caller {
    // Define remote actor interface
    type RemoteActor = actor {
        getData : () -> async Nat;
        setData : (Nat) -> async ();
    };
    
    public func callRemote(canisterId : Text) : async Nat {
        let remote : RemoteActor = actor(canisterId);
        
        // Call remote function
        let currentValue = await remote.getData();
        
        // Update remote state
        await remote.setData(currentValue + 1);
        
        return currentValue + 1;
    };
};
```

### 2.8.4 Error Handling in Messages

```js
actor ErrorHandling {
    public func riskyOperation() : async Result.Result<Nat, Text> {
        try {
            let remote = actor("unknown-id") : actor {
                compute : () -> async Nat;
            };
            let result = await remote.compute();
            #ok(result);
        } catch (e) {
            #err("Failed to call remote: " # Error.message(e));
        };
    };
};
```

## 2.9 Modules and Imports

Modules organize code into reusable, composable units. Motoko supports both local modules and package imports.

### 2.9.1 Defining Modules

```js
// MathUtils.mo
module {
    public func add(a : Nat, b : Nat) : Nat {
        a + b;
    };
    
    public func multiply(a : Nat, b : Nat) : Nat {
        a * b;
    };
    
    public func square(n : Nat) : Nat {
        multiply(n, n);
    };
};
```

### 2.9.2 Importing Local Modules

```js
// Main.mo
import MathUtils "./MathUtils";

actor {
    public func calculate() : async Nat {
        let sum = MathUtils.add(5, 3);
        let product = MathUtils.multiply(4, 7);
        return sum + product;
    };
};
```

### 2.9.3 Importing from Base Library

The Motoko base library provides essential utilities.

```js
import Array "mo:base/Array";
import Nat "mo:base/Nat";
import Text "mo:base/Text";
import Debug "mo:base/Debug";
import Iter "mo:base/Iter";
import HashMap "mo:base/HashMap";
import Buffer "mo:base/Buffer";
import Result "mo:base/Result";
import Option "mo:base/Option";
import Principal "mo:base/Principal";

actor Example {
    public func demonstrateBase() : async () {
        // Array operations
        let numbers = [1, 2, 3, 4, 5];
        let doubled = Array.map<Nat, Nat>(numbers, func(n) = n * 2);
        
        // Text operations
        let upper = Text.toUppercase("hello");
        
        // Iteration
        for (n in Iter.range(0, 9)) {
            Debug.print(Nat.toText(n));
        };
    };
};
```

### 2.9.4 Module Patterns

```js
// Nested modules
module OuterModule {
    public module InnerModule {
        public func helper() : Nat { 42 };
    };
    
    public func useInner() : Nat {
        InnerModule.helper() * 2;
    };
};

// Module with private state
module Counter {
    var count : Nat = 0;
    
    public func increment() : Nat {
        count += 1;
        count;
    };
    
    public func get() : Nat {
        count;
    };
};

// Importing specific items
import { map; filter } = "mo:base/Array";
```

## 2.10 Pattern Matching

Pattern matching is one of Motoko's most powerful features, enabling elegant and safe data destructuring.

### 2.10.1 Basic Patterns

```js
// Literal patterns
func isZero(n : Nat) : Bool {
    switch (n) {
        case (0) true;
        case (_) false;  // wildcard
    };
};

// Variable binding
func describe(opt : ?Nat) : Text {
    switch (opt) {
        case null "No value";
        case (?n) "Value: " # Nat.toText(n);
    };
};
```

### 2.10.2 Tuple Patterns

```js
func swapIfNeeded(pair : (Nat, Nat)) : (Nat, Nat) {
    switch (pair) {
        case ((a, b)) if (a > b) (b, a);
        case ((a, b)) (a, b);
    };
};

// Nested tuples
func processNested(data : (Nat, (Text, Bool))) : Text {
    switch (data) {
        case ((n, (s, true))) "Active: " # s # " = " # Nat.toText(n);
        case ((n, (s, false))) "Inactive: " # s;
    };
};
```

### 2.10.3 Record Patterns

```js
type User = {
    name : Text;
    age : Nat;
    isAdmin : Bool;
};

func greetUser(user : User) : Text {
    switch (user) {
        case ({ name; isAdmin = true }) "Hello, Admin " # name;
        case ({ name; age }) if (age < 18) "Hello, young " # name;
        case ({ name }) "Hello, " # name;
    };
};

// Partial record matching
func getUsername(user : User) : Text {
    let { name } = user;
    name;
};
```

### 2.10.4 Variant Patterns

```js
type Result<T, E> = {
    #Ok : T;
    #Err : E;
};

func unwrapOr<T, E>(result : Result<T, E>, default : T) : T {
    switch (result) {
        case (#Ok(value)) value;
        case (#Err(_)) default;
    };
};

// Nested variant matching
type Payment = {
    #Cash : Nat;
    #Card : { number : Text; amount : Nat };
    #Crypto : { token : Text; amount : Nat };
};

func processPayment(payment : Payment) : Text {
    switch (payment) {
        case (#Cash(amount)) "Cash: " # Nat.toText(amount);
        case (#Card({ amount })) "Card: " # Nat.toText(amount);
        case (#Crypto({ token; amount })) token # ": " # Nat.toText(amount);
    };
};
```

### 2.10.5 Array Patterns

```js
func describeList(list : [Nat]) : Text {
    switch (list.size()) {
        case (0) "Empty list";
        case (1) "Single element: " # Nat.toText(list[0]);
        case (_) "Multiple elements, first: " # Nat.toText(list[0]);
    };
};
```

### 2.10.6 Guards

Use guards (`if`) for additional conditions.

```js
func categorize(n : Int) : Text {
    switch (n) {
        case (x) if (x < 0) "Negative";
        case (0) "Zero";
        case (x) if (x > 0 and x <= 10) "Small positive";
        case (_) "Large positive";
    };
};

type Account = {
    balance : Nat;
    isVIP : Bool;
};

func checkWithdrawal(account : Account, amount : Nat) : Bool {
    switch (account) {
        case ({ balance; isVIP = true }) if (balance >= amount) true;
        case ({ balance; isVIP = false }) if (balance >= amount + 10) true;
        case (_) false;
    };
};
```

## 2.11 Error Handling

Robust error handling is critical for production applications. Motoko provides multiple mechanisms for dealing with errors.

### 2.11.1 Try-Catch

Handle runtime errors with try-catch blocks.

```js
import Error "mo:base/Error";

actor ErrorHandling {
    public func divide(a : Nat, b : Nat) : async Result.Result<Nat, Text> {
        try {
            if (b == 0) {
                throw Error.reject("Division by zero");
            };
            #ok(a / b);
        } catch (e) {
            #err(Error.message(e));
        };
    };
    
    public func multipleOperations() : async ?Nat {
        try {
            let step1 = await remoteCall1();
            let step2 = await remoteCall2(step1);
            let step3 = await remoteCall3(step2);
            ?step3;
        } catch (e) {
            Debug.print("Error: " # Error.message(e));
            null;
        };
    };
    
    // Helper functions (example)
    func remoteCall1() : async Nat { 10 };
    func remoteCall2(n : Nat) : async Nat { n * 2 };
    func remoteCall3(n : Nat) : async Nat { n + 5 };
};
```

### 2.11.2 Result Type

Use the `Result` type for explicit error handling.

```js
import Result "mo:base/Result";

type Result<T, E> = Result.Result<T, E>;

actor ResultExample {
    type Error = {
        #NotFound;
        #InvalidInput : Text;
        #Unauthorized;
    };
    
    func validateInput(input : Text) : Result<Text, Error> {
        if (input.size() == 0) {
            return #err(#InvalidInput("Empty input"));
        };
        if (input.size() > 100) {
            return #err(#InvalidInput("Input too long"));
        };
        #ok(input);
    };
    
    func findUser(id : Nat) : Result<User, Error> {
        // Simulated lookup
        if (id == 0) {
            #err(#NotFound);
        } else {
            #ok({ name = "User " # Nat.toText(id); age = 25 });
        };
    };
    
    public func processUser(id : Nat, input : Text) : async Result<Text, Error> {
        switch (validateInput(input)) {
            case (#err(e)) #err(e);
            case (#ok(validInput)) {
                switch (findUser(id)) {
                    case (#err(e)) #err(e);
                    case (#ok(user)) {
                        #ok("Processed " # validInput # " for " # user.name);
                    };
                };
            };
        };
    };
};
```

### 2.11.3 Option Type

Use `Option` for operations that may not return a value.

```js
import Option "mo:base/Option";

actor OptionExample {
    func safeDivide(a : Nat, b : Nat) : ?Nat {
        if (b == 0) {
            null;
        } else {
            ?(a / b);
        };
    };
    
    public func calculate(a : Nat, b : Nat) : async Nat {
        switch (safeDivide(a, b)) {
            case null 0;  // Default value
            case (?result) result;
        };
    };
    
    // Option utilities
    public func demonstrateOption() : async () {
        let maybeValue : ?Nat = ?42;
        
        // Check if value exists
        let exists = Option.isSome(maybeValue);
        
        // Get value or default
        let value = Option.get(maybeValue, 0);
        
        // Map over option
        let doubled = Option.map<Nat, Nat>(maybeValue, func(n) = n * 2);
        
        // Chain operations
        let result = Option.chain<Nat, Nat>(
            maybeValue,
            func(n) = if (n > 0) ?n else null
        );
    };
};
```

### 2.11.4 Assert and Debug

Use assertions for development and invariant checking.

```js
import Debug "mo:base/Debug";

actor Assertions {
    public func criticalOperation(value : Nat) : async () {
        // Assert preconditions
        assert value > 0;
        assert value < 1000;
        
        // Perform operation
        let result = value * 2;
        
        // Assert postconditions
        assert result > value;
        
        Debug.print("Operation successful: " # Nat.toText(result));
    };
    
    public func debugExample() : async () {
        Debug.print("Starting operation");
        
        let x = 42;
        Debug.print("x = " # debug_show(x));
        
        let record = { name = "Alice"; age = 30 };
        Debug.print("record = " # debug_show(record));
    };
};
```

### 2.11.5 Error Propagation

Chain error-prone operations cleanly.

```js
actor ErrorPropagation {
    type Error = { #DatabaseError; #NetworkError; #ValidationError };
    
    func step1() : Result<Nat, Error> {
        // Simulated operation
        #ok(10);
    };
    
    func step2(n : Nat) : Result<Nat, Error> {
        if (n > 5) #ok(n * 2) else #err(#ValidationError);
    };
    
    func step3(n : Nat) : Result<Text, Error> {
        #ok("Final: " # Nat.toText(n));
    };
    
    public func pipeline() : async Result<Text, Error> {
        // Manual error propagation
        switch (step1()) {
            case (#err(e)) #err(e);
            case (#ok(v1)) {
                switch (step2(v1)) {
                    case (#err(e)) #err(e);
                    case (#ok(v2)) {
                        step3(v2);
                    };
                };
            };
        };
    };
    
    // Helper for cleaner propagation
    func andThen<T, U, E>(
        result : Result<T, E>,
        f : T -> Result<U, E>
    ) : Result<U, E> {
        switch (result) {
            case (#err(e)) #err(e);
            case (#ok(value)) f(value);
        };
    };
    
    public func pipelineClean() : async Result<Text, Error> {
        step1()
        |> andThen(_, step2)
        |> andThen(_, step3);
    };
};
```

## 2.12 Data Persistence

Unlike traditional smart contracts, Motoko provides **orthogonal persistence**—your data automatically persists across upgrades without explicit serialization.

### 2.12.1 Stable Variables

Mark variables as `stable` to persist them across canister upgrades.

```js
actor PersistentCounter {
    stable var count : Nat = 0;
    stable var users : [Text] = [];
    stable var lastUpdate : Nat = 0;
    
    public func increment() : async Nat {
        count += 1;
        lastUpdate := count;  // Simplified timestamp
        count;
    };
    
    public func addUser(name : Text) : async () {
        users := Array.append(users, [name]);
    };
    
    public query func getStats() : async (Nat, Nat, Nat) {
        (count, users.size(), lastUpdate);
    };
};
```

### 2.12.2 Stable Types

Only certain types can be marked as stable:

- ✅ Primitive types: `Nat`, `Int`, `Bool`, `Text`, `Principal`, `Blob`

- ✅ Immutable arrays: `[T]` where `T` is stable

- ✅ Tuples of stable types

- ✅ Records of stable types

- ✅ Variants of stable types

- ✅ Options of stable types

- ❌ Mutable arrays: `[var T]`

- ❌ Functions

- ❌ Objects with methods

```js
actor StableTypes {
    type StableUser = {
        name : Text;
        balance : Nat;
        registered : Nat;
    };
    
    type StableRecord = {
        #Active : StableUser;
        #Suspended : { reason : Text };
    };
    
    stable var users : [StableUser] = [];
    stable var records : [StableRecord] = [];
    
    // This won't work - mutable array
    // stable var mutableArray : [var Nat] = [var 1, 2, 3];
    
    // This won't work - HashMap is not stable
    // import HashMap "mo:base/HashMap";
    // stable var map = HashMap.HashMap<Nat, Text>(10, Nat.equal, Hash.hash);
};
```

### 2.12.3 Upgrade Hooks

Use `preupgrade` and `postupgrade` hooks for complex state migration.

```js
import Buffer "mo:base/Buffer";
import HashMap "mo:base/HashMap";

actor UpgradeExample {
    // Non-stable runtime state
    var runtimeCache = HashMap.HashMap<Nat, Text>(10, Nat.equal, Hash.hash);
    let buffer = Buffer.Buffer<Nat>(0);
    
    // Stable storage
    stable var stableData : [(Nat, Text)] = [];
    stable var stableArray : [Nat] = [];
    
    // Before upgrade: save state
    system func preupgrade() {
        // Convert HashMap to stable array
        stableData := Iter.toArray(runtimeCache.entries());
        
        // Convert Buffer to stable array
        stableArray := Buffer.toArray(buffer);
        
        Debug.print("Preupgrade: saved " # Nat.toText(stableData.size()) # " entries");
    };
    
    // After upgrade: restore state
    system func postupgrade() {
        // Restore HashMap from stable array
        for ((key, value) in stableData.vals()) {
            runtimeCache.put(key, value);
        };
        
        // Restore Buffer from stable array
        for (item in stableArray.vals()) {
            buffer.add(item);
        };
        
        // Clear stable storage to save memory
        stableData := [];
        stableArray := [];
        
        Debug.print("Postupgrade: restored cache and buffer");
    };
    
    public func addEntry(key : Nat, value : Text) : async () {
        runtimeCache.put(key, value);
        buffer.add(key);
    };
};
```

### 2.12.4 Migration Patterns

Handle schema changes gracefully during upgrades.

```js
actor VersionedStorage {
    // Version 1 schema
    type UserV1 = {
        name : Text;
        balance : Nat;
    };
    
    // Version 2 schema (added email field)
    type UserV2 = {
        name : Text;
        balance : Nat;
        email : ?Text;
    };
    
    stable var version : Nat = 2;
    stable var usersV2 : [UserV2] = [];
    
    // Migration from V1 to V2
    system func postupgrade() {
        if (version == 1) {
            // Migrate V1 users to V2 format
            // usersV2 := Array.map(usersV1, func(u : UserV1) : UserV2 {
            //     { name = u.name; balance = u.balance; email = null }
            // });
            version := 2;
            Debug.print("Migrated from V1 to V2");
        };
    };
};
```

## 2.13 Garbage Collection

Motoko features automatic memory management with incremental garbage collection. Understanding GC behavior helps optimize performance.

### 2.13.1 Memory Management

Motoko's garbage collector runs incrementally during message execution:
- **Automatic**: No manual memory management needed
- **Incremental**: Spreads GC work across multiple messages
- **Generational**: Optimizes for short-lived objects
- **Compacting**: Reduces fragmentation

```js
actor GCExample {
    // Short-lived objects (collected quickly)
    public func processData() : async Nat {
        let temp1 = Array.init<Nat>(1000, 0);
        let temp2 = Array.tabulate<Nat>(1000, func(i) = i);
        // temp1 and temp2 become garbage when function returns
        temp2[500];
    };
    
    // Long-lived objects (stay in memory)
    stable var persistentData : [Nat] = [];
    
    public func storeData(items : [Nat]) : async () {
        persistentData := Array.append(persistentData, items);
        // persistentData survives across calls
    };
};
```

### 2.13.2 Memory Optimization

Best practices for memory efficiency:

```js
import Buffer "mo:base/Buffer";

actor Optimized {
    // ❌ Bad: Creates many intermediate arrays
    func inefficientProcessing(data : [Nat]) : [Nat] {
        let step1 = Array.map<Nat, Nat>(data, func(n) = n * 2);
        let step2 = Array.filter<Nat>(step1, func(n) = n > 10);
        let step3 = Array.map<Nat, Nat>(step2, func(n) = n + 1);
        step3;
    };
    
    // ✅ Good: Uses Buffer for efficient incremental building
    func efficientProcessing(data : [Nat]) : [Nat] {
        let result = Buffer.Buffer<Nat>(data.size());
        for (n in data.vals()) {
            let doubled = n * 2;
            if (doubled > 10) {
                result.add(doubled + 1);
            };
        };
        Buffer.toArray(result);
    };
    
    // ✅ Good: Reuse existing structures
    var cache = HashMap.HashMap<Nat, Text>(100, Nat.equal, Hash.hash);
    
    public func getValue(key : Nat) : async ?Text {
        switch (cache.get(key)) {
            case (?value) ?value;  // Reuse cached value
            case null {
                let computed = computeExpensiveValue(key);
                cache.put(key, computed);
                ?computed;
            };
        };
    };
    
    func computeExpensiveValue(key : Nat) : Text {
        "Value for " # Nat.toText(key);
    };
};
```

### 2.13.3 Monitoring Memory Usage

```js
import Prim "mo:prim";

actor MemoryMonitor {
    public query func getMemorySize() : async Nat {
        Prim.rts_memory_size();
    };
    
    public query func getHeapSize() : async Nat {
        Prim.rts_heap_size();
    };
    
    public func reportMemory() : async Text {
        let total = Prim.rts_memory_size();
        let heap = Prim.rts_heap_size();
        "Total: " # Nat.toText(total) # " bytes, Heap: " # Nat.toText(heap) # " bytes";
    };
};
```

## 2.14 Orthogonal Persistence

Orthogonal persistence is a revolutionary feature of the Internet Computer that automatically persists program state without explicit save/load operations.

### 2.14.1 Understanding Orthogonal Persistence

In traditional systems, you must:
1. Serialize state to storage
2. Deserialize state from storage
3. Manage database connections
4. Handle data consistency

With orthogonal persistence:

- ✅ All state persists automatically

- ✅ No serialization/deserialization

- ✅ No database management

- ✅ Consistency guaranteed

```js
actor AutoPersist {
    // All these persist automatically!
    var counter : Nat = 0;
    var users : [Text] = [];
    let records = Buffer.Buffer<Text>(0);
    var map = HashMap.HashMap<Nat, Text>(10, Nat.equal, Hash.hash);
    
    public func increment() : async Nat {
        counter += 1;
        // Automatically persisted after message execution
        counter;
    };
    
    public func addUser(name : Text) : async () {
        users := Array.append(users, [name]);
        // State change persisted automatically
    };
};
```

### 2.14.2 Stable vs Regular Variables

```js
actor PersistenceTypes {
    // Regular variable: persists between calls, 
    // but NOT across upgrades
    var temporary : Nat = 0;
    
    // Stable variable: persists between calls 
    // AND across upgrades
    stable var permanent : Nat = 0;
    
    public func incrementBoth() : async (Nat, Nat) {
        temporary += 1;
        permanent += 1;
        (temporary, permanent);
    };
    
    // After upgrade:
    // - temporary resets to 0
    // - permanent keeps its value
};
```

### 2.14.3 Persistence Lifecycle

```js
actor Lifecycle {
    var callCount : Nat = 0;
    stable var totalCalls : Nat = 0;
    
    public func recordCall() : async Text {
        callCount += 1;
        totalCalls += 1;
        
        "This call: " # Nat.toText(callCount) # 
        ", Total: " # Nat.toText(totalCalls);
    };
    
    // Persistence timeline:
    // 1. Message received
    // 2. Function executes
    // 3. State changes made
    // 4. Message completes
    // 5. State automatically persisted ✓
    // 6. Next message sees updated state
};
```

### 2.14.4 Best Practices

```js
actor BestPractices {
    // ✅ Use stable for critical data
    stable var userBalances : [(Principal, Nat)] = [];
    stable var totalSupply : Nat = 0;
    
    // ✅ Use regular vars for caches (can rebuild)
    var computedCache = HashMap.HashMap<Nat, Nat>(100, Nat.equal, Hash.hash);
    
    // ✅ Use stable vars for configuration
    stable var adminPrincipal : Principal = Principal.fromText("aaaaa-aa");
    stable var feeBasisPoints : Nat = 30;  // 0.3%
    
    // ✅ Large collections: use stable storage patterns
    stable var entries : [(Nat, Text)] = [];
    
    public func addEntry(key : Nat, value : Text) : async () {
        entries := Array.append(entries, [(key, value)]);
    };
    
    // ⚠️ For upgrades, use pre/postupgrade hooks
    system func preupgrade() {
        // Convert complex structures to stable format
        entries := Iter.toArray(computedCache.entries());
    };
    
    system func postupgrade() {
        // Rebuild complex structures from stable data
        for ((k, v) in entries.vals()) {
            computedCache.put(k, Nat.fromText(v) |> Option.get(_, 0));
        };
    };
};
```

---

## Summary

This chapter covered the fundamental building blocks of Motoko programming:

1. **Hello, World!** - Your first Motoko program
2. **Basic Syntax** - Expressions, blocks, comments, and naming conventions
3. **Types** - Rich type system with primitives, composites, and generics
4. **Declarations** - Immutable (`let`) and mutable (`var`) bindings
5. **Control Flow** - Conditionals, loops, and powerful pattern matching
6. **Actors & Async** - The foundation of Internet Computer applications
7. **Mutable State** - Managing state safely and efficiently
8. **Messaging** - Inter-actor communication patterns
9. **Modules & Imports** - Code organization and reuse
10. **Pattern Matching** - Exhaustive, type-safe data destructuring
11. **Error Handling** - Robust error management with Result and Option types
12. **Data Persistence** - Stable variables and upgrade hooks
13. **Garbage Collection** - Automatic memory management
14. **Orthogonal Persistence** - Automatic state persistence without serialization

With these fundamentals mastered, you're ready to build sophisticated decentralized applications on the Internet Computer. The next chapter will dive deeper into Motoko's advanced type system and how it prevents common programming errors at compile time.

---
