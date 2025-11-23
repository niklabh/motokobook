# Chapter 14: Troubleshooting and Best Practices

Even experienced developers encounter specific Motoko quirks. This comprehensive chapter outlines common compiler errors, debugging strategies, performance optimization techniques, and security best practices to help you build robust and efficient Internet Computer applications.

### 12.1 Common Compiler Errors

Understanding compiler errors is crucial for productive Motoko development. Here's an extensive guide to the most common issues you'll encounter.

**Table 3: Comprehensive Troubleshooting Guide**

| Error Code | Description | Solution |
|-----------|-------------|----------|
| **M0096** | Expression cannot produce expected type. | Check for trailing semicolons in blocks returning values. Remove `;` from the last expression. |
| **M0031** | Type mismatch in `async` return. | Ensure shared functions return `async T`. All public functions must be async. |
| **M0019** | Unbound identifier `null`. | Use `?T` (Option type) if a value can be null. Import `Option` from base library. |
| **M0050** | Literal out of range for type. | Value exceeds type bounds. Use larger type (e.g., `Int` instead of `Int8`). |
| **M0057** | Unbound type. | Import the type or define it. Check spelling and module imports. |
| **M0070** | Shared function has non-shared parameter type. | Ensure all parameters are shareable (no functions, objects with methods). |
| **M0095** | Canister has no public shared functions. | Add at least one `public shared` function for the canister to be callable. |
| **M0138** | Variant case mismatch. | Check variant constructor names match exactly (case-sensitive). |
| **M0155** | Cycle balance depleted. | Top up canister cycles or optimize cycle consumption. |
| **Canister Trapped** | Runtime failure (e.g., integer underflow, out of bounds). | Use `Nat` carefully. Ensure arrays are not accessed out of bounds. Add bounds checks. |

#### 12.1.1 Trailing Semicolon Issues

One of the most common mistakes in Motoko is adding a semicolon after the final expression in a block:

```motoko
// ❌ Wrong - semicolon makes function return ()
public func getValue() : async Nat {
    let result = 42;
    result;  // This returns the value correctly
};

// ❌ Wrong - semicolon discards the value
public func getValueWrong() : async Nat {
    let result = 42;
    result;  // ERROR: semicolon makes this return ()
};

// ✅ Correct
public func getValueCorrect() : async Nat {
    let result = 42;
    result   // No semicolon on last expression
};
```

#### 12.1.2 Async/Await Mismatches

```motoko
// ❌ Wrong - missing async
public shared func updateBalance(amount: Nat) : Nat {
    balance += amount;
    balance
};

// ✅ Correct
public shared func updateBalance(amount: Nat) : async Nat {
    balance += amount;
    balance
};

// ❌ Wrong - forgot await on async call
public shared func callOther() : async Text {
    let result = otherCanister.getValue();  // Missing await
    result
};

// ✅ Correct
public shared func callOther() : async Text {
    let result = await otherCanister.getValue();
    result
};
```

#### 12.1.3 Type Inference Limitations

Sometimes the compiler needs explicit type annotations:

```motoko
// ❌ May fail type inference
let items = [];
items.add(1);

// ✅ Better - explicit type
let items : Buffer.Buffer<Nat> = Buffer.Buffer<Nat>(0);
items.add(1);

// ✅ Or infer from initialization
let items = Buffer.Buffer<Nat>(0);
items.add(1);
```

### 12.2 Debugging Techniques

Since canisters run on a remote blockchain, traditional debugging approaches need adaptation. Here are comprehensive strategies for effective Motoko debugging.

#### 12.2.1 Debug.print() for Local Development

`Debug.print()` is your primary debugging tool during local development:

```motoko
import Debug "mo:base/Debug";
import Int "mo:base/Int";
import Array "mo:base/Array";

actor {
    public func processData(values: [Nat]) : async Nat {
        Debug.print("Processing " # debug_show(values.size()) # " values");
        
        var sum = 0;
        for (v in values.vals()) {
            Debug.print("Processing value: " # debug_show(v));
            sum += v;
        };
        
        Debug.print("Final sum: " # debug_show(sum));
        sum
    };
};
```

**Important Notes:**
- `Debug.print()` only works on local replicas and testnets
- Output appears in dfx console, not in canister responses
- Use `debug_show()` to convert any value to text representation
- On mainnet, Debug.print calls are no-ops (they don't execute)

#### 12.2.2 Structured Logging Pattern

Create a logging system that can work both locally and in production:

```motoko
import Array "mo:base/Array";
import Time "mo:base/Time";
import Text "mo:base/Text";
import Buffer "mo:base/Buffer";
import Debug "mo:base/Debug";

actor Logger {
    type LogLevel = {
        #INFO;
        #WARN;
        #ERROR;
        #DEBUG;
    };
    
    type LogEntry = {
        timestamp: Time.Time;
        level: LogLevel;
        message: Text;
    };
    
    stable var logs : [LogEntry] = [];
    let logBuffer = Buffer.Buffer<LogEntry>(100);
    
    // Maximum logs to keep in memory
    let MAX_LOGS = 1000;
    
    private func log(level: LogLevel, message: Text) {
        let entry : LogEntry = {
            timestamp = Time.now();
            level = level;
            message = message;
        };
        
        logBuffer.add(entry);
        
        // Also print locally
        Debug.print("[" # debug_show(level) # "] " # message);
        
        // Keep buffer size manageable
        if (logBuffer.size() > MAX_LOGS) {
            ignore logBuffer.remove(0);
        };
    };
    
    public func info(message: Text) : async () {
        log(#INFO, message);
    };
    
    public func warn(message: Text) : async () {
        log(#WARN, message);
    };
    
    public func error(message: Text) : async () {
        log(#ERROR, message);
    };
    
    public query func getLogs(count: Nat) : async [LogEntry] {
        let size = logBuffer.size();
        let start = if (size > count) { size - count } else { 0 };
        Buffer.toArray(Buffer.subBuffer(logBuffer, start, size - start))
    };
    
    system func preupgrade() {
        logs := Buffer.toArray(logBuffer);
    };
    
    system func postupgrade() {
        for (entry in logs.vals()) {
            logBuffer.add(entry);
        };
    };
};
```

#### 12.2.3 Trap Analysis and Error Handling

When a canister traps, it's crucial to understand why. Implement comprehensive error handling:

```motoko
import Result "mo:base/Result";
import Error "mo:base/Error";
import Debug "mo:base/Debug";

actor {
    type DatabaseError = {
        #NotFound;
        #InvalidInput: Text;
        #InternalError: Text;
    };
    
    var storage = HashMap.HashMap<Text, Nat>(10, Text.equal, Text.hash);
    
    // ❌ Bad - will trap on errors
    public func getValueUnsafe(key: Text) : async Nat {
        switch (storage.get(key)) {
            case null { assert false; 0 }; // Traps!
            case (?v) v;
        };
    };
    
    // ✅ Good - returns Result type
    public func getValue(key: Text) : async Result.Result<Nat, DatabaseError> {
        switch (storage.get(key)) {
            case null { #err(#NotFound) };
            case (?v) { #ok(v) };
        };
    };
    
    // ✅ Better - with logging
    public func getValueWithLogging(key: Text) : async Result.Result<Nat, DatabaseError> {
        Debug.print("Getting value for key: " # key);
        switch (storage.get(key)) {
            case null {
                Debug.print("Key not found: " # key);
                #err(#NotFound)
            };
            case (?v) {
                Debug.print("Found value: " # debug_show(v));
                #ok(v)
            };
        };
    };
    
    // Handle arithmetic safely
    public func safeDivide(a: Int, b: Int) : async Result.Result<Int, Text> {
        if (b == 0) {
            #err("Division by zero")
        } else {
            #ok(a / b)
        };
    };
};
```

#### 12.2.4 State Inspection and Query Functions

Create query functions to inspect canister state during debugging:

```motoko
actor {
    stable var userCount : Nat = 0;
    var cache = HashMap.HashMap<Text, Text>(10, Text.equal, Text.hash);
    
    // Debug query functions
    public query func debug_getUserCount() : async Nat {
        userCount
    };
    
    public query func debug_getCacheSize() : async Nat {
        cache.size()
    };
    
    public query func debug_getCacheKeys() : async [Text] {
        Iter.toArray(cache.keys())
    };
    
    public query func debug_getState() : async {
        userCount: Nat;
        cacheSize: Nat;
        memorySize: Nat;
    } {
        {
            userCount = userCount;
            cacheSize = cache.size();
            memorySize = Prim.rts_memory_size();
        }
    };
};
```

### 12.3 Best Practices

Following established best practices will help you write maintainable, secure, and efficient Motoko code.

#### 12.3.1 Code Organization

**Modularization:**

```motoko
// types.mo - Centralize type definitions
module Types {
    public type User = {
        id: Principal;
        name: Text;
        email: Text;
        createdAt: Int;
    };
    
    public type Post = {
        id: Nat;
        author: Principal;
        content: Text;
        timestamp: Int;
    };
};

// utils.mo - Reusable utility functions
module Utils {
    import Text "mo:base/Text";
    
    public func validateEmail(email: Text) : Bool {
        Text.contains(email, #text "@") and Text.size(email) > 3
    };
    
    public func sanitizeInput(input: Text) : Text {
        // Remove potentially dangerous characters
        Text.trim(input, #text " \n\t\r")
    };
};

// main.mo - Main actor
import Types "types";
import Utils "utils";

actor Main {
    stable var users : [Types.User] = [];
    
    public shared(msg) func registerUser(name: Text, email: Text) : async Result.Result<(), Text> {
        if (not Utils.validateEmail(email)) {
            return #err("Invalid email format");
        };
        
        let newUser : Types.User = {
            id = msg.caller;
            name = Utils.sanitizeInput(name);
            email = email;
            createdAt = Time.now();
        };
        
        // Add user logic...
        #ok(())
    };
};
```

#### 12.3.2 Stable Memory Management

```motoko
import HashMap "mo:base/HashMap";
import Iter "mo:base/Iter";
import Array "mo:base/Array";

actor {
    // ❌ Bad - will lose data on upgrade
    var users = HashMap.HashMap<Principal, User>(10, Principal.equal, Principal.hash);
    
    // ✅ Good - stable storage with upgrade hooks
    stable var stableUsers : [(Principal, User)] = [];
    var users = HashMap.HashMap<Principal, User>(10, Principal.equal, Principal.hash);
    
    system func preupgrade() {
        stableUsers := Iter.toArray(users.entries());
    };
    
    system func postupgrade() {
        users := HashMap.fromIter<Principal, User>(
            stableUsers.vals(),
            10,
            Principal.equal,
            Principal.hash
        );
        stableUsers := [];  // Free memory
    };
};
```

#### 12.3.3 Cycle Management

Always monitor and manage cycles proactively:

```motoko
import Cycles "mo:base/ExperimentalCycles";
import Error "mo:base/Error";

actor {
    private let MINIMUM_CYCLES : Nat = 1_000_000_000_000; // 1T cycles
    private let CYCLE_THRESHOLD : Nat = 5_000_000_000_000; // 5T cycles
    
    public shared func checkCycleBalance() : async Nat {
        Cycles.balance()
    };
    
    public shared func acceptCycles() : async Nat {
        let available = Cycles.available();
        let accepted = Cycles.accept(available);
        accepted
    };
    
    // Check cycles before expensive operations
    private func ensureSufficientCycles() : Bool {
        Cycles.balance() >= MINIMUM_CYCLES
    };
    
    public shared func expensiveOperation() : async Result.Result<(), Text> {
        if (not ensureSufficientCycles()) {
            return #err("Insufficient cycles");
        };
        
        // Perform operation...
        #ok(())
    };
    
    // Monitor and alert on low cycles
    public query func needsCycleTopup() : async Bool {
        Cycles.balance() < CYCLE_THRESHOLD
    };
};
```

#### 12.3.4 Security Best Practices

**Authentication and Authorization:**

```motoko
import Principal "mo:base/Principal";
import HashMap "mo:base/HashMap";
import Result "mo:base/Result";

actor SecureCanister {
    stable var owner : Principal = Principal.fromText("aaaaa-aa");
    stable var admins : [Principal] = [];
    
    // Role-based access control
    type Role = {
        #Owner;
        #Admin;
        #User;
    };
    
    private func getRole(caller: Principal) : Role {
        if (caller == owner) {
            return #Owner;
        };
        if (Array.find<Principal>(admins, func(p) { p == caller }) != null) {
            return #Admin;
        };
        #User
    };
    
    private func requireRole(caller: Principal, required: Role) : Result.Result<(), Text> {
        let role = getRole(caller);
        switch (role, required) {
            case (#Owner, _) { #ok(()) };  // Owner can do anything
            case (#Admin, #Admin) { #ok(()) };
            case (#Admin, #User) { #ok(()) };
            case (#User, #User) { #ok(()) };
            case (_, _) { #err("Insufficient permissions") };
        };
    };
    
    // Always validate caller identity
    public shared(msg) func adminOnlyFunction() : async Result.Result<(), Text> {
        switch (requireRole(msg.caller, #Admin)) {
            case (#ok(_)) {
                // Perform admin operation
                #ok(())
            };
            case (#err(e)) { #err(e) };
        };
    };
    
    // Prevent unauthorized access
    public shared(msg) func sensitiveOperation(amount: Nat) : async Result.Result<(), Text> {
        // Validate caller
        if (Principal.isAnonymous(msg.caller)) {
            return #err("Anonymous callers not allowed");
        };
        
        // Validate input
        if (amount == 0 or amount > 1_000_000) {
            return #err("Invalid amount");
        };
        
        // Perform operation...
        #ok(())
    };
};
```

**Input Validation:**

```motoko
module Validation {
    import Text "mo:base/Text";
    import Nat "mo:base/Nat";
    import Array "mo:base/Array";
    
    public func validateText(input: Text, minLen: Nat, maxLen: Nat) : Bool {
        let len = Text.size(input);
        len >= minLen and len <= maxLen
    };
    
    public func validateNat(input: Nat, min: Nat, max: Nat) : Bool {
        input >= min and input <= max
    };
    
    public func sanitizeText(input: Text) : Text {
        // Remove null bytes and control characters
        Text.translate(input, func(c: Char) : Text {
            if (c == '\0' or c < ' ') { "" } else { Text.fromChar(c) }
        })
    };
    
    public func isValidPrincipal(p: Principal) : Bool {
        not Principal.isAnonymous(p)
    };
};
```

### 12.4 Performance Optimization

#### 12.4.1 Data Structure Selection

Choose the right data structure for your use case:

```motoko
import HashMap "mo:base/HashMap";
import RBTree "mo:base/RBTree";
import Buffer "mo:base/Buffer";
import Array "mo:base/Array";

actor {
    // Use HashMap for fast lookups by key (O(1) average)
    var userCache = HashMap.HashMap<Principal, User>(100, Principal.equal, Principal.hash);
    
    // Use RBTree for sorted data and range queries (O(log n))
    var sortedScores = RBTree.RBTree<Nat, User>(Nat.compare);
    
    // Use Buffer for dynamic arrays with frequent additions (O(1) amortized)
    var eventLog = Buffer.Buffer<Event>(1000);
    
    // Use Array for immutable, fixed-size collections
    stable var constants : [Text] = ["value1", "value2", "value3"];
};
```

#### 12.4.2 Minimize State Access

```motoko
actor {
    stable var largeState : [User] = [];
    
    // ❌ Bad - multiple iterations over stable state
    public query func getActiveUsersCount() : async Nat {
        var count = 0;
        for (user in largeState.vals()) {
            if (user.active) { count += 1 };
        };
        count
    };
    
    // ✅ Better - maintain derived state
    stable var activeUserCount : Nat = 0;
    
    public func addUser(user: User) : async () {
        largeState := Array.append(largeState, [user]);
        if (user.active) {
            activeUserCount += 1;
        };
    };
    
    public query func getActiveUsersCountOptimized() : async Nat {
        activeUserCount  // O(1) instead of O(n)
    };
};
```

#### 12.4.3 Batch Operations

```motoko
actor {
    // ❌ Bad - multiple separate calls
    public shared func addUser(user: User) : async () {
        // Process one user
    };
    
    // ✅ Good - batch processing
    public shared func addUsers(users: [User]) : async [Result.Result<(), Text>] {
        Array.map<User, Result.Result<(), Text>>(
            users,
            func(user) {
                // Validate and process each user
                // Return result
                #ok(())
            }
        )
    };
};
```

#### 12.4.4 Query vs Update Calls

```motoko
actor {
    stable var counter : Nat = 0;
    var cache : Text = "";
    
    // Use query for read-only operations (faster, no consensus)
    public query func getCounter() : async Nat {
        counter
    };
    
    public query func getCache() : async Text {
        cache
    };
    
    // Use update calls only when modifying state
    public shared func incrementCounter() : async Nat {
        counter += 1;
        counter
    };
    
    // Use composite queries for efficient multi-canister reads
    public composite query func getMultipleValues() : async {
        local: Nat;
        remote: Nat;
    } {
        let remoteValue = await otherCanister.getValue();  // Query call
        {
            local = counter;
            remote = remoteValue;
        }
    };
};
```

### 12.5 Testing Strategies

#### 12.5.1 Unit Testing with Motoko Test

```motoko
// test/utils.test.mo
import Debug "mo:base/Debug";
import { test; suite } "mo:test";
import Utils "../src/utils";

suite("Utils Tests", func() {
    test("validateEmail with valid email", func() {
        let result = Utils.validateEmail("user@example.com");
        assert result == true;
    });
    
    test("validateEmail with invalid email", func() {
        let result = Utils.validateEmail("invalid");
        assert result == false;
    });
    
    test("sanitizeInput removes whitespace", func() {
        let result = Utils.sanitizeInput("  test  ");
        assert result == "test";
    });
});
```

#### 12.5.2 Integration Testing

```bash
#!/bin/bash
# test/integration.sh

# Start local replica
dfx start --background --clean

# Deploy canisters
dfx deploy

# Run test scenarios
dfx canister call my_canister addUser '(record { name = "Alice"; email = "alice@example.com" })'
dfx canister call my_canister getUser '(principal "aaaaa-aa")'

# Verify results
RESULT=$(dfx canister call my_canister getUserCount)
if [ "$RESULT" != "(1 : nat)" ]; then
    echo "Test failed: Expected user count 1"
    exit 1
fi

echo "All integration tests passed"
dfx stop
```

### 12.6 Common Pitfalls and Solutions

#### 12.6.1 Integer Overflow/Underflow

```motoko
import Nat "mo:base/Nat";
import Int "mo:base/Int";

actor {
    // ❌ Bad - can trap on underflow
    public func unsafeSubtract(a: Nat, b: Nat) : async Nat {
        a - b  // Traps if b > a
    };
    
    // ✅ Good - safe subtraction
    public func safeSubtract(a: Nat, b: Nat) : async Result.Result<Nat, Text> {
        if (b > a) {
            #err("Underflow: b > a")
        } else {
            #ok(a - b)
        };
    };
    
    // ✅ Use Int for values that can be negative
    public func safeDifference(a: Nat, b: Nat) : async Int {
        Int.abs(a) - Int.abs(b)
    };
};
```

#### 12.6.2 Memory Leaks

```motoko
actor {
    // ❌ Bad - unbounded growth
    var logs : [Text] = [];
    
    public func addLog(message: Text) : async () {
        logs := Array.append(logs, [message]);  // Grows forever
    };
    
    // ✅ Good - bounded with rotation
    stable var logs : [Text] = [];
    let MAX_LOGS = 1000;
    
    public func addLogBounded(message: Text) : async () {
        logs := Array.append(logs, [message]);
        if (logs.size() > MAX_LOGS) {
            logs := Array.subArray(logs, logs.size() - MAX_LOGS, MAX_LOGS);
        };
    };
};
```

#### 12.6.3 Upgrade Compatibility

```motoko
actor {
    // Version 1
    stable var users_v1 : [(Principal, Text)] = [];
    
    // Version 2 - Adding fields
    type UserV2 = {
        name: Text;
        email: Text;
        createdAt: Int;
    };
    
    stable var users_v2 : [(Principal, UserV2)] = [];
    
    system func postupgrade() {
        // Migrate from v1 to v2
        if (users_v1.size() > 0 and users_v2.size() == 0) {
            users_v2 := Array.map<(Principal, Text), (Principal, UserV2)>(
                users_v1,
                func((id, name)) {
                    (id, {
                        name = name;
                        email = "";  // Default value
                        createdAt = Time.now();
                    })
                }
            );
            users_v1 := [];  // Clear old data
        };
    };
};
```

### 12.7 Monitoring and Maintenance

#### 12.7.1 Health Checks

```motoko
actor HealthMonitor {
    stable var lastHealthCheck : Int = 0;
    stable var healthStatus : Text = "OK";
    
    public query func health() : async {
        status: Text;
        timestamp: Int;
        cycles: Nat;
        memorySize: Nat;
    } {
        {
            status = healthStatus;
            timestamp = Time.now();
            cycles = Cycles.balance();
            memorySize = Prim.rts_memory_size();
        }
    };
    
    public shared func performHealthCheck() : async Bool {
        lastHealthCheck := Time.now();
        
        // Check cycles
        if (Cycles.balance() < 1_000_000_000_000) {
            healthStatus := "WARN: Low cycles";
            return false;
        };
        
        // Check memory
        if (Prim.rts_memory_size() > 3_000_000_000) {
            healthStatus := "WARN: High memory usage";
            return false;
        };
        
        healthStatus := "OK";
        true
    };
};
```

#### 12.7.2 Metrics Collection

```motoko
actor Metrics {
    stable var requestCount : Nat = 0;
    stable var errorCount : Nat = 0;
    stable var totalLatency : Nat = 0;
    
    public shared func incrementRequests() : async () {
        requestCount += 1;
    };
    
    public shared func recordError() : async () {
        errorCount += 1;
    };
    
    public shared func recordLatency(latency: Nat) : async () {
        totalLatency += latency;
    };
    
    public query func getMetrics() : async {
        requests: Nat;
        errors: Nat;
        avgLatency: Float;
        errorRate: Float;
    } {
        let avgLatency = if (requestCount > 0) {
            Float.fromInt(totalLatency) / Float.fromInt(requestCount)
        } else {
            0.0
        };
        
        let errorRate = if (requestCount > 0) {
            Float.fromInt(errorCount) / Float.fromInt(requestCount)
        } else {
            0.0
        };
        
        {
            requests = requestCount;
            errors = errorCount;
            avgLatency = avgLatency;
            errorRate = errorRate;
        }
    };
};
```

### 12.8 Summary

Effective troubleshooting and following best practices are essential for building production-ready Internet Computer applications. Key takeaways:

1. **Understand Common Errors**: Familiarize yourself with compiler error codes and their solutions.
2. **Debug Effectively**: Use structured logging and query functions to inspect state.
3. **Handle Errors Gracefully**: Always use Result types for operations that can fail.
4. **Secure Your Code**: Implement proper authentication, authorization, and input validation.
5. **Optimize Performance**: Choose appropriate data structures and minimize state access.
6. **Test Thoroughly**: Write unit and integration tests for critical functionality.
7. **Monitor in Production**: Implement health checks and metrics collection.
8. **Plan for Upgrades**: Design stable variables and migration strategies from the start.

By following these practices, you'll write more robust, maintainable, and efficient Motoko applications.

---

