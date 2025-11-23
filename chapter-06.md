# Chapter 6: Tokenomics and Ledger Integration

OpenPatron requires a financial layer. Unlike Ethereum, where tokens are smart contracts often copied and pasted by developers, ICP encourages the use of standardized **Ledger Canisters** implementing the **ICRC-1** standard.

### 6.1 Inter-Canister Ledger Interactions

OpenPatron does not "mint" new tokens; it manages the flow of existing tokens (e.g., ICP or a stablecoin). Therefore, OpenPatron acts as a wallet controller.

To interact with the official Ledger, we must define an **Actor Interface**. This is equivalent to an ABI (Application Binary Interface) in Solidity.

```js
// Abstract interface for the ICRC-1 Ledger
type Account = { owner : Principal; subaccount : ?[Nat8] };
type TransferArgs = {
    to : Account;
    fee : ?Nat;
    memo : ?Blob;
    from_subaccount : ?[Nat8];
    created_at_time : ?Nat64;
    amount : Nat;
};
type TransferResult = { #Ok : Nat; #Err : Variant {... } };

actor OpenPatron {
    let ledgerId = Principal.fromText("mxzaz-hqaaa-aaaar-qaada-cai");
    let ledger = actor(Principal.toText(ledgerId)) : actor {
        icrc1_transfer : (TransferArgs) -> async TransferResult;
        icrc1_balance_of : (Account) -> async Nat;
    };
}
```

### 6.2 The Deposit Pattern vs. Approve/TransferFrom

In Ethereum, the standard subscription pattern is `approve()` (User allows contract to spend) followed by `transferFrom()` (Contract pulls funds). While supported by ICRC-2, this introduces UX friction (two transactions).

For OpenPatron, we implement the **Deposit Pattern** (often called the Subaccount Pattern):

1.  **Subaccount Generation:** OpenPatron calculates a unique subaccount address for User A. This is a deterministic derivation of `hash(OpenPatron_Principal + User_A_Principal)`.
    
2.  **Direct Transfer:** User A sends tokens directly to this subaccount on the Ledger. This is a standard transfer, not a smart contract interaction.
    
3.  **Notification:** User A calls `OpenPatron.notify_deposit()`.
    
4.  **Verification:** OpenPatron queries the Ledger for the balance of that specific subaccount.
    
5.  **Crediting:** OpenPatron updates its internal state: `balances[User_A] += amount`.
    

This pattern is gas-efficient and secure, as OpenPatron has full cryptographic control over the subaccount.

### 6.3 Deterministic Subaccount Derivation

Subaccounts are 32-byte blobs, so we can deterministically derive one per supporter without storing anything on-chain. The canonical approach is to hash a namespace prefix together with the caller's `Principal`.

```js
import Blob "mo:base/Blob";
import Principal "mo:base/Principal";
import SHA256 "mo:crypto/SHA/SHA256";

let namespace = "OpenPatron";

func supporterSubaccount(user : Principal) : Blob {
  let input = Blob.fromArray(Text.encodeUtf8(namespace)) # Principal.toBlob(user);
  let digest = SHA256.fromBlob(input);
  return Blob.fromArray(digest.vals()[0 : 32]);
};
```

Because the derivation is deterministic, both the frontend and backend can display the same deposit address. If the namespace ever changes, historical subaccounts are still valid because the Ledger only cares about the resulting 32-byte value.

### 6.4 Verifying Deposits Against the Ledger

When `notify_deposit()` is called, OpenPatron must query the Ledger to confirm funds really arrived. The flow is:

1. Recompute the subaccount using the user principal.
2. Call `icrc1_balance_of` with `{ owner = OpenPatron_Principal; subaccount = ?sub }`.
3. Compare the returned amount with what the user claims.
4. Only after a successful check, update internal accounting and emit an event.

```js
public shared ({ caller }) func notifyDeposit(expected : Nat) : async Nat {
  let account : Account = { owner = OpenPatronId; subaccount = ?Blob.toArray(supporterSubaccount(caller)) };
  let balance = await ledger.icrc1_balance_of(account);
  assert(balance >= expected);
  balances.put(caller, balance);
  return balance;
};
```

This keeps OpenPatron stateless regarding incoming transfers and aligns with the immutable history the Ledger already provides.

### 6.5 Withdrawals, Refunds, and Creator Payouts

Outbound transfers use the same actor reference but call `icrc1_transfer`. We treat refunds and scheduled payouts identically; only the `Account` destination differs.

```js
public shared ({ caller }) func payout(creator : Principal, amount : Nat) : async TransferResult {
  assert(hasRole(caller, #Admin));
  let args : TransferArgs = {
    to = { owner = creator; subaccount = null };
    fee = null;
    memo = null;
    from_subaccount = null;
    created_at_time = ?Time.now();
    amount = amount;
  };
  return await ledger.icrc1_transfer(args);
};
```

Important safeguards:

- Track pending payouts in stable memory so retries are idempotent.
- Cap the maximum amount per call to avoid draining the treasury due to a bug.
- Bubble up `#Err` variants to the caller so the UI can prompt the user to retry later.

### 6.6 Supporting Multiple Tokens (ICRC-1 vs. ICRC-2)

Many creators want to accept both ICP and a stable asset. OpenPatron can maintain a registry of "payment rails," each storing the Ledger canister principal, decimals, and default fee. The deposit workflow stays the same because every ICRC-1 token exposes `icrc1_balance_of` and `icrc1_transfer`. For tokens that support ICRC-2 approvals, we can optionally let power users enable the `approve/transfer_from` flow for recurring billing, while keeping the deposit pattern as the default for simplicity.

### 6.7 Local Testing with the Ledger Canister

`dfx` ships with a local Ledger replica. A productive workflow is:

1. `dfx start --background --clean`
2. `dfx ledger fabricate-cycles --canister openpatron`
3. `dfx ledger transfer <subaccount-principal> --amount 10`
4. Call `notify_deposit` from the candid UI or a unit test.

Because the local Ledger persists to the `dfx` state directory, you can script entire integration tests that simulate deposits, time-based payouts, and refunds without touching mainnet.

### 6.8 Operational Safeguards

- **Rate limits:** throttle `notify_deposit` to prevent spamming ledger queries.
- **Reconciliation jobs:** run a nightly timer that scans every subaccount and compares on-ledger balances with internal records to catch drift.
- **Audit trails:** append immutable events (deposit verified, payout executed, refund issued) to a log canister so compliance and customer support have a source of truth.
- **Upgrade safety:** keep derived subaccounts deterministic and do not migrate them; ledger balances are independent of code upgrades, so your upgrade logic should never attempt to recreate them differently.

---

