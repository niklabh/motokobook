# Chapter 8: Asynchronous Safety and Reentrancy

As OpenPatron moves from prototype to production, naive implementations will encounter the hard limits of distributed systems: concurrency bugs and resource constraints.

The most dangerous aspect of Motoko for developers coming from Solidity is the **non-atomicity of inter-canister calls**.

### 8.1 The Await Gap

When an actor calls `await ledger.transfer(...)`, the execution of that function is **suspended**. The actor releases its lock on the state. While waiting for the ledger to reply (which might take seconds), the actor can process _new_ messages from other users.

**The Reentrancy Vulnerability:**

Consider a naive withdrawal function:

1.  Check Balance (`if balance > 0`)
    
2.  `await ledger.transfer(balance)`
    
3.  Set Balance to 0 (`balance := 0`)
    

If a malicious user sends two withdrawal requests simultaneously:

-   **Request A** checks balance (100 tokens). Passes. Calls Ledger. Pauses.
    
-   **Request B** arrives. Request A is still paused (balance is still 100). Request B checks balance. Passes. Calls Ledger.
    
-   Both transfers succeed. The canister is drained.
    

### 8.2 The Solution: Optimistic Accounting vs. Locks

To prevent this, state changes must happen **before** the asynchronous call.

**Optimistic Accounting Pattern:**

1.  Check Balance.
    
2.  **Deduct Balance Immediately** (`balance := 0`).
    
3.  `await ledger.transfer(...)`.
    
4.  If the transfer fails (returns `#Err`), **Refund the Balance** (`balance += amount`).
    

This ensures that any interleaved messages see the updated (zero) balance.

**Code Example: Safe Withdrawal**

```js
public shared (msg) func withdraw(amount : Nat) : async Text {
    let user = msg.caller;
    let currentBal = getBalance(user);
    
    if (currentBal < amount) return "Insufficient Funds";
    
    // 1. UPDATE STATE BEFORE AWAIT
    balances.put(user, currentBal - amount);
    
    // 2. INTERACT WITH EXTERNAL ACTOR
    let result = await ledger.icrc1_transfer(...);
    
    // 3. HANDLE ROLLBACK IF NEEDED
    switch(result) {
        case (#Ok(_)) { return "Success"; };
        case (#Err(_)) {
            // Refund
            let newBal = getBalance(user);
            balances.put(user, newBal + amount);
            return "Transfer failed, refunded.";
        };
    };
};
```

### 8.3 Visualizing the Await Gap

It helps to treat every shared function as a **three-phase state machine**:

1.  **Pre-await** – deterministic, single-threaded execution.
2.  **Await gap** – execution is suspended, other messages may mutate state.
3.  **Post-await** – resumes with whatever state now exists.

```
User A calls withdraw ─┐
                       ├─ Phase 1: balance read, state updated
User B calls withdraw ─┘
                       ├─ Await gap: A is paused, B now runs
Ledger responds       ─┘
                       └─ Phase 3: A resumes with NEW state
```

By explicitly labelling these phases in design docs, engineers remember to ask _“What can happen while we are away?”_. That question tends to surface hidden assumptions about uniqueness, ordering, and double-spend resistance.

### 8.4 Guarding with Pending Operations

Optimistic accounting works for simple subtraction, but larger workflows need **operation guards**. Track every in-flight withdrawal in a `pendingOps` map keyed by `(user, nonce)`:

```js
type Pending = {
    amount : Nat;
    expiresAt : Nat;
};

stable var pendingOps : HashMap<(Principal, Nat), Pending> = ...;
```

-   **Before the await**: insert a record with an expiration block height.
-   **On resume**: remove the record only after the external effect succeeds.
-   **On timeout**: a cron or heartbeat can sweep expired entries back into balances.

This pattern prevents overlapping operations per user while still allowing the canister to serve other principals.

### 8.5 Idempotent External Calls

Ledger calls are not guaranteed to be idempotent—network retries may result in duplicates. Wrap every transfer payload in a deterministic memo (e.g., hash of `(user, nonce, amount)`) so repeated ledger executions can be detected downstream. On the Motoko side:

1.  Persist the memo in stable state.
2.  Verify the returned block’s memo matches.
3.  If the await resumes with an error, re-issue the same memo instead of minting a new one.

Idempotency removes an entire class of “at-least-once” bugs that otherwise leak funds when retries overlap with user-initiated calls.

### 8.6 Testing for Reentrancy Bugs

Reentrancy is hard to spot by inspection alone. Combine the following techniques:

-   **PocketIC / ic-repl scripts**: send two `withdraw` calls in quick succession and assert final balances.
-   **Forced scheduling**: use a mock ledger canister that delays its response so you can deterministically interleave other calls during the await gap.
-   **Property tests**: model balances as integers and prove “total supply never decreases” under arbitrary call orderings.

Automating these tests ensures future refactors (e.g., when changing the storage layout) keep the same concurrency guarantees.

---

