# Chapter 7: Autonomous Subscriptions via Timers

The "Holy Grail" of crypto payments is the recurring subscription. Blockchains are passive; they only change state when triggered. Ethereum requires external "Keepers" (e.g., Chainlink Automation) to trigger functions. The Internet Computer, however, allows canisters to schedule their own execution.

### 7.1 The Timer API

Motoko provides the `Timer` module in the base library. It allows for both one-off tasks (`setTimer`) and recurring tasks (`recurringTimer`).

**Implementation Strategy:**

OpenPatron initiates a recurring timer that runs every hour (or day). This "Cron Job" iterates through active subscriptions and processes payments.

```js
import Timer "mo:base/Timer";
import Time "mo:base/Time";

actor OpenPatron {
    
    // One day in nanoseconds
    let INTERVAL : Nat64 = 86_400_000_000_000; 

    // The heartbeat function
    private func processSubscriptions() : async () {
        let now = Time.now();
        // Iterate active subscriptions
        // Check if due_date < now
        // Move internal balance from Patron to Creator
    };

    // Start the engine
    public func init() : async () {
        let timerId = Timer.recurringTimer(#nanoseconds(INTERVAL), processSubscriptions);
    };
}
```

### 7.2 Efficiency and "Virtual" Transactions

Crucially, the `processSubscriptions` function does **not** interact with the main Token Ledger for every subscription payment. That would be prohibitively slow and expensive (requiring inter-canister calls for every $5 payment).

Instead, OpenPatron uses **Virtual Accounting**:

1.  The Patron deposits $50 into the canister (recorded on the Ledger).
    
2.  OpenPatron credits the Patron's internal balance variable.
    
3.  Every month, OpenPatron simply decrements `PatronBalance` and increments `CreatorBalance` in its own `TrieMap`. This operation is instant and free.
    
4.  Real tokens only move on the Ledger when the Creator decides to `withdraw()` their accumulated earnings.
    

This scalability strategy mirrors how centralized exchanges (Coinbase, Binance) handle internal trades off-chain, but here the "off-chain" logic is actually "on-chain" in the canister's secured memory.

### 7.3 Scheduling Windows and Drift

Timers are *best effort*. They are driven by the replica's heartbeat, so the callback runs **no sooner** than the interval and can drift when the subnet is busy. Keep the following guard rails in mind:

- Treat the timer as a *reminder* rather than an exact timestamp. Always compare `subscription.nextCharge <= Time.now()` before charging.
- Keep timer callbacks short (< ~2B instructions). Heavy work should be chunked and scheduled again, otherwise the replica will trap the timer.
- Persist the timer identifier if you need to cancel or reschedule it after upgrades: store `timerId : ?Timer.TimerId` in stable memory and restart it from `postupgrade`.

When ultra-precise timing is required (e.g., daily charges at midnight UTC), record the `nextCharge` timestamp and calculate `max(Time.now() - nextCharge, 0)` to detect missed windows.

### 7.4 Modeling the Subscription Queue

Because the timer callback may run late, the queue must be idempotent. One practical model:

```js
type SubscriptionId = Nat32;
type Timestamp = Nat64;

type Subscription = {
    patron : Principal;
    creator : Principal;
    cadence : Nat64;          // nanoseconds between invoices
    nextCharge : Timestamp;
    amount : Nat;
};

stable var subscriptions = TrieMap.TrieMap<SubscriptionId, Subscription>(...);
```

- The timer walks the map, collects subscriptions whose `nextCharge` is due, and pushes them into a batch list.
- After posting the batch, update each record's `nextCharge += cadence`. If the patron lacks funds, mark the subscription as `Suspended` and notify them out-of-band.
- Use pagination (process 100 subs per tick) to stay within instruction limits. Add a `cursor` in stable memory so the next tick resumes where it left off.

### 7.5 Failure Modes and Recovery

Even with virtual accounting, things can go wrong:

- **Transient traps** (e.g., due to temporary Ledger outages). Surround external calls with retries/backoff and record failures in a `Queue<Event>` that a maintainer can inspect.
- **Long outages**. If the canister is stopped for hours, the next timer run should loop until `nextCharge` catches up with `now`, charging multiple periods if necessary.
- **Skipped patrons**. Store a `lastProcessed` timestamp for diagnostic purposes so you can alert users when their subscriptions paused for too long.

Expose a public `manualProcess(limit : Nat)` method guarded by an access control check. Operators can call it to drain the queue if the timer lags.

### 7.6 Manual Overrides and Observability

Self-healing automation still needs visibility:

- Emit `processSubscriptions` metrics: number of patrons charged, total debited, ms spent. You can expose these via `shared query func stats()`.
- Log anomalies (insufficient balance, stuck creators) to an append-only `EventLog`. Keep it compact (e.g., circular buffer) so upgrades stay cheap.
- Provide UX endpoints: `patronUpcomingCharges(patron, horizon)` so front-ends can show when the next debit occurs.

### 7.7 Testing Timer Logic Without Waiting

Timers do not fire inside unit tests, so decouple the pure logic from the scheduling:

1. Move the core loop into `processSubscriptionsInternal(now : Time.Time)`.
2. Have the timer call `processSubscriptionsInternal(Time.now())`.
3. In tests, inject deterministic timestamps and fake subscription data to assert the resulting state transitions (`balances`, `nextCharge`, event logs).

This pattern also enables canary environments where you invoke `manualProcess` on demand before enabling the recurring timer in production.

---

