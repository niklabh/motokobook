# Chapter 11: Ecosystem Tools and Testing

Professional engineering requires rigorous testing and dependency management. The Motoko ecosystem has matured significantly, offering sophisticated tools for package management, testing, debugging, and continuous integration. This chapter explores the essential tools that transform Motoko development from experimental scripts into production-grade systems.

### 9.1 Dependency Management with Mops

Early Motoko development relied on `vessel`, but the ecosystem has migrated to **Mops** (Motoko Package Manager). Mops creates a standard for publishing and importing community libraries (like `encoding`, `test`, or data structures).

#### 9.1.1 Getting Started with Mops

**Initial Setup:**

```bash
# Install Mops globally
npm install -g ic-mops

# Initialize Mops in your project
mops init

# Add dependencies
mops add base
mops add sha256
mops add map
```

This generates a `mops.toml` configuration file:

```toml
[dependencies]
base = "0.11.1"
sha256 = "1.0.1"
map = "9.0.1"

[toolchain]
moc = "0.11.1"
```

#### 9.1.2 Using Dependencies in Code

Once dependencies are installed, import them using the `mo:` prefix:

```motoko
import SHA256 "mo:sha256";
import Map "mo:map/Map";
import { nhash } "mo:map";

actor {
  type Map<K, V> = Map.Map<K, V>;
  
  stable var subscriptions : Map<Principal, Nat64> = Map.new();
  
  public func hashPassword(password : Text) : async Blob {
    SHA256.fromText(password)
  };
}
```

#### 9.1.3 Publishing Your Own Package

Mops makes it easy to share reusable code with the community:

```bash
# Create package metadata
mops init --name my-library --version 1.0.0

# Add package description
mops config set description "My awesome Motoko library"
mops config set repository "https://github.com/username/my-library"

# Publish to Mops registry
mops publish
```

**Best Practices:**
- **Semantic Versioning**: Follow semver (1.0.0 → 1.0.1 for patches, 1.1.0 for features, 2.0.0 for breaking changes)
- **Documentation**: Include README.md with usage examples
- **Type Safety**: Export well-typed public interfaces
- **Testing**: Include test files demonstrating correct usage

#### 9.1.4 Version Pinning and Reproducibility

Mops generates a `mops.lock` file to ensure deterministic builds:

```toml
# mops.lock
[[packages]]
name = "base"
version = "0.11.1"
hash = "sha256:a1b2c3d4..."

[[packages]]
name = "sha256"
version = "1.0.1"
hash = "sha256:e5f6g7h8..."
```

**Always commit `mops.lock` to version control** to ensure all team members and CI/CD pipelines use identical dependencies.

### 9.2 Testing Strategies

Testing on the Internet Computer requires different approaches than traditional web development. Canisters are stateful, asynchronous, and interact with other canisters, requiring sophisticated testing strategies.

#### 9.2.1 Unit Testing Pure Functions

For pure Motoko functions (no state, no async), use the built-in `Debug.print` for simple assertions:

```motoko
import Debug "mo:base/Debug";
import Text "mo:base/Text";

module {
  public func calculateFee(amount : Nat) : Nat {
    amount * 5 / 100  // 5% fee
  };
  
  // Simple test
  public func testCalculateFee() {
    let result = calculateFee(1000);
    assert(result == 50);
    Debug.print("✓ calculateFee test passed");
  };
}
```

For more sophisticated unit testing, use the `motoko-matchers` library:

```motoko
import Suite "mo:matchers/Suite";
import T "mo:matchers/Testable";
import M "mo:matchers/Matchers";

let suite = Suite.suite("Fee Calculation Tests", [
  Suite.test("calculates 5% fee correctly",
    calculateFee(1000),
    M.equals(T.nat(50))
  ),
  Suite.test("handles zero amount",
    calculateFee(0),
    M.equals(T.nat(0))
  ),
  Suite.test("rounds down for odd amounts",
    calculateFee(999),
    M.equals(T.nat(49))
  ),
]);

Suite.run(suite);
```

#### 9.2.2 Testing Actor Methods

Testing actor methods requires a different approach since they're asynchronous and maintain state. Use `dfx` to deploy locally:

```bash
# Start local replica
dfx start --clean --background

# Deploy canister
dfx deploy my_canister

# Test via dfx command line
dfx canister call my_canister deposit '(100 : nat64)'
dfx canister call my_canister getBalance '()'
```

### 9.3 Integration Testing with PocketIC

Unit testing Motoko functions is useful, but integration testing involving multiple canisters (OpenPatron + Ledger + Internet Identity) is critical.

**PocketIC** is the industry-standard testing framework. It allows developers to write tests in Python or Rust that spin up a lightweight, deterministic instance of the Internet Computer. Unlike a full local replica, PocketIC allows for **Time Travel** (advancing the clock to test subscriptions) and inspecting the raw state of canisters.

#### 9.3.1 Setting Up PocketIC

**Python Setup:**

```bash
pip install pocket-ic
```

**Rust Setup:**

```toml
# Cargo.toml
[dev-dependencies]
pocket-ic = "3.0.0"
candid = "0.10"
```

#### 9.3.2 Basic PocketIC Test (Python)

```python
from pocket_ic import PocketIC

def test_deposit_and_withdrawal():
    # Create IC instance
    pic = PocketIC()
    
    # Deploy OpenPatron canister
    canister_id = pic.create_canister()
    pic.install_code(
        canister_id,
        wasm_path="./target/wasm32-unknown-unknown/release/openpatron.wasm"
    )
    
    # Create test user
    user_principal = pic.create_principal("user_a")
    
    # Test deposit
    result = pic.update_call(
        canister_id,
        user_principal,
        "deposit",
        encode([{"amount": 100}])
    )
    assert result["status"] == "success"
    
    # Verify balance
    balance = pic.query_call(
        canister_id,
        user_principal,
        "getBalance",
        encode([])
    )
    assert balance == 100
    
    # Test withdrawal
    result = pic.update_call(
        canister_id,
        user_principal,
        "withdraw",
        encode([{"amount": 50}])
    )
    assert result["status"] == "success"
    
    # Verify final balance
    balance = pic.query_call(canister_id, user_principal, "getBalance", encode([]))
    assert balance == 50
```

#### 9.3.3 Time Travel Testing

**Example PocketIC Scenario with Time Travel:**

```python
from pocket_ic import PocketIC
import time

def test_subscription_payment():
    pic = PocketIC()
    
    # 1. Instantiate OpenPatron Canister
    openpatron_id = pic.create_canister()
    pic.install_code(openpatron_id, wasm_path="openpatron.wasm")
    
    # 2. Instantiate Ledger Canister
    ledger_id = pic.create_canister()
    pic.install_code(ledger_id, wasm_path="ledger.wasm")
    
    # 3. Mint 100 tokens to User A
    user_a = pic.create_principal("alice")
    pic.update_call(ledger_id, pic.admin_principal(), "mint", 
                    encode([{"to": user_a, "amount": 100_000_000}]))
    
    # 4. User A calls deposit on OpenPatron
    pic.update_call(openpatron_id, user_a, "deposit",
                   encode([{"amount": 100_000_000}]))
    
    # 5. User A subscribes to Creator B
    creator_b = pic.create_principal("bob")
    pic.update_call(openpatron_id, user_a, "subscribe",
                   encode([{"creator": creator_b, "amount": 10_000_000}]))
    
    # 6. **Advance time by 31 days** (Crucial step impossible in standard unit tests)
    pic.advance_time_seconds(31 * 24 * 60 * 60)
    
    # Trigger heartbeat/timer to process subscriptions
    pic.tick()
    
    # 7. Assert that OpenPatron triggered the subscription payment automatically
    creator_balance = pic.query_call(openpatron_id, creator_b, "getBalance", encode([]))
    assert creator_balance == 10_000_000, "Subscription payment should have been processed"
    
    user_balance = pic.query_call(openpatron_id, user_a, "getBalance", encode([]))
    assert user_balance == 90_000_000, "User balance should be reduced by subscription amount"
```

#### 9.3.4 Multi-Canister Testing

Testing inter-canister calls is where PocketIC shines:

```python
def test_ledger_integration():
    pic = PocketIC()
    
    # Deploy multiple canisters
    ledger = pic.create_and_install("ledger.wasm")
    openpatron = pic.create_and_install("openpatron.wasm")
    
    # Configure OpenPatron to use Ledger
    pic.update_call(openpatron, pic.admin_principal(), "setLedgerId", 
                    encode([{"ledger": ledger}]))
    
    # User deposits via Ledger
    user = pic.create_principal("user")
    
    # Approve OpenPatron to spend tokens
    pic.update_call(ledger, user, "icrc2_approve", encode([{
        "spender": openpatron,
        "amount": 1_000_000
    }]))
    
    # OpenPatron pulls tokens from Ledger
    result = pic.update_call(openpatron, user, "depositFromLedger", 
                             encode([{"amount": 1_000_000}]))
    
    assert result["success"] == True
    
    # Verify internal balance matches
    balance = pic.query_call(openpatron, user, "getBalance", encode([]))
    assert balance == 1_000_000
```

### 9.4 Property-Based Testing

Property-based testing generates random inputs to verify that certain properties always hold:

```python
from hypothesis import given, strategies as st
from pocket_ic import PocketIC

@given(
    amount=st.integers(min_value=1, max_value=1_000_000_000),
    fee_percentage=st.integers(min_value=0, max_value=10)
)
def test_fee_calculation_properties(amount, fee_percentage):
    """Test that fee calculation always produces valid results"""
    pic = PocketIC()
    canister = pic.create_and_install("fee_calculator.wasm")
    
    result = pic.query_call(canister, pic.admin_principal(), 
                           "calculateFee", encode([{
                               "amount": amount,
                               "feePercentage": fee_percentage
                           }]))
    
    fee = decode(result)["fee"]
    
    # Property 1: Fee should never exceed amount
    assert fee <= amount
    
    # Property 2: Fee should be non-negative
    assert fee >= 0
    
    # Property 3: Fee should match expected calculation
    expected_fee = (amount * fee_percentage) // 100
    assert fee == expected_fee
```

### 9.5 Debugging Techniques

#### 9.5.1 Debug.print for Runtime Inspection

```motoko
import Debug "mo:base/Debug";

actor {
  public func processPayment(amount : Nat) : async Bool {
    Debug.print("Processing payment for amount: " # debug_show(amount));
    
    if (amount < 100) {
      Debug.print("⚠️  Payment amount too small");
      return false;
    };
    
    Debug.print("✓ Payment processed successfully");
    true
  };
}
```

Run with `dfx deploy` and view output in the terminal.

#### 9.5.2 Canister Profiling

Monitor canister performance:

```bash
# Check canister status
dfx canister status my_canister

# Output:
# Canister status: Running
# Memory allocation: 0
# Memory size: 1_234_567
# Cycles: 3_500_000_000_000
# Module hash: 0xabcd...
```

#### 9.5.3 State Inspection

PocketIC allows direct state inspection:

```python
def test_inspect_canister_state():
    pic = PocketIC()
    canister = pic.create_and_install("my_canister.wasm")
    
    # Perform some operations
    pic.update_call(canister, user, "addItem", encode([{"item": "test"}]))
    
    # Inspect stable memory directly
    stable_memory = pic.get_stable_memory(canister)
    print(f"Stable memory size: {len(stable_memory)} bytes")
    
    # Get canister cycles balance
    cycles = pic.get_cycle_balance(canister)
    assert cycles > 0, "Canister should have cycles"
```

### 9.6 Continuous Integration

Integrate PocketIC tests into CI/CD pipelines:

**GitHub Actions Example:**

```yaml
name: Motoko Tests

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    
    steps:
      - uses: actions/checkout@v3
      
      - name: Install DFX
        run: |
          sh -ci "$(curl -fsSL https://internetcomputer.org/install.sh)"
          echo "$HOME/.local/bin" >> $GITHUB_PATH
      
      - name: Install Mops
        run: npm install -g ic-mops
      
      - name: Install Dependencies
        run: mops install
      
      - name: Build Canisters
        run: dfx build
      
      - name: Install Python Dependencies
        run: |
          pip install pocket-ic pytest
      
      - name: Run Tests
        run: pytest tests/
```

### 9.7 Best Practices

1. **Test Pyramid**: Write many unit tests, fewer integration tests, and even fewer end-to-end tests
2. **Deterministic Tests**: Avoid flaky tests by using PocketIC's controlled environment
3. **Test Coverage**: Aim for >80% code coverage for critical paths
4. **Fast Feedback**: Keep unit tests fast (<1s), integration tests moderate (<30s)
5. **Realistic Data**: Use production-like data in tests to catch edge cases
6. **Upgrade Testing**: Test canister upgrades to verify stable variables persist correctly

```motoko
import Debug "mo:base/Debug";

actor {
  stable var version : Nat = 1;
  stable var data : [Nat] = [];
  
  system func preupgrade() {
    Debug.print("Preparing for upgrade, version: " # debug_show(version));
  };
  
  system func postupgrade() {
    version += 1;
    Debug.print("Upgraded to version: " # debug_show(version));
    assert(data.size() > 0);  // Verify data persisted
  };
}
```

### 9.8 Performance Testing

Load testing ensures your canister handles production traffic:

```python
import concurrent.futures
from pocket_ic import PocketIC

def stress_test_concurrent_calls():
    pic = PocketIC()
    canister = pic.create_and_install("my_canister.wasm")
    
    def make_call(i):
        user = pic.create_principal(f"user_{i}")
        return pic.update_call(canister, user, "processRequest", 
                              encode([{"data": f"request_{i}"}]))
    
    # Execute 100 concurrent calls
    with concurrent.futures.ThreadPoolExecutor(max_workers=100) as executor:
        futures = [executor.submit(make_call, i) for i in range(100)]
        results = [f.result() for f in futures]
    
    # All calls should succeed
    assert all(r["success"] for r in results)
    
    # Check canister didn't run out of cycles
    cycles = pic.get_cycle_balance(canister)
    assert cycles > 1_000_000_000, "Canister running low on cycles"
```

---

The combination of Mops for dependency management, PocketIC for integration testing, and proper CI/CD pipelines transforms Motoko development into a professional engineering discipline. These tools enable developers to ship complex, multi-canister systems with confidence.

---

