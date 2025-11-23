# OpenPatron Architecture

Comprehensive technical architecture documentation for the OpenPatron platform.

## System Overview

OpenPatron is a decentralized membership and subscription platform built on the Internet Computer Protocol (ICP). It enables creators to receive recurring payments from patrons without intermediaries.

```
┌─────────────────────────────────────────────────────────────┐
│                      OpenPatron Platform                     │
│                                                               │
│  ┌────────────────────────────────────────────────────────┐ │
│  │                   Actor Interface                       │ │
│  │  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐ │ │
│  │  │  Query   │ │  Update  │ │  System  │ │  Timer   │ │ │
│  │  │ Methods  │ │ Methods  │ │  Hooks   │ │ Callback │ │ │
│  │  └──────────┘ └──────────┘ └──────────┘ └──────────┘ │ │
│  └────────────────────────────────────────────────────────┘ │
│                                                               │
│  ┌────────────────────────────────────────────────────────┐ │
│  │                   Business Logic Layer                  │ │
│  │  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐ │ │
│  │  │Identity  │ │ Payment  │ │Subscribe │ │  Cycle   │ │ │
│  │  │  Mgmt    │ │  Engine  │ │  Engine  │ │   Mgmt   │ │ │
│  │  └──────────┘ └──────────┘ └──────────┘ └──────────┘ │ │
│  └────────────────────────────────────────────────────────┘ │
│                                                               │
│  ┌────────────────────────────────────────────────────────┐ │
│  │                   Data Layer                            │ │
│  │  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐ │ │
│  │  │  Users   │ │ Balances │ │Subscribe │ │  Logs    │ │ │
│  │  │ HashMap  │ │ HashMap  │ │ HashMap  │ │  Buffer  │ │ │
│  │  └──────────┘ └──────────┘ └──────────┘ └──────────┘ │ │
│  │                                                         │ │
│  │  ┌────────────────────────────────────────────────┐   │ │
│  │  │           Stable Memory (Persistent)            │   │ │
│  │  │  - usersEntries: [(Principal, Profile)]         │   │ │
│  │  │  - balancesEntries: [(Principal, Nat)]          │   │ │
│  │  │  - subscriptionsEntries: [(ID, Subscription)]   │   │ │
│  │  │  - treasuryBalance: Nat                         │   │ │
│  │  │  - logs: [LogEntry]                             │   │ │
│  │  └────────────────────────────────────────────────┘   │ │
│  └────────────────────────────────────────────────────────┘ │
│                                                               │
│  ┌────────────────────────────────────────────────────────┐ │
│  │              External Integration Layer                 │ │
│  │  ┌──────────────────┐  ┌──────────────────┐           │ │
│  │  │  ICRC-1 Ledger   │  │  HTTP Outcalls   │           │ │
│  │  │  (Token Transfers)│  │  (Optional)      │           │ │
│  │  └──────────────────┘  └──────────────────┘           │ │
│  └────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

## Core Components

### 1. Identity & Access Control

**Purpose**: Manage user authentication, profiles, and role-based permissions.

**Key Types**:
- `Role`: `#Patron | #Creator | #Admin`
- `Profile`: User information and metadata

**Data Structures**:
- `users: HashMap<Principal, Profile>` - User registry
- `usersEntries: [(Principal, Profile)]` - Stable storage

**Security Patterns**:
- Anonymous caller rejection
- Role-based access control (RBAC)
- Principal-based authentication

**Functions**:
- `register()` - Create new user account
- `getProfile()` - Retrieve user profile
- `updateProfile()` - Modify profile information
- `assignRole()` - Admin-only role management

### 2. Payment Engine

**Purpose**: Handle deposits, withdrawals, and internal accounting.

**Key Concepts**:
- **Virtual Accounting**: Internal balance tracking for efficiency
- **Subaccount Pattern**: Deterministic deposit addresses
- **Optimistic Accounting**: Reentrancy protection

**Data Flow**:

```
1. Deposit Flow:
   User transfers tokens to subaccount on Ledger
        ↓
   User calls notifyDeposit()
        ↓
   Platform verifies balance on Ledger
        ↓
   Platform credits internal balance

2. Withdrawal Flow:
   User calls withdraw()
        ↓
   Platform deducts balance immediately (optimistic)
        ↓
   Platform transfers via Ledger
        ↓
   On failure: Refund internal balance
```

**Functions**:
- `getDepositAddress()` - Get unique deposit address
- `notifyDeposit()` - Verify and credit deposit
- `getBalance()` - Query internal balance
- `withdraw()` - Transfer tokens out

**ICRC-1 Integration**:
```motoko
type Account = { owner: Principal; subaccount: ?Blob };
type TransferArgs = { to: Account; amount: Nat; ... };
type TransferResult = { #Ok: Nat; #Err: TransferError };
```

### 3. Subscription Engine

**Purpose**: Automate recurring payments from patrons to creators.

**Key Types**:
```motoko
type Subscription = {
    patron: Principal;
    creator: Principal;
    cadence: Int;        // Billing interval (nanoseconds)
    nextCharge: Int;     // Next charge timestamp
    amount: Nat;         // Payment amount
    active: Bool;        // Subscription status
};
```

**Timer Architecture**:
```
System Timer (24-hour interval)
        ↓
processSubscriptions()
        ↓
For each active subscription:
    ├─ Check if nextCharge <= now
    ├─ Verify patron balance
    ├─ Calculate platform fee (1%)
    ├─ Update balances (virtual accounting)
    ├─ Update nextCharge time
    └─ Log transaction
```

**State Machine**:
```
[Created] ──subscribe()──> [Active]
                              │
    ┌─────────────────────────┼─────────────────────────┐
    │                         │                         │
    │                         │                         │
cancelSubscription()   Insufficient Funds      processSubscriptions()
    │                         │                         │
    ↓                         ↓                         ↓
[Cancelled]              [Suspended]              [Next Cycle]
```

**Functions**:
- `subscribe()` - Create new subscription
- `cancelSubscription()` - Terminate subscription
- `getSubscription()` - Query subscription details
- `getActiveSubscriptions()` - List all active subscriptions
- `processSubscriptions()` - Internal timer callback

### 4. Cycle Management

**Purpose**: Monitor and maintain canister operational budget.

**Economic Model**:
```
Revenue Sources:
├─ Platform fees (1% of subscriptions)
└─ Direct cycle deposits

Expenses:
├─ Storage costs (~4.2B cycles/GB/day)
├─ Computation costs (varies by usage)
└─ Inter-canister calls (to Ledger)

Sustainability:
Treasury Balance → Convert to Cycles → Fund Operations
```

**Monitoring**:
- `MINIMUM_CYCLES`: 1T (emergency threshold)
- `CYCLES_REFILL_THRESHOLD`: 2T (refill trigger)
- Automatic health checks via timer

**Functions**:
- `getCycleBalance()` - Query current cycles
- `checkHealth()` - Health status check
- `acceptCycles()` - Receive cycle deposits
- `getTreasuryBalance()` - Query platform revenue

### 5. Logging & Observability

**Purpose**: Track system events for debugging and audit trails.

**Log Structure**:
```motoko
type LogEntry = {
    timestamp: Time.Time;
    level: LogLevel;      // #info | #warning | #error
    message: Text;
};
```

**Storage Strategy**:
- In-memory buffer (1000 entries max)
- Circular buffer (oldest entries evicted)
- Persisted to stable memory on upgrades

**Functions**:
- `getLogs()` - Query recent log entries
- `getStats()` - Platform statistics

## Data Flow Diagrams

### User Registration

```
Frontend                 OpenPatron                 State
   │                         │                        │
   │─register("alice")──────>│                        │
   │                         │                        │
   │                         │──requireAuthenticated()│
   │                         │                        │
   │                         │──users.get(caller)────>│
   │                         │<─────null──────────────│
   │                         │                        │
   │                         │──users.put(...)───────>│
   │                         │──log(#info, ...)──────>│
   │                         │                        │
   │<─────true───────────────│                        │
```

### Subscription Payment Processing (Automated)

```
Timer                   OpenPatron                  Ledger
 │                          │                         │
 │──tick (24h)─────────────>│                         │
 │                          │                         │
 │                    processSubscriptions()          │
 │                          │                         │
 │                    For each subscription:          │
 │                      ├─ Check nextCharge          │
 │                      ├─ Verify balance            │
 │                      ├─ Calculate fee             │
 │                      ├─ Update balances           │
 │                      └─ Update nextCharge         │
 │                          │                         │
 │                    (All virtual, no Ledger calls)  │
```

### Withdrawal (With Ledger Call)

```
User                    OpenPatron                  Ledger
 │                          │                         │
 │──withdraw(1000)─────────>│                         │
 │                          │                         │
 │                     Check balance (1500)           │
 │                     ├─ Deduct 1000 (now 500)      │
 │                     │                              │
 │                     └─icrc1_transfer(1000)────────>│
 │                          │                         │
 │                          │<────#Ok(blockIndex)─────│
 │                          │                         │
 │<─────#ok()───────────────│                         │
 │                          │                         │
 │                   (If error, refund 1000)          │
```

## Security Architecture

### Reentrancy Protection

**Problem**: Async inter-canister calls can be interleaved.

**Solution**: Optimistic Accounting Pattern

```motoko
// ❌ VULNERABLE
func withdraw(amount) {
    if (balance >= amount) {           // 1. Check
        await ledger.transfer(amount);  // 2. Interact (VULNERABLE GAP)
        balance -= amount;              // 3. Update
    }
}

// ✅ SECURE
func withdraw(amount) {
    if (balance >= amount) {           // 1. Check
        balance -= amount;              // 2. Update FIRST
        let result = await ledger.transfer(amount);  // 3. Interact
        if (result == #Err) {
            balance += amount;          // 4. Rollback on failure
        }
    }
}
```

### Access Control Matrix

| Function              | Anonymous | Patron | Creator | Admin |
|-----------------------|-----------|--------|---------|-------|
| whoami()              | ✅        | ✅     | ✅      | ✅    |
| register()            | ❌        | ✅     | ✅      | ✅    |
| getProfile()          | ❌        | ✅     | ✅      | ✅    |
| subscribe()           | ❌        | ✅     | ✅      | ✅    |
| withdraw()            | ❌        | ✅     | ✅      | ✅    |
| assignRole()          | ❌        | ❌     | ❌      | ✅    |
| getStats()            | ✅        | ✅     | ✅      | ✅    |

### Input Validation

All public functions validate:
- Principal is not anonymous
- Text inputs are sanitized
- Numeric values are within bounds
- Required fields are present

## Upgrade Strategy

### Stable Variables

Data persisted across upgrades:
```motoko
stable var usersEntries: [(Principal, Profile)] = [];
stable var balancesEntries: [(Principal, Nat)] = [];
stable var subscriptionsEntries: [(SubscriptionId, Subscription)] = [];
stable var treasuryBalance: Nat = 0;
stable var nextSubscriptionId: SubscriptionId = 0;
stable var logs: [LogEntry] = [];
```

### Lifecycle Hooks

```motoko
system func preupgrade() {
    // Convert HashMaps to stable arrays
    usersEntries := Iter.toArray(users.entries());
    balancesEntries := Iter.toArray(balances.entries());
    subscriptionsEntries := Iter.toArray(subscriptions.entries());
    logs := Buffer.toArray(logBuffer);
}

system func postupgrade() {
    // Restore HashMaps from stable arrays
    users := HashMap.fromIter(usersEntries.vals(), ...);
    balances := HashMap.fromIter(balancesEntries.vals(), ...);
    subscriptions := HashMap.fromIter(subscriptionsEntries.vals(), ...);
    
    // Restore logs to buffer
    for (entry in logs.vals()) {
        logBuffer.add(entry);
    };
    
    // Restart timer
    initTimer();
}
```

### Migration Strategy

For breaking changes:
1. Add version field to stable variables
2. Implement migration logic in postupgrade
3. Test on local replica before mainnet
4. Deploy to testnet first
5. Monitor for 24 hours before mainnet upgrade

## Performance Considerations

### Query vs Update Calls

- **Query**: Fast, read-only, not certified
  - `getProfile()`, `getBalance()`, `getStats()`
  
- **Update**: Slower, consensus, state-modifying
  - `register()`, `withdraw()`, `subscribe()`

### Instruction Limits

- **Single message**: 20B instructions
- **Timer callback**: Should stay under 2B instructions
- **Chunk large operations** if approaching limits

### Memory Management

- HashMaps: O(1) lookup, O(n) upgrade cost
- Stable memory: Persistent but slower access
- Circular log buffer: Bounded memory usage

## Integration Points

### ICRC-1 Ledger

Required methods:
```motoko
actor {
    icrc1_transfer: (TransferArgs) -> async TransferResult;
    icrc1_balance_of: (Account) -> async Nat;
}
```

### Frontend (via Agent-JS)

```typescript
import { Actor, HttpAgent } from "@dfinity/agent";
import { idlFactory } from "./declarations/openpatron";

const agent = new HttpAgent({ host: "https://ic0.app" });
const actor = Actor.createActor(idlFactory, {
    agent,
    canisterId: "xxxxx-xxxxx-xxxxx-xxxxx-cai",
});

// Call methods
await actor.register("alice", ["Bio text"]);
const profile = await actor.getProfile();
```

## Scalability

### Current Limits

- **Users**: ~1M (HashMap capacity)
- **Subscriptions**: ~1M active subscriptions
- **Logs**: 1000 entries (circular buffer)

### Scaling Strategies

1. **Horizontal Scaling**: Split by user cohort
   - UserCanister_A (principals A-M)
   - UserCanister_B (principals N-Z)

2. **Vertical Scaling**: Split by function
   - IdentityCanister
   - PaymentCanister
   - SubscriptionCanister

3. **Archive Pattern**: Move old data to archive canister

## Future Extensions

### Planned Features (From Book)

- HTTP Outcalls for creator verification (Chapter 9)
- Frontend asset canister (Chapter 10)
- PocketIC integration tests (Chapter 11)
- SNS governance (Chapter 13)

### Potential Enhancements

- Multi-token support
- Tiered subscriptions
- Creator analytics dashboard
- Patron perks and rewards
- Escrow for disputes
- Reputation system

---

**Architecture Version**: 1.0.0  
**Last Updated**: 2025  
**Corresponds to**: Mastering Motoko - Chapters 5-12

