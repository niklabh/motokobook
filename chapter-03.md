# Chapter 3: Type System and Safety

The primary design goal of Motoko is **safety**. The language employs a sound type system that enforces rigorous checks at compile time, preventing entire classes of errors such as null pointer dereferences, type mismatches, and memory corruption.

### 3.1 Nominal vs. Structural Typing

Motoko employs a mix of nominal and structural typing, but it leans heavily on structural typing for records and objects. This allows for flexible interaction between different actors that may not share the same source code but share the same data shape.

**Primitives and Bounded Types:**

Unlike languages that default to a generic int, Motoko forces the developer to be precise about the nature of numbers:

-   **`Nat` (Natural Number):** An unbounded non-negative integer (0, 1, 2...). This is the default for counters, balances, and IDs. Using `Nat` prevents underflow errors (e.g., a balance going below zero) by definition.
    
-   **`Int` (Integer):** Unbounded signed integers.
    
-   **`Nat8`, `Nat32`, `Nat64`:** Fixed-width types used for binary data processing, cryptographic operations, and interacting with standard interfaces like the Ledger (which often uses `Nat64`).
    

### 3.2 The Billion Dollar Mistake: Option Types

Motoko eliminates the concept of a "null" value that can be implicitly assigned to any reference type. Instead, it utilizes **Option Types** (`?T`). A variable of type `Text` _must_ contain text. It cannot be null. If a value might be missing, it must be declared as `?Text`.

This forces the developer to handle the "missing" case explicitly using pattern matching, eliminating the risk of runtime null pointer exceptions.

**Code Snippet: Pattern Matching Options**

```motoko
let bio : ?Text = null;

// The compiler forces us to handle both cases
let displayBio = switch(bio) {
    case (null) { "User has not provided a bio." };
    case (?text) { text };
};
```

### 3.3 More Primitive Types

In addition to numeric types, Motoko provides several other primitive types that ensure safety and precision:

- **`Bool`**: Represents true or false values.
- **`Text`**: Immutable strings of Unicode characters.
- **`Blob`**: Binary data, useful for raw bytes.
- **`Principal`**: Unique identifiers for users and canisters on the Internet Computer.
- **`Float`**: 64-bit floating-point numbers for decimal arithmetic.

These types are designed to prevent common errors, such as overflow in numerics or invalid string operations.

**Example:**

```motoko
let isActive : Bool = true;
let username : Text = "motoko_dev";
let userId : Principal = Principal.fromText("aaaaa-aa");
```

### 3.4 Composite Types

Motoko supports several composite types to structure data safely.

#### Records

Records are structural types that group named fields.

**Example:**

```motoko
type Person = {
  name : Text;
  age : Nat;
  var balance : Int;
};

let user : Person = { name = "Alice"; age = 30; var balance = 100 };
user.balance := 200;
```

#### Variants

Variants represent tagged unions, useful for enumerations or error handling.

**Example:**

```motoko
type Result<T, E> = {
  #Ok : T;
  #Err : E;
};

let success : Result<Nat, Text> = #Ok(42);
let failure : Result<Nat, Text> = #Err("Operation failed");
```

#### Arrays and Tuples

Arrays can be immutable or mutable, and tuples are anonymous records.

**Example:**

```motoko
let numbers : [Nat] = [1, 2, 3];
let mutableArray : [var Nat] = [var 4, 5, 6];

let pair : (Text, Nat) = ("Score", 100);
```

### 3.5 Type Aliases

Type aliases improve code readability without creating new types.

**Example:**

```motoko
type Username = Text;
type Age = Nat;

type User = {
  username : Username;
  age : Age;
};
```

### 3.6 Generics

Generics allow functions and classes to work with any type.

**Example:**

```motoko
func identity<T>(x : T) : T {
  return x;
};

ignore identity<Nat>(42);

class Box<T>(value : T) {
  public func open() : T { value };
};

let intBox = Box<Nat>(10);
ignore intBox.open();
```

### 3.7 Type Inference

Motoko infers types where possible, reducing annotations.

**Example:**

```motoko
let ar = [1, 2, 3]; // Inferred as [Nat]
let doubled = Array.map(ar, func x { x * 2 }); // Inferred types
```

---

