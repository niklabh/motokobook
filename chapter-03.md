# Chapter 3: Type System and Safety

The primary design goal of Motoko is **safety**. The language employs a sound type system that enforces rigorous checks at compile time, preventing entire classes of errors such as null pointer dereferences, type mismatches, and memory corruption.

A type system is the foundation of a language's reliability. Motoko's type system is designed to catch errors early, enforce contracts between components, and provide mathematical guarantees about program behavior. Unlike weakly-typed languages where runtime errors are common, or gradually-typed languages that allow type escape hatches, Motoko enforces strict type discipline throughout the entire codebase.

This chapter explores Motoko's rich type system, from basic primitives to advanced features like generics, subtyping, and shared types for inter-canister communication.

### 3.1 Nominal vs. Structural Typing

Motoko employs a mix of nominal and structural typing, but it leans heavily on **structural typing** for records and objects. This design decision has profound implications for actor-based programming on the Internet Computer.

**Structural Typing** means that two types are considered compatible if they have the same structure—the same fields with the same types—regardless of their names. This is particularly useful in a distributed system where different canisters may define their own types independently.

**Example: Structural Compatibility**

```js
type UserA = {
  name : Text;
  age : Nat;
};

type UserB = {
  name : Text;
  age : Nat;
};

func greet(user : UserA) : Text {
  "Hello, " # user.name
};

let bob : UserB = { name = "Bob"; age = 25 };
// This works! UserB is structurally compatible with UserA
let greeting = greet(bob);
```

In the above example, `UserA` and `UserB` are different type aliases, but they have the same structure. Motoko treats them as compatible because their structure matches.

**Nominal Typing** is used for certain types like actors, modules, and custom variants where identity matters more than structure. For example, two actor types with identical interfaces are not interchangeable unless explicitly related through subtyping.

**Why This Matters:**

In a distributed system with independent canisters, structural typing allows for flexible integration. A canister doesn't need to import another canister's type definitions to interact with it—as long as the structure matches, communication works. This promotes loose coupling and independent evolution of services.

### 3.2 Primitives and Bounded Types

Unlike languages that default to a generic `int`, Motoko forces the developer to be precise about the nature of numbers. This precision is not just pedantic—it prevents subtle bugs and makes the domain model explicit in the type system.

#### Unbounded Integers

-   **`Nat` (Natural Number):** An unbounded non-negative integer (0, 1, 2...). This is the default for counters, balances, and IDs. Using `Nat` prevents underflow errors (e.g., a balance going below zero) by definition. Mathematical operations that would result in negative numbers cause runtime errors, forcing explicit handling.
    
-   **`Int` (Integer):** Unbounded signed integers. These can be arbitrarily large or small, limited only by the canister's memory. This eliminates overflow issues common in fixed-width integer types.

**Example: Nat Safety**

```js
let balance : Nat = 100;
// balance := balance - 200; // Runtime trap: Natural subtraction underflow
let newBalance = balance -% 200; // Returns 0 (saturating subtraction)
```

#### Fixed-Width Types

-   **`Nat8`, `Nat16`, `Nat32`, `Nat64`:** Unsigned integers of specific bit widths (8, 16, 32, 64 bits).
-   **`Int8`, `Int16`, `Int32`, `Int64`:** Signed integers of specific bit widths.

These fixed-width types are essential for:
- **Binary data processing:** Working with bytes, buffers, and serialization
- **Cryptographic operations:** Hash functions, signatures, keys
- **Standard interfaces:** The ICP Ledger uses `Nat64` for token amounts
- **Performance-critical code:** Fixed-width operations are more efficient

**Example: Using Fixed-Width Types**

```js
import Nat8 "mo:base/Nat8";
import Nat32 "mo:base/Nat32";
import Array "mo:base/Array";

// Processing binary data
let bytes : [Nat8] = [0x48, 0x65, 0x6C, 0x6C, 0x6F]; // "Hello" in ASCII

// Bitwise operations
let flags : Nat32 = 0b1010;
let mask : Nat32 = 0b0110;
let result = flags & mask; // Bitwise AND

// Converting between types
let bigNum : Nat = 1000;
let smallNum : Nat32 = Nat32.fromNat(bigNum);
```

#### Wrapping Arithmetic

Motoko provides special operators for wrapping arithmetic on bounded types:

- `+%` : wrapping addition
- `-%` : wrapping subtraction
- `*%` : wrapping multiplication
- `**%` : wrapping exponentiation

```js
let maxVal : Nat8 = 255;
let wrapped = maxVal +% 1; // Wraps to 0 instead of trapping
```
    

### 3.3 The Billion Dollar Mistake: Option Types

Sir Tony Hoare, the inventor of null references, called them his "billion dollar mistake." Null pointer exceptions have caused countless bugs, crashes, and security vulnerabilities throughout the history of computing. Motoko eliminates this entire class of errors.

Motoko eliminates the concept of a "null" value that can be implicitly assigned to any reference type. Instead, it utilizes **Option Types** (`?T`). A variable of type `Text` _must_ contain text. It cannot be null. If a value might be missing, it must be declared as `?Text`.

This forces the developer to handle the "missing" case explicitly using pattern matching, eliminating the risk of runtime null pointer exceptions.

**Code Snippet: Pattern Matching Options**

```js
let bio : ?Text = null;

// The compiler forces us to handle both cases
let displayBio = switch(bio) {
    case (null) { "User has not provided a bio." };
    case (?text) { text };
};
```

#### Option Combinators

The `Option` module in the base library provides utility functions for working with optional values:

```js
import Option "mo:base/Option";

let maybeAge : ?Nat = ?25;

// get: Extract value or use default
let age = Option.get(maybeAge, 0); // Returns 25

// map: Transform the inner value if it exists
let maybeDouble = Option.map(maybeAge, func (x : Nat) : Nat { x * 2 }); // ?50

// chain (flatMap): Combine operations that return Options
func parseNumber(text : Text) : ?Nat {
  // Simplified parsing example
  if (text == "42") { ?42 } else { null }
};

let input : ?Text = ?"42";
let parsed = Option.chain(input, parseNumber); // ?42

// isSome / isNull: Check if value exists
if (Option.isSome(maybeAge)) {
  // Safe to assume value exists
};
```

#### Practical Example: User Lookup

```js
import HashMap "mo:base/HashMap";
import Text "mo:base/Text";
import Option "mo:base/Option";

type User = {
  id : Nat;
  name : Text;
  email : ?Text; // Email is optional
};

let users = HashMap.HashMap<Nat, User>(10, Nat.equal, Hash.hash);

// Safe user lookup with default
func getUserName(userId : Nat) : Text {
  switch (users.get(userId)) {
    case (null) { "Unknown User" };
    case (?user) { user.name };
  }
};

// Accessing nested optional values
func getUserEmail(userId : Nat) : Text {
  let maybeUser = users.get(userId);
  switch (maybeUser) {
    case (null) { "No user found" };
    case (?user) {
      switch (user.email) {
        case (null) { "Email not provided" };
        case (?email) { email };
      };
    };
  };
};
```

The compiler's type checker ensures you can never accidentally access a null value. This is one of Motoko's strongest safety guarantees.

### 3.4 More Primitive Types

In addition to numeric types, Motoko provides several other primitive types that ensure safety and precision:

#### Bool

Boolean values (`true` or `false`) with standard logical operations:

```js
let isActive : Bool = true;
let hasAccess : Bool = false;

// Logical operations
let both = isActive and hasAccess;  // false
let either = isActive or hasAccess;  // true
let negated = not isActive;  // false
```

#### Text

Immutable strings of Unicode characters. Motoko's `Text` type fully supports Unicode, making it suitable for international applications:

```js
let greeting : Text = "Hello, World! 👋";
let chinese : Text = "你好";
let emoji : Text = "🚀";

// Text concatenation
let message = greeting # " " # chinese; 

// Text comparison
let isEqual = greeting == "Hello, World! 👋"; // true
```

The `Text` module provides rich string manipulation functions:

```js
import Text "mo:base/Text";

let sample = "Motoko Programming";

// Get length (counts Unicode characters, not bytes)
let len = Text.size(sample); // 18

// Check prefix/suffix
let startsWithM = Text.startsWith(sample, #text "Motoko"); // true

// Case conversion
let upper = Text.toUppercase(sample);

// Splitting and joining
let words = Text.split(sample, #char ' ');
```

#### Char

Individual Unicode characters:

```js
let firstLetter : Char = 'M';
let newline : Char = '\n';
let emoji : Char = '🎉';

// Character to Nat32 (Unicode code point)
let codePoint : Nat32 = Char.toNat32(firstLetter); // 77
```

#### Blob

Binary data, represented as immutable byte sequences. Essential for cryptographic operations, file handling, and low-level data processing:

```js
import Blob "mo:base/Blob";

// Creating from array of bytes
let bytes : [Nat8] = [72, 101, 108, 108, 111];
let blob : Blob = Blob.fromArray(bytes);

// Getting size
let size = blob.size(); // 5

// Converting back to array
let backToBytes = Blob.toArray(blob);
```

#### Principal

The `Principal` type is unique to the Internet Computer. It represents the identity of users and canisters. Every canister and user has a unique Principal identifier:

```js
import Principal "mo:base/Principal";

// Anonymous principal (used for unauthenticated calls)
let anon = Principal.fromText("2vxsx-fae");

// Check if a principal is anonymous
let isAnonymous = Principal.isAnonymous(anon);

// Convert to text for display
let principalText = Principal.toText(anon);

// Compare principals
let isSame = Principal.equal(anon, Principal.fromText("2vxsx-fae"));
```

Principals are crucial for access control and identity management in canisters:

```js
import HashMap "mo:base/HashMap";
import Principal "mo:base/Principal";

stable var owner : Principal = Principal.fromText("aaaaa-aa");

func isOwner(caller : Principal) : Bool {
  Principal.equal(caller, owner)
};
```

#### Float

64-bit IEEE 754 floating-point numbers for decimal arithmetic. Use with caution due to precision limitations inherent to floating-point representation:

```js
let pi : Float = 3.14159;
let e : Float = 2.71828;

// Arithmetic operations
let sum = pi + e;
let product = pi * 2;

// Comparison (be careful with equality due to floating-point precision)
let isGreater = pi > e;

// Converting from/to Int and Nat
let floatFromInt = Float.fromInt(42);
let intFromFloat = Float.toInt(pi); // Truncates: 3
```

**Warning:** Avoid using `Float` for financial calculations where precision is critical. Use `Nat` or `Int` with appropriate scaling instead:

```js
// Bad: Using Float for currency
let price : Float = 0.1 + 0.2; // Might not equal 0.3 due to floating-point errors

// Good: Using Nat with scaling (e.g., cents instead of dollars)
let priceInCents : Nat = 10 + 20; // Exactly 30
```

### 3.5 Composite Types

Motoko supports several composite types to structure data safely. These types allow you to build complex data structures while maintaining type safety.

#### Records

Records are structural types that group named fields. They are the primary way to represent structured data in Motoko:

```js
type Person = {
  name : Text;
  age : Nat;
  var balance : Int;  // Mutable field
};

let user : Person = { name = "Alice"; age = 30; var balance = 100 };
user.balance := 200;  // Mutating a mutable field
// user.age := 31;  // Error: age is immutable
```

**Record Subtyping:**

Records support width and depth subtyping. A record with more fields is a subtype of a record with fewer fields:

```js
type BasicUser = {
  name : Text;
};

type DetailedUser = {
  name : Text;
  email : Text;
  age : Nat;
};

func greetUser(user : BasicUser) : Text {
  "Hello, " # user.name
};

let detailed : DetailedUser = { 
  name = "Bob"; 
  email = "bob@example.com"; 
  age = 25 
};

// Works! DetailedUser is a subtype of BasicUser
let greeting = greetUser(detailed);
```

**Nested Records:**

```js
type Address = {
  street : Text;
  city : Text;
  country : Text;
};

type UserWithAddress = {
  name : Text;
  address : Address;
};

let userAddr : UserWithAddress = {
  name = "Charlie";
  address = {
    street = "123 Main St";
    city = "San Francisco";
    country = "USA";
  };
};

// Accessing nested fields
let city = userAddr.address.city;
```

#### Variants

Variants (also called tagged unions or sum types) represent a value that can be one of several alternatives. Each alternative is tagged with a label:

```js
type Result<T, E> = {
  #Ok : T;
  #Err : E;
};

let success : Result<Nat, Text> = #Ok(42);
let failure : Result<Nat, Text> = #Err("Operation failed");

// Pattern matching on variants
func handleResult(result : Result<Nat, Text>) : Text {
  switch (result) {
    case (#Ok(value)) { "Success: " # Nat.toText(value) };
    case (#Err(error)) { "Error: " # error };
  }
};
```

**Enumerations with Variants:**

```js
type Status = {
  #Active;
  #Inactive;
  #Pending;
  #Suspended;
};

type PaymentMethod = {
  #Cash;
  #CreditCard : { last4 : Text };
  #BankTransfer : { accountNumber : Text };
  #Crypto : { walletAddress : Text };
};

func processPayment(method : PaymentMethod, amount : Nat) : Text {
  switch (method) {
    case (#Cash) { "Processing cash payment" };
    case (#CreditCard(card)) { 
      "Charging card ending in " # card.last4 
    };
    case (#BankTransfer(bank)) { 
      "Transferring to account " # bank.accountNumber 
    };
    case (#Crypto(wallet)) {
      "Sending to wallet " # wallet.walletAddress
    };
  }
};
```

**Recursive Variants:**

Variants can be recursive, enabling tree and list structures:

```js
type List<T> = {
  #Nil;
  #Cons : (T, List<T>);
};

// Creating a linked list: 1 -> 2 -> 3
let myList : List<Nat> = #Cons(1, #Cons(2, #Cons(3, #Nil)));

// Recursive function to sum a list
func sumList(list : List<Nat>) : Nat {
  switch (list) {
    case (#Nil) { 0 };
    case (#Cons(head, tail)) { head + sumList(tail) };
  }
};
```

#### Arrays

Arrays can be immutable or mutable. Immutable arrays provide safety and enable sharing, while mutable arrays allow in-place updates:

```js
// Immutable array
let numbers : [Nat] = [1, 2, 3, 4, 5];
// numbers[0] := 10;  // Error: cannot mutate immutable array

// Mutable array
let mutableArray : [var Nat] = [var 10, 20, 30];
mutableArray[0] := 15;  // OK: mutable array

// Array operations from Array module
import Array "mo:base/Array";

let doubled = Array.map<Nat, Nat>(numbers, func (x) { x * 2 });
let filtered = Array.filter<Nat>(numbers, func (x) { x > 2 });
let sum = Array.foldLeft<Nat, Nat>(numbers, 0, func (acc, x) { acc + x });
```

**Array Initialization:**

```js
import Array "mo:base/Array";

// Initialize array with a function
let sequence = Array.tabulate<Nat>(10, func (i) { i * i });
// [0, 1, 4, 9, 16, 25, 36, 49, 64, 81]

// Create array of same value
let zeros = Array.freeze<Nat>(Array.init<Nat>(5, 0));
// [0, 0, 0, 0, 0]
```

#### Tuples

Tuples are anonymous records with positional fields. They're useful for returning multiple values or creating simple pairs:

```js
let pair : (Text, Nat) = ("Score", 100);

// Accessing tuple elements
let label = pair.0;  // "Score"
let value = pair.1;  // 100

// Destructuring tuples
let (name, score) = pair;

// Function returning tuple
func divMod(a : Nat, b : Nat) : (Nat, Nat) {
  (a / b, a % b)
};

let (quotient, remainder) = divMod(17, 5);  // (3, 2)

// Nested tuples
let nested : ((Text, Nat), Bool) = (("Status", 200), true);
```

#### Objects

Objects are like records but with methods. They support encapsulation and can maintain internal state:

```js
type Counter = {
  get : () -> Nat;
  inc : () -> ();
};

func makeCounter() : Counter {
  var count = 0;
  
  {
    get = func () : Nat { count };
    inc = func () { count += 1 };
  }
};

let counter = makeCounter();
counter.inc();
counter.inc();
let value = counter.get();  // 2
```

### 3.6 Type Aliases

Type aliases improve code readability and documentation without creating new nominal types. They're purely syntactic sugar that helps make code self-documenting:

```js
type Username = Text;
type Age = Nat;
type UserId = Nat;

type User = {
  id : UserId;
  username : Username;
  age : Age;
};

// Type aliases are transparent - these are the same type
let name1 : Username = "alice";
let name2 : Text = name1;  // OK: Username = Text
```

**Complex Type Aliases:**

Type aliases can represent complex types, making them easier to reuse:

```js
type Callback<T> = (T) -> ();
type AsyncCallback<T> = (T) -> async ();
type Result<T> = { #Ok : T; #Err : Text };
type HashMap<K, V> = [(K, V)];

// Using type aliases for clarity
type TransactionProcessor = (
  userId : Nat,
  amount : Nat,
  callback : Callback<Result<Nat>>
) -> async Result<Nat>;
```

**Phantom Types:**

Type aliases can be used to create phantom types for additional type safety:

```js
type Unvalidated = { #unvalidated };
type Validated = { #validated };

type Email<T> = {
  address : Text;
  state : T;
};

func createEmail(address : Text) : Email<Unvalidated> {
  { address; state = #unvalidated }
};

func validateEmail(email : Email<Unvalidated>) : ?Email<Validated> {
  if (Text.contains(email.address, #char '@')) {
    ?{ address = email.address; state = #validated }
  } else {
    null
  }
};

// This enforces that only validated emails can be sent
func sendEmail(email : Email<Validated>) : async () {
  // Send email logic
};
```

### 3.7 Generics

Generics (also called parametric polymorphism) allow functions, classes, and types to work with any type while maintaining type safety. This enables code reuse without sacrificing type checking:

```js
func identity<T>(x : T) : T {
  return x;
};

let num = identity<Nat>(42);      // T = Nat
let text = identity<Text>("hi");  // T = Text
let auto = identity(true);        // T inferred as Bool
```

#### Generic Functions

Generic functions can operate on values of any type:

```js
// Swap elements in a tuple
func swap<A, B>(pair : (A, B)) : (B, A) {
  (pair.1, pair.0)
};

let numText = swap<Nat, Text>((42, "answer"));  // ("answer", 42)

// First element of a tuple
func first<A, B>(pair : (A, B)) : A {
  pair.0
};

// Compose two functions
func compose<A, B, C>(f : B -> C, g : A -> B) : A -> C {
  func (x : A) : C {
    f(g(x))
  }
};
```

#### Generic Classes

Classes can be parameterized by types:

```js
class Box<T>(initValue : T) {
  var value = initValue;
  
  public func get() : T { value };
  
  public func set(newValue : T) {
    value := newValue;
  };
  
  public func map<U>(f : T -> U) : Box<U> {
    Box<U>(f(value))
  };
};

let intBox = Box<Nat>(10);
intBox.set(20);

let stringBox = intBox.map<Text>(func (n) { Nat.toText(n) });
ignore stringBox.get();  // "20"
```

#### Generic Data Structures

Generics enable reusable data structures:

```js
type Stack<T> = {
  #Empty;
  #Node : { value : T; rest : Stack<T> };
};

func push<T>(stack : Stack<T>, value : T) : Stack<T> {
  #Node({ value; rest = stack })
};

func pop<T>(stack : Stack<T>) : ?(T, Stack<T>) {
  switch (stack) {
    case (#Empty) { null };
    case (#Node({ value; rest })) { ?(value, rest) };
  }
};

// Using the generic stack
var numStack : Stack<Nat> = #Empty;
numStack := push(numStack, 1);
numStack := push(numStack, 2);
numStack := push(numStack, 3);

switch (pop(numStack)) {
  case (?(value, rest)) {
    // value = 3, rest contains [2, 1]
  };
  case null { };
};
```

#### Type Constraints

While Motoko doesn't have explicit type constraints (like Rust's trait bounds), you can use structural typing to achieve similar effects:

```js
type Comparable = {
  compare : (Comparable) -> Int;
};

func max<T>(a : T, b : T, cmp : (T, T) -> Int) : T {
  if (cmp(a, b) > 0) { a } else { b }
};

let maxNum = max<Nat>(5, 10, func (a, b) { 
  if (a > b) { 1 } else if (a < b) { -1 } else { 0 }
});
```

#### Higher-Kinded Types (Limited Support)

Motoko has limited support for higher-kinded types. You can't parameterize over type constructors directly, but you can use workarounds:

```js
type Functor<F> = {
  map : <A, B>(F, A -> B) -> F;
};

// Example: Option as a functor
let optionFunctor : Functor<Option> = {
  map = func<A, B>(opt : ?A, f : A -> B) : ?B {
    switch (opt) {
      case (null) { null };
      case (?value) { ?f(value) };
    }
  };
};
```

### 3.8 Type Inference

Motoko features a sophisticated type inference engine based on Hindley-Milner type inference. This means you often don't need to write explicit type annotations—the compiler can deduce them:

```js
let ar = [1, 2, 3]; // Inferred as [Nat]
let doubled = Array.map(ar, func x { x * 2 }); // Function type inferred

// Inference with generics
func wrap(x) { ?x };  // Inferred as <T>(T) -> ?T
let maybeNum = wrap(42);  // ?Nat

// Inference in pattern matching
let result = #Ok(42);  // Inferred as Result<Nat, Any>
switch (result) {
  case (#Ok(val)) { val + 1 };  // val inferred as Nat
  case (#Err(e)) { 0 };
};
```

#### When Type Annotations Are Required

While inference is powerful, there are cases where annotations are necessary:

1. **Public function signatures** (for clarity and interface stability)
2. **Recursive functions** (to avoid infinite type expansion)
3. **Empty collections** (compiler can't infer element type)
4. **Ambiguous contexts**

```js
// Annotation required for public functions
public func processUser(user : User) : Result<(), Text> {
  // Implementation
};

// Annotation helps with empty arrays
let empty : [Nat] = [];  // Without annotation, type is ambiguous

// Recursive functions need annotation
func factorial(n : Nat) : Nat {
  if (n == 0) { 1 } else { n * factorial(n - 1) }
};
```

#### Type Inference Best Practices

```js
// Good: Let inference work for local variables
let numbers = [1, 2, 3, 4, 5];
let sum = Array.foldLeft(numbers, 0, func (a, b) { a + b });

// Good: Annotate public interfaces
public type API = {
  getUser : (UserId) -> async ?User;
  updateUser : (UserId, User) -> async Result<(), Text>;
};

// Good: Annotate when it improves readability
let users : HashMap<UserId, User> = HashMap.HashMap(10, Nat.equal, Hash.hash);

// Avoid: Over-annotation makes code verbose
let x : Nat = 42 : Nat;  // Redundant
let y : Nat = (x : Nat) + (10 : Nat);  // Too verbose
```

### 3.9 Subtyping

Motoko supports structural subtyping, which is essential for flexible and compositional programming. A type `S` is a subtype of `T` (written `S <: T`) if a value of type `S` can be safely used wherever a `T` is expected.

#### Record Subtyping (Width)

A record with more fields is a subtype of a record with fewer fields:

```js
type Person = {
  name : Text;
};

type Employee = {
  name : Text;
  employeeId : Nat;
  department : Text;
};

func greet(person : Person) : Text {
  "Hello, " # person.name
};

let emp : Employee = { 
  name = "Alice"; 
  employeeId = 12345;
  department = "Engineering";
};

// OK: Employee <: Person
let greeting = greet(emp);
```

#### Variant Subtyping (Depth)

A variant with fewer alternatives is a subtype of a variant with more alternatives:

```js
type BasicError = {
  #NotFound;
  #Unauthorized;
};

type ExtendedError = {
  #NotFound;
  #Unauthorized;
  #RateLimited;
  #ServerError;
};

func handleBasicError(err : BasicError) : Text {
  switch (err) {
    case (#NotFound) { "Not found" };
    case (#Unauthorized) { "Unauthorized" };
  }
};

// BasicError <: ExtendedError in some contexts
// But be careful: subtyping with variants is contravariant in some positions
```

#### Function Subtyping

Functions are contravariant in their arguments and covariant in their return types:

```js
// If S2 <: S1 and T1 <: T2, then (S1 -> T1) <: (S2 -> T2)

type ProcessEmployee = Employee -> Text;
type ProcessPerson = Person -> Text;

// ProcessEmployee <: ProcessPerson (in terms of what they can accept)
```

#### Mutable Field Subtyping

Mutable fields are invariant—they must match exactly:

```js
type WithMutable = {
  var count : Nat;
};

type WithMoreFields = {
  var count : Nat;
  name : Text;
};

// This does NOT work for mutable fields
// func update(x : WithMutable) { x.count := 0 };
// let y : WithMoreFields = { var count = 1; name = "test" };
// update(y);  // Type error due to invariance
```

### 3.10 Shared Types

Shared types are types that can be sent across actor boundaries. Not all Motoko types are shared—only those that can be serialized for inter-canister communication.

#### Shared Type Requirements

A type is shared if:
1. It contains no mutable fields
2. It contains no functions (except `shared` functions)
3. All nested types are also shared

```js
// Shared types (can be sent across actors)
type SharedUser = {
  id : Nat;
  name : Text;
  email : ?Text;
};

type SharedResult = {
  #Ok : Nat;
  #Err : Text;
};

// NOT shared types
type NotShared1 = {
  var count : Nat;  // Mutable field
};

type NotShared2 = {
  callback : (Nat) -> Nat;  // Function field
};
```

#### Shared Functions

Functions that cross actor boundaries must be declared as `shared`:

```js
actor Counter {
  var count = 0;
  
  // Shared query function (read-only, fast)
  public shared query func get() : async Nat {
    count
  };
  
  // Shared update function (can modify state)
  public shared func increment() : async () {
    count += 1;
  };
  
  // Shared function with caller identity
  public shared(msg) func incrementBy(n : Nat) : async () {
    let caller : Principal = msg.caller;
    // Can check authorization based on caller
    count += n;
  };
};
```

#### The Candid Type System

Shared types are automatically mapped to Candid (the Interface Description Language for the Internet Computer):

```js
// Motoko type
type User = {
  id : Nat;
  name : Text;
  friends : [Nat];
};

// Corresponds to Candid:
// type User = record {
//   id : nat;
//   name : text;
//   friends : vec nat;
// };
```

### 3.11 Async Types

Asynchronous programming is fundamental to the Internet Computer. The `async` type represents a computation that may not complete immediately:

```js
type AsyncResult = async Nat;

// Function returning async value
func fetchData() : async Nat {
  // Async computation
  42
};

// Awaiting async values
func processData() : async Nat {
  let data = await fetchData();
  data * 2
};
```

#### Error Handling with Async

Async computations can trap (throw errors). Use `try/catch` to handle them:

```js
func safeDivide(a : Nat, b : Nat) : async Result<Nat, Text> {
  if (b == 0) {
    return #Err("Division by zero");
  };
  #Ok(a / b)
};

func handleOperation() : async Text {
  try {
    let result = await riskyOperation();
    "Success: " # Nat.toText(result)
  } catch (err) {
    "Error occurred"
  }
};
```

#### Async Combinators

```js
import Array "mo:base/Array";

// Sequentially process async operations
func processSequential(items : [Nat]) : async [Nat] {
  var results : [Nat] = [];
  for (item in items.vals()) {
    let processed = await processItem(item);
    results := Array.append(results, [processed]);
  };
  results
};

// Note: Motoko doesn't have built-in parallel async combinators
// All awaits in a single async function happen sequentially
```

### 3.12 Type Soundness and Safety Guarantees

Motoko's type system provides strong guarantees:

1. **No null pointer exceptions**: Optional types force explicit handling
2. **No type confusion**: Values always have the type the system believes they have
3. **Memory safety**: No buffer overflows, use-after-free, or dangling pointers
4. **No uninitialized variables**: All variables must be initialized
5. **Bounded recursion**: Async functions prevent unbounded stack growth
6. **Actor isolation**: Mutable state cannot leak across actor boundaries

These guarantees are enforced at compile time wherever possible, and runtime checks catch violations that can't be statically verified (like array bounds or arithmetic overflow).

**Example: Type Safety in Action**

```js
// This code won't compile - type errors caught at compile time
func example() {
  let x : Nat = 42;
  // let y : Text = x;  // Error: type mismatch
  
  let maybe : ?Nat = null;
  // let z = maybe + 1;  // Error: can't use option directly
  
  let arr = [1, 2, 3];
  // arr[10];  // Runtime trap, but type-safe
  
  // let f : Nat -> Nat = func (x) { x # "text" };  // Error: type mismatch in function body
};
```

---

